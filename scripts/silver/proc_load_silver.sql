-- ===============================================================================
-- Stored Procedure: Load Silver Layer (Bronze -> Silver)
-- ===============================================================================
-- Script Purpose:
--     This stored procedure performs the ETL (Extract, Transform, Load) process to populate the 'silver' schema tables from the 'bronze' schema.
--     It performs the following actions:
--     - Truncates the silver tables before loading data.
--     - Inserts transformed and cleaned data from Bronze into Silver tables.
--
-- Parameters:
--     None.
--     This stored procedure does not accept any parameters or return any values.
--
-- Usage Example:
--     CALL bronze.load_bronze();
-- ===============================================================================

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time        TIMESTAMP;
    v_end_time          TIMESTAMP;
    v_batch_start_time  TIMESTAMP;
    v_batch_end_time    TIMESTAMP;
BEGIN
    v_batch_start_time := clock_timestamp();
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Silver Layer';
    RAISE NOTICE '================================================';

    -- ---------------------------------------------------------------
    -- CRM Tables
    -- ---------------------------------------------------------------
    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '------------------------------------------------';
    
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info;
    RAISE NOTICE '>> Inserting Data Into: silver.crm_cust_info';
    INSERT INTO silver.crm_cust_info (
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date)

    SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) as cst_firstname,
    TRIM(cst_lastname) as cst_lastname,
    CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        ELSE 'Unknown'
    END cst_marital_status,
    CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'Unknown'
    END cst_gndr,
    cst_create_date
    FROM(
        SELECT *,
        ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_latest
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    )
    WHERE flag_latest = 1;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INT;
    RAISE NOTICE '>> -------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_prd_info';
    TRUNCATE TABLE silver.crm_prd_info;
    RAISE NOTICE '>> Inserting Data Into: silver.crm_prd_info';
    INSERT INTO silver.crm_prd_info (
        prd_id,
        prd_cat,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt)

    SELECT 
    prd_id,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') as prd_cat,
    SUBSTRING(prd_key, 7, LENGTH(prd_key)) as prd_key,
    prd_nm,
    COALESCE(prd_cost, 0) as prd_cost,
    CASE UPPER(TRIM(prd_line)) 
        WHEN 'M' THEN 'Mountain'
        WHEN 'S' THEN 'other Sales'
        WHEN 'T' THEN 'Touring'
        WHEN 'R' THEN 'Road'
        ELSE 'Unknown'
    END as prd_line,
    CAST (prd_start_dt as DATE) as prd_start_dt,
    CAST (LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - INTERVAL '1 day' as DATE) as prd_end_dt
    FROM bronze.crm_prd_info;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INT;
    RAISE NOTICE '>> -------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_sales_details';
    TRUNCATE TABLE silver.crm_sales_details;
    RAISE NOTICE '>> Inserting Data Into: silver.crm_sales_details';
    INSERT INTO silver.crm_sales_details (
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price)
    SELECT
    sls_ord_num, 
    sls_prd_key, 
    sls_cust_id, 
    CASE WHEN sls_order_dt = 0 OR LENGTH(sls_order_dt::VARCHAR) != 8 THEN NULL
        ELSE CAST(CAST(sls_order_dt as VARCHAR) as DATE)
    END as sls_order_dt,
    CASE WHEN sls_ship_dt = 0 OR LENGTH(sls_ship_dt::VARCHAR) != 8 THEN NULL
        ELSE CAST(CAST(sls_ship_dt as VARCHAR) as DATE)
    END as sls_ship_dt,
    CASE WHEN sls_due_dt = 0 OR LENGTH(sls_due_dt::VARCHAR) != 8 THEN NULL
        ELSE CAST(CAST(sls_due_dt as VARCHAR) as DATE)
    END as sls_due_dt,
    CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END as sls_sales,
    sls_quantity, 
    CASE WHEN sls_price IS NULL OR sls_price <= 0
            THEN sls_sales / COALESCE(sls_quantity, 0)
        ELSE sls_price
    END as sls_price
    FROM bronze.crm_sales_details;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INT;
    RAISE NOTICE '>> -------------';


    -- ---------------------------------------------------------------
    -- ERP Tables
    -- ---------------------------------------------------------------
    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading ERP Tables';
    RAISE NOTICE '------------------------------------------------';


    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: erp_cust_az12';
    TRUNCATE TABLE silver.erp_cust_az12;
    RAISE NOTICE '>> Inserting Data Into: erp_cust_az12';
    INSERT INTO silver.erp_cust_az12 (
        cid,
        bdate,
        gen)
    SELECT
    CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))
        ELSE cid
    END as cid,
    CASE WHEN bdate > CURRENT_DATE THEN NULL
        ELSE bdate
    END AS bdate,
    CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
        ELSE 'Unknown'
    END as gen
    FROM bronze.erp_cust_az12;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INT;
    RAISE NOTICE '>> -------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: erp_loc_a101';
    TRUNCATE TABLE silver.erp_loc_a101;
    RAISE NOTICE '>> Inserting Data Into: erp_loc_a101';
    INSERT INTO silver.erp_loc_a101 (
        cid,
        cntry)
    SELECT
    REPLACE(cid, '-', '') as cid,
    CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
        WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
        WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'Unknown'
        ELSE TRIM(cntry)
    END as cntry
    FROM bronze.erp_loc_a101;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INT;
    RAISE NOTICE '>> -------------';

    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: erp_px_cat_g1v2';
    TRUNCATE TABLE silver.erp_px_cat_g1v2;
    RAISE NOTICE '>> Inserting Data Into: erp_px_cat_g1v2';
    INSERT INTO silver.erp_px_cat_g1v2 (
        id,
        cat,
        subcat,
        maintenance)
    SELECT
    id,
    cat,
    subcat,
    maintenance
    FROM bronze.erp_px_cat_g1v2;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INT;
    RAISE NOTICE '>> -------------';

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'ERROR OCCURED DURING LOADING SILVER LAYER';
    RAISE NOTICE 'Error Message: %', SQLERRM;
    RAISE NOTICE 'Error Code:    %', SQLSTATE;
    RAISE NOTICE '==========================================';
END;
$$;
