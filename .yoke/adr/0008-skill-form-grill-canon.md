# Skill form: the grill canon — intent over procedure

grill is 52 lines of intent, principles, and boundaries, and delivers the
plugin's best results; review is 307 lines of step-by-step mechanics and needed
the most hand-holding. We decided (2026-07-08): every shipped SKILL.md states
intent, principles, and boundaries in roughly ≤100 lines, trusts the model
instead of scripting it, and moves formats/mechanics into reference/ files
loaded on demand. Any decision fork inside a skill is one AskUserQuestion with
a recommended option — a convention for all skills, not a grill feature.
review, bootstrap, do, and pr get rewritten to this canon in 3.0.

The trade-off is real: procedural skills are more predictable step-to-step, but
a month of logs showed the intent-shaped skill outperformed them in practice,
and long scripts drift out of date faster than principles do.
