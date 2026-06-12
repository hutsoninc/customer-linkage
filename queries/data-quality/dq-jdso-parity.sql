/* ============================================================
   EQUIP / JDSO (Dataverse) Contact Field Parity Check
   File: queries/data-quality/dq-jdso-parity.sql

   Compares active EQUIP contact fields against their JDSO
   (Dataverse) counterparts before bulk cleanup runs via
   Dataverse. Because JDSO sends a full field payload to EQUIP
   on each update, any existing mismatch gets overwritten with
   JDSO's version. Run this to know what is already out of sync
   before choosing which system to use for each cleanup pass.

   Run on-demand after Dataverse Synapse Link sync completes.

   Three sections — run each separately:
     Section 0: Overall contact counts (sync coverage)
     Section 1: Summary — mismatch counts by field
     Section 2: Detail  — per-contact, per-field mismatches
   ============================================================ */


/* ============================================================
   SECTION 0 — OVERALL SYNC COVERAGE
   Run first. Shows how many active EQUIP contacts have a
   matching Dataverse row vs. no row at all (sync gap).
   ============================================================ */

WITH ar_ap_contacts AS (
    SELECT UPPER(contact_code) AS contact_code
    FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster]
    WHERE contact_code IS NOT NULL
    UNION
    SELECT UPPER(CONTACT_CODE)
    FROM [Bronze_Production_Lakehouse].[Equip].[APMASTER]
    WHERE CONTACT_CODE IS NOT NULL
),
equip_active AS (
    SELECT UPPER(c.contact_code) AS contact_code
    FROM [Bronze_Production_Lakehouse].[Equip].[contact] c
    INNER JOIN ar_ap_contacts acct ON acct.contact_code = UPPER(c.contact_code)
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] m ON m.[Code] = c.contact_code
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] s ON s.[CODE] = c.contact_code
    WHERE ISNULL(c.Inactive_Indicator, 'A') <> 'I'
      AND m.[Code] IS NULL
      AND s.[CODE]  IS NULL
),
jdso_active AS (
    SELECT REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '') AS contact_code
    FROM [Bronze_Production_Lakehouse].[Dataverse].[contact] dc
    INNER JOIN ar_ap_contacts acct
        ON acct.contact_code = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] m
        ON UPPER(m.[Code]) = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] s
        ON UPPER(s.[CODE]) = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Dataverse].[account] ar_acct ON dc.parentcustomerid = ar_acct.[Id]
    LEFT JOIN [Bronze_Production_Lakehouse].[Dataverse].[account] ap_acct ON dc.jd_vendorid      = ap_acct.[Id]
    WHERE (dc.jd_referenceid LIKE 'ARCONTACT-%' OR dc.jd_referenceid LIKE 'APCONTACT-%')
      AND dc.statecode = 0
      AND m.[Code] IS NULL
      AND s.[CODE]  IS NULL
      AND ISNULL(COALESCE(ar_acct.statuscode, ap_acct.statuscode), 0) <> 2
)
SELECT
    COUNT(e.contact_code)                                                                        AS total_active_equip,
    SUM(CASE WHEN e.contact_code IS NOT NULL AND j.contact_code IS NOT NULL THEN 1 ELSE 0 END)  AS matched_in_jdso,
    SUM(CASE WHEN e.contact_code IS NOT NULL AND j.contact_code IS NULL     THEN 1 ELSE 0 END)  AS equip_only_no_jdso_row,
    SUM(CASE WHEN e.contact_code IS NULL     AND j.contact_code IS NOT NULL THEN 1 ELSE 0 END)  AS jdso_only_no_equip_row
FROM equip_active e
FULL OUTER JOIN jdso_active j ON e.contact_code = j.contact_code;


/* ============================================================
   SECTION 0b — SYNC GAP DETAIL
   Contact-code level breakdown of mismatches from Section 0.
   Run after Section 0 to investigate specific contacts.

   mismatch_type values:
     EQUIP_ONLY  — active EQUIP contact with no matching JDSO row
     JDSO_ONLY   — active JDSO contact with no matching EQUIP row
   ============================================================ */

