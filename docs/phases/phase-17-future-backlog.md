# Phase 17+ — Future Ideas Backlog

**Status:** Unscoped — candidates for future projects  
**Goal:** Capture ideas that logically extend from earlier phases and are worth revisiting once Phases 1–16 are underway and priorities can be set with more context.

These are not committed phases. They are grouped by theme for easier prioritization later.

---

## Proactive Data Governance

- **Real-time linkage pipeline** — automatically run new EQUIP contacts through the matching process at creation time so the backlog never accumulates again; the current project closes the existing gap, but this prevents future accumulation
- **Automated quality maintenance** — trigger DQ flags immediately when bad data is entered (invalid phone, placeholder email, wrong state code) rather than catching it in the weekly snapshot; could live as EQUIP validation rules or Salesforce field-level automation
- **Data stewardship program** — define ongoing ownership of data quality: who is responsible for which fields, what standards apply, how issues escalate, and what the review cadence is; the organizational complement to the technical tooling

---

## Additional Data Sources

- **JDLink / telematics** — machines with JDLink have hours, fault codes, and location data accessible via Operations Center; linking this to customer accounts proactively surfaces service needs before a customer calls
- **Parts order history** — connect parts purchase history to the customer and machine record to surface replenishment opportunities and identify parts-only customers as service conversion targets
- **Customer satisfaction data** — link JD satisfaction survey results (CSI scores) to Salesforce accounts so CAMs have visibility into satisfaction trends alongside sales and service history; a dissatisfied high-value account is a retention priority
- **FSA / Farm Service Agency data** — JD uses FSA/SIC data as a Registry source; if accessible, could help with contact enrichment and customer classification (farm size, crop types, operation profile)

---

## Advanced Analytics

- **Predictive churn modeling** — use sales history, equipment age, service frequency, and UCC data to score customers by churn risk; surface high-value accounts trending toward a competitor before the loss happens
- **Fleet composition and competitive intelligence** — UCC data shows all financed equipment a customer owns, not just ours; understanding a customer's full fleet (including competitive units) sharpens trade-in and replacement conversations
- **Trade-in and inventory matching** — connect customer equipment history and replacement scoring to available used inventory so CAMs can surface a specific trade-in offer rather than a generic replacement pitch

---

## Organizational and Access

- **Digital User Account (DUA) linkage** — Deere customers with a myJohnDeere account have a DUA tied to their Registry entity; linking our accounts to DUAs gives visibility into digital engagement and unlocks additional JD data streams; also helps resolve Shop.deere.com access issues (currently addressed through Phase 1 JD Partnership work)
- **Territory and book optimization** — with a clean, scored account list, build tooling to analyze CAM/ASR territory assignments by account value, geography, and workload rather than relying on static territory maps
- **SMS / text outreach channel** — once phone numbers are validated and enriched, add SMS as a channel for campaign touchpoints and service appointment reminders; higher open rates than email for time-sensitive outreach
