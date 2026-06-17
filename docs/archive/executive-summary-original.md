# Customer Linkage & Contact Cleanup — Executive Summary

**Date:** May 2026

---

## What We're Doing and Why

John Deere's customer Registry is the connective tissue across the entire JD ecosystem. Formally linking our accounts unlocks capabilities across a wide range of tools and data sources:

- **JD sales tools** (JDQuote2, JDMint, Sales Center, Rewards, Warranty Portal) — our dealership number appears in the customer profile; equipment history, financing, and warranty data become navigable by customer
- **Customer Lead Generator (CLG)** — Deere generates equipment leads by customer; with linkage we can cross-reference those against our own quotes and sales to filter down to leads worth actually pursuing
- **UCC filings and lost sale detection** — Deere has provided an EDA buyer ID to entity ID mapping; once linked, we can bridge to UCC filing data to identify when a customer purchased equipment elsewhere and alert the responsible CAM
- **Operations Center** — linkage gives us access to each customer's Organization ID, creating a complete map between our account data, Deere's Registry, and the customer's Operations Center org
- **Expert Connect and SMO migration** — we can enrich inbound call data automatically so reps aren't looking customers up by hand; linkage also sets up a cleaner SMO migration and gives account managers more accurate data across the board

Beyond the tool integrations, this project directly addresses pain points that have been a recurring concern for a couple of years — duplicate accounts, missing or incorrect linkages, and general data quality issues that cause friction during the sales process, complicate account assignments for CAMs and ASRs, and make it harder to track the metrics we care about. Rather than managing these symptoms individually, this effort works from the top down to fix the underlying foundation.

These issues have been chipped away at manually for years with limited progress. Doing this in bulk — with automated extraction, validation, and systematic cleanup passes — lets us close the gap at a scale that manual effort never could. The same tooling and reporting infrastructure we've built also positions us to automatically flag new issues as they arise, rather than letting them accumulate again.

---

## What We've Done So Far

**Data Quality Reporting — Complete**
Weekly Power BI dashboard tracking 140 metrics across linkage coverage, completeness, field quality, Registry parity, account staleness, and match readiness — at both the population level for trend tracking and the individual contact level for targeted cleanup. Any issue can be pulled as a list of affected accounts for a bulk fix, and every contact has an effective data quality score that could be surfaced directly in the CRM.

**Research and Groundwork — Complete**
Tested the bulk linkage tool end-to-end, built data models documenting how the tool behaves, and wrote the extraction queries and automation scripts needed to run linkage at scale. We also built a validation layer that goes beyond Deere's tight match criteria — before accepting any batch we run our own checks to ensure we are only creating linkages we are confident in.

**Quick Win Linkages — In Progress**
~13,000 accounts where a Registry entity ID is already known but the formal linkage was never created — no matching or cleanup required. First batch submitted and verified.

---

## Key Findings from the Data Quality Report

The DQ report surfaced the scale of our linkage gap and underlying data quality issues:

- **Only 11% of our active accounts (58,000 of 524,000) are formally linked** — the remaining ~466,000 are invisible to Deere's tools and downstream data sources
- **213,000 accounts — nearly 40% of contacts — have no transaction history**, most likely from mergers and acquisitions where data was loaded without transaction records or with broken account links
- **56,000 contacts — another 10% — have no associated account or vendor record at all**; combined with the above, roughly half of our active contacts have a fundamental data gap
- **120,000 accounts have not transacted with us in over five years** — inactivation candidates adding noise to matching and reporting
- **87% of contacts are missing an email address**; of those already linked to the Registry, 10% have an email in Deere's system we could copy over — a quick enrichment win requiring no outreach
- **30,000 contacts (~5%) have no contact information at all** — no email and no value in any of the three phone fields; these records cannot be reached or matched
- **185,000 individual field-level issues identified** — including placeholder values, invalid phone numbers and emails, invalid ZIP codes, and status text such as "Deceased" or "Do Not Use" entered in name and company fields

These findings reinforce why data cleanup runs in parallel with linkage and why the DQ report is a prerequisite for prioritizing where we focus effort.

---

## What's Ahead

| # | Phase | Work |
|---|---|---|
| 1 | **Quick Win Linkages** *(in progress)* | ~13,000 accounts with a known Registry ID — no matching required |
| 2 | **EQUIP Data Cleanup** | Standardize address and coded fields, fix invalid phones and emails, inactivate stale accounts — improves match quality before bulk upload |
| 3 | **Linkage — High-Quality Accounts** | Upload unlinked accounts in priority order (top accounts by revenue first); accept only tight matches that pass our validation checks |
| 4 | **Salesforce Cleanup** | Merge Prospect accounts into Customer accounts; delete orphaned online-lead Prospects; fix the process gap so future sales convert correctly |
| 5 | **EQUIP Deduplication** | Merge duplicate records in EQUIP and clean up duplicate entity IDs in Deere's Registry — a multi-system process requiring software partner coordination; confirmed duplicates so far are only a subset of full scope |
| 6 | **Other System Linkages** | Operations Center org mapping, Expert Connect enrichment, EDA/UCC lost sale alerting — each builds on the Registry linkage established in earlier phases |
