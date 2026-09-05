# Reviewer Backend Contract

HANDOFF step 6 (external review) runs through a **backend-neutral reviewer
contract**. `codex` is the default backend; `claude` is an opt-in fallback. This
document is the single home for the abstraction — the inputs, obligations,
output, backend table, config location, and the per-backend start-confirmation
oracle. It is referenced from [`autoflow-guide.md`](autoflow-guide.md) HANDOFF
step 6, [`design-rationale.md`](design-rationale.md) Decision 9, and `CLAUDE.md`.

## Contract

```
Contract: reviewer-backend
  Inputs : --pr <N>  [--repo <owner/name>]  [--expected-head <branch>]
  Obligations (in an ISOLATED session, no orchestrator/implementer context):
    1. Fetch the PR diff + metadata via `gh` (every gh call carries --repo when
       the backend runs outside the repo working dir).
    2. Review the diff per the shared instruction body (.codex/review.md):
       Korean, severity-ranked, verified findings, one high-signal overview.
    3. Post the review as a PR comment (`gh pr comment`) — the comment is the
       artifact, not the subprocess stdout.
    4. The gate-label obligation is DIRECTIONAL (per .codex/review.md):
       - clean state (no confirmed Critical/High/Medium) ⇒ REMOVE
         `blocked-by-review` (gh pr edit → gh issue edit fallback → verify);
       - a confirmed Critical/High/Medium finding while the label is absent
         ⇒ attach `blocked-by-review` (gh pr edit → gh issue edit fallback →
         verify present);
       - any other state ⇒ leave the label unchanged.
       A review only ever performs one of these three actions.
  Authority: the configured isolated reviewer subprocess is the SOLE clearer of
             `blocked-by-review`. The orchestrator is hook-denied (Decision 9).
  Output   : the posted PR comment + label state. NOT the subprocess stdout.
```

## Backends

| Backend | Default | Runtime |
|---------|---------|---------|
| `codex` | yes | `codex exec` in the repo working dir; loads `AGENTS.md` → `.codex/review.md` automatically. |
| `claude` | opt-in | `claude -p` in a **neutral cwd** with the parent session's **`CLAUDE*` env scrubbed** and **`--setting-sources ""`** (no user-scope plugin hooks), `--system-prompt-file .codex/review.md`, `--repo` on every `gh` call, tool-sealed to `Bash(gh *)`, `ANTHROPIC_API_KEY` unset. |

The single wrapper `scripts/review/codex-review-pr.sh` implements both branches;
the CLI signature is unchanged across backends (the backend is not a flag).
Either backend additionally receives the configured **model / effort** flags
from the shared resolver (see *Model and effort* below), or none when
inheriting.

## Config location

The backend is recorded in the target-owned scaffold
`.claude/autoflow.local.json`:

```json
{ "review": { "backend": "codex" } }
```

Read via `jq -r '.review.backend // "codex"'`. **Absent file or absent key ⇒
`codex`** (preserves the current zero-config behavior). The scaffold is
delivered by `init.sh` and **never overwritten** on re-install, so a target
operator's explicit `claude` selection survives (no silent downgrade).

A **present-but-unparseable** file (invalid JSON), **a present file that cannot
be read because `jq` is not on PATH**, **or a present file whose
`.review.backend` is empty (`""`) or otherwise not `codex`/`claude`**, does
**not** default to `codex`: the consumers (`codex-review-pr.sh`,
`check-review-backend.sh`) fail closed (**exit 2**) and the install-time reporter
(`detect.sh`) reports `REVIEW_BACKEND=invalid` — a configured backend is never
silently downgraded by a corrupt or empty config. Only an **absent file, an
absent `.review.backend` key, or an explicit `null`** resolves to the `codex`
default. (Symmetric with `set-review-backend.sh`'s write-side
unparseable-refuse.)

## Model and effort

