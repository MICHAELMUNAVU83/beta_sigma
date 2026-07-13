# Admin Redesign Guide — Minimal / Notion-style

This replaces the decorative direction in `design_guide.md`. The goal is a calm, text-forward,
Notion-like workspace: the UI recedes, the content leads. Use this when building or restyling any
authenticated admin view.

## Philosophy

Notion looks the way it does because the interface tries to disappear:

- **Content first, chrome last.** Text and data are the design. Borders, shadows, and color are
  used only when they carry meaning.
- **Flat, not glassy.** No glassmorphism, no backdrop blur, no big drop shadows. A single hairline
  border or a divider is enough to separate things.
- **Restraint over decoration.** One accent color, used rarely. Everything else is neutral gray.
- **Quiet hierarchy.** Establish structure with size, weight, and spacing — not with uppercase
  eyebrows, wide letter-spacing, or gradient tone cards.
- **Dense but breathable.** Comfortable line height and consistent spacing, without wasted vertical
  space or oversized hero blocks.

If a page feels "designed", it's probably too much. Aim for "obvious".

## What we are removing (the "AI slop" tells)

Search-and-destroy these patterns during migration:

| Remove | Replace with |
| --- | --- |
| `rounded-[2rem]`, `rounded-[1.75rem]` | `rounded-lg` (8px) for panels, `rounded-md` (6px) for controls |
| `shadow-[0_20px_60px_rgba(15,23,42,0.08)]` and other large soft shadows | no shadow on static panels; `shadow-sm` only on menus/modals |
| `bg-white/90`, `bg-stone-50/80`, `backdrop-blur-sm` | solid `bg-white` / `bg-neutral-50`, no blur |
| eyebrow labels: `uppercase tracking-[0.24em] text-orange-700` | plain sentence-case label, `text-sm font-medium text-neutral-500` |
| `text-4xl` metric numbers, `sm:text-4xl` page titles | `text-2xl` page title, `text-xl`/`text-2xl` for a metric |
| gradient / tinted "tone" cards (ink/amber/emerald/rose backgrounds) | one neutral card style; color only in a small dot/label |
| marketing copy ("at a glance", "in motion", "portfolio health") | literal, functional labels ("12 tasks · 3 overdue") |
| pill buttons (`rounded-full`) with large padding | compact `rounded-md` buttons |

## Color

Neutral is the default. Color is the exception.

- **Canvas:** `bg-white`. Optionally `bg-neutral-50` for the app shell behind cards.
- **Text:**
  - Primary: `text-neutral-900` (near-black, not pure black).
  - Secondary: `text-neutral-500`.
  - Muted / hints: `text-neutral-400`.
- **Borders / dividers:** `border-neutral-200` (hairline). This is the primary way to separate
  content — prefer a `border` or `divide-y` over a shadowed card.
- **Accent (orange `#f26334`, the existing brand color):** use *only* for
  - the primary button,
  - active nav / selected state,
  - links,
  - a focus ring.
  Do not tint backgrounds, headers, or cards with it.
- **Status colors** — used as a small dot or short text label, never as a card background:
  - green `text-emerald-600` — done / healthy / live
  - amber `text-amber-600` — warning / due soon
  - red `text-red-600` — overdue / destructive / error
- **Hover feedback:** a subtle gray fill, `hover:bg-neutral-100`. This is the Notion signature —
  rows and buttons highlight quietly on hover instead of shifting shadow or scale.

Stick to Tailwind's `neutral` scale for grays so everything stays consistent (avoid mixing
`stone`, `slate`, and `zinc`).

## Typography

- **Page title:** `text-2xl font-semibold text-neutral-900 tracking-tight`. No eyebrow above it.
- **Section heading:** `text-sm font-semibold text-neutral-900` (or `text-base` for a major
  section). Optionally with a bottom hairline divider.
- **Body:** `text-sm text-neutral-700 leading-6`.
- **Secondary / metadata:** `text-xs text-neutral-500`. Sentence case, not uppercase.
- **Weight does the work.** Differentiate levels with `font-medium` / `font-semibold` and size,
  not with letter-spacing or color washes. Never use `tracking-[0.2em]` uppercase labels.

## Spacing & Layout

- **Page rhythm:** `space-y-6` between major sections (down from `space-y-8`). Tighter and calmer.
- **Container:** `max-w-5xl` for reading/detail pages; full width for dense tables. Keep it
  consistent within a section.
- **Padding:** `p-4` inside cards, `p-6` for a page's outer padding. Avoid `p-8`+ blocks that push
  content below the fold.
- **Separation:** prefer dividers (`divide-y divide-neutral-200`) and single hairline borders over
  stacking multiple bordered-and-shadowed cards. Whitespace separates; walls are a last resort.

## Panels & Cards

The default surface — one style, reused everywhere:

```
rounded-lg border border-neutral-200 bg-white
```

- No shadow on static content panels.
- Internal card / nested block: same border, `bg-neutral-50` if it needs to sit "inside" a white
  panel.
- Only floating surfaces (dropdown menus, popovers, modals) get elevation: `shadow-md` + `bg-white`
  + `border border-neutral-200`.

## Buttons & Actions

Compact and flat. `rounded-md`, `px-3 py-1.5`, `text-sm font-medium`.

- **Primary:** `bg-[#f26334] text-white hover:bg-[#d9532a]`. One per screen context.
- **Secondary / default:** `border border-neutral-200 bg-white text-neutral-700 hover:bg-neutral-50`.
- **Ghost / tertiary** (icon buttons, row actions): `text-neutral-500 hover:bg-neutral-100`,
  no border.
