# EQUIP Data Update Log

A record of bulk data changes and linkage uploads applied to EQUIP contacts.

| Date | Type | Description | Records Affected |
|---|---|---|---|
| 2026-05-27 | Linkage Upload | Phase 1.2 — Anvil-only SF customers: uploaded 12,933 contacts to tight match tool (`queries/phase-1/block-7a.sql`); received 8,548 tight matches. Validated 7,263 by comparing tight match entity ID against Salesforce `Anvil__CustomerCompEntityID__c` and verifying contact type alignment (e.g., rejected B/C contacts matched to an Individual entity). Imported 7,263 via Create DBS Linkage tool. 1,285 tight matches rejected during validation. | 7,263 |
| 2026-05-27 | Linkage Cleanup | Orphaned registry linkages — queried `customer_cross_ref` for entries with no matching active EQUIP contact; 8 results, all corresponding to contacts merged in EQUIP. Bulk deleted all 8 linkages via Customer Linkage Tool, then manually re-linked 4 where the linkage had not carried over to the merged-to contact. | 8 |
| 2026-05-26 | Linkage Upload | Phase 1.3 — Manual review of 11 remaining non-tight-match contacts from the May MTD run; manually linked 7 via Customer Linkage Tool as a test | 7 |
| 2026-05-26 | Linkage Upload | Phase 1.3 Path B — Quote-to-sale gap: queried MTD May sales with quoted-prospect/sold-to variance (`queries/phase-1/block-7e.sql`); 50 unique customers submitted to Customer Linkage Tool; 39 tight matches returned, all confirmed matching entity IDs from the quoted prospect (Anvil `CustomerCompEntityID__c`); accepted all 39 in the tool | 39 |
| 2026-05-19 | Data Quality Fix | Manually corrected 10 `country` fields (`,`, `.`, `United States`, `usa`) → `US` | 10 |
| 2026-05-19 | Data Quality Fix | Updated `country` from `Canada` → `CA` on active AR/AP contacts | 19 |
| 2026-05-19 | Data Quality Fix | Updated `country` from `CANANDA` → `CA` on active AR/AP contacts | 68 |
| 2026-05-19 | Data Quality Fix | Updated `country` from `U.S.A.` → `US` on active AR/AP contacts | 138 |
| 2026-05-19 | Data Quality Fix | Updated `country` from `USA` → `US` on active AR/AP contacts | 151 |
| 2026-04-29 | Linkage Upload | Phase 1.1 Path A test — YAGLEJAC9453 and YOUNBUC709311 created; WILSONSOAK71156 and WILSONVAN423230 linked to merged entities | 4 |
| 2026-04-29 | Linkage Upload | Manual linkages via EQUIP Contact Maintenance before project tooling was in place | 2 |
