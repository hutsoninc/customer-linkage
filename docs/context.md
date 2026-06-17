# Customer Linkage Project — Domain Glossary

Key terms, systems, and relationships used across all project documents and AI conversations.

---

## Systems

**EQUIP** — Hutson's dealer business system (DBS). Primary system of record for customer contacts (`Equip.contact`), accounts (`ArMaster`), and machines. Contact records are identified by `contact_code`. The DBS number (dealer identifier) appears in JD's CSC once a formal linkage is created.

**JDSO** — John Deere Salesforce.com. Hutson's Salesforce instance with the Anvil integration. Syncs bidirectionally with EQUIP: changes in EQUIP push to Salesforce; updates in Salesforce (via Dataverse) send a full contact payload back to EQUIP. Key account fields: `Anvil__AccountNumber__c` (contact code), `Anvil__CustomerCompEntityID__c` (entity ID from quote workflow), `H_Equip_contact_Ckc_Id__c` (entity ID synced from formal EQUIP linkage — takes precedence).

**Registry (CKC / IKC)** — John Deere's Customer Registry. The authoritative master for customer entities across the JD ecosystem. Every registered entity has a unique **Entity ID**. The Registry is the bridge to all downstream JD data: equipment history, UCC filings, Operations Center orgs, CLG leads, Expert Connect, Rewards, Service Center.

**DDP (John Deere Data Products)** — JD's Fabric-hosted datasets accessible to dealers. Key tables: `DDP.customer_profile` (entity → cross_ref mapping), others for equipment and warranty data. Always filter `customer_profile` with `cross_ref_description = 'HUTSON INC Dealer XREF'` to avoid EDA fan-out.

**CSC (Common Search Component)** — JD's customer search tool embedded in JD sales and service applications (Sales Center, Rewards, Service Center). Our DBS number appears in the CSC membership column once a formal linkage exists, making the customer's JD data navigable from our dealership context.

**CLG (Customer Lead Generator)** — JD's lead scoring service. Generates equipment replacement leads by customer entity ID based on equipment age, ownership patterns, and scoring models. Leads are only actionable if we have Registry linkage — the entity ID is the join key between our accounts and CLG lead records.

**Operations Center** — JD's agronomic and telematics platform. Uses **Organization IDs** (Org IDs) that relate to Registry Entity IDs via a many-to-many mapping (one entity can belong to multiple orgs; one org can have multiple entities). Entity ID → Org ID mapping is a separate research workstream (Phase 9).

**Expert Connect** — JD's inbound call routing system. Currently shows phone numbers for inbound contacts but no name or account context. Registry linkage enables enriching inbound calls with customer name and EQUIP account info automatically.

**SMO (Sales and Marketing Operations)** — John Deere's CRM and marketing platform, built on Microsoft Dynamics 365. Includes a sales CRM (Sales Hub) and a marketing automation tool (Customer Insights and Journeys). A migration from Hutson's current Salesforce instance to SMO is anticipated, likely in 2027 or 2028 — no committed timeline yet. The Salesforce cleanup and enrichment work in this project (Phase 5, Phase 11) is also migration preparation: getting data clean and structured before it moves into the next system. Prospect records are a specific concern — they exist only in Salesforce, not in EQUIP, and need to be evaluated for value before migration.

**Fabric** — Microsoft cloud data platform where Hutson's data warehouse lives. JD's DDP datasets are also available here. All queries in this project run against Fabric using `scripts/fabric_query.py`.

---

## Key Concepts

**Linkage** — A formal record in `customer_cross_ref` (Registry side) and `Equip.contact.Ckc_Id` (EQUIP side) connecting a Hutson EQUIP contact to a JD Registry entity. Creating a linkage is what makes our DBS number appear in CSC. Also called "Registry linkage" or "formal linkage."

**Entity ID** — The unique identifier for a customer in JD's Registry (also called CKC ID or IKC ID). Stored as `Ckc_Id` in EQUIP and `Anvil__CustomerCompEntityID__c` / `H_Equip_contact_Ckc_Id__c` in Salesforce. The `H_Equip_contact_Ckc_Id__c` field (from formal EQUIP linkage) takes precedence over `Anvil__CustomerCompEntityID__c` (from quote workflow) when populated.

**cross_ref** — The `customer_cross_ref` table in JD's Registry. One row per linkage. Each row maps a dealer's DBS number + contact code to a Registry entity ID. The `cross_ref_description` field identifies the source; always filter to `'HUTSON INC Dealer XREF'` to exclude EDA and other cross-ref types.

