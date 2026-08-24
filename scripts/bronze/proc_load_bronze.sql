/*
===============================================================================
MySQL Script: Load Bronze Layer (Source -> Bronze)
===============================================================================
Purpose:
    Loads the Bronze layer from CSV files.

Important:
    - This is a MySQL version of the original SQL Server script.
    - MySQL does NOT support BULK INSERT / CREATE OR ALTER PROCEDURE in the
      same way as the original SQL Server script.
    - LOAD DATA LOCAL INFILE is therefore used.
    - Run this script from the MySQL client with LOCAL INFILE enabled.
    - The paths below use the user's Windows project directory.
===============================================================================
*/

USE bronze;

SET SQL_SAFE_UPDATES = 0;

SELECT '================================================' AS '';
SELECT 'Loading Bronze Layer' AS '';
SELECT '================================================' AS '';

/* ============================================================================
   CRM TABLES
============================================================================ */

SELECT '------------------------------------------------' AS '';
SELECT 'Loading CRM Tables' AS '';
SELECT '------------------------------------------------' AS '';

/* ---------------------------------------------------------------------------
   CRM Customer Info
--------------------------------------------------------------------------- */

SELECT '>> Truncating Table: bronze.crm_cust_info' AS '';
TRUNCATE TABLE bronze.crm_cust_info;

SELECT '>> Inserting Data Into: bronze.crm_cust_info' AS '';

LOAD DATA LOCAL INFILE
'D:/sql-data-warehouse-project-main/sql-data-warehouse-project-main/datasets/source_crm/cust_info.csv'
INTO TABLE bronze.crm_cust_info
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    @cst_create_date
)
SET
    cst_create_date =
        CASE
            WHEN @cst_create_date IS NULL OR TRIM(@cst_create_date) = '' THEN NULL
            WHEN @cst_create_date LIKE '____-__-__'
                THEN STR_TO_DATE(@cst_create_date, '%Y-%m-%d')
            WHEN @cst_create_date LIKE '__-__-____'
                THEN STR_TO_DATE(@cst_create_date, '%m-%d-%Y')
            ELSE NULL
        END;

/* ---------------------------------------------------------------------------
   CRM Product Info
--------------------------------------------------------------------------- */

SELECT '>> Truncating Table: bronze.crm_prd_info' AS '';
TRUNCATE TABLE bronze.crm_prd_info;

SELECT '>> Inserting Data Into: bronze.crm_prd_info' AS '';

LOAD DATA LOCAL INFILE
'D:/sql-data-warehouse-project-main/sql-data-warehouse-project-main/datasets/source_crm/prd_info.csv'
INTO TABLE bronze.crm_prd_info
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    prd_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    @prd_start_dt,
    @prd_end_dt
)
SET
    prd_start_dt =
        CASE
            WHEN @prd_start_dt IS NULL OR TRIM(@prd_start_dt) = '' THEN NULL
            WHEN @prd_start_dt LIKE '____-__-__'
                THEN STR_TO_DATE(@prd_start_dt, '%Y-%m-%d')
            WHEN @prd_start_dt LIKE '__-__-____'
                THEN STR_TO_DATE(@prd_start_dt, '%m-%d-%Y')
            WHEN @prd_start_dt LIKE '____-__-__ __:__:__'
                THEN STR_TO_DATE(@prd_start_dt, '%Y-%m-%d %H:%i:%s')
            WHEN @prd_start_dt LIKE '__-__-____ __:__:__'
                THEN STR_TO_DATE(@prd_start_dt, '%m-%d-%Y %H:%i:%s')
            ELSE NULL
        END,
    prd_end_dt =
        CASE
            WHEN @prd_end_dt IS NULL OR TRIM(@prd_end_dt) = '' THEN NULL
            WHEN @prd_end_dt LIKE '____-__-__'
                THEN STR_TO_DATE(@prd_end_dt, '%Y-%m-%d')
            WHEN @prd_end_dt LIKE '__-__-____'
                THEN STR_TO_DATE(@prd_end_dt, '%m-%d-%Y')
            WHEN @prd_end_dt LIKE '____-__-__ __:__:__'
                THEN STR_TO_DATE(@prd_end_dt, '%Y-%m-%d %H:%i:%s')
            WHEN @prd_end_dt LIKE '__-__-____ __:__:__'
                THEN STR_TO_DATE(@prd_end_dt, '%m-%d-%Y %H:%i:%s')
            ELSE NULL
        END;

