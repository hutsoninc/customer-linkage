# Source Materials Summary

Consolidated summary of all input documents provided for the customer linkage project.

---

## File Parse Status

| File | Parsed | Notes |
|---|---|---|
| `Customer+Linkage+Help+Document+Current.pdf` | ✅ Full | 16 pages, complete content |
| `EQUIP_Customer_CleanUp.pdf` | ✅ Full | 9 pages, complete content |
| `EQUIP_CustomerLinkageContactData_Report.pdf` | ✅ Full | 1 page, complete content |
| `Create_Bulk_Linkages_Template.csv` | ✅ Full | Column headers only (template is empty) |
| `DBS_Registry_UploadTemplate.csv` | ✅ Full | Column headers only (template is empty) |
| `Delete_Bulk_Linkages_Template.csv` | ✅ Full | Column headers only (template is empty) |
| `AHW 2023 Presentation.pdf` | ✅ Full | 62 pages (many image-only slides); all text-bearing pages captured |
| `Customer Data Linkage EXPO Final.pptx` | ✅ Full | 19 slides with speaker notes captured |
| `Customer Data Management Job Aid.docx` | ✅ Full | Complete content captured |

---

## Customer Linkage Help Document (Current)
**Source:** `Customer+Linkage+Help+Document+Current.pdf`  
**Origin:** Pulled directly from https://customerlinkage.deere.com/ — most up-to-date official documentation.

### Overview

The Customer Linkage application creates linkages (pointers) in bulk between DBS customers and John Deere Registry customers. The linkage does **not** sync data between systems — it simply establishes that a DBS contact and a Registry entity are the same customer. Data differences between the two records are acceptable.

Once linked, the DBS number appears in the CSC (Common Search Component) **Membership column** in JD sales tools, visible only to the dealership that created the linkage.

### Glossary

| Term | Definition |
|---|---|
| **DBS** | Dealer Business System |
| **EQUIP** | The DBS used by US and Canadian dealers |
| **Registry (IKC/CKC)** | John Deere's Customer Master Datasource — source of truth used by Sales Center, JDQuote2, JDMint, JDSET, Configurator, Rewards, Warranty Portal, etc. |
| **Linkage** | A pointer between a DBS customer and a Registry customer. Data can differ, but they must be the same real-world customer. |
| **CSC (Common Search Component)** | Tool embedded in JD sales tools to search, add, and edit Registry customers. DBS number appears in the Membership column when linked. |
| **Tight Match** | Registry's algorithm determined the two records are the same customer based on standardized name and address comparison (e.g., "Bill" and "William" are treated as the same). Auto-linkable without human review. |
| **Potential Match** | Close but not exact — requires a person who knows the customer to confirm. Uses phones, email, and Tax ID to surface candidates. |

### Registry Customer Types

| Registry Type | Business Name | Person Name | Entity ID | Contact ID |
|---|---|---|---|---|
| Business | SMITH GARAGE | — | 501065658 | — |
| Business with Contact | SMITH GARAGE | MICKEY SMITH | 501065658 | 105263458 |
| Business with Contact | SMITH GARAGE | JOHN SMITH | 501065658 | 105263459 |
| Individual | JACK KEAN | — | 587894325 | — |

- Business and Individual records have an **Entity ID**
- Business Contacts have the **parent Business's Entity ID** plus their own **Contact ID**

### Recommended Approach (from Deere)

1. Start with a small list of 10–100 customers you know you want to link
2. Clean customer data in EQUIP (remove unneeded data, put data in correct fields)
3. Extract DBS customer data to CSV using the Contact Data Extract
4. Upload to Customer Linkage application and create linkages
5. Communicate to dealership staff so they can take advantage of the CSC Membership column
6. Gather feedback
7. Repeat with the next set of customers

### Access Requirements

Two DPA (Dealer Profile Administrator) roles are available:

| Role | Capabilities |
|---|---|
| **Dealer Customer Maintainer** | Upload files + all Reviewer access |
| **Dealer Customer Reviewer** | Create linkages for tight matches, review customers and create linkages on the Review page |

