# Per-skill MDX template

Each generated page at `site/src/content/docs/skills/<name>.mdx` follows
this exact shape. Seven sections, top to bottom.

## Template

````mdx
---
title: /yoke:<name>
description: <one-line description from SKILL.md frontmatter>
---

<!-- 1. Title is rendered by Starlight from `title:` above. -->

<!-- 2. One-line description -->

<!--
  The renderer omits any `import { … }` line by default. Add an
  import block here ONLY if a body section below uses Starlight
  components like <Aside> or <Code>. Today no per-skill page does.
-->

<one-line description from SKILL.md frontmatter, full sentence>

<!-- 3. Trigger phrases -->

## Triggers

Activates when the user writes:

- `<trigger phrase 1>`
- `<trigger phrase 2>`
- …

<!-- 4. Use it -->

## Use it

```
/yoke:<name>
<additional example invocations from docs/<name>.md or SKILL.md body>
```

<!-- 5. Inputs / outputs / side effects -->

## Inputs and outputs

**Input:** <from docs/<name>.md ## Input, or extracted from SKILL.md>

**Output:** <from docs/<name>.md **Output:** line, or extracted from SKILL.md>

**Side effects:** <commits, files written, external calls — only when present>

<!-- 6. Full instructions (raw SKILL.md verbatim) -->

<details>
<summary>Full instructions</summary>

```markdown
<raw SKILL.md body, verbatim, including frontmatter>
```

</details>

{/* 7. Footer link */}

## Source

[View `SKILL.md` on GitHub →](https://github.com/yokeloop/yoke/blob/main/skills/<name>/SKILL.md)
````

## Field sources

| Section           | Source (in priority order)                                                         |
| ----------------- | ---------------------------------------------------------------------------------- |
| `title`           | Always `/yoke:<name>`                                                              |
| `description`     | First sentence of `description:` in `skills/<name>/SKILL.md` frontmatter           |
| One-line summary  | Full first sentence of the frontmatter `description`                               |
| Triggers          | Quoted substrings inside the frontmatter `description` that look like user phrases |
| Use it            | First example code block in `docs/<name>.md`; else extracted from SKILL.md body    |
| Input             | `## Input` section of `docs/<name>.md`; else extracted from SKILL.md               |
| Output            | `**Output:**` line in `docs/<name>.md`; else extracted from SKILL.md               |
| Side effects      | Listed only when SKILL.md or docs explicitly mention commits/files/API calls       |
| Full instructions | Raw `skills/<name>/SKILL.md` body, including frontmatter, verbatim                 |
| Footer link       | Canonical GitHub URL for `skills/<name>/SKILL.md` on `main`                        |

## Rules

- The MDX is plain Starlight markdown. Do not introduce custom components
  beyond `<Aside>` and `<Code>`.
- The `<details>` block always contains the SKILL.md verbatim — line breaks,
  YAML, frontmatter all preserved.
- The Side effects line is omitted when nothing applies. Do not write
  `Side effects: none`.
- Trigger phrases preserve the original case and punctuation from the
  description.
- Output column in the README block uses the same source as the MDX
  Output field.
- Use unix line endings (`\n`); no trailing whitespace.
