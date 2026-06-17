# Customer Linkage & Contact Cleanup — Order of Operations

**Updated:** 2026-05-15

---

## Phase 0 — Data Quality Reporting Baseline

**Status:** Complete  
**Goal:** Establish a weekly snapshot pipeline and Power BI report to track data quality trends, surface cleanup targets, and provide a measurable before/after baseline for all cleanup phases.

Before any bulk operations began, a full data quality reporting foundation was built. A scheduled notebook runs weekly in Fabric, capturing 140 metrics across all active contacts and writing results to a snapshot table. A Power BI report built on top of that table gives both a population-level view (weekly trends) and a contact-level view (per-account issue flags and scores). This makes it possible to measure whether cleanup efforts are working and to pull a targeted list of affected records for any given issue.

**Steps:**

- **Build DQ snapshot notebook** — write all metric logic, run against Fabric, validate results, and schedule as a weekly job
- **Create contact-level issues table** — map each metric flag to individual contacts for drill-down and targeted cleanup
- **Build Power BI report** — 8-page report covering linkage quality, completeness, field quality, Registry parity, account staleness, and match readiness
- **Review first snapshot** — walk through each metric, identify query bugs and logic issues, fix and re-run before marking complete

---

## Phase 1 — Quick Win Linkages

**Status:** In Progress  
**Goal:** Formalize linkages where the Registry entity ID is already known — no matching or data cleanup required.

This phase targets two groups where the hard work of identifying the correct Registry entity has already been done: contacts in EQUIP that have an entity ID recorded but no formal linkage entry, and Salesforce customers where the entity ID came through the quote workflow. Both groups can be linked quickly, but the Salesforce group requires a validation step first to confirm the IDs are still accurate before formalizing them.

**Steps:**

- **Establish progress tracking baseline** — capture the linkage count at project start and set up the tracking query to isolate project-attributed linkages from background workflow activity
- **Link informal EQUIP records** — upload the ~49 contacts that have a valid entity ID in EQUIP but no formal Registry linkage entry
- **Validate and link Anvil-only Salesforce customers** — run the ~12,970 Salesforce customers with quote-workflow entity IDs through Deere's matching tool to independently confirm the IDs before formally linking; flag any where Deere returns a different entity ID than Salesforce has on file

---

## Phase 2 — EQUIP Data Cleanup

**Status:** Not Started  
**Goal:** Improve contact data quality so that bulk uploads in Phase 3 produce tight matches rather than potential matches or no matches.

The DQ report surfaces exactly where the problems are — invalid phone numbers, bad emails, status text in the wrong fields, non-standard coded values, and stale accounts. This phase works through those issues systematically so the data going into the linkage tool is as clean as possible. Phases 1 and 2 can run in parallel.

**Steps:**

- **Inactivate stale accounts** — use EQUIP's bulk inactivation program to flag accounts with no activity beyond a defined cutoff date; inactivated records are automatically excluded from linkage uploads
- **Standardize coded fields** — run Contact Mass Update to correct non-standard State, Country, and Prefix values to their proper codes; these fields directly affect Registry matching
- **Fix misplaced data** — identify and correct status text stuffed into name or address fields, combined names that should be separate records, and data that belongs in dedicated fields like Doing Business As or Generation
- **Decide business vs. contact linkage for C-type records** — determine whether Business-with-Contact records should link at the business entity level or the individual contact level; this decision controls how all C-type records are extracted for upload
- **Clean up invalid phone numbers** — identify and null out all-zero, sequential placeholder, wrong-length, and non-numeric phone values across all three phone fields
- **Clean up invalid email addresses** — identify and null out structurally invalid emails, known placeholder patterns, and internal employee emails left on customer records
- **Cross-reference with Registry for data variance** — for already-linked contacts, compare EQUIP data against Registry and surface significant divergences; use Registry as a signal for where our data may be out of date
- **Track cleanup progress** — capture before/after counts for each cleanup pass using the DQ report as the measurement tool

---

## Phase 3 — Bulk Linkage Upload

**Status:** Not Started  
**Goal:** Link the remaining unlinked accounts through Deere's matching tool, prioritizing high-value accounts and accepting only tight matches that also pass internal validation checks.