**DBS Number** — Hutson's dealer business system number. Appears in the CSC membership column in JD's sales tools once a linkage exists for the customer.

**Tight Match** — A match returned by the Customer Linkage Tool with high confidence, based on name + address + contact info alignment. Tight matches are auto-approvable after passing our internal reconciliation check. Contrasted with **Potential Match** (lower confidence, requires human review).

**Potential Match** — A match returned by the Customer Linkage Tool with lower confidence. Cannot be bulk-accepted; requires a person to review and confirm before linking.

**Path A (Create DBS Linkage)** — Linkage method used when the Entity ID is already known. No matching required — the upload directly creates the `cross_ref` entry. Template: `Create_Bulk_Linkages_Template.csv`.

**Path B (Match DBS Customer List)** — Linkage method that uses name + address + contact info to find the best Registry match. Returns tight matches, potential matches, and no-match results. Template: `DBS_Registry_UploadTemplate.csv`.

**Business_Individual (B / I / C)** — EQUIP contact type classification. **B** = Business (company or organization). **I** = Individual (person, not associated with a business entity). **C** = Business Contact (person associated with a business entity). Affects name field usage, upload formatting, and linkage level (entity vs. contact).

**Sentinel Entity ID** — Entity ID `999999998`. A placeholder used by JD for records that cannot be uniquely identified. Always exclude from queries and linkage uploads.

**AOR (Area of Responsibility)** — The geographic territory a dealer is responsible for servicing. In JD's system, each machine has a responsible dealer — the dealer in whose AOR the machine resides. When a machine is sold to a customer outside Hutson's AOR, the responsible dealer should be transferred to the appropriate servicing dealer. This process is owned by Hutson's warranty team but is performed inconsistently, leaving Hutson with a machine population in JD's systems that overstates what is physically in our territory. Correcting this is the focus of Phase 12 (machine cleanup) and Phase 13 (marketplace scraping for transfer identification).

---

## JD Programs and Initiatives

**Project Halo** — John Deere's dealer linkage initiative. Establishes formal linkage targets for dealers: 25% of accounts linked in the near term, 80–90% in subsequent years. Hutson leadership is familiar with this program. Our project is directly positioned to exceed these targets ahead of schedule relative to other dealers.

**EDA (Equipment Data Analytics)** — JD's program that uses UCC filing data to score and rank equipment leads (feeds CLG). Each customer in the EDA dataset has an EDA buyer ID which JD has mapped to a Registry entity ID. JD published this EDA buyer ID → entity ID mapping dataset to all dealers via their data share following our DDL partnership meeting — giving us access to 136,000+ relationships. With entity ID as the bridge, UCC filing data can be mapped to our EQUIP accounts. Enables lost sale detection (Phase 15) and CRM enrichment with financing activity (Phase 11).

**UCC (Uniform Commercial Code)** — Equipment financing filings. Filed when a customer purchases equipment through a lender. Comparing UCC filing data against our own sales history reveals when a customer bought equipment from a competitor.

**DUA (Digital User Account)** — A customer's myJohnDeere account. Ties to a Registry entity ID. Linkage gaps or incorrect entity IDs can cause customers to lose access to discounts, invoices, and other services on Shop.deere.com.

---

## Legacy / Deprecated JD Applications

These applications appear in older JD documentation and source materials in this project. Do not reference them in new documents or communications — use the current replacement instead.

| Legacy App | Status | Replacement |
|---|---|---|
| JDQuote2 | Migrated | Sales Center |
| JDMint | Migrated | Sales Center |
| Warranty Portal | Consolidated | Service Center |
| JD AIM (JDAim) | Sunsetting (announced) | Sales Center + Publication Management application |

References in `docs/source-materials-summary.md` are preserved as-is since they are quotes from historical JD source documents.

---

## Roles

**CAM (Customer Account Manager)** — Hutson's regional account managers. Responsible for customer relationships and outreach within assigned territories. Primary audience for opportunity surfacing tools, playbooks, and CRM enrichment work.

**ASR (Account Sales Representative)** — Sales staff. Work under CAMs. Also a target audience for playbooks and account research tools.

**CSC / DDL / DDH (JD teams)** — Common Search Component, Dealer Data Lake, Dealer Data Hub. JD product and data teams engaged through the JD Partnership workstream (Phase 1). Key contacts: Cindy and Vicky (CSC/Shop.deere.com PMs), Nevin Kroeker (DDL PM).