If the dealership is not set up to create linkages, contact CustomerLinkageFeedback@JohnDeere.com.

### Two Methods for Creating Linkages

#### Method 1: Match DBS Customer List
Upload a CSV of customer data. Registry's algorithm attempts to match each record to a Registry customer. Results in Tight Matches (auto-link) and Potential Matches (manual review).

**File requirements:**
- CSV format, UTF-8 encoding if special characters present
- Maximum 6MB / ~60,000 rows per file (break larger lists into multiple files)
- Column headers required in row 1 (row 1 is not processed)
- No spaces before or within DBS numbers (trailing spaces are removed automatically)
- State codes: capitalized abbreviations (IA, IL, FL, CA, MB, BC)
- Country codes: capitalized 2-character codes (US, CA, AU, NZ)

**Important business vs. contact rule:** If a record has data in both business name fields AND person name fields (Prefix through Suffix), Registry will **never** tight match it to a business record. To link to the business entity (not a contact), strip all person name fields from business records before uploading.

**Processing:** ~1 minute per 500 records. Email notification when complete.

**Email statistics provided on completion:**
- Count of records in file
- Count of duplicate records
- Count already linked
- Count with tight match
- Count with potential match
- Count with no match
- Count with errors

For error details beyond what the email shows, forward to: 90ISCustomerLinkage@JohnDeere.com

#### Method 2: Create DBS Linkage
If the Registry Entity ID is already known (stored in DBS or CRM), upload DBS Number + Entity ID directly. Skips the matching process entirely. Contact ID is optional — only needed when linking to a specific contact under a business entity.

**File format:** `DBS Number`, `Entity Id`, `Contact Id`

### Workflow After Upload

**Tight Match tab:**
- "Create Linkage" — bulk-creates all tight match linkages
- "Remove From List" — removes all tight matches without creating linkages (if you change your mind)
- "Download/Tight Match Report" — exports the matched records
- "Exact Search" — find a specific DBS number to review its tight match

**Review tab (Potential Matches and No Matches):**
- Displays 30 customers at a time
- Search by DBS Number or Postal Code (starts-with)
- Click "Review" next to a customer to see potential Registry matches
- "Create Linkage" — links to a potential match
- "Create New Customer & Link" — adds customer to Registry (pre-populated from your file) then creates linkage
- "Remove Customer From List" — skips this customer, no linkage created

**Notes on Review tab:**
- "Deceased" or "Out of Business" will display if the Registry customer has that status
- EQUIP dealers: linkages created in Registry via the tool are sent to EQUIP overnight

### Removing Linkages

- **EQUIP dealers:** Remove linkages through EQUIP (the Maintain page in the tool is not available to EQUIP dealers)
- **Non-EQUIP dealers:** Use the Maintain page — enter DBS Number, click "Retrieve Linkage," then "Remove Linkage"
- Bulk delete is available via the Delete DBS Linkage upload using `Delete_Bulk_Linkages_Template.csv` (DBS Number only)

### Additional Features

**View Equipment:** Available for Registry customers — retrieves all equipment associated to the customer visible to your dealership in JDAim. Requires JDAim access (granted by Dealer Profile Administrator).

**Potential Duplicate DBS Customer Listing:** Identifies DBS numbers linked to the same Registry customer (i.e., confirmed EQUIP duplicates). Accessible within the tool.

**DBS Data Share (US/CA EQUIP dealers only):** Within CSC 2.0, after finding a linked customer, users can click "DBS Data Share" on the Edit Customer page to update both the Registry record and the EQUIP record simultaneously. Not available for JD Financial customer records.

Data that should **NOT** be shared with Registry via DBS Data Share:
- Combined names ("John & Mary") in First Name — Registry requires individual records
- Non-address data in address fields ("C/O Bill")

These can remain in EQUIP — differences between the two records are acceptable as long as they represent the same customer.

### FAQ Highlights

**Q: What happens if customers are merged in CSC or JDAim?**  
A: Linkages on the losing record move to the surviving record.