WITH ar_ap_contacts AS (
    SELECT UPPER(contact_code) AS contact_code
    FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster]
    WHERE contact_code IS NOT NULL
    UNION
    SELECT UPPER(CONTACT_CODE)
    FROM [Bronze_Production_Lakehouse].[Equip].[APMASTER]
    WHERE CONTACT_CODE IS NOT NULL
),
equip_active AS (
    SELECT UPPER(c.contact_code) AS contact_code
    FROM [Bronze_Production_Lakehouse].[Equip].[contact] c
    INNER JOIN ar_ap_contacts acct ON acct.contact_code = UPPER(c.contact_code)
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] m ON m.[Code] = c.contact_code
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] s ON s.[CODE] = c.contact_code
    WHERE ISNULL(c.Inactive_Indicator, 'A') <> 'I'
      AND m.[Code] IS NULL
      AND s.[CODE]  IS NULL
),
jdso_active AS (
    SELECT REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '') AS contact_code
    FROM [Bronze_Production_Lakehouse].[Dataverse].[contact] dc
    INNER JOIN ar_ap_contacts acct
        ON acct.contact_code = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] m
        ON UPPER(m.[Code]) = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] s
        ON UPPER(s.[CODE]) = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Dataverse].[account] ar_acct ON dc.parentcustomerid = ar_acct.[Id]
    LEFT JOIN [Bronze_Production_Lakehouse].[Dataverse].[account] ap_acct ON dc.jd_vendorid      = ap_acct.[Id]
    WHERE (dc.jd_referenceid LIKE 'ARCONTACT-%' OR dc.jd_referenceid LIKE 'APCONTACT-%')
      AND dc.statecode = 0
      AND m.[Code] IS NULL
      AND s.[CODE]  IS NULL
      AND ISNULL(COALESCE(ar_acct.statuscode, ap_acct.statuscode), 0) <> 2
)
SELECT
    COALESCE(e.contact_code, j.contact_code)  AS contact_code,
    CASE
        WHEN e.contact_code IS NOT NULL AND j.contact_code IS NULL THEN 'EQUIP_ONLY'
        WHEN e.contact_code IS NULL     AND j.contact_code IS NOT NULL THEN 'JDSO_ONLY'
    END AS mismatch_type
FROM equip_active e
FULL OUTER JOIN jdso_active j ON e.contact_code = j.contact_code
WHERE e.contact_code IS NULL OR j.contact_code IS NULL
ORDER BY mismatch_type, contact_code;


/* ============================================================
   SECTION 1 — SUMMARY BY FIELD
   Mismatch counts per field across all matched contacts.
   Contacts with no JDSO row (sync gap) are excluded from
   field-level counts but are visible in Section 0.

   Columns:
     matched_contacts — contacts with a Dataverse row (same for every field)
     conflict         — both sides populated, values differ  ← highest risk
     equip_ahead      — EQUIP has value, JDSO is null
     jdso_ahead       — JDSO has value, EQUIP is null
     conflict_pct     — conflict / matched_contacts
   ============================================================ */

WITH ar_ap_contacts AS (
    SELECT UPPER(contact_code) AS contact_code
    FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster]
    WHERE contact_code IS NOT NULL
    UNION
    SELECT UPPER(CONTACT_CODE)
    FROM [Bronze_Production_Lakehouse].[Equip].[APMASTER]
    WHERE CONTACT_CODE IS NOT NULL
),

