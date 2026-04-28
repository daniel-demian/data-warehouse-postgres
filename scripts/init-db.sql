-- =============================================================
-- Create Database and Schemas
-- =============================================================
-- Script Purpose:
--     This script creates a new database named 'datawarehouse' after checking if it already exists.
--     If the database exists, it is dropped and recreated. Additionally, the script sets up three schemas
--     within the database: 'bronze', 'silver', and 'gold'.
--
-- WARNING:
--     Running this script will drop the entire 'datawarehouse' database if it exists.
--     All data in the database will be permanently deleted. Proceed with caution
--     and ensure you have proper backups before running this script.
--
-- Usage (run from terminal):
--     psql -U postgres -f init-db.sql
-- =============================================================

-- Connect to the default postgres database to safely drop/create
\c postgres

-- Drop and recreate the 'datawarehouse' database
DROP DATABASE IF EXISTS datawarehouse;
CREATE DATABASE datawarehouse;

-- Connect to the new database
\c datawarehouse

-- Create Schemas
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
