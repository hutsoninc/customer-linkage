# Phase 1 — JD Partnership & Standards

**Status:** 🔄 In Progress (ongoing)  
**Effort:** Ongoing | **Risk:** Low | **Dependency:** None

**Goal:** Align with John Deere on linkage standards, data models, and system relationships. Surface JD commitments to support our work, influence JD's product roadmap in areas that affect us, and establish a shared playbook for how linkage should work across Hutson and JD systems.

---

## Why This Is Its Own Phase

Most of what blocks or complicates our linkage and data quality work originates on JD's side — incorrect entity IDs in their Registry, gaps in the entity-to-Ops Center mapping, Digital User Account linkage issues, missing data in Sales Center. Working directly with JD teams accelerates our own work and positions us to get improvements made in their systems that we can't fix ourselves. It also ensures we're building toward JD's standards, not against them.

---

## JD Teams Engaged

| Team | Contact(s) | Session Focus |
|---|---|---|
| Dealer Data Lake (DDL) | Nevin Kroeker (PM) | DQ reporting demo, bulk update methodology, Ops Center org mapping |
| Dealer Data Hub (DDH) | PM (name TBD) | Dataset availability, methodology feedback |
| Common Search Component (CSC) & Linkage | Vicky (PM) | Linkage standards, acceptable linkage types, playbook proposal |
| Shop.deere.com | Cindy (PM) | DUA-to-entity linkage, CSC display improvements, access issue debugging |
| Leadership / JD (joint) | — | Dealer Capabilities Expectations, Dealer of Tomorrow scorecard (2026-06-03) |

---

## Key Outcomes So Far

**Dealer Data Lake & Dealer Data Hub (DDL/DDH):**
Demonstrated our Power BI data quality reports, bulk update methodology, and linkage approach. The DDL team had dealer linkage improvement on their own roadmap and were enthusiastic — they shared recordings of our session internally and we've since received inbound contacts from JD staff who watched. Gathered feedback on our approach and gave suggestions for how their teams can actively support dealers. Nevin Kroeker is also building an entity → Ops Center org ID mapping table but is blocked on internal JD permissions (see Phase 9).

**Vicky, CSC & Linkage PM:**
Discussed the full project scope and received guidance on how JD expects linkages to be structured — including confirmation that C-type contacts linked at the entity level is acceptable; Individual contacts linked to a business entity is the real concern. This refined our `type_mismatch_linkage` metric. Gave suggestions for improvements to the CSC and made the case for a formal dealer linkage playbook.

**Cindy, Shop.deere.com:**
Discussed how Digital User Accounts link to Registry entities and the downstream side effects of different linkage types. Customers have lost access to discounts, invoices, and account features on Shop.deere.com because their DUA is tied to a different entity ID than their EQUIP record. Gave suggestions for updating Shop.deere.com and the CSC — which surfaces throughout Sales Center, Service Center, and other JD applications — to display which DUAs are associated with each entity, so dealers can debug access issues without escalating tickets.

**Leadership meeting with JD — 2026-06-03:**
Hutson's leadership team met with JD to review Dealer Capabilities Expectations and the Dealer of Tomorrow scorecard. JD specifically mentioned Hutson's data cleanup efforts and the playbook concept. JD indicated they are planning to work on a dealer linkage playbook — a direct result of suggestions raised across our individual sessions. Our recommendations have already caught traction at the program level.

**EDA buyer ID dataset (direct outcome — unlocks Phase 15):**
Following the DDL meeting, pushed for JD to publish a dataset mapping EDA buyer IDs to Registry entity IDs. JD uses EDA data (UCC filing data) in their CLG lead scoring — each customer in that dataset has a specific EDA buyer ID which JD has mapped to entity IDs. Shortly after the call, JD released this mapping dataset to all dealers via their dealer data product data share. This gives us access to 136,000+ EDA buyer ID → entity ID relationships. With entity ID as the bridge, we can map UCC filing data directly to accounts in our system — enabling lost sale detection (Phase 15) and CRM enrichment with financing activity (Phase 11).

**Parent account hierarchy (discussed — feeds Phase 11):**
Explored getting JD to push parent account relationships (business entity → business contacts) into our CRM so that quotes, activities, and dates roll up to the parent entity. This would allow reporting to treat a business and all its contacts as a single customer for quote coverage and activity tracking accuracy.

**Project Halo context:**
JD is mandating 25% linkage by 2027 and 80–90% by 2028. Also connects to Dealer Capabilities Expectations and Dealer of Tomorrow scorecard. Hutson is ahead of most dealers in both tooling and progress.

---

## Ongoing Steps

1. **Maintain regular cadence with CSC team** — continue alignment on linkage standards, surface new edge cases as we encounter them in bulk upload work
2. **Follow up with Nevin Kroeker (DDL)** on Ops Center org mapping table — blocked on JD internal permissions; check status before deciding whether to pull the data ourselves (Action Item #29)
3. **Coordinate Sales Center / Service Center updates** — DUA username field addition; confirm timeline and what data we need to provide
4. **Push JD to publish a dealer linkage playbook** — shared standards document that Hutson and other dealers can reference; reduces ambiguity and gives us a defensible baseline
5. **Monitor Project Halo requirements** — 25% by 2027 and 80–90% by 2028 communicated, but measurement methodology and lookback window not yet formally defined; track as JD publishes details
6. **Parent account hierarchy** — follow up on whether JD can push parent account relationships into our CRM and what the data model for that looks like

---

## Open Questions

- What is the exact measurement methodology and lookback window for the Project Halo 25% target?
- Will JD publish a formal dealer linkage playbook, or does this remain dealer-by-dealer?
- What is Nevin Kroeker's timeline for the Ops Center org mapping table?
- Can JD push parent account hierarchy (entity → contacts) into Salesforce, and if so, what triggers the update?