active_contacts AS (
    SELECT
        c.contact_code,
        c.Business_Individual,
        -- Name
        NULLIF(LTRIM(RTRIM(c.[name])),         '') AS eq_firstname,
        NULLIF(LTRIM(RTRIM(c.initial)),        '') AS eq_middlename,
        NULLIF(LTRIM(RTRIM(c.surname)),        '') AS eq_lastname,
        NULLIF(LTRIM(RTRIM(c.Familiar_Name)),  '') AS eq_nickname,
        NULLIF(LTRIM(RTRIM(c.title)),          '') AS eq_salutation,
        NULLIF(LTRIM(RTRIM(c.Suffix)),         '') AS eq_suffix,
        NULLIF(LTRIM(RTRIM(c.Generation)),     '') AS eq_generation,
        NULLIF(LTRIM(RTRIM(c.company_name)),   '') AS eq_company_name,
        -- Contact
        NULLIF(LTRIM(RTRIM(c.email_address)),   '') AS eq_email1,

        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.BusinessPhone,'-',''),'(',''),')',''),' ',''),'.',''))), '') AS eq_phone1,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.PrivatePhone, '-',''),'(',''),')',''),' ',''),'.',''))), '') AS eq_phone2,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.MobilePhone,  '-',''),'(',''),')',''),' ',''),'.',''))), '') AS eq_mobile,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.fax_no,       '-',''),'(',''),')',''),' ',''),'.',''))), '') AS eq_fax,
        NULLIF(LTRIM(RTRIM(CAST(c.Cmp_Ckc_Id AS NVARCHAR(50)))),    '') AS eq_cmp_ckc_id,
        -- Address 1 (physical/delivery)
        NULLIF(LTRIM(RTRIM(c.street)),   '') AS eq_addr1_line1,
        NULLIF(LTRIM(RTRIM(c.street_2)), '') AS eq_addr1_line2,
        NULLIF(LTRIM(RTRIM(c.city)),     '') AS eq_addr1_city,
        NULLIF(LTRIM(RTRIM(c.state)),    '') AS eq_addr1_state,
        NULLIF(LTRIM(RTRIM(c.pcode)),    '') AS eq_addr1_zip,
        NULLIF(LTRIM(RTRIM(c.County)),   '') AS eq_addr1_county,
        NULLIF(LTRIM(RTRIM(c.country)),  '') AS eq_addr1_country,
        -- Address 2 (postal)
        NULLIF(LTRIM(RTRIM(c.postal_street_1)), '') AS eq_addr2_line1,
        NULLIF(LTRIM(RTRIM(c.postal_street_2)), '') AS eq_addr2_line2,
        NULLIF(LTRIM(RTRIM(c.postal_city)),     '') AS eq_addr2_city,
        NULLIF(LTRIM(RTRIM(c.postal_state)),    '') AS eq_addr2_state,
        NULLIF(LTRIM(RTRIM(c.postal_pcode)),    '') AS eq_addr2_zip,
        NULLIF(LTRIM(RTRIM(c.Postal_County)),   '') AS eq_addr2_county,
        NULLIF(LTRIM(RTRIM(c.postal_country)),  '') AS eq_addr2_country
    FROM [Bronze_Production_Lakehouse].[Equip].[contact] c
    INNER JOIN ar_ap_contacts acct ON acct.contact_code = UPPER(c.contact_code)
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] m ON m.[Code] = c.contact_code
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] s ON s.[CODE] = c.contact_code
    WHERE ISNULL(c.Inactive_Indicator, 'A') <> 'I'
      AND m.[Code] IS NULL
      AND s.[CODE]  IS NULL
),

jdso_contacts AS (
    SELECT
        REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '') AS contact_code,
        -- Name
        NULLIF(LTRIM(RTRIM(dc.firstname)),     '') AS dv_firstname,
        NULLIF(LTRIM(RTRIM(dc.middlename)),    '') AS dv_middlename,
        NULLIF(LTRIM(RTRIM(dc.lastname)),      '') AS dv_lastname,
        NULLIF(LTRIM(RTRIM(dc.nickname)),      '') AS dv_nickname,
        NULLIF(LTRIM(RTRIM(dc.salutation)),    '') AS dv_salutation,
        NULLIF(LTRIM(RTRIM(dc.suffix)),        '') AS dv_suffix,
        NULLIF(LTRIM(RTRIM(dc.jd_generation)), '') AS dv_generation,
        NULLIF(LTRIM(RTRIM(dc.company)),       '') AS dv_company_name,
        -- Contact
        NULLIF(LTRIM(RTRIM(dc.emailaddress1)), '') AS dv_email1,

        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(dc.telephone1, '-',''),'(',''),')',''),' ',''),'.',''))), '') AS dv_phone1,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(dc.telephone2, '-',''),'(',''),')',''),' ',''),'.',''))), '') AS dv_phone2,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(dc.mobilephone,'-',''),'(',''),')',''),' ',''),'.',''))), '') AS dv_mobile,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(dc.fax,        '-',''),'(',''),')',''),' ',''),'.',''))), '') AS dv_fax,
        NULLIF(LTRIM(RTRIM(TRY_CAST(dc.jd_compckcid AS NVARCHAR(50)))), '') AS dv_cmp_ckc_id,
        -- Address 1
        NULLIF(LTRIM(RTRIM(dc.address1_line1)),           '') AS dv_addr1_line1,
        NULLIF(LTRIM(RTRIM(dc.address1_line2)),           '') AS dv_addr1_line2,
        NULLIF(LTRIM(RTRIM(dc.address1_city)),            '') AS dv_addr1_city,
        NULLIF(LTRIM(RTRIM(dc.address1_stateorprovince)), '') AS dv_addr1_state,
        NULLIF(LTRIM(RTRIM(dc.address1_postalcode)),      '') AS dv_addr1_zip,
        NULLIF(LTRIM(RTRIM(dc.address1_county)),          '') AS dv_addr1_county,
        NULLIF(LTRIM(RTRIM(dc.address1_country)),         '') AS dv_addr1_country,
        -- Address 2
        NULLIF(LTRIM(RTRIM(dc.address2_line1)),           '') AS dv_addr2_line1,
        NULLIF(LTRIM(RTRIM(dc.address2_line2)),           '') AS dv_addr2_line2,
        NULLIF(LTRIM(RTRIM(dc.address2_city)),            '') AS dv_addr2_city,
        NULLIF(LTRIM(RTRIM(dc.address2_stateorprovince)), '') AS dv_addr2_state,
        NULLIF(LTRIM(RTRIM(dc.address2_postalcode)),      '') AS dv_addr2_zip,
        NULLIF(LTRIM(RTRIM(dc.address2_county)),          '') AS dv_addr2_county,
        NULLIF(LTRIM(RTRIM(dc.address2_country)),         '') AS dv_addr2_country
    FROM [Bronze_Production_Lakehouse].[Dataverse].[contact] dc
    INNER JOIN ar_ap_contacts acct
        ON acct.contact_code = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] m
        ON UPPER(m.[Code]) = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] s
        ON UPPER(s.[CODE]) = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Dataverse].[account] ar_acct ON dc.parentcustomerid = ar_acct.[Id]
    LEFT JOIN [Bronze_Production_Lakehouse].[Dataverse].[account] ap_acct ON dc.jd_vendorid      = ap_acct.[Id]
    WHERE (dc.jd_referenceid LIKE 'ARCONTACT-%' OR dc.jd_referenceid LIKE 'APCONTACT-%')
      AND dc.statecode = 0
      AND m.[Code] IS NULL
      AND s.[CODE]  IS NULL
      AND ISNULL(COALESCE(ar_acct.statuscode, ap_acct.statuscode), 0) <> 2
),

