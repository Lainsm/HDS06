/* ============================================================================
   00_create_database.sql
   Westbrook University Hospitals NHS Trust - Clinical Trial Participant Registry
   ----------------------------------------------------------------------------
   Creates (or recreates) the database used by the rest of the scripts.
   Run this FIRST. Microsoft SQL Server (T-SQL).
   ============================================================================ */

IF DB_ID('HDS_ClinicalTrial') IS NOT NULL
BEGIN
    ALTER DATABASE HDS_ClinicalTrial SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HDS_ClinicalTrial;
END
GO

CREATE DATABASE HDS_ClinicalTrial;
GO

USE HDS_ClinicalTrial;
GO
