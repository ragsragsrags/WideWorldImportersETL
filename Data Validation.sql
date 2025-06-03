SET NOCOUNT ON

DECLARE @NewCutoff DATETIME = '6/3/2025'

-- Start Cities

IF OBJECT_ID('tempdb..#Cities') IS NOT NULL 
	DROP TABLE #Cities

CREATE TABLE #Cities
(
	CityID INT,
	CityName NVARCHAR(50),
	[Location] NVARCHAR(100),
	LatestRecordedPopulation INT,
	StateProvince NVARCHAR(50),
	Country NVARCHAR(60),
	Continent NVARCHAR(30),
	SalesTerritory NVARCHAR(50),
	Region NVARCHAR(30),
	SubRegion NVARCHAR(30)
)

INSERT INTO #Cities
(
	CityID,
	CityName,
	[Location],
	LatestRecordedPopulation,
	StateProvince,
	Country,
	Continent,
	SalesTerritory,
	Region,
	SubRegion
)
SELECT
	C.CityID,
	C.CityName,
	C.[Location],
	C.LatestRecordedPopulation,
	SP.StateProvinceName,
	CA.CountryName,
	CA.Continent,
	SP.SalesTerritory,
	CA.Region,
	CA.Subregion
FROM
	(
		SELECT
			C.CityID,
			C.CityName,
			[Location] = CAST(C.Location AS NVARCHAR(100)),
			[LatestRecordedPopulation] = ISNULL(C.LatestRecordedPopulation, 0),
			C.StateProvinceID
		FROM
			WideWorldImporters.Application.Cities C
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo 

		UNION

		SELECT
			CA.CityID,
			CA.CityName,
			[Location] = CAST(CA.Location AS NVARCHAR(100)),
			[LatestRecordedPopulation] = ISNULL(CA.LatestRecordedPopulation, 0),
			CA.StateProvinceID
		FROM
			WideWorldImporters.Application.Cities_Archive CA
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo 
	) C LEFT JOIN
	(
		SELECT
			SP.StateProvinceID,
			SP.CountryID,
			SP.StateProvinceName,
			SP.SalesTerritory
		FROM
			WideWorldImporters.Application.StateProvinces SP
		WHERE
			@NewCutoff BETWEEN SP.ValidFrom AND SP.ValidTo 

		UNION

		SELECT
			SPA.StateProvinceID,
			SPA.CountryID,
			SPA.StateProvinceName,
			SPA.SalesTerritory
		FROM
			WideWorldImporters.Application.StateProvinces_Archive SPA
		WHERE
			@NewCutoff BETWEEN SPA.ValidFrom AND SPA.ValidTo
	) SP ON
		SP.StateProvinceID = C.StateProvinceID LEFT JOIN
	(
		SELECT
			C.CountryID,
			C.CountryName,
			C.Continent,
			C.Region,
			C.Subregion
		FROM
			WideWorldImporters.Application.Countries C
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo 

		UNION

		SELECT
			CA.CountryID,
			CA.CountryName,
			CA.Continent,
			CA.Region,
			CA.Subregion
		FROM
			WideWorldImporters.Application.Countries_Archive CA
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) CA ON
		CA.CountryID = SP.CountryID