The reviewer's model and reasoning effort can be pinned **per backend** in the
same target-owned scaffold (issue #184). Every key is optional:

```json
{
  "review": {
    "backend": "codex",
    "codex":  { "model": "gpt-5.6-sol", "effort": "high" },
    "claude": { "model": "opus",        "effort": "high" }
  }
}
```

**Single source of truth.** `scripts/review/lib/review-config.sh` is the one
parser, validator and flag-mapper for the whole `review` section. It is
**sourced** by both the live wrapper (`codex-review-pr.sh`) and
`check-review-backend.sh` (presence path and `--probe`), and it ships to targets
as a `copy` artifact next to `claude-isolation.sh`. Neither consumer reads
`.claude/autoflow.local.json` on its own, so the probe and the live review cannot
drift on defaults or validation — the same drift class the isolation helper
closed for the `CLAUDE*` scrub.

**Flag mapping** (`build_review_backend_args`, the only place it is written):

| Backend | model | effort |
|---------|-------|--------|
| `codex` | `codex exec --model <model>` | `codex exec -c model_reasoning_effort=<effort>` |
| `claude` | `claude -p --model <model>` | `claude -p --effort <effort>` |

Values travel as a bash array, one argv element per token, so a model id or
effort string is never word-split or re-quoted by the shell.

**Precedence** (per value, most specific first):

| Value | Order |
|-------|-------|
| backend | `--backend` override (`check-review-backend.sh` only) → `.review.backend` → `codex` |
| model | `.review.<backend>.model` → `MODEL` env (**claude only** — the pre-#184 passthrough, retained for compatibility) → **inherit** |
| effort | `.review.<backend>.effort` → **inherit** |

**Inherit means no flag.** When a key is absent (or JSON `null`) the wrapper
passes nothing, and the CLI applies its own configuration exactly as before:
`~/.codex/config.toml` (`model`, `model_reasoning_effort`) for `codex`, the
claude CLI's user/default model and effort for `claude`. The scaffold delivered
by `init.sh` pins **nothing** and is never overwritten, so adding this feature
re-pins no existing install; review-only pinning is an explicit hand-edit of the
target's file.

**Supported effort values** (the vocabulary lives in `review-config.sh` and is
edited there when a CLI's set evolves — model identifiers are not validated,
since they change per vendor and release):

| Backend | Accepted `effort` | Source |
|---------|-------------------|--------|
| `codex` | `none` `minimal` `low` `medium` `high` `xhigh` `max` `ultra` `persistent` | the named variants of `enum ReasoningEffort`, `codex-rs/protocol/src/openai_models.rs` (codex-cli 0.153.4). codex accepts any other string as a `Custom` variant and does **not** reject it at launch, so this list is the only guard. |
| `claude` | `low` `medium` `high` `xhigh` `max` | `claude --help` → `--effort <level>` |

**Fail-closed** (exit `2`, diagnostic on stderr, **before any reviewer
launches** — in both the wrapper and `check-review-backend.sh`, so an invalid
pin also stops PREFLIGHT rather than surfacing mid-HANDOFF):

- the file is present but `jq` is not on PATH, or the file is not valid JSON
  (unchanged from the backend rule above);
- `.review.<backend>.model` or `.effort` is present but empty (`""`) or not a
  string;
- `.review.<backend>.effort` is a string outside that backend's vocabulary.

Only the **configured** backend's section is validated; the other backend's
section is not read. An absent key is inheritance, never an error.

**Start marker.** The wrapper's marker names the backend and the effective
explicitly configured values — `[codex-review] starting codex for PR #<N>
(model=gpt-5.6-sol effort=high) at …`, or `model=inherit effort=inherit` when
nothing is pinned — and prints nothing else from the environment (no
credentials, no unrelated variables). `--probe` prints the same summary as
`[check-review-backend] --probe: <backend> (model=… effort=…)` before its
round-trip, and passes the identical flags.

**Orchestrator vs. reviewer.** These pins govern only the **isolated reviewer
subprocess** HANDOFF step 6 launches. The orchestrating Claude Code session's
own model and effort follow the user's session settings, and the AutoFlow role
spawns follow `.claude/autoflow/spawn-policy.json`; neither reads the `review`
section, and the review pins read neither of them. A target can therefore fix
its review quality/cost policy independently of the session that runs the
cycle and of the operator's global `~/.codex/config.toml`.

## Claude isolation basis

**[MUST]** The `claude` branch enforces **three-layer isolation**: it runs in a
**neutral cwd** (excludes project-scope `.claude/settings.json`), **scrubs every
`CLAUDE`-prefixed env var** from the subprocess (blocks the parent session's
re-attach), and passes **`--setting-sources ""`** (loads no settings sources, so
**user-scope plugin hooks** are not enabled). It also passes `--repo` on every
`gh` call. All are load-bearing for Decision 9's "sole clearer" property,
**not** ergonomic choices: Decision 9 rests on the reviewer subprocess **not**
loading the AutoFlow gate hook that denies `--remove-label blocked-by-review`.
For `codex exec` this holds because it is a separate subprocess. For `claude -p`
it holds only if claude loads **none** of the settings sources that carry that
hook — and the hook reaches a claude session by three distinct paths, each
closed by one layer below.

**Layer 1 — project settings (neutral cwd).** Claude Code discovers project
settings from the **working directory** (the `--setting-sources` /
settings-discovery model: project settings are loaded from the project the cwd
sits in). Running in a neutral cwd (e.g. a fresh `mktemp -d`) omits the target's
project settings — including the gate hook.

**Layer 2 — parent-session re-attach (`CLAUDE*` env scrub). Neutral cwd alone is
insufficient when the wrapper runs from inside a Claude Code session** (the real
HANDOFF execution context). The nested `claude -p`
inherits the parent session's `CLAUDECODE` / `CLAUDE_CODE_*` env (session,
bridge, and child-session ids) and **re-attaches to the parent session's project
context**, loading that project's gate hook despite the neutral cwd — witnessed
on PR #981, where the loaded hook denied the reviewer's own
`gh pr edit --remove-label blocked-by-review` (and the `gh issue edit` fallback),
so the disposable PR could not be cleared. The fix therefore also scrubs **all**
`CLAUDE`-prefixed env vars — via a dynamic `env -u` list built from `${!CLAUDE@}`,
robust to future `CLAUDE_*` additions rather than a hardcoded name list — so the
child never re-attaches. The scrub excepts `CLAUDE_CODE_OAUTH_TOKEN` — the
documented headless-automation credential the claude backend authenticates with
— which is retained so the nested reviewer keeps its auth channel when no
`HOME`-stored OAuth login and no `ANTHROPIC_API_KEY` are present (issue #979).
`PATH` and `HOME` are preserved (claude needs `HOME` for
its OAuth credentials, `PATH` to resolve `gh`).

**Layer 3 — user-scope plugin hook (`--setting-sources ""`).** The gate hook
also ships as a **user-scope plugin** (`~/.claude/settings.json` `enabledPlugins`
`autoflow@autoflow`), whose hooks load in **every** claude session
regardless of cwd or env — so Layers 1 and 2 alone do not close it. Passing
`--setting-sources ""` (an empty value — load no settings sources) excludes the
user-scope plugin from the reviewer session. Probe evidence (INTEGRATE M-1
re-run, orchestrator probe): a neutral-cwd control `claude -p` denied
`gh pr merge --help` via `${CLAUDE_PLUGIN_ROOT}/hooks/check-autoflow-gate.sh`,
while the same probe with `--setting-sources ""` loaded no hooks and was
permitted, with `gh` and OAuth intact — witnessed on the PR #981 re-run.

`--repo` on every `gh` call is mandatory precisely because a neutral cwd cannot
resolve the repo from `.`.

Because no in-suite test can prove claude's settings-loading behavior, VALIDATE
carries a **[MUST]** live-manual gate: a real `claude -p` reviewer, run
neutral-cwd **with the `CLAUDE*` env scrubbed and `--setting-sources ""`**
against a clean disposable PR, must actually clear `blocked-by-review` (proving
neither the project nor the user-scope-plugin gate hook denied `--remove-label`)
and retain it on a seeded Medium+ finding.

## Availability (PREFLIGHT, fail-closed)

`scripts/preflight/check-review-backend.sh [--backend codex|claude]` resolves
the `review` section through the shared resolver (so an invalid model/effort
pin fails closed here too — *Model and effort* above) and probes the
configured backend's CLI **presence only** (`command -v`), exiting non-zero
with a reason when absent. PREFLIGHT wires it as a drift-check-style **stop
condition**: the cycle does not begin until the CLI is installed or the backend
is switched. Symmetrically, the live wrapper `scripts/review/codex-review-pr.sh`
also fail-closes on an **unknown** `.review.backend` value (any non-empty string
other than `codex`/`claude`): it exits `2` with a stderr diagnostic before
invoking any reviewer, matching this pre-check's own `exit 2` so both entrypoints
enforce the same contract on the same value. On this **presence-only** PREFLIGHT
path, auth is **not** probed — a side-effect-free command whose exit encodes
auth state does not exist, so a present-but-unauthenticated backend passes
PREFLIGHT and its auth failure surfaces at HANDOFF step 6 (the review run
itself). An explicit, on-demand authenticated round-trip is available separately
via `--probe` (next section) and is never wired into this PREFLIGHT path.

## On-demand auth probe (`--probe`)

`scripts/preflight/check-review-backend.sh --probe` is a **separate on-demand
mode** (issue #979): it performs **one real authenticated round-trip** against
the configured backend — not a `command -v` presence check and not a version
check — over the **identical auth channel and isolation** HANDOFF step 6 uses
(for `claude`: the same neutral cwd + `CLAUDE*` env scrub + OAuth carve-out +
`--setting-sources ""` isolation triple, sourced from the shared
`scripts/review/lib/claude-isolation.sh`; for `codex`: the same model-API
connection a `codex exec` opens). Because the probe exercises the same channel,
a green probe predicts a green step 6.

**Triggers — on-demand only, at two moments:**

- **install time** — `/autoflow:install` auto-runs the probe (advisory) right
  after it persists the backend selection.
- **backend-change time** — `set-review-backend.sh` prints a reminder to run
  the probe after a successful switch; the operator runs it on-demand.

It is **not** run per-cycle, is **not** wired into PREFLIGHT, and **no hook
consumes it** — the exit code is for the install skill's advisory narration and
the operator's manual backend-change run only. A probe failure is advisory: it
is narrated, never used to abort an install or gate a cycle.

**Exit-code contract** (extends the presence `0/1/2`):

| Exit | Meaning |
|------|---------|
| `0` | Round-trip succeeded — backend authenticated & responsive. |
| `1` | Backend CLI **absent** — short-circuit that reuses the presence exit 1 + remedy (no round-trip is attempted). |
| `2` | Usage/config error (bad arg, unknown/unresolvable backend, jq-absent/parse). |
| `3` | **Indeterminate** — the probe could not reach a verdict (timeout / no-TTY interactive-login required). Bounded by `PROBE_TIMEOUT_SECS` (default 20s). |
| `4` | Backend CLI **present but the round-trip failed** (unauthenticated / rejected) — the condition that surfaces at step 6. Distinct from `1`=absent so a caller can tell presence-absent from auth-failed. |

## Per-backend start-confirmation oracle

- `codex` — a fresh `~/.codex/sessions/<date>/rollout-*.jsonl` +
  `pgrep -f "pull request #<N>"` + an advancing rollout `mtime` (the long-run
  health signal); the review runs in the background to completion. The wrapper
  closes `codex exec` stdin (`< /dev/null`) so an inherited parent stdin cannot
  hold the review open, and prints completion marker
  `[review] codex completed for PR #<N> (exit=…)` when the subprocess returns.
- `claude` — the wrapper runs `claude -p` **synchronously** and prints a
  completion marker `[review] claude completed for PR #<N> (exit=…)` when the
  subprocess returns. That marker is the start/finish signal; a non-zero exit
  means the review run itself failed.

## Trade-offs

- **Vendor independence.** The `claude` backend loses cross-vendor blind-spot
  coverage (this repo's own record shows cross-vendor review catching Medium+
  findings internal gates missed). `codex` remains the default for that reason;
  switching to `claude` is an explicit, disclosed opt-in.
- **Account allowance.** The `claude` backend consumes the same account
  allowance as the orchestrator, so a long cycle's terminal review may hit a
  session limit. It uses `CLAUDE_CODE_OAUTH_TOKEN` (automation) or a logged-in
  subscription; it must **not** inherit `ANTHROPIC_API_KEY` (the wrapper unsets
  it to avoid metered-API billing).