This is the main body of the linkage work. With data cleanup from Phase 2 complete, unlinked contacts are uploaded in batches to Deere's Customer Linkage Tool which attempts to match each record to a Registry entity using name, address, and contact information. Only tight matches that also pass our own reconciliation checks are accepted — accounts with poor data quality or ambiguous matches are left for further cleanup rather than linked with low confidence.

**Steps:**

- **Define upload batches** — prioritize by account value (top revenue accounts first), then by territory and contact type; keep each file within the tool's upload limits
- **Export contacts via Customer Linkage Contact Data Extract** — filter to active, unlinked contacts and apply the business vs. contact linkage decision from Phase 2
- **Upload, validate, and accept** — upload each batch, run the reconciliation script to compare Deere's match results against our Salesforce data, apply internal validation checks, and accept only confirmed tight matches
- **Measure and adjust** — after each batch, review tight match rates and identify patterns in unmatched records; address data issues before the next batch

---

## Phase 4 — Salesforce Cleanup

**Status:** Not Started  
**Goal:** Eliminate Salesforce Prospect accounts that should either be merged into an existing Customer account or removed from the system entirely, and fix the process gap that caused the problem.

Salesforce has accumulated over 50,000 Prospect accounts — many representing customers who were sold to and converted to EQUIP accounts but were never properly merged in Salesforce. Others are online sales leads that generated a Prospect record but never resulted in a quote and are effectively orphaned. This phase merges the convertible ones, removes the orphans, and documents the process that should prevent the backlog from growing again.

**Steps:**

- **Match Prospects to linked Customers by entity ID** — once Phase 1 and 3 linkages are established, find Salesforce Prospects whose entity ID matches a linked Customer record and merge them
- **Delete orphaned online lead Prospects** — identify Prospects created from online sales leads that never had a quote created, copy contact info to the linked Request record for retention, then delete the Prospect accounts
- **Document and fix the process gap** — define the post-sale conversion process (EQUIP account creation → entity ID update → Salesforce merge) and build a report or alert to surface future cases where a Prospect should be converted

---

## Phase 5 — Manual Review Backlog

**Status:** Ongoing (parallel track)  
**Goal:** Resolve records that require human judgment and cannot be handled through bulk operations.

A small set of records have conflicting data between our systems and Deere's Registry that needs a person to look at and adjudicate. A larger set will come out of Phase 3 as potential matches — records where the tool isn't confident enough to auto-link but a human could confirm. Both are routed for review without requiring a dedicated reviewer.

**Steps:**

- **Resolve SF/cross-ref disagreements** — for the ~150 accounts where Salesforce and the Registry have different entity IDs, determine which is correct and update the appropriate system
- **Route potential matches to account managers** — send potential match records in small batches to the account manager responsible for each territory; frame as a quick confirmation rather than a formal review task

---

## Phase 6 — EQUIP Customer Deduplication

**Status:** Not Started  
**Goal:** Merge duplicate customer records in EQUIP and address duplicate entity IDs in Deere's Registry — a multi-system process that comes after Phases 1–3 are mature.

Duplicate contacts in EQUIP — where the same customer was entered twice and both records eventually got linked to the same Registry entity — need to be merged so there is a single authoritative record. The confirmed duplicates identified so far are only a subset; full deduplication will surface more. This phase also involves cleaning up duplicate entity IDs in Deere's Registry itself. Because EQUIP merges touch a large number of tables and require partner systems to merge in sync, this phase carries the highest coordination cost and is deliberately sequenced last among the core cleanup work.

**Steps:**

- **Investigate mixed-type cases** — inspect duplicates where the two records have different contact types (e.g., Individual + Business Contact) to determine whether they are true duplicates or legitimate separate relationships
- **Coordinate with software partners** — notify partner systems that need to merge their data in sync with EQUIP; update any in-progress work orders to the surviving customer number before merging; schedule merges during off-hours
- **Merge by priority** — work through duplicate pairs in order: Individual+Individual pairs first (clearest cases), then Business Contact+Business Contact, then three-way duplicates, then mixed types, then complex multi-record cases

---

## Phase 7 — Operations Center Org Reconciliation

**Status:** Future workstream  
**Goal:** Build a complete map between our EQUIP accounts, Deere's Registry entity IDs, and Operations Center Organization IDs.

