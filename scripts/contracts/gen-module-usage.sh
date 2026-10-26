#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# gen-module-usage.sh — the per-module part of docs/autoflow-guide.md (epic #507)
# =============================================================================
# docs/autoflow-guide.md says how each module is run and how one module's output
# becomes another's input. Between its BEGIN and END marker lines, under
# "## Modules", one section per module — its kind, goal, procedure, params,
# inputs with where each comes from, outputs, and an invocation skeleton — is
# generated from the contracts, docs/contracts/<module>.json, so the guide and
# the contracts change together; the rest of the guide is written by hand.
#
#   gen-module-usage.sh            write the per-module part
#   gen-module-usage.sh --check    exit 0 when the committed document equals the
#                                  generator's output, 1 otherwise
# =============================================================================

set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/autoflow-guide.md"
BEGIN='<!-- BEGIN generated from docs/contracts/*.json by scripts/contracts/gen-module-usage.sh — edit the contracts, then regenerate. -->'
END='<!-- END generated -->'
ORDER="criterion-screen criterion-trace criterion-in-depth criterion-reconcile analysis criteria-apply hypothesis design plan build audit quality delivery review"

case "${1:-}" in "" | --check) ;; *) echo "usage: gen-module-usage.sh [--check]" >&2; exit 2 ;; esac
[ -f "$DOC" ] || { echo "gen-module-usage: $DOC not found" >&2; exit 2; }
for f in "$ROOT"/docs/contracts/*.json; do
  m=$(basename "$f" .json)
  case " $ORDER " in *" $m "*) ;; *) echo "gen-module-usage: docs/contracts/$m.json is not in ORDER" >&2; exit 2 ;; esac
done
grep -qxF "$BEGIN" "$DOC" && grep -qxF "$END" "$DOC" || { echo "gen-module-usage: $DOC has no BEGIN or END marker line" >&2; exit 2; }

section() { # <contract file>
  jq -r '
    def src: if type == "array" then map(src) | join(", or ")
      elif has("module") then "`\(.module)` → `\(.output)`"
      elif has("ledger") then "the ledger: " + (.ledger | map("`[\(.)]`") | join(", ")) + " entries"
      elif has("path") then (if .path == "target" then "a document of the target" else "a file the invocation gives" end)
      elif has("results") then "the `tool-requests.json` of earlier runs"
      else "?" end;
    def ptype: if .pattern then "`\(.pattern)`" elif .type then .type else "" end;
    "### `\(.module)`",
    "",
    "- Kind: \(.kind)" + (if .reads_records then "; given the record directory (`records`)" else "; given its declared inputs only" end),
    "- Goal: \(.goal | sub("\\s+$"; ""))",
    "- Procedure: `<autoflow-root>/\(.procedure)`",
    "",
    "| Param | Required | Form |",
    "|---|---|---|",
    (.params // {} | to_entries[] | "| `\(.key)` | \(if .value.required then "yes" else "no" end) | \(.value | ptype) |"),
    "",
    "| Input | Required | From |",
    "|---|---|---|",
    (.inputs // {} | if length == 0 then "| — | | |" else to_entries[] | "| `\(.key)` | \(if .value.required then "yes" else "no" end) | \(.value.from | src) |" end),
    "",
    "| Output | File |",
    "|---|---|",
    (.outputs | to_entries[] | "| `\(.key)` | \(if .value.file then "`<out>/\(.value.file)`" else .value.format end) |"),
    "",
    "```json",
    ({contract: 1, module: .module,
      params: (.params // {} | with_entries(select(.value.required)) | map_values("<\(.type // "value")>")),
      inputs: (.inputs // {} | with_entries(select(.value.required)) | map_values("<path>"))}
     + (if .reads_records then {records: "<record directory>"} else {} end)
     + {out: "<record directory>/\(.module)-<n>"} | tojson),
    "```",
    ""' "$1"
}

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
{
  awk -v m="$BEGIN" '{ print } $0 == m { exit }' "$DOC"
  echo
  for m in $ORDER; do section "$ROOT/docs/contracts/$m.json"; done
  awk -v m="$END" 'f { print } $0 == m { f = 1; print }' "$DOC"
} > "$TMP"

if [ "${1:-}" = --check ]; then
  cmp -s "$TMP" "$DOC" && exit 0
  echo "gen-module-usage: docs/autoflow-guide.md differs from the generator's output — run: bash scripts/contracts/gen-module-usage.sh" >&2
  exit 1
fi
cp "$TMP" "$DOC"
