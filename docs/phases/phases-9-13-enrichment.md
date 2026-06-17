# Phases 9–13 — Enrichment & Integration

These phases build on the Registry linkage established in the Foundation phases. Each uses the entity ID as the bridge to an additional JD system or data source.

---

## Phase 9 — Operations Center Org Mapping {#phase-9}

**Status:** ⏳ Future  
**Dependency:** Phases 2 and 4 complete (linkage coverage mature)

**Goal:** Build a complete map between Hutson's EQUIP accounts, JD Registry entity IDs, and Operations Center Organization IDs.

Operations Center uses Org IDs that connect to Registry entity IDs via a **many-to-many** relationship (one entity can belong to multiple orgs; one org can have multiple entities). Establishing this mapping unlocks Operations Center data — machine telematics, field operations, agronomic records — navigable by our customer account.

**Status of JD-side work:** Nevin Kroeker (Dealer Data Lake PM) is building an entity-to-Org ID mapping table but is blocked on permissions with the Operations Center team (as of 2026-05-29). Two paths forward:
1. Contact Nevin for a status update and wait for the mapping table
2. Pull Operations Center data ourselves to measure current entity-to-org coverage independently

**Next step:** Reach out to Nevin before deciding which path to take (Action Item #29).

---

## Phase 10 — Expert Connect Enrichment {#phase-10}

**Status:** ⏳ Future  
**Dependency:** Phases 2 and 4 complete

**Goal:** Use Registry linkage to automatically populate Expert Connect with customer name and account context, eliminating manual lookup by representatives on inbound calls.

Expert Connect currently shows phone numbers for inbound contacts but no name or account context. With Registry linkage in place, the entity ID bridges phone number → Registry record → EQUIP account.

**Steps:**
- Research the Expert Connect data model and available integration points (API, flat file sync, or push from another system)
- Define the enrichment payload (name, account number, contact type, branch)
- Build and schedule the enrichment feed
- Confirm with the Expert Connect team what format is required

---

## Phase 11 — CRM Enrichment {#phase-11}

**Status:** ⏳ Future  
**Dependency:** Phases 2 and 4 complete; Phase 5 (SF cleanup) substantially done

**Goal:** Enrich Salesforce customer accounts with internal and external data to give CAMs a fuller picture of each customer — reducing system-switching and surfacing context that currently lives outside of Salesforce.

**CAM assignment automation:**
New EQUIP accounts sync to Salesforce without an assigned owner. The right CAM can be determined automatically from recent sales history — a newly created account should be assigned to the salesperson who sold to that customer. Build an automation that looks up the most recent sale for a new account's contact code and assigns the responsible CAM in Salesforce at account creation time. Exceptions (no sales history, shared territory) surface for manual assignment. This keeps the account list clean and avoids accounts sitting unassigned.

**Planned enrichment sources:**

| Data | Source | Value |
|---|---|---|
| Customer segmentation | EQUIP / Fabric | Customer type, equipment tier, revenue band — lets CAMs filter and prioritize their books |
| Sales history | EQUIP / Fabric | Lifetime revenue, last purchase date, top equipment categories — eliminates separate lookup |
| UCC filing data | EDA / JD | Recent financing activity; flags potential lost sales on linked accounts |
| Deep links | Sales Center, Service Center | Direct links from Salesforce account record to the customer in each JD system |
| Parent account hierarchy | JD (proposed) | Business entity → business contacts relationship pushed into Salesforce for quote coverage and activity rollup |
| Additional sources | TBD | Operations Center org data, warranty history, CLG lead scores — evaluate for consistent value |

**Parent account hierarchy context:** Discussed with JD (Phase 1). Goal is to have JD push the parent account relationship so that quotes and activities on individual business contacts roll up to the parent business entity. This would allow reporting to say a business was quoted even if only one of three contacts received a quote — improving CAM coverage metrics and activity tracking.

---

## Phase 11b — EQUIP Enrichment {#phase-11b}

**Status:** ⏳ Future  
**Dependency:** Phase 4 (linkage coverage mature — entity ID is the join key for Registry enrichment); Phase 5 (SF cleanup substantially done before pulling Prospect data into EQUIP)

**Goal:** Enrich EQUIP contact records from external sources — filling gaps and correcting data quality issues in the system of record rather than just in the CRM layer. The inverse of Phase 11 (which enriches Salesforce).

**Enrichment sources:**

| Source | What to Pull | Value |
|---|---|---|
| JD Registry | Email, phone, address where EQUIP is blank or invalid | Fills contact gaps that block marketing and outreach; Registry data is often more current for active JD customers |
| JD Registry | Corrected postal codes and address components | Fixes delivery failures for mailers and reduces undeliverable mail rates |
| Salesforce Prospects | Contact data collected by CAMs (email, phone, notes) | CAMs can update Prospects but not EQUIP directly — this syncs their collected data back to the system of record |

**Notes:**
- Registry enrichment requires active Registry linkage (entity ID in `Equip.contact.Ckc_Id`) — Phase 4 is the primary gate
- Salesforce Prospect sync should run after Phase 5 cleanup so that only vetted, non-duplicate Prospect data is pulled across
- Field-level conflict resolution rules needed: decide whether Registry or Salesforce takes precedence when both have a value that differs from EQUIP (e.g., two different phone numbers)
- Enrichment writes to EQUIP, which triggers JDSO sync — use the JDSO parity notebook to validate post-enrichment

---

## Phase 12 — Machine Data Quality & Cleanup {#phase-12}

**Status:** ⏳ Future  
**Dependency:** Phase 0 methodology established (mirrors the contact DQ approach)

**Goal:** Build a machine-level equivalent of the contact DQ report — surfacing field completeness issues, duplicates, and EQUIP vs. Registry parity gaps across the unit population. Then execute bulk cleanup driven by those findings.

**Machine DQ reporting:**
- Identify key fields and validation rules (PIN format, model code validity, missing serial numbers, duplicate detection)
- Build a machine DQ snapshot notebook modeled on `notebooks/dq-snapshot.ipynb`; schedule weekly
- Surface parity gaps between EQUIP machine records and JD Registry
- Generate per-unit issue lists for targeted cleanup

**Machine cleanup (follows DQ reporting):**
- Merge duplicate units — consolidate transaction and work order history to the surviving record
- Correct PIN numbers and machine IDs — validate from warranty, JDParts, or physical inspection
- Sync corrected data to JD Registry and Operations Center
- Enrich machine records from warranty history, JDParts, and manufacturer data
- Define a centralized maintenance process for the warranty team — make every service visit an opportunity to validate and enrich the machine record
- Document a step-by-step manual correction process for records that can't be fixed in bulk

**Why this is more complex than contact cleanup:** Machines touch more systems (EQUIP, JD Registry, Operations Center, JDParts, warranty) and some corrections require physical verification of the unit. The warranty team workflow is the natural owner of ongoing maintenance.

**AOR (Area of Responsibility) ownership problem:**
In JD's system, each machine has a responsible dealer — the dealer in whose AOR the machine resides. When Hutson sells a machine to a customer outside our AOR (e.g., a customer in Virginia), the warranty team is supposed to transfer that machine's responsibility to the appropriate servicing dealer. In practice this is done inconsistently, leaving Hutson with a machine population in JD's system that significantly overstates what is physically in our territory. This creates noise in lead scoring, warranty, and Operations Center data.

**Automation opportunities:**
- **Out-of-AOR sale flagging:** When a sale is recorded to a customer address outside Hutson's AOR, automatically identify the responsible dealer based on the customer's location and generate a transfer request to submit to JD. Eliminates the warranty team's manual lookup step.
- **Marketplace scraping (feeds Phase 13):** Identify machines listed on third-party marketplaces (MachineFinder, IronPlanet, Purple Wave, etc.) by a dealer or private party other than Hutson. When a machine in our population is spotted, submit a transfer or removal request to JD with context: machine serial number, listing source, listing dealer or seller. Automates a process that currently has no systematic owner.

**Manual cleanup required (no automation path):**
- Scrapped, junked, or destroyed machines — no listing data available; requires human confirmation before removing from population
- Machines sold off-market (private sales with no public listing) — flag candidates based on age + no recent warranty activity, route to warranty team for confirmation

---

## Phase 13 — Auction / Listing Machine Population Sync {#phase-13}

**Status:** ⏳ Future  
**Dependency:** Phase 12 (machine DQ reporting complete)

**Goal:** Pull data from auction history and online equipment listings to identify machines that have changed hands and should be transferred out of our active machine population in JD's system.

When a machine appears in auction results or active online listings under a different owner, it has likely left our customer's possession. Identifying these proactively keeps our machine population accurate and prevents stale units from generating incorrect leads, warranties, or service recommendations.

**Steps:**
- Identify available data sources: auction result feeds, online listing aggregators (MachineFinder, IronPlanet, Purple Wave), or JD-provided transfer data
- Match auction/listing records to our EQUIP machine population by PIN or serial number
- For each match: determine the listing party (another dealer, auction house, private seller); compose a transfer request to JD citing the serial number, listing source, and listing party
- Submit requests in bulk; log outcomes
- Define the ongoing transfer workflow and determine which team owns it going forward (warranty team as current process owner, or a dedicated data role)

**Relationship to Phase 12:** Phase 12 handles the AOR transfer automation and scrap/junk manual cleanup. Phase 13 extends that to the marketplace scraping signal — both feed into the same transfer request workflow to JD. The two phases share a submission mechanism and can be built together or sequentially.
