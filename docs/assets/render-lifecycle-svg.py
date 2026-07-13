#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
"""Render the README lifecycle diagram as themed SVGs.

Single source for both README diagram variants:

    python3 docs/assets/render-lifecycle-svg.py

writes ``autoflow-lifecycle-light.svg`` and ``autoflow-lifecycle-dark.svg``
next to this script. The README embeds them via a ``<picture>`` element so
GitHub serves the variant matching the viewer's color scheme. The Mermaid
text source stays in the README (collapsed) as the greppable fallback the
issue-952 G4 preservation guards assert on.

Beyond the happy path, the diagram encodes the design decisions of
``docs/design-rationale.md``:

- D1  DIAGNOSE structure analysis is issue-isolated (node subtitle)
- D2  every gate is a fresh-spawned Evaluation AI (gate subtitles, legend)
- D3  the hook computes PASS from raw scores (legend)
- D6  structure FAIL = no code change -> stop/close (dashed STOP node)
- D7  every FAIL loop is bounded, cap -> human escalation (dashed red
      return edges with their caps from CLAUDE.md > Regressions)
- D8  deliberation runs in isolated sub-contexts (isolation glyph)
- D9  HANDOFF review auto-resolution re-enters RED, bounded at 7 (top bus)
"""

from pathlib import Path

# ---------------------------------------------------------------- content

# (badge, stage-name, [(phase, subtitle, kind, isolated)]) — the ``isolated``
# flag marks phases that run in an isolated sub-context / fresh spawn (D8).
STAGES = [
    ("01", "ANALYSIS", [
        ("PREFLIGHT", "git clean · prior-cycle check", "start", False),
        ("DIAGNOSE", "3-phase · issue-isolated", "phase", True),
        ("GATE:HYPOTHESIS", "fresh eval · bug only", "gate", False),
    ]),
    ("02", "PLANNING", [
        ("ARCHITECT", "dev + test deliberation", "phase", True),
        ("GATE:PLAN", "fresh eval AI · 5×10", "gate", False),
        ("DISPATCH", "fresh test/dev spawn", "phase", False),
    ]),
    ("03", "TDD", [
        ("RED", "test AI · failing first", "red", False),
        ("GREEN", "developer AI · min code", "green", False),
        ("VERIFY", "cause-branch check", "phase", True),
        ("REFINE", "fresh respawn", "phase", True),
    ]),
    ("04", "QUALITY", [
        ("VALIDATE", "auto + manual + docs", "phase", False),
        ("AUDIT", "independent eval AI", "gate", False),
        ("GATE:QUALITY", "fresh eval AI · 10×10", "gate", False),
    ]),
    ("05", "DELIVERY", [
        ("DELIVER", "branch push · shutdown", "phase", False),
        ("INTEGRATE", "build · health · e2e", "phase", False),
        ("HANDOFF", "PR · CI · review triage", "end", False),
    ]),
]

# Per-phase FAIL caps rendered inside the node, bottom-right (CLAUDE.md >
# Regressions). ↩ = bounded return edge drawn dashed; ↻ = in-place fix cycle.
FAIL_CAPS = {
    "GATE:HYPOTHESIS": "↩ ≤2×",
    "GATE:PLAN": "↩ ≤3×",
    "VERIFY": "↩ ≤3×",
    "GATE:QUALITY": "↩ ≤3×",
    "AUDIT": "↻ ≤2×",
    "REFINE": "↻ ≤2×",
}

# ---------------------------------------------------------------- themes

