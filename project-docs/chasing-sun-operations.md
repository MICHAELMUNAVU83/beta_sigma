# Chasing Sun Agribusiness and IoT Implementation Guide

**Source:** `PRD/Chasing Sun X BSC_Technology_Requirements_Form .pdf`  
**Business owner:** Josiah Stanley  
**Source date:** 4 July 2026  
**Business:** Horticulture production in Naivasha and B2B commodity trade in East Africa

## Outcome

Give management reliable financial and document visibility, then extend the existing farm
dashboard with trustworthy greenhouse telemetry for soil moisture, humidity, temperature, and wind
speed. The solution should connect systems of record rather than create a second accounting ledger.

## Current state and priorities

- Outlook, WhatsApp, Microsoft Office, Adobe Acrobat, Claude, and ChatGPT are in use.
- Revenue and expenses are spread across spreadsheets; invoices and delivery notes are manual.
- Department documents live on employee computers.
- An existing dashboard tracks planting, greenhouse productivity, and weekly revenue collection.
- **High:** finance system. **Medium:** central documents and greenhouse IoT. Hardware requests for
  marketing microphones and a replacement phone are not urgent in the source.

## Product boundary

- QuickBooks or an approved alternative owns accounting entries, invoices, and official reporting.
- An approved repository owns document binaries and versions.
- IoT gateways/platform services own device connectivity and buffering.
- BetaSigma supplies management views, workflow, access, integration health, and the unified link
  between farms, greenhouses, crops, telemetry, documents, and finance references.

Do not replace the existing dashboard until its code, data model, hosting, ownership, and API have
been assessed.

## Roles

| Role | Capabilities |
| --- | --- |
| Farm operator | View assigned greenhouse conditions, acknowledge alerts, record observations |
| Agronomist | Configure agronomic thresholds, annotate events, review crop/telemetry trends |
| Operations | Orders, delivery notes, stock/fulfilment references, operational documents |
| Accountant | Accounting sync, invoices, expense/revenue classification, exceptions |
| Executive | Read-only financial and production summaries across permitted operations |
| IoT technician | Device provisioning, calibration, maintenance, connectivity health |
| Records admin | Repository taxonomy, access, retention |

## Phase 1: finance and documents

### C1. Accounting integration

- Configure company, currency, accounts, customers, suppliers, items, taxes, and tracking dimensions.
- Generate invoices and delivery notes in the accounting/approved document system; surface their
  status and secure links in BetaSigma.
- Import daily/weekly/monthly revenue and expense summaries with last-sync and source status.
- Use stable remote IDs and idempotency keys; Finance resolves mapping and sync exceptions.
- Separate commodity and horticulture reporting while permitting a consolidated executive view.

### C2. Document workspace

- Department/farm folders plus metadata for type, owner, entity, counterparty, crop/event, date,
  confidentiality, and retention.
- Role-based access, document versions, audit events, full-text search, and recovery.
- Migrate from employee computers through inventory, deduplication, classification, owner review,
  and verified backup—not a blind bulk upload.

## Phase 2: greenhouse telemetry

### C3. Device and location registry

- Model farms, blocks, greenhouses, zones, sensors, gateways, installation position, serial number,
  firmware, calibration, and service state.
- Maintain sensor history when devices move or are replaced.

### C4. Telemetry ingestion

1. Sensor sends measurement to a gateway over an appropriate local protocol.
2. Gateway timestamps/buffers data and publishes through authenticated MQTT or vendor API.
3. Ingestion validates device, unit, time, range, and duplicate message ID.
4. Store raw immutable measurement, then compute aggregates.
5. Update dashboard and evaluate alerts.

Canonical measurements include soil moisture, relative humidity, air temperature, and wind speed.
Every value carries unit, observed time, received time, sensor ID, and quality flag.

### C5. Monitoring and alerts

