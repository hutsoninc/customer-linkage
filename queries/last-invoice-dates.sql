-- Last Complete Goods Invoice Date by Contact Code
SELECT
  vhs.Owner AS ContactCode,
  MAX(CONVERT(DATE, SALESDATE)) AS LastCompleteGoodsInvoiceDate
FROM Equip.VhStock vhs
GROUP BY vhs.Owner


-- Last Parts Invoice Date by Equip Account Number
SELECT
  i.bill_to_acc AS AccountNumber,
  MAX(CONVERT(DATE, invo_datetime)) AS LastPartsInvoiceDate
FROM Equip.Invoice i
WHERE i.invo_type IN ('C', 'I') AND i.module_type = 'I'
GROUP BY i.bill_to_acc


-- Last Service Invoice Date by Equip Account Number
SELECT
  i.bill_to_acc AS AccountNumber
, MAX(CONVERT(DATE, invo_datetime)) AS LastServiceInvoiceDate
FROM Equip.Invoice i
WHERE i.invo_type IN ('C', 'I') AND i.module_type = 'W'
GROUP BY i.bill_to_acc


-- Last Rental Invoice Date by Equip Account Number
SELECT
  i.bill_to_acc AS AccountNumber
, MAX(CONVERT(DATE, invo_datetime)) AS LastRentalInvoiceDate
FROM Equip.Invoice i
LEFT JOIN Equip.Rental_History rh ON i.document_no = rh.Invoice_No
WHERE i.invo_type IN ('C', 'I') AND rh.Invoice_No IS NOT NULL
GROUP BY i.bill_to_acc
