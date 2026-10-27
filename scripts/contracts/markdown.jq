# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# markdown.jq — the markdown model the contract scripts read (issue #509): a
# file's lines outside code fences, its level-2 sections (a "## Delta — round
# <n>" section flagged as a delta), and its tables (header cells, rows, the
# section each sits under). Used by contract.sh and criteria-apply.sh.
def cells: sub("^\\s*\\|"; "") | sub("\\|\\s*$"; "")
  | [splits("(?<!\\\\)\\|")] | map(gsub("^\\s+|\\s+$"; ""));
def norm: gsub("`"; "") | gsub("^\\s+|\\s+$"; "");
def model:
  split("\n") as $L
  | reduce range(0; $L | length) as $i (
      {fence: false, sec: null, delta: false, lines: [], sections: [], tables: [], intable: false};
      ($L[$i]) as $l
      | if ($l | test("^\\s*(```|~~~)")) then .fence = (.fence | not) | .intable = false
        elif .fence then .
        elif ($l | test("^## ")) then
          ($l | sub("^## +"; "") | sub("\\s+$"; "")) as $h
          | .sec = $h | .delta = ($h | test("^Delta — round"))
          | .sections += [{heading: $h, delta: .delta, body: []}] | .intable = false
        else
          .lines += [$l]
          | (if (.sections | length) > 0 then .sections[-1].body += [$l] else . end)
          | if ($l | test("^\\s*\\|")) then
              if .intable then
                if (.tables[-1].sep | not) and ($l | test("^\\s*\\|?\\s*:?-+")) then .tables[-1].sep = true
                else .tables[-1].rows += [$l | cells | map(norm)] end
              else .intable = true
                | .tables += [{under: .sec, delta: .delta, header: ($l | cells | map(norm)), sep: false, rows: []}]
              end
            else .intable = false end
        end)
  | {lines, sections, tables: [.tables[] | select(.sep)]};
# the first table matching a check's first / header / under / outside_delta
def pick($c):
  [.tables[]
   | select(($c.first == null) or (.header[0] == $c.first))
   | select(($c.header == null) or (.header == $c.header))
   | select(($c.under == null) or (.under == $c.under))
   | select((($c.outside_delta // false) | not) or (.delta | not))] | first;
