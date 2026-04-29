Data is in Fabric Lakehouses. Write queries in T-SQL format.

# Equip.contact

Table has contacts with contact information, name, address, etc.

Columns:
- Ckc_Id - int - this seems to be the main ckc id for the contact. 58.3k non-null
- Cmp_Ckc_Id - int - I'm not sure what this is exactly. Complimentary ckc id? 50k of the 58.3k are 0. 4k are populated with a different ckc id. The reamining ~4k are null. This might tie to a company with multiple contacts? Need help verifying.
- contact_code - string - PK
- Business_Individual - string - B = Business, I = Individual, C = Business Contact
- Inactive_Indicator - string - A = Active, I = Inactive, null = Active

# Equip.ArMaster

Table has customer account information. Balance, credit terms, credit limit, etc.

Columns:
- ACC_NO - int - PK
- contact_code - string - FK to Equip.contact.contact_code. Primary contact on the account.


# DDP.customer_cross_ref

Deere Dealer Data Product (DDP) dataset. This is synced to our Fabric environment from Deere's CKC registry. These are confirmed linkages by Deere. Table has a relationship map between CKC and Equip.

Columns:
- entity_id - int
- contact_id - int
- cross_ref_number - string - FK to Equip.contact.contact_code

58.3k rows. 57.7k distinct count entity_id, ~4k distinct count contact_id.

# DDP.customer_profile

Deere Dealer Data Product (DDP) dataset. This is also synced to our Fabric environment from Deere's CKC registry. It includes contact information similar to our Equip.contact table: names, addresses, contact info, etc.

Columns:
- entity_id - int
- contact_id - int - note: seeing all 0's in this from the top 1k rows preview in my Fabric lakehouse view.
- out_of_busn_ind - Y/N out of business
- descd_ind - Y/N deceased

# Salesforce.Account

Salesforce accounts. Includes Customer accounts (RecordTypeId = 0124W000001aGwlQAE) synced from Equip with a contact code and account number, plus Prospect accounts (RecordTypeId = 0124W000001aGwgQAE) which are exclusive to Salesforce.

Columns:
- Id - string - PK salesforce record id
- Anvil__AccountNumber__c - Equip.ArMaster.ACC_NO
- RecordTypeId - 0124W000001aGwlQAE = Customer, 0124W000001aGwgQAE = Prospect
- Anvil__CustomerCompEntityID__c - int - customer entity id used by salesforce/anvil integrations.
- H_Equip_contact_Ckc_Id__c - int - ckc id synced from equip

93.5k Anvil__CustomerCompEntityID__c exist and 56.5k H_Equip_contact_Ckc_Id__c exist. If H_Equip_contact_Ckc_Id__c is populated, it will overwrite what is in Anvil__CustomerCompEntityID__c.

# Additional datasets that may be useful

I have queries to calculate account sales history trends by account number, so we could filter to accounts we've transacted with recently or target high value accounts first.

I have quote data from Salesforce and Sold To Customer tied to individual stock units. This often varies for unlinked customers. The quote is tied to the Prospect while the stock unit is tied to the Customer we sold it to. I can write queries to surface these for potential merges and updates to registry.

Warranty registration data from Deere + our own equipment dataset from service and sales. We can join these together on serial number and check the contact in Deere's registry vs who we think owns that machine in our Equip data. This could surface potential linkages.