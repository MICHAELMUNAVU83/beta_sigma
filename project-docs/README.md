# PRD Implementation Guides

These guides translate each source file in `PRD/` into a build plan for the BetaSigma
Phoenix/LiveView platform. They are implementation aids, not replacements for the signed source
documents.

| Source PRD | Build guide | HTML view | Recommended product boundary |
| --- | --- | --- | --- |
| `BSC_Technology_Requirements.docx` | [Group Finance](group-finance.md) | [View](html/group-finance.html) | Integrate accounting and payments; build oversight and document workflows |
| `HR.docx` | [Group HR](group-hr.md) | [View](html/group-hr.html) | Integrate Kenya-compliant payroll; build the group employee experience around it |
| `SLA.docx` | [Sichangi Law Alliance](sla-legal-operations.md) | [View](html/sla-legal-operations.html) | Build matter workflow; integrate specialist legal document and finance capabilities |
| `Tukutane_Tech_Requirements.docx` | [Tukutane Entertainment](tukutane-event-operations.md) | [View](html/tukutane-event-operations.html) | Build an operations hub; integrate ticketing, finance, and social publishing |
| `Chasing Sun X BSC_Technology_Requirements_Form .pdf` | [Chasing Sun](chasing-sun-operations.md) | [View](html/chasing-sun-operations.html) | Build a management and telemetry layer; integrate accounting and IoT hardware |

## Shared delivery rules

- Use the existing `BetaSigma.Accounts` authentication and page-permission model.
- Keep LiveViews thin; put business rules in domain contexts.
- Every subsidiary-owned record must include an `entity_id` (or equivalent tenant boundary).
- Use role and record-level authorization, audit sensitive changes, and test cross-entity isolation.
- Prefer adapters around third-party APIs so a vendor can be replaced without rewriting workflows.
- Do not store payment-card data, payroll secrets, or raw credentials in this application.
- Add asynchronous integrations through Oban with idempotency keys, retries, and visible sync status.
- Treat the priorities in each PRD as discovery input; confirm them with the named business owner
  before committing dates or vendors.

## Suggested build order

1. Add a shared `Organizations`/`Entities` domain, audit log, document metadata, and integration
   framework.
2. Implement high-risk shared-service integrations: accounting, payments, HR/payroll, and storage.
3. Deliver the highest-value vertical slice for each subsidiary.
4. Add analytics only after operational data quality and ownership are established.

HTML files are generated from these Markdown sources with:

```sh
ruby scripts/render_project_docs.rb
```
