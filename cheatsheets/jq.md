# jq cheatsheet

jq reads JSON, applies a filter and writes the results. Use it to inspect a
response, choose records by their fields or construct a smaller report.

These examples use the prepared four-job [runs.json](jq-example/runs.json) from
**jq: Turn a JSON report into an answer**. Save it as `runs.json` in a fresh
directory. The [episode command list](jq-example/commands.md) is beside it.
Commands assume a Unix shell and were checked with jq 1.8.2.

```sh
jq --version
jq '.' runs.json
```

The quoted argument is the jq filter. Single quotes keep the shell from
interpreting its pipes, dollar signs and other syntax.

## Read a path

`.` means the current input. Field paths follow the structure of that value.

| Filter | Result in this example |
| --- | --- |
| `.` | The whole report |
| `.machine` | `"workshop"` |
| `.runs` | One array containing four job objects |
| `.runs[0]` | The first job object; array positions start at zero |
| `.runs[0].name` | `"nightly-photos"` |
| `.runs[]` | Four separate job objects |

```sh
jq '.runs[0].name' runs.json
jq '.runs[] | .name' runs.json
jq -r '.runs[] | .name' runs.json
```

Inside the quotes, `|` sends each result to the next jq filter. After
`.runs[]`, `.name` reads the name of each job. A pipe outside the quotes would
connect shell commands instead.

`-r` writes string results as plain text without JSON quotes. Objects and
arrays still use JSON. `-c` writes compact JSON, one line per result.

## Select records and choose fields

```sh
jq '.runs[] | select(.status == "failed")' runs.json
jq -r '.runs[] | select(.status == "failed") | .name' runs.json
jq '.runs[] | {name, status}' runs.json
```

`select` keeps a value when its condition is true; `==` compares values.
The failed-name query prints:

```text
nightly-photos
archive
```

Compare the `status` field directly. The successful `documents` job has the
message `"No failed transfers"`, so finding the word `failed` in the text would
answer a different question.

`{name, status}` constructs a new object. It is shorthand for
`{name: .name, status: .status}`.

## Source, stream and array

The source file contains one report object. Filters produce results without
editing that source file.

```sh
# A stream: two separate job objects.
jq '.runs[] | select(.status == "failed")' runs.json

# An array: one value containing those two objects.
jq '[.runs[] | select(.status == "failed")]' runs.json

# Count the collected jobs: 2.
jq '[.runs[] | select(.status == "failed")] | length' runs.json

# Count characters in each failed name instead: 14, then 7.
jq '.runs[] | select(.status == "failed") | .name | length' runs.json
```

`[]` around an expression collects its results. `.[]` after an array emits
its elements separately. A sequence of JSON objects is not itself a JSON array.
`length` counts array elements or string Unicode codepoints, according to the
value it receives.

## Sort and summarize

```sh
# Longest failed run first, with only the fields needed here.
jq '[.runs[] | select(.status == "failed")] | sort_by(.durationSeconds) | reverse | .[] | {name, durationSeconds}' runs.json

# Four runs.
jq '.runs | length' runs.json

# [120, 42, 700, 8], then their sum: 870.
jq '.runs | map(.files)' runs.json
jq '.runs | map(.files) | add' runs.json

# Four compact JSON objects, one per line.
jq -c '.runs[] | {name, status}' runs.json
```

`sort_by` orders an array in ascending order; `reverse` reverses it. The result
here is `archive` at 240 seconds, then `nightly-photos` at 72. These durations
are JSON numbers. Text such as `"72"` is a different type and sorts differently.

`map(.files)` builds an array of the reported counts. `add` sums these numbers;
it returns `null` for an empty array. If an empty numeric collection should
total zero, use `(.runs | map(.files) | add) // 0`.
The total is reported file counts, not unique files: a file counted by two
jobs contributes twice.

## Null, false and an absent field

```sh
jq '.runs[] | {name, retry, hasRetry: has("retry")}' runs.json
```

| Job | `.retry` | `has("retry")` |
| --- | --- | --- |
| `nightly-photos` | `null` | `true` |
| `documents` | `false` | `true` |
| `archive` | `null` | `false` |
| `notes` | `false` | `true` |

Reading an absent object field produces `null`. `has("retry")` tells you
whether that key was present, including when its value was explicitly null.

```sh
jq -r '.runs[] | (.retry // "not set")' runs.json
```

All four results are `not set`: `//` falls back for both `null` and `false`
in this expression. It also falls back when its left side produces no results.
Keep the original value or use `has` when false carries useful information.

To default only an absent key while preserving explicit null and false:

```sh
jq '.runs[] | if has("retry") then .retry else "not set" end' runs.json
```

## Pass a value safely

```sh
jq -r --arg wanted failed '.runs[] | select(.status == $wanted) | .name' runs.json
jq -r --arg wanted ok '.runs[] | select(.status == $wanted) | .name' runs.json
```

`--arg wanted failed` supplies the string `"failed"` as `$wanted`. The second
command prints `documents` and `notes`. Keep the filter quoted and pass values
separately; do not construct jq code by inserting the chosen text into it.
`--arg` always creates a string, even when its argument contains only digits.

## Use an exit status in a script

```sh
# Prints false; exits 1 for this report.
jq -e '.runs | all(.status == "ok")' runs.json

# Produces no result; exits 4.
jq -e '.runs[] | select(.status == "running")' runs.json
```

With `-e`, successful filter evaluation uses the **last output value**:

| Exit status | Result |
| --- | --- |
| `0` | Last output is anything except `false` or `null`, including `0`, `""` or `[]` |
| `1` | Last output is `false` or `null` |
| `4` | No result was produced |

Usage, compile, input and runtime errors also return nonzero; read stderr.
Without `-e`, a normally completed command does not tell you that the jobs
succeeded. For a condition, prefer a filter that produces one boolean.
`all` on an empty array is true, so check the count too if an empty run list
should fail the check.

Immediately after jq, inspect the status with `echo $?` in Bash or
`echo $status` in Fish, the shell shown in the episode.

## Save a report

Choose a fresh output filename. The shell opens `>` before jq reads the input;
using the input filename as the output can truncate the source.

```sh
jq '[.runs[] | select(.status == "failed")] | sort_by(.durationSeconds) | reverse' runs.json > failed-runs.json
jq '.' failed-runs.json
```

`failed-runs.json` contains one array, ordered `archive`, then `nightly-photos`.
Keep `runs.json` for the next question.

## References

- [jq project and downloads](https://jqlang.org/)
- [Official tutorial](https://jqlang.org/tutorial/)
- [jq 1.8 manual](https://jqlang.org/manual/v1.8/)
- Installed reference: `man jq`; in less, search with `/raw-output`, then `n`, and leave with `q`.
- [Prepared example JSON](jq-example/runs.json) and [all episode commands](jq-example/commands.md)

Try changing `archive` from `"failed"` to `"ok"`, then run the failed-name query
again. Which name disappears?
