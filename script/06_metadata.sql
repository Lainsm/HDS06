/* ============================================================================
   06_metadata.sql
   Metadata development: table and column descriptions are stored IN the
   database catalog as extended properties (MS_Description), so the data
   dictionary is not static documentation -- it travels with the schema and
   can be reproduced (or consumed by tooling) by querying the catalog views.
   Run AFTER 01_create_tables.sql.
   ============================================================================ */

USE HDS_ClinicalTrial;
GO

/* ----------------------------------------------------------------------------
   Table-level descriptions
   ---------------------------------------------------------------------------- */
EXEC sp_addextendedproperty 'MS_Description',
     N'One row per clinical trial run by the trust; identified externally by its ISRCTN registration number.',
     'SCHEMA','dbo','TABLE','ClinicalTrial';
EXEC sp_addextendedproperty 'MS_Description',
     N'One row per hospital site in the trust; identified operationally by its short site code.',
     'SCHEMA','dbo','TABLE','HospitalSite';
EXEC sp_addextendedproperty 'MS_Description',
     N'One pseudonymised participant per row; no names are held (data minimisation).',
     'SCHEMA','dbo','TABLE','Participant';
EXEC sp_addextendedproperty 'MS_Description',
     N'Controlled vocabulary of standardised reasons a participant leaves a trial, for consistent cross-trial reporting.',
     'SCHEMA','dbo','TABLE','InactivationReason';
EXEC sp_addextendedproperty 'MS_Description',
     N'Link table resolving the many-to-many between trials and sites; carries the recruitment open/close dates of the pairing.',
     'SCHEMA','dbo','TABLE','TrialSite';
EXEC sp_addextendedproperty 'MS_Description',
     N'Every approved version of a trial''s consent form, with effective date and full wording; old versions are never overwritten.',
     'SCHEMA','dbo','TABLE','ConsentVersion';
EXEC sp_addextendedproperty 'MS_Description',
     N'A participant''s enrolment in a trial at a specific site; exit is recorded in place, the row is never deleted.',
     'SCHEMA','dbo','TABLE','Enrollment';
EXEC sp_addextendedproperty 'MS_Description',
     N'Append-only log of every consent signing event (protected by an INSTEAD OF UPDATE/DELETE trigger).',
     'SCHEMA','dbo','TABLE','ConsentSigning';
GO

/* ----------------------------------------------------------------------------
   Column-level descriptions -- columns whose meaning is not self-evident,
   in particular those where NULL carries meaning.
   ---------------------------------------------------------------------------- */
EXEC sp_addextendedproperty 'MS_Description',
     N'NULL = trial still ongoing; filled when the trial ends.',
     'SCHEMA','dbo','TABLE','ClinicalTrial','COLUMN','end_date';
EXEC sp_addextendedproperty 'MS_Description',
     N'NULL = site still open for recruitment on this trial; filled when recruitment closes.',
     'SCHEMA','dbo','TABLE','TrialSite','COLUMN','closed_date';
EXEC sp_addextendedproperty 'MS_Description',
     N'NULL = participant still active in the trial; filled with the date they left. Paired with inactivation_reason_id by a CHECK constraint.',
     'SCHEMA','dbo','TABLE','Enrollment','COLUMN','inactivation_date';
EXEC sp_addextendedproperty 'MS_Description',
     N'NULL = participant still active; otherwise a standardised InactivationReason. Paired with inactivation_date by a CHECK constraint.',
     'SCHEMA','dbo','TABLE','Enrollment','COLUMN','inactivation_reason_id';
EXEC sp_addextendedproperty 'MS_Description',
     N'Pseudonymous study code (e.g. WBK-001); the only identifier ever exposed outside the research office linkage list.',
     'SCHEMA','dbo','TABLE','Participant','COLUMN','study_code';
EXEC sp_addextendedproperty 'MS_Description',
     N'Full consent form wording as approved; preserved verbatim for every version.',
     'SCHEMA','dbo','TABLE','ConsentVersion','COLUMN','wording_text';
GO

/* ----------------------------------------------------------------------------
   Machine-readable data dictionary, generated from the catalog itself.
   Result 1: tables with their descriptions.
   Result 2: every column with type, nullability, and description where set.
   ---------------------------------------------------------------------------- */
SELECT t.name                          AS table_name,
       CAST(ep.value AS NVARCHAR(400)) AS table_description
FROM   sys.tables t
LEFT   JOIN sys.extended_properties ep
       ON  ep.major_id = t.object_id AND ep.minor_id = 0
       AND ep.class = 1 AND ep.name = 'MS_Description'
ORDER  BY t.name;
GO

SELECT t.name                                        AS table_name,
       c.name                                        AS column_name,
       CONCAT(TYPE_NAME(c.user_type_id),
              CASE WHEN TYPE_NAME(c.user_type_id) LIKE '%varchar'
                   THEN CONCAT('(', IIF(c.max_length = -1, 'MAX',
                        CAST(c.max_length / IIF(TYPE_NAME(c.user_type_id) = 'nvarchar', 2, 1) AS VARCHAR(10))), ')')
                   ELSE '' END)                      AS data_type,
       IIF(c.is_nullable = 1, 'NULL', 'NOT NULL')    AS nullability,
       CAST(ep.value AS NVARCHAR(400))               AS column_description
FROM   sys.tables  t
JOIN   sys.columns c ON c.object_id = t.object_id
LEFT   JOIN sys.extended_properties ep
       ON  ep.major_id = c.object_id AND ep.minor_id = c.column_id
       AND ep.class = 1 AND ep.name = 'MS_Description'
ORDER  BY t.name, c.column_id;
GO