THEMES = {
    "light": {
        "canvas": "#ffffff",
        "col_fill": "#f6f8fa", "col_stroke": "#d0d7de",
        "node_fill": "#ffffff", "node_stroke": "#d0d7de",
        "text": "#1f2328", "muted": "#59636e",
        "gate_fill": "#fff8c5", "gate_stroke": "#d4a72c", "gate_text": "#9a6700",
        "start_fill": "#ddf4ff", "start_stroke": "#54aeff", "start_text": "#0969da",
        "end_fill": "#fbefff", "end_stroke": "#c297ff", "end_text": "#8250df",
        "conn": "#8c959f",
        "fail": "#cf222e", "iso": "#1b7c83",
        "red": "#cf222e", "green": "#1a7f37",
    },
    "dark": {
        "canvas": "#0d1117",
        "col_fill": "#161b22", "col_stroke": "#30363d",
        "node_fill": "#21262d", "node_stroke": "#3d444d",
        "text": "#e6edf3", "muted": "#9198a1",
        "gate_fill": "#2a2211", "gate_stroke": "#9e6a03", "gate_text": "#e3b341",
        "start_fill": "#121d2f", "start_stroke": "#1f6feb", "start_text": "#79c0ff",
        "end_fill": "#211d33", "end_stroke": "#8957e5", "end_text": "#d2a8ff",
        "conn": "#6e7681",
        "fail": "#f85149", "iso": "#39c5cf",
        "red": "#f85149", "green": "#3fb950",
    },
}

MONO = "ui-monospace,'SF Mono','Cascadia Mono','Roboto Mono',Menlo,monospace"
SANS = "-apple-system,BlinkMacSystemFont,'Segoe UI','Noto Sans',Helvetica,Arial,sans-serif"

# ---------------------------------------------------------------- geometry

MARGIN, COL_W, COL_GAP = 20, 190, 30
PAD, NODE_H, V_GAP, LABEL_H, COL_PAD_B = 12, 46, 18, 40, 14
TOP, BUS_Y = 80, 58
NODE_W = COL_W - 2 * PAD
WIDTH = 2 * MARGIN + 5 * COL_W + 4 * COL_GAP
DASH = 'stroke-dasharray="5 4"'

def col_x(i):
    return MARGIN + i * (COL_W + COL_GAP)

def node_y(j):
    return TOP + LABEL_H + j * (NODE_H + V_GAP)

def col_h(n):
    return LABEL_H + n * NODE_H + (n - 1) * V_GAP + COL_PAD_B

MAX_H = max(col_h(len(s[2])) for s in STAGES)
LEGEND_Y = TOP + MAX_H + 28
HEIGHT = LEGEND_Y + 40

# ---------------------------------------------------------------- render

def node_colors(kind, t):
    return {
        "phase": (t["node_fill"], t["node_stroke"], t["text"]),
        "red":   (t["node_fill"], t["node_stroke"], t["text"]),
        "green": (t["node_fill"], t["node_stroke"], t["text"]),
        "gate":  (t["gate_fill"], t["gate_stroke"], t["gate_text"]),
        "start": (t["start_fill"], t["start_stroke"], t["start_text"]),
        "end":   (t["end_fill"], t["end_stroke"], t["end_text"]),
    }[kind]

def iso_glyph(x, y, t):
    """Two overlapping rounded squares — isolated sub-context marker (D8)."""
    return (
        f'<g stroke="{t["iso"]}" fill="none" stroke-width="1.3">'
        f'<rect x="{x}" y="{y + 3}" width="7" height="7" rx="1.5"/>'
        f'<rect x="{x + 3}" y="{y}" width="7" height="7" rx="1.5"/></g>'
    )

