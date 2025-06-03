USE [WideWorldImporters]
GO
/****** Object:  StoredProcedure [Integration].[GetCityUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








/*

EXEC [Integration].[GetCityUpdatesNew] '1/1/2013', '1/1/2013'

*/
CREATE PROCEDURE [Integration].[GetCityUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

	IF OBJECT_ID('tempdb..#CitiesChangesFinal') IS NOT NULL 
		DROP TABLE #CitiesChangesFinal

	IF OBJECT_ID('tempdb..#StateProvincesChanges') IS NOT NULL 
		DROP TABLE #StateProvincesChanges

	IF OBJECT_ID('tempdb..#CountriesChanges') IS NOT NULL 
		DROP TABLE #CountriesChanges

	IF OBJECT_ID('tempdb..#StateProvinces') IS NOT NULL 
		DROP TABLE #StateProvinces

	IF OBJECT_ID('tempdb..#Countries') IS NOT NULL 
		DROP TABLE #Countries

    -- Table for all changes to cities by city, state provice or country
	CREATE TABLE #CitiesChangesFinal
	(
		[WWI City ID] [int] NOT NULL,
		[City] [nvarchar](50) NOT NULL,
		[State Province ID] [int] NOT NULL, 
		[State Province] [nvarchar](50) NOT NULL,
		[Country ID] [int] NOT NULL,
		[Country] [nvarchar](60) NOT NULL,
		[Continent] [nvarchar](30) NOT NULL,
		[Sales Territory] [nvarchar](50) NOT NULL,
		[Region] [nvarchar](30) NOT NULL,
		[Subregion] [nvarchar](30) NOT NULL,
		[Location] [geography] NULL,
		[Latest Recorded Population] [bigint],
		[Valid From] [datetime2](7) NOT NULL,
		[Valid To] [datetime2](7) NOT NULL
	)

	-- Table for state/province changes only
	CREATE TABLE #StateProvincesChanges
	(
		StateProvinceID INT,
		ValidFrom DATETIME2,
		ValidTo DATETIME2
	)

	-- Table for country changes only
	CREATE TABLE #CountriesChanges
	(
		CountryID INT,
		ValidFrom DATETIME2,
		ValidTo DATETIME2
	)

	-- Table for state provinces 
	CREATE TABLE #StateProvinces
	(
		StateProvinceID INT,
		CountryID INT,
		StateProvinceName NVARCHAR(50),
		SalesTerritory NVARCHAR(50)
	)

	-- Table for countries
	CREATE TABLE #Countries
	(
		CountryID INT,
		CountryName NVARCHAR(50),
		Continent NVARCHAR(50),
		Region NVARCHAR(50),
		Subregion NVARCHAR(50)
	)


	-- Start Step 1: Get changes by state provinces

	INSERT INTO #StateProvincesChanges
	(
		StateProvinceID,
		ValidFrom,
		ValidTo
	)
	SELECT
		SP.StateProvinceID,
		SP.ValidFrom,
		SP.ValidTo
	FROM
		Application.StateProvinces SP
	WHERE
		(
			SP.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				SP.ValidFrom >= @LastCutoff
			)
		) AND
		@NewCutoff <= SP.ValidTo AND
		SP.ValidFrom <= @NewCutoff 

	UNION ALL

	SELECT
		SPA.StateProvinceID,
		SPA.ValidFrom,
		SPA.ValidTo
	FROM
		Application.StateProvinces_Archive SPA
	WHERE
		(
			SPA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				SPA.ValidFrom >= @LastCutoff
			)
		) AND
		@NewCutoff <= SPA.ValidTo AND
		SPA.ValidFrom <= @NewCutoff 

	-- End Step 1: Get changes by state provinces


	-- Start Step 2: Get changes by countries

	INSERT INTO #CountriesChanges
	(
		CountryID,
		ValidFrom,
		ValidTo
	)
	SELECT 
		C.CountryID,
		C.ValidFrom,
		C.ValidTo
	FROM 
		Application.Countries C
	WHERE
		(
			C.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				C.ValidFrom >= @LastCutoff
			)
		) AND
		C.ValidFrom <= @NewCutoff AND
		@NewCutoff <= C.ValidTo

	UNION ALL

	SELECT 
		CA.CountryID,
		CA.ValidFrom,
		CA.ValidTo
	FROM
		Application.Countries_Archive CA
	WHERE
		(
			CA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				CA.ValidFrom >= @LastCutoff
			)
		) AND
		CA.ValidFrom <= @NewCutoff AND
		@NewCutoff <= CA.ValidTo

	-- End Step 2: Get changes by countries


	-- Start Step 3: Get state provinces that is in new cutoff

	INSERT INTO #StateProvinces
	(
		StateProvinceID,
		CountryID,
		StateProvinceName,
		SalesTerritory
	)
	SELECT
		SP.StateProvinceID,
		SP.CountryID,
		SP.StateProvinceName,
		SP.SalesTerritory
	FROM
		Application.StateProvinces SP
	WHERE
		@NewCutoff BETWEEN SP.ValidFrom AND SP.ValidTo

	UNION

	SELECT
		SPA.StateProvinceID,
		SPA.CountryID,
		SPA.StateProvinceName,
		SPA.SalesTerritory
	FROM
		Application.StateProvinces_Archive SPA
	WHERE
		@NewCutoff BETWEEN SPA.ValidFrom AND SPA.ValidTo

	-- End Step 3: Get state provinces that is in new cutoff


	-- Start Step 4: Get all countries that is in new cutoff
	
	INSERT INTO #Countries
	(
		CountryID,
		CountryName,
		Continent,
		Region,
		Subregion
	)
	SELECT
		C.CountryID,
		C.CountryName,
		C.Continent,
		C.Region,
		C.Subregion
	FROM
		Application.Countries C
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
		Application.Countries_Archive CA
	WHERE
		@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo

	-- End Step 4: Get all countries that is in new cutoff


	-- Start Step 5: Copy the cities to final table
	
	-- Copy city
	INSERT INTO #CitiesChangesFinal
	(
		[WWI City ID],
		[City],
		[State Province ID],
		[State Province],
		[Country ID],
		[Country],
		[Continent],
		[Sales Territory],
		[Region],
		[Subregion],
		[Location],
		[Latest Recorded Population],
		[Valid From],
		[Valid To]
	)
	SELECT 
		[WWI City ID] = C.CityID,
		[City] = C.CityName,
		[State Province ID] = C.StateProvinceID,
		[State Province] = SP.StateProvinceName,
		[Country ID] = CO.CountryID,
		[Country] = CO.CountryName,
		[Continent] = CO.Continent,
		[Sales Territory] = SP.SalesTerritory,
		[Region] = CO.Region,
		[Subregion] = CO.Subregion,
		[Location] = C.[Location],
		[Latest Recorded Population] = C.LatestRecordedPopulation,
		[Valid From] = C.ValidFrom,
		[Valid To] = C.ValidTo
	FROM 
		Application.Cities C LEFT JOIN
		#StateProvinces SP ON
			SP.StateProvinceID = C.StateProvinceID LEFT JOIN
		#Countries CO ON
			CO.CountryID = SP.CountryID
	WHERE
		(
			C.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				C.ValidFrom >= @NewCutoff
			) OR
			EXISTS
			(
				SELECT
					1
				FROM
					#StateProvincesChanges SPC
				WHERE
					SPC.StateProvinceID = SP.StateProvinceID
			) OR
			EXISTS
			(
				SELECT
					1
				FROM
					#CountriesChanges CC
				WHERE
					CC.CountryID = CO.CountryID 
			)
		) AND
		@NewCutoff <= C.ValidTo AND
		C.ValidFrom <= @NewCutoff

	-- Copy city archive
	INSERT INTO #CitiesChangesFinal
	(
		[WWI City ID],
		[City],
		[State Province ID],
		[State Province],
		[Country ID],
		[Country],
		[Continent],
		[Sales Territory],
		[Region],
		[Subregion],
		[Location],
		[Latest Recorded Population],
		[Valid From],
		[Valid To]
	)
	SELECT 
		[WWI City ID] = CA.CityID,
		[City] = CA.CityName,
		[State Province ID] = CA.StateProvinceID,
		[State Province] = SP.StateProvinceName,
		[Country ID] = CO.CountryID,
		[Country] = CO.CountryName,
		[Continent] = CO.Continent,
		[Sales Territory] = SP.SalesTerritory,
		[Region] = CO.Region,
		[Subregion] = CO.Subregion,
		[Location] = CA.[Location],
		[Latest Recorded Population] = CA.LatestRecordedPopulation,
		[Valid From] = CA.ValidFrom,
		[Valid To] = CA.ValidTo
	FROM 
		Application.Cities_Archive CA LEFT JOIN
		#StateProvinces SP ON
			SP.StateProvinceID = CA.StateProvinceID LEFT JOIN
		#Countries CO ON
			CO.CountryID = SP.CountryID
	WHERE
		NOT EXISTS 
		(
			SELECT
				1
			FROM
				#CitiesChangesFinal CCF 
			WHERE
				CCF.[WWI City ID] = CA.CityID
		) AND
		(
			CA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				CA.ValidFrom >= @NewCutoff
			) OR
			EXISTS
			(
				SELECT
					1
				FROM
					#StateProvincesChanges SPC
				WHERE
					SPC.StateProvinceID = SP.StateProvinceID
			) OR
			EXISTS
			(
				SELECT
					1
				FROM
					#CountriesChanges CC
				WHERE
					CC.CountryID = CO.CountryID 
			)
		) AND 
		@NewCutoff <= CA.ValidTo AND
		CA.ValidFrom <= @NewCutoff
	
	-- Start Step 5: Copy the cities to final table
	

	-- Select the final table
	SELECT
		CCF.[WWI City ID],
		CCF.[City],
		CCF.[State Province],
		CCF.[Country],
		CCF.[Continent],
		CCF.[Sales Territory],
		CCF.[Region],
		CCF.[Subregion],
		CCF.[Location],
		[Latest Recorded Population] = ISNULL(CCF.[Latest Recorded Population], 0),
		[Valid From] = 
			CASE 
				WHEN 
					CCF.[Valid From] <= ISNULL(SPC.ValidFrom, CCF.[Valid From]) AND 
					CCF.[Valid From] <= ISNULL(CC.ValidFrom, CCF.[Valid From]) 
					THEN CCF.[Valid From]
				WHEN 
					ISNULL(SPC.ValidFrom, CCF.[Valid From]) <= CCF.[Valid From] AND 
					ISNULL(SPC.ValidFrom, CCF.[Valid From]) <= CC.ValidFrom 
					THEN ISNULL(SPC.ValidFrom, CCF.[Valid From])
				ELSE ISNULL(CC.ValidFrom, CCF.[Valid From])
			END,
		[Valid To] = 
			CASE 
				WHEN 
					CCF.[Valid To] >= ISNULL(SPC.ValidTo, CCF.[Valid To]) AND 
					CCF.[Valid To] >= ISNULL(CC.ValidTo, CCF.[Valid To]) 
					THEN CCF.[Valid To]
				WHEN 
					ISNULL(SPC.ValidTo, CCF.[Valid To]) >= CCF.[Valid To] AND 
					ISNULL(SPC.ValidTo, CCF.[Valid To]) >= CC.ValidTo 
					THEN ISNULL(SPC.ValidTo, CCF.[Valid To])
				ELSE ISNULL(CC.ValidTo, CCF.[Valid To])
			END
	FROM
		#CitiesChangesFinal CCF LEFT JOIN
		#StateProvincesChanges SPC ON
			SPC.StateProvinceID = CCF.[State Province ID] LEFT JOIN
		#CountriesChanges CC ON
			CC.CountryID = CCF.[Country ID]
	ORDER BY
		[Valid From],
		[WWI City ID]

