# Customer Linkage & Contact Cleanup — Project Plan

**Last Updated:** 2026-06-17  
**Project Start:** 2026-04-29  
**Status:** Foundation phases complete and underway; business value proof points in progress

Domain glossary and key terms: [`docs/context.md`](context.md)

---

## Project Overview

Formal linkage between Hutson's EQUIP contacts and John Deere's Customer Registry (CKC) so our DBS number appears in the CSC membership column across all JD sales tools. Registry linkage is the prerequisite for everything downstream — it bridges our account data to JD's equipment history, UCC filings, Operations Center orgs, CLG leads, Expert Connect, and future analytics. Secondary goals: EQUIP data quality, Salesforce duplicate cleanup, and machine data cleanup.

**Two operating modes:**
- **Bulk automation** — what can be fixed at scale using code and scheduled jobs; Austin's primary focus
- **Ongoing maintenance** — team-level manual cleanup guided by playbooks developed during the bulk phase; handed off once processes are documented

---

## Project Halo Context

John Deere is formally requiring dealers to achieve linkage targets under **Project Halo**:

| Year | Requirement |
|---|---|
| 2027 | 25% of accounts linked to Registry |
| 2028 | 80–90% of accounts linked |

Also connects to Dealer Capabilities Expectations and Dealer of Tomorrow scorecard frameworks.

> **Note:** JD has not formally defined the measurement methodology — denominator (all active accounts vs. recently transacted vs. other) is unconfirmed. Numbers below assume all active accounts as the base and are directional until JD publishes the official calculation.

**Current linkage state (2026-06-17 estimate):**

| Metric | Count |
|---|---|
| Active EQUIP contacts | ~549,000 |
| Linked at project start (2026-04-29) | ~59,000 (~11%) |
| Added via project work (project-attributed) | ~20,000+ |
| Estimated current linkage | **~80,000 (~15%)** |
| Gap to 25% target (assumes all active contacts) | ~57,000 additional |

Phase 4 (Bulk Linkage Upload) is the primary lever for closing this gap.

---

## Phase Index

### Foundation

| # | Phase | Status | Est. Effort | Detail |
|---|---|---|---|---|
| 0 | Data Quality Reporting Baseline | ✅ Complete (2026-05-15) | — | [→](phases/phase-0-dq-reporting.md) |
| 1 | JD Partnership & Standards | 🔄 In Progress (ongoing) | Ongoing | [→](phases/phase-1-jd-partnership.md) |
| 2 | Quick Win Linkages | ✅ Complete (~2026-06-10) | — | [→](phases/phase-2-quick-wins.md) |
| 3 | EQUIP Data Cleanup + JDSO Parity | 🔄 In Progress | ~2–3 months | [→](phases/phase-3-equip-cleanup.md) |
| 4 | Bulk Linkage Upload | ⏳ Not Started | ~2–4 months | [→](phases/phase-4-bulk-linkage.md) |
| 5 | Salesforce Cleanup | 🔄 In Progress | ~1–2 months remaining | [→](phases/phase-5-sf-cleanup.md) |
| 6 | Documentation & Playbooks | 🔄 In Progress (parallel track) | Ongoing | [→](phases/phase-6-docs-playbooks.md) |
| 7 | CLG Lead Automation | 🔄 First pass built — pending approval | Medium | [→](phases/phase-7-clg-automation.md) |
| 8 | EQUIP Customer Deduplication | ⏳ Not Started | High / ~2 months | [→](phases/phase-8-equip-dedup.md) |

### Enrichment & Integration

