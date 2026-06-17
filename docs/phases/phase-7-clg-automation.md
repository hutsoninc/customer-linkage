# Phase 7 — CLG Lead Automation

**Status:** 🔄 First pass built (2026-06-16) — pending Shane and Reagan approval  
**Effort:** Medium | **Risk:** Low | **Dependency:** Registry linkage (Phase 2 establishes entity ID coverage); Phases 3–4 expand the addressable population

**Goal:** Build an automated pipeline that ingests JD-generated CLG leads, applies suppression logic, routes each lead to the right owner, and stages them as Salesforce sales lead requests — running on a recurring schedule so new leads surface automatically as they are scored.

---

## Why This Phase Exists Here

This phase is a proof of concept that the data foundation work (Registry linkage, EQUIP cleanup) directly enables business value. CLG leads are only actionable if we have a Registry entity ID to match against — linkage coverage is the prerequisite. Every account linked in Phase 2 and Phase 4 expands the pool of leads we can act on.

It also demonstrates the "leveraging the data" payoff to leadership at a point in the project where the cleanup work is still ongoing — showing the return before the foundation work is complete.

---

## What Was Built (First Pass — 2026-06-16)

### Lead Ingestion
- Queries to pull CLG-scored leads from JD's dataset in Fabric

### Suppression Logic
Leads are suppressed (excluded from the load) if any of the following exist:
- An existing quote for that customer on the recommended model or category
- A recent sale for that customer on the recommended model or category
- A previously loaded lead request for that customer (prevents re-surfacing the same lead on subsequent runs)

### Owner Routing (waterfall)
Each lead is assigned an owner using this priority order:
1. Owner of the matching EQUIP/Salesforce account (if a linked account is found)
2. Last person who quoted that customer
3. Regional Manager based on the lead's location
4. Fallback: Greg Stone (pending decision on rerouting)

### Staging Table
Output is a staging table with all fields required to create a Salesforce Sales Lead Request, including:
- Full CLG data (model, category, lead score, scoring signals)
- Potential matching account information from EQUIP/Salesforce
- Opportunity dollars: prior sales for the recommended model; or average quote selling value by equipment category when no sales history exists for that model

### First Pass Results (very high probability to purchase)
- **1,574 leads staged**
- **$78M in total opportunity dollars**

---

## Next Steps

1. **Get approval** — Shane and Reagan reviewing first-pass results; approval needed to begin loading into Salesforce
2. **Load into Salesforce** — once approved, run the staging → Salesforce Sales Lead Request import
3. **Schedule automation** — configure as a weekly or monthly recurring job; each run loads net-new leads only (suppression logic prevents re-loading previously surfaced leads)
4. **Expand to additional lead tiers** — first pass covers very-high-probability leads; subsequent passes can include lower probability tiers as the process matures and owners are comfortable with volume
5. **Monitor and tune suppression** — as quotes and sales occur against loaded leads, confirm suppression is working correctly and adjust windows as needed

---

## Connection to Other Phases

- **Phase 4 (Bulk Linkage Upload):** Every new account linked expands the pool of CLG leads we can match against our customer base. Lead volume will grow as linkage coverage improves.
- **Phase 11 (CRM Enrichment):** As additional data is added to Salesforce accounts, the CLG lead description can be enriched further (equipment history, last purchase date, open service items, etc.)
- **Phase 16 (Opportunity Mining):** The CLG pipeline feeds into the broader opportunity surfacing framework — leads become one signal among several in a CAM's prioritized account list.

---

## Open Questions

- What is the final routing decision for the Greg Stone fallback — who should receive unroutable leads long-term?
- What approval workflow is needed before leads are loaded into Salesforce (single approval, or per-batch review)?
- Should the recurring schedule be weekly or monthly — what cadence matches CAM bandwidth to work the leads?
- As linkage coverage grows, how do we handle the expected increase in lead volume?