joined AS (
    SELECT
        e.contact_code,
        e.Business_Individual,
        CASE WHEN d.contact_code IS NULL THEN 1 ELSE 0 END AS equip_only,
        e.eq_firstname,     d.dv_firstname,
        e.eq_middlename,    d.dv_middlename,
        e.eq_lastname,      d.dv_lastname,
        e.eq_nickname,      d.dv_nickname,
        e.eq_salutation,    d.dv_salutation,
        e.eq_suffix,        d.dv_suffix,
        e.eq_generation,    d.dv_generation,
        e.eq_company_name,  d.dv_company_name,
        e.eq_email1,        d.dv_email1,

        e.eq_phone1,        d.dv_phone1,
        e.eq_phone2,        d.dv_phone2,
        e.eq_mobile,        d.dv_mobile,
        e.eq_fax,           d.dv_fax,
        e.eq_cmp_ckc_id,    d.dv_cmp_ckc_id,
        e.eq_addr1_line1,   d.dv_addr1_line1,
        e.eq_addr1_line2,   d.dv_addr1_line2,
        e.eq_addr1_city,    d.dv_addr1_city,
        e.eq_addr1_state,   d.dv_addr1_state,
        e.eq_addr1_zip,     d.dv_addr1_zip,
        e.eq_addr1_county,  d.dv_addr1_county,
        e.eq_addr1_country, d.dv_addr1_country,
        e.eq_addr2_line1,   d.dv_addr2_line1,
        e.eq_addr2_line2,   d.dv_addr2_line2,
        e.eq_addr2_city,    d.dv_addr2_city,
        e.eq_addr2_state,   d.dv_addr2_state,
        e.eq_addr2_zip,     d.dv_addr2_zip,
        e.eq_addr2_county,  d.dv_addr2_county,
        e.eq_addr2_country, d.dv_addr2_country
    FROM active_contacts e
    LEFT JOIN jdso_contacts d ON UPPER(e.contact_code) = d.contact_code
),