- Greenhouse overview shows latest values, freshness, trends, device health, and active alerts.
- Thresholds are versioned by greenhouse/crop stage and approved by an agronomist.
- Alerts include severity, duration/debounce, recipient, acknowledgement, escalation, and resolution.
- Missing/offline data is distinct from a normal reading.
- Alerts advise humans in MVP; they do not autonomously control irrigation or climate equipment.

## Data model

| Record | Essential fields |
| --- | --- |
| `farms` / `greenhouses` / `zones` | hierarchy, location, timezone, status |
| `crop_cycles` | location, crop/variety, planted/expected harvest dates, status |
| `devices` | hardware ID, type, model, firmware, location, installed_at, state |
| `calibrations` | device, time, method, result, technician, next due |
| `measurements` | device, metric, decimal value, unit, observed_at, received_at, quality |
| `alert_rules` | scope, metric, operator, threshold, duration, severity, effective dates |
| `sensor_alerts` | rule, start/end, state, acknowledgement, resolution note |
| `accounting_mappings` / `sync_runs` | local/remote IDs, direction, status, errors |
| `business_documents` | repository ID, department, type, classification, retention |

For telemetry volume, evaluate PostgreSQL partitioning or TimescaleDB after sampling rate and
retention are known; do not choose solely from the PRD.

## Interfaces

- `/app/chasing-sun` — executive operations overview
- `/app/chasing-sun/finance` — summaries, documents, and sync exceptions
- `/app/chasing-sun/farms/:id`
- `/app/chasing-sun/greenhouses/:id` — current values, trends, crop cycle, alerts
- `/app/chasing-sun/devices` — provisioning, health, calibration
- `/app/chasing-sun/alerts`
- Extend or embed in `dashboard.chasingsun.africa` only after architecture review

## Reliability and security

- Device identity uses per-device/gateway credentials, rotation, and revocation.
- Buffer during connectivity loss and safely replay with duplicate protection.
- Monitor ingestion lag, impossible values, sensor drift, battery, and gateway availability.
- Define sampling, aggregation, raw retention, uptime, and acceptable staleness.
- Test backup/restore for business records and configuration; raw telemetry may use a tiered policy.
- Network-segment IoT devices; they must not share unrestricted office or finance access.
- Disclose AI data-use rules and prohibit confidential/business data in unapproved accounts.

## Acceptance criteria

- Executives view source-labelled financial summaries by horticulture/commodity and period.
- Invoice/delivery-note links reconcile to the accounting system and duplicate sync is prevented.
- Authorized users find migrated documents without accessing another department's restricted files.
- Pilot measurements retain correct units, device, timestamps, and quality state through outage replay.
- Dashboard marks stale/offline sensors and never represents missing data as normal.
- Threshold breach creates one debounced alert, records acknowledgement/escalation, and closes cleanly.
- Calibration and device replacement preserve historical traceability.
- A pilot demonstrates acceptable coverage and data completeness before fleet rollout.

## Delivery plan

1. Audit existing dashboard, spreadsheets, document locations, connectivity, power, and greenhouse
   layout.
2. Select/configure accounting and repository; migrate one period/department and reconcile.
3. Run an IoT site survey and bench-test sensor/gateway candidates.
4. Pilot one greenhouse with agreed sampling, thresholds, and manual reference readings.
5. Review accuracy, reliability, agronomic usefulness, security, and operating cost.
6. Roll out in stages with spares, calibration schedule, ownership, and support runbook.

## Decisions still required

- Who owns and supports the existing dashboard, and what API/database access is available?
- Which accounting edition, invoice/delivery-note template, currencies, taxes, and reporting
  dimensions are required?
- Which repository and department access/retention taxonomy will be used?
- What greenhouse count/size, power, connectivity, sensor ranges/accuracy, sampling, and budget apply?
- Who defines thresholds and escalation contacts for each crop stage?
- What happens operationally when a sensor, gateway, internet link, or dashboard is unavailable?
- What specifications and budget apply to microphones and the replacement phone?

## Out of scope for MVP

Autonomous irrigation/climate control, yield prediction, commodity exchange/trading, full inventory
or warehouse management, replacement of the accounting ledger, and unreviewed AI agronomic advice.