**Q: What happens if a business contact is deleted in CSC?**  
A: Name, email, and phones are deleted. Business-related data (including DBS linkages) moves to the business. EQUIP dealers: change is reflected in EQUIP the following day.

**Q: How to set up EQUIP to integrate with Registry?**  
A: Reference KB0111655 "EQUIP Set Up for Integration with Registry and Usage."

**Q: Training available?**  
A: Yes — training video linked in the document at https://p.widencdn.net/04rxtm/CustLinkageEQUIPCustDataCleanUp

---

## EQUIP Customer Record Clean Up Guide
**Source:** `EQUIP_Customer_CleanUp.pdf`  
**Origin:** JDIS / EQUIP documentation for dealers.

### Important Prerequisites Before Any Merges

- **Coordinate with Strategic Solution Providers** — CustomerTRAX, Foresight, and Sedona must merge data in their applications to stay in sync
- **Service Delivery impact** — Update any In-Progress Work Orders to the surviving Customer Number before merging
- **Other affected systems** — Merging or deleting customer records impacts Service Delivery, Service Admin Portal (SVAP), and JDParts
- **Contact JDIS Support** for questions

### Step 1: Inactivate Customer Records

Use the **Inactivate Customer Records** program to mark customers as Inactive based on last activity date. Options:
- Last Activity Date is equal to or less than [date]
- Created Prior To [date] (excludes newer customers)
- Records with No Creation Date

Can also filter by Account range and Territory. Inactive customers:
- Are excluded from the Customer Linkage Contact Data Extract
- Do not appear in Smart Searches in invoicing and crediting programs

Set an **Inactive Reason** (e.g., Out of Business, Deceased) — this eliminates the need to store "OUT OF BUSINESS" text in a name or address field.

### Step 2: Locate Duplicate Contacts

Use the **Locate Duplicate Contacts** program. Search criteria options (up to two can be combined):

| Search By | What It Compares |
|---|---|
| Phone Number | Business, Mobile, and Private phone numbers |
| Email Address | Email and Email 2 fields |
| Name | Company Name or First+Last Name, combined with City and State (Delivery or Postal) |
| Cust Ent ID / Business Contact ID | Either ID |

Additional filter: **Created Since** date — limits results to contacts created after a date (useful for finding recently entered duplicates).

Search by Name supports a range (From: "a" To: "bz") to work through the alphabet in batches.

Results show AR Merge, AR Merge Tile, and Delete checkboxes for action.

### Step 3: Merge Duplicate Customers and Contact Codes

Use the **Customer/Contact Merge** program. Key points:
- Run **during off-hours** — merges update a large number of tables
- The merge updates all EQUIP transactions from the "From Customer" to the "To Customer" account number
- Check **"Delete After Merging"** to remove the duplicate
- After merging customers, the program launches the **Merge Contact Codes** program directly

**Merge Contact Codes** options:
- **Merge with Review** — opens the Merge Contact Codes program to compare fields side by side before merging
- **Merge without Review** — automatically merges contacts with no field-level review
- **Do not merge Contacts** — skips contact merge

The Merge Contact Codes screen shows both contact records side by side with `>>` arrows to copy individual field values from one to the other. Surviving Contact Code gets all transactional history.

Note: Contacts can also be merged directly from **Contact Maintenance** via the "Merge Contacts" button.

If you try to delete a Contact Code that is associated with a merged Customer Account, you may not be able to due to existing transactions — merge the contact codes instead of deleting.

### Step 4: Contact Mass Update

Use the **Contact Mass Update** program to standardize field values across the entire CONTACT database. Fields added for Registry alignment:

- **Prefix** — Old Value dropdown shows all non-standard prefixes; convert to valid Registry values
- **State** — Old Value dropdown shows non-standard entries (e.g., "Illinois" → "IL")
- **Country** — Old Value dropdown shows non-standard entries

Work through each Old Value until the dropdown is empty — that means all data is now in Registry-compliant format. The system replaces all matching Old Values with the New Value in the CONTACT table.