field_comparisons AS (

    SELECT 'firstname'    AS field_name, equip_only, eq_firstname    AS eq_val, dv_firstname    AS dv_val FROM joined UNION ALL
    SELECT 'middlename',                 equip_only, eq_middlename,              dv_middlename             FROM joined UNION ALL
    SELECT 'lastname',                   equip_only, eq_lastname,                dv_lastname               FROM joined UNION ALL
    SELECT 'nickname',                   equip_only, eq_nickname,                dv_nickname               FROM joined UNION ALL
    SELECT 'salutation',                 equip_only, eq_salutation,              dv_salutation             FROM joined UNION ALL
    SELECT 'suffix',                     equip_only, eq_suffix,                  dv_suffix                 FROM joined UNION ALL
    SELECT 'generation',                 equip_only, eq_generation,              dv_generation             FROM joined UNION ALL
    SELECT 'company_name',               equip_only, eq_company_name,            dv_company_name           FROM joined UNION ALL
    SELECT 'email1',                     equip_only, eq_email1,                  dv_email1                 FROM joined UNION ALL

    SELECT 'phone1',                     equip_only, eq_phone1,                  dv_phone1                 FROM joined UNION ALL
    SELECT 'phone2',                     equip_only, eq_phone2,                  dv_phone2                 FROM joined UNION ALL
    SELECT 'mobile',                     equip_only, eq_mobile,                  dv_mobile                 FROM joined UNION ALL
    SELECT 'fax',                        equip_only, eq_fax,                     dv_fax                    FROM joined UNION ALL
    SELECT 'cmp_ckc_id',                 equip_only, eq_cmp_ckc_id,              dv_cmp_ckc_id             FROM joined UNION ALL
    SELECT 'addr1_line1',                equip_only, eq_addr1_line1,             dv_addr1_line1            FROM joined UNION ALL
    SELECT 'addr1_line2',                equip_only, eq_addr1_line2,             dv_addr1_line2            FROM joined UNION ALL
    SELECT 'addr1_city',                 equip_only, eq_addr1_city,              dv_addr1_city             FROM joined UNION ALL
    SELECT 'addr1_state',                equip_only, eq_addr1_state,             dv_addr1_state            FROM joined UNION ALL
    SELECT 'addr1_zip',                  equip_only, eq_addr1_zip,               dv_addr1_zip              FROM joined UNION ALL
    SELECT 'addr1_county',               equip_only, eq_addr1_county,            dv_addr1_county           FROM joined UNION ALL
    SELECT 'addr1_country',              equip_only, eq_addr1_country,           dv_addr1_country          FROM joined UNION ALL
    SELECT 'addr2_line1',                equip_only, eq_addr2_line1,             dv_addr2_line1            FROM joined UNION ALL
    SELECT 'addr2_line2',                equip_only, eq_addr2_line2,             dv_addr2_line2            FROM joined UNION ALL
    SELECT 'addr2_city',                 equip_only, eq_addr2_city,              dv_addr2_city             FROM joined UNION ALL
    SELECT 'addr2_state',                equip_only, eq_addr2_state,             dv_addr2_state            FROM joined UNION ALL
    SELECT 'addr2_zip',                  equip_only, eq_addr2_zip,               dv_addr2_zip              FROM joined UNION ALL
    SELECT 'addr2_county',               equip_only, eq_addr2_county,            dv_addr2_county           FROM joined UNION ALL
    SELECT 'addr2_country',              equip_only, eq_addr2_country,           dv_addr2_country          FROM joined

)

SELECT
    field_name,
    SUM(CASE WHEN equip_only = 0 THEN 1 ELSE 0 END)  AS matched_contacts,
    SUM(CASE WHEN equip_only = 0
             AND eq_val IS NOT NULL AND dv_val IS NOT NULL
             AND UPPER(eq_val) <> UPPER(dv_val)       THEN 1 ELSE 0 END) AS conflict,
    SUM(CASE WHEN equip_only = 0
             AND eq_val IS NOT NULL AND dv_val IS NULL THEN 1 ELSE 0 END) AS equip_ahead,
    SUM(CASE WHEN equip_only = 0
             AND eq_val IS NULL AND dv_val IS NOT NULL THEN 1 ELSE 0 END) AS jdso_ahead,
    CAST(ROUND(
        100.0
        * SUM(CASE WHEN equip_only = 0 AND eq_val IS NOT NULL AND dv_val IS NOT NULL
                    AND UPPER(eq_val) <> UPPER(dv_val) THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN equip_only = 0 THEN 1 ELSE 0 END), 0),
    1) AS DECIMAL(5,1)) AS conflict_pct
FROM field_comparisons
GROUP BY field_name
ORDER BY conflict DESC, (equip_ahead + jdso_ahead) DESC;


/* ============================================================
   SECTION 2 — DETAIL PER CONTACT
   Per-contact, per-field mismatches only (matches excluded).
   Run separately — can be large. Useful for spot-checking
   specific contacts or exporting the full mismatch list.

   mismatch_type values:
     CONFLICT     — both sides populated, values differ
     EQUIP_AHEAD  — EQUIP has value, JDSO is null
     JDSO_AHEAD   — JDSO has value, EQUIP is null
   ============================================================ */

WITH ar_ap_contacts AS (
    SELECT UPPER(contact_code) AS contact_code
    FROM [Bronze_Production_Lakehouse].[Equip].[ArMaster]
    WHERE contact_code IS NOT NULL
    UNION
    SELECT UPPER(CONTACT_CODE)
    FROM [Bronze_Production_Lakehouse].[Equip].[APMASTER]
    WHERE CONTACT_CODE IS NOT NULL
),