Operations Center uses Organization IDs that connect to Registry entity IDs. Once Registry linkage coverage is high enough, we can establish the full account map (EQUIP account → Registry entity → Org ID), which unlocks Operations Center data — machine telematics, field operations, agronomic records — navigable by our customer account. Requires separate research into available datasets and the mapping path.

---

## Phase 8 — Expert Connect Enrichment

**Status:** Future workstream  
**Goal:** Use Registry linkage to automatically populate Expert Connect with customer name and account context, eliminating manual lookup by representatives on inbound calls.

Expert Connect currently shows phone numbers for inbound contacts but no name or account context — representatives have to look up or enter that information manually. With Registry linkage in place, the entity ID bridges phone number to Registry record to EQUIP account. Requires research into Expert Connect's data model and available integration points.

---

## Phase 9 — EDA Buyer ID Mapping and Lost Sale Alerts

**Status:** Future workstream  
**Goal:** Leverage Deere's EDA buyer ID to entity ID mapping to connect UCC filing data to our customer accounts and surface lost sale alerts to the responsible CAM.

Deere has provided a mapping from EDA buyer IDs to Registry entity IDs. UCC filings record equipment purchases made through a lender. By joining our linked accounts to UCC filing data, we can identify purchases our customers made elsewhere and alert the Regional Customer Account Manager responsible for that account. High-value accounts (top sales deciles from the DQ report) are prioritized for alerts first.

---

## Phase 10 — Machine Data Quality Reporting

**Status:** Future workstream  
**Goal:** Build a machine-level equivalent of the contact DQ report, surfacing field completeness issues, duplicates, and EQUIP vs. Registry parity gaps across the unit population.

Mirrors the Phase 0 approach applied to machines rather than contacts. A weekly snapshot notebook captures issues by individual field (PIN, machine ID, model, serial number, etc.), flags duplicates, and compares EQUIP data against Deere's Registry. Output is a per-unit issue table that drives prioritized cleanup lists — the same pattern established for contacts in Phase 0.

**Steps:**
- **Define machine quality checks** — identify key fields and validation rules (PIN format, model code validity, missing serial numbers, duplicate detection)
- **Build machine DQ snapshot notebook** — model on the contact DQ notebook; schedule as a weekly job
- **Surface parity gaps** — compare EQUIP machine records against Deere's Registry and flag divergences
- **Generate per-unit issue lists** — feed into Phase 11 batch cleanup operations

---

## Phase 11 — Machine Cleanup

**Status:** Future workstream  
**Goal:** Merge duplicate units, enrich machine records, correct PINs and machine IDs, sync with Deere's Registry and Operations Center, and establish a centralized ongoing process so machine data is maintained as units move through the shop.

Machine cleanup is more complex than contact cleanup — units touch more systems (EQUIP, Deere Registry, Operations Center, JDParts, warranty) and some corrections require physical verification of the unit. The bulk of the work is driven by the DQ report; records that cannot be fixed programmatically are routed through a centralized team modeled on the warranty group workflow, making every service visit an opportunity to validate and enrich the machine record.

**Steps:**
- **Merge duplicate units in EQUIP** — identify and merge units entered multiple times; consolidate transaction and work order history to the surviving record
- **Correct PIN numbers and machine IDs** — validate PIN formats and update from available sources (warranty, JDParts, physical inspection at service intake)
- **Sync with Deere's Registry** — submit corrected machine data via available update paths; confirm ownership and unit records align with our EQUIP population
- **Update Operations Center** — reflect machine record corrections in Operations Center org assignments where applicable
- **Enrich machine records** — pull additional data from warranty history, JDParts, and manufacturer data to fill missing fields in bulk
- **Define centralized maintenance process** — document a workflow for the warranty team (or equivalent) to validate and update machine data whenever a unit comes in for service; make this part of standard service intake
- **Document the manual process** — for records that cannot be fixed in bulk, provide a step-by-step correction guide any team member can follow consistently

---

## Phase 12 — Auction and Listing-Based Machine Population Sync

**Status:** Future workstream  
**Goal:** Pull data from auction history and online equipment listings to identify machines that should be transferred out of our active machine population in Deere's system.

When a machine appears in auction results or active online listings under a different owner, it has likely left our customer's possession and should no longer be tracked in our active population. Identifying these proactively — rather than waiting for manual discovery — keeps our machine population accurate and prevents stale units from generating incorrect leads, warranties, or service recommendations.