### Step 5: New Fields for Registry Alignment

These fields were added to Contact and Customer Maintenance to match Registry conventions. Data previously stored in other fields should be moved here:

- **Doing Business As**
- **Familiar Name** (nickname)
- **Generation** (Jr., Sr., III, etc.)
- **Suffix**

Tip: Download Contact Code data to Excel to audit which records have data in the wrong fields.

### Step 6: Customer Linkage Contact Data Extract

When ready to export contacts for upload to the Customer Linkage Tool:
- Use the EQUIP utility: **Customer Linkage Contact Data Extract**
- Only returns contacts **not already linked to Registry** (no prior Customer Entity ID)
- Output saved as CSV — column order must not be changed

See separate section below for full details.

---

## EQUIP Customer Linkage Contact Data Extract
**Source:** `EQUIP_CustomerLinkageContactData_Report.pdf`  
**Origin:** EQUIP documentation for the data extract utility.

### Overview

Generates a CSV file of EQUIP contacts formatted for upload to the Customer Linkage Tool. **Only includes contacts that have not previously been linked to Registry** (no Customer Entity ID / CKC ID stored).

The report must be added to EQUIP via Menu Maintenance before it is available.

### Selection Criteria

| Option | Description |
|---|---|
| Selection By | Contact Code, Account No, or Name |
| Name search | Searches Company Name, Doing Business As, or Last Name (starts-with) |
| Top N Customers Based on Sales | Filter to return only top N contacts by sales volume |
| Territory | Filter by territory |
| Contact Created Since Date | Filter to contacts created after a date |
| Include only Contacts with associated AR Customer No | Restrict to contacts with a billing account |
| Exclude Inactive Contacts | Recommended — excludes inactivated records |
| Equipment/Rental Sales and Parts/Service Sales | Date range filters for sales activity |

### Business vs. Contact Linkage Option

**"Exclude Business Contact Name for Businesses with Contacts?" checkbox:**  
If checked, the export removes all person-name fields (Prefix, First Name, Familiar Name, Middle Name, Last Name, Generation, Suffix) from Business-type records that have associated contacts. This causes Registry to match the record to the **business entity** rather than to a specific business contact.

Use this when you want the DBS linkage on the business record itself, not on an individual contact under it.

### Output

- CSV file with columns in a fixed order (do not reorder)
- Columns: DBS Customer Number, Account No, Business Name, Doing Business As Name, Prefix, First Name, Familiar Name, Middle Name, Last Name, Generation, Suffix, Address Line 1, and more
- Save using "Save Extract to File"

---

## CSV Upload Templates
**Source:** Exported from https://customerlinkage.deere.com/

### Create_Bulk_Linkages_Template.csv
Used for **Method 2: Create DBS Linkage** — when the Registry Entity ID is already known.

| Column | Notes |
|---|---|
| `DBS Number` | EQUIP contact code |
| `Entity Id` | Registry Entity ID |
| `Contact Id` | Optional — only needed to link to a specific contact under a business |

### DBS_Registry_UploadTemplate.csv
Used for **Method 1: Match DBS Customer List** — when the Registry Entity ID is not known and matching is needed.

| Column | Notes |
|---|---|
| `DBS Customer Number` | EQUIP contact code |
| `Business Name` | Leave blank for individuals |
| `Doing Business As Name` | |
| `Prefix` | Valid values from CSC "Add Individual" page dropdown |
| `First Name` | Leave blank for businesses with unknown contact |
| `Familiar Name` | |
| `Middle Name` | |
| `Last Name` | |
| `Generation` | Valid values from CSC "Add Individual" page dropdown |
| `Suffix` | |
| `Address Line 1` | Physical address preferred; do not combine physical + mailing |
| `Address Line 2` | |
| `City` | |
| `State Code` | Capitalized abbreviations: IA, IL, FL, CA, MB, BC |
| `Postal Code` | |
| `Country Code` | Capitalized 2-character: US, CA, AU, NZ |
| `Email Address` | Used for potential match scoring |
| `Work Phone` | Used for potential match scoring |
| `Home Phone` | |
| `Mobile Phone` | |
| `Home Fax` | |
| `Work Fax` | |
| `Tax Type` | |
| `Tax ID` | Only valid for specific countries (not US) |