active_contacts AS (
    SELECT
        c.contact_code,
        c.Business_Individual,
        -- Name
        NULLIF(LTRIM(RTRIM(c.[name])),         '') AS eq_firstname,
        NULLIF(LTRIM(RTRIM(c.initial)),        '') AS eq_middlename,
        NULLIF(LTRIM(RTRIM(c.surname)),        '') AS eq_lastname,
        NULLIF(LTRIM(RTRIM(c.Familiar_Name)),  '') AS eq_nickname,
        NULLIF(LTRIM(RTRIM(c.title)),          '') AS eq_salutation,
        NULLIF(LTRIM(RTRIM(c.Suffix)),         '') AS eq_suffix,
        NULLIF(LTRIM(RTRIM(c.Generation)),     '') AS eq_generation,
        NULLIF(LTRIM(RTRIM(c.company_name)),   '') AS eq_company_name,
        -- Contact
        NULLIF(LTRIM(RTRIM(c.email_address)),   '') AS eq_email1,

        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.BusinessPhone,'-',''),'(',''),')',''),' ',''),'.',''))), '') AS eq_phone1,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.PrivatePhone, '-',''),'(',''),')',''),' ',''),'.',''))), '') AS eq_phone2,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.MobilePhone,  '-',''),'(',''),')',''),' ',''),'.',''))), '') AS eq_mobile,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.fax_no,       '-',''),'(',''),')',''),' ',''),'.',''))), '') AS eq_fax,
        NULLIF(LTRIM(RTRIM(CAST(c.Cmp_Ckc_Id AS NVARCHAR(50)))),    '') AS eq_cmp_ckc_id,
        -- Address 1
        NULLIF(LTRIM(RTRIM(c.street)),   '') AS eq_addr1_line1,
        NULLIF(LTRIM(RTRIM(c.street_2)), '') AS eq_addr1_line2,
        NULLIF(LTRIM(RTRIM(c.city)),     '') AS eq_addr1_city,
        NULLIF(LTRIM(RTRIM(c.state)),    '') AS eq_addr1_state,
        NULLIF(LTRIM(RTRIM(c.pcode)),    '') AS eq_addr1_zip,
        NULLIF(LTRIM(RTRIM(c.County)),   '') AS eq_addr1_county,
        NULLIF(LTRIM(RTRIM(c.country)),  '') AS eq_addr1_country,
        -- Address 2
        NULLIF(LTRIM(RTRIM(c.postal_street_1)), '') AS eq_addr2_line1,
        NULLIF(LTRIM(RTRIM(c.postal_street_2)), '') AS eq_addr2_line2,
        NULLIF(LTRIM(RTRIM(c.postal_city)),     '') AS eq_addr2_city,
        NULLIF(LTRIM(RTRIM(c.postal_state)),    '') AS eq_addr2_state,
        NULLIF(LTRIM(RTRIM(c.postal_pcode)),    '') AS eq_addr2_zip,
        NULLIF(LTRIM(RTRIM(c.Postal_County)),   '') AS eq_addr2_county,
        NULLIF(LTRIM(RTRIM(c.postal_country)),  '') AS eq_addr2_country
    FROM [Bronze_Production_Lakehouse].[Equip].[contact] c
    INNER JOIN ar_ap_contacts acct ON acct.contact_code = UPPER(c.contact_code)
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] m ON m.[Code] = c.contact_code
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] s ON s.[CODE] = c.contact_code
    WHERE ISNULL(c.Inactive_Indicator, 'A') <> 'I'
      AND m.[Code] IS NULL
      AND s.[CODE]  IS NULL
),

