# Internal Redesign Guide — BeCorp Editorial

This supersedes `design.md` (the Notion-minimal direction). The new reference point is the public
BeCorp marketing site (`lib/beta_sigma_web/live/marketing_live/*`, `marketing_components.ex`,
`layouts/marketing*.html.heex`). Use this when building or restyling any authenticated `/app` or
`/admin` view.

Read `design.md` first if you want the contrast — almost every rule below is a deliberate reversal
of it (dark instead of white, square instead of rounded, huge type instead of small, generous
instead of dense). Don't blend the two directions on the same page.

## Philosophy

The BeCorp site is editorial, not app-like: big type carries the hierarchy, a single hairline
carries the separation, and one blue accent appears just often enough to feel intentional.

- **Type is the hierarchy.** Size and weight do the work that cards, colored backgrounds, and
  shadows used to do. A section doesn't need a tinted panel if its heading is 64px.
- **Flat and square.** No border radius anywhere on the marketing site — not on buttons, not on
  cards, not on inputs. No shadows. No blur except the sticky header itself.
- **One accent, used like punctuation.** `accent` blue shows up on icons, active nav state, hover
  states, and small numeric markers (`/ 01`, `+`). It never fills a background.
- **Borders instead of cards.** Sections are separated by a single `border-n600/40` hairline, not
  by stacking bordered-and-padded card boxes.
- **Generous, not dense.** Sections breathe (`py-24 lg:py-40`). This is the opposite instinct from
  `design.md`'s "tighter and calmer" — here, whitespace itself is part of the design.
- **Links, not buttons, for primary actions.** The CTA pattern is underlined text + an arrow that
  nudges right on hover — not a filled, rounded button.

If a page still looks like a SaaS dashboard after restyling, it hasn't gone far enough.

## What we are removing

| Remove (Notion-minimal era) | Replace with (BeCorp editorial) |
| --- | --- |
| `rounded-lg` / `rounded-md` on panels, buttons, inputs | no radius — square corners everywhere |
| `bg-white` / `bg-neutral-50` canvas | `bg-ink` (`#060606`) canvas, light text |
| `text-neutral-900` / `text-neutral-500` / `text-neutral-400` | `text-n100` / `text-n500` / `text-n600` (see Color) |
| orange `#f26334` accent | blue `accent` `#4269e2` (`accentDeep` `#2544a8` for filled accent blocks) |
| `text-2xl font-semibold` page titles | fluid, large headings — `text-[32px] sm:text-[44px] lg:text-[64px] font-medium` for a section/page heading |
| filled `bg-[#f26334]` buttons | underlined text link + arrow icon, `group-hover:translate-x-1` |
| `divide-y divide-neutral-200` rows with `hover:bg-neutral-100` | keep for genuinely dense tables (see below), but prefer hairline-divided blocks with breathing room elsewhere |
| `shadow-sm` / `shadow-md` on menus/modals | no shadow; use a `border border-white/10` or `border-white/20` instead |
| sentence-case quiet labels | small uppercase, tracked "eyebrow" labels are back: `text-sm uppercase tracking-[0.1em] text-n100`, usually paired with a small `+` icon in `accent` |

## Color

- **Canvas:** `bg-ink` (`#060606`). This is the app shell background, not just marketing pages.
- **Text:**
  - Headings / emphasis: `text-n100` (`#ffffff`).
  - Body default: `text-n500` (`#bababa`) — this is the base text color on `<body>`, most prose
    doesn't need an explicit color class.
  - Muted / metadata: `text-n600` (`#8b8b8b`).
  - Bright alt (rarely needed): `text-n400` (`#e1e1e1`).
- **Accent:** `accent` (`#4269e2`) for icons, hover states, active nav, small numeral/eyebrow
  markers, and the `+` in stat numbers. `accentDeep` (`#2544a8`) only for a filled block that needs
  the blue as a background (e.g. a portfolio tile), never for text on `bg-ink`.
- **Surfaces:** there is no "card" surface color distinct from the canvas. A block is either bare
  (just spacing) or has a `border border-white/10` (or `/20` for interactive elements like carousel
  arrows). Use `bg-n800` (`#171717`) only when a block sits over imagery and needs a solid fallback
  (see the portfolio tiles).
- **Status colors:** keep `text-emerald-600` / `text-amber-600` / `text-red-600` for done/warning/
  overdue, same as before — these are functional, not stylistic, and the editorial palette doesn't
  replace them. Render as a small dot or label text on the dark canvas, same rule as `design.md`.

Fonts import from `assets/css/app.css`; the marketing font is registered as `font-becorp` in
`assets/tailwind.config.js` (DM Sans), separate from the app's Manrope-based `font-sans`. When
restyling `/app`, switch the shell to `font-becorp` — don't mix the two fonts on one page.

## Typography

- **Page / section heading:** `text-[32px] font-medium leading-[1.2] text-n100 sm:text-[44px]
  lg:text-[64px]`. This is deliberately huge — it replaces the old `text-2xl font-semibold` page
  title outright.