### Delete_Bulk_Linkages_Template.csv
Used to remove existing linkages in bulk.

| Column | Notes |
|---|---|
| `DBS Number` | EQUIP contact code whose linkage should be removed |

---

## AHW 2023 Presentation
**Source:** `AHW 2023 Presentation.pdf`  
**Origin:** AHW, a John Deere dealership that piloted customer linkage early, presented their process and lessons learned at a 2023 dealer conference.

### Core Vision
One unique customer record per customer. Data entered accurately and consistently from the start — name, address, phone, email captured correctly at point of entry (parts counter, service desk). "Garbage in, garbage out."

### Name Data Rules (from AHW's training)
- Use **legal names** — not nicknames (put nickname in Familiar Name field)
- **No joint names** in First Name (e.g., "John & Mary") — create two individual records, then use Primary/Secondary Customer on the quote. JD Data Stewards actively revert records with multiple names because DOB/SSN may be associated.
- **Generation** (Sr., Jr.) belongs in the Generation field, not appended to last name
- Familiar Name field is searched alongside First Name — use it for preferred names

### Business Records
- Only **legally verified** business customers should have business-type records (important for Rewards program)
- Secretary of State website is a recommended resource to verify legal entity names
- DBA names are searchable — search goes against all business name fields

### EQUIP Cleanup Programs — AHW's Experience

**Contact Mass Update** — bulk change field values across all contacts. Powerful but dangerous.
> "There's enough power to quickly wreck all of your data. Be Careful!" — e.g., accidentally replacing all zip codes with 11111.

**Locate and Merge Duplicate Accounts** — finds duplicates by phone, email, name, or JD Registry ID. Groups results by color. Built-in merge tool.
> Caution: matching phone numbers alone doesn't mean two accounts should be merged — confirm before merging.

**Inactivate Customer Records** — AHW's "Junk Closet" strategy. Called it a "game changer."
- AHW used: **last activity date ≥ 2 years ago**, excluding records created in the last year
- Result: 230,000 total contacts → 68,500 active
- Parts/service teams were initially concerned, then "quickly thrilled" — searching "Mike Miller" went from 20 results to 6
- Allows focus on a smaller, manageable active set; inactive records can be reactivated one at a time with cleanup and linkage at that point

### AHW's Execution Strategy

1. Created a dedicated **Customer Team**, trained them on the right way
2. **Inactivated 100,000+ accounts** first — made the problem smaller before trying to clean it
3. **Turned off access** to adding customer records to non-experts — most controversial but most effective step. Prevents the pile from growing while cleaning. "You can't let data cleanup turn into doing laundry!"
4. **Audited outside systems** that add to the pile: Handle, Service Delivery, Customer Dealer Portal

### Measuring Progress
- **EQUIP query**: pulls unlinked customers with recent invoice activity. Start by linking yesterday's customers, then the day before, work backward in time. Set achievable goals and celebrate when hit.
- **Linkage progress chart**: tracked active linked vs. unlinked over time.
  - Started ~35,000 unlinked active accounts
  - After aggressive inactivation (Oct 2020): ~13,000 active unlinked
  - Oct 2020 → Oct 2021: moved from 70% linked to **100% linked**
  - April 2022: acquired 4 stores → ~10,000 new unlinked; back to 100% by December 2022

### Bulk Linkage — AHW's Honest Assessment
> "AHW piloted the Bulk Linkage process. While it gave us a head start on linkage, it left us with no good way of knowing which customers we've cleaned. We would like to know that linked customers are clean, in both DBS and Registry. If you use bulk linkage you won't be able to know that."

Bulk linkage creates linkages fast but doesn't guarantee the underlying data is clean. AHW's preferred approach: link one customer at a time so you can verify data quality as you go.

