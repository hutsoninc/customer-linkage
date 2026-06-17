# Customer Linkage & Data Quality — Executive Summary

**Date:** June 17, 2026 • **Prepared for:** Scott Miller • **Prepared by:** Austin Gordon

## What This Is and Why It Matters

We are formally linking Hutson's customer accounts in EQUIP to John Deere's Customer Registry — the connective tissue across JD's entire ecosystem. The entity ID is the bridge that ties our dealer data to Deere's, and that connection unlocks a broad network of JD applications, datasets, and partner integrations: Sales Center, Service Center, Rewards, Operations Center, Equipment Mobile, CLG lead scoring, and third-party vendors like EDA. Without linkage, our customer records are isolated to our own systems. With it, we thread Hutson's data into Deere's and gain access to everything built on top of it.

Beyond tool access, this project is addressing data quality issues — duplicates, missing fields, stale records, mismatched accounts — that have been a friction point for years. The infrastructure we're building also gives us automated lead processing, a weekly data quality dashboard, and a foundation for future projects.

This work is also SMO migration preparation. Getting Salesforce clean and enriched before we move to SMO and CI&J is the right call regardless of timeline — and Prospect records are a priority since they exist only in Salesforce, not in EQUIP, and need to be evaluated before they carry into the next system.

## Project Halo — External Mandate

JD is formalizing linkage as a requirement under Project Halo, which connects to our Dealer Capabilities Expectations and DOT scorecard:

| Year | Requirement |
|---|---|
| 2027 | 25% of accounts linked to JD Registry |
| 2028 | 80–90% of accounts linked |

**Where we stand today:**

| Metric | Count |
|---|---|
| Active EQUIP contacts | ~549,000 |
| Linked at project start (April 2026) | ~59,000 — ~11% |
| Current linkage | **~80,000 — ~15%** |
| Gap to 25% target | ~57,000 additional |

*Note: JD has not yet formally defined the measurement methodology — denominator (all contacts vs. recently transacted vs. other) is unconfirmed. Numbers above are directional estimates assuming all active contacts as the base.*

We are ahead of most dealers in both progress and tooling, and are working directly with JD teams to align on standards and push for improvements on their end — the Dealer Data Lake team has shared our work internally and we've received inbound contacts from JD staff following our approach.

## What We've Accomplished

| Milestone | Impact |
|---|---|
| **Data quality reporting** | Weekly Power BI dashboard tracking 140 metrics across 549K contacts — linkage, completeness, field quality, parity, staleness |
| **Quick win linkages** | 20,000+ accounts formally linked using already-known entity IDs |
| **Salesforce duplicate merges** | 14,500+ Prospect accounts merged into Customer records; automated merge tooling built for ongoing use |
| **JDSO field parity corrections** | 450+ field-level mismatches corrected; nickname sync issues submitted to JD as a ticket; enhancement requests submitted for JDSO and SMO |
| **EDA buyer ID dataset** | Pushed JD's DDL team to publish EDA buyer ID → entity ID mappings for all dealers; 136,000+ relationships now accessible — enables UCC filing data to be joined to our accounts |
| **JD partnership** | Sessions with DDL, DDH, CSC/Linkage, and Shop.deere.com; JD mentioned our cleanup work at the June 3rd capabilities meeting and has begun work on a dealer linkage playbook based on our recommendations |
| **CLG lead automation** | 1,574 very-high-probability leads staged with routing, suppression, and Salesforce load logic — **$78M in identified opportunity** *(pending Shane and Reagan approval)* |

## Roadmap

Work is being done in bulk first — linkages, merges, and data corrections are handled programmatically at scale with validation before anything is accepted. Once the bulk phase and playbooks are complete, the team takes over ongoing manual cleanup using documented processes. The goal is a proactive, repeatable approach to data quality that doesn't require starting from scratch.

| Group | Phase | Status |
|---|---|---|
| **Foundation** | Data Quality Reporting | Complete |
| | Quick Win Linkages | Complete |
| | Bulk EQUIP Data Cleanup + Field Parity | In Progress |
| | Salesforce Cleanup | In Progress |
| | Bulk Linkage Upload *(closes Project Halo gap)* | Starting soon |
| | JD Partnership & Standards | Ongoing |
| | Documentation & Playbooks | Ongoing |
| **Enrichment** | CRM Enrichment *(segmentation, sales history, UCC data, deep links)* | Future |
| | EQUIP Enrichment *(Registry contact data backfill, Salesforce Prospect sync)* | Future |
| | Expert Connect Contact Enrichment | Future |
| | Operations Center Org Mapping | Future |
| | Machine Data Quality & Cleanup | Future |
| **Leveraging Data** | CLG Lead Automation | In Progress |
| | Marketing & Sales Automation *(warranty, PIP, EDA/UCC lost sale alerts, replacement scoring, opportunity surfacing for CAMs)* | Future |
| **Ongoing Maintenance** | Automated operations *(merge monitoring, CAM auto-assignment, account management automations)* | Future |
| | Machine ownership & AOR maintenance *(out-of-AOR transfers, marketplace flagging, scrap/junk cleanup)* | Future |
| | Team-driven manual cleanup & process updates | After bulk phase |
