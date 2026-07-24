# Sichangi Law Alliance Legal Operations Implementation Guide

**Source:** `PRD/SLA.docx`  
**Business owners:** Edith Nyatigo and Vivian Mukire  
**Source date:** 7 July 2026  
**Status:** All submitted requirements were marked high priority

## Outcome

Provide dependable infrastructure and a secure matter-centric workspace for legal work: cases,
clients, documents, deadlines, time, billing handoff, and client communication. The first release
must reduce operational and confidentiality risk before pursuing advanced document automation.

## Current state and gaps

- Existing services include corporate email, e-filing, Ardhisasa, and iTax.
- The firm lacks fit-for-purpose laptops/desktops, reliable internet/network equipment, maintained
  printing, and an assured backup system.
- Matters and documents are not centrally managed.
- There is no company website or coordinated social presence.
- The source benchmarks iManage, Litera, HighQ, and Elite 3E as capability references; these are
  not vendor selections.

## Product boundary and delivery strategy

Infrastructure and data protection are prerequisites. Build a focused matter workflow in
BetaSigma, but integrate a proven document repository, email, backup, and accounting solution.
Specialist legal tools should be procured only after workflow and security discovery.

## Users and ethical boundaries

| Role | Access |
| --- | --- |
| Partner | Authorized matters, approvals, financial and workload summaries |
| Advocate | Assigned matters, documents, tasks, time, client communications |
| Paralegal | Assigned matter operations under configured restrictions |
| Finance | Billing/time exports and financial metadata, not privileged content by default |
| Client | Explicitly published portal items for their matter only |
| Records/admin | Filing and retention; content access only when authorized |
| IT admin | Technical administration without automatic matter-content access |

Use matter teams and ethical walls. Firm-wide role alone must never grant access to every matter.

## MVP scope

### L1. Client and matter intake

- Create individual or organisation clients with contacts and identifiers.
- Run a documented conflict-search workflow before opening a matter.
- Capture practice area, responsible partner, team, status, confidentiality class, opening date,
  billing arrangement, and key parties.
- A partner approves matter opening; rejected/duplicate intake remains auditable.

### L2. Matter workspace

- Overview, team, tasks, key dates, activity, related parties, documents, time, and notes.
- Calendar reminders for court dates, filing deadlines, limitation dates, and client commitments.
- Reusable matter templates create standard tasks without replacing legal judgment.
- Full-text search respects ethical walls and document permissions.

### L3. Document and email management

- Store documents in an approved encrypted repository; BetaSigma stores metadata and secure links.
- Capture matter, document type, author, version, privilege class, status, and retention rule.
- Check-in/check-out or collision-safe versioning; no silent overwrite.
- File selected emails and attachments to a matter with sender, recipients, and sent time.
- Generate tamper-evident audit history for view, download, upload, share, and delete events.

### L4. Time and billing handoff

- Record date, matter, activity, narrative, duration, billable state, and rate reference.
- Submit time for review and lock approved periods.
- Export approved entries to the authoritative finance/practice-management system.
- Do not build trust accounting in MVP.

### L5. Client portal

- Invite named client contacts with MFA.
- Publish selected documents, updates, requests, and messages—nothing is shared by default.
- Expiring download links, revocation, access audit, and clear client/matter branding.

### L6. Public website

- Accessible pages for profile, practice areas, team, insights, contact, and required notices.
- Content approval and publishing workflow; spam-protected enquiries route to an owned mailbox/CRM.
- No confidential matter data shares infrastructure or public routes with the website.

## Data model

| Record | Essential fields |
| --- | --- |
| `legal_clients` / `client_contacts` | entity, type, names, contacts, restricted identifiers |
| `matter_intakes` | requester, prospective client, parties, conflict status, decision |
| `matters` | client, number, title, practice, partner, status, confidentiality, billing terms |
| `matter_memberships` | matter, user, role, access dates |
| `matter_parties` | matter, party name, relationship, aliases |
| `matter_deadlines` | matter, type, due_at, owner, source, completion |
| `legal_documents` | matter, repository ID, version, class, privilege, retention |
| `time_entries` | user, matter, date, minutes, narrative, rate reference, approval |
| `portal_publications` | matter, resource, client contact, published/revoked times |

## Interfaces

- `/app/legal/intake`
- `/app/legal/matters` and `/app/legal/matters/:id`
- `/app/legal/calendar`
- `/app/legal/time`
- `/app/legal/search`
- `/client/matters/:id` — isolated client portal
- Public website routes outside authenticated application scopes

## Infrastructure work package

- Inventory users, devices, network coverage, printers, and current data locations.
- Procure managed business laptops with disk encryption, endpoint protection, screen lock, and
  remote wipe.
- Install redundant business internet where feasible, managed firewall/Wi-Fi, and guest isolation.
- Define 3-2-1 backup coverage for repository, Microsoft 365/email, and application data; test
  restores and record recovery time/recovery point objectives.
- Repair or replace printers and require secure print/release for sensitive output where practical.

## Security and compliance

- MFA for all users and stronger controls for external portal access.
- Matter-level authorization on every query and background job.
- Encryption in transit/at rest, malware scanning, data-loss controls, session expiry, and remote
  access policy.
- Preserve legal holds; block disposal while a hold applies.
- Obtain Kenyan legal/privacy professional review for retention, client confidentiality, hosting,
  breach response, and electronic signatures.
- No client data may be sent to generative AI without an approved policy and technical safeguards.

## Acceptance criteria

- Unauthorized staff cannot discover a restricted matter through search, URLs, exports, or alerts.
- A matter cannot open until the configured conflict decision and partner approval exist.
- Document versions and access history are recoverable and exportable.
- Only explicitly published resources appear in a client's portal.
- A restored backup meets the agreed recovery objective in a witnessed test.
- Approved time exports once, with stable remote references and reconciliation totals.
- The public site passes accessibility, responsive, security-header, and enquiry-routing checks.

## Delivery plan

1. Infrastructure/security audit and emergency backup coverage.
2. Matter taxonomy, ethical-wall rules, conflict workflow, and repository/vendor decisions.
3. Pilot intake, matter workspace, deadlines, and document metadata with a small matter set.
4. Migrate active matters after deduplication and access review.
5. Add time export, client portal, and public website as separately tested releases.
6. Evaluate advanced comparison, drafting, automation, and practice management after adoption.

## Decisions still required

- Which repository and email platform are authoritative, and is iManage/HighQ-scale tooling viable?
- What conflict-search data, approval, waiver, and audit rules apply?
- What matter numbering, practice areas, retention schedules, and legal-hold procedure are required?
- Which finance system receives time and billing data?
- What hardware quantities/specifications, internet SLA, backup objectives, and budget are approved?
- Who owns website content, legal notices, enquiry response, and publishing approval?

## Out of scope for MVP

Automated legal advice, court/e-filing automation, trust accounting, AI drafting, automated conflict
decisions, and wholesale replacement of specialist document-management software.
