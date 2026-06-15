/* ============================================================================
   05_append_only_trigger.sql
   Enforces the append-only rule on consent records at the DATABASE level.
   Any attempt to UPDATE or DELETE a row in ConsentSigning is rejected, so the
   consent audit trail can only ever be added to. (Supports Reflection Q3.)
   Run AFTER 01_create_tables.sql (it only needs the table to exist).
   ============================================================================ */

USE HDS_ClinicalTrial;
GO

CREATE OR ALTER TRIGGER dbo.trg_ConsentSigning_AppendOnly
ON dbo.ConsentSigning
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51000,
        'ConsentSigning is append-only: rows cannot be updated or deleted.', 1;
END;
GO

/* ---- Optional verification (these two statements SHOULD fail with error 51000):

   UPDATE dbo.ConsentSigning SET witnessed_by = N'Someone Else'
   WHERE  consent_signing_id = 1;

   DELETE FROM dbo.ConsentSigning
   WHERE  consent_signing_id = 1;
---- */
