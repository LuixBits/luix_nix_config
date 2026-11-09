# Initial comparison — 3 November 2026

Both checkpoints passed this small functional suite on the RX 7900 XTX. There
is no quality winner from these results. Their solutions are very similar:
both check the packet length before allocation, widen frame-size arithmetic,
and reject invalid transfers before modifying either balance. Both parser
answers include an unnecessary `<cstring>` header.

| Check | Normal | Abliterated |
| --- | --- | --- |
| C++17 packet parser, malformed and partial frames | Pass | Pass |
| C++17 currency transfer, boundary values and alias rejection | Pass | Pass |
| Structured `read_file` tool call with the requested path | Pass | Pass |

Raw prompts, responses, compiler diagnostics, and outcomes are in
[normal.json](normal.json) and [abliterated.json](abliterated.json).

Both runs used the pinned models in `../../models.nix`, Strata 0.2.10 / engine
0.1.56, IQ3_XXS weights, 32K context, int8 KV, 15 CPU workers, a 3072 MiB VRAM
reserve, and the same static expert profile. MTP and prompt-lookup drafting
were disabled. Requests used temperature 0, seed 42, thinking disabled, and a
4096-token output limit. Each model ran alone through a temporary localhost
API using the Nix-generated profile with only its working/log paths changed.
Generated code compiled with GCC 15.3.0 and undefined-behavior sanitization,
then ran in the network-isolated Bubblewrap sandbox.

Do not compare the recorded wall times as model speed scores. The first normal
request included a cold load and overlapped Nix verification of the abliterated
weights; its decode paused during that work. The first abliterated request also
included a cold load. No controlled throughput benchmark was performed.

These results establish basic runtime, code-generation, and tool-call behavior.
They do not measure repository-scale coding, autonomous task completion,
security-review accuracy, or refusal behavior. No Flyff source or live service
was modified. Both temporary inference processes were stopped after testing.