/* ---------------------------------------------------------------------------
   CRM Sales Details
--------------------------------------------------------------------------- */

SELECT '>> Truncating Table: bronze.crm_sales_details' AS '';
TRUNCATE TABLE bronze.crm_sales_details;

SELECT '>> Inserting Data Into: bronze.crm_sales_details' AS '';

LOAD DATA LOCAL INFILE
'D:/sql-data-warehouse-project-main/sql-data-warehouse-project-main/datasets/source_crm/sales_details.csv'
INTO TABLE bronze.crm_sales_details
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
);


/* ============================================================================
   ERP TABLES
============================================================================ */

SELECT '------------------------------------------------' AS '';
SELECT 'Loading ERP Tables' AS '';
SELECT '------------------------------------------------' AS '';

/* ---------------------------------------------------------------------------
   ERP Location
--------------------------------------------------------------------------- */

SELECT '>> Truncating Table: bronze.erp_loc_a101' AS '';
TRUNCATE TABLE bronze.erp_loc_a101;

SELECT '>> Inserting Data Into: bronze.erp_loc_a101' AS '';

LOAD DATA LOCAL INFILE
'D:/sql-data-warehouse-project-main/sql-data-warehouse-project-main/datasets/source_erp/loc_a101.csv'
INTO TABLE bronze.erp_loc_a101
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;


/* ---------------------------------------------------------------------------
   ERP Customer
--------------------------------------------------------------------------- */

SELECT '>> Truncating Table: bronze.erp_cust_az12' AS '';
TRUNCATE TABLE bronze.erp_cust_az12;

SELECT '>> Inserting Data Into: bronze.erp_cust_az12' AS '';

LOAD DATA LOCAL INFILE
'D:/sql-data-warehouse-project-main/sql-data-warehouse-project-main/datasets/source_erp/cust_az12.csv'
INTO TABLE bronze.erp_cust_az12
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;


/* ---------------------------------------------------------------------------
   ERP Product Category
--------------------------------------------------------------------------- */

SELECT '>> Truncating Table: bronze.erp_px_cat_g1v2' AS '';
TRUNCATE TABLE bronze.erp_px_cat_g1v2;

SELECT '>> Inserting Data Into: bronze.erp_px_cat_g1v2' AS '';

LOAD DATA LOCAL INFILE
'D:/sql-data-warehouse-project-main/sql-data-warehouse-project-main/datasets/source_erp/px_cat_g1v2.csv'
INTO TABLE bronze.erp_px_cat_g1v2
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;


/* ============================================================================
   COMPLETED
============================================================================ */

SELECT '==========================================' AS '';
SELECT 'Loading Bronze Layer is Completed' AS '';
SELECT '==========================================' AS '';

/* ============================================================================
   OPTIONAL VALIDATION
============================================================================ */

SELECT 'Row counts after Bronze load:' AS '';

SELECT 'crm_cust_info' AS table_name, COUNT(*) AS row_count
FROM bronze.crm_cust_info;

SELECT 'crm_prd_info' AS table_name, COUNT(*) AS row_count
FROM bronze.crm_prd_info;

SELECT 'crm_sales_details' AS table_name, COUNT(*) AS row_count
FROM bronze.crm_sales_details;

SELECT 'erp_loc_a101' AS table_name, COUNT(*) AS row_count
FROM bronze.erp_loc_a101;

SELECT 'erp_cust_az12' AS table_name, COUNT(*) AS row_count
FROM bronze.erp_cust_az12;

SELECT 'erp_px_cat_g1v2' AS table_name, COUNT(*) AS row_count
FROM bronze.erp_px_cat_g1v2;
