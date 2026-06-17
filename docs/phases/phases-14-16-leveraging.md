# Phases 14–16 — Leveraging the Data

These phases use the clean, linked, enriched customer and machine data built in earlier phases to drive business outcomes — automated outreach, lead qualification, lost sale alerts, and opportunity surfacing for CAMs. These are distinct from the data infrastructure work in that they deliver direct, measurable business value to the sales and marketing teams.

---

## Phase 14 — Marketing & Sales Automation {#phase-14}

**Status:** ⏳ Future  
**Dependency:** Phases 3–4 (clean data), Phase 11 (CRM enrichment), Phase 6 (playbooks to support the processes)

**Goal:** Use the cleaned, enriched customer dataset to drive automated outreach and lead qualification — replacing ad-hoc campaigns with systematic, data-driven touchpoints across whole goods, parts, service, PIPs, and warranty.

**Planned automation types:**

| Campaign | Trigger | Channel |
|---|---|---|
| Expiring warranty outreach | Warranty nearing expiration date | Automated or CAM-assisted |
| PIP notification | Units eligible for open Performance Improvement Plans | Automated |
| Parts / service reminders | Equipment age, service history, seasonal patterns | Automated |
| Whole goods replacement | CLG lead score + equipment age + sales history | CAM-assisted |
| Lead qualification | Inbound online forms, CLG leads, trade-in inquiries | Automated routing to CAM |
| Outreach sequencing | Multi-touch (email → phone prompt → SF task) | Per-campaign |

**Relationship to CLG Automation (Phase 7):** Phase 7 handles the inbound CLG lead pipeline. Phase 14 extends that into structured outreach campaigns and adds the other trigger types above. Phase 7 is the proof of concept; Phase 14 is the scaled system.

---

## Phase 15 — EDA / UCC Lost Sale Alerts {#phase-15}

**Status:** ⏳ Future — dataset now accessible  
**Dependency:** Phases 2 and 4 (linkage coverage sufficient to make alerts actionable)

**Goal:** Use JD's EDA buyer ID → entity ID mapping to connect UCC filing data to our customer accounts and surface lost sale alerts to the responsible CAM.

**Dataset status:** Following the DDL partnership meeting, JD published the EDA buyer ID → entity ID mapping dataset to all dealers via their data share. We have access to 136,000+ relationships. The prerequisite for this phase is met — scoping and build can begin once linkage coverage from Phase 4 is mature enough to make alerts broadly actionable.

**How it works:**
- UCC (Uniform Commercial Code) filings record equipment financing — filed when a customer purchases equipment through a lender
- JD uses EDA data in CLG lead scoring; each customer in that dataset has an EDA buyer ID mapped to a Registry entity ID
- Join path: EQUIP account → Registry entity ID → EDA buyer ID → UCC filing
- Compare UCC filings against our own sales history to identify equipment our customers purchased elsewhere
- Surface as alerts to the Regional CAM responsible for that account

**Prioritization:** Focus alerts on high-value accounts (top sales deciles from the DQ report) first — most impactful, easiest for CAMs to act on.

---

## Phase 16 — Opportunity Mining & Surfacing Tools {#phase-16}

**Status:** ⏳ Future  
**Dependency:** Phase 11 (CRM enrichment), Phase 15 (lost sale alerts), Phase 7 (CLG pipeline)

**Goal:** Build tooling that proactively surfaces the right accounts to the right CAMs at the right time — with enough context to make outreach meaningful — rather than relying on CAMs to manually mine for opportunities.

**Planned components:**

| Tool | What It Does |
|---|---|
| Equipment replacement scoring | Uses CLG lead data, equipment age, and sales history to score accounts by buying window likelihood; surfaces as a prioritized list in Salesforce |
| Lost sale follow-up queue | Routes UCC-flagged lost sale alerts (Phase 15) into a CAM action queue in Salesforce with account context attached |
| Lapsed customer identification | Flags accounts that transacted historically but have gone quiet; surfaces for CAM outreach before they are lost |
| Cross-sell / upsell signals | Identifies accounts with equipment portfolio gaps relative to their operation type or peer group |
| Opportunity dashboard | Consolidated view (Salesforce or Power BI) giving each CAM their top opportunities ranked by value, with one-click access to account details and supporting context |

**Relationship to Phase 7 (CLG Automation):** Phase 7 builds the lead pipeline; Phase 16 integrates that pipeline with other signals (UCC, lapsed customer, cross-sell) into a unified prioritized view for CAMs. Phase 7 is the first output; Phase 16 is the full system.
