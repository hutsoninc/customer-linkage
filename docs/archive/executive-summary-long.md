# Customer Linkage & Data Quality — Executive Summary

**Prepared for:** Scott  
**Date:** June 2026  
**Prepared by:** Austin Gordon

---

## What This Is and Why It Matters

We are formally linking Hutson's customer accounts in EQUIP to John Deere's Customer Registry. This linkage is how our dealership number appears in JD's sales tools — Sales Center, Rewards, and Service Center — making each customer's equipment history, financing, and warranty data navigable from our context.

Beyond the tool integrations, this project addresses data quality issues (duplicates, missing fields, stale records, and mismatched accounts) that have been a friction point for years and that are now blocking us from doing more with JD's data. The same infrastructure we're building to link accounts also gives us a weekly data quality report, automated lead processing, and a foundation for future projects.

---

## Project Halo — External Mandate

John Deere is formalizing linkage as a dealer requirement under **Project Halo**, which also connects to our Dealer Capabilities Expectations and Dealer of Tomorrow scorecard. Hard targets have been communicated for:

| Year | Requirement |
|---|---|
| 2027 | 25% of accounts linked to JD Registry |
| 2028 | 80–90% of accounts linked |

> **Note:** JD has not yet formally defined the measurement methodology for these targets — it is unclear whether the denominator is all active accounts, accounts transacted within a certain time window, or another population. The numbers below assume all active EQUIP accounts as the base and should be treated as directional estimates until JD publishes the official calculation.

**Where we stand today (estimated):**

| Metric | Count |
|---|---|
| Active EQUIP contacts | ~549,000 |
| Linked at project start (April 2026) | ~59,000 — **~11%** |
| Added through project work (project-attributed) | ~20,000+ |
| Estimated current linkage | **~80,000 — ~15%** |
| Gap to 25% target (assumes all active contacts as base) | ~57,000 additional |

We are ahead of most dealers in both progress and tooling. Several JD teams — including the Dealer Data Lake team — have shared our work internally and we've received inbound contacts from JD staff watching our approach.

---

## What We've Accomplished

| Date | Milestone | Impact |
|---|---|---|
| May 2026 | **Data quality reporting live** | Weekly Power BI dashboard tracking 140 metrics across 549K contacts — linkage coverage, completeness, field quality, Registry parity, account staleness |
| May–June 2026 | **Quick win linkages complete** | 20,000+ accounts formally linked using known entity IDs — no matching required |
| June 2026 | **Salesforce duplicate merges** | 14,500+ Prospect accounts merged into Customer records; automated merge tooling built with field-level rules and a recovery snapshot for ongoing use |
| June 2026 | **JDSO field parity corrections** | 450+ field-level mismatches corrected; nickname field sync issues identified and submitted to JD as a ticket for correction; several enhancement requests submitted to improve the JDSO and SMO interfaces; weekly parity tracking notebook live |
| June 2026 | **JD partnership meetings** | Individual sessions with Dealer Data Lake, Dealer Data Hub, CSC/Linkage, and Shop.deere.com teams; leadership meeting with JD on June 3rd; JD has begun work on a dealer linkage playbook — a direct result of suggestions made across these sessions |
| June 2026 | **CLG lead automation — first pass** | 1,574 very-high-probability leads staged with routing, suppression, and Salesforce load logic; **$78M in identified opportunity** — pending Shane and Reagan approval |

---

## Roadmap

### Foundation (In Progress)

| Phase | Description | Status | Est. Timeline |
|---|---|---|---|
| 0 | Data Quality Reporting | ✅ Complete | Done |
| 1 | JD Partnership & Standards | 🔄 Ongoing | Continuous |
| 2 | Quick Win Linkages | ✅ Complete | Done |
| 3 | Bulk EQUIP Data Cleanup + Field Parity | 🔄 In Progress | ~2–3 months |
| 4 | Bulk Linkage Upload (closes Project Halo gap) | ⏳ Starting soon | ~2–4 months |
| 5 | Salesforce Cleanup (remaining merges + orphaned leads) | 🔄 In Progress | ~1–2 months |
| 6 | Documentation & Playbooks (parallel) | 🔄 Ongoing | Parallel |
| 7 | CLG Lead Automation | 🔄 First pass built | Pending approval |
| 8 | EQUIP Customer Deduplication | ⏳ After Phase 4 | ~2 months |