END;
GO
/****** Object:  StoredProcedure [Integration].[GetCustomerUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





/*

EXEC [Integration].[GetCustomerUpdatesNew] '1/1/2013', '1/1/2013'

*/
CREATE PROCEDURE [Integration].[GetCustomerUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

	IF OBJECT_ID('tempdb..#CustomersChangesFinal') IS NOT NULL 
		DROP TABLE #CustomersChangesFinal

	IF OBJECT_ID('tempdb..#CustomerCategoriesChanges') IS NOT NULL 
		DROP TABLE #CustomerCategoriesChanges

	IF OBJECT_ID('tempdb..#BuyingGroupsChanges') IS NOT NULL 
		DROP TABLE #BuyingGroupsChanges

	IF OBJECT_ID('tempdb..#PrimaryContactChanges') IS NOT NULL 
		DROP TABLE #PrimaryContactChanges

	IF OBJECT_ID('tempdb..#Customers') IS NOT NULL 
		DROP TABLE #Customers

	IF OBJECT_ID('tempdb..#CustomerCategories') IS NOT NULL 
		DROP TABLE #CustomerCategories

	IF OBJECT_ID('tempdb..#BuyingGroups') IS NOT NULL 
		DROP TABLE #BuyingGroups

	IF OBJECT_ID('tempdb..#PrimaryContacts') IS NOT NULL 
		DROP TABLE #PrimaryContacts

	-- Table for all changes to customers by customer, category, buying groups and primary contacts
	CREATE TABLE #CustomersChangesFinal
	(
		[WWI Customer ID] [int] NOT NULL,
		[Customer] [nvarchar](100) NOT NULL,
		[Bill To Customer] [nvarchar](100) NULL,
		[Category ID] [int] NULL,
		[Category] [nvarchar](50) NULL,
		[Buying Group ID] [int] NULL,
		[Buying Group] [nvarchar](50) NULL,
		[Primary Contact ID] INT NULL,
		[Primary Contact] [nvarchar](50) NULL,
		[Postal Code] [nvarchar](10) NOT NULL,
		[Valid From] [datetime2](7) NOT NULL,
		[Valid To] [datetime2](7) NOT NULL
	)

	-- Table for customer categories changes
	CREATE TABLE #CustomerCategoriesChanges
	(
		CustomerCategoryID INT,
		ValidFrom DATETIME2(7),
		ValidTo DATETIME2(7)
	)

	-- Table for buying groups changes only
	CREATE TABLE #BuyingGroupsChanges
	(
		BuyingGroupID INT,
		ValidFrom DATETIME2(7),
		ValidTo DATETIME2(7)
	)

	-- Table for primary contact changes only
	CREATE TABLE #PrimaryContactChanges
	(
		PersonID INT,
		ValidFrom DATETIME2(7),
		ValidTo DATETIME2(7)
	)

	-- Table for customers for new cutoff
	CREATE TABLE #Customers
	(
		CustomerID INT,
		CustomerName NVARCHAR(50)
	)

	-- Table for customer categories for new cutoff
	CREATE TABLE #CustomerCategories
	(
		CustomerCategoryID INT,
		CustomerCategoryName NVARCHAR(50)
	)

	-- Table for buying groups for new cutoff
	CREATE TABLE #BuyingGroups
	(
		BuyingGroupID INT,
		BuyingGroupName NVARCHAR(50)
	)

	-- Table for primary contacts for new cutoff
	CREATE TABLE #PrimaryContacts
	(
		PersonID INT,
		FullName NVARCHAR(50)
	)


	-- Start Step 1: Get changes by customer categories
	INSERT INTO #CustomerCategoriesChanges
	(
		CustomerCategoryID,
		ValidFrom,
		ValidTo
	)
	SELECT	
		CC.CustomerCategoryID,
		CC.ValidFrom,
		CC.ValidTo
	FROM
		Sales.CustomerCategories CC 
	WHERE
		(
			CC.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				CC.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= CC.ValidTo AND
		CC.ValidFrom <= @NewCutoff

	UNION

	SELECT	
		CCA.CustomerCategoryID,
		CCA.ValidFrom,
		CCA.ValidTo
	FROM
		Sales.CustomerCategories_Archive CCA
	WHERE
		(
			CCA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				CCA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= CCA.ValidTo AND
		CCA.ValidFrom <= @NewCutoff

	-- End Step 1: Get changes by customer categories


	-- Start Step 2: Get changes by buying groups

	INSERT INTO #BuyingGroupsChanges
	(
		BuyingGroupID,
		ValidFrom,
		ValidTo
	)
	SELECT
		BG.BuyingGroupID,
		BG.ValidFrom,
		BG.ValidTo
	FROM
		Sales.BuyingGroups BG
	WHERE
		(
			BG.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				BG.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= BG.ValidTo AND
		BG.ValidFrom <= @NewCutoff

	UNION

	SELECT
		BGA.BuyingGroupID,
		BGA.ValidFrom,
		BGA.ValidTo
	FROM
		Sales.BuyingGroups_Archive BGA
	WHERE
		(
			BGA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				BGA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= BGA.ValidTo AND
		BGA.ValidFrom <= @NewCutoff

	-- End Step 2: Get changes by buying groups


	-- Start Step 3: Get changes by primary contacts

	INSERT INTO #PrimaryContactChanges
	(
		PersonID,
		ValidFrom,
		ValidTo
	)
	SELECT
		P.PersonID,
		P.ValidFrom,
		P.ValidTo
	FROM
		Application.People P 
	WHERE
		(
			P.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				P.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= P.ValidTo AND
		P.ValidFrom <= @NewCutoff

	UNION

	SELECT
		PA.PersonID,
		PA.ValidFrom,
		PA.ValidTo
	FROM
		Application.People_Archive PA
	WHERE
		(
			PA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PA.ValidTo AND
		PA.ValidFrom <= @NewCutoff

	-- End Step 3: Get changes by primary contacts


	-- End Step 4: Get customers by new cut off

	INSERT INTO #Customers 
	(
		CustomerID,
		CustomerName
	)
	SELECT
		C.CustomerID,
		C.CustomerName
	FROM
		Sales.Customers C
	WHERE
		@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo

	UNION

	SELECT
		CA.CustomerID,
		CA.CustomerName
	FROM
		Sales.Customers_Archive CA
	WHERE
		@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo

	-- End Step 4: Get customers by new cut off


	-- Start Step 5: Get customer categories by new cutoff
	
	INSERT INTO #CustomerCategories
	(
		CustomerCategoryID,
		CustomerCategoryName
	)
	SELECT
		CC.CustomerCategoryID,
		CC.CustomerCategoryName
	FROM
		Sales.CustomerCategories CC
	WHERE
		@NewCutoff BETWEEN CC.ValidFrom AND CC.ValidTo

	UNION

	SELECT
		CCA.CustomerCategoryID,
		CCA.CustomerCategoryName
	FROM
		Sales.CustomerCategories_Archive CCA
	WHERE
		@NewCutoff BETWEEN CCA.ValidFrom AND CCA.ValidTo

	-- End Step 5: Get customer categories by new cutoff


	-- Start Step 6: Get buying groups by new cutoff
	
	INSERT INTO #BuyingGroups
	(
		BuyingGroupID,
		BuyingGroupName
	)
	SELECT
		BG.BuyingGroupID,
		BG.BuyingGroupName
	FROM
		Sales.BuyingGroups BG
	WHERE
		@NewCutoff BETWEEN BG.ValidFrom AND BG.ValidTo

	UNION

	SELECT
		BGA.BuyingGroupID,
		BGA.BuyingGroupName
	FROM
		Sales.BuyingGroups_Archive BGA
	WHERE
		@NewCutoff BETWEEN BGA.ValidFrom AND BGA.ValidTo

	-- End Step 6: Get buying groups by new cutoff


	-- Start Step 7: Get primary contacts by new cutoff
	
	INSERT INTO #PrimaryContacts
	(
		PersonID,
		FullName
	)
	SELECT
		P.PersonID,
		P.FullName
	FROM
		Application.People P
	WHERE
		@NewCutoff BETWEEN P.ValidFrom AND P.ValidTo

	UNION

	SELECT
		PA.PersonID,
		PA.FullName
	FROM
		Application.People_Archive PA
	WHERE
		@NewCutoff BETWEEN PA.ValidFrom AND PA.ValidTo

	-- End Step 7: Get primary contacts by new cutoff


	-- Start Step 8: Copy to customers table final

	-- Copy from customers table
	INSERT INTO #CustomersChangesFinal
	(
		[WWI Customer ID],
		[Customer],
		[Bill To Customer],
		[Category ID],
		[Category],
		[Buying Group ID],
		[Buying Group],
		[Primary Contact ID],
		[Primary Contact],
		[Postal Code],
		[Valid From],
		[Valid To]
	)
	SELECT
		[WWI Customer ID] = C.CustomerID,
		[Customer] = C.CustomerName,
		[Bill To Customer] = C2.CustomerName,
		[Category ID] = C.CustomerCategoryID,
		[Category] = CC.CustomerCategoryName,
		[Buying Group ID] = BG.BuyingGroupID,
		[Buying Group] = BG.BuyingGroupName,
		[Primary Contact ID] = PC.PersonID,
		[Primary Contact] = PC.FullName,
		[Postal Code] = C.DeliveryPostalCode,
		[Valid From] = C.ValidFrom,
		[Valid To] = C.ValidTo
	FROM
		Sales.Customers C LEFT JOIN
		#Customers C2 ON
			C2.CustomerID = C.BillToCustomerID LEFT JOIN
		#CustomerCategories CC ON
			CC.CustomerCategoryID = C.CustomerCategoryID LEFT JOIN
		#BuyingGroups BG ON
			BG.BuyingGroupID = C.BuyingGroupID LEFT JOIN
		#PrimaryContacts PC ON
			PC.PersonID = C.PrimaryContactPersonID
	WHERE
		(
			C.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				C.ValidFrom >= @NewCutoff
			) OR
			EXISTS
			(
				SELECT
					1
				FROM
					#CustomerCategoriesChanges CCC
				WHERE
					CCC.CustomerCategoryID = C.CustomerCategoryID
			) OR
			EXISTS
			(
				SELECT
					1
				FROM
					#BuyingGroupsChanges BGC
				WHERE
					BGC.BuyingGroupID = C.BuyingGroupID
			) OR
			EXISTS
			(
				SELECT
					1
				FROM
					#PrimaryContactChanges PCC
				WHERE
					PCC.PersonID = C.PrimaryContactPersonID
			)
		) AND
		@NewCutoff <= C.ValidTo AND
		C.ValidFrom <= @NewCutoff 

	-- Copy from customers archive
	INSERT INTO #CustomersChangesFinal
	(
		[WWI Customer ID],
		[Customer],
		[Bill To Customer],
		[Category ID],
		[Category],
		[Buying Group ID],
		[Buying Group],
		[Primary Contact ID],
		[Primary Contact],
		[Postal Code],
		[Valid From],
		[Valid To]
	)
	SELECT
		[WWI Customer ID] = CA.CustomerID,
		[Customer] = CA.CustomerName,
		[Bill To Customer] = C2.CustomerName,
		[Category ID] = CA.CustomerCategoryID,
		[Category] = CC.CustomerCategoryName,
		[Buying Group ID] = BG.BuyingGroupID,
		[Buying Group] = BG.BuyingGroupName,
		[Primary Contact ID] = PC.PersonID,
		[Primary Contact] = PC.FullName,
		[Postal Code] = CA.DeliveryPostalCode,
		[Valid From] = CA.ValidFrom,
		[Valid To] = CA.ValidTo
	FROM
		Sales.Customers_Archive CA LEFT JOIN
		#Customers C2 ON
			C2.CustomerID = CA.BillToCustomerID LEFT JOIN
		#CustomerCategories CC ON
			CC.CustomerCategoryID = CA.CustomerCategoryID LEFT JOIN
		#BuyingGroups BG ON
			BG.BuyingGroupID = CA.BuyingGroupID LEFT JOIN
		#PrimaryContacts PC ON
			PC.PersonID = CA.PrimaryContactPersonID
	WHERE
		NOT EXISTS
		(
			SELECT
				1
			FROM
				#CustomersChangesFinal CCF 
			WHERE
				CCF.[WWI Customer ID] = CA.CustomerID
		) AND
		(
			CA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				CA.ValidFrom >= @NewCutoff
			) OR
			EXISTS
			(
				SELECT
					1
				FROM
					#CustomerCategoriesChanges CCC
				WHERE
					CCC.CustomerCategoryID = CA.CustomerCategoryID
			) OR
			EXISTS
			(
				SELECT
					1
				FROM
					#BuyingGroupsChanges BGC
				WHERE
					BGC.BuyingGroupID = CA.BuyingGroupID
			) OR
			EXISTS
			(
				SELECT
					1
				FROM
					#PrimaryContactChanges PCC
				WHERE
					PCC.PersonID = CA.PrimaryContactPersonID
			)
		) AND
		@NewCutoff <= CA.ValidTo AND
		CA.ValidFrom <= @NewCutoff 

	-- End Step 8: Get changes by customers

	
	-- Select final table
	SELECT
		[WWI Customer ID],
		[Customer],
		[Bill To Customer],
		[Category],
		[Buying Group] = ISNULL([Buying Group], ''),
		[Primary Contact],
		[Postal Code],
		[Valid From] =
			CASE 
				WHEN 
					CCF.[Valid From] <= ISNULL(CCC.ValidFrom, CCF.[Valid From]) AND
					CCF.[Valid From] <= ISNULL(BGC.ValidFrom, CCF.[Valid From]) AND
					CCF.[Valid From] <= ISNULL(PCC.ValidFrom, CCF.[Valid From]) 
					THEN CCF.[Valid From]
				WHEN 
					ISNULL(CCC.ValidFrom, CCF.[Valid From]) <= CCF.[Valid From] AND
					ISNULL(CCC.ValidFrom, CCF.[Valid From]) <= ISNULL(BGC.ValidFrom, CCF.[Valid From]) AND
					ISNULL(CCC.ValidFrom, CCF.[Valid From]) <= ISNULL(PCC.ValidFrom, CCF.[Valid From]) 
					THEN ISNULL(CCC.ValidFrom, CCF.[Valid From])
				WHEN 
					ISNULL(BGC.ValidFrom, CCF.[Valid From]) <= CCF.[Valid From] AND
					ISNULL(BGC.ValidFrom, CCF.[Valid From]) <= ISNULL(CCC.ValidFrom, CCF.[Valid From]) AND
					ISNULL(BGC.ValidFrom, CCF.[Valid From]) <= ISNULL(PCC.ValidFrom, CCF.[Valid From]) 
					THEN ISNULL(BGC.ValidFrom, CCF.[Valid From])
				ELSE ISNULL(PCC.ValidFrom, CCF.[Valid From])
			END,
		[Valid To] = 
			CASE 
				WHEN 
					CCF.[Valid To] >= ISNULL(CCC.ValidTo, CCF.[Valid To]) AND
					CCF.[Valid To] >= ISNULL(BGC.ValidTo, CCF.[Valid To]) AND
					CCF.[Valid To] >= ISNULL(PCC.ValidTo, CCF.[Valid To]) 
					THEN CCF.[Valid To]
				WHEN 
					ISNULL(CCC.ValidTo, CCF.[Valid To]) >= CCF.[Valid To] AND
					ISNULL(CCC.ValidTo, CCF.[Valid To]) >= ISNULL(BGC.ValidTo, CCF.[Valid To]) AND
					ISNULL(CCC.ValidTo, CCF.[Valid To]) >= ISNULL(PCC.ValidTo, CCF.[Valid To]) 
					THEN ISNULL(CCC.ValidTo, CCF.[Valid To])
				WHEN 
					ISNULL(BGC.ValidTo, CCF.[Valid To]) >= CCF.[Valid To] AND
					ISNULL(BGC.ValidTo, CCF.[Valid To]) >= ISNULL(CCC.ValidTo, CCF.[Valid To]) AND
					ISNULL(BGC.ValidTo, CCF.[Valid To]) >= ISNULL(PCC.ValidTo, CCF.[Valid To]) 
					THEN ISNULL(BGC.ValidTo, CCF.[Valid To])
				ELSE ISNULL(PCC.ValidTo, CCF.[Valid To])
			END
	FROM
		#CustomersChangesFinal CCF LEFT JOIN
		#CustomerCategoriesChanges CCC ON 
			CCC.CustomerCategoryID = CCF.[Category ID] LEFT JOIN
		#BuyingGroupsChanges BGC ON
			BGC.BuyingGroupID = CCF.[Buying Group ID] LEFT JOIN
		#PrimaryContactChanges PCC ON
			PCC.PersonID = CCF.[Primary Contact ID]
	ORDER BY
		[Valid From],
		[WWI Customer ID]

END;
GO
/****** Object:  StoredProcedure [Integration].[GetEmployeeUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







/*

EXEC [Integration].[GetEmployeeUpdatesNew] '1/1/2013', '1/1/2013'

*/
CREATE PROCEDURE [Integration].[GetEmployeeUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

	SELECT 
		[WWI Employee ID] = P.PersonID,
		[Employee] = P.FullName,
		[Preferred Name] = P.PreferredName,
		[Is Salesperson] = P.IsSalesperson,
		[Photo] = P.Photo,
		[Valid From] = P.ValidFrom,
		[Valid To] = P.ValidTo
	FROM 
		Application.People P 
	WHERE
		P.IsEmployee = 1 AND
		(
			P.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				P.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= P.ValidTo AND
		P.ValidFrom <= @NewCutoff

	UNION

	SELECT 
		[WWI Employee ID] = PA.PersonID,
		[Employee] = PA.FullName,
		[Preferred Name] = PA.PreferredName,
		[Is Salesperson] = PA.IsSalesperson,
		[Photo] = PA.Photo,
		[Valid From] = PA.ValidFrom,
		[Valid To] = PA.ValidTo
	FROM 
		Application.People_Archive PA
	WHERE
		PA.IsEmployee = 1 AND
		(
			PA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PA.ValidTo AND
		PA.ValidFrom <= @NewCutoff
	ORDER BY
		[Valid From],
		[WWI Employee ID]

END;
GO
/****** Object:  StoredProcedure [Integration].[GetMovementUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*

EXEC [Integration].[GetMovementUpdatesNew] '1/1/2013', '6/30/2013'

*/
CREATE PROCEDURE [Integration].[GetMovementUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

    SELECT 
		[Date Key] = CAST(SIT.TransactionOccurredWhen AS DATE),
        [WWI Stock Item Transaction ID] = SIT.StockItemTransactionID,
		[WWI Invoice ID] = SIT.InvoiceID,
		[WWI Purchase Order ID] = SIT.PurchaseOrderID,
		[Quantity] = CAST(SIT.Quantity AS INT),
		[WWI Stock Item ID] = SIT.StockItemID,
        [WWI Customer ID] = SIT.CustomerID,
        [WWI Supplier ID] = SIT.SupplierID,
        [WWI Transaction Type ID] = SIT.TransactionTypeID,
		[Transaction Occurred When] = SIT.TransactionOccurredWhen
    FROM 
		Warehouse.StockItemTransactions AS SIT
    WHERE 
		(
			SIT.LastEditedWhen > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				SIT.LastEditedWhen >= @NewCutoff
			)
		) AND
		SIT.LastEditedWhen <= @NewCutoff
    ORDER BY 
		SIT.StockItemTransactionID;

END;
GO
/****** Object:  StoredProcedure [Integration].[GetOrderUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







/*

EXEC [Integration].[GetOrderUpdatesNew] '1/1/2013', '1/2/2013'

*/
CREATE PROCEDURE [Integration].[GetOrderUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;
	
	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

	IF OBJECT_ID('tempdb..#PackageTypesChanges') IS NOT NULL 
		DROP TABLE #PackageTypesChanges

	IF OBJECT_ID('tempdb..#PackageTypes') IS NOT NULL 
		DROP TABLE #PackageTypes

	CREATE TABLE #PackageTypesChanges
	(
		PackageTypeID INT
	)

	CREATE TABLE #PackageTypes
	(
		PackageTypeID INT,
		PackageTypeName NVARCHAR(50)
	)

	INSERT INTO #PackageTypesChanges
	(
		PackageTypeID
	)
	SELECT
		PT.PackageTypeID
	FROM
		Warehouse.PackageTypes PT
	WHERE
		(
			PT.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PT.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PT.ValidTo AND
		PT.ValidFrom <= @NewCutoff

	UNION

	SELECT
		PTA.PackageTypeID
	FROM
		Warehouse.PackageTypes_Archive PTA
	WHERE
		(
			PTA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PTA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PTA.ValidTo AND
		PTA.ValidFrom <= @NewCutoff

	INSERT INTO #PackageTypes
	(
		PackageTypeID,
		PackageTypeName
	)
	SELECT
		PT.PackageTypeID,
		PT.PackageTypeName
	FROM
		Warehouse.PackageTypes PT
	WHERE
		@NewCutoff BETWEEN PT.ValidFrom AND PT.ValidTo
	
	UNION
	
	SELECT
		PTA.PackageTypeID,
		PTA.PackageTypeName
	FROM
		Warehouse.PackageTypes_Archive PTA
	WHERE
		@NewCutoff BETWEEN PTA.ValidFrom AND PTA.ValidTo

    SELECT 
		[Order Date Key] = CAST(O.OrderDate AS DATE),
		[Picked Date Key] = CAST(OL.PickingCompletedWhen AS DATE),
		[WWI Order ID] = O.OrderID,
		[WWI Backorder ID] = O.BackorderOrderID,
		[Description] = OL.[Description],
		[Package] = PT.PackageTypeName,
		[Quantity] = OL.Quantity,
		[Unit Price] = OL.UnitPrice,
		[Tax Rate] = OL.TaxRate,
		[Total Excluding Tax] = ROUND(OL.Quantity * OL.UnitPrice, 2),
		[Tax Amount] = ROUND((OL.Quantity * OL.UnitPrice * OL.TaxRate) / 100.0, 2),
		[Total Including Tax] = (
			ROUND(OL.Quantity * OL.UnitPrice, 2) + 
			ROUND((OL.Quantity * OL.UnitPrice * OL.TaxRate) / 100.0, 2)
		),

		[WWI City ID] = C.DeliveryCityID,
		[WWI Customer ID] = C.CustomerID,
		[WWI Stock Item ID] = OL.StockItemID,
		[WWI Salesperson ID] = O.SalespersonPersonID,
		[WWI Picker ID] = O.PickedByPersonID,
		[Last Modified When] = 
			CASE 
				WHEN OL.LastEditedWhen > O.LastEditedWhen THEN OL.LastEditedWhen 
				ELSE O.LastEditedWhen 
			END 
    FROM 
		Sales.Orders O JOIN 
		Sales.OrderLines OL ON 
			O.OrderID = OL.OrderID JOIN 
			#PackageTypes PT ON
				PT.PackageTypeID = OL.PackageTypeID JOIN
		Sales.Customers C ON 
			C.CustomerID = O.CustomerID
    WHERE 
		(
			O.LastEditedWhen > @LastCutoff OR
			OL.LastEditedWhen > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				(
					O.LastEditedWhen >= @NewCutoff OR
					OL.LastEditedWhen >= @NewCutoff
				)
			) OR
			OL.PackageTypeID IN (SELECT PackageTypeID FROM #PackageTypesChanges)
		) AND
		(
			O.LastEditedWhen <= @NewCutoff OR
			OL.LastEditedWhen <= @NewCutoff
		)
    ORDER BY 
		O.OrderID

END;
GO
/****** Object:  StoredProcedure [Integration].[GetPaymentMethodUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*

EXEC [Integration].[GetPaymentMethodUpdatesNew] '1/1/2013', '1/1/2013'

*/
CREATE PROCEDURE [Integration].[GetPaymentMethodUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

	SELECT
		[WWI Payment Method ID] = PM.PaymentMethodID,
		[Payment Method] = PM.PaymentMethodName,
		[Valid From] = PM.ValidFrom,
		[Valid To] = PM.ValidTo
	FROM
		Application.PaymentMethods PM
	WHERE 
		(
			PM.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PM.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PM.ValidTo AND
		PM.ValidFrom <= @NewCutoff

	UNION

	SELECT
		[WWI Payment Method ID] = PMA.PaymentMethodID,
		[Payment Method] = PMA.PaymentMethodName,
		[Valid From] = PMA.ValidFrom,
		[Valid To] = PMA.ValidTo
	FROM
		Application.PaymentMethods_Archive PMA
	WHERE 
		(
			PMA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PMA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PMA.ValidTo AND
		PMA.ValidFrom <= @NewCutoff

	ORDER BY
		[Valid From],
		[WWI Payment Method ID]

END;
GO
/****** Object:  StoredProcedure [Integration].[GetPurchaseUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






/*

EXEC [Integration].[GetPurchaseUpdatesNew] '1/1/2013', '1/1/2014'

*/
CREATE PROCEDURE [Integration].[GetPurchaseUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

	IF OBJECT_ID('tempdb..#PackageTypesChanges') IS NOT NULL 
		DROP TABLE #PackageTypesChanges

	IF OBJECT_ID('tempdb..#PackageTypes') IS NOT NULL 
		DROP TABLE #PackageTypes

	CREATE TABLE #PackageTypesChanges
	(
		PackageTypeID INT
	)

	CREATE TABLE #PackageTypes
	(
		PackageTypeID INT,
		PackageTypeName NVARCHAR(50)
	)

	INSERT INTO #PackageTypesChanges
	(
		PackageTypeID
	)
	SELECT
		PT.PackageTypeID
	FROM
		Warehouse.PackageTypes PT
	WHERE
		(
			PT.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PT.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PT.ValidTo AND
		PT.ValidFrom <= @NewCutoff

	UNION

	SELECT
		PTA.PackageTypeID
	FROM
		Warehouse.PackageTypes_Archive PTA
	WHERE
		(
			PTA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PTA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PTA.ValidTo AND
		PTA.ValidFrom <= @NewCutoff

	INSERT INTO #PackageTypes
	(
		PackageTypeID,
		PackageTypeName
	)
	SELECT
		PT.PackageTypeID,
		PT.PackageTypeName
	FROM
		Warehouse.PackageTypes PT
	WHERE
		@NewCutoff BETWEEN PT.ValidFrom AND PT.ValidTo
	
	UNION
	
	SELECT
		PTA.PackageTypeID,
		PTA.PackageTypeName
	FROM
		Warehouse.PackageTypes_Archive PTA
	WHERE
		@NewCutoff BETWEEN PTA.ValidFrom AND PTA.ValidTo

    SELECT 
		[Date Key] = CAST(PO.OrderDate AS date),
		[WWI Purchase Order ID] = PO.PurchaseOrderID,
		[Ordered Outers] = POL.OrderedOuters,
        [Ordered Quantity] = POL.OrderedOuters * SI.QuantityPerOuter,
        [Received Outers] = POL.ReceivedOuters,
        [Package] = PT.PackageTypeName,
        [Is Order Finalized] = POL.IsOrderLineFinalized,
        [WWI Supplier ID] = PO.SupplierID,
		[WWI Stock Item ID] = POL.StockItemID,
		[Last Modified When] =
			CASE 
				WHEN POL.LastEditedWhen > POL.LastEditedWhen THEN POL.LastEditedWhen 
				ELSE PO.LastEditedWhen 
			END
    FROM 
		Purchasing.PurchaseOrders PO JOIN 
		Purchasing.PurchaseOrderLines AS POL
			ON PO.PurchaseOrderID = POL.PurchaseOrderID JOIN 
		Warehouse.StockItems AS SI
			ON POL.StockItemID = SI.StockItemID JOIN 
		#PackageTypes AS PT
			ON POL.PackageTypeID = PT.PackageTypeID
    WHERE 
		(
			PO.LastEditedWhen > @LastCutoff OR
			POL.LastEditedWhen > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				(
					PO.LastEditedWhen >= @NewCutoff OR
					POL.LastEditedWhen >= @NewCutoff
				)
			) OR
			POL.PackageTypeID IN (SELECT PackageTypeID FROM #PackageTypesChanges)
		) AND
		(
			PO.LastEditedWhen <= @NewCutoff OR
			POL.LastEditedWhen <= @NewCutoff
		)
	ORDER BY
		PO.PurchaseOrderID
    
END;
GO
/****** Object:  StoredProcedure [Integration].[GetSaleUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




/*

EXEC [Integration].[GetSaleUpdatesNew] '6/30/2013', '1/1/2014'

*/
CREATE PROCEDURE [Integration].[GetSaleUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

	IF OBJECT_ID('tempdb..#PackageTypesChanges') IS NOT NULL 
		DROP TABLE #PackageTypesChanges

	IF OBJECT_ID('tempdb..#PackageTypes') IS NOT NULL 
		DROP TABLE #PackageTypes

	CREATE TABLE #PackageTypesChanges
	(
		PackageTypeID INT
	)

	CREATE TABLE #PackageTypes
	(
		PackageTypeID INT,
		PackageTypeName NVARCHAR(50)
	)

	INSERT INTO #PackageTypesChanges
	(
		PackageTypeID
	)
	SELECT
		PT.PackageTypeID
	FROM
		Warehouse.PackageTypes PT
	WHERE
		(
			PT.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PT.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PT.ValidTo AND
		PT.ValidFrom <= @NewCutoff

	UNION

	SELECT
		PTA.PackageTypeID
	FROM
		Warehouse.PackageTypes_Archive PTA
	WHERE
		(
			PTA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PTA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PTA.ValidTo AND
		PTA.ValidFrom <= @NewCutoff

	INSERT INTO #PackageTypes
	(
		PackageTypeID,
		PackageTypeName
	)
	SELECT
		PT.PackageTypeID,
		PT.PackageTypeName
	FROM
		Warehouse.PackageTypes PT
	WHERE
		@NewCutoff BETWEEN PT.ValidFrom AND PT.ValidTo
	
	UNION
	
	SELECT
		PTA.PackageTypeID,
		PTA.PackageTypeName
	FROM
		Warehouse.PackageTypes_Archive PTA
	WHERE
		@NewCutoff BETWEEN PTA.ValidFrom AND PTA.ValidTo

    SELECT 
		[Invoice Date Key] = CAST(I.InvoiceDate AS date),
        [Delivery Date Key] = CAST(I.ConfirmedDeliveryTime AS date),
        [WWI Invoice ID] = I.InvoiceID,
		[WWI Invoice Line ID] = IL.[InvoiceLineID],
        [Description] = IL.[Description],
        [Package] = PT.PackageTypeName,
        [Quantity] = IL.Quantity,
        [Unit Price] = IL.UnitPrice,
        [Tax Rate] = IL.TaxRate,
        [Total Excluding Tax] = IL.ExtendedPrice - IL.TaxAmount,
        [Tax Amount] = IL.TaxAmount,
        [Profit] = IL.LineProfit,
        [Total Including Tax] = IL.ExtendedPrice,
		[Total Dry Items] = 
			CASE 
				WHEN SI.IsChillerStock = 0 THEN IL.Quantity 
				ELSE 0 
			END,
		[Total Chiller Items] =
			CASE 
				WHEN SI.IsChillerStock <> 0 THEN IL.Quantity 
				ELSE 0 
			END,
        [WWI City ID] = C.DeliveryCityID,
        [WWI Customer ID] = I.CustomerID,
        [WWI Bill To Customer ID] = I.BillToCustomerID,
        [WWI Stock Item ID] = IL.StockItemID,
        [WWI Saleperson ID] = I.SalespersonPersonID,
		[Last Modified When] = 
			CASE 
				WHEN IL.LastEditedWhen > I.LastEditedWhen THEN IL.LastEditedWhen 
				ELSE I.LastEditedWhen 
			END 
    FROM 
		Sales.Invoices I JOIN 
		Sales.InvoiceLines IL ON 
			I.InvoiceID = IL.InvoiceID JOIN 
		Warehouse.StockItems SI ON 
			IL.StockItemID = SI.StockItemID JOIN 
		#PackageTypes PT ON 
			IL.PackageTypeID = PT.PackageTypeID JOIN 
		Sales.Customers C ON 
			I.CustomerID = C.CustomerID JOIN 
		Sales.Customers BT ON 
			I.BillToCustomerID = BT.CustomerID
    WHERE 
		(
			
			I.LastEditedWhen > @LastCutoff OR
			IL.LastEditedWhen > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				(
					I.LastEditedWhen >= @NewCutoff OR
					IL.LastEditedWhen >= @NewCutoff
				)
			) OR
			IL.PackageTypeID IN (SELECT PackageTypeID FROM #PackageTypesChanges)
		) AND
		(
			I.LastEditedWhen <= @NewCutoff OR
			IL.LastEditedWhen <= @NewCutoff 
		)
    ORDER BY 
		I.InvoiceID, 
		IL.InvoiceLineID;

END;
GO
/****** Object:  StoredProcedure [Integration].[GetStockHoldingUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [Integration].[GetStockHoldingUpdatesNew]
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SELECT 
		[Quantity On Hand] = SIH.QuantityOnHand,
        [Bin Location] = SIH.BinLocation,
        [Last Stocktake Quantity] = SIH.LastStocktakeQuantity,
        [Last Cost Price] = SIH.LastCostPrice,
        [Reorder Level] = SIH.ReorderLevel,
        [Target Stock Level] = SIH.TargetStockLevel,
        [WWI Stock Item ID] = sih.StockItemID
    FROM 
		Warehouse.StockItemHoldings SIH
    ORDER BY 
		SIH.StockItemID;

END;
GO
/****** Object:  StoredProcedure [Integration].[GetStockItemUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





/*

EXEC [Integration].[GetStockItemUpdatesNew] '1/1/2013', '1/1/2013'

*/
CREATE PROCEDURE [Integration].[GetStockItemUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

	IF OBJECT_ID('tempdb..#StockItemsFinal') IS NOT NULL 
		DROP TABLE #StockItemsFinal
	
	IF OBJECT_ID('tempdb..#PackageTypesChanges') IS NOT NULL 
		DROP TABLE #PackageTypesChanges

	IF OBJECT_ID('tempdb..#ColorChanges') IS NOT NULL 
		DROP TABLE #ColorChanges

	IF OBJECT_ID('tempdb..#PackageTypes') IS NOT NULL 
		DROP TABLE #PackageTypes

	IF OBJECT_ID('tempdb..#Colors') IS NOT NULL 
		DROP TABLE #Colors

	CREATE TABLE #StockItemsFinal
    (
        [WWI Stock Item ID] int,
        [Stock Item] nvarchar(100),
		[Color ID] int,
        [Color] nvarchar(20),
		[Selling Package ID] int,
        [Selling Package] nvarchar(50),
        [Buying Package ID] int,
		[Buying Package] nvarchar(50),
        [Brand] nvarchar(50),
        [Size] nvarchar(20),
        [Lead Time Days] int,
        [Quantity Per Outer] int,
        [Is Chiller Stock] bit,
        [Barcode] nvarchar(50),
        [Tax Rate] decimal(18,3),
        [Unit Price] decimal(18,2),
        [Recommended Retail Price] decimal(18,2),
        [Typical Weight Per Unit] decimal(18,3),
        [Photo] varbinary(max),
        [Valid From] datetime2(7),
        [Valid To] datetime2(7)
    )

	-- Table for package types changes
	CREATE TABLE #PackageTypesChanges
	(
		PackageTypeID INT,
		ValidFrom DATETIME2(7),
		ValidTo DATETIME2(7)
	)

	-- Table for color changes
	CREATE TABLE #ColorChanges
	(
		ColorID INT,
		ValidFrom DATETIME2(7),
		ValidTo DATETIME2(7)
	)

	-- Table for stock items changes
	CREATE TABLE #StockItemsChanges
	(
		StockItemID INT,
		ValidFrom DATETIME2(7),
		ValidTo DATETIME2(7)
	)

	-- Table for package types used selection
	CREATE TABLE #PackageTypes
	(
		PackageTypeID INT,
		PackageTypeName NVARCHAR(50)
	)

	-- Table for colors used selection
	CREATE TABLE #Colors
	(
		ColorID INT,
		ColorName NVARCHAR(50)
	)
	
	-- Populate package type changes table
	INSERT INTO #PackageTypesChanges
	(
		PackageTypeID,
		ValidFrom,
		ValidTo
	)
	SELECT
		PT.PackageTypeID,
		PT.ValidFrom,
		PT.ValidTo
	FROM
		Warehouse.PackageTypes PT
	WHERE
		(
			PT.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PT.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PT.ValidTo AND
		PT.ValidFrom <= @NewCutoff

	UNION

	SELECT
		PTA.PackageTypeID,
		PTA.ValidFrom,
		PTA.ValidTo
	FROM
		Warehouse.PackageTypes_Archive PTA
	WHERE
		(
			PTA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PTA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PTA.ValidTo AND
		PTA.ValidFrom <= @NewCutoff

	-- Populate color changes table
	INSERT INTO #ColorChanges
	(
		ColorID,
		ValidFrom,
		ValidTo
	)
	SELECT
		C.ColorID,
		C.ValidFrom,
		C.ValidTo
	FROM
		Warehouse.Colors C
	WHERE
		(
			C.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				C.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= C.ValidTo AND
		C.ValidFrom <= @NewCutoff

	UNION

	SELECT
		CA.ColorID,
		CA.ValidFrom,
		CA.ValidTo
	FROM
		Warehouse.Colors_Archive CA
	WHERE
		(
			CA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				CA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= CA.ValidTo AND
		CA.ValidFrom <= @NewCutoff

	-- Populate package types by new cut off date
	INSERT INTO #PackageTypes
	(
		PackageTypeID,
		PackageTypeName
	)
	SELECT
		PT.PackageTypeID,
		PT.PackageTypeName
	FROM
		Warehouse.PackageTypes PT
	WHERE
		@NewCutoff BETWEEN PT.ValidFrom AND PT.ValidTo
	
	UNION
	
	SELECT
		PTA.PackageTypeID,
		PTA.PackageTypeName
	FROM
		Warehouse.PackageTypes_Archive PTA
	WHERE
		@NewCutoff BETWEEN PTA.ValidFrom AND PTA.ValidTo

	-- Populate package types by new cut off date
	INSERT INTO #Colors
	(
		ColorID,
		ColorName
	)
	SELECT
		C.ColorID,
		C.ColorName
	FROM
		Warehouse.Colors C
	WHERE
		@NewCutoff BETWEEN C.ValidFrom AND C.ValidTo
	
	UNION
	
	SELECT
		CA.ColorID,
		CA.ColorName
	FROM
		Warehouse.Colors_Archive CA
	WHERE
		@NewCutoff BETWEEN CA.ValidFrom AND CA.ValidTo

	-- Insert to final table
	INSERT INTO #StockItemsFinal
    (
        [WWI Stock Item ID],
        [Stock Item],
        [Color ID],
		[Color],
        [Selling Package ID],
		[Selling Package],
        [Buying Package ID],
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
        [Photo],
        [Valid From],
        [Valid To]
    )
	SELECT 
		SI.StockItemID, 
		SI.StockItemName,
		SI.ColorID,
		C.ColorName,
		SI.UnitPackageID,
		SPT.PackageTypeName,
		SI.OuterPackageID,
        BPT.PackageTypeName, 
		SI.Brand, 
		SI.Size, 
		SI.LeadTimeDays, 
		SI.QuantityPerOuter,
        SI.IsChillerStock, 
		SI.Barcode, 
		SI.TaxRate, 
		SI.UnitPrice, 
		SI.RecommendedRetailPrice,
        SI.TypicalWeightPerUnit, 
		SI.Photo, 
		SI.ValidFrom, 
		SI.ValidTo
	FROM 
		Warehouse.StockItems SI JOIN 
		#PackageTypes SPT ON
			SI.UnitPackageID = SPT.PackageTypeID JOIN 
		#PackageTypes BPT ON 
			SI.OuterPackageID = BPT.PackageTypeID LEFT JOIN 
		#Colors C ON 
			SI.ColorID = C.ColorID
	WHERE 
		(
			SI.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				SI.ValidFrom >= @LastCutoff
			) OR
			EXISTS 
			(
				SELECT 
					1 
				FROM 
					#PackageTypesChanges PTC
				WHERE 
					PTC.PackageTypeID IN (SI.UnitPackageID, SI.OuterPackageID) AND
					PTC.ValidFrom BETWEEN SI.ValidFrom AND SI.ValidTo
			) OR
			EXISTS 
			(
				SELECT 
					1 
				FROM 
					#ColorChanges CC
				WHERE 
					CC.ColorID = SI.ColorID AND
					CC.ValidFrom BETWEEN SI.ValidFrom AND SI.ValidTo
			)
		) AND
		SI.ValidFrom <= @NewCutoff AND
		@NewCutoff <= SI.ValidTo

	INSERT INTO #StockItemsFinal
    (
        [WWI Stock Item ID],
        [Stock Item],
        [Color ID],
		[Color],
        [Selling Package ID],
		[Selling Package],
        [Buying Package ID],
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
        [Photo],
        [Valid From],
        [Valid To]
    )
	SELECT 
		SIA.StockItemID, 
		SIA.StockItemName,
		SIA.ColorID,
		C.ColorName,
		SIA.UnitPackageID,
		SPT.PackageTypeName,
		SIA.OuterPackageID,
        BPT.PackageTypeName, 
		SIA.Brand, 
		SIA.Size, 
		SIA.LeadTimeDays, 
		SIA.QuantityPerOuter,
        SIA.IsChillerStock, 
		SIA.Barcode, 
		SIA.TaxRate,
		SIA.UnitPrice, 	
		SIA.RecommendedRetailPrice,
        SIA.TypicalWeightPerUnit, 
		SIA.Photo, 
		SIA.ValidFrom, 
		SIA.ValidTo
	FROM 
		Warehouse.StockItems_Archive SIA JOIN 
		#PackageTypes SPT ON
			SIA.UnitPackageID = SPT.PackageTypeID JOIN 
		#PackageTypes BPT ON 
			SIA.OuterPackageID = BPT.PackageTypeID LEFT JOIN 
		#Colors C ON 
			SIA.ColorID = C.ColorID
	WHERE
		NOT EXISTS
		(
			SELECT
				1
			FROM
				#StockItemsFinal SIF 
			WHERE
				SIF.[WWI Stock Item ID] = SIA.StockItemID
		) AND
		(
			SIA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				SIA.ValidFrom >= @LastCutoff
			) OR
			EXISTS 
			(
				SELECT 
					1 
				FROM 
					#PackageTypesChanges PTC
				WHERE 
					PTC.PackageTypeID IN (SIA.UnitPackageID, SIA.OuterPackageID) AND
					PTC.ValidFrom BETWEEN SIA.ValidFrom AND SIA.ValidTo
			) OR
			EXISTS 
			(
				SELECT 
					1 
				FROM 
					#ColorChanges CC
				WHERE 
					CC.ColorID = SIA.ColorID AND
					CC.ValidFrom BETWEEN SIA.ValidFrom AND SIA.ValidTo
			)
		) AND
		SIA.ValidFrom <= @NewCutoff AND
		@NewCutoff <= SIA.ValidTo

	SELECT
		SIF.[WWI Stock Item ID],
        SIF.[Stock Item],
        [Color] = ISNULL(SIF.[Color], ''),
        SIF.[Selling Package],
        SIF.[Buying Package],
        [Brand] = ISNULL(SIF.[Brand], ''),
        [Size] = ISNULL(SIF.[Size], ''),
        SIF.[Lead Time Days],
        SIF.[Quantity Per Outer],
        SIF.[Is Chiller Stock],
        SIF.[Barcode],
        SIF.[Tax Rate],
        SIF.[Unit Price],
        SIF.[Recommended Retail Price],
        SIF.[Typical Weight Per Unit],
        SIF.[Photo],
        [Valid From] =
			CASE 
				WHEN 
					SIF.[Valid From] <= ISNULL(PTC.ValidFrom, SIF.[Valid From]) AND 
					SIF.[Valid From] <= ISNULL(PTC2.ValidFrom, SIF.[Valid From]) AND 
					SIF.[Valid From] <= ISNULL(CC.ValidFrom, SIF.[Valid From])
					THEN SIF.[Valid From]
				WHEN 
					ISNULL(PTC.ValidFrom, SIF.[Valid From]) <= SIF.[Valid From] AND
					ISNULL(PTC.ValidFrom, SIF.[Valid From]) <= ISNULL(PTC2.ValidFrom, SIF.[Valid From]) AND
					ISNULL(PTC.ValidFrom, SIF.[Valid From]) <= ISNULL(CC.ValidFrom, SIF.[Valid From])
					THEN ISNULL(PTC.ValidFrom, SIF.[Valid From])
				WHEN 
					ISNULL(PTC2.ValidFrom, SIF.[Valid From]) <= SIF.[Valid From] AND
					ISNULL(PTC2.ValidFrom, SIF.[Valid From]) <= ISNULL(PTC.ValidFrom, SIF.[Valid From]) AND
					ISNULL(PTC2.ValidFrom, SIF.[Valid From]) <= ISNULL(CC.ValidFrom, SIF.[Valid From])
					THEN ISNULL(PTC2.ValidFrom, SIF.[Valid From])
				ELSE
					ISNULL(CC.ValidFrom, SIF.[Valid From])
			END,
        [Valid To] = 
			CASE 
				WHEN 
					SIF.[Valid To] >= ISNULL(PTC.ValidTo, SIF.[Valid To]) AND 
					SIF.[Valid To] >= ISNULL(PTC2.ValidTo, SIF.[Valid To]) AND 
					SIF.[Valid To] >= ISNULL(CC.ValidTo, SIF.[Valid To])
					THEN SIF.[Valid To]
				WHEN 
					ISNULL(PTC.ValidTo, SIF.[Valid To]) >= SIF.[Valid To] AND
					ISNULL(PTC.ValidTo, SIF.[Valid To]) >= ISNULL(CC.ValidTo, SIF.[Valid To])
					THEN ISNULL(PTC.ValidTo, SIF.[Valid To])
				ELSE
					ISNULL(CC.ValidTo, SIF.[Valid To])
			END
	FROM
		#StockItemsFinal SIF LEFT JOIN
		#PackageTypesChanges PTC ON
			PTC.PackageTypeID = SIF.[Buying Package ID] LEFT JOIN
		#PackageTypesChanges PTC2 ON
			PTC2.PackageTypeID = SIF.[Selling Package ID] LEFT JOIN
		#ColorChanges CC ON
			CC.ColorID = SIF.[Color ID]
	ORDER BY
		SIF.[Valid From],
		SIF.[WWI Stock Item ID]
    
END;
GO
/****** Object:  StoredProcedure [Integration].[GetSupplierUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/*

EXEC [Integration].[GetSupplierUpdatesNew] '1/1/2013', '1/1/2015'

*/
CREATE PROCEDURE [Integration].[GetSupplierUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

	IF OBJECT_ID('tempdb..#SuppliersFinal') IS NOT NULL 
		DROP TABLE #SuppliersFinal

	IF OBJECT_ID('tempdb..#SupplierCategoriesChanges') IS NOT NULL 
		DROP TABLE #SupplierCategoriesChanges

	IF OBJECT_ID('tempdb..#PrimaryContactPersonChanges') IS NOT NULL 
		DROP TABLE #PrimaryContactPersonChanges

	IF OBJECT_ID('tempdb..#SupplierCategories') IS NOT NULL 
		DROP TABLE #SupplierCategories

	IF OBJECT_ID('tempdb..#PrimaryContactPersons') IS NOT NULL 
		DROP TABLE #PrimaryContactPersons

	-- Table for suppliers for all changes: suppliers, supplier categories and primary contact
	CREATE TABLE #SuppliersFinal
    (
        [WWI Supplier ID] INT,
        [Supplier] NVARCHAR(100),
		[Category ID] INT,
        [Category] NVARCHAR(50),
		[Primary Contact ID] INT,
        [Primary Contact] NVARCHAR(50),
        [Supplier Reference] NVARCHAR(20),
        [Payment Days] INT,
        [Postal Code] NVARCHAR(10),
        [Valid From] DATETIME2(7),
        [Valid To] DATETIME2(7)
    )

	-- Table for supplier categories changes
	CREATE TABLE #SupplierCategoriesChanges
	(
		SupplierCategoryID INT,
		ValidFrom DATETIME2(7),
		ValidTo DATETIME2(7)
	)

	-- Table for primary contact person changes
	CREATE TABLE #PrimaryContactPersonChanges
	(
		PrimaryContactPersonID INT,
		ValidFrom DATETIME2(7),
		ValidTo DATETIME2(7)
	)

	-- Table for supplier categories 
	CREATE TABLE #SupplierCategories
	(
		SupplierCategoryID INT,
		SupplierCategoryName NVARCHAR(50)
	)

	-- Table for primary contact persons
	CREATE TABLE #PrimaryContactPersons
	(
		PrimaryContactPersonID INT,
		PrimaryContactPersonName NVARCHAR(50)
	)

	-- Populate the supplier categories changes table
	INSERT INTO #SupplierCategoriesChanges
	(
		SupplierCategoryID,
		ValidFrom,
		ValidTo
	)
	SELECT
		SC.SupplierCategoryID,
		SC.ValidFrom,
		SC.ValidTo
	FROM
		Purchasing.SupplierCategories SC
	WHERE
		(
			SC.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				SC.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= SC.ValidTo AND
		SC.ValidFrom <= @NewCutoff 
		
	UNION

	SELECT
		SCA.SupplierCategoryID,
		SCA.ValidFrom,
		SCA.ValidTo
	FROM
		Purchasing.SupplierCategories_Archive SCA
	WHERE
		(
			SCA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				SCA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= SCA.ValidTo AND
		SCA.ValidFrom <= @NewCutoff

	-- Populate the primary contact person changes table
	INSERT INTO #PrimaryContactPersonChanges
	(
		PrimaryContactPersonID,
		ValidFrom,
		ValidTo
	)
	SELECT
		P.PersonID,
		P.ValidFrom,
		P.ValidTo
	FROM
		Application.People P 
	WHERE
		(
			P.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				P.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= P.ValidTo AND
		P.ValidFrom <= @NewCutoff 

	UNION

	SELECT
		PA.PersonID,
		PA.ValidFrom,
		PA.ValidTo
	FROM
		Application.People_Archive PA 
	WHERE
		(
			PA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				PA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= PA.ValidTo AND
		PA.ValidFrom <= @NewCutoff 
	
	-- Populate supplier categories table to be used in the final table
	INSERT INTO #SupplierCategories
	(
		SupplierCategoryID,
		SupplierCategoryName
	)
	SELECT 
		SC.SupplierCategoryID,
		SC.SupplierCategoryName
	FROM
		Purchasing.SupplierCategories SC
	WHERE
		@NewCutoff BETWEEN SC.ValidFrom AND SC.ValidTo

	UNION

	SELECT 
		SCA.SupplierCategoryID,
		SCA.SupplierCategoryName
	FROM
		Purchasing.SupplierCategories_Archive SCA
	WHERE
		@NewCutoff BETWEEN SCA.ValidFrom AND SCA.ValidTo

	-- Populate primary contact persons table to be used in the final table
	INSERT INTO #PrimaryContactPersons
	(
		PrimaryContactPersonID,
		PrimaryContactPersonName
	)
	SELECT
		P.PersonID,
		P.FullName
	FROM
		Application.People P
	WHERE
		@NewCutoff BETWEEN P.ValidFrom AND P.ValidTo

	UNION

	SELECT
		PA.PersonID,
		PA.FullName
	FROM
		Application.People_Archive PA
	WHERE
		@NewCutoff BETWEEN PA.ValidFrom AND PA.ValidTo

	-- Populate the suppliers final table from the main table
	INSERT INTO #SuppliersFinal
	(
		[WWI Supplier ID],
        [Supplier],
		[Category ID],
        [Category],
		[Primary Contact ID],
        [Primary Contact],
        [Supplier Reference],
        [Payment Days],
        [Postal Code],
        [Valid From],
        [Valid To]
	)
	SELECT 
		S.SupplierID, 
		S.SupplierName, 
		S.SupplierCategoryID,
		SC.SupplierCategoryName, 
		S.PrimaryContactPersonID,
		PCP.PrimaryContactPersonName, 
		S.SupplierReference,
        S.PaymentDays, 
		S.DeliveryPostalCode, 
		S.ValidFrom, 
		S.ValidTo
	FROM 
		Purchasing.Suppliers S JOIN 
		#SupplierCategories SC
			ON S.SupplierCategoryID = SC.SupplierCategoryID JOIN 
		#PrimaryContactPersons PCP
			ON S.PrimaryContactPersonID = PCP.PrimaryContactPersonID
	WHERE 
		(
			S.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				S.ValidFrom >= @LastCutoff
			) OR
			EXISTS 
			(
				SELECT 
					1 
				FROM 
					#SupplierCategoriesChanges SCC
				WHERE 
					SCC.SupplierCategoryID = S.SupplierCategoryID AND
					SCC.ValidFrom BETWEEN S.ValidFrom AND S.ValidTo
			) OR
			EXISTS 
			(
				SELECT 
					1 
				FROM 
					#PrimaryContactPersonChanges PCPC
				WHERE 
					PCPC.PrimaryContactPersonID = S.PrimaryContactPersonID AND
					PCPC.ValidFrom BETWEEN S.ValidFrom AND S.ValidTo
			)
		) AND
		S.ValidFrom <= @NewCutoff AND
		@NewCutoff <= S.ValidTo

	-- Populate the suppliers final table from the archive table
	INSERT INTO #SuppliersFinal
	(
		[WWI Supplier ID],
        [Supplier],
		[Category ID],
        [Category],
		[Primary Contact ID],
        [Primary Contact],
        [Supplier Reference],
        [Payment Days],
        [Postal Code],
        [Valid From],
        [Valid To]
	)
	SELECT 
		SA.SupplierID, 
		SA.SupplierName, 
		SA.SupplierCategoryID,
		SC.SupplierCategoryName, 
		SA.PrimaryContactPersonID,
		PCP.PrimaryContactPersonName, 
		SA.SupplierReference,
        SA.PaymentDays, 
		SA.DeliveryPostalCode, 
		SA.ValidFrom, 
		SA.ValidTo
	FROM 
		Purchasing.Suppliers_Archive SA JOIN 
		#SupplierCategories SC
			ON SA.SupplierCategoryID = SC.SupplierCategoryID JOIN 
		#PrimaryContactPersons PCP
			ON SA.PrimaryContactPersonID = PCP.PrimaryContactPersonID
	WHERE 
		NOT EXISTS
		(
			SELECT
				1
			FROM
				#SuppliersFinal SF
			WHERE
				SF.[WWI Supplier ID] = SA.SupplierID
		) AND
		(
			SA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				SA.ValidFrom >= @LastCutoff
			) OR
			EXISTS 
			(
				SELECT 
					1 
				FROM 
					#SupplierCategoriesChanges SCC
				WHERE 
					SCC.SupplierCategoryID = SA.SupplierCategoryID AND
					SCC.ValidFrom BETWEEN SA.ValidFrom AND SA.ValidTo
			) OR
			EXISTS 
			(
				SELECT 
					1 
				FROM 
					#PrimaryContactPersonChanges PCPC
				WHERE 
					PCPC.PrimaryContactPersonID = SA.PrimaryContactPersonID AND
					PCPC.ValidFrom BETWEEN SA.ValidFrom AND SA.ValidTo
			)
		) AND
		SA.ValidFrom <= @NewCutoff AND
		@NewCutoff <= SA.ValidTo
	
	-- Select the suppliers final table
	SELECT 
		SF.[WWI Supplier ID],
        SF.[Supplier],
		SF.[Category],
		SF.[Primary Contact],
        SF.[Supplier Reference],
        SF.[Payment Days],
        SF.[Postal Code],
        [Valid From] = 
			CASE
				WHEN 
					SF.[Valid From] <= ISNULL(SCC.ValidFrom, SF.[Valid From]) AND
					SF.[Valid From] <= ISNULL(PCPC.ValidFrom, SF.[Valid From])
					THEN SF.[Valid From]

				WHEN 
					ISNULL(SCC.ValidFrom, SF.[Valid From]) <= SF.[Valid From] AND
					ISNULL(SCC.ValidFrom, SF.[Valid From]) <= ISNULL(PCPC.ValidFrom, SF.[Valid From])
					THEN ISNULL(SCC.ValidFrom, SF.[Valid From])
				ELSE
					ISNULL(PCPC.ValidFrom, SF.[Valid From])
			END,
        [Valid To] = 
			CASE
				WHEN 
					SF.[Valid To] >= ISNULL(SCC.ValidTo, SF.[Valid To]) AND
					SF.[Valid To] >= ISNULL(PCPC.ValidTo, SF.[Valid To])
					THEN SF.[Valid To]

				WHEN 
					ISNULL(SCC.ValidTo, SF.[Valid To]) >= SF.[Valid To] AND
					ISNULL(SCC.ValidTo, SF.[Valid To]) >= ISNULL(PCPC.ValidTo, SF.[Valid To])
					THEN ISNULL(SCC.ValidTo, SF.[Valid To])
				ELSE
					ISNULL(PCPC.ValidTo, SF.[Valid To])
			END
	FROM
		#SuppliersFinal SF LEFT JOIN
		#SupplierCategoriesChanges SCC ON
			SCC.SupplierCategoryID = SF.[Category ID] LEFT JOIN
		#PrimaryContactPersonChanges PCPC ON
			PCPC.PrimaryContactPersonID = SF.[Primary Contact ID]
	ORDER BY
		[Valid From],
		SF.[WWI Supplier ID]
	
END;
GO
/****** Object:  StoredProcedure [Integration].[GetTransactionTypeUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*

EXEC [Integration].[GetTransactionTypeUpdatesNew] '1/1/2013', '1/1/2013'

*/
CREATE PROCEDURE [Integration].[GetTransactionTypeUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

	SELECT
		[WWI Transaction Type ID] = TT.TransactionTypeID,
        [Transaction Type] = TT.TransactionTypeName,
        [Valid From] = TT.ValidFrom,
        [Valid To] = TT.ValidTo
	FROM
		[Application].TransactionTypes TT 
	WHERE
		(
			TT.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				TT.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= TT.ValidTo AND
		TT.ValidFrom <= @NewCutoff

	UNION

	SELECT
		[WWI Transaction Type ID] = TTA.TransactionTypeID,
        [Transaction Type] = TTA.TransactionTypeName,
        [Valid From] = TTA.ValidFrom,
        [Valid To] = TTA.ValidTo
	FROM
		[Application].TransactionTypes_Archive TTA
	WHERE
		(
			TTA.ValidFrom > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				TTA.ValidFrom >= @NewCutoff
			)
		) AND
		@NewCutoff <= TTA.ValidTo AND
		TTA.ValidFrom <= @NewCutoff

	ORDER BY
		[Valid From],
		[WWI Transaction Type ID]

END;
GO
/****** Object:  StoredProcedure [Integration].[GetTransactionUpdatesNew]    Script Date: 6/3/2025 11:50:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*

EXEC [Integration].[GetTransactionUpdatesNew] '1/1/2013', '1/1/2014'

*/
CREATE PROCEDURE [Integration].[GetTransactionUpdatesNew]
(
	@LastCutoff datetime2(7),
	@NewCutoff datetime2(7)
)
WITH EXECUTE AS OWNER
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	DECLARE @InitialLoad DATE = '01/01/2013'

	IF @LastCutoff IS NULL
		SET @LastCutoff = @InitialLoad

    SELECT 
		[Date Key] = CAST(CT.TransactionDate AS DATE),
		[WWI Customer Transaction ID] = CT.CustomerTransactionID,
        [WWI Supplier Transaction ID] = CAST(NULL AS INT),
        [WWI Invoice ID] = CT.InvoiceID,
        [WWI Purchase Order ID] = CAST(NULL AS int),
        [Supplier Invoice Number] = CAST(NULL AS nvarchar(20)),
        [Total Excluding Tax] = CT.AmountExcludingTax,
        [Tax Amount] = CT.TaxAmount,
        [Total Including Tax] = CT.TransactionAmount,
        [Outstanding Balance] = CT.OutstandingBalance,
        [Is Finalized] = CT.IsFinalized,
        [WWI Customer ID] = COALESCE(I.CustomerID, CT.CustomerID),
        [WWI Bill To Customer ID] = CT.CustomerID,
        [WWI Supplier ID] = CAST(NULL AS INT),
        [WWI Transaction Type ID] = CT.TransactionTypeID,
        [WWI Payment Method ID] = CT.PaymentMethodID,
        [Last Modified When] = CT.LastEditedWhen
    FROM 
		Sales.CustomerTransactions CT LEFT JOIN 
		Sales.Invoices I ON 
			CT.InvoiceID = I.InvoiceID
    WHERE 
		(
			CT.LastEditedWhen > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				CT.LastEditedWhen >= @NewCutoff
			)
		) AND
		CT.LastEditedWhen <= @NewCutoff
		
    UNION ALL

    SELECT 
		[Date Key] = CAST(st.TransactionDate AS DATE),
        [WWI Customer Transaction ID] = CAST(NULL AS INT),
        [WWI Supplier Transaction ID] = ST.SupplierTransactionID,
        [WWI Invoice ID] = CAST(NULL AS INT),
        [WWI Purchase Order ID] = ST.PurchaseOrderID,
        [Supplier Invoice Number] = ST.SupplierInvoiceNumber,
        [Total Excluding Tax] = ST.AmountExcludingTax,
        [Tax Amount] = ST.TaxAmount,
        [Total Including Tax] = ST.TransactionAmount,
        [Outstanding Balance] = ST.OutstandingBalance,
        [Is Finalized] = ST.IsFinalized,
        [WWI Customer ID] = CAST(NULL AS INT),
        [WWI Bill To Customer ID] = CAST(NULL AS INT),
        [WWI Supplier ID] = ST.SupplierID,
        [WWI Transaction Type ID] = ST.TransactionTypeID,
        [WWI Payment Method ID] = ST.PaymentMethodID,
        [Last Modified When] = ST.LastEditedWhen 
    FROM 
		Purchasing.SupplierTransactions ST
    WHERE 
		(
			ST.LastEditedWhen > @LastCutoff OR
			(
				@NewCutoff = @InitialLoad AND
				ST.LastEditedWhen >= @NewCutoff
			)
		) AND
		ST.LastEditedWhen <= @NewCutoff


END;
GO