def render(theme):
    t = THEMES[theme]
    s = []
    s.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" '
        f'viewBox="0 0 {WIDTH} {HEIGHT}" role="img" '
        f'aria-label="AutoFlow 16-phase lifecycle with bounded fail loops and isolated sub-contexts">'
    )
    s.append("<!-- SPDX-FileCopyrightText: 2026 Munsik-Park -->")
    s.append("<!-- SPDX-License-Identifier: Elastic-2.0 -->")
    s.append(f"<!-- Generated by docs/assets/render-lifecycle-svg.py ({theme}) — edit the script, not this file. -->")
    s.append("<defs>")
    for mid, color in (("arr", t["conn"]), ("arrf", t["fail"])):
        s.append(
            f'<marker id="{mid}" viewBox="0 0 8 8" refX="6.5" refY="4" markerWidth="7" '
            f'markerHeight="7" orient="auto"><path d="M1,0.8 L6.6,4 L1,7.2" fill="none" '
            f'stroke="{color}" stroke-width="1.5" stroke-linecap="round" '
            f'stroke-linejoin="round"/></marker>'
        )
    s.append("</defs>")
    s.append(f'<rect width="{WIDTH}" height="{HEIGHT}" fill="{t["canvas"]}"/>')

    # header row
    s.append(
        f'<text x="{MARGIN + 2}" y="34" font-family="{SANS}" font-size="11" font-weight="700" '
        f'letter-spacing="2.2" fill="{t["muted"]}">AUTOFLOW · 16-PHASE LIFECYCLE</text>'
    )
    s.append(
        f'<text x="{WIDTH - MARGIN}" y="34" text-anchor="end" font-family="{SANS}" '
        f'font-size="11" fill="{t["muted"]}">solid → happy path · dashed → bounded fail / stop paths</text>'
    )

    origin = {}  # phase name -> (x, y) node box origin
    for i, (badge, name, phases) in enumerate(STAGES):
        x, h = col_x(i), col_h(len(phases))
        s.append(
            f'<rect x="{x}" y="{TOP}" width="{COL_W}" height="{h}" rx="12" '
            f'fill="{t["col_fill"]}" stroke="{t["col_stroke"]}"/>'
        )
        s.append(
            f'<text x="{x + PAD}" y="{TOP + 25}" font-family="{SANS}" font-size="11" '
            f'font-weight="700" letter-spacing="1.6" fill="{t["muted"]}">'
            f'<tspan opacity="0.55">{badge}</tspan>  {name}</text>'
        )
        for j, (phase, sub, kind, isolated) in enumerate(phases):
            nx, ny = x + PAD, node_y(j)
            origin[phase] = (nx, ny)
            fill, stroke, txt = node_colors(kind, t)
            s.append(
                f'<rect x="{nx}" y="{ny}" width="{NODE_W}" height="{NODE_H}" rx="8" '
                f'fill="{fill}" stroke="{stroke}" stroke-width="1.2"/>'
            )
            tx = nx + 12
            if kind == "gate":
                s.append(
                    f'<path d="M{tx + 4},{ny + 10} l4.5,4.5 l-4.5,4.5 l-4.5,-4.5 Z" '
                    f'fill="{t["gate_stroke"]}"/>'
                )
                tx += 14
            elif kind in ("red", "green"):
                s.append(f'<circle cx="{tx + 4}" cy="{ny + 14.5}" r="4" fill="{t[kind]}"/>')
                tx += 14
            s.append(
                f'<text x="{tx}" y="{ny + 19}" font-family="{MONO}" font-size="12" '
                f'font-weight="600" fill="{txt}">{phase}</text>'
            )
            s.append(
                f'<text x="{nx + 12}" y="{ny + 35}" font-family="{SANS}" font-size="10" '
                f'fill="{t["muted"]}">{sub}</text>'
            )
            if isolated:
                s.append(iso_glyph(nx + NODE_W - 20, ny + 8, t))
            if phase in FAIL_CAPS:
                s.append(
                    f'<text x="{nx + NODE_W - 8}" y="{ny + 35}" text-anchor="end" '
                    f'font-family="{SANS}" font-size="9" fill="{t["fail"]}">{FAIL_CAPS[phase]}</text>'
                )
            if j < len(phases) - 1:  # in-column happy connector
                cx = nx + NODE_W / 2
                s.append(
                    f'<line x1="{cx}" y1="{ny + NODE_H + 2}" x2="{cx}" y2="{ny + NODE_H + 14}" '
                    f'stroke="{t["conn"]}" stroke-width="1.5" marker-end="url(#arr)"/>'
                )

    # cross-column happy connectors: last node of col i -> first node of col i+1
    for i in range(4):
        lx, ly = origin[STAGES[i][2][-1][0]]
        rx, ry = origin[STAGES[i + 1][2][0][0]]
        x1, y1 = lx + NODE_W + 2, ly + NODE_H / 2
        x2, y2 = rx - 4, ry + NODE_H / 2
        s.append(
            f'<path d="M{x1},{y1} C{x1 + 26},{y1} {x2 - 26},{y2} {x2},{y2}" fill="none" '
            f'stroke="{t["conn"]}" stroke-width="1.5" marker-end="url(#arr)"/>'
        )

    # ---- bounded FAIL return edges (D7; caps from CLAUDE.md > Regressions)
    def fail_loop(src, dst, span):
        """Right-side dashed return loop from src node up to dst node.

        The cap itself is rendered inside the source node (FAIL_CAPS) — a
        floating label in the column gap collides with the happy-path edges.
        """
        (sx, sy), (dx, dy) = origin[src], origin[dst]
        x = sx + NODE_W
        y1, y2 = sy + 15, dy + NODE_H - 15
        bulge = x + 18 + 4 * span
        s.append(
            f'<path d="M{x + 2},{y1} C{bulge},{y1} {bulge},{y2} {x + 2},{y2}" fill="none" '
            f'stroke="{t["fail"]}" stroke-width="1.3" {DASH} opacity="0.9" '
            f'marker-end="url(#arrf)"/>'
        )

    fail_loop("GATE:HYPOTHESIS", "DIAGNOSE", 1)   # cause FAIL -> DIAGNOSE (max 2x)
    fail_loop("GATE:PLAN", "ARCHITECT", 1)        # plan FAIL -> ARCHITECT (max 3x)
    fail_loop("VERIFY", "RED", 2)                 # cause-branched fix (max 3 round-trips)

    # GATE:QUALITY FAIL -> RED (max 3x): dashed edge through the col3/col4 gap
    (qx, qy), (rx_, ry_) = origin["GATE:QUALITY"], origin["RED"]
    x1, y1 = qx - 4, qy + NODE_H / 2
    x2, y2 = rx_ + NODE_W + 2, ry_ + 11
    s.append(
        f'<path d="M{x1},{y1} C{x1 - 30},{y1} {x2 + 30},{y2} {x2},{y2}" fill="none" '
        f'stroke="{t["fail"]}" stroke-width="1.3" {DASH} opacity="0.9" marker-end="url(#arrf)"/>'
    )

    # HANDOFF review/CI fail bus -> RED (D9: bounded auto-resolution, max 7x)
    (hx, hy), (rx_, ry_) = origin["HANDOFF"], origin["RED"]
    bx, ex = hx + NODE_W - 24, rx_ + 103
    s.append(
        f'<path d="M{bx},{hy - 2} L{bx},{BUS_Y + 8} Q{bx},{BUS_Y} {bx - 8},{BUS_Y} '
        f'L{ex + 8},{BUS_Y} Q{ex},{BUS_Y} {ex},{BUS_Y + 8} L{ex},{ry_ - 4}" fill="none" '
        f'stroke="{t["fail"]}" stroke-width="1.3" {DASH} opacity="0.9" marker-end="url(#arrf)"/>'
    )
    s.append(
        f'<text x="{(bx + ex) / 2}" y="{BUS_Y - 8}" text-anchor="middle" font-family="{SANS}" '
        f'font-size="10" fill="{t["fail"]}">CI fail / review Medium+ → back to RED · review-response ≤7×</text>'
    )

    # ---- STOP node (D6: structure FAIL = no code change -> close/report)
    (gx, gy) = origin["GATE:HYPOTHESIS"]
    sx, sy = gx, TOP + col_h(3) + 16
    s.append(
        f'<line x1="{gx + NODE_W / 2}" y1="{gy + NODE_H + 2}" x2="{gx + NODE_W / 2}" '
        f'y2="{sy - 4}" stroke="{t["conn"]}" stroke-width="1.3" {DASH} marker-end="url(#arr)"/>'
    )
    s.append(
        f'<rect x="{sx}" y="{sy}" width="{NODE_W}" height="{NODE_H}" rx="8" fill="none" '
        f'stroke="{t["muted"]}" stroke-width="1.1" {DASH} opacity="0.85"/>'
    )
    s.append(
        f'<text x="{sx + 12}" y="{sy + 19}" font-family="{MONO}" font-size="11" '
        f'font-weight="600" fill="{t["muted"]}">STOP · CLOSE/REPORT</text>'
    )
    s.append(
        f'<text x="{sx + 12}" y="{sy + 35}" font-family="{SANS}" font-size="10" '
        f'fill="{t["muted"]}">no real gap · non-code cause</text>'
    )

    # ---- legend (two rows)
    y1, y2 = LEGEND_Y, LEGEND_Y + 20
    s.append(f'<path d="M{MARGIN + 7},{y1 - 9} l4.5,4.5 l-4.5,4.5 l-4.5,-4.5 Z" fill="{t["gate_stroke"]}"/>')
    s.append(
        f'<text x="{MARGIN + 18}" y="{y1}" font-family="{SANS}" font-size="11" fill="{t["muted"]}">'
        f'evaluation gate — fresh-spawned Evaluation AI · hook computes PASS from scores (avg ≥ 7.5)</text>'
    )
    s.append(iso_glyph(560, y1 - 10, t))
    s.append(
        f'<text x="{560 + 16}" y="{y1}" font-family="{SANS}" font-size="11" fill="{t["muted"]}">'
        f'isolated sub-context (Workflow / fresh spawn)</text>'
    )
    s.append(f'<circle cx="{830 + 5}" cy="{y1 - 4}" r="4" fill="{t["red"]}"/>')
    s.append(f'<circle cx="{830 + 16}" cy="{y1 - 4}" r="4" fill="{t["green"]}"/>')
    s.append(f'<text x="{830 + 27}" y="{y1}" font-family="{SANS}" font-size="11" fill="{t["muted"]}">red / green TDD</text>')

    s.append(
        f'<line x1="{MARGIN + 2}" y1="{y2 - 4}" x2="{MARGIN + 26}" y2="{y2 - 4}" '
        f'stroke="{t["fail"]}" stroke-width="1.3" {DASH}/>'
    )
    s.append(
        f'<text x="{MARGIN + 32}" y="{y2}" font-family="{SANS}" font-size="11" fill="{t["muted"]}">'
        f'bounded FAIL loop (≤N×) — cap exhausted → human escalation, never unbounded</text>'
    )
    s.append(
        f'<rect x="560" y="{y2 - 12}" width="14" height="10" rx="3" fill="none" '
        f'stroke="{t["muted"]}" stroke-width="1.1" {DASH}/>'
    )
    s.append(
        f'<text x="{560 + 20}" y="{y2}" font-family="{SANS}" font-size="11" fill="{t["muted"]}">'
        f'no code-change need → stop (no unfounded work)</text>'
    )
    s.append(f'<rect x="880" y="{y2 - 12}" width="10" height="10" rx="3" fill="{t["start_fill"]}" stroke="{t["start_stroke"]}"/>')
    s.append(f'<rect x="894" y="{y2 - 12}" width="10" height="10" rx="3" fill="{t["end_fill"]}" stroke="{t["end_stroke"]}"/>')
    s.append(f'<text x="911" y="{y2}" font-family="{SANS}" font-size="11" fill="{t["muted"]}">entry / hand-off (never merges)</text>')

    s.append("</svg>")
    return "\n".join(s) + "\n"

def main():
    here = Path(__file__).resolve().parent
    for theme in THEMES:
        out = here / f"autoflow-lifecycle-{theme}.svg"
        out.write_text(render(theme), encoding="utf-8")
        print(f"wrote {out}")

if __name__ == "__main__":
    main()
