# Dataset: Equip.contact

**Source:** EQUIP DBS  
**Rows:** ~565,000 (all contact types, active and inactive)  
**Primary Key:** `contact_code`

---

## Overview

The central customer table in EQUIP. Stores all contact records regardless of type (Business, Individual, or Business Contact) and status (Active or Inactive). Every `Equip.ArMaster` billing account links 1:1 to a contact code in this table.

**Important:** `contact_code` is stored in `DDP.customer_cross_ref` as **ALL CAPS**. All joins between this table and `customer_cross_ref` must use `UPPER()` on both sides. See CLAUDE.md.

---

## Case Differences — Schema vs. Live Table

The schema CSV uses different casing than the actual column names in Fabric. Use the live names in queries:

| Schema CSV Name | Live Column Name |
|---|---|
| `CONTACT_CODE` | `contact_code` |
| `BANK` | `bank` |
| `BANK_BRANCH` | `bank_branch` |
| `BANK_BR_NO` | `bank_br_no` |
| `BANK_ACC` | `bank_acc` |
| `TAX_FILE_NO` | `tax_file_no` |
| `NOTE` | `Note` |
| `GST_REG_FLAG` | `GST_Reg_Flag` |
| `ABN` | `abn` |
| `TAX_EXEMPT_NO` | `tax_exempt_no` |
| `WINDOWS_USER` | `Windows_User` |

---

## Key Fields for Querying

| Column | Type | Notes |
|---|---|---|
| `contact_code` | char(15) | PK. Stored ALL CAPS in cross_ref — always use `UPPER()` when joining to `DDP.customer_cross_ref`. |
| `Business_Individual` | char(1) | `B` = Business, `I` = Individual, `C` = Business Contact. Drives how `Ckc_Id` and `Cmp_Ckc_Id` are interpreted. |
| `Inactive_Indicator` | char(1) | `A` = Active, `I` = Inactive, **`NULL` = Active** (treat null as A). |
| `Ckc_Id` | numeric(10) | For B/I: own Registry Entity ID. For C: **parent Business's** Registry Entity ID. |
| `Cmp_Ckc_Id` | numeric(10) | For C-type only: own Registry Contact ID. For B/I: unused (0 or null). Confirmed 96–99% match rate against `DDP.customer_cross_ref`. |
| `Inactive_Reason` | char(15) | `Deceased`, `Out of Business`, `Other`. Use this instead of stuffing status text into name/address fields. |

---

## DBS_Registry_UploadTemplate.csv Column Mapping

Maps `Equip.contact` fields to the columns required by the Customer Linkage Tool's Path B upload template.

| Template Column | EQUIP Column | Notes |
|---|---|---|
| `DBS Customer Number` | `contact_code` | |
| `Business Name` | `company_name` | varchar(150). Leave blank for pure individuals. |
| `Doing Business As Name` | `Doing_Business_As` | varchar(150). |
| `Prefix` | `title` | char(15). Valid values from Registry CSC dropdown (Mr., Mrs., Dr., etc.). Standardize with Contact Mass Update before upload. |
| `First Name` | `name` | varchar(150). One legal first name only. |
| `Familiar Name` | `Familiar_Name` | varchar(150). Nickname / preferred name. |
| `Middle Name` | `initial` | varchar(40). Despite field name, stores full middle name or initial. |
| `Last Name` | `surname` | varchar(150). |
| `Generation` | `Generation` | char(15). Jr., Sr., II, III, etc. |
| `Suffix` | `Suffix` | char(20). MD, PhD, CPA, etc. |
| `Address Line 1` | `street` | varchar(65). Physical/delivery address preferred. Do not combine physical + mailing. |
| `Address Line 2` | `street_2` | varchar(65). |
| `City` | `city` | char(30). |
| `State Code` | `state` | char(30). **Must be 2-char abbreviation** (IA, IL, IN) for Registry tight match. Run Contact Mass Update to standardize before upload. |
| `Postal Code` | `pcode` | char(11). |
| `Country Code` | `country` | char(30). **Must be 2-char code** (US, CA, AU) for Registry tight match. Standardize before upload. |
| `Email Address` | `email_address` | varchar(50). Used for potential match scoring. |
| `Work Phone` | `BusinessPhone` | char(15). Use the stripped version (no formatting chars) rather than `bus_phone`. |
| `Home Phone` | `PrivatePhone` | char(15). Stripped version of `prv_phone`. |
| `Mobile Phone` | `MobilePhone` | char(15). Stripped version of `mob_phone`. |
| `Home Fax` | `fax_no` | char(15). EQUIP has a single fax field — use for Home Fax on individuals, leave Work Fax blank. For businesses, use for Work Fax and leave Home Fax blank. |
| `Work Fax` | *(see above)* | |
| `Tax Type` | `Tax_Exempt_Type` | char(15). |
| `Tax ID` | `tax_exempt_no` | char(16). **Only valid for non-US countries** (AR, AU, BO, BR, etc. per template header). Do not populate for US records. |

### Phone Field Notes
EQUIP stores both raw (`bus_phone`, `mob_phone`, `prv_phone`) and stripped (`BusinessPhone`, `MobilePhone`, `PrivatePhone`) versions of phone numbers. The stripped versions remove formatting characters and are preferable for upload. Both are char(15).