jdso_contacts AS (
    SELECT
        REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '') AS contact_code,
        -- Name
        NULLIF(LTRIM(RTRIM(dc.firstname)),     '') AS dv_firstname,
        NULLIF(LTRIM(RTRIM(dc.middlename)),    '') AS dv_middlename,
        NULLIF(LTRIM(RTRIM(dc.lastname)),      '') AS dv_lastname,
        NULLIF(LTRIM(RTRIM(dc.nickname)),      '') AS dv_nickname,
        NULLIF(LTRIM(RTRIM(dc.salutation)),    '') AS dv_salutation,
        NULLIF(LTRIM(RTRIM(dc.suffix)),        '') AS dv_suffix,
        NULLIF(LTRIM(RTRIM(dc.jd_generation)), '') AS dv_generation,
        NULLIF(LTRIM(RTRIM(dc.company)),       '') AS dv_company_name,
        -- Contact
        NULLIF(LTRIM(RTRIM(dc.emailaddress1)), '') AS dv_email1,

        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(dc.telephone1, '-',''),'(',''),')',''),' ',''),'.',''))), '') AS dv_phone1,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(dc.telephone2, '-',''),'(',''),')',''),' ',''),'.',''))), '') AS dv_phone2,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(dc.mobilephone,'-',''),'(',''),')',''),' ',''),'.',''))), '') AS dv_mobile,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(dc.fax,        '-',''),'(',''),')',''),' ',''),'.',''))), '') AS dv_fax,
        NULLIF(LTRIM(RTRIM(TRY_CAST(dc.jd_compckcid AS NVARCHAR(50)))), '') AS dv_cmp_ckc_id,
        -- Address 1
        NULLIF(LTRIM(RTRIM(dc.address1_line1)),           '') AS dv_addr1_line1,
        NULLIF(LTRIM(RTRIM(dc.address1_line2)),           '') AS dv_addr1_line2,
        NULLIF(LTRIM(RTRIM(dc.address1_city)),            '') AS dv_addr1_city,
        NULLIF(LTRIM(RTRIM(dc.address1_stateorprovince)), '') AS dv_addr1_state,
        NULLIF(LTRIM(RTRIM(dc.address1_postalcode)),      '') AS dv_addr1_zip,
        NULLIF(LTRIM(RTRIM(dc.address1_county)),          '') AS dv_addr1_county,
        NULLIF(LTRIM(RTRIM(dc.address1_country)),         '') AS dv_addr1_country,
        -- Address 2
        NULLIF(LTRIM(RTRIM(dc.address2_line1)),           '') AS dv_addr2_line1,
        NULLIF(LTRIM(RTRIM(dc.address2_line2)),           '') AS dv_addr2_line2,
        NULLIF(LTRIM(RTRIM(dc.address2_city)),            '') AS dv_addr2_city,
        NULLIF(LTRIM(RTRIM(dc.address2_stateorprovince)), '') AS dv_addr2_state,
        NULLIF(LTRIM(RTRIM(dc.address2_postalcode)),      '') AS dv_addr2_zip,
        NULLIF(LTRIM(RTRIM(dc.address2_county)),          '') AS dv_addr2_county,
        NULLIF(LTRIM(RTRIM(dc.address2_country)),         '') AS dv_addr2_country
    FROM [Bronze_Production_Lakehouse].[Dataverse].[contact] dc
    INNER JOIN ar_ap_contacts acct
        ON acct.contact_code = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[WKMECHFL] m
        ON UPPER(m.[Code]) = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Equip].[VhSalman] s
        ON UPPER(s.[CODE]) = REPLACE(REPLACE(UPPER(dc.jd_referenceid), 'ARCONTACT-', ''), 'APCONTACT-', '')
    LEFT JOIN [Bronze_Production_Lakehouse].[Dataverse].[account] ar_acct ON dc.parentcustomerid = ar_acct.[Id]
    LEFT JOIN [Bronze_Production_Lakehouse].[Dataverse].[account] ap_acct ON dc.jd_vendorid      = ap_acct.[Id]
    WHERE (dc.jd_referenceid LIKE 'ARCONTACT-%' OR dc.jd_referenceid LIKE 'APCONTACT-%')
      AND dc.statecode = 0
      AND m.[Code] IS NULL
      AND s.[CODE]  IS NULL
      AND ISNULL(COALESCE(ar_acct.statuscode, ap_acct.statuscode), 0) <> 2
),

