# Issue #952 — Manual (Tier-3) Verification Scenarios

Per verification design (`.autoflow/issue-952-verification-design.md` §1, T3):
human read of the rendered `setup/SETUP-GUIDE.md` plus an eyeball of the
no-arg run. Run at VALIDATE's manual checklist.

## M1 — No-arg `init.sh` usage message reads clearly

1. In a throwaway directory, run `bash setup/init.sh` with no arguments and
   observe stdout/stderr.
2. Confirm the printed message:
   - clearly states `--target <path>` is required,
   - does NOT print the old wizard banner ("Setup Wizard", "Project
     Configuration", "Project name:"),
   - points at `setup/SETUP-GUIDE.md` for further detail.
3. Confirm the process exits immediately (does not block waiting on a
   `read`).

## M2 — `setup/SETUP-GUIDE.md` reads coherently after the legacy-section deletion

1. Read `setup/SETUP-GUIDE.md` top to bottom.
2. Confirm the top note states install-into-TARGET is the only supported
   model (no residual "Legacy in-place (Steps 1-9)" framing).
3. Confirm `## Prerequisites` still reads sensibly on its own (no dangling
   reference to a removed step).
4. Confirm no instruction remaining in the document tells the reader to copy
   a `*.template` file — every remaining `cp`/copy instruction targets a file
   that actually exists in the tree.

## M3 — `README.md` Quick Start / Post-Setup Checklist read coherently

1. Read `README.md`'s Quick Start and Post-Setup Checklist sections.
2. Confirm no step references the removed `### Placeholders` table or the
   "Legacy in-place setup (reference only)" trailer.
3. Confirm the `{{REPO_*}}`/`{{GITHUB_ORG}}` identifier-placeholder bullet
   (around README:12) and the Mermaid flow diagram's `{{GATE:...}}`/
   `{{AUDIT}}` rhombus nodes still read naturally in context (they are
   preserved, not leftover residue).

## M4 — `CLAUDE.md` delivered copy reads coherently without the Language Rule

1. Read the top of `CLAUDE.md` (through `## What This Repo Is`).
2. Confirm the flow from the repo intro straight into "What This Repo Is" is
   natural (no doubled blank line, no dangling reference to a "Language
   Rule" section elsewhere in the file).
3. Confirm the "Identifier placeholders" history bullet (around `CLAUDE.md:14`)
   reads as a description of the notation convention, not as a claim that
   `setup/init.sh` performs a live substitution.