- **Destructive:** `text-red-600 hover:bg-red-50`; only fill red (`bg-red-600 text-white`) inside a
  confirmation modal where the risk is explicit.
- **Focus ring:** `focus-visible:ring-2 focus-visible:ring-[#f26334]/40 focus-visible:ring-offset-0`.

No pill shapes, no oversized padding, no gradients.

## Forms

- Inputs: `rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm`, focus with the accent
  ring above. No inner shadow, no heavy fill.
- Labels: `text-sm font-medium text-neutral-700`, sentence case, directly above the field.
- Prefer inline / in-context editing where it fits Notion's model; use a modal for
  create/invite/focused-edit flows.
- Actions bottom-right: `Cancel` (secondary) then the primary action. Keep the group short.

## Lists, Tables & Boards

This is where the Notion feel matters most.

- **Rows over cards.** A list is dividers between rows (`divide-y divide-neutral-200`), each row
  `px-3 py-2` with a `hover:bg-neutral-50` highlight. Reserve standalone cards for genuinely
  card-shaped content (a board column, a summary tile).
- **Most important text first**, left-aligned. Metadata trails as small `text-xs text-neutral-500`
  on the same line or a quiet second line.
- **Status as a dot or short label**, not a colored chip background: `● Overdue` with the dot in
  the status color. If you must use a chip, keep it flat and small: `bg-neutral-100 text-neutral-600
  text-xs rounded px-1.5 py-0.5`.
- **Tables:** header row `text-xs font-medium text-neutral-500`, hairline bottom border, generous
  cell padding, hover row highlight. No zebra striping, no shadows.
- **Boards (kanban):** column is a light neutral surface; cards are white with a hairline border and
  no shadow. Title first; status/priority/due as small quiet metadata.
- Guard derived values and counts defensively — never assume associations are loaded in render
  helpers.

## Metrics / Stats

Replace the four gradient "tone" tiles with a quiet stat row:

- One neutral card style (`rounded-lg border border-neutral-200 bg-white p-4`) or a simple
  divided row — not four differently-colored panels.
- Label: `text-sm text-neutral-500` (sentence case). Value: `text-2xl font-semibold
  text-neutral-900`. A short delta/context line in `text-xs text-neutral-500`.
- Put color only on a change indicator (`text-emerald-600` / `text-red-600`), if at all.

## Navigation / Sidebar

- Solid `bg-neutral-50` or `bg-white`, single right hairline border. No blur, no heavy shadow.
- Items: `rounded-md px-2 py-1.5 text-sm text-neutral-600 hover:bg-neutral-100`.
- Active item: `bg-neutral-100 text-neutral-900 font-medium` — or a thin accent marker. The active
  state should be *legible*, not loud.
- Section labels: `text-xs font-medium text-neutral-400`, sentence case. No wide tracking.

## Empty States

- A simple centered block inside a hairline-bordered panel (a dashed border is fine, but light:
  `border border-dashed border-neutral-200`).
- One line telling the user what to do, `text-sm text-neutral-500`, plus a single primary action.
- No illustration-heavy or gradient empty states.

## Modals & Menus

- Modal: `rounded-lg border border-neutral-200 bg-white shadow-md`, comfortable padding
  (`p-6`), backdrop `bg-black/20` (no blur).
- Title: `text-base font-semibold text-neutral-900`, optional one-line `text-sm text-neutral-500`
  context. No uppercase label above it.
- Dropdown menus: `rounded-md border border-neutral-200 bg-white shadow-md`, items
  `px-3 py-1.5 text-sm hover:bg-neutral-100`.

## Before → After (quick reference)

```
- <section class="rounded-[2rem] border border-stone-200/80 bg-white/90
-   p-6 shadow-[0_20px_60px_rgba(15,23,42,0.08)] backdrop-blur-sm">
+ <section class="rounded-lg border border-neutral-200 bg-white p-4">

- <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-500">Active projects</p>
- <p class="mt-4 text-4xl font-semibold text-slate-950">{@value}</p>
+ <p class="text-sm text-neutral-500">Active projects</p>
+ <p class="mt-1 text-2xl font-semibold text-neutral-900">{@value}</p>

- <a class="rounded-full bg-orange-600 px-6 py-3 text-white shadow-lg">Create</a>
+ <a class="rounded-md bg-[#f26334] px-3 py-1.5 text-sm font-medium text-white hover:bg-[#d9532a]">Create</a>
```

## Reuse Checklist

Before shipping a redesigned admin page, confirm:

- No `rounded-[2rem]`, no large soft shadows, no `backdrop-blur`, no `bg-white/90`.
- Grays come from a single scale (`neutral`); orange appears only on the primary action, active
  nav, and links.
- Page title is plain `text-2xl font-semibold` with no uppercase eyebrow.
- Lists are divided rows with a hover highlight, not stacks of shadowed cards.
- Status is shown as a dot/label, not a colored card.
- Copy is literal and functional, not marketing-speak.
- Only floating surfaces (menus, modals) carry elevation.
- Helper functions handle unloaded associations safely.

## Migration Order

Restyle in this sequence so the shared language propagates outward:

1. App shell + sidebar (`sidebar_component.ex`, `layouts/`) — sets the neutral canvas.
2. Core components (`core_components.ex`) — buttons, inputs, modal, table, header.
3. One workspace (Projects or Notes) as the reference page, then match the rest to it.
```