| # | Phase | Status | Est. Effort | Detail |
|---|---|---|---|---|
| 9 | Operations Center Org Mapping | ⏳ Future | TBD | [→](phases/phases-9-13-enrichment.md#phase-9) |
| 10 | Expert Connect Enrichment | ⏳ Future | TBD | [→](phases/phases-9-13-enrichment.md#phase-10) |
| 11 | CRM Enrichment | ⏳ Future | TBD | [→](phases/phases-9-13-enrichment.md#phase-11) |
| 11b | EQUIP Enrichment | ⏳ Future | TBD | [→](phases/phases-9-13-enrichment.md#phase-11b) |
| 12 | Machine Data Quality & Cleanup | ⏳ Future | TBD | [→](phases/phases-9-13-enrichment.md#phase-12) |
| 13 | Auction / Listing Machine Population Sync | ⏳ Future | TBD | [→](phases/phases-9-13-enrichment.md#phase-13) |

### Leveraging the Data

| # | Phase | Status | Est. Effort | Detail |
|---|---|---|---|---|
| 14 | Marketing & Sales Automation | ⏳ Future | TBD | [→](phases/phases-14-16-leveraging.md#phase-14) |
| 15 | EDA / UCC Lost Sale Alerts | 🟡 Dataset ready — pending Phase 4 coverage | TBD | [→](phases/phases-14-16-leveraging.md#phase-15) |
| 16 | Opportunity Mining & Surfacing Tools | ⏳ Future | TBD | [→](phases/phases-14-16-leveraging.md#phase-16) |

### Ongoing Maintenance & Automation

Transitions from bulk-first delivery into sustained operations. Begins after Foundation phases are substantially complete and playbooks are in place.

| Item | Status | Detail |
|---|---|---|
| Automated merge monitoring | ⏳ Future | Continuously bulk-merge flagged prospect/customer pairs as they are identified; route exceptions to manual reviewer |
| CAM auto-assignment | ⏳ Future | New accounts auto-assigned to the salesperson who sold to them based on sales history; see Phase 11 for detail |
| Account management process updates | ⏳ Future | Define and document updated processes for account ownership, creation, and conversion |
| Machine ownership & AOR maintenance | ⏳ Future | Automate out-of-AOR transfer requests (lookup responsible dealer by customer location); scrape marketplace listings to flag machines listed elsewhere and submit transfers with context; manual cleanup for scrapped/junked/off-market units; see Phases 12–13 |
| Team-driven manual cleanup | ⏳ After bulk phase | Reports and issue datasets fed to the team for ongoing one-by-one corrections |

### Future Ideas Backlog

Unscoped candidates — see [`phases/phase-17-future-backlog.md`](phases/phase-17-future-backlog.md).

---

## Completed Milestones

| Date | Milestone | Records |
|---|---|---|
| 2026-04-29 | Project start — linkage baseline captured | 58,328 linked |
| 2026-05-15 | Phase 0 complete — DQ snapshot pipeline + Power BI report live | — |
| 2026-05-19 | Country field bulk cleanup (USA / CANANDA / U.S.A. → US / CA) | 376 |
| 2026-05-26 | Quote-to-sale gap test run (MTD May) | 39 |
| 2026-05-27 | Anvil-only SF customers linked (Phase 2 main run) | 7,263 |
| 2026-05-27 | Orphaned registry linkages cleaned up | 8 deleted / 4 re-linked |
| 2026-06-01 | Quote-to-sale gap full run | 7,408 |
| 2026-06-03 | Email domain typo corrections | 194 |
| 2026-06-03 | Warranty registration linkages | 4,958 |
| 2026-06-06 | SF record type corrections (Prospect ↔ Customer) | 865 |
| 2026-06-06 | SF Prospect → Customer merges, run 1 | 8,808 processed / 6,979 merged |
| 2026-06-08 | SF Prospect → Customer merges, run 2 | 12,522 processed / 7,603 merged |
| 2026-06-09 | SF customers with JD registry linkage not in EQUIP | 413 |
| 2026-06-10 | JDSO field parity corrections | 448 |
| 2026-06-10 | Familiar name parity gap submitted to JD (INC17612795) | 420 submitted |
| 2026-06-10 | JDSO parity notebook live (scheduled weekly) | — |
| 2026-06-16 | CLG lead automation — first pass staged | 1,574 leads / $78M opportunity |

---

## Key Open Decisions

Blocking or shaping upcoming phases. See phase detail files for full context.

| Decision | Affects | Owner |
|---|---|---|
| Inactivation cutoff date (last transaction threshold for stale accounts) | Phase 3 | Austin + leadership |
| C-type linkage level (entity vs. contact level for Business-with-Contact records) | Phase 4 | Austin |
| Employee linkage scope (filter out or link technician/salesperson records) | Phase 4, DQ metrics | Austin |
| Account deactivation approach (what counts as "active" for upload batches) | Phase 4 | Austin + leadership |
| Manual review ownership (~150 SF/cross-ref disagreements, potential match batches) | Phases 4, 8 | TBD — needs an owner |
| Ops Center mapping path (wait for Nevin Kroeker / JD DDL, or pull data ourselves) | Phase 9 | Austin + JD |
| CLG automation approval (1,574 leads / $78M — pending Shane and Reagan) | Phase 7 | Shane / Reagan |

---

## Supporting Docs

| File | Purpose |
|---|---|
| [`docs/context.md`](context.md) | Domain glossary — key terms, systems, and relationships |
| [`docs/update-log.md`](update-log.md) | Chronological log of all bulk data changes and linkage uploads |
| [`docs/data-model.md`](data-model.md) | ERD, table relationships, field semantics |
| [`docs/query-conventions.md`](query-conventions.md) | SQL patterns, critical rules, examples |
| [`docs/research-findings.md`](research-findings.md) | All query blocks, results, and findings |
| [`docs/data-quality-plan.md`](data-quality-plan.md) | DQ snapshot architecture, metric definitions, Power BI structure |
| [`docs/dq-review-notes.md`](dq-review-notes.md) | Metric-by-metric review notes and open action items |
| [`docs/dataset-equip-contact.md`](dataset-equip-contact.md) | EQUIP contact column reference + upload template mapping |
| [`docs/archive/`](archive/) | Originals of replaced documents |
