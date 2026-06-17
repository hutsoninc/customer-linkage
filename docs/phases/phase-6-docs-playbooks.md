# Phase 6 — Documentation & Playbooks

**Status:** 🔄 In Progress (parallel track)  
**Effort:** Low-Medium | **Risk:** Low | **Dependency:** None — runs in parallel, grows as each phase ships

**Goal:** Build practical, task-oriented documentation for the tools, datasets, and processes being created so any team member can use them effectively. The goal is short guides that answer "how do I do X" — not "how does X work." Documentation is written as processes are discovered, not saved for the end.

---

## Why This Runs in Parallel and Starts Early

As bulk cleanup work progresses, processes and best practices are being discovered in real time. Capturing them now — while the decisions are fresh — creates the playbooks that enable the team to handle ongoing manual cleanup after the bulk phase completes. Without this parallel track, the team inherits tools and data without the context to use them.

This also supports the JD partnership work (Phase 1): pushing JD to define shared standards is easier when we can show we have our own internal standards already documented.

---

## Planned Deliverables

### Account Cleanup Guide
Step-by-step instructions for identifying and fixing issues on an account:
- Using the DQ report to find problems for a specific contact
- Correcting data in EQUIP or Salesforce
- Confirming the fix is reflected in reporting after the next snapshot run

### Data Quality Report Usage Guide
How to read the Power BI report:
- How to pull a list of accounts affected by a specific issue
- How to interpret quality scores and tier classifications
- How to use contact-level issue flags from `contact_issues` for bulk cleanup lists

### EQUIP Data Entry Standards
Field-by-field reference for how each contact field should be populated:
- Required vs. optional fields by contact type (B / I / C)
- Valid values for coded fields (State, Country, Prefix, Generation, Suffix)
- What belongs in each address field vs. Doing Business As vs. Familiar Name
- How to handle business contacts (C-type): when to use entity vs. contact linkage

### CRM Enrichment Field Guide *(future — as Phase 11 ships)*
Reference covering each enriched Salesforce field: what it means, where it comes from, how often it updates, and how to use it in CAM workflows.

### Account Research Playbook *(future — as Phases 11–13 ship)*
Structured process for preparing for a sales call: which systems to check, what data to pull, how to interpret CLG leads, UCC filings, equipment history, and service records into a coherent picture of the account.

### Opportunity Mining Guide *(future — as Phase 16 ships)*
How to use opportunity scoring tools to identify and prioritize accounts worth contacting, with worked examples by scenario.

### Tool-Specific How-To Guides *(as each tool ships)*
Short reference docs for each new tool or dataset: Expert Connect enrichment, Operations Center mapping, CLG lead pipeline, auction sync, etc.

---

## Process for Adding to This Phase

When a new process is established or a best practice confirmed during any other phase:
1. Document it immediately in the relevant guide (or start a new one if it doesn't fit an existing guide)
2. Link the guide from the relevant phase detail file
3. Note in `docs/update-log.md` if the process reflects a decision that could affect other phases