### Operations Center Linkage (mentioned at end of presentation)
- JD used an automatic process to compare Operations Center Organizations against Registry customer data (like tight-match horseshoes logic)
- Dealers can review, remove, and reestablish those Org links — or create links for Orgs missed in the automatic process
- Org linkages are visible to **all users** in JD Sales Tools (not just the creating dealer)
- Org linkage is currently manual for dealers; AHW noted it will eventually be automatic — if 100% linked when that begins, saves significant effort

### Benefits by Department (AHW's experience)
- **Parts**: cleaner search, fewer John Smiths to filter through, faster/more accurate results, find equipment quicker
- **Service**: accurate PIP lists, proper customer info on Expert Alerts, fewer wrong-account work orders, service campaigns reach correct customers
- **Admin**: Rewards membership visible in membership column for quotes → correct entity selected → reduced chargebacks; Retail Bonus PO shows Rewards number; easier to submit
- **Sales/Marketing**: JDAIM campaign lists more reliable; mismatches (entity IDs not linked to DBS) are correctable; salespeople trust the lists

### Customer Trust
AHW cited Cisco annual customer surveys: customers care increasingly about how their personal data is handled, and most won't do business with companies they don't trust with data. How you handle data entry signals your trustworthiness. "A 'We can fix it' culture replaces the 'Just deal with it' culture."

---

## Customer Data Linkage EXPO Presentation
**Source:** `Customer Data Linkage EXPO Final.pptx`  
**Origin:** Conference presentation by Vickie Denger, Product Manager for CSC and DBS Customer Linkage at John Deere. Includes detailed speaker notes.

### Scale of the Problem
- JD Customer Registry: **~39 million customer records**
- Current DBS to Registry linkages: **~1.6 million**
- Current Org to Registry linkages: **~330,000**

### Multiple Views of the Customer
Three separate databases, each with a different owner:

| View | System | Owner |
|---|---|---|
| Dealer view | Dealer Business System (EQUIP, CDK) | Dealer-controlled |
| Deere view | John Deere Customer Registry (IKC/CKC) | Deere-controlled |
| Customer view | Operations Center Organization | Customer-controlled |

Registry receives data from many sources: dealers, UCC-1 filings, FSA/SIC purchased data, sales leads/events, and John Deere Digital Accounts created by customers. Registry avoids duplicates but errs on the side of caution if name/address don't match after standardization.

**JD Financial**: JD Financial data flows to Registry and **overwrites** what is there. For customer record updates where JD Financial is involved, reach out to JDF — do not attempt to edit the Registry record directly.

### Benefits of Linking
- **Save time**: fewer, more accurate records to search; DBS linkage visible so dealership knows which record is theirs
- **Get it right the first time**: consistently use the correct customer record
- **Get paid**: reduce Rewards and Retail Incentive chargebacks
  > "Alex Ezzell at Quality Equipment: it has significantly reduced their chargebacks." Chargebacks are expensive to fix — sometimes take days if customer merges and Rewards grouping are needed.
- **Know the customer's entire fleet**
- **Smoother workflows**: quote/PO integration from DBS or CRM with JD Quote will know the corresponding customer