joined AS (
    SELECT
        e.contact_code,
        e.Business_Individual,
        CASE WHEN d.contact_code IS NULL THEN 1 ELSE 0 END AS equip_only,
        e.eq_firstname,     d.dv_firstname,
        e.eq_middlename,    d.dv_middlename,
        e.eq_lastname,      d.dv_lastname,
        e.eq_nickname,      d.dv_nickname,
        e.eq_salutation,    d.dv_salutation,
        e.eq_suffix,        d.dv_suffix,
        e.eq_generation,    d.dv_generation,
        e.eq_company_name,  d.dv_company_name,
        e.eq_email1,        d.dv_email1,

        e.eq_phone1,        d.dv_phone1,
        e.eq_phone2,        d.dv_phone2,
        e.eq_mobile,        d.dv_mobile,
        e.eq_fax,           d.dv_fax,
        e.eq_cmp_ckc_id,    d.dv_cmp_ckc_id,
        e.eq_addr1_line1,   d.dv_addr1_line1,
        e.eq_addr1_line2,   d.dv_addr1_line2,
        e.eq_addr1_city,    d.dv_addr1_city,
        e.eq_addr1_state,   d.dv_addr1_state,
        e.eq_addr1_zip,     d.dv_addr1_zip,
        e.eq_addr1_county,  d.dv_addr1_county,
        e.eq_addr1_country, d.dv_addr1_country,
        e.eq_addr2_line1,   d.dv_addr2_line1,
        e.eq_addr2_line2,   d.dv_addr2_line2,
        e.eq_addr2_city,    d.dv_addr2_city,
        e.eq_addr2_state,   d.dv_addr2_state,
        e.eq_addr2_zip,     d.dv_addr2_zip,
        e.eq_addr2_county,  d.dv_addr2_county,
        e.eq_addr2_country, d.dv_addr2_country
    FROM active_contacts e
    LEFT JOIN jdso_contacts d ON UPPER(e.contact_code) = d.contact_code
),

field_pairs AS (
    SELECT
        j.contact_code,
        j.Business_Individual,
        j.equip_only,
        f.field_name,
        f.eq_val,
        f.dv_val
    FROM joined j
    CROSS APPLY (VALUES
        ('firstname',     j.eq_firstname,     j.dv_firstname),
        ('middlename',    j.eq_middlename,    j.dv_middlename),
        ('lastname',      j.eq_lastname,      j.dv_lastname),
        ('nickname',      j.eq_nickname,      j.dv_nickname),
        ('salutation',    j.eq_salutation,    j.dv_salutation),
        ('suffix',        j.eq_suffix,        j.dv_suffix),
        ('generation',    j.eq_generation,    j.dv_generation),
        ('company_name',  j.eq_company_name,  j.dv_company_name),
        ('email1',        j.eq_email1,        j.dv_email1),

        ('phone1',        j.eq_phone1,        j.dv_phone1),
        ('phone2',        j.eq_phone2,        j.dv_phone2),
        ('mobile',        j.eq_mobile,        j.dv_mobile),
        ('fax',           j.eq_fax,           j.dv_fax),
        ('cmp_ckc_id',    j.eq_cmp_ckc_id,    j.dv_cmp_ckc_id),
        ('addr1_line1',   j.eq_addr1_line1,   j.dv_addr1_line1),
        ('addr1_line2',   j.eq_addr1_line2,   j.dv_addr1_line2),
        ('addr1_city',    j.eq_addr1_city,    j.dv_addr1_city),
        ('addr1_state',   j.eq_addr1_state,   j.dv_addr1_state),
        ('addr1_zip',     j.eq_addr1_zip,     j.dv_addr1_zip),
        ('addr1_county',  j.eq_addr1_county,  j.dv_addr1_county),
        ('addr1_country', j.eq_addr1_country, j.dv_addr1_country),
        ('addr2_line1',   j.eq_addr2_line1,   j.dv_addr2_line1),
        ('addr2_line2',   j.eq_addr2_line2,   j.dv_addr2_line2),
        ('addr2_city',    j.eq_addr2_city,    j.dv_addr2_city),
        ('addr2_state',   j.eq_addr2_state,   j.dv_addr2_state),
        ('addr2_zip',     j.eq_addr2_zip,     j.dv_addr2_zip),
        ('addr2_county',  j.eq_addr2_county,  j.dv_addr2_county),
        ('addr2_country', j.eq_addr2_country, j.dv_addr2_country)
    ) AS f(field_name, eq_val, dv_val)
)

SELECT
    contact_code,
    Business_Individual,
    field_name,
    eq_val  AS equip_value,
    dv_val  AS jdso_value,
    CASE
        WHEN eq_val IS NOT NULL AND dv_val IS NOT NULL
             AND UPPER(eq_val) <> UPPER(dv_val) THEN 'CONFLICT'
        WHEN eq_val IS NOT NULL AND dv_val IS NULL    THEN 'EQUIP_AHEAD'
        WHEN eq_val IS NULL     AND dv_val IS NOT NULL THEN 'JDSO_AHEAD'
    END AS mismatch_type
FROM field_pairs
WHERE equip_only = 0
  AND (
       (eq_val IS NOT NULL AND dv_val IS NOT NULL AND UPPER(eq_val) <> UPPER(dv_val))
    OR (eq_val IS NOT NULL AND dv_val IS NULL)
    OR (eq_val IS NULL     AND dv_val IS NOT NULL)
  )
ORDER BY contact_code, field_name;
