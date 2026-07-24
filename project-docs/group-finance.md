# Group Finance Implementation Guide

**Source:** `PRD/BSC_Technology_Requirements.docx`  
**Business owner:** Mutethia Raymond Nkinduku, Finance  
**Source date:** 6 July 2026  
**Status:** Discovery baseline; validate assumptions before implementation

## Outcome

Give Group Finance reliable bookkeeping, financial reporting, controlled petty cash, and a secure
place for finance documents across subsidiaries. The application should provide group visibility
without attempting to recreate a regulated accounting ledger or payment network.

## Current state and pain points

- Tukutane uses QuickBooks; some subsidiaries have no accounting system.
- Bookkeeping may be manual and financial reports depend on desktop QuickBooks availability.
- Finance documents live on personal phones and laptops.
- Petty-cash requests, approvals, disbursements, and reconciliation have no standard workflow.
- Current tools include QuickBooks, Workpay, Microsoft 365, WhatsApp, and spreadsheets.

## Product boundary

### Integrate or procure

- A supported QuickBooks edition or equivalent ledger remains the accounting system of record.
- Popote Pay, Boya, Sava, or another approved provider executes petty-cash payments.
- Microsoft 365/SharePoint, S3-compatible storage, or another approved repository stores files.

### Build in BetaSigma

- A group dashboard showing entity-level sync status and approved financial summaries.
- Petty-cash request, approval, disbursement tracking, receipt capture, and reconciliation.
- Document indexing, permissions, retention metadata, and links to the chosen repository.
- Integration monitoring, exception queues, and a complete audit trail.

Do not build double-entry accounting or hold funds in the first release.

## Users and access

| Role | Capabilities |
| --- | --- |
| Requester | Submit a petty-cash request, attach evidence, view own requests |
| Approver | Approve/reject within delegated limits; cannot approve own request |
| Finance officer | Disburse, reconcile, export, manage finance documents |
| CFO/Group finance | Cross-entity dashboard, policy and approval-limit management |
| Auditor | Read-only records, attachments, history, and exports |
| System admin | Configure access and integrations; no implicit approval rights |

All records are scoped to a subsidiary. Cross-entity access must be explicitly granted.

## MVP scope

### F1. Entity-aware finance workspace

- Select an entity and period; show connection health, unreconciled items, pending approvals, and
  latest imported summary.
- Prevent users from querying entities outside their grants.
- Label data with source, sync time, currency, and whether it is draft or posted.

### F2. Petty-cash workflow

1. Requester enters entity, cost centre, purpose, amount, required date, and attachments.
2. The policy engine selects approver(s) from amount and entity rules.
3. Approvers approve, reject, or return with a reason.
4. Finance sends the approved payment through a provider or records a manual disbursement.
5. Requester uploads receipt and actual spend.
6. Finance reconciles the item and records refund or top-up differences.

Statuses: `draft`, `submitted`, `approved`, `rejected`, `disbursing`, `paid`, `evidence_due`,
`reconciled`, `cancelled`, `failed`.

### F3. Accounting synchronisation

- Map entity, account, tax code, vendor, project/event, and cost centre identifiers.
- Push only approved/reconciled transactions after finance review.
- Store the remote ID and immutable request hash to prevent duplicates.
- Pull summary balances or reports supported by the selected accounting API.
- Put failures into a visible queue; never silently discard an integration error.

### F4. Finance document register

- Store metadata for invoices, receipts, statements, reports, and supporting evidence.
- Support entity, period, vendor, document type, tags, owner, retention date, and access class.
- Virus-scan uploads and use time-limited download URLs.

## Data model

| Record | Essential fields |
| --- | --- |
| `entities` | name, code, legal name, base currency, status |
| `entity_memberships` | entity, user, finance role |
| `petty_cash_requests` | entity, requester, amount, purpose, cost centre, status, required date |
| `approval_steps` | request, sequence, approver, decision, reason, decided_at |
| `disbursements` | request, provider, remote_id, amount, recipient, status, idempotency_key |
| `reconciliations` | request, actual_amount, variance, reconciled_by, reconciled_at |
| `finance_documents` | entity, storage_key, type, period, tags, classification |
| `integration_connections` | entity, provider, encrypted credentials reference, status |
| `sync_runs` | connection, direction, started_at, result, counts, error summary |

Money uses fixed-precision decimal values plus ISO currency codes.

## Interfaces

- `/app/finance` — group/entity dashboard
- `/app/finance/petty-cash` — queue and filters
- `/app/finance/petty-cash/:id` — request, decisions, payment, evidence, audit
- `/app/finance/documents` — document register
- `/app/finance/integrations` — admin connection and sync health
- `/app/finance/reports` — exportable operational summaries

## Security and controls

- Maker-checker separation: a requester cannot approve or reconcile their own item.
- Configurable approval limits, with all policy changes versioned.
- Encrypt integration secrets outside the database where possible.
- Audit create, submit, approve, reject, pay, reconcile, export, view-sensitive-document, and
  permission changes.
- Mask bank/mobile-money details and minimize personal data.
- Define retention and backup recovery objectives with Finance.

## Acceptance criteria

- A request follows the correct approval chain for its entity and amount.
- Self-approval and out-of-scope entity access are blocked and tested.
- Retried payment/accounting jobs do not create duplicate remote transactions.
- Finance can trace a reconciled item from request through approval, payment, receipt, and ledger ID.
- CFO can see last-sync time and failures per entity.
- An auditor can export a period with decisions and evidence without edit access.

## Delivery plan

1. **Discovery and vendor selection:** confirm entities, chart-of-accounts approach, approval matrix,
   QuickBooks deployment/API availability, payment providers, and storage.
2. **Foundation:** entity access, audit events, document metadata, integration adapters.
3. **MVP:** petty cash from request through manual disbursement and reconciliation.
4. **Integration:** enable one payment provider and one accounting entity, then pilot.
5. **Rollout:** add remaining entities, reporting, retention, and operational support.

## Decisions still required

- Which QuickBooks product and deployment is authoritative for each entity?
- Which payment provider passes Finance, security, pricing, and API due diligence?
- What are approval thresholds, cost centres, currencies, and reconciliation SLAs?
- Must documents remain in Microsoft 365, or may the app use object storage?
- Which reports require posted ledger data versus operational workflow data?

## Out of scope for MVP

General ledger construction, tax filing, payroll calculation, bank reconciliation engine, lending,
card-data storage, and autonomous payment approval.