### Linking DBS to Registry
- Works with any DBS — no special DBS functionality required
- EQUIP and CDK have built-in extract functionality
- EQUIP dealers must use EQUIP to remove linkages (not the Customer Linkage Tool's Maintain page)
- **Recent enhancement**: DBS customer phones and emails are now used to find more potential Registry customer matches
- Customer Linkage Tool can download a report of all your dealership's DBS linkages plus Registry customer details

### Approach Options (Vickie's recommendations)
1. **Customer Data Management "Experts"** — restrict who can add/update customer records to a small trained group
2. **Monitor New/Updated Records** — run reports to catch newly added customers, verify they were entered correctly and linked
3. **Clean as you Link** vs. **Link then clean as you use** — dealer's choice

Key principle: educate dealership on importance of correct data entry from the start. Since Registry receives data from many sources, creating links on current customer data also makes it easier to recognize and merge duplicates that flow in.

### Recommended Starting Point
- Start with **top 100** customers, then the next 100, then top 20%
- Early on, prioritize **problematic records** that always cause trouble: father/son pairs, records entered in multiple duplicate formats
- Set goals and monitor progress

### Digital User Account
- Any customer can connect to all JD online tools by creating a Digital User Account
- New Digital User Accounts automatically create an Organization **linked to a Registry customer**
- Dealers can send account creation invitations: `https://account.deere.com/invite`
- Invite process uses the customer search tool — can be linked to an existing Registry customer, preventing duplicate creation

### Org Linkage
- Created and removed in **Operations Center → Team Manager**
- Visible to **all users** in JD Sales Tools (not just the creating dealer)
- Near-future roadmap: plans to show Organization Name and a partnership indicator in the JD Applications customer search

### Roadmap / Future Plans
- CSC 1.0 is being replaced by CSC 2.0 — enhanced search, more intuitive, responsive to screen size
- Near future: show Organization Name and dealership partnership indicator in the customer search UI
- Future: more seamless terminal management in Operations Center once Org linkages are established

---

## Customer Data Management Job Aid
**Source:** `Customer Data Management Job Aid.docx`  
**Origin:** Official Deere best practices document for adding and updating customer records.

### Intent
Best practices for adding and updating customer records. Applies to everyone at the dealership who touches customer data — parts counter, service desk, sales. "Garbage in, garbage out."

All customers added through JD Sales Tools and JDAim are added to Customer Registry. Correct entry at point of capture produces high-quality Registry data.

### JD Financial Note
JD Financial data flows to Registry and overwrites it. If a customer has JDF involvement, contact JD Financial for updates rather than editing Registry directly.

### Individual Name Field Rules

| Field | What Goes Here |
|---|---|
| First Name | Legal first name only. One name only — no "&", "and", or "/" |
| Middle Name | Middle name or initial. No other person's name |
| Last Name | Legal last name only — no Generation or Suffix |
| Generation | Sr., Jr., III, etc. |
| Suffix | Titles/licenses: MD, PhD, etc. |
| Familiar Name | Nickname or preferred name. Optional. Searched alongside First Name |

### Business Name Field Rules

| Field | What Goes Here |
|---|---|
| Business Name | Legal entity name — full legal name (e.g., "123 Lawn and Landscapes, Inc.") |
| Business Name 2 | Department within a government entity, or branch/location of a private entity |
| DBA / Trading As | Commonly known business name — name on trucks, website, etc. |

- Use Secretary of State website to verify full legal business names
- The more complete the business name, the lower the chance of duplicates
- Names of business contacts should NOT go in Business Name 2 or DBA

### Address Rules
- **Physical/Delivery address**: valid street address, no directional info
- **Mailing address**: PO BOX format; billing address if different from physical
- Do not put "In Care Of," "c/o," or "ATTN:" in Street Line 1

### Best Practices — Adding a New Record
- Search for an existing customer first before creating new
- Capture all data: name, address, phone, email
- Never use dealership or employee info to bypass a required field
- Leave fields blank if data is unavailable — do not use placeholder data (e.g., 555-555-5555)
- Do not put SSN/Tax IDs in name or address fields

### Best Practices — Updating a Record
- Update when: customer requests a change, mail returned, customer notifies out of business
- **Never change a record from one individual to another** — the record may have DOB and SSN/Tax ID associated to it that you cannot see
- If a customer is deceased: mark the Registry record as deceased (do not repurpose the record) — DOB/SSN may be attached
- If a customer's business closes and they open a new one: create a new business record; do not overwrite the old one

### Tools to Maintain Registry Data
Three processes available:
1. **Dealer Requested Customer Merge** via Channel Applications (CSC)
2. **JDAim Feedback Forms**
3. **Support Center** — choose "Channel Customer Data Steward" for: Customer Marketing, Update Customer Attributes/Details, Customer Grouping/Merging