### Business vs. Individual Upload Behavior
If a record has data in both `company_name` AND any person name field (`name`, `surname`, etc.), Registry will **never** tight-match it to a business record. To link at the business entity level, strip all person name fields from business records before upload. The EQUIP Contact Data Extract has a checkbox ("Exclude Business Contact Name for Businesses with Contacts") that handles this automatically.

---

## Full Column Reference

| Live Column | Type | Length | PK | Nullable | Description |
|---|---|---|---|---|---|
| `contact_code` | char | 15 | ✓ | N | Primary key. Stored ALL CAPS in DDP.customer_cross_ref. |
| `surname` | varchar | 150 | | Y | Last name. |
| `name` | varchar | 150 | | Y | First name. One name only — no "&" or "/". |
| `initial` | varchar | 40 | | Y | Middle name or initial. |
| `title` | char | 15 | | Y | Prefix (Mr., Mrs., Dr., etc.). Maps to Registry "Prefix" field. Values maintained in Type Code Maintenance = TI. |
| `sex` | char | 1 | | Y | Gender. |
| `marital_status` | char | 1 | | Y | Marital status. Values in Type Code Maintenance = MS. |
| `company_name` | varchar | 150 | | Y | Business/company name. Maps to Registry "Business Name" field — should be legal entity name. |
| `bus_phone` | char | 15 | | Y | Business phone (raw, may include formatting). |
| `BusinessPhone` | char | 15 | | Y | Business phone stripped of formatting. Use this for uploads. |
| `prv_phone` | char | 15 | | Y | Private/home phone (raw). |
| `PrivatePhone` | char | 15 | | Y | Private phone stripped of formatting. Use this for uploads. |
| `mob_phone` | char | 15 | | Y | Mobile phone (raw). |
| `MobilePhone` | char | 15 | | Y | Mobile phone stripped of formatting. Use this for uploads. |
| `fax_no` | char | 15 | | Y | Fax number. Single field — maps to Home Fax or Work Fax in template depending on contact type. |
| `email_address` | varchar | 50 | | Y | Primary email. Used for potential match scoring in the linkage tool. |
| `Email_Address_2` | varchar | 50 | | Y | Secondary email. |
| `street` | varchar | 65 | | Y | Street address line 1. Physical/delivery address. |
| `street_2` | varchar | 65 | | Y | Street address line 2. |
| `city` | char | 30 | | Y | City. |
| `state` | char | 30 | | Y | State. Must be 2-char abbreviation (IA, IL) for Registry upload. Standardize with Contact Mass Update. |
| `pcode` | char | 11 | | Y | Postal / zip code. |
| `country` | char | 30 | | Y | Country. Must be 2-char code (US, CA) for Registry upload. |
| `County` | char | 40 | | Y | County name. |
| `postal_street_1` | varchar | 65 | | Y | Mailing/postal address line 1. |
| `postal_street_2` | varchar | 65 | | Y | Mailing/postal address line 2. |
| `postal_city` | char | 30 | | Y | Mailing city. |
| `postal_state` | char | 30 | | Y | Mailing state. |
| `postal_pcode` | char | 11 | | Y | Mailing postal code. |
| `postal_country` | char | 30 | | Y | Mailing country. |
| `Postal_County` | char | 40 | | Y | Mailing county. |
| `address_dpid` | char | 10 | | Y | Postal system unique ID of the delivery address. |
| `postal_address_dpid` | char | 10 | | Y | Postal system unique ID of the mailing address. |
| `Business_Individual` | char | 1 | | Y | Contact type: `B` = Business, `I` = Individual, `C` = Business Contact. Drives Ckc_Id / Cmp_Ckc_Id semantics. |
| `Inactive_Indicator` | char | 1 | | N | `A` = Active, `I` = Inactive, `NULL` = Active. Always filter with `ISNULL(Inactive_Indicator, 'A') <> 'I'`. |
| `Inactive_Reason` | char | 15 | | Y | `Deceased`, `Out of Business`, `Other`. Use instead of stuffing status in name/address fields. |
| `Inactive_Effect_Date` | timestamp | 8 | | Y | Date contact was inactivated. |
| `Ckc_Id` | numeric | 10 | | Y | Registry ID. For B/I: own Entity ID. For C: parent Business Entity ID. Sentinel value 999,999,998 = invalid. |
| `Cmp_Ckc_Id` | numeric | 10 | | Y | For C-type only: own Registry Contact ID. For B/I: unused (null or 0). Confirmed 96–99% match rate against cross_ref. |
| `Last_Ckc_Req` | timestamp | 8 | | Y | Last time this contact was refreshed from the CKC/Registry database. |
| `Last_Xref_Date` | timestamp | 8 | | Y | Last time the associated cross-reference information was updated in Registry. |
| `Doing_Business_As` | varchar | 150 | | Y | DBA name. Searchable in Registry alongside Business Name. |
| `Familiar_Name` | varchar | 150 | | Y | Nickname or preferred name. Searched alongside First Name in Registry. |
| `Generation` | char | 15 | | Y | Jr., Sr., II, III, etc. Belongs in this field, not appended to surname. |
| `Suffix` | char | 20 | | Y | Credentials: MD, PhD, CPA, etc. |
| `Creation_Date` | timestamp | 8 | | Y | Date contact record was created. |
| `Last_Modified_Date` | timestamp | 8 | | Y | Date contact record was last modified. |
| `Account_Class` | char | 15 | | Y | Customer account class. Can be used to identify internal/employee accounts for exclusion. |
| `contact_type` | char | 2 | | Y | Optional user-defined field. |
| `class` | char | 5 | | Y | Optional user-defined field. |
| `lang_pref` | char | 2 | | Y | Language preference (e.g., EN). |
| `Tax_Region` | char | 20 | | Y | Tax region code. In USA, reflects state/municipal/parish tax jurisdiction. |
| `Tax_Status` | char | 2 | | Y | `SE` = Tax Exempt, `ST` = Taxable, `SN` = Never Tax. |
| `Tax_Exempt_Type` | char | 15 | | Y | Tax exempt type code. |
| `tax_exempt_no` | char | 16 | | Y | Tax exempt number. Maps to "Tax ID" in upload template — only valid for non-US countries. |
| `tax_file_no` | char | 2 | | Y | Tax file number. |
| `Social_Security_No` | char | 15 | | Y | SSN. Do not include in upload files or name/address fields. |
| `abn` | char | 16 | | Y | Australian Business Number. May also be used for TIN. |
| `company_acn` | char | 20 | | Y | Company ACN number. |
| `Cust_Delivery_Flag` | char | 1 | | Y | USA: Y = invoice requires delivery to customer (affects tax region). |
| `DOB` | timestamp | 8 | | Y | Date of birth. Do not expose or include in uploads. |
| `REWARDS_NO` | numeric | 10 | | Y | JD Rewards number. |
| `Rewards_Status` | char | 15 | | Y | JD Rewards status. |
| `Rewards_Points` | numeric | 12 | | Y | JD Rewards points balance. |
| `Note` | char | 4000 | | Y | Free-text notes on the contact. |
| `change_case_flag` | char | 1 | | Y | Y = include in Change Case Utility run. |
| `privacy_marketing` | char | 1 | | Y | Y = keep details private from marketing. |
| `privacy_service` | char | 1 | | Y | Y = keep details private from service. |
| `privacy_other` | char | 1 | | Y | Y = keep details private from other functions. |
| `Privacy_Parts` | char | 1 | | Y | Y = keep details private from 3rd party functions. |
| `Privacy_3rd_Party` | char | 1 | | Y | 3rd party privacy flag. |
| `bank` | char | 50 | | Y | Financial institution name. |
| `bank_branch` | char | 20 | | Y | Bank branch number. |
| `bank_br_no` | char | 10 | | Y | Bank branch state number. |
| `bank_acc` | char | 15 | | Y | Bank account number. |
| `bank_acc_name` | char | 50 | | Y | Bank account name. |
| `driver_lic_no` | char | 20 | | Y | Driver's license number. |
| `Driver_Lic_Expiry_Date` | timestamp | 8 | | Y | Driver's license expiration date. |
| `rta_no` | char | 20 | | Y | RTA number. |
| `fleet_no` | char | 20 | | Y | Fleet number. |
| `dealer_no` | char | 20 | | Y | Dealer number. |
| `GST_Reg_Flag` | char | 1 | | Y | Y = GST applicable. |
| `Rental_Insurance_Policy_No` | char | 30 | | Y | Rental insurance policy number. |
| `Rental_Insurance_Provider` | varchar | 60 | | Y | Rental insurance provider name. |
| `Rental_Insurance_Limit` | numeric | 12 | | Y | Rental insurance limit amount. |
| `Rental_Insurance_Expiry_Date` | timestamp | 8 | | Y | Rental insurance expiration date. |
| `prev_CG_survey_date` | timestamp | 8 | | Y | Previous complete goods invoice survey date. |
| `Prev_Parts_Survey_Date` | timestamp | 8 | | Y | Previous parts invoice survey date. |
| `Prev_Wkshop_Survey_Date` | timestamp | 8 | | Y | Previous service/workshop invoice survey date. |
| `prev_rental_survey_date` | timestamp | 8 | | Y | Previous rental invoice survey date. |
| `Min_CG_Survey_Interval` | integer | 4 | | Y | Minimum days between complete goods surveys. |
| `Min_Parts_Survey_Interval` | integer | 4 | | Y | Minimum days between parts surveys. |
| `Min_Wkshop_Survey_Interval` | integer | 4 | | Y | Minimum days between service surveys. |
| `Min_rental_Survey_Interval` | integer | 4 | | Y | Minimum days between rental surveys. |
| `Windows_User` | varchar | 50 | | Y | Windows/RACF user associated with the contact. |
| `CreatedByUser` | varchar | 50 | | Y | User who created the record. |
| `CreatedByApp` | varchar | 50 | | Y | Application that created the record. |
| `ModifiedByApp` | varchar | 50 | | Y | Application that last modified the record. |
