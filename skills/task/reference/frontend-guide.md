# Frontend Guide

Read this file when `TASK_TYPE = frontend` — in addition to `synthesize-guide.md`.

Goal: write Requirements, Constraints, and Verification for frontend tasks so that the implementer never makes visual decisions on their own.

---

## Principle

Frontend tasks fail when the task file doesn't answer:

- Which exact font-family?
- Which easing on the transition?
- What happens at the mobile breakpoint?
- What counts as "correct" visually?

The prompt engineer's job is to translate the ticket and the Figma link into concrete visual requirements with verifiable values.

---

## Step 1 — Design context: what to find during Investigate

Answer these questions before Synthesize.
If task-explorer did not find the answers — add them to the clarifying questions.

**Typography:**

- Which font-family is in the project? (CSS variables, tailwind config, globals)
- Is there a type scale? (`typography.ts`, `tailwind.config.js`, CSS)

**Color system:**

- How are colors defined — CSS variables, Tailwind tokens, JS theme object?
- Token names for primary, surface, border, text (from the files)

**Spacing:**

- 4px or 8px grid? (tailwind config or the design system)

**Animation:**

- Animation library? (Framer Motion, GSAP, CSS-only)
- Standard easings/durations in the project? (`animations.ts` or CSS vars)

**Breakpoints:**

- Breakpoints? (tailwind config or CSS media queries)
- Mobile-first or desktop-first?

**Component patterns:**

- Structure of similar components? (paths + structure from findings)

---

## Step 2 — Requirements: how to write visual requirements

### Rule: every visual requirement carries a concrete value

Remove room to interpret visual details.

**Before / After:**

```
# Bad — the implementer will guess
- Add a card mount animation
- The card should look interactive on hover
- Use colors from the design system
```

```
# Good — every value is concrete
- On mount: cards appear with a staggered fade-in, 60ms delay between items,
  duration 300ms, easing: ease-out. Use Framer Motion (already in the project).
- Hover state: box-shadow transitions to `--shadow-md` over 180ms ease-out,
  translateY(-2px) over the same time. One transition, not two separate ones.
- Colors strictly from CSS variables: background → `--color-surface`,
  border → `--color-border`, text → `--color-text-primary`.
```

### Frontend Requirements checklist

For each visual element walk through the checklist:

**Typography** (if the task touches text):

- [ ] font-family — concrete value or project token
- [ ] font-size — value or scale step (`text-sm`, `--font-size-body`)
- [ ] font-weight — number or token (`font-medium`, `500`)
- [ ] line-height — value (`leading-relaxed`, `1.6`)
- [ ] letter-spacing — if non-standard

**Color** (if the task touches color):

- [ ] Concrete CSS variables or Tailwind tokens for each color
- [ ] Color across states: default, hover, active, disabled, focus
- [ ] Dark mode — is it required, how does the project switch it?

**Spacing & Layout**:

- [ ] Concrete padding/margin values or tokens (`p-4`, `gap-6`, `--space-md`)
- [ ] Breakpoints — how layout changes on mobile/tablet/desktop
- [ ] Alignment and distribution — flex/grid config

**Animation & Motion**:

- [ ] Trigger — when it fires (mount, hover, scroll, click)
- [ ] Property — what animates (opacity, transform, height)
- [ ] Duration — milliseconds
- [ ] Easing — function (`ease-out`, `cubic-bezier(0.4, 0, 0.2, 1)`)
- [ ] Delay — if staggered
- [ ] Library — CSS transition, Framer Motion, GSAP

**Interactive states**:

- [ ] hover — visual change + transition
- [ ] focus-visible — ring/outline for accessibility
- [ ] active/pressed — tactile feedback
- [ ] disabled — opacity + cursor
- [ ] loading — skeleton or spinner

---

## Step 3 — Constraints: what to protect in frontend tasks

### Always add these Constraints for frontend:

**Fonts — protect from replacement:**

```
- Do not replace font-family — use only what's already in the project
  (found: [concrete values from Investigate])
- Do not pull in new fonts via Google Fonts or @import
```

**Tokens — protect from hardcoded values:**

```
- All colors via CSS variables / Tailwind tokens only — no hardcoded hex
- All sizes via tokens — no hardcoded px outside the design system
```

**Animations — protect from excess:**

```
- Do not add animations that aren't in the ticket
- prefers-reduced-motion: every motion effect disables via the media query
```

**Existing components — protect from duplication:**

```
- Use the existing [ComponentName] from [path] — do not create a duplicate
- Do not change the props interface of existing components
```

**Anti-convergence (from the frontend-design skill):**

```
- Do not use Inter/Roboto/Arial if they aren't in the project
- Do not add a purple gradient — the project's design system doesn't contain one
- Follow the established visual style, do not introduce a new aesthetic
```

---

## Step 4 — Verification: how to verify frontend tasks

### The frontend Verification problem

`curl` can't verify "looks right".
Concrete behavioral checks can.

**Verification levels for frontend:**

**1. Automated (when the project has tests):**

```
- `npm test src/components/Card.test.tsx` — all tests green
- `npm run type-check` — no TypeScript errors
- `npm run lint` — no eslint errors
```

**2. Visual checklists (manual but concrete):**

```
- Open the component on desktop (1440px): cards in 3 columns with 24px gap
- Open on mobile (375px): cards in 1 column, 16px side padding
- Hover on a card: shadow appears in 180ms, no jitter
- Tab through elements: focus ring visible on every interactive element
- Enable prefers-reduced-motion in the OS: all animations gone
- Dark mode (if supported): all colors switch via CSS variables
```

**3. Accessibility:**

```
- Images have alt text
- Interactive elements are keyboard-accessible
- Text contrast ratio ≥ 4.5:1 (check in Chrome DevTools)
```

### Before / After for Verification:

```
# Bad — unverifiable
- The animation works correctly
- Looks good on mobile
- Hover state exists
```

```
# Good — concrete checks
- `npm run type-check` — 0 errors
- Resize to 375px: layout switches to 1 column, text doesn't clip
- Hover on the button: translateY(-2px) + shadow over 180ms, no jitter
- Tab to the button: focus ring 2px solid var(--color-focus) visible
- System dark mode ON: all surfaces use --color-surface-dark
- prefers-reduced-motion ON in the OS: open the page, no animations
```

---

## Clarifying questions for frontend tasks

Before adding a question, check whether the user already answered it in the prompt (synthesize-guide.md, "Validate against the user's input").

If Investigate didn't answer the key questions — add them to the AskUserQuestion list (ask interactively, don't write them to the file):

- "Do we need dark mode for this component?" → Yes, CSS variables (project pattern) / No, light only
- "How to handle animations under prefers-reduced-motion?" → Disable entirely / Keep opacity-only
- "Which breakpoint splits mobile → desktop?" → md 768px (Tailwind standard) / lg 1024px (complex component)
- "Do we need skeleton loading states?" → Yes, following [component] pattern / No, spinner