**Steps:**
- **Identify data sources** — evaluate auction result feeds and online listing aggregators (MachineFinder, IronPlanet, Purple Wave, etc.) and any Deere-provided transfer data for availability and match quality
- **Match to EQUIP population** — join auction and listing records to our machine population by PIN or serial number to identify units that have changed hands
- **Flag and confirm transfers** — route matched units for review, confirm the transfer, and initiate the appropriate Registry population update
- **Define the transfer ownership process** — determine which team (CAM, warranty, or dedicated data role) owns the workflow going forward

---

## Phase 13 — CRM Enrichment

**Status:** Future workstream  
**Goal:** Enrich Salesforce customer accounts with external and internal data to give CAMs a fuller picture of each customer, reducing system-switching and surfacing context that currently lives nowhere visible in the CRM.

With Registry linkage established and the account list cleaned up, the CRM becomes a reliable foundation for layering in additional data. The focus is on information that directly helps CAMs make better decisions and have more informed customer conversations — pulling it into Salesforce so they don't have to go looking for it.

**Steps:**
- **Pull in customer segmentation data** — sync segmentation attributes (customer type, equipment tier, revenue band, industry) to Salesforce account fields so CAMs can filter and prioritize their books
- **Surface UCC filing data** — bring recent UCC filing activity onto linked account records; flags financing activity and potential lost sales without the CAM needing to leave Salesforce
- **Add sales history** — enrich accounts with key metrics (lifetime revenue, last purchase date, top equipment categories) from EQUIP or Fabric; eliminates the need to look up purchase history separately
- **Add deep links to Sales Center and Service Center** — surface direct links from the Salesforce account record to the corresponding customer in each system; reduces context-switching during customer calls
- **Evaluate additional enrichment sources** — assess Operations Center org data, warranty history, CLG lead scores, and other available sources for consistent value before including

---

## Phase 14 — Opportunity Mining and Surfacing Tools

**Status:** Future workstream  
**Goal:** Build tooling that proactively surfaces opportunities for CAMs — identifying which accounts to prioritize, what to discuss, and when to reach out — rather than relying on CAMs to manually mine for leads.

With enriched CRM data and Registry linkage in place, the underlying data exists to drive intelligent opportunity identification. The goal is to surface the right account to the right CAM at the right time, with enough context to make the outreach meaningful.

**Steps:**
- **Equipment replacement opportunity scoring** — use CLG lead data, equipment age, and sales history to score accounts by likelihood of being in a buying window; surface top scores as a prioritized list in Salesforce
- **Lost sale follow-up queue** — route UCC-flagged lost sale alerts (Phase 9) directly into a CAM action queue in Salesforce with account context attached
- **Lapsed customer identification** — flag accounts that transacted historically but have gone quiet; surface for CAM outreach before they are lost entirely
- **Cross-sell and upsell signal detection** — identify accounts with gaps in their equipment portfolio relative to their operation type or peer group
- **Opportunity dashboard** — a consolidated view in Salesforce or Power BI giving each CAM their top opportunities ranked by potential value, with one-click access to the relevant account and supporting context

---

## Phase 15 — Marketing and Sales Automation

**Status:** Future workstream  
**Goal:** Use the cleaned, enriched customer dataset to drive automated outreach and lead qualification across whole goods, parts, service, PIPs, and warranty — replacing ad-hoc campaigns with systematic, data-driven touchpoints.

A clean, linked, enriched dataset is the prerequisite for effective marketing automation. Once the earlier phases have established a reliable foundation, outreach can be triggered by data signals rather than manually built campaign lists. The goal is to reach the right customer at the right time with the right message, and to qualify inbound leads automatically so CAMs spend time on opportunities rather than list-building.

