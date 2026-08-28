USE DataWarehouse;
GO

-- 1. Check whether procedure exists
SELECT
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS ProcedureName,
    create_date,
    modify_date
FROM sys.procedures
WHERE name = 'load_bronze'
  AND schema_id = SCHEMA_ID('bronze');

-- 2. Execute Bronze Load
EXEC bronze.load_bronze;
GO

-- 3. Verify rows AFTER loading
SELECT 'crm_cust_info' AS TableName, COUNT(*) AS RowCount
FROM bronze.crm_cust_info

UNION ALL

SELECT 'crm_prd_info', COUNT(*)
FROM bronze.crm_prd_info

UNION ALL

SELECT 'crm_sales_details', COUNT(*)
FROM bronze.crm_sales_details

UNION ALL

SELECT 'erp_cust_az12', COUNT(*)
FROM bronze.erp_cust_az12

UNION ALL

SELECT 'erp_loc_a101', COUNT(*)
FROM bronze.erp_loc_a101

UNION ALL

SELECT 'erp_px_cat_g1v2', COUNT(*)
FROM bronze.erp_px_cat_g1v2;
GO
