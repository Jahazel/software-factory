# Design templates

The [Design](../playbooks/design.md) playbook writes these files in `docs/design/research/<feature>/`.

## brief.md

```markdown
# Design brief: <feature>

Tracking ticket: #<n>

## Job
One or two sentences: what the user comes here to do.

## Flow map
| From | User action | To |
| --- | --- | --- |

## States
| State | When it happens | What it must show |
| --- | --- | --- |

## Data cases
Real data shapes the layout must hold, such as one item, many items, or a partial set.

## Out of scope
What this design leaves for later, and why.

## Open questions
Numbered. The research step answers each one.

## Directions
The three directions shown, with one line each, and the one the user picked.
```

## motion.md

```markdown
# Motion spec: <feature>

| Element | Trigger | Motion | Duration token | Reduced motion |
| --- | --- | --- | --- | --- |
| List row | Press | Background darkens | Press duration | Same, no movement |
| Detail page | Opens from a row | Slides in from the right | Overlay duration | Appears without movement |
```

Use only the project's motion durations. Every row needs a reduced-motion entry.