SELECT
	[City Count] = (SELECT COUNT(*) FROM #Cities),
	[DW City Count] = (SELECT COUNT(*) FROM Dimension.City WHERE [City Key] > 0),
	[City Mismatch Count] = 
		(SELECT COUNT(*) FROM #Cities) - 
		(SELECT COUNT(*) FROM Dimension.City WHERE [City Key] > 0)
	,
	[City Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#Cities C LEFT JOIN
			Dimension.City DWC ON
				DWC.[WWI City ID] = C.CityID AND
				DWC.City LIKE C.CityName AND
				CAST(DWC.Location AS NVARCHAR(100)) = C.Location AND
				DWC.[Latest Recorded Population] = C.LatestRecordedPopulation AND
				DWC.Continent = C.Continent AND
				DWC.Country = C.Country AND
				DWC.Region = C.Region AND
				DWC.Subregion = C.SubRegion AND
				DWC.[Sales Territory] = C.SalesTerritory
		WHERE
			DWC.[WWI City ID] IS NULL
	)

-- End Cities


-- Start Customers

IF OBJECT_ID('tempdb..#Customers') IS NOT NULL 
	DROP TABLE #Customers

CREATE TABLE #Customers 
(
	[WWI Customer ID] [int] NOT NULL,
	[Customer] [nvarchar](100) NOT NULL,
	[Bill To Customer] [nvarchar](100) NOT NULL,
	[Category] [nvarchar](50) NOT NULL,
	[Buying Group] [nvarchar](50) NOT NULL,
	[Primary Contact] [nvarchar](50) NOT NULL,
	[Postal Code] [nvarchar](10) NOT NULL
)

INSERT INTO #Customers
(
	[WWI Customer ID],
	[Customer],
	[Bill To Customer],
	[Category],
	[Buying Group],
	[Primary Contact],
	[Postal Code]
)
SELECT
	C.CustomerID,
	C.CustomerName,
	BC.CustomerName,
	CC.CustomerCategoryName,
	ISNULL(BG.BuyingGroupName, ''),
	PA.FullName,
	C.DeliveryPostalCode
FROM
	(
		SELECT 
			C.CustomerID,
			C.BillToCustomerID,
			C.CustomerCategoryID,
			C.PrimaryContactPersonID,
			C.BuyingGroupID,
			C.CustomerName,
			C.DeliveryPostalCode
		FROM
			WideWorldImporters.Sales.Customers C
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION

		SELECT 
			CA.CustomerID,
			CA.BillToCustomerID,
			CA.CustomerCategoryID,
			CA.PrimaryContactPersonID,
			CA.BuyingGroupID,
			CA.CustomerName,
			CA.DeliveryPostalCode
		FROM
			WideWorldImporters.Sales.Customers_Archive CA
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) C LEFT JOIN
	(
		SELECT 
			C.CustomerID,
			C.CustomerName,
			C.DeliveryPostalCode
		FROM
			WideWorldImporters.Sales.Customers C
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION

		SELECT 
			CA.CustomerID,
			CA.CustomerName,
			CA.DeliveryPostalCode
		FROM
			WideWorldImporters.Sales.Customers_Archive CA
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) BC ON
		BC.CustomerID = C.BillToCustomerID LEFT JOIN
	(
		SELECT
			CC.CustomerCategoryID,
			CC.CustomerCategoryName
		FROM
			WideWorldImporters.sales.CustomerCategories CC 
		WHERE
			@NewCutoff BETWEEN CC.ValidFrom AND CC.ValidTo

		UNION

		SELECT
			CCA.CustomerCategoryID,
			CCA.CustomerCategoryName
		FROM
			WideWorldImporters.sales.CustomerCategories_Archive CCA
		WHERE
			@NewCutoff BETWEEN CCA.ValidFrom AND CCA.ValidTo
	) CC ON
		CC.CustomerCategoryID = C.CustomerCategoryID LEFT JOIN
	(
		SELECT
			P.PersonID,
			P.FullName
		FROM
			WideWorldImporters.Application.People P 
		WHERE
			@NewCutoff BETWEEN P.ValidFrom AND P.ValidTo

		UNION

		SELECT
			PA.PersonID,
			PA.FullName
		FROM
			WideWorldImporters.Application.People_Archive PA
		WHERE
			@NewCutoff BETWEEN PA.ValidFrom AND PA.ValidTo
	) PA ON
		PA.PersonID = C.PrimaryContactPersonID LEFT JOIN
	(
		SELECT
			BG.BuyingGroupID,
			BG.BuyingGroupName
		FROM
			WideWorldImporters.Sales.BuyingGroups BG 
		WHERE
			@NewCutoff BETWEEN BG.ValidFrom AND BG.ValidTo

		UNION

		SELECT
			BGA.BuyingGroupID,
			BGA.BuyingGroupName
		FROM
			WideWorldImporters.Sales.BuyingGroups_Archive BGA
		WHERE
			@NewCutoff BETWEEN BGA.ValidFrom AND BGA.ValidTo
	) BG ON
		BG.BuyingGroupID = C.BuyingGroupID

SELECT
	[Customer Count] = (SELECT COUNT(*) FROM #Customers),
	[DW Customer Count] = (SELECT COUNT(*) FROM Dimension.Customer WHERE [Customer Key] > 0),
	[Customer Mismatch Data] = ABS(
		(SELECT COUNT(*) FROM #Customers) - 
		(SELECT COUNT(*) FROM Dimension.Customer WHERE [Customer Key] > 0)
	),
	[Customer Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#Customers C LEFT JOIN
			Dimension.Customer DWC ON
				DWC.[WWI Customer ID] = C.[WWI Customer ID] AND
				DWC.[Customer] = C.[Customer] AND
				DWC.[Bill To Customer] = C.[Bill To Customer] AND
				DWC.[Category] = C.[Category] AND
				DWC.[Buying Group] = C.[Buying Group] AND
				DWC.[Primary Contact] = C.[Primary Contact] AND
				DWC.[Postal Code] = C.[Postal Code]
		WHERE
			DWC.[WWI Customer ID] IS NULL
	)

-- End Customers


-- Start Employees

IF OBJECT_ID('tempdb..#Employees') IS NOT NULL 
	DROP TABLE #Employees

CREATE TABLE #Employees
(
	[WWI Employee ID] [int] NOT NULL,
	[Employee] [nvarchar](50) NOT NULL,
	[Preferred Name] [nvarchar](50) NOT NULL,
	[Is Salesperson] [bit] NOT NULL,
	[Photo] [varbinary](max) NULL
)

INSERT INTO #Employees
(
	[WWI Employee ID],
	[Employee],
	[Preferred Name],
	[Is Salesperson],
	[Photo]
)
SELECT 
	P.PersonID,
	P.FullName,
	P.PreferredName,
	P.IsSalesperson,
	P.Photo
FROM 
	WideWorldImporters.Application.People P 
WHERE
	P.IsEmployee = 1 AND
	@NewCutoff BETWEEN P.ValidFrom AND P.ValidTo

UNION

SELECT 
	PA.PersonID,
	PA.FullName,
	PA.PreferredName,
	PA.IsSalesperson,
	PA.Photo
FROM 
	WideWorldImporters.Application.People_Archive PA 
WHERE
	PA.IsEmployee = 1 AND
	@NewCutoff BETWEEN PA.ValidFrom AND PA.ValidTo

SELECT
	[Employees Count] = (SELECT COUNT(*) FROM #Employees),
	[DW Employees Count] = (SELECT COUNT(*) FROM Dimension.Employee WHERE [Employee Key] > 0),
	[Employees Mismatch Count] = ABS(
		(SELECT COUNT(*) FROM #Employees) - 
		(SELECT COUNT(*) FROM Dimension.Employee WHERE [Employee Key] > 0)
	),
	[Employees Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#Employees E LEFT JOIN
			Dimension.Employee DWE ON
				DWE.[WWI Employee ID] = E.[WWI Employee ID] AND
				DWE.[Employee] = E.[Employee] AND
				DWE.[Preferred Name] = E.[Preferred Name] AND
				DWE.[Is Salesperson] = E.[Is Salesperson] AND
				(
					DWE.[Photo] = E.[Photo] OR
					(
						DWE.[Photo] IS NULL AND
						E.Photo IS NULL
					)
				)
		WHERE
			DWE.[Employee Key] IS NULL
	)

-- End Employees


-- Start Payment Methods

IF OBJECT_ID('tempdb..#PaymentMethods') IS NOT NULL 
	DROP TABLE #PaymentMethods

CREATE TABLE #PaymentMethods
(
	[WWI Payment Method ID] [int] NOT NULL,
	[Payment Method] [nvarchar](50) NOT NULL
)

INSERT INTO #PaymentMethods
(
	[WWI Payment Method ID],
	[Payment Method]
)
SELECT
	PM.PaymentMethodID,
	PM.PaymentMethodName
FROM
	WideWorldImporters.Application.PaymentMethods PM
WHERE
	@NewCutoff BETWEEN PM.ValidFrom AND PM.ValidTo

UNION

SELECT
	PMA.PaymentMethodID,
	PMA.PaymentMethodName
FROM
	WideWorldImporters.Application.PaymentMethods_Archive PMA
WHERE
	@NewCutoff BETWEEN PMA.ValidFrom AND PMA.ValidTo

SELECT
	[Payment Methods Count] = (SELECT COUNT(*) FROM #PaymentMethods),
	[DW Payment Methods Count] = (SELECT COUNT(*) FROM Dimension.[Payment Method] WHERE [Payment Method Key] > 0),
	[Payment Methods Mismatch Count] = ABS(
		(SELECT COUNT(*) FROM #PaymentMethods) - 
		(SELECT COUNT(*) FROM Dimension.[Payment Method] WHERE [Payment Method Key] > 0)
	),
	[Payment Methods Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#PaymentMethods PM LEFT JOIN
			Dimension.[Payment Method] DWPM ON
				DWPM.[WWI Payment Method ID] = PM.[WWI Payment Method ID] AND
				DWPM.[Payment Method] = PM.[Payment Method] 
		WHERE
			DWPM.[Payment Method Key] IS NULL
	)

-- End Payment Methods


-- Start Stock Items

IF OBJECT_ID('tempdb..#StockItems') IS NOT NULL 
	DROP TABLE #StockItems

CREATE TABLE #StockItems
(
	[WWI Stock Item ID] [int] NOT NULL,
	[Stock Item] [nvarchar](100) NOT NULL,
	[Color] [nvarchar](20) NOT NULL,
	[Selling Package] [nvarchar](50) NOT NULL,
	[Buying Package] [nvarchar](50) NOT NULL,
	[Brand] [nvarchar](50) NOT NULL,
	[Size] [nvarchar](20) NOT NULL,
	[Lead Time Days] [int] NOT NULL,
	[Quantity Per Outer] [int] NOT NULL,
	[Is Chiller Stock] [bit] NOT NULL,
	[Barcode] [nvarchar](50) NULL,
	[Tax Rate] [decimal](18, 3) NOT NULL,
	[Unit Price] [decimal](18, 2) NOT NULL,
	[Recommended Retail Price] [decimal](18, 2) NULL,
	[Typical Weight Per Unit] [decimal](18, 3) NOT NULL,
	[Photo] [varbinary](max) NULL
)

INSERT INTO #StockItems
(
	[WWI Stock Item ID],
	[Stock Item],
	[Color],
	[Selling Package],
	[Buying Package],
	[Brand],
	[Size],
	[Lead Time Days],
	[Quantity Per Outer],
	[Is Chiller Stock],
	[Barcode],
	[Tax Rate],
	[Unit Price],
	[Recommended Retail Price],
	[Typical Weight Per Unit],
	[Photo]
)

SELECT
	SI.[WWI Stock Item ID],
	SI.[Stock Item],
	ISNULL(C.ColorName, ''),
	SP.PackageTypeName,
	ISNULL(BP.PackageTypeName, ''),
	ISNULL(SI.Brand, ''),
	ISNULL(SI.Size, ''),
	SI.[Lead Time Days],
	SI.[Quantity Per Outer],
	SI.[Is Chiller Stock],
	SI.Barcode,
	SI.[Tax Rate],
	SI.[Unit Price],
	SI.[Recommended Retail Price],
	SI.[Typical Weight Per Unit],
	SI.Photo
FROM
	(
		SELECT
			[WWI Stock Item ID] = SI.StockItemID,
			[Stock Item] = SI.StockItemName,
			SI.ColorID,
			SI.OuterPackageID,
			SI.UnitPackageID,
			[Brand] = SI.Brand,
			[Size] = SI.Size,
			[Lead Time Days] = SI.LeadTimeDays,
			[Quantity Per Outer] = SI.QuantityPerOuter,
			[Is Chiller Stock] = SI.IsChillerStock,
			[Barcode] = SI.Barcode,
			[Tax Rate] = SI.TaxRate,
			[Unit Price] = SI.UnitPrice,
			[Recommended Retail Price] = SI.RecommendedRetailPrice,
			[Typical Weight Per Unit] = SI.TypicalWeightPerUnit,
			[Photo] = SI.Photo
		FROM
			WideWorldImporters.Warehouse.StockItems SI
		WHERE
			@NewCutoff BETWEEN SI.ValidFrom AND SI.ValidTo

		UNION

		SELECT
			[WWI Stock Item ID] = SIA.StockItemID,
			[Stock Item] = SIA.StockItemName,
			SIA.ColorID,
			SIA.OuterPackageID,
			SIA.UnitPackageID,
			[Brand] = SIA.Brand,
			[Size] = SIA.Size,
			[Lead Time Days] = SIA.LeadTimeDays,
			[Quantity Per Outer] = SIA.QuantityPerOuter,
			[Is Chiller Stock] = SIA.IsChillerStock,
			[Barcode] = SIA.Barcode,
			[Tax Rate] = SIA.TaxRate,
			[Unit Price] = SIA.UnitPrice,
			[Recommended Retail Price] = SIA.RecommendedRetailPrice,
			[Typical Weight Per Unit] = SIA.TypicalWeightPerUnit,
			[Photo] = SIA.Photo
		FROM
			WideWorldImporters.Warehouse.StockItems_Archive SIA
		WHERE
			@NewCutoff BETWEEN SIA.ValidFrom AND SIA.ValidTo
	) SI LEFT JOIN
	(
		SELECT
			C.ColorID,
			C.ColorName
		FROM
			WideWorldImporters.Warehouse.Colors C 
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION

		SELECT
			CA.ColorID,
			CA.ColorName
		FROM
			WideWorldImporters.Warehouse.Colors_Archive CA 
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) C ON
		C.ColorID = SI.ColorID LEFT JOIN
	(
		SELECT
			PT.PackageTypeID,
			PT.PackageTypeName
		FROM
			WideWorldImporters.Warehouse.PackageTypes PT 
		WHERE
			@NewCutoff BETWEEN PT.ValidFrom AND PT.ValidTo

		UNION

		SELECT
			PTA.PackageTypeID,
			PTA.PackageTypeName
		FROM
			WideWorldImporters.Warehouse.PackageTypes_Archive PTA 
		WHERE
			@NewCutoff BETWEEN PTA.ValidFrom AND PTA.ValidTo
	) SP ON
		SP.PackageTypeID = SI.UnitPackageID LEFT JOIN
	(
		SELECT
			PT.PackageTypeID,
			PT.PackageTypeName
		FROM
			WideWorldImporters.Warehouse.PackageTypes PT 
		WHERE
			@NewCutoff BETWEEN PT.ValidFrom AND PT.ValidTo

		UNION

		SELECT
			PTA.PackageTypeID,
			PTA.PackageTypeName
		FROM
			WideWorldImporters.Warehouse.PackageTypes_Archive PTA 
		WHERE
			@NewCutoff BETWEEN PTA.ValidFrom AND PTA.ValidTo
	) BP ON
		BP.PackageTypeID = SI.OuterPackageID

SELECT
	[Stock Items Count] = (SELECT COUNT(*) FROM #StockItems),
	[DW Stock Items Count] = (SELECT COUNT(*) FROM Dimension.[Stock Item] WHERE [Stock Item Key] > 0),
	[Stock Items Mismatch Count] = ABS(
		(SELECT COUNT(*) FROM #StockItems) - 
		(SELECT COUNT(*) FROM Dimension.[Stock Item] WHERE [Stock Item Key] > 0)
	),
	[Stock Items Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#StockItems SI LEFT JOIN
			Dimension.[Stock Item] DWSI ON
				DWSI.[WWI Stock Item ID] = SI.[WWI Stock Item ID] AND
				DWSI.[Stock Item] = SI.[Stock Item] AND
				DWSI.[Color] = SI.[Color] AND
				DWSI.[Selling Package] = SI.[Selling Package] AND
				DWSI.[Buying Package] = SI.[Buying Package] AND
				DWSI.[Brand] = SI.[Brand] AND
				DWSI.[Size] = SI.[Size] AND
				DWSI.[Lead Time Days] = SI.[Lead Time Days] AND
				DWSI.[Quantity Per Outer] = SI.[Quantity Per Outer] AND
				DWSI.[Is Chiller Stock] = SI.[Is Chiller Stock] AND
				ISNULL(DWSI.[Barcode], '') = ISNULL(SI.[Barcode], '') AND
				--DWSI.[Tax Rate] = SI.[Tax Rate] AND
				DWSI.[Unit Price] = SI.[Unit Price] AND
				DWSI.[Recommended Retail Price] = SI.[Recommended Retail Price] AND
				DWSI.[Typical Weight Per Unit] = SI.[Typical Weight Per Unit] AND
				(
					DWSI.[Photo] = SI.[Photo] OR
					(
						DWSI.[Photo] IS NULL AND
						SI.[Photo] IS NULL
					)
				)
		WHERE
			DWSI.[WWI Stock Item ID] IS NULL
	)

-- End Stock Items


-- Start Suppliers

IF OBJECT_ID('tempdb..#Suppliers') IS NOT NULL 
	DROP TABLE #Suppliers

CREATE TABLE #Suppliers 
(
	[WWI Supplier ID] [int] NOT NULL,
	[Supplier] [nvarchar](100) NOT NULL,
	[Category] [nvarchar](50) NOT NULL,
	[Primary Contact] [nvarchar](50) NOT NULL,
	[Supplier Reference] [nvarchar](20) NULL,
	[Payment Days] [int] NOT NULL,
	[Postal Code] [nvarchar](10) NOT NULL
)	

INSERT INTO #Suppliers
(
	[WWI Supplier ID],
	[Supplier],
	[Category],
	[Primary Contact],
	[Supplier Reference],
	[Payment Days],
	[Postal Code]
)
SELECT
	S.SupplierID,
	S.SupplierName,
	SC.SupplierCategoryName,
	P.FullName,
	S.SupplierReference,
	S.PaymentDays,
	S.DeliveryPostalCode
FROM
	(
		SELECT 
			S.SupplierID,
			S.SupplierCategoryID,
			S.PrimaryContactPersonID,
			S.SupplierName,
			S.SupplierReference,
			S.PaymentDays,
			S.DeliveryPostalCode
		FROM 
			WideWorldImporters.Purchasing.Suppliers S
		WHERE
			@NewCutoff BETWEEN S.ValidFrom AND S.ValidTo

		UNION

		SELECT
			SA.SupplierID,
			SA.SupplierCategoryID,
			SA.PrimaryContactPersonID,
			SA.SupplierName,
			SA.SupplierReference,
			SA.PaymentDays,
			SA.DeliveryPostalCode
		FROM
			WideWorldImporters.Purchasing.Suppliers_Archive SA
		WHERE
			@NewCutoff BETWEEN SA.ValidFrom AND SA.ValidTo
	) S LEFT JOIN
	(
		SELECT 
			SC.SupplierCategoryID,
			SC.SupplierCategoryName
		FROM
			WideWorldImporters.Purchasing.SupplierCategories SC 
		WHERE
			@NewCutoff BETWEEN SC.ValidFrom AND SC.ValidTo

		UNION

		SELECT
			SCA.SupplierCategoryID,
			SCA.SupplierCategoryName
		FROM
			WideWorldImporters.Purchasing.SupplierCategories_Archive SCA
		WHERE
			@NewCutoff BETWEEN SCA.ValidFrom AND SCA.ValidTo
	) SC ON
		SC.SupplierCategoryID = S.SupplierCategoryID LEFT JOIN
	(
		SELECT
			P.PersonID,
			P.FullName
		FROM
			WideWorldImporters.Application.People P
		WHERE
			@NewCutoff BETWEEN P.ValidFrom AND P.ValidTo

		UNION

		SELECT
			PA.PersonID,
			PA.FullName
		FROM
			WideWorldImporters.Application.People_Archive PA
		WHERE
			@NewCutoff BETWEEN PA.ValidFrom AND PA.ValidTo
	) P ON
		P.PersonID = S.PrimaryContactPersonID

SELECT
	[Suppliers Count] = (SELECT COUNT(*) FROM #Suppliers),
	[DW Suppliers Count] = (SELECT COUNT(*) FROM Dimension.Supplier WHERE [Supplier Key] > 0),
	[Suppliers Mismatch Count] = ABS(
		(SELECT COUNT(*) FROM #Suppliers) - 
		(SELECT COUNT(*) FROM Dimension.Supplier WHERE [Supplier Key] > 0)
	),
	[Suppliers Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#Suppliers S LEFT JOIN
			Dimension.Supplier DWS ON
				DWS.[WWI Supplier ID] = S.[WWI Supplier ID] AND
				DWS.[Supplier] = S.[Supplier] AND
				DWS.[Category] = S.[Category] AND
				DWS.[Primary Contact] = S.[Primary Contact] AND
				DWS.[Supplier Reference] = S.[Supplier Reference] AND
				DWS.[Payment Days] = S.[Payment Days] AND
				DWS.[Postal Code] = S.[Postal Code]
		WHERE
			DWS.[Supplier Key] IS NULL
	)

-- End Suppliers


-- Start Transaction Types

IF OBJECT_ID('tempdb..#TransactionTypes') IS NOT NULL 
	DROP TABLE #TransactionTypes

CREATE TABLE #TransactionTypes
(
	[WWI Transaction Type ID] [int] NOT NULL,
	[Transaction Type] [nvarchar](50) NOT NULL
)

INSERT INTO #TransactionTypes
(
	[WWI Transaction Type ID],
	[Transaction Type]
)
SELECT
	TT.[TransactionTypeID],
	TT.TransactionTypeName
FROM
	WideWorldImporters.Application.TransactionTypes TT
WHERE
	@NewCutoff BETWEEN TT.ValidFrom AND TT.ValidTo

UNION 

SELECT
	TTA.[TransactionTypeID],
	TTA.TransactionTypeName
FROM
	WideWorldImporters.Application.TransactionTypes_Archive TTA
WHERE
	@NewCutoff BETWEEN TTA.ValidFrom AND TTA.ValidTo

SELECT
	[Transaction Types Count] = (SELECT COUNT(*) FROM #TransactionTypes),
	[DW Transaction Types Count] = (SELECT COUNT(*) FROM Dimension.[Transaction Type] WHERE [Transaction Type Key] > 0),
	[Transaction Types Mismatch Count] = ABS(
		(SELECT COUNT(*) FROM #TransactionTypes) - 
		(SELECT COUNT(*) FROM Dimension.[Transaction Type] WHERE [Transaction Type Key] > 0)
	),
	[Transaction Types Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#TransactionTypes TT LEFT JOIN
			Dimension.[Transaction Type] DWTT ON
				DWTT.[WWI Transaction Type ID] = TT.[WWI Transaction Type ID] AND
				DWTT.[Transaction Type] = TT.[Transaction Type]
		WHERE
			DWTT.[Transaction Type Key] IS NULL
	)

-- End Transaction Types


-- Start Movement

IF OBJECT_ID('tempdb..#Movements') IS NOT NULL 
	DROP TABLE #Movements

CREATE TABLE #Movements 
(
	[Date Key] [date] NOT NULL,
	[Stock Item] [nvarchar](100) NOT NULL,
	[Customer] [nvarchar](100) NULL,
	[Supplier] [nvarchar](100) NULL,
	[Transaction Type] [nvarchar](100) NOT NULL,
	[WWI Stock Item Transaction ID] [int] NOT NULL,
	[WWI Invoice ID] [int] NULL,
	[WWI Purchase Order ID] [int] NULL,
	[Quantity] [int] NOT NULL
)

INSERT INTO #Movements
(
	[Date Key],
	[Stock Item],
	[Customer],
	[Supplier],
	[Transaction Type],
	[WWI Stock Item Transaction ID],
	[WWI Invoice ID],
	[WWI Purchase Order ID],
	[Quantity]
)
SELECT
	SIT.TransactionOccurredWhen,
	SI.StockItemName,
	C.CustomerName,
	S.SupplierName,
	TT.TransactionTypeName,
	SIT.StockItemTransactionID,
	SIT.InvoiceID,
	SIT.PurchaseOrderID,
	SIT.Quantity
FROM
	WideWorldImporters.Warehouse.StockItemTransactions SIT LEFT JOIN
	(
		SELECT
			SI.StockItemID,
			SI.StockItemName
		FROM
			WideWorldImporters.Warehouse.StockItems SI 
		WHERE
			@NewCutoff BETWEEN Si.ValidFrom AND SI.ValidTo

		UNION

		SELECT
			SIA.StockItemID,
			SIA.StockItemName
		FROM
			WideWorldImporters.Warehouse.StockItems_Archive SIA
		WHERE
			@NewCutoff BETWEEN SIA.ValidFrom AND SIA.ValidTo
	) SI ON
		SI.StockItemID = SIT.StockItemID LEFT JOIN
	(
		SELECT
			C.CustomerID,
			C.CustomerName
		FROM
			WideWorldImporters.Sales.Customers C 
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION

		SELECT
			CA.CustomerID,
			CA.CustomerName
		FROM
			WideWorldImporters.Sales.Customers_Archive CA
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) C ON 
		C.CustomerID = SIT.CustomerID LEFT JOIN
	(
		SELECT
			S.SupplierID,
			S.SupplierName
		FROM
			WideWorldImporters.Purchasing.Suppliers S 
		WHERE
			@NewCutoff BETWEEN S.ValidFrom AND S.ValidTo

		UNION

		SELECT
			SA.SupplierID,
			SA.SupplierName
		FROM
			WideWorldImporters.Purchasing.Suppliers_Archive SA
		WHERE
			@NewCutoff BETWEEN SA.ValidFrom AND SA.ValidTo
	) S ON 
		S.SupplierID = SIT.SupplierID LEFT JOIN
	(
		SELECT
			TT.TransactionTypeID,
			TT.TransactionTypeName
		FROM
			WideWorldImporters.Application.TransactionTypes TT 
		WHERE
			@NewCutoff BETWEEN TT.ValidFrom AND TT.ValidTo

		UNION

		SELECT
			TTA.TransactionTypeID,
			TTA.TransactionTypeName
		FROM
			WideWorldImporters.Application.TransactionTypes_Archive TTA
		WHERE
			@NewCutoff BETWEEN TTA.ValidFrom AND TTA.ValidTo
	) TT ON 
		TT.TransactionTypeID = SIT.TransactionTypeID
WHERE
	SIT.LastEditedWhen <= @NewCutoff

SELECT
	[Movements Count] = (SELECT COUNT(*) FROM #Movements),
	[DW Movements Count] = (SELECT COUNT(*) FROM Fact.Movement WHERE [Movement Key] > 0),
	[Movements Mismatch Count] = (
		(SELECT COUNT(*) FROM #Movements) - 
		(SELECT COUNT(*) FROM Fact.Movement WHERE [Movement Key] > 0)
	),
	[Movements Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#Movements M LEFT JOIN
			Fact.Movement DWM ON
				DWM.[WWI Stock Item Transaction ID] = M.[WWI Stock Item Transaction ID] 
				AND
				DWM.[Date Key] = M.[Date Key] AND
				DWM.[Quantity] = M.[Quantity] AND
				ISNULL(DWM.[WWI Invoice ID], 0) = ISNULL(M.[WWI Invoice ID], 0) AND
				ISNULL(DWM.[WWI Purchase Order ID], 0) = ISNULL(M.[WWI Purchase Order ID], 0) LEFT JOIN
			Dimension.[Stock Item] SI ON
				SI.[Stock Item Key] = DWM.[Stock Item Key] AND
				SI.[Stock Item] = ISNULL(M.[Stock Item], 'Unknown') LEFT JOIN
			Dimension.[Customer] C ON
				C.[Customer Key] = DWM.[Customer Key] AND
				C.Customer = ISNULL(M.[Customer], 'Unknown') LEFT JOIN
			Dimension.Supplier S ON
				S.[Supplier Key] = DWM.[Supplier Key] AND
				S.Supplier = ISNULL(M.Supplier, 'Unknown') LEFT JOIN
			Dimension.[Transaction Type] TT ON
				TT.[Transaction Type Key] = DWM.[Transaction Type Key] AND
				TT.[Transaction Type] = ISNULL(M.[Transaction Type], 'Unknown')
		WHERE
			DWM.[Movement Key] IS NULL OR
			SI.[Stock Item] IS NULL OR
			C.[Customer Key]  IS NULL OR
			S.[Supplier Key] IS NULL OR
			TT.[Transaction Type Key] IS NULL
	)

-- End Movements


-- Start Orders

IF OBJECT_ID('tempdb..#Orders') IS NOT NULL 
	DROP TABLE #Orders

CREATE TABLE #Orders 
(
	[City] NVARCHAR(100) NOT NULL,
	[Customer] NVARCHAR(100) NOT NULL,
	[Stock Item] NVARCHAR(100) NOT NULL,
	[Order Date Key] [date] NOT NULL,
	[Picked Date Key] [date] NULL,
	[Salesperson] NVARCHAR(100) NOT NULL,
	[Picker] NVARCHAR(100) NULL,
	[WWI Order ID] [int] NOT NULL,
	[WWI Backorder ID] [int] NULL,
	[Description] [nvarchar](100) NOT NULL,
	[Package] [nvarchar](50) NOT NULL,
	[Quantity] [int] NOT NULL,
	[Unit Price] [decimal](18, 2) NOT NULL,
	[Tax Rate] [decimal](18, 3) NOT NULL,
	[Total Excluding Tax] [decimal](18, 2) NOT NULL,
	[Tax Amount] [decimal](18, 2) NOT NULL,
	[Total Including Tax] [decimal](18, 2) NOT NULL
)

INSERT INTO #Orders
(
	[City],
	[Customer],
	[Stock Item],
	[Order Date Key],
	[Picked Date Key],
	[Salesperson],
	[Picker],
	[WWI Order ID],
	[WWI Backorder ID],
	[Description],
	[Package],
	[Quantity],
	[Unit Price],
	[Tax Rate],
	[Total Excluding Tax],
	[Tax Amount],
	[Total Including Tax]
)
SELECT
	CI.CityName,
	C.CustomerName,
	SI.StockItemName,
	O.OrderDate,
	O.PickingCompletedWhen,
	P.FullName,
	P2.FullName,
	O.OrderID,
	O.BackorderOrderID,
	OL.Description,
	PT.PackageTypeName,
	OL.Quantity,
	OL.UnitPrice,
	OL.TaxRate,
	ROUND(OL.Quantity * OL.UnitPrice, 2),
	ROUND(OL.Quantity * OL.UnitPrice * ol.TaxRate / 100.0, 2),
	ROUND(OL.Quantity * OL.UnitPrice, 2) + ROUND(OL.Quantity * ol.UnitPrice * OL.TaxRate / 100.0, 2)
FROM
	WideWorldImporters.Sales.Orders O LEFT JOIN
	WideWorldImporters.Sales.OrderLines OL ON
		OL.OrderID = O.OrderID LEFT JOIN 
	(
		SELECT
			C.CustomerID,
			C.DeliveryCityID,
			C.CustomerName
		FROM
			WideWorldImporters.Sales.Customers C
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION

		SELECT
			CA.CustomerID,
			CA.DeliveryCityID,
			CA.CustomerName
		FROM
			WideWorldImporters.Sales.Customers_Archive CA
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) C ON
		C.CustomerID = O.CustomerID LEFT JOIN
	(
		SELECT
			C.CityID,
			C.CityName
		FROM
			WideWorldImporters.Application.Cities C
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION

		SELECT
			CA.CityID,
			CA.CityName
		FROM
			WideWorldImporters.Application.Cities_Archive CA
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) CI ON
		CI.CityID = C.DeliveryCityID LEFT JOIN
	(
		SELECT
			SI.StockItemID,
			SI.StockItemName
		FROM
			WideWorldImporters.Warehouse.StockItems SI 
		WHERE
			@NewCutoff BETWEEN SI.ValidFrom AND SI.ValidTo

		UNION

		SELECT
			SIA.StockItemID,
			SIA.StockItemName
		FROM
			WideWorldImporters.Warehouse.StockItems_Archive SIA 
		WHERE
			@NewCutoff BETWEEN SIA.ValidFrom AND SIA.ValidTo
	) SI ON
		SI.StockItemID = OL.StockItemID LEFT JOIN
	(
		SELECT
			P.PersonID,
			P.FullName
		FROM
			WideWorldImporters.Application.People P 
		WHERE
			@NewCutoff BETWEEN P.ValidFrom AND P.ValidTo

		UNION

		SELECT
			PA.PersonID,
			PA.FullName
		FROM
			WideWorldImporters.Application.People_Archive PA 
		WHERE
			@NewCutoff BETWEEN PA.ValidFrom AND PA.ValidTo
	) P ON
		P.PersonID = O.SalespersonPersonID LEFT JOIN
	(
		SELECT
			P.PersonID,
			P.FullName
		FROM
			WideWorldImporters.Application.People P 
		WHERE
			@NewCutoff BETWEEN P.ValidFrom AND P.ValidTo

		UNION

		SELECT
			PA.PersonID,
			PA.FullName
		FROM
			WideWorldImporters.Application.People_Archive PA 
		WHERE
			@NewCutoff BETWEEN PA.ValidFrom AND PA.ValidTo
	) P2 ON
		P2.PersonID = O.PickedByPersonID LEFT JOIN
	(
		SELECT
			PT.PackageTypeID,
			PT.PackageTypeName
		FROM
			WideWorldImporters.Warehouse.PackageTypes PT 
		WHERE
			@NewCutoff BETWEEN PT.ValidFrom AND PT.ValidTo

		UNION

		SELECT
			PTA.PackageTypeID,
			PTA.PackageTypeName
		FROM
			WideWorldImporters.Warehouse.PackageTypes_Archive PTA 
		WHERE
			@NewCutoff BETWEEN PTA.ValidFrom AND PTA.ValidTo
	) PT ON
		PT.PackageTypeID = OL.PackageTypeID
WHERE
	O.LastEditedWhen <= @NewCutoff OR
	OL.LastEditedWhen <= @NewCutoff

SELECT
	[Orders Count] = (SELECT COUNT(*) FROM #Orders),
	[DW Orders Count] = (SELECT COUNT(*) FROM Fact.[Order] WHERE [Order Key] > 0),
	[Orders Mismatch Count] = ABS(
		(SELECT COUNT(*) FROM #Orders) - 
		(SELECT COUNT(*) FROM Fact.[Order] WHERE [Order Key] > 0)
	),
	[Orders Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#Orders O LEFT JOIN
			Fact.[Order] DWO ON
				DWO.[Order Date Key] = O.[Order Date Key] AND
				(
					DWO.[Picked Date Key] = O.[Picked Date Key] OR
					(
						DWO.[Picked Date Key] IS NULL AND
						O.[Picked Date Key] IS NULL
					)
				) AND
				DWO.[WWI Order ID] = O.[WWI Order ID] AND
				ISNULL(DWO.[WWI Backorder ID], 0) = ISNULL(O.[WWI Backorder ID], 0) AND
				DWO.[Description] = O.Description AND
				DWO.Package = O.Package AND
				DWO.[Quantity] = O.Quantity AND
				DWO.[Unit Price] = O.[Unit Price] AND
				DWO.[Tax Rate] = O.[Tax Rate] AND
				DWO.[Total Excluding Tax] = O.[Total Excluding Tax] AND
				DWO.[Tax Amount] = O.[Tax Amount] AND
				DWO.[Total Including Tax] = O.[Total Including Tax] 
				LEFT JOIN
			Dimension.City C ON
				C.[City Key] = DWO.[City Key] AND
				C.[City] = O.City LEFT JOIN
			Dimension.Customer CU ON
				CU.[Customer Key] = DWO.[Customer Key] AND
				CU.[Customer] = O.Customer LEFT JOIN
			Dimension.[Stock Item] SI ON
				SI.[Stock Item Key] = DWO.[Stock Item Key] AND
				SI.[Stock Item] = O.[Stock Item] LEFT JOIN
			Dimension.Employee E ON
				E.[Employee Key] = DWO.[Salesperson Key] AND
				E.[Employee] = O.Salesperson LEFT JOIN
			Dimension.Employee E2 ON
				E2.[Employee Key] = DWO.[Picker Key] AND 
				E2.[Employee] = ISNULL(O.Picker, 'Unknown')
		WHERE
			DWO.[Order Key] IS NULL OR
			C.[City Key] IS NULL OR
			CU.[Customer Key]  IS NULL OR
			SI.[Stock Item Key] IS NULL OR
			E.[Employee Key] IS NULL OR
			E2.[Employee Key] IS NULL
	)

-- End Orders


-- Start Purchases

IF OBJECT_ID('tempdb..#Purchases') IS NOT NULL 
	DROP TABLE #Purchases

CREATE TABLE #Purchases
(
	[Date Key] [date] NOT NULL,
	[Supplier] NVARCHAR(100) NOT NULL,
	[Stock Item] NVARCHAR(100) NOT NULL,
	[WWI Purchase Order ID] [int] NULL,
	[Ordered Outers] [int] NOT NULL,
	[Ordered Quantity] [int] NOT NULL,
	[Received Outers] [int] NOT NULL,
	[Package] [nvarchar](50) NOT NULL,
	[Is Order Finalized] [bit] NOT NULL,
	[WWI Stock Item ID] [int] NULL
)

INSERT INTO #Purchases
(
	[Date Key],
	[Supplier],
	[Stock Item],
	[WWI Purchase Order ID],
	[Ordered Outers],
	[Ordered Quantity],
	[Received Outers],
	[Package],
	[Is Order Finalized],
	[WWI Stock Item ID]
)
SELECT
	PO.OrderDate,
	S.SupplierName,
	SI.StockItemName,
	PO.PurchaseOrderID,
	POL.OrderedOuters,
	POL.OrderedOuters * SI.QuantityPerOuter,
	POL.ReceivedOuters,
	PT.PackageTypeName,
	PO.IsOrderFinalized,
	pol.StockItemID
FROM
	WideWorldImporters.Purchasing.PurchaseOrders PO LEFT JOIN
	WideWorldImporters.Purchasing.PurchaseOrderLines POL ON
		POL.PurchaseOrderID = PO.PurchaseOrderID LEFT JOIN
	(
		SELECT 
			S.SupplierID,
			S.SupplierName
		FROM
			WideWorldImporters.Purchasing.Suppliers S
		WHERE
			@NewCutoff BETWEEN S.ValidFrom AND S.ValidTo

		UNION

		SELECT 
			SA.SupplierID,
			SA.SupplierName
		FROM
			WideWorldImporters.Purchasing.Suppliers_Archive SA
		WHERE
			@NewCutoff BETWEEN SA.ValidFrom AND SA.ValidTo
	) S ON
		S.SupplierID = PO.SupplierID LEFT JOIN
	(
		SELECT
			SI.StockItemID,
			SI.StockItemName,
			SI.QuantityPerOuter
		FROM
			WideWorldImporters.Warehouse.StockItems SI 
		WHERE
			@NewCutoff BETWEEN SI.ValidFrom AND SI.ValidTo

		UNION

		SELECT
			SIA.StockItemID,
			SIA.StockItemName,
			SIA.QuantityPerOuter
		FROM
			WideWorldImporters.Warehouse.StockItems_Archive SIA
		WHERE
			@NewCutoff BETWEEN SIA.ValidFrom AND SIA.ValidTo
	) SI ON
		SI.StockItemID = POL.StockItemID LEFT JOIN
	(
		SELECT
			PT.PackageTypeID,
			PT.PackageTypeName
		FROM
			WideWorldImporters.Warehouse.PackageTypes PT
		WHERE
			@NewCutoff BETWEEN PT.ValidFrom AND PT.ValidTo

		UNION

		SELECT
			PTA.PackageTypeID,
			PTA.PackageTypeName
		FROM
			WideWorldImporters.Warehouse.PackageTypes_Archive PTA
		WHERE
			@NewCutoff BETWEEN PTA.ValidFrom AND PTA.ValidTo
	) PT ON
		PT.PackageTypeID = POL.PackageTypeID
WHERE
	PO.LastEditedWhen <= @NewCutoff OR
	POL.LastEditedWhen <= @NewCutoff

SELECT
	[Purchases Count] = (SELECT COUNT(*) FROM #Purchases),
	[DW Purchases Count] = (SELECT COUNT(*) FROM Fact.[Purchase] WHERE [Purchase Key] > 0),
	[Purchases Mismatch Count] = ABS(
		(SELECT COUNT(*) FROM #Purchases) - 
		(SELECT COUNT(*) FROM Fact.[Purchase] WHERE [Purchase Key] > 0)
	),
	[Purchases Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#Purchases P LEFT JOIN
			(
				SELECT
					DWP.*,
					SI.[Stock Item],
					SI.[WWI Stock Item ID]
				FROM
					Fact.[Purchase] DWP LEFT JOIN
					Dimension.[Stock Item] SI ON
						SI.[Stock Item Key] = DWP.[Stock Item Key] 
			) DWP ON
				DWP.[WWI Purchase Order ID] = P.[WWI Purchase Order ID] AND
				DWP.[WWI Stock Item ID] = P.[WWI Stock Item ID] AND
				DWP.[Stock Item] = ISNULL(P.[Stock Item], 'Unknown') AND
				DWP.[Date Key] = P.[Date Key] AND
				DWP.[WWI Purchase Order ID] = P.[WWI Purchase Order ID] AND
				DWP.[Ordered Outers] = P.[Ordered Outers] AND
				DWP.[Ordered Quantity] = P.[Ordered Quantity] AND
				DWP.[Received Outers] = P.[Received Outers] AND
				DWP.[Package] = P.Package AND
				DWP.[Is Order Finalized] = P.[Is Order Finalized] LEFT JOIN
			Dimension.Supplier S ON
				S.[Supplier Key] = DWP.[Supplier Key] AND
				S.Supplier = ISNULL(P.Supplier, 'Unknown') 
				
		WHERE
			DWP.[Purchase Key] IS NULL OR
			S.[Supplier Key] IS NULL 
	)

-- End Purchases


-- Start Sales

IF OBJECT_ID('tempdb..#Sales') IS NOT NULL 
	DROP TABLE #Sales

CREATE TABLE #Sales
(
	[City] nvarchar(100) NOT NULL,
	[Customer] nvarchar(100) NOT NULL,
	[Bill To Customer] nvarchar(100) NOT NULL,
	[Stock Item] nvarchar(100) NOT NULL,
	[Invoice Date Key] [date] NOT NULL,
	[Delivery Date Key] [date] NULL,
	[Salesperson] nvarchar(100) NOT NULL,
	[WWI Invoice ID] [int] NOT NULL,
	[Description] [nvarchar](100) NOT NULL,
	[Package] [nvarchar](100) NOT NULL,
	[Quantity] [int] NOT NULL,
	[Unit Price] [decimal](18, 2) NOT NULL,
	[Tax Rate] [decimal](18, 3) NOT NULL,
	[Total Excluding Tax] [decimal](18, 2) NOT NULL,
	[Tax Amount] [decimal](18, 2) NOT NULL,
	[Profit] [decimal](18, 2) NOT NULL,
	[Total Including Tax] [decimal](18, 2) NOT NULL,
	[Total Dry Items] [int] NOT NULL,
	[Total Chiller Items] [int] NOT NULL,
	[WWI Invoice Line ID] [int] NOT NULL
)

INSERT INTO #Sales
(
	[City],
	[Customer],
	[Bill To Customer],
	[Stock Item],
	[Invoice Date Key],
	[Delivery Date Key],
	[Salesperson],
	[WWI Invoice ID],
	[Description],
	[Package],
	[Quantity],
	[Unit Price],
	[Tax Rate],
	[Total Excluding Tax],
	[Tax Amount],
	[Profit],
	[Total Including Tax],
	[Total Dry Items],
	[Total Chiller Items],
	[WWI Invoice Line ID]
)
SELECT
	ISNULL(C.CityName, ''),
	ISNULL(CU.CustomerName, ''),
	ISNULL(BCU.CustomerName, ''),
	ISNULL(SI.StockItemName, ''),
	I.InvoiceDate,
	I.ConfirmedDeliveryTime,
	SP.FullName,
	I.InvoiceID,
	IL.Description,
	PT.PackageTypeName,
	IL.Quantity,
	IL.UnitPrice,
	IL.TaxRate,
	IL.ExtendedPrice - IL.TaxAmount,
	IL.TaxAmount,
	IL.LineProfit,
	IL.ExtendedPrice,
	CASE 
		WHEN SI.IsChillerStock = 0 THEN IL.Quantity 
		ELSE 0 
	END,
	CASE 
		WHEN SI.IsChillerStock <> 0 THEN IL.Quantity 
		ELSE 0 
	END,
	IL.InvoiceLineID
FROM
	WideWorldImporters.Sales.Invoices I LEFT JOIN
	WideWorldImporters.Sales.InvoiceLines IL ON
		IL.InvoiceID = I.InvoiceID LEFT JOIN
	(
		SELECT
			C.CustomerID,
			C.CustomerName,
			C.DeliveryCityID
		FROM
			WideWorldImporters.Sales.Customers C
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION

		SELECT
			CA.CustomerID,
			CA.CustomerName,
			CA.DeliveryCityID
		FROM
			WideWorldImporters.Sales.Customers_Archive CA
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) CU ON
		CU.CustomerID = I.CustomerID LEFT JOIN
	(
		SELECT
			C.CityID,
			C.CityName
		FROM
			WideWorldImporters.Application.Cities C
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION

		SELECT
			CA.CityID,
			CA.CityName
		FROM
			WideWorldImporters.Application.Cities_Archive CA
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) C ON
		C.CityID = CU.DeliveryCityID LEFT JOIN
	(
		SELECT
			C.CustomerID,
			C.CustomerName
		FROM
			WideWorldImporters.Sales.Customers C
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION

		SELECT
			CA.CustomerID,
			CA.CustomerName
		FROM
			WideWorldImporters.Sales.Customers_Archive CA
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) BCU ON
		BCU.CustomerID = I.BillToCustomerID LEFT JOIN
	(
		SELECT
			SI.StockItemID,
			SI.StockItemName,
			SI.IsChillerStock
		FROM
			WideWorldImporters.Warehouse.StockItems SI
		WHERE
			@NewCutoff BETWEEN SI.ValidFrom AND SI.ValidTo

		UNION

		SELECT
			SIA.StockItemID,
			SIA.StockItemName,
			SIA.IsChillerStock
		FROM
			WideWorldImporters.Warehouse.StockItems_Archive SIA
		WHERE
			@NewCutoff BETWEEN SIA.ValidFrom AND SIA.ValidTo
	) SI ON
		SI.StockItemID = IL.StockItemID LEFT JOIN
	(
		SELECT
			P.PersonID,
			P.FullName
		FROM
			WideWorldImporters.Application.People P
		WHERE
			@NewCutoff BETWEEN P.ValidFrom AND P.ValidTo

		UNION

		SELECT
			PA.PersonID,
			PA.FullName
		FROM
			WideWorldImporters.Application.People_Archive PA
		WHERE
			@NewCutoff BETWEEN PA.ValidFrom AND PA.ValidTo
	) SP ON
		SP.PersonID = I.SalespersonPersonID LEFT JOIN
	(
		SELECT
			PT.PackageTypeID,
			PT.PackageTypeName
		FROM
			WideWorldImporters.Warehouse.PackageTypes PT
		WHERE
			@NewCutoff BETWEEN PT.ValidFrom AND PT.ValidTo

		UNION

		SELECT
			PTA.PackageTypeID,
			PTA.PackageTypeName
		FROM
			WideWorldImporters.Warehouse.PackageTypes_Archive PTA
		WHERE
			@NewCutoff BETWEEN PTA.ValidFrom AND PTA.ValidTo
	) PT ON
		PT.PackageTypeID = IL.PackageTypeID
WHERE
	I.LastEditedWhen <= @NewCutoff OR
	IL.LastEditedWhen <= @NewCutoff

SELECT
	[Sales Count] = (SELECT COUNT(*) FROM #Sales),
	[DW Sales Count] = (SELECT COUNT(*) FROM Fact.Sale WHERE [Sale Key] > 0),
	[Sales Mismatch Count] = ABS(
		(SELECT COUNT(*) FROM #Sales) - 
		(SELECT COUNT(*) FROM Fact.Sale WHERE [Sale Key] > 0)
	),
	[Sales Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#Sales P LEFT JOIN
			Fact.Sale DWS ON
				DWS.[Invoice Date Key] = P.[Invoice Date Key] AND
				(
					DWS.[Delivery Date Key] = P.[Delivery Date Key] OR
					(
						DWS.[Delivery Date Key] IS NULL AND
						P.[Delivery Date Key] IS NULL
					)
				)	AND
				DWS.[WWI Invoice ID] = P.[WWI Invoice ID] AND
				DWS.[WWI Invoice Line ID] = P.[WWI Invoice Line ID] AND
				DWS.[Description] = ISNULL(P.[Description], '') AND
				DWS.[Package] = ISNULL(P.Package, '') AND
				DWS.[Quantity] = P.Quantity AND
				DWS.[Unit Price] = P.[Unit Price] ANd
				DWS.[Tax Rate] = P.[Tax Rate] AND
				DWS.[Total Excluding Tax] = P.[Total Excluding Tax] AND
				DWS.[Tax Amount] = P.[Tax Amount] AND
				DWS.[Profit] = P.Profit AND
				DWS.[Total Including Tax] = P.[Total Including Tax] AND
				DWS.[Total Dry Items] = P.[Total Dry Items] AND
				DWS.[Total Chiller Items] = P.[Total Chiller Items] 
				LEFT JOIN
			Dimension.City C ON
				C.[City Key] = DWS.[City Key] AND
				C.City = ISNULL(P.City, 'Unknown') LEFT JOIN
			Dimension.Customer CU ON
				CU.[Customer Key] = DWS.[Customer Key] AND
				CU.Customer = ISNULL(P.Customer, 'Unknown') LEFT JOIN
			Dimension.Customer BCU ON
				BCU.[Customer Key] = DWS.[Bill To Customer Key] AND
				BCU.Customer = ISNULL(P.[Bill To Customer], 'Unknown') LEFT JOIN
			Dimension.[Stock Item] SI ON
				SI.[Stock Item Key] = DWS.[Stock Item Key] AND
				SI.[Stock Item] = ISNULL(P.[Stock Item], 'Unknown') LEFT JOIN
			Dimension.Employee E ON
				E.[Employee Key] = DWS.[Salesperson Key] AND
				E.Employee = ISNULL(P.Salesperson, 'Unknown')
 		WHERE
			DWS.[Sale Key] IS NULL OR
			C.[City Key] IS NULL OR
			CU.[Customer Key] IS NULL OR
			BCU.[Customer Key] IS NULL OR
			SI.[Stock Item Key] IS NULL OR
			E.[Employee Key] IS NULL
	)

-- End Sales


-- Start Stock Holdings

IF OBJECT_ID('tempdb..#StockHoldings') IS NOT NULL 
	DROP TABLE #StockHoldings

CREATE TABLE #StockHoldings 
(
	[WWI Stock Item ID] [int] NOT NULL,
	[Stock Item] nvarchar(100) NOT NULL,
	[Quantity On Hand] [int] NOT NULL,
	[Bin Location] [nvarchar](20) NOT NULL,
	[Last Stocktake Quantity] [int] NOT NULL,
	[Last Cost Price] [decimal](18, 2) NOT NULL,
	[Reorder Level] [int] NOT NULL,
	[Target Stock Level] [int] NOT NULL
)

INSERT INTO #StockHoldings
(
	[WWI Stock Item ID],
	[Stock Item],
	[Quantity On Hand],
	[Bin Location],
	[Last Stocktake Quantity],
	[Last Cost Price],
	[Reorder Level],
	[Target Stock Level]
)
SELECT 
	SI.StockItemID,
	SI.StockItemName,
	SIH.QuantityOnHand,
	SIH.BinLocation,
	SIH.LastStocktakeQuantity,
	SIH.LastCostPrice,
	SIH.ReorderLevel,
	SIH.TargetStockLevel
FROM
	WideWorldImporters.Warehouse.StockItemHoldings SIH JOIN
	(
		SELECT
			SI.StockItemID,
			SI.StockItemName
		FROM
			WideWorldImporters.Warehouse.StockItems SI
		WHERE
			@NewCutoff BETWEEN SI.ValidFrom AND SI.ValidTo

		UNION

		SELECT
			SIA.StockItemID,
			SIA.StockItemName
		FROM
			WideWorldImporters.Warehouse.StockItems_Archive SIA
		WHERE
			@NewCutoff BETWEEN SIA.ValidFrom AND SIA.ValidTo
	) SI ON
		SI.StockItemID = SIH.StockItemID

SELECT
	[Stock Holdings Count] = (SELECT COUNT(*) FROM #StockHoldings),
	[DW Stock Holdings Count] = (SELECT COUNT(*) FROM Fact.[Stock Holding] WHERE [Stock Holding Key] > 0),
	[Stock Holdings Mismatch Data] = ABS(
		(SELECT COUNT(*) FROM #StockHoldings) - 
		(SELECT COUNT(*) FROM Fact.[Stock Holding] WHERE [Stock Holding Key] > 0)
	),
	[Purchases Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#StockHoldings SH LEFT JOIN
			(
				SELECT
					DWSH.*,
					SI.[Stock Item],
					SI.[WWI Stock Item ID]
				FROM
					Fact.[Stock Holding] DWSH JOIN
					Dimension.[Stock Item] SI ON
						SI.[Stock Item Key] = DWSH.[Stock Item Key]

			) DWSH ON
				DWSH.[WWI Stock Item ID] = SH.[WWI Stock Item ID] AND
				DWSH.[Stock Item] = SH.[Stock Item] AND
				DWSH.[Quantity On Hand] = SH.[Quantity On Hand] AND
				DWSH.[Bin Location] = SH.[Bin Location] AND
				DWSH.[Last Stocktake Quantity] = SH.[Last Stocktake Quantity] AND
				DWSH.[Last Cost Price] = SH.[Last Cost Price] AND
				DWSH.[Reorder Level] = SH.[Reorder Level] AND
				DWSH.[Target Stock Level] = SH.[Target Stock Level]
		WHERE
			DWSH.[WWI Stock Item ID] IS NULL
	)

-- End Stock Holdings


-- Start Transactions

IF OBJECT_ID('tempdb..#Transactions') IS NOT NULL 
	DROP TABLE #Transactions

CREATE TABLE #Transactions 
(
	[Date Key] [date] NOT NULL,
	[Customer] nvarchar(100) NULL,
	[Bill To Customer] nvarchar(100) NULL,
	[Supplier] nvarchar(100) NULL,
	[Transaction Type] nvarchar(100) NOT NULL,
	[Payment Method] nvarchar(100) NULL,
	[WWI Customer Transaction ID] [int] NULL,
	[WWI Supplier Transaction ID] [int] NULL,
	[WWI Invoice ID] [int] NULL,
	[WWI Purchase Order ID] [int] NULL,
	[Supplier Invoice Number] [nvarchar](20) NULL,
	[Total Excluding Tax] [decimal](18, 2) NOT NULL,
	[Tax Amount] [decimal](18, 2) NOT NULL,
	[Total Including Tax] [decimal](18, 2) NOT NULL,
	[Outstanding Balance] [decimal](18, 2) NOT NULL,
	[Is Finalized] [bit] NOT NULL
)

INSERT INTO #Transactions
(
	[Date Key],
	[Customer],
	[Bill To Customer],
	[Supplier],
	[Transaction Type],
	[Payment Method],
	[WWI Customer Transaction ID],
	[WWI Supplier Transaction ID],
	[WWI Invoice ID],
	[WWI Purchase Order ID],
	[Supplier Invoice Number],
	[Total Excluding Tax],
	[Tax Amount],
	[Total Including Tax],
	[Outstanding Balance],
	[Is Finalized]
)
SELECT
	CT.TransactionDate,
	C.CustomerName,
	BC.CustomerName,
	CAST(NULL AS nvarchar(100)),
	TT.TransactionTypeName,
	PM.PaymentMethodName,
	CT.CustomerTransactionID,
	CAST(NULL AS INT),
	CT.InvoiceID,
	CAST(NULL AS INT),
	CAST(NULL AS NVARCHAR(20)),
	CT.AmountExcludingTax,
	CT.TaxAmount,
	CT.TransactionAmount,
	CT.OutstandingBalance,
	CT.IsFinalized
FROM
	WideWorldImporters.Sales.CustomerTransactions CT LEFT JOIN
	WideWorldImporters.Sales.Invoices I ON
		I.InvoiceID = CT.InvoiceID LEFT JOIN
	(
		SELECT
			C.CustomerID,
			C.CustomerName
		FROM
			WideWorldImporters.Sales.Customers C 
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION 

		SELECT
			CA.CustomerID,
			CA.CustomerName
		FROM
			WideWorldImporters.Sales.Customers_Archive CA 
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) C ON
		C.CustomerID = COALESCE(I.CustomerID, CT.CustomerID) LEFT JOIN
	(
		SELECT
			C.CustomerID,
			C.CustomerName
		FROM
			WideWorldImporters.Sales.Customers C 
		WHERE
			@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

		UNION 

		SELECT
			CA.CustomerID,
			CA.CustomerName
		FROM
			WideWorldImporters.Sales.Customers_Archive CA 
		WHERE
			@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo
	) BC ON
		BC.CustomerID = CT.CustomerID LEFT JOIN
	(
		SELECT
			TT.TransactionTypeID,
			TT.TransactionTypeName
		FROM
			WideWorldImporters.Application.TransactionTypes  TT 
		WHERE
			@NewCutoff BETWEEN TT.ValidFrom AND TT.ValidTo

		UNION 

		SELECT
			TTA.TransactionTypeID,
			TTA.TransactionTypeName
		FROM
			WideWorldImporters.Application.TransactionTypes_Archive  TTA 
		WHERE
			@NewCutoff BETWEEN TTA.ValidFrom AND TTA.ValidTo
	) TT ON
		TT.TransactionTypeID = CT.TransactionTypeID LEFT JOIN
	(
		SELECT
			PM.PaymentMethodID,
			PM.PaymentMethodName
		FROM
			WideWorldImporters.Application.PaymentMethods PM 
		WHERE
			@NewCutoff BETWEEN PM.ValidFrom AND PM.ValidTo

		UNION 

		SELECT
			PMA.PaymentMethodID,
			PMA.PaymentMethodName
		FROM
			WideWorldImporters.Application.PaymentMethods_Archive PMA
		WHERE
			@NewCutoff BETWEEN PMA.ValidFrom AND PMA.ValidTo
	) PM ON
		PM.PaymentMethodID = CT.PaymentMethodID
WHERE
	CT.LastEditedWhen <= @NewCutoff

UNION ALL

SELECT
	ST.TransactionDate,
	CAST(NULL AS NVARCHAR(100)),
	CAST(NULL AS NVARCHAR(100)),
	S.SupplierName,
	TT.TransactionTypeName,
	PM.PaymentMethodName,
	CAST(NULL AS INT),
	ST.SupplierTransactionID,
	CAST(NULL AS INT),
	ST.PurchaseOrderID,
	ST.SupplierInvoiceNumber,
	ST.AmountExcludingTax,
	ST.TaxAmount,
	ST.TransactionAmount,
	ST.OutstandingBalance,
	ST.IsFinalized
FROM
	WideWorldImporters.Purchasing.SupplierTransactions ST LEFT JOIN
	(
		SELECT
			S.SupplierID,
			S.SupplierName
		FROM
			WideWorldImporters.Purchasing.Suppliers S 
		WHERE
			@NewCutoff BETWEEN S.ValidFrom AND S.ValidTo

		UNION 

		SELECT
			SA.SupplierID,
			SA.SupplierName
		FROM
			WideWorldImporters.Purchasing.Suppliers_Archive SA 
		WHERE
			@NewCutoff BETWEEN SA.ValidFrom AND SA.ValidTo
	) S ON
		S.SupplierID = ST.SupplierID LEFT JOIN
	(
		SELECT
			TT.TransactionTypeID,
			TT.TransactionTypeName
		FROM
			WideWorldImporters.Application.TransactionTypes  TT 
		WHERE
			@NewCutoff BETWEEN TT.ValidFrom AND TT.ValidTo

		UNION 

		SELECT
			TTA.TransactionTypeID,
			TTA.TransactionTypeName
		FROM
			WideWorldImporters.Application.TransactionTypes_Archive  TTA 
		WHERE
			@NewCutoff BETWEEN TTA.ValidFrom AND TTA.ValidTo
	) TT ON
		TT.TransactionTypeID = ST.TransactionTypeID LEFT JOIN
	(
		SELECT
			PM.PaymentMethodID,
			PM.PaymentMethodName
		FROM
			WideWorldImporters.Application.PaymentMethods PM 
		WHERE
			@NewCutoff BETWEEN PM.ValidFrom AND PM.ValidTo

		UNION 

		SELECT
			PMA.PaymentMethodID,
			PMA.PaymentMethodName
		FROM
			WideWorldImporters.Application.PaymentMethods_Archive PMA
		WHERE
			@NewCutoff BETWEEN PMA.ValidFrom AND PMA.ValidTo
	) PM ON
		PM.PaymentMethodID = ST.PaymentMethodID
WHERE
	ST.LastEditedWhen <= @NewCutoff

SELECT
	[Transactions Count] = (SELECT COUNT(*) FROM #Transactions),
	[DW Transactions Count] = (SELECT COUNT(*) FROM Fact.[Transaction] WHERE [Transaction Key] > 0),
	[Transactions Mismatch Count] = ABS(
		(SELECT COUNT(*) FROM #Transactions) - 
		(SELECT COUNT(*) FROM Fact.[Transaction] WHERE [Transaction Key] > 0)
	),
	[Transactions Mismatch Data] =
	(
		SELECT
			COUNT(*)
		FROM
			#Transactions T LEFT JOIN
			Fact.[Transaction] DWT ON
				DWT.[Date Key] = T.[Date Key] aND
				ISNULL(DWT.[WWI Customer Transaction ID], 0) = ISNULL(T.[WWI Customer Transaction ID], 0) AND
				ISNULL(DWT.[WWI Supplier Transaction ID], 0) = ISNULL(T.[WWI Supplier Transaction ID], 0) AND
				ISNULL(DWT.[WWI Invoice ID], 0) = ISNULL(T.[WWI Invoice ID], 0) AND
				ISNULL(DWT.[WWI Purchase Order ID], 0) = ISNULL(T.[WWI Purchase Order ID], 0) AND
				ISNULL(DWT.[Supplier Invoice Number], 0) = ISNULL(T.[Supplier Invoice Number], 0) AND
				DWT.[Total Excluding Tax] = T.[Total Excluding Tax] AND
				DWT.[Tax Amount] = T.[Tax Amount] AND
				DWT.[Total Including Tax] = T.[Total Including Tax] AND
				DWT.[Outstanding Balance] = T.[Outstanding Balance] AND
				DWT.[Is Finalized] = T.[Is Finalized]
				LEFT JOIN
			Dimension.Customer C ON
				C.[Customer Key] = DWT.[Customer Key] AND
				C.Customer = ISNULL(T.Customer, 'Unknown') LEFT JOIN
			Dimension.Customer BC ON
				BC.[Customer Key] = DWT.[Bill To Customer Key] AND
				BC.Customer = ISNULL(T.[Bill To Customer], 'Unknown') LEFT JOIN
			Dimension.Supplier S ON
				S.[Supplier Key] = DWT.[Supplier Key] AND
				S.Supplier = ISNULL(T.Supplier, 'Unknown') LEFT JOIN
			Dimension.[Transaction Type] TT ON
				TT.[Transaction Type Key] = DWT.[Transaction Type Key] AND
				TT.[Transaction Type] = ISNULL(T.[Transaction Type], 'Unknown') LEFT JOIN
			Dimension.[Payment Method] PM ON
				PM.[Payment Method Key] = DWT.[Payment Method Key] AND
				PM.[Payment Method] = ISNULL(T.[Payment Method], 'Unknown')
 		WHERE
			DWT.[Transaction Key] IS NULL OR
			C.Customer IS NULL OR
			BC.[Customer Key] IS NULL OR
			S.[Supplier Key] IS NULL OR
			TT.[Transaction Type Key] IS NULL OR
			PM.[Payment Method Key] IS NULL
	)

-- End Transactions

--select * from Integration.[ETL Cutoff]
