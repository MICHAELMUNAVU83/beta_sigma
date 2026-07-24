# Tukutane Event Operations Implementation Guide

**Source:** `PRD/Tukutane_Tech_Requirements.docx`  
**Business owner:** Mary Murimi  
**Source date:** July 2026  
**Business:** Sponsorship-led live events and entertainment across East Africa

## Outcome

Create one operational view from event concept through close-out. Ticketing and sponsor pipelines
are the immediate revenue priorities; production, content, audience insight, and event finance
follow through shared event records and integrations.

## Current state and gaps

- WhatsApp coordinates staff, artists, vendors, and sponsors; Instagram is the primary audience
  channel.
- There is no formal ticketing, CRM, project management, event finance, audience database, or
  secure contract repository.
- Sales, capacity, obligations, production dependencies, and budget position lack real-time
  visibility.
- Source benchmarks include Blankets & Wine and Live Nation practices; named tools are references,
  not approved vendors.

## Product boundary

Use external providers to process ticket payments/issuance, publish social content, hold financial
ledgers, and store signed contracts. Build the Tukutane operations hub in BetaSigma to unify event,
sponsor, artist, vendor, campaign, task, budget, and imported ticket/audience data.

## Roles

| Role | Capabilities |
| --- | --- |
| Event lead | Own event plan, capacity, team, readiness, and close-out |
| Partnerships | Sponsor CRM, proposals, commitments, follow-ups, pipeline |
| Production | Tasks, vendors, riders, run-of-show, dependencies |
| Marketing | Campaign calendar, assets, links, performance imports |
| Finance | Budget, approvals, actuals, reconciliation/export |
| Box office | Ticket summaries, check-in exceptions, complimentary allocations |
| External collaborator | Only explicitly shared event tasks/documents |
| Executive | Portfolio, revenue, pipeline, readiness, and post-event summaries |

## MVP scope

### T1. Event portfolio and workspace

- Event identity, venue, dates, timezone, lifecycle, owner, capacity, ticket-provider event ID.
- Tabs for overview, sponsor pipeline, production plan, ticket summary, audience, campaign, budget,
  documents, and close-out.
- Template milestones and readiness checklist; owners and dependencies are visible.

### T2. Ticketing integration

- Configure ticket types, capacity allocations, sale windows, and complimentary categories in the
  chosen provider or link to provider-managed configuration.
- Receive signed webhooks and periodic reconciliation for orders, refunds, cancellations, and
  check-ins.
- Dashboard shows gross sales, ticket count, check-ins, capacity, channel, and last sync.
- Store only the attendee fields with a documented purpose and consent; never store card data.
- Export sponsor-report data using anonymised/aggregated fields by default.

### T3. Sponsor CRM

1. Create organisation/contact and opportunity tied to one or more events.
2. Track stage: `prospect`, `qualified`, `proposal`, `negotiation`, `committed`, `won`, `lost`.
3. Record expected/committed value, currency, probability, owner, next action, and conversation.
4. For won deals, record benefits, deliverables, evidence owner, due dates, and fulfilment status.
5. Close-out produces a sponsor pack with approved reach, attendance, and activation evidence.

### T4. Production management

- Use existing Projects/Tasks/Sprints capabilities through an event-to-project link.
- Templates cover venue, permits, artist contracting/riders, travel, vendors, safety, ticketing,
  marketing, show-day, and close-out.
- External collaborators receive narrow, expiring access.
- Critical overdue dependencies appear in readiness status.

### T5. Campaign calendar and analytics

- Plan channel, content owner, asset, campaign, publish time, status, and sponsor association.
- Publishing stays in an approved social tool; import post/campaign metrics where APIs permit.
- Report metric definitions and collection time to avoid unsupported comparisons.

### T6. Event budget

- Versioned budget lines for sponsorship, ticket revenue, artist fees, venue, production, marketing,
  staffing, and vendors.
- Approval workflow for commitments; import actuals from Group Finance/accounting.
- Compare budget, committed, actual, and variance per category.
- BetaSigma is not the accounting ledger.

## Data model

| Record | Essential fields |
| --- | --- |
| `events` | entity, name, venue, start/end, timezone, owner, capacity, status |
| `ticket_connections` | event, provider, remote event ID, sync status |
| `ticket_orders` / `ticket_summaries` | remote ID, type, quantity, amount, status, consent flags |
| `crm_organizations` / `crm_contacts` | type, owner, contacts, lawful communication status |
| `opportunities` | event, sponsor, stage, values, probability, owner, next action |
| `sponsor_deliverables` | opportunity, obligation, owner, due date, evidence, status |
| `event_participants` | artist/vendor, role, contract/repository reference |
| `campaign_items` | event, channel, publish_at, asset, sponsor, metrics reference |
| `event_budget_versions` / `budget_lines` | event, version, category, budget/commitment/actual |

Reuse existing projects, tasks, assignees, comments, notifications, and notes where suitable.

## Interfaces

- `/app/events` and `/app/events/:id`
- `/app/partnerships/pipeline`
- `/app/events/:id/production`
- `/app/events/:id/tickets`
- `/app/events/:id/campaign`
- `/app/events/:id/budget`
- `/app/events/:id/close-out`

## Integration rules

- Ticket webhooks require signature verification, replay protection, idempotent event IDs, and a
  scheduled reconciliation job.
- CRM imports require deduplication and visible merge decisions.
- Store signed contracts in the group repository and retain only metadata/secure links.
- Social API credentials use delegated accounts, not employee passwords.
- Financial actuals carry ledger source IDs and posted/draft status.

## Acceptance criteria

- Ticket events replay safely and dashboard totals reconcile to the provider for a chosen event.
- Capacity and complimentary allocations are visible without exposing payment data.
- Every active sponsor opportunity has an owner, next action, and dated history.
- Won sponsorships create trackable deliverables and an exportable evidence pack.
- Production readiness identifies overdue critical dependencies.
- Budget variance reconciles to imported accounting actuals.
- Audience exports honor consent, purpose, suppression, and retention rules.
- External collaborators cannot see other events, sponsor values, or finance data.

## Delivery plan

1. Select ticketing provider and define event, audience, consent, and sponsor-report requirements.
2. Build event workspace plus sponsor CRM; connect a pilot event.
3. Link event templates to existing project/task capabilities.
4. Add campaign planning and provider metric imports.
5. Add versioned budgets and finance actuals.
6. Run close-out, data-retention, and sponsor-report review after each pilot.

## Decisions still required

- Which channels (web/mobile/USSD), payment methods, refund rules, fees, and settlement SLA decide
  the ticketing vendor?
- Is one attendee identity needed across events, and what marketing consent wording/retention apply?
- What sponsor stages, probability rules, packages, currencies, and deliverable templates are used?
- Which external collaborators need access and who approves it?
- Which finance dimensions map events and budget categories to the ledger?
- Which social tool owns publishing and which metrics are contractually promised to sponsors?

## Out of scope for MVP

Building a payment gateway, ticket barcode engine, reserved-seat map, social publishing network,
full accounting ledger, artist marketplace, or automated sponsor valuation.
