# jq: commands from the episode

Copy the [authored report](runs.json) into a demo directory as
`runs.json`. Verified with jq 1.8.2. These commands assume a Unix shell and
single-quote the jq program so the shell passes it intact.

```sh
jq --version
jq '.' runs.json
jq '.machine' runs.json
jq '.runs[0]' runs.json
jq '.runs[0].name' runs.json
jq '.runs[] | .name' runs.json
jq -r '.runs[] | .name' runs.json
jq '.runs[] | {name, status}' runs.json
jq '.runs[] | select(.status == "failed")' runs.json
jq -r '.runs[] | select(.status == "failed") | .name' runs.json
jq '[.runs[] | select(.status == "failed")] | length' runs.json
jq '[.runs[] | select(.status == "failed")] | sort_by(.durationSeconds) | reverse | .[] | {name, durationSeconds}' runs.json
jq '.runs | length' runs.json
jq '.runs | map(.files) | add' runs.json
jq -c '.runs[] | {name, status}' runs.json
jq '[.runs[] | select(.status == "failed")] | sort_by(.durationSeconds) | reverse' runs.json > failed-runs.json
jq '.runs[] | {name, retry, hasRetry: has("retry")}' runs.json
jq -r '.runs[] | (.retry // "not set")' runs.json
jq -r --arg wanted failed '.runs[] | select(.status == $wanted) | .name' runs.json
jq -r --arg wanted ok '.runs[] | select(.status == $wanted) | .name' runs.json
jq -e '.runs | all(.status == "ok")' runs.json
man jq
# In less: /raw-output, n, q.
```

The failed names are `nightly-photos` and `archive`; durations are 72 and
240 seconds. The four reported file counts sum to 870. `//` also uses the
fallback for false: all four retry results above become `not set`.
`has("retry")` distinguishes an absent key from a present null.

`-r` writes string results as plain text; `-c` prints compact JSON. A stream
of values and one JSON array are different output shapes. `--arg` creates
a string variable. With `-e`, one final boolean false exits 1, true exits 0;
no result exits 4. Parse/runtime errors are separate outcomes.
Immediately after the command, `echo $status` shows its exit status in Fish,
the shell used in this episode. In Bash, use `echo $?`.

Never redirect into the input filename; the shell can truncate it first.
Use a fresh output name for each retained report. See the
[official tutorial](https://jqlang.org/tutorial/) and
[version 1.8 manual](https://jqlang.org/manual/v1.8/).

See the [explained cheatsheet](../jq.md) for output shapes, expected results and edge cases.