### Enrichment & Integration (Future)

| Phase | Description |
|---|---|
| 9 | Operations Center Org Mapping |
| 10 | Expert Connect Inbound Call Enrichment |
| 11 | CRM Enrichment (sales history, UCC data, deep links) |
| 12–13 | Machine Data Quality & Cleanup |

### Leveraging the Data (Future)

| Phase | Description |
|---|---|
| 14 | Marketing & Sales Automation (warranty, PIP, replacement campaigns) |
| 15 | EDA / UCC Lost Sale Alerts |
| 16 | Opportunity Mining & Surfacing Tools for CAMs |

---

## Business Value in Action — CLG Lead Automation

As a proof of concept for how this data foundation pays off: using Registry linkage and our quote/sales history, we built an automated pipeline that ingests JD-generated equipment leads, suppresses duplicates, routes each lead to the right account owner, and stages them for Salesforce with opportunity dollar estimates attached.

**First pass results (very high probability to purchase):**
- **1,574 leads identified**
- **$78M in total opportunity dollars**
- Pending Shane and Reagan's review and approval to move forward

Once approved, this runs weekly/monthly — automatically surfacing new leads as they are scored by JD and loading them into Salesforce for CAM action. This is one of several downstream capabilities that only become possible once the linkage and data quality foundation is in place.

---

## JD Partnership — Where We Stand

We have been working directly with several John Deere product and data teams — not just consuming their tools, but influencing how those tools work and how JD thinks about dealer linkage at the program level.

**Meetings held:**

- **Dealer Data Lake & Dealer Data Hub PMs** — Demonstrated our Power BI data quality reports, our bulk update methodology, and our plans for linkage at scale. Gathered feedback on approach and gave suggestions for how their teams can actively support dealers on this work. The DDL team had dealer linkage improvement on their own roadmap and were enthusiastic about our reporting — they shared recordings of our session internally and we've since received inbound contacts from JD staff who watched.

- **Vicky, Common Search Component & Linkage PM** — Discussed the project in full, received guidance on how JD expects linkages to be structured (including clarifying acceptable linkage types for business contacts), and gave feedback on improvements to the Common Search Component and the case for a formal dealer linkage playbook.

- **Cindy, Shop.deere.com** — Discussed how Digital User Accounts link to Registry entities and the downstream side effects of different linkage types. Gave suggestions for updating Shop.deere.com and the Common Search Component — which surfaces throughout Sales Center, Service Center, and other JD applications — to display which Digital User Accounts are associated with each entity. This would help dealers debug access issues and identify linkage problems without needing to escalate tickets.

- **Leadership meeting with John Deere, June 3, 2026** — Our leadership team met with JD to discuss Dealer Capabilities Expectations and the Dealer of Tomorrow scorecard. During that meeting, JD specifically mentioned Hutson's data cleanup efforts and the playbook concept. JD indicated they are planning to work on a dealer linkage playbook — a direct result of suggestions raised across our team sessions.

The relationship is bidirectional: we are confirming that our approach aligns with JD's standards while simultaneously pushing for JD-side improvements — system updates, shared documentation, and enrichment opportunities — that benefit not just Hutson but the dealer network as a whole.

---

## How We Operate

The project runs in two modes:

1. **Bulk automation** — everything that can be fixed at scale (linkages, merges, data corrections) is being handled programmatically with validation and reconciliation checks before any change is accepted
2. **Playbook-guided maintenance** — once the bulk cleanup and documentation work is complete, the team will take over ongoing manual cleanup using the processes we've developed; the goal is a repeatable, proactive approach to data quality that doesn't require starting from scratch each time

Manual cleanup is intentionally deferred until the bulk phase is done and playbooks are in place. This ensures the team has clear, documented processes to follow rather than working without a defined standard — and that the highest-volume issues are already resolved before any manual effort begins.

We are also working with JD directly to align on what correct linkage looks like, push for improvements on their end (Sales Center updates, Digital User Account visibility, parent account hierarchy), and position ourselves well ahead of the Project Halo targets.