**Steps:**
- **Expiring warranty outreach** — identify customers with warranties nearing expiration and trigger automated or CAM-assisted outreach for extended warranty or service plan offers
- **PIP notification campaigns** — surface customers with units eligible for open Performance Improvement Plans and automate outreach to schedule the update and drive shop traffic
- **Parts and service campaign triggers** — use equipment age, service history, and seasonal patterns to trigger timely outreach (pre-season service reminders, wear-part replenishment, etc.)
- **Whole goods replacement campaigns** — use CLG lead scores, equipment age, and sales history to build targeted replacement campaigns for customers approaching the end of a typical equipment lifecycle
- **Lead qualification automation** — build scoring and routing logic so inbound leads (online forms, CLG leads, trade-in inquiries) are automatically qualified and assigned to the right CAM with account context attached
- **Outreach sequencing** — define and automate multi-touch outreach sequences (email, phone prompt, Salesforce task) for each campaign type so follow-through doesn't depend on individual CAM recall

---

## Phase 16 — Documentation and Playbooks

**Status:** Parallel track — grows as each phase ships  
**Goal:** Build practical, task-oriented documentation for the tools, datasets, and processes we are creating so any team member can use them effectively without needing to know how they were built.

Documentation is written as each phase completes rather than saved for the end. The audience is primarily CAMs, ASRs, and anyone doing account management or customer research. Guides focus on "how do I do X" rather than "how does X work" — short, practical, and tied to real workflows.

**Deliverables:**
- **Account cleanup guide** — how to identify issues on an account using the DQ report, correct data in EQUIP or Salesforce, and confirm the fix is reflected in reporting
- **Data quality report usage guide** — how to read the Power BI report, pull a list of accounts affected by a specific issue, interpret quality scores, and use contact-level flags for bulk cleanup
- **CRM enrichment field guide** — reference document covering each enriched Salesforce field: what it means, where it comes from, how often it updates, and how to use it in day-to-day CAM workflows
- **Account research playbook** — a structured process for preparing for a sales call: which systems to check, what data to pull, and how to interpret CLG leads, UCC filings, equipment history, and service records into a coherent picture of the account
- **Opportunity mining guide** — how to use the opportunity dashboard and scoring tools to identify and prioritize accounts worth contacting, with worked examples by scenario (replacement cycle, lapsed customer, lost sale follow-up, PIP outreach)
- **Tool-specific how-to guides** — short reference docs for each tool or dataset as it ships (Expert Connect enrichment, Operations Center mapping, auction sync, etc.)

---

## Phase 17 — Future Ideas Backlog

**Status:** Unscoped — candidates for future projects  
**Goal:** Capture ideas that logically extend from earlier phases and are worth exploring once Phases 1–16 are underway and priorities can be set with more context.

These are not committed phases. They are grouped by theme for easier prioritization later.

**Proactive Data Governance**
- **Real-time linkage pipeline** — automatically run new EQUIP contacts through the matching process at creation time so the backlog never accumulates again
- **Automated quality maintenance** — trigger DQ flags immediately when bad data is entered rather than catching it in the weekly snapshot; could live as EQUIP or Salesforce validation rules
- **Data stewardship program** — define ongoing ownership of data quality: who is responsible for which fields, what standards apply, and how issues escalate

**Additional Data Sources**
- **JDLink / telematics** — link machine hours, fault codes, and location data from Operations Center to customer accounts to proactively surface service needs
- **Parts order history** — connect parts purchase history to the customer and machine record to surface replenishment opportunities and identify parts-only customers as service conversion targets
- **Customer satisfaction data** — link CSI scores to Salesforce accounts so CAMs have visibility into satisfaction trends alongside sales and service history
- **FSA / Farm Service Agency data** — evaluate for contact enrichment and customer classification (farm size, crop types, operation profile)

**Advanced Analytics**
- **Predictive churn modeling** — score customers by churn risk using sales history, equipment age, service frequency, and UCC data; surface high-value accounts trending toward a competitor
- **Fleet composition and competitive intelligence** — use UCC data to understand a customer's full equipment fleet, including competitive units, to sharpen trade-in and replacement conversations
- **Trade-in and inventory matching** — connect replacement scoring to available used inventory so CAMs can surface a specific trade-in offer rather than a generic pitch

**Organizational and Access**
- **Digital User Account (DUA) linkage** — link our accounts to customers' myJohnDeere Digital User Accounts to gain visibility into digital engagement and unlock additional Deere data streams
- **Territory and book optimization** — build tooling to analyze CAM/ASR territory assignments by account value, geography, and workload rather than relying on static territory maps
- **SMS / text outreach channel** — once phone numbers are validated, add SMS as an outreach channel for campaigns and service appointment reminders
