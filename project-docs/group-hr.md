# Group HR Implementation Guide

**Source:** `PRD/HR.docx`  
**Business owner:** Mary Murimi, Human Resources  
**Source date:** July 2026  
**Coverage:** BeCorp, SLA, Tukutane Entertainment, Chasing Sun, and SandCorp

## Outcome

Create a single, secure group employee experience for 20–50 staff while using a proven
Kenya-compliant platform for payroll and statutory calculations. Leadership needs entity-aware
headcount and payroll visibility; employees need self-service; HR needs consistent workflows and
records.

## Current state and risks

- Payroll, leave, and employee records are maintained in Excel, email, WhatsApp, and physical files.
- Manual statutory deductions and remittances create financial and compliance risk.
- Employees cannot retrieve payslips, request leave, submit expenses, or update details directly.
- Onboarding differs by entity and reporting requires spreadsheet consolidation.
- Working hours, start/end times, and breaks are not captured consistently.
- SLA needs ten business-ready laptops.

## Product boundary

Procure or retain a Kenya-compliant payroll engine such as Workpay or an approved alternative.
That provider owns calculation of PAYE and current statutory deductions, payslip generation, and
salary disbursement. BetaSigma can own the group directory, workflows, employee portal, reporting
layer, and integration orchestration.

Do not encode statutory rates in application code. Import versioned results from the payroll
provider and show the source payroll run.

## Users and permissions

| Role | Access |
| --- | --- |
| Employee | Own profile, documents, payslips, leave, expenses, attendance |
| Line manager | Direct reports, approvals, team calendar; no unnecessary payroll details |
| HR officer | Employee lifecycle, documents, leave administration, reporting |
| Payroll officer | Payroll inputs, validation, provider sync, payroll reports |
| Group HR lead | Cross-entity configuration and analytics |
| Executive | Aggregated approved dashboards only |
| Auditor | Time-bound read-only access to specified records |

Separate HR administration from system administration and log privileged access.

## MVP scope

### H1. Group employee record

- One person record may have multiple employment records over time.
- Employment contains entity, department, manager, job title, location, contract dates, status,
  payroll identifier, and work schedule.
- Sensitive identity, bank, tax, and medical fields use restricted field-level access.
- Bulk import validates duplicates and provides a reversible preview.

### H2. Employee self-service

- View profile and submit controlled change requests.
- Retrieve provider-issued payslips with step-up authentication where appropriate.
- Request leave, see balances, submit expenses, and view request history.
- Display policy documents and acknowledged versions.

### H3. Leave workflow

1. Employee selects leave type and dates.
2. System calculates working days against schedule and holidays.
3. It validates balance, overlap, notice, and attachment rules.
4. Manager approves/rejects; HR handles configured exceptions.
5. Approved leave updates the team calendar and provider where supported.

Support annual, sick, compassionate, maternity/paternity, unpaid, and configurable types without
hard-coding policy.

### H4. Attendance

- Web/mobile clock-in, clock-out, and break events with server timestamps and source.
- Configurable schedules, grace periods, and manager correction requests.
- Keep raw events immutable; corrections are linked adjustments with an audit reason.
- Attendance informs reports but does not automatically reduce pay in MVP.

### H5. Onboarding and offboarding

- Templates per entity/role generate checklists with owners and due dates.
- Capture contract completion, statutory details, policy acknowledgements, equipment, account
  provisioning, and induction.
- Offboarding revokes access, returns assets, records exit documents, and triggers provider updates.

### H6. Payroll integration and analytics

- Send approved employee and variable-input changes to the payroll provider.
- Import payroll-run status, totals, and payslip references.
- Require payroll officer review before final provider submission.
- Report headcount, joins/exits, leave liability, payroll cost by entity, and attendance exceptions.

## Data model

| Record | Essential fields |
| --- | --- |
| `people` | names, contacts, restricted identifiers |
| `employments` | person, entity, manager, role, department, dates, status, payroll_remote_id |
| `leave_types` / `leave_policies` | entity, rules, accrual, evidence, approval path |
| `leave_balances` | employment, type, period, accrued, used, adjusted |
| `leave_requests` | employment, dates, units, status, reason |
| `time_events` | employment, event type, server time, source, device metadata |
| `workflow_templates` / `workflow_tasks` | entity, lifecycle type, owner, due date, completion |
| `employee_documents` | person/employment, class, storage key, access and retention |
| `payroll_runs` | entity, provider ID, period, status, totals, imported_at |
| `assets` / `asset_assignments` | device, serial, custodian, condition, dates |

## Interfaces

- `/app/hr/me` — self-service home
- `/app/hr/team` — manager team, approvals, and calendar
- `/app/hr/people` and `/app/hr/people/:id` — authorized HR directory/profile
- `/app/hr/leave` — requests and administration
- `/app/hr/attendance` — clocking and exceptions
- `/app/hr/onboarding` — lifecycle workflow board
- `/app/hr/payroll` — provider sync and run validation
- `/app/hr/reports` — entity-scoped analytics

## Non-functional and privacy requirements

- Comply with applicable Kenyan employment, tax, and data-protection obligations; obtain counsel
  review before production.
- Encrypt transport, backups, and sensitive fields; use time-limited document URLs.
- Define retention by record type and legal basis, including deletion/anonymisation procedures.
- Record consent or notice where attendance collection requires it.
- Meet agreed payroll cut-off availability and maintain a documented manual fallback.
- Nightly backups plus tested restore drills; audit exports should be tamper-evident.

## Acceptance criteria

- HR imports employees into the correct entities without duplicate identities.
- Employees see only their data; managers see only current direct reports and allowed fields.
- Leave balances use the configured schedule/holiday calendar and all decisions are traceable.
- Raw attendance events cannot be overwritten.
- Payroll totals reconcile to the provider run and no statutory calculation is performed locally.
- Leadership dashboards aggregate approved data while preserving salary confidentiality.
- Offboarding closes sessions and produces an auditable access-removal checklist.

## Delivery plan

1. Select provider and complete privacy/security/API due diligence.
2. Define entities, job structure, policies, payroll calendar, and data migration ownership.
3. Deliver directory, self-service, leave, and provider identity mapping.
4. Pilot payroll sync in parallel with the current process for at least one agreed cycle.
5. Add attendance and onboarding; issue and inventory SLA laptops.
6. Add approved analytics after data reconciliation.

## Decisions still required

- Is Workpay the selected provider, and which modules/API operations are contracted?
- Which statutory term replaces legacy `NHIF` references in current operations, and how does the
  provider evidence current compliance?
- What are entity-specific leave policies, working schedules, holidays, and approval chains?
- Is location/device data permitted for time tracking, and what is its retention period?
- Which documents require electronic signature and which storage system is authoritative?
- What is the device specification, budget, ownership, and support plan for the ten SLA laptops?

## Out of scope for MVP

Building a payroll/tax engine, biometric surveillance, automated disciplinary decisions,
recruitment ATS, performance scoring, and cross-border employer-of-record functionality.
