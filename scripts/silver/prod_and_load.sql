USE DataWarehouse;
GO

-- ======================================================================
-- Stored Procedure: silver.load_silver
-- Purpose: Load and transform data from the bronze layer into the silver layer.
--          The silver layer applies data cleaning, standardization, and deduplication.
--          All tables are truncated and reloaded fully.
-- ======================================================================
CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    -- Suppress "rows affected" messages for cleaner output
    SET NOCOUNT ON;
    -- Automatically roll back the transaction on any error
    SET XACT_ABORT ON;

    -- Declare timing variables
    DECLARE @start_time        DATETIME,
            @end_time          DATETIME,
            @batch_start_time  DATETIME,
            @batch_end_time    DATETIME;

    -- Variable to capture the number of rows inserted (for logging)
    DECLARE @row_count INT;

    BEGIN TRY
        -- Start the transaction so all changes are atomic
        BEGIN TRANSACTION;

        -- Record the batch start time
        SET @batch_start_time = GETDATE();

        PRINT '================================================';
        PRINT '            LOADING SILVER LAYER               ';
        PRINT '================================================';

        -- =============================================================
        -- SECTION 1: CRM TABLES (Customer, Product, Sales)
        -- =============================================================
        PRINT '------------------------------------------------';
        PRINT '          Loading CRM Tables                    ';
        PRINT '------------------------------------------------';

        -- -------------------------------------------------------------
        -- 1. silver.crm_cust_info  (Customer Information)
        --    - Deduplicate: keep only the latest record per customer
        --      based on cst_create_date (most recent first).
        --    - Standardize marital status and gender to readable strings.
        --    - Trim first/last names to remove extra spaces.
        -- -------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        PRINT '>> Inserting Data Into: silver.crm_cust_info';
        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname)  AS cst_lastname,
            -- Normalise marital status: 'S' → 'Single', 'M' → 'Married', else 'n/a'
            CASE UPPER(TRIM(cst_marital_status))
                WHEN 'S' THEN 'Single'
                WHEN 'M' THEN 'Married'
                ELSE 'n/a'
            END AS cst_marital_status,
            -- Normalise gender: 'F' → 'Female', 'M' → 'Male', else 'n/a'
            CASE UPPER(TRIM(cst_gndr))
                WHEN 'F' THEN 'Female'
                WHEN 'M' THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date
        FROM (
            -- Use ROW_NUMBER to pick the most recent record per customer
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id
                    ORDER BY cst_create_date DESC
                ) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL   -- ignore rows without a customer ID
        ) t
        WHERE flag_last = 1;   -- only the latest record per customer

        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Inserted ' + CAST(@row_count AS VARCHAR) + ' rows.';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- -------------------------------------------------------------
        -- 2. silver.crm_prd_info  (Product Information)
        --    - Split the product key into category ID (first 5 chars)
        --      and product key (remaining part).
        --    - Replace hyphens with underscores in category ID.
        --    - Map product line codes (M,R,S,T) to descriptive names.
        --    - Set cost to 0 if missing.
        --    - Derive the product end date as one day before the next
        --      start date for the same product (using LEAD window function).
        -- -------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        PRINT '>> Inserting Data Into: silver.crm_prd_info';
        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,   -- extract category ID
            SUBSTRING(prd_key, 7, LEN(prd_key))          AS prd_key,   -- actual product key
            prd_nm,
            ISNULL(prd_cost, 0) AS prd_cost,
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,
            CAST(prd_start_dt AS DATE) AS prd_start_dt,
            -- End date = start date of the next version minus one day
            CAST(
                LEAD(prd_start_dt) OVER (
                    PARTITION BY prd_key
                    ORDER BY prd_start_dt
                ) - 1 AS DATE
            ) AS prd_end_dt
        FROM bronze.crm_prd_info;

        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Inserted ' + CAST(@row_count AS VARCHAR) + ' rows.';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- -------------------------------------------------------------
        -- 3. silver.crm_sales_details  (Sales Transactions)
        --    - Convert integer date fields (YYYYMMDD) into proper DATE type.
        --      Invalid values (0 or not 8 digits) become NULL.
        --    - Recalculate sales if the original sales value is NULL,
        --      <=0, or inconsistent (sales ≠ quantity × price).
        --    - Derive price if the original price is NULL or <=0,
        --      by dividing sales by quantity (avoid division by zero).
        -- -------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        PRINT '>> Inserting Data Into: silver.crm_sales_details';
        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            -- Convert order date: if 0 or not 8 digits → NULL, else convert to DATE
            CASE
                WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,
            -- Same for ship date
            CASE
                WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,
            -- Same for due date
            CASE
                WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,
            -- Recalculate sales if missing, <=0, or inconsistent with quantity × price
            CASE
                WHEN sls_sales IS NULL OR sls_sales <= 0
                     OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            -- Derive price if missing or <=0, using sales/quantity (guard against division by zero)
            CASE
                WHEN sls_price IS NULL OR sls_price <= 0
                THEN sls_sales / NULLIF(sls_quantity, 0)
                ELSE sls_price
            END AS sls_price
        FROM bronze.crm_sales_details;

        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Inserted ' + CAST(@row_count AS VARCHAR) + ' rows.';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- -------------------------------------------------------------
        -- 4. silver.erp_cust_az12  (ERP Customer Data)
        --    - Remove the 'NAS' prefix from customer IDs if present.
        --    - Set future birthdates to NULL.
        --    - Normalise gender: 'F'/'FEMALE' → 'Female', 'M'/'MALE' → 'Male', else 'n/a'.
        -- -------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT '>> Inserting Data Into: silver.erp_cust_az12';
        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )
        SELECT
            CASE
                WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid
            END AS cid,
            CASE
                WHEN bdate > GETDATE() THEN NULL   -- future birthdate → invalid
                ELSE bdate
            END AS bdate,
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
                ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;

        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Inserted ' + CAST(@row_count AS VARCHAR) + ' rows.';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- =============================================================
        -- SECTION 2: ERP TABLES (Location, Category)
        -- =============================================================
        PRINT '------------------------------------------------';
        PRINT '          Loading ERP Tables                    ';
        PRINT '------------------------------------------------';

        -- -------------------------------------------------------------
        -- 5. silver.erp_loc_a101  (ERP Location / Country)
        --    - Remove hyphens from customer ID.
        --    - Normalise country codes to full country names.
        --      (DE → Germany, US/USA → United States, blank/null → 'n/a')
        -- -------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT '>> Inserting Data Into: silver.erp_loc_a101';
        INSERT INTO silver.erp_loc_a101 (
            cid,
            cntry
        )
        SELECT
            REPLACE(cid, '-', '') AS cid,
            CASE
                WHEN TRIM(cntry) = 'DE'           THEN 'Germany'
                WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
                WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
                ELSE TRIM(cntry)
            END AS cntry
        FROM bronze.erp_loc_a101;

        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Inserted ' + CAST(@row_count AS VARCHAR) + ' rows.';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- -------------------------------------------------------------
        -- 6. silver.erp_px_cat_g1v2  (Product Category Hierarchy)
        --    - No transformation needed; direct copy from bronze.
        -- -------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance
        FROM bronze.erp_px_cat_g1v2;

        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Inserted ' + CAST(@row_count AS VARCHAR) + ' rows.';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- =============================================================
        -- Finalise: commit the transaction and log total duration
        -- =============================================================
        COMMIT TRANSACTION;

        SET @batch_end_time = GETDATE();
        PRINT '==========================================';
        PRINT '      SILVER LAYER LOAD COMPLETED         ';
        PRINT '   - Total Load Duration: ' +
              CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS VARCHAR) + ' seconds';
        PRINT '==========================================';

    END TRY
    BEGIN CATCH
        -- On error, roll back all changes made during this batch
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Print detailed error information
        PRINT '==========================================';
        PRINT '     ERROR OCCURRED IN SILVER LAYER       ';
        PRINT '------------------------------------------';
        PRINT 'Error Number   : ' + CAST(ERROR_NUMBER() AS VARCHAR);
        PRINT 'Error Severity : ' + CAST(ERROR_SEVERITY() AS VARCHAR);
        PRINT 'Error State    : ' + CAST(ERROR_STATE() AS VARCHAR);
        PRINT 'Error Line     : ' + CAST(ERROR_LINE() AS VARCHAR);
        PRINT 'Error Message  : ' + ERROR_MESSAGE();
        PRINT '------------------------------------------';
        PRINT 'The transaction has been rolled back.';
        PRINT '==========================================';
    END CATCH
END
GO