- **Hero-scale heading** (top of a page, used sparingly — e.g. a dashboard's top-level greeting):
  `text-[44px] font-medium leading-[1.15] text-n100 sm:text-[64px] lg:text-[80px]`.
  Subsection heading: `text-[26px] font-medium leading-[1.28] text-n100 lg:text-[50px]`.
- **Eyebrow label** (above a heading, optional): `text-sm uppercase tracking-[0.1em] text-n100`,
  usually preceded by a small 16px accent icon (a "plus" cross glyph is the site's signature icon —
  see any `<svg>` before an eyebrow span in the marketing templates).
- **Body:** `text-[18px] leading-[1.667]` for prose paragraphs, no explicit color needed
  (inherits `text-n500`). Use `<span class="whitespace-nowrap">` on the last couple of words of a
  paragraph to avoid an orphan line — this is used throughout the marketing copy and is worth
  keeping as a habit for hero/intro copy.
- **Metadata / secondary:** `text-lg text-n600` or `text-base text-n600` depending on context
  (e.g. the small category label under a portfolio tile).
- **Font weight** is `font-light` by default (set on `<body>`); headings and emphasis opt into
  `font-medium` / `font-semibold` explicitly.

## Spacing & Layout

- **Container:** `mx-auto w-full max-w-[1290px] px-5`. Use this consistently instead of `max-w-5xl`
  — internal pages should feel as wide and considered as the marketing site.
- **Section rhythm:** stacked sections, each `py-24 lg:py-40` (or `lg:py-32` for a slightly smaller
  section), separated by a single `border-b border-n600/40` on all but the last section on a page.
  This replaces `space-y-6` + individually bordered cards.
- **Content spacing inside a section:** generous — `mb-16` between a section's heading block and
  its content, `gap-16`/`gap-24` between grid columns. Don't shrink this to fit more on screen;
  editorial pages accept scrolling.
- **Sticky-label pattern:** for a section pairing a short label/heading with a longer list of
  items (see "Our approach", "Group Highlights" on the homepage), put the label in
  `lg:sticky lg:top-32 lg:self-start` inside a `grid lg:grid-cols-[maxpx_auto]` — the label stays
  pinned while the content scrolls past. This is a good fit for e.g. a settings page with a fixed
  left label and a long list of fields on the right.

## Buttons & Links

The primary CTA pattern, used everywhere instead of a filled button:

```heex
<.link navigate={~p"/..."} class="group inline-flex items-center gap-2 border-b border-n100 pb-2 text-2xl font-semibold text-n100 transition-colors hover:border-accent hover:text-accent">
  Label
  <svg class="h-5 w-5 shrink-0 transition-transform duration-200 group-hover:translate-x-1" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
    <line x1="5" y1="12" x2="19" y2="12" /><polyline points="12 5 19 12 12 19" />
  </svg>
</.link>
```

Scale the text size down (`text-lg`, `text-base`) for secondary/inline actions, keeping the same
underline + arrow shape.

Internal pages still need real buttons for destructive/modal/form actions where a text link would
be ambiguous (Delete, Save, Cancel inside a dialog). For those:

- **Primary:** `bg-accent text-n100 hover:bg-accentDeep`, square corners, `px-4 py-2 text-sm
  font-medium`. No pill shape, no rounded corners — this is the one place a filled button is fine.
- **Secondary:** `border border-white/20 text-n100 hover:border-accent hover:text-accent`, same
  padding, transparent background.
- **Destructive:** `text-red-500 hover:bg-red-500/10`, only filled red inside a confirmation
  modal.
- Icon-only / row actions: `text-n600 hover:text-accent`, no border, no fill.

## Panels & Cards

There is no reusable "card" component on the marketing site — resist the urge to invent a
`rounded-lg bg-n800` box for every internal block. Default to:

```
border border-white/10 p-10
```

square corners, no shadow, no fill. Use `p-8`/`p-6` for smaller blocks. Reserve `bg-n800` for a
block that sits over an image or needs a definite fill (matches the portfolio tiles pattern).
Floating surfaces (dropdown menus, popovers, modals) are the one place elevation-by-border is
still appropriate: `border border-white/10 bg-ink` with no radius, no shadow — the borders should
do all the separating.

## Forms

- Inputs follow the contact-form pattern: **no box, just an underline.**
  `w-full border-b border-n600 bg-transparent py-4 text-n100 placeholder:text-n600
  focus:border-accent focus:outline-none`. Labels are `sr-only` with a descriptive `placeholder`
  doing the visible labeling — fine for short forms (contact, subscribe), but use a visible
  `text-sm font-medium text-n100` label above the field for internal forms with more than 2-3
  fields, where placeholder-as-label stops being usable.
- Submit as a link-style CTA (see Buttons & Links) for simple forms; use a filled `bg-accent`
  button only inside modals or multi-field forms where a text link would be missed.
- Textarea/select follow the same underline treatment; no rounded corners, no inner shadow.

## Lists, Tables & Boards

The marketing site has no example of a dense data table, so this section is a deliberate
adaptation rather than a lift:

- **Rows still use hairline dividers** (`divide-y divide-white/10` instead of
  `divide-neutral-200`), each row `px-3 py-2.5`, `hover:bg-white/5` instead of `hover:bg-neutral-100`.
- **Headings inside a table** follow the eyebrow pattern: `text-sm uppercase tracking-[0.1em]
  text-n600` for column headers, instead of `text-xs font-medium text-neutral-500`.
- **Status** stays a small dot/label — same rule as `design.md` — but rendered against `text-n500`
  body text instead of `text-neutral-700`.
- **Boards (kanban):** column surface is `bg-n800` (not `bg-neutral-100`); cards are
  `border border-white/10` with no radius and no shadow, title in `text-n100`, metadata in
  `text-n600`.
- Numbered/step lists (onboarding, a wizard, an ordered process) should use the site's `/ 01`
  marker style: `<div class="text-base text-accent">/ 01</div>` beside the item heading, exactly as
  in the homepage's "Our approach" section.

## Stats / Metrics

Use the homepage stat-block pattern directly — it already generalizes well to a dashboard:

```heex
<div class="text-[32px] font-medium leading-[1.2] text-n100 sm:text-[44px] lg:text-[64px]">
  128<span class="text-accent">+</span>
</div>
<div class="text-2xl text-n600">Active tasks</div>
```

Lay several out in a `grid grid-cols-2 lg:grid-cols-4 gap-x-16 gap-y-14`, same as the homepage
"who we are" stats. No card, no background tint — the numbers carry the section on their own.

## Navigation

- Sticky header: `sticky top-0 z-50 border-b border-white/5 bg-ink/95 backdrop-blur`. This is the
  one place `backdrop-blur` is allowed — the header, and only the header.
- Nav items: `text-n100`, `hover:text-accent`; active item is `text-accent` with `aria-current`.
  No pill/background highlight for the active state — color alone marks it, same idiom as
  `marketing_header/1`'s `active` attr.
- For a persistent app sidebar (as opposed to the marketing site's overlay nav), keep it
  `bg-ink` with a single `border-white/10` right edge, items `text-n500 hover:text-n100`, active
  item `text-accent font-medium` — no background fill on the active row, just color + weight.

## Empty States

- Centered block inside a `border border-white/10` panel (no dashed border needed — the site
  doesn't use dashed borders anywhere).
- One line in `text-n500`, plus a single link-style CTA (see Buttons & Links), not a filled button.

## Before → After (quick reference)

```
- <div class="rounded-lg border border-neutral-200 bg-white p-4">
-   <p class="text-sm text-neutral-500">Active projects</p>
-   <p class="mt-1 text-2xl font-semibold text-neutral-900">{@value}</p>
- </div>
+ <div>
+   <div class="text-[32px] font-medium leading-[1.2] text-n100 sm:text-[44px] lg:text-[64px]">
+     {@value}<span class="text-accent">+</span>
+   </div>
+   <div class="text-2xl text-n600">Active projects</div>
+ </div>

- <a class="rounded-md bg-[#f26334] px-3 py-1.5 text-sm font-medium text-white hover:bg-[#d9532a]">Create</a>
+ <.link class="group inline-flex items-center gap-2 border-b border-n100 pb-2 text-lg font-semibold text-n100 hover:border-accent hover:text-accent">
+   Create
+   <svg class="h-4 w-4 transition-transform duration-200 group-hover:translate-x-1" ...>...</svg>
+ </.link>

- <div class="rounded-lg border border-neutral-200 bg-white divide-y divide-neutral-200">
+ <div class="border border-white/10 divide-y divide-white/10">
```

## Reuse Checklist

Before shipping a restyled internal page, confirm:

- Canvas is `bg-ink`, not white/neutral.
- No `rounded-*` anywhere except a deliberate, rare exception — square corners are the default.
- No shadows outside floating menus/modals (and even those lean on borders, not shadow).
- Headings use the fluid `text-[Npx] sm:text-[Npx] lg:text-[Npx]` scale, not `text-2xl`.
- Accent color is blue (`accent`/`accentDeep`), used sparingly — icons, hover, active state, `+`
  markers — never as a large fill.
- Primary actions are underline-and-arrow links; filled buttons are reserved for modals/forms.
- Section separation comes from a single hairline border, not stacked cards.
- Font is `font-becorp` (DM Sans), not the old `font-sans` (Manrope), on any page being migrated.

## Migration Order

1. App shell + sidebar (`sidebar_component.ex`, `layouts/app.html.heex`) — sets the dark canvas and
   nav idiom for everything nested inside it.
2. Core components (`core_components.ex`) — buttons, inputs, modal, table, header — so every page
   inherits the new look without per-page rework.
3. One workspace (Projects or Notes) as the reference page, then match the rest to it, the same
   order `design.md` used for the previous migration.
4. Re-check any page that mixed both eras (e.g. built mid-migration) against the Reuse Checklist
   above before calling it done.
