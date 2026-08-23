# C7 pilot probe fixture — ground truth

Sibling to `tests/fixtures/c7-pilot/` (Issue #74, RED stage 1). Deliberately
kept **outside** the fixture directory a pilot arm is handed
(`tests/fixtures/c7-pilot/`): an arm's own contract obliges it to enumerate
from the tree it is handed, so an in-tree ground-truth file would sit on the
arm's own prescribed enumeration path and the pilot would silently measure
nothing. Exclusion is a property of the layout, not of prompt wording — see
`.autoflow/issue-74-feature-design.md` §3.

Every condition below is deliberate. A later reader must not "fix" the
planted branch or the diverging double — that is the fixture's whole
purpose.

## Step 3 — minimal-implementation / coverage check

| Condition | Fixture location | Sentinel | Expected step-3 answer |
|---|---|---|---|
| `step3-planted` | `probe-cli` branch `planted` | `PROBE_S3_PLANTED` — invoked by `probe-suite` but never appears as an argument on a line invoking `probe_assert` | `detected` |
| `step3-clean` | `probe-cli` branch `covered` | `PROBE_S3_COVERED` — invoked by `probe-suite` and appears as an argument on the `probe_assert "PROBE_S3_COVERED" "$covered_output"` line | `clean` |

"Covered" is defined solely as: the branch's sentinel token appears as an
argument on a line invoking `probe_assert`. `probe-suite` invokes both
`probe-cli` branches (exercising each), but only pipes the `covered` output
through `probe_assert`; the `planted` output is only echoed, so its sentinel
never sits on a `probe_assert` line. Invocation and assertion are therefore
distinguishable by text search alone, without any coverage instrumentation.

## Step 4 — mock-boundary fidelity check

| Double | Real interface | Divergent dimension | Expected step-4 answer |
|---|---|---|---|
| `mock-real-tool/real-tool` | `real-tool` | error path / exit status: `real-tool` prints `ERROR: unknown op` to stderr and exits `2` on an unrecognized op; the double silently exits `0` instead. Argv shape (dispatch on `$1`) is held **matching** | `detected` |
| `mock-real-tool-b/real-tool-b` | `real-tool-b` | none — matches in all four dimensions (signature, argument count, return shape, error path) | `clean` |

The `mock-real-tool/real-tool` divergence is confined to exactly one
dimension (error path / exit status) so that an arm can only reach
`detected` by actually re-deriving the error-path contract — not by
tripping over an argv-dispatch failure, which the fixture deliberately does
not introduce. This is the pattern the repository's own
`tests/issue-25/mock-gh/gh` shim follows (dispatch on `ARGS="$*"`).

## Not part of the ground truth

`probe-diff.patch` is the implementation diff the step-3 check analyses —
the hunk that introduced `probe-cli`'s `planted` branch — in `git diff`
form. It is never applied; it is inert text the fixture carries so the
step-3 check has a diff to read.
