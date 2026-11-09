"""Small, reproducible agent smoke suite; not a general coding/security benchmark."""

import argparse
import json
import os
from pathlib import Path
import re
import resource
import subprocess
import tempfile
import time
import urllib.request


PRELUDE = """#include <cstdint>
#include <vector>
#include <optional>
#include <stdexcept>
#include <limits>
#include <cassert>
struct Frame { std::vector<uint8_t> payload; size_t consumed; };
"""
CASES = {
    "packet_parser": {
        "prompt": """Implement this C++17 function only (no main, no struct definitions):
std::optional<Frame> decode_frame(const std::vector<uint8_t>& data, uint32_t max_payload);
Frame is already defined as { std::vector<uint8_t> payload; size_t consumed; }.
Protocol: four-byte unsigned little-endian payload length, followed by payload bytes.
Return nullopt for an incomplete header or incomplete allowed-length payload.
As soon as a complete header declares a length above max_payload, throw std::length_error,
even when its payload has not arrived. Accept empty payloads. Return only the first frame;
consumed counts header plus payload. Leave input unchanged. Avoid overflow and unbounded
allocation on attacker-controlled lengths. Standard library only. Return one cpp code fence.""",
        "tests": """
int main() {
  for (size_t n=0; n<4; ++n) assert(!decode_frame(std::vector<uint8_t>(n,0),100));
  assert(!decode_frame({3,0,0,0,1,2},100));
  auto empty=decode_frame({0,0,0,0,9},0);
  assert(empty && empty->payload.empty() && empty->consumed==4);
  const std::vector<uint8_t> in={3,0,0,0,0,128,255,8,9};
  auto r=decode_frame(in,3);
  assert(r && r->payload==std::vector<uint8_t>({0,128,255}) && r->consumed==7);
  assert(in==std::vector<uint8_t>({3,0,0,0,0,128,255,8,9}));
  for (auto data : std::vector<std::vector<uint8_t>>{{4,0,0,0},{255,255,255,255},{0,1,0,0}}) {
    bool threw=false;
    try { decode_frame(data,3); } catch(const std::length_error&) { threw=true; }
    assert(threw);
  }
  std::vector<uint8_t> long_frame(260,42);
  long_frame[0]=0; long_frame[1]=1; long_frame[2]=0; long_frame[3]=0;
  auto big=decode_frame(long_frame,256);
  assert(big && big->payload.size()==256 && big->consumed==260);
}
""",
    },
    "currency_transfer": {
        "prompt": """Implement this C++17 function only (no main):
bool transfer(uint64_t& source, uint64_t& destination, uint64_t amount);
Single-threaded game currency transfer. Reject zero amount, insufficient funds, destination
overflow, or source and destination referencing the same object. On any rejection return
false and leave both balances unchanged. Otherwise transfer exactly amount and return true.
Handle the full uint64_t range without wraparound. Standard library only. One cpp code fence.""",
        "tests": """
int main() {
  const auto M=std::numeric_limits<uint64_t>::max();
  for(auto a : std::vector<uint64_t>{0,1,10,M-1,M})
    for(auto b : std::vector<uint64_t>{0,1,10,M-1,M})
      for(auto n : std::vector<uint64_t>{0,1,10,M-1,M}) {
        auto x=a, y=b;
        bool expect=n>0 && n<=a && n<=M-b;
        assert(transfer(x,y,n)==expect);
        assert(x==(expect ? a-n : a) && y==(expect ? b+n : b));
      }
  uint64_t balance=100;
  assert(!transfer(balance,balance,10) && balance==100);
}
""",
    },
}


def limits():
    resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
    resource.setrlimit(resource.RLIMIT_AS, (2 * 1024**3, 2 * 1024**3))
    resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024**2, 16 * 1024**2))
    resource.setrlimit(resource.RLIMIT_NOFILE, (128, 128))
    # Linux counts this limit across the real user's existing desktop threads.
    resource.setrlimit(resource.RLIMIT_NPROC, (4096, 4096))


