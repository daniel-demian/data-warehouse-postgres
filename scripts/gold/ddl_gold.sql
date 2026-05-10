/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
    ci.cst_id AS customer_id, 
    ci.cst_key AS customer_number, 
    ci.cst_firstname AS first_name, 
    ci.cst_lastname AS last_name,
    el.cntry AS country,
    ci.cst_marital_status AS marital_status,
    CASE WHEN ci.cst_gndr != 'Unknown' THEN ci.cst_gndr
         ELSE COALESCE(ec.gen, 'Unknown')
    END AS gender,
    ec.bdate AS birthdate,
    ci.cst_create_date AS create_date
FROM silver.crm_cust_info as ci
LEFT JOIN silver.erp_cust_az12 as ec ON ci.cst_key = ec.cid
LEFT JOIN silver.erp_loc_a101 as el ON ci.cst_key = el.cid;
