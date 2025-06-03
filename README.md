This is an attempt of improvement of the existing WideWorldImportersDW ETL workflow found here: https://learn.microsoft.com/en-us/sql/samples/wide-world-importers-perform-etl?view=sql-server-ver17

These improvement mainly addreses the following: 
  - Improvements on stored procedures to not use cursors and duplicates
  - Remove the relevance of lineage key by not adding new data every ran.  Rather, warehouse data is updated and only new ones are added.

These are the changes on this workflow:
  - In the WideWorldImporters database, I've added new stored procedures for getting the updates for performance and readability (just my preference).  I've added stored procedures with "new" suffixes:
      Integration.GetCityUpdatesNew
      Integration.GetCustomerUpdatesNew
      Integration.GetEmployeeUpdatesNew
      Integration.GetMovementUpdatesNew
      Integration.GetOrderUpdatesNew
      Integration.GetPaymentMethodUpdatesNew
      Integration.GetPurchaseUpdatesNew
      Integration.GetSaleUpdatesNew
      Integration.GetStockHoldingUpdatesNew
      Integration.GetStockItemUpdatesNew
      Integration.GetSupplierUpdatesNew
      Integration.GetTransactionTypeUpdatesNew
      Integration.GetTransactionUpdatesNew
  - In the WideWorldImportersDW database, I've added new stored procedures for migrating staging data to the actual tables.  This new stored procedures are  I've added stored procedures with "new" suffixes:
      Integration.MigrateStagedCityDataNew
      Integration.MigrateStagedCustomerDataNew
      Integration.MigrateStagedEmployeeDataNew
      Integration.MigrateStagedMovementDataNew
      Integration.MigrateStagedOrderDataNew
      Integration.MigrateStagedPaymentMethodDataNew
      Integration.MigrateStagedPurchaseDataNew
      Integration.MigrateStagedSaleDataNew
      Integration.MigrateStagedStockHoldingDataNew
      Integration.MigrateStagedStockItemDataNew
      Integration.MigrateStagedSupplierDataNew
      Integration.MigrateStagedTransactionDataNew
      Integration.MigrateStagedTransactionTypeDataNew
      Integration.PopulateDateDimensionForYearNew
      Integration.GetLastETLCutoffTimeNew
  - Also in the WideWorldImportersDW database, added WWI Invoice Line ID column in Fact.sale table
  - In the SSIS project, the following are the changes:
      * Added configuration to set the new cutoff data: User::ConfiguredTargetETLCutoffTime.  The initial date must start at 1/1/2013
      * If you want to migrate data at a certain date, just update the User::ConfiguredTargetETLCutoffTime after 1/1/2013 and so on
      * If you want to migrate data by using the current date just configure the date to before 1/1/2013 say 12/31/2012, and it should use the system time.
  - To validate data, you may use the Data Validation.sql, just update the @NewCutoff date to the configured date in the SSIS project

For the source database, it is located here: https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
![image](https://github.com/user-attachments/assets/5e0fdfe9-f2f8-42f2-b9b8-0f3f6383aca0)
Add the stored procedures using the WideWorldImportersSPUpdates.sql file

For the destination database, please use this WideWorldImportersDW.sql file to create new database

