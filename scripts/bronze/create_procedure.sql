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

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @batch_start_time DATETIME2(0) = SYSDATETIME(),
        @batch_end_time   DATETIME2(0),
        @start_time       DATETIME2(0),
        @end_time         DATETIME2(0),
        @error_message    NVARCHAR(4000);

    BEGIN TRY

        ------------------------------------------------------------
        -- START
        ------------------------------------------------------------
        PRINT '============================================================';
        PRINT '              STARTING BRONZE LOAD';
        PRINT '============================================================';
        PRINT 'Start Time: ' + CONVERT(VARCHAR(19), @batch_start_time, 120);
        PRINT '';

        ------------------------------------------------------------
        -- VALIDATE SCHEMA
        ------------------------------------------------------------
        IF SCHEMA_ID('bronze') IS NULL
        BEGIN
            THROW 50001, 'Schema [bronze] does not exist.', 1;
        END;

        ------------------------------------------------------------
        -- VALIDATE TABLES
        ------------------------------------------------------------
        IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NULL
            THROW 50002, 'Table [bronze.crm_cust_info] does not exist.', 1;

        IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NULL
            THROW 50003, 'Table [bronze.crm_prd_info] does not exist.', 1;

        IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NULL
            THROW 50004, 'Table [bronze.crm_sales_details] does not exist.', 1;

        IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NULL
            THROW 50005, 'Table [bronze.erp_cust_az12] does not exist.', 1;

        IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NULL
            THROW 50006, 'Table [bronze.erp_loc_a101] does not exist.', 1;

        IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NULL
            THROW 50007, 'Table [bronze.erp_px_cat_g1v2] does not exist.', 1;

        ------------------------------------------------------------
        -- START TRANSACTION
        ------------------------------------------------------------
        BEGIN TRANSACTION;

        ------------------------------------------------------------
        -- CRM TABLES
        ------------------------------------------------------------
        PRINT '------------------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------------------';

        ------------------------------------------------------------
        -- crm_cust_info
        ------------------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating: bronze.crm_cust_info';

        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT '>> Loading: bronze.crm_cust_info';

        BULK INSERT bronze.crm_cust_info
        FROM 'D:\sql-data-warehouse-project-main\datasets\source_crm\cust_info.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST((SELECT COUNT(*) FROM bronze.crm_cust_info) AS VARCHAR(20));

        PRINT '>> Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';

        ------------------------------------------------------------
        -- crm_prd_info
        ------------------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating: bronze.crm_prd_info';

        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '>> Loading: bronze.crm_prd_info';

        BULK INSERT bronze.crm_prd_info
        FROM 'D:\sql-data-warehouse-project-main\datasets\source_crm\prd_info.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST((SELECT COUNT(*) FROM bronze.crm_prd_info) AS VARCHAR(20));

        PRINT '>> Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';

        ------------------------------------------------------------
        -- crm_sales_details
        ------------------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating: bronze.crm_sales_details';

        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '>> Loading: bronze.crm_sales_details';

        BULK INSERT bronze.crm_sales_details
        FROM 'D:\sql-data-warehouse-project-main\datasets\source_crm\sales_details.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST((SELECT COUNT(*) FROM bronze.crm_sales_details) AS VARCHAR(20));

        PRINT '>> Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';

        ------------------------------------------------------------
        -- ERP TABLES
        ------------------------------------------------------------
        PRINT '';
        PRINT '------------------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------------------';

        ------------------------------------------------------------
        -- erp_cust_az12
        ------------------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating: bronze.erp_cust_az12';

        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT '>> Loading: bronze.erp_cust_az12';

        BULK INSERT bronze.erp_cust_az12
        FROM 'D:\sql-data-warehouse-project-main\datasets\source_erp\CUST_AZ12.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST((SELECT COUNT(*) FROM bronze.erp_cust_az12) AS VARCHAR(20));

        PRINT '>> Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';

        ------------------------------------------------------------
        -- erp_loc_a101
        ------------------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating: bronze.erp_loc_a101';

        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT '>> Loading: bronze.erp_loc_a101';

        BULK INSERT bronze.erp_loc_a101
        FROM 'D:\sql-data-warehouse-project-main\datasets\source_erp\LOC_A101.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST((SELECT COUNT(*) FROM bronze.erp_loc_a101) AS VARCHAR(20));

        PRINT '>> Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';

        ------------------------------------------------------------
        -- erp_px_cat_g1v2
        ------------------------------------------------------------
        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating: bronze.erp_px_cat_g1v2';

        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT '>> Loading: bronze.erp_px_cat_g1v2';

        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'D:\sql-data-warehouse-project-main\datasets\source_erp\PX_CAT_G1V2.csv'
        WITH
        (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Rows Loaded: '
            + CAST((SELECT COUNT(*) FROM bronze.erp_px_cat_g1v2) AS VARCHAR(20));

        PRINT '>> Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';

        ------------------------------------------------------------
        -- COMMIT
        ------------------------------------------------------------
        COMMIT TRANSACTION;

        SET @batch_end_time = SYSDATETIME();

        PRINT '';
        PRINT '============================================================';
        PRINT '             BRONZE LOAD COMPLETED SUCCESSFULLY';
        PRINT '============================================================';
        PRINT 'End Time: ' + CONVERT(VARCHAR(19), @batch_end_time, 120);
        PRINT 'Total Duration: '
            + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS VARCHAR(20))
            + ' seconds';
        PRINT '============================================================';

    END TRY

    BEGIN CATCH

        ------------------------------------------------------------
        -- ROLLBACK
        ------------------------------------------------------------
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @error_message = ERROR_MESSAGE();

        PRINT '';
        PRINT '============================================================';
        PRINT '                 BRONZE LOAD FAILED';
        PRINT '============================================================';
        PRINT 'Error Number : ' + CAST(ERROR_NUMBER() AS VARCHAR(20));
        PRINT 'Error State  : ' + CAST(ERROR_STATE() AS VARCHAR(20));
        PRINT 'Error Line   : ' + CAST(ERROR_LINE() AS VARCHAR(20));
        PRINT 'Error Message: ' + @error_message;
        PRINT '============================================================';

        THROW;

    END CATCH
END;
GO