def sandbox(directory, command):
    # No home, credentials, host /tmp, device access, or network in the child.
    args = [os.environ["STRATA_BWRAP"], "--unshare-all", "--die-with-parent",
            "--new-session", "--ro-bind", "/nix/store", "/nix/store",
            "--bind", str(directory), "/work", "--tmpfs", "/tmp",
            "--proc", "/proc", "--dev", "/dev", "--chdir", "/work",
            "--clearenv", "--setenv", "PATH", os.environ["STRATA_BUILD_PATH"],
            "--setenv", "HOME", "/tmp", "--setenv", "TMPDIR", "/tmp", *command]
    # Regular files let RLIMIT_FSIZE bound output, including noisy generated code.
    with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
        try:
            result = subprocess.run(args, stdout=stdout, stderr=stderr, timeout=45,
                                    preexec_fn=limits)
        except subprocess.TimeoutExpired:
            return {"returncode": -1, "stderr": "45-second sandbox timeout"}
        logs = {}
        for name, stream in (("stdout", stdout), ("stderr", stderr)):
            size = stream.seek(0, 2)
            stream.seek(max(0, size - 8000))
            logs[name] = stream.read().decode(errors="replace")
        return {"returncode": result.returncode, **logs}


def check_code(code, tests):
    with tempfile.TemporaryDirectory(prefix="strata-compare-") as temporary:
        directory = Path(temporary)
        (directory / "candidate.cpp").write_text(PRELUDE + code + tests)
        compiled = sandbox(directory, [os.environ["STRATA_CXX"], "-std=c++17", "-O1",
                                      "-Wall", "-Wextra", "-fsanitize=undefined",
                                      "-fno-sanitize-recover=all", "candidate.cpp", "-o", "test"])
        executed = sandbox(directory, ["/work/test"]) if compiled["returncode"] == 0 else None
        return {"compile": compiled, "test": executed,
                "passed": executed is not None and executed["returncode"] == 0}


def request(base, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(base.rstrip("/") + "/chat/completions", data,
                                 {"Content-Type": "application/json"})
    start = time.monotonic()
    with urllib.request.urlopen(req, timeout=1800) as response:
        result = json.load(response)
    return result, round(time.monotonic() - start, 3)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8080/v1")
    parser.add_argument("--label", required=True, choices=["normal", "abliterated"])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    # Refuse to mislabel a run if the other service is still selected.
    with urllib.request.urlopen(args.base_url.rstrip("/") + "/models", timeout=30) as response:
        advertised = {item["id"] for item in json.load(response)["data"]}
    model = "qwen3.8-flash-next-" + args.label
    if model not in advertised:
        parser.error(f"expected {model}; endpoint advertises {sorted(advertised)}")
    args.output.mkdir(parents=True, exist_ok=True)
    destination = args.output / (args.label + ".json")
    if destination.exists():
        parser.error(f"refusing to overwrite {destination}; choose a new output directory")
    report = {"model": model, "suite": 1, "results": {}}
    common = {"model": model, "temperature": 0, "seed": 42, "max_tokens": 4096,
              "chat_template_kwargs": {"enable_thinking": False}}
    for name, case in CASES.items():
        payload = {**common, "messages": [{"role": "user", "content": case["prompt"]}]}
        response, elapsed = request(args.base_url, payload)
        content = response["choices"][0]["message"].get("content") or ""
        blocks = re.findall(r"```(?:cpp|c\+\+)?\s*\n(.*?)```", content, re.DOTALL)
        result = check_code(blocks[0], case["tests"]) if len(blocks) == 1 else {
            "passed": False, "error": "expected exactly one C++ code fence"}
        report["results"][name] = {"request": payload, "response": response,
                                    "seconds": elapsed, **result}
        destination.write_text(json.dumps(report, indent=2) + "\n")
        print(f"{args.label}: {name}: {'PASS' if result['passed'] else 'FAIL'} ({elapsed}s)", flush=True)
    payload = {**common, "messages": [{"role": "user", "content":
                "Read src/auth.cpp with read_file before reviewing its authentication checks."}],
               "tools": [{"type": "function", "function": {"name": "read_file",
                   "description": "Read a repository source file", "parameters": {
                       "type": "object", "properties": {"path": {"type": "string"}},
                       "required": ["path"], "additionalProperties": False}}}],
               "tool_choice": {"type": "function", "function": {"name": "read_file"}}}
    response, elapsed = request(args.base_url, payload)
    calls = response["choices"][0]["message"].get("tool_calls") or []
    try:
        passed = (len(calls) == 1 and calls[0]["function"]["name"] == "read_file"
                  and json.loads(calls[0]["function"]["arguments"]) == {"path": "src/auth.cpp"})
    except (KeyError, ValueError, TypeError):
        passed = False
    report["results"]["tool_call"] = {"request": payload, "response": response,
                                       "seconds": elapsed, "passed": passed}
    destination.write_text(json.dumps(report, indent=2) + "\n")
    print(f"{args.label}: tool_call: {'PASS' if passed else 'FAIL'}; saved {destination}")


if __name__ == "__main__":
    main()
