/* ============================================================================
   - HDS_DB_LAINSBURY_2026.sql
   - Westbrook University Hospitals NHS Trust, Clinical Trial Participant Registry
   - Microsoft SQL Server (T-SQL)
   - Ran on Linux (Ubuntu 26.04) without error in VS Code using mssql extension.
   ============================================================================ */


/* ###################### Create Database  ###################### */

/* ============================================================================
   First script to run. Creates the database.
   
   I used an IF to allow you to run this script even if you already created 
   a DB with same name from previous classmate assignments.
   ============================================================================ */

USE master;
GO

IF DB_ID('HDS_ClinicalTrial') IS NOT NULL
BEGIN
    -- Kill any other sessions (e.g. IntelliSense) still attached, so the
    -- single-user slot isn't reclaimed before the DROP statement runs.
    DECLARE @kill NVARCHAR(MAX) = N'';
    SELECT @kill += N'KILL ' + CONVERT(NVARCHAR(5), session_id) + N';'
    FROM sys.dm_exec_sessions
    WHERE database_id = DB_ID('HDS_ClinicalTrial') AND session_id <> @@SPID;
    EXEC sp_executesql @kill;

    ALTER DATABASE HDS_ClinicalTrial SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HDS_ClinicalTrial;
END
GO

CREATE DATABASE HDS_ClinicalTrial;
GO

USE HDS_ClinicalTrial;
GO


/* ###################### Create tables ###################### */

/* ============================================================================

   Design summary:

   ClinicalTrial: one row per trial
   HospitalSite: one row per hospital site
   Participant: one row per pseudonymised participant (no names held)
   InactivationReason: standardised reasons a participant leaves a trial
   TrialSite: link table resolving the M:M -> ClinicalTrial <-> HospitalSite (M:N)
   ConsentVersion: each approved version of a trial's consent form
   Enrollment: a participant enrolled in a trial at a specific site
   ConsentSigning: append-only record of every consent signing event

   Every table has a surrogate INT IDENTITY primary key plus one or more
   business (natural) UNIQUE keys (as per recommendation in the brief),
   EXCEPT TrialSite, which uses a composite natural primary key
   (trial_id, site_id) instead of a surrogate - the pairing itself is
   the identity of that row, so a separate IDENTITY column would be
   redundant with no other column.
   ============================================================================ */

USE HDS_ClinicalTrial; 
GO

/* Drop in reverse dependency order so the script can be re-run cleanly. */
DROP TABLE IF EXISTS dbo.ConsentSigning;
DROP TABLE IF EXISTS dbo.Enrollment;
DROP TABLE IF EXISTS dbo.ConsentVersion;
DROP TABLE IF EXISTS dbo.TrialSite;
DROP TABLE IF EXISTS dbo.InactivationReason;
DROP TABLE IF EXISTS dbo.Participant;
DROP TABLE IF EXISTS dbo.HospitalSite;
DROP TABLE IF EXISTS dbo.ClinicalTrial;
GO

/* ----------------------------------------------------------------------------
   ClinicalTrial
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.ClinicalTrial (
    trial_id            INT IDENTITY(1,1)   NOT NULL,
    registration_number VARCHAR(20)         NOT NULL,   --ISRCTN business key
    trial_name          NVARCHAR(150)       NOT NULL,
    phase               VARCHAR(4)          NOT NULL,
    status              VARCHAR(20)         NOT NULL,
    start_date          DATE                NOT NULL,
    end_date            DATE                NULL,        -- NULL as we can have ongoing trials
    CONSTRAINT PK_ClinicalTrial        PRIMARY KEY (trial_id),
    CONSTRAINT UQ_ClinicalTrial_reg    UNIQUE (registration_number),
    CONSTRAINT CK_ClinicalTrial_phase  CHECK (phase IN ('I','II','III','IV')), -- using "phase" for controlled vocabulary for trial phases
    CONSTRAINT CK_ClinicalTrial_status CHECK (status IN ('recruiting','active','completed','suspended')),
    CONSTRAINT CK_ClinicalTrial_dates  CHECK (end_date IS NULL OR end_date >= start_date)
);
GO

/* ----------------------------------------------------------------------------
   HospitalSite
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.HospitalSite (
    site_id     INT IDENTITY(1,1) NOT NULL,
    site_code   VARCHAR(10)       NOT NULL,   -- business key
    site_name   NVARCHAR(100)     NOT NULL,
    city        NVARCHAR(60)      NOT NULL,
    country     NVARCHAR(60)      NOT NULL,
    CONSTRAINT PK_HospitalSite      PRIMARY KEY (site_id),
    CONSTRAINT UQ_HospitalSite_code UNIQUE (site_code)
);
GO

/* ----------------------------------------------------------------------------
   Participant  (pseudonymised)
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.Participant (
    participant_id    INT IDENTITY(1,1) NOT NULL,
    study_code        VARCHAR(15)       NOT NULL,   -- pseudonymous business key
    date_of_birth     DATE              NOT NULL,
    sex_at_birth      VARCHAR(10)       NOT NULL,
    registration_date DATE              NOT NULL,
    CONSTRAINT PK_Participant        PRIMARY KEY (participant_id),
    CONSTRAINT UQ_Participant_code   UNIQUE (study_code),
    CONSTRAINT CK_Participant_sex    CHECK (sex_at_birth IN ('Male','Female')), -- biological sex at birth, not gender identity; only two values are recorded for this field
    CONSTRAINT CK_Participant_dob    CHECK (date_of_birth < registration_date)
);
GO

/* ----------------------------------------------------------------------------
   InactivationReason  (controlled vocabulary)
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.InactivationReason (
    reason_id          INT IDENTITY(1,1) NOT NULL,
    reason_code        VARCHAR(30)       NOT NULL,   -- business key used in reports
    reason_description NVARCHAR(255)     NOT NULL,
    CONSTRAINT PK_InactivationReason      PRIMARY KEY (reason_id),
    CONSTRAINT UQ_InactivationReason_code UNIQUE (reason_code)
);
GO

/* ----------------------------------------------------------------------------
   TrialSite  (link table: which sites run which trials, M:N)
   Composite primary key (trial_id, site_id) - no surrogate ID column;
   Enrollment below carries a composite FK to this pair directly.
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.TrialSite (
    trial_id      INT               NOT NULL,
    site_id       INT               NOT NULL,
    opened_date   DATE              NOT NULL,   -- site opened for recruitment
    closed_date   DATE              NULL,        -- NULL = still open
    /* Composite natural key: the (trial, site) pairing IS the identity of this
       row - there is nothing else to surrogate-key against, so no separate
       IDENTITY column is used here (unlike the rest of the schema). */
    CONSTRAINT PK_TrialSite        PRIMARY KEY (trial_id, site_id),
    CONSTRAINT FK_TrialSite_trial  FOREIGN KEY (trial_id) REFERENCES dbo.ClinicalTrial(trial_id),
    CONSTRAINT FK_TrialSite_site   FOREIGN KEY (site_id)  REFERENCES dbo.HospitalSite(site_id),
    CONSTRAINT CK_TrialSite_dates  CHECK (closed_date IS NULL OR closed_date >= opened_date)
);
GO

/* ----------------------------------------------------------------------------
   ConsentVersion  (each version of a trial's consent form; never overwritten)
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.ConsentVersion (
    consent_version_id INT IDENTITY(1,1) NOT NULL,
    trial_id           INT               NOT NULL,
    version_number     INT               NOT NULL,
    effective_from     DATE              NOT NULL,
    wording_text       NVARCHAR(MAX)     NOT NULL,
    CONSTRAINT PK_ConsentVersion       PRIMARY KEY (consent_version_id),
    CONSTRAINT UQ_ConsentVersion       UNIQUE (trial_id, version_number),
    CONSTRAINT FK_ConsentVersion_trial FOREIGN KEY (trial_id) REFERENCES dbo.ClinicalTrial(trial_id),
    CONSTRAINT CK_ConsentVersion_ver   CHECK (version_number > 0)
);
GO

/* ----------------------------------------------------------------------------
   Enrollment  (a participant enrolled in a trial at a specific site)
   The enrolment carries (trial_id, site_id) as a composite FK to TrialSite,
   so the trial AND the site are captured together and an enrolment can only
   reference a site that actually runs the trial. The original enrolment row
   is preserved; leaving the trial only sets inactivation_date /
   inactivation_reason_id.
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.Enrollment (
    enrollment_id         INT IDENTITY(1,1) NOT NULL,
    participant_id        INT               NOT NULL,
    trial_id               INT              NOT NULL,
    site_id                 INT             NOT NULL,
    enrolment_date        DATE              NOT NULL,
    inactivation_date     DATE              NULL,   -- NULL = still active
    inactivation_reason_id INT              NULL,   -- NULL = still active
    CONSTRAINT PK_Enrollment             PRIMARY KEY (enrollment_id),
    CONSTRAINT FK_Enrollment_participant FOREIGN KEY (participant_id)         REFERENCES dbo.Participant(participant_id),
    CONSTRAINT FK_Enrollment_trialsite   FOREIGN KEY (trial_id, site_id)      REFERENCES dbo.TrialSite(trial_id, site_id),
    CONSTRAINT FK_Enrollment_reason      FOREIGN KEY (inactivation_reason_id) REFERENCES dbo.InactivationReason(reason_id),
    CONSTRAINT UQ_Enrollment             UNIQUE (participant_id, trial_id, site_id), --A participant cannot be enrolled in the same trial-site twice
    CONSTRAINT CK_Enrollment_inactivation CHECK ( --Inactivation date and reason must both be present or both absent
        (inactivation_date IS NULL     AND inactivation_reason_id IS NULL)
     OR (inactivation_date IS NOT NULL AND inactivation_reason_id IS NOT NULL)),
    CONSTRAINT CK_Enrollment_dates CHECK (inactivation_date IS NULL OR inactivation_date >= enrolment_date)
);
GO

/* A participant may be ACTIVELY enrolled in only one trial at a time.
   A filtered unique index enforces this: at most one row per participant
   where inactivation_date IS NULL. Past (inactivated) enrolments are
   unrestricted, preserving full trial history. */
CREATE UNIQUE INDEX UX_Enrollment_OneActivePerParticipant
    ON dbo.Enrollment(participant_id)
    WHERE inactivation_date IS NULL;
GO

/* ----------------------------------------------------------------------------
   ConsentSigning  (append-only log of every consent signing event)
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.ConsentSigning (
    consent_signing_id INT IDENTITY(1,1) NOT NULL,
    enrollment_id      INT               NOT NULL,
    consent_version_id INT               NOT NULL,
    signed_date        DATE              NOT NULL,
    witnessed_by       NVARCHAR(100)     NOT NULL,
    CONSTRAINT PK_ConsentSigning          PRIMARY KEY (consent_signing_id),
    CONSTRAINT FK_ConsentSigning_enrol    FOREIGN KEY (enrollment_id)      REFERENCES dbo.Enrollment(enrollment_id),
    CONSTRAINT FK_ConsentSigning_version  FOREIGN KEY (consent_version_id) REFERENCES dbo.ConsentVersion(consent_version_id),
    /* The same enrolment cannot sign the same version twice. */
    CONSTRAINT UQ_ConsentSigning          UNIQUE (enrollment_id, consent_version_id),
    /* Witness must be a plausible person name: letters, spaces, hyphens and
       apostrophes only (no digits/symbols), and at least forename + surname. */
    CONSTRAINT CK_ConsentSigning_witness  CHECK (witnessed_by NOT LIKE N'%[^A-Za-z ''-]%'
                                             AND witnessed_by LIKE N'% %')
);
GO


/* ###################### Insert DATA ###################### */

/* ============================================================================

   Using both the reference data supplied (Excel file provided with the brief) and additional data as per brief.

   FK look-ups use subqueries on business keys. No hard-coded IDENTITY values as seen in course.
   ============================================================================ */

USE HDS_ClinicalTrial;
GO

/* ----------------------------------------------------------------------------
   ClinicalTrial
   ---------------------------------------------------------------------------- */
INSERT INTO dbo.ClinicalTrial (registration_number, trial_name, phase, status, start_date, end_date)
VALUES
 ('ISRCTN10234567', N'CARDIOPROTECT: Cardiac Rehabilitation in Post-MI Patients', 'III', 'active',     '2023-03-01', NULL),
 ('ISRCTN20345678', N'BREATHE: Pulmonary Rehabilitation in COPD',                 'II',  'recruiting', '2024-06-01', NULL),
 ('ISRCTN30456789', N'MOBILISE: Early Mobilisation Following Hip Replacement',    'II',  'completed',  '2021-01-01', '2024-12-31');
GO

/* ----------------------------------------------------------------------------
   HospitalSite 
   ---------------------------------------------------------------------------- */
INSERT INTO dbo.HospitalSite (site_code, site_name, city, country)
VALUES
 ('WBK-GEN', N'Westbrook General Hospital',   N'London',     N'England'),
 ('STK-NOR', N'St Katherine''s Hospital',     N'Manchester', N'England'),
 ('RDG-COM', N'Ridgeway Community Hospital',  N'Bristol',    N'England');
GO

/* ----------------------------------------------------------------------------
   Participant
   ---------------------------------------------------------------------------- */
INSERT INTO dbo.Participant (study_code, date_of_birth, sex_at_birth, registration_date)
VALUES
 ('WBK-001', '1958-04-12', 'Male',   '2021-11-03'),
 ('WBK-002', '1971-09-28', 'Female', '2022-02-14'),
 ('WBK-003', '1965-07-05', 'Male',   '2023-01-20'),
 ('WBK-004', '1949-12-18', 'Female', '2023-04-09'),
 ('WBK-005', '1980-03-31', 'Male',   '2024-07-22');
GO

/* ----------------------------------------------------------------------------
   InactivationReason - inserted with N for NVARCHAR support (Unicode) to allow for any special characters.
   ---------------------------------------------------------------------------- */
INSERT INTO dbo.InactivationReason (reason_code, reason_description)
VALUES
 ('consent_withdrawn',  N'Participant withdrew their consent to take part in the trial'),
 ('eligibility_lost',   N'Participant no longer meets the eligibility criteria for the trial'),
 ('clinician_decision', N'The clinical team withdrew the participant - safety concern, protocol non-compliance, or other clinical reason'),
 ('death',              N'Participant died during the trial period'),
 ('lost_to_follow_up',  N'Participant could not be contacted and did not attend scheduled appointments'),
 ('trial_completed',    N'Participant completed the full trial protocol successfully');
GO

/* ----------------------------------------------------------------------------
   ConsentVersion - trial_id is looked up from the registration number. The reason is that the trial_id is an
   IDENTITY column and we want to avoid hardcoding it.
   This ensures that the correct trial_id is used even if the IDENTITY values change in the future.
   ---------------------------------------------------------------------------- */
INSERT INTO dbo.ConsentVersion (trial_id, version_number, effective_from, wording_text) 
VALUES
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number = 'ISRCTN10234567'),
  1, '2023-03-01',
  N'I agree to take part in the CARDIOPROTECT study. I understand that the study involves cardiac rehabilitation sessions over a 12-month period and that my health data will be used for research purposes. I may withdraw at any time without affecting my medical care.'),

 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number = 'ISRCTN10234567'),
  2, '2024-01-15',
  N'I agree to take part in the CARDIOPROTECT study. I understand that the study involves cardiac rehabilitation sessions over a 12-month period and that my health data, including data from wearable monitoring devices, will be used for research purposes. I may withdraw at any time without affecting my medical care.'),

 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number = 'ISRCTN20345678'),
  1, '2024-06-01',
  N'I agree to take part in the BREATHE study. I understand that the study involves pulmonary rehabilitation exercises and that my lung function data will be collected and used for research purposes. I may withdraw at any time without affecting my medical care.'),

 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number = 'ISRCTN30456789'),
  1, '2021-01-01',
  N'I agree to take part in the MOBILISE study. I understand that the study involves an early post-operative mobilisation programme following hip replacement surgery. My mobility and recovery data will be collected for research purposes. I may withdraw at any time without affecting my medical care.');
GO


/* ###################### insert additional ops data ###################### */

/* 
   data added to make the seven queries meaningful:
     - TrialSite      : which sites run which trials (and when they opened/closed)
     - Enrollment     : participants enrolled in trials at sites, incl. history
     - ConsentSigning : append-only consent signing events (incl. re-consent)

   ============================================================================ */

USE HDS_ClinicalTrial;
GO

/* ----------------------------------------------------------------------------
   TrialSite is what links trials to sites (each trial at >= 2 sites where possible)
     CARDIOPROTECT -> WBK-GEN, STK-NOR
     BREATHE       -> WBK-GEN, RDG-COM   (RDG-COM intentionally has 0 enrolments)
     MOBILISE      -> STK-NOR            (site closed when the trial completed)
   ---------------------------------------------------------------------------- */
INSERT INTO dbo.TrialSite (trial_id, site_id, opened_date, closed_date)
VALUES
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN10234567'),
  (SELECT site_id  FROM dbo.HospitalSite  WHERE site_code='WBK-GEN'), '2023-03-01', NULL),
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN10234567'),
  (SELECT site_id  FROM dbo.HospitalSite  WHERE site_code='STK-NOR'), '2023-04-01', NULL), -- data is authored to allow to answer queries
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN20345678'),
  (SELECT site_id  FROM dbo.HospitalSite  WHERE site_code='WBK-GEN'), '2024-06-01', NULL),
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN20345678'),
  (SELECT site_id  FROM dbo.HospitalSite  WHERE site_code='RDG-COM'), '2024-07-01', NULL),
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN30456789'),
  (SELECT site_id  FROM dbo.HospitalSite  WHERE site_code='STK-NOR'), '2021-01-01', '2024-12-31');
GO



/* WBK-001 : active in CARDIOPROTECT at Westbrook General (re-consents later) */
INSERT INTO dbo.Enrollment (participant_id, trial_id, site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant   WHERE study_code='WBK-001'),
  (SELECT trial_id       FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN10234567'),
  (SELECT site_id        FROM dbo.HospitalSite  WHERE site_code='WBK-GEN'),
  '2023-03-15', NULL, NULL);

/* WBK-002 : completed MOBILISE (past), now active in CARDIOPROTECT at St Katherine's */
INSERT INTO dbo.Enrollment (participant_id, trial_id, site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant   WHERE study_code='WBK-002'),
  (SELECT trial_id       FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN30456789'),
  (SELECT site_id        FROM dbo.HospitalSite  WHERE site_code='STK-NOR'),
  '2022-03-01', '2024-12-31',
  (SELECT reason_id FROM dbo.InactivationReason WHERE reason_code='trial_completed'));

INSERT INTO dbo.Enrollment (participant_id, trial_id, site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant   WHERE study_code='WBK-002'),
  (SELECT trial_id       FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN10234567'),
  (SELECT site_id        FROM dbo.HospitalSite  WHERE site_code='STK-NOR'),
  '2025-01-10', NULL, NULL);

/* WBK-003 : withdrew from BREATHE (past), now active in CARDIOPROTECT - needed for Query 3 */
INSERT INTO dbo.Enrollment (participant_id, trial_id, site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant   WHERE study_code='WBK-003'),
  (SELECT trial_id       FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN20345678'),
  (SELECT site_id        FROM dbo.HospitalSite  WHERE site_code='WBK-GEN'),
  '2024-06-10', '2024-09-15',
  (SELECT reason_id FROM dbo.InactivationReason WHERE reason_code='consent_withdrawn'));

INSERT INTO dbo.Enrollment (participant_id, trial_id, site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant   WHERE study_code='WBK-003'),
  (SELECT trial_id       FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN10234567'),
  (SELECT site_id        FROM dbo.HospitalSite  WHERE site_code='WBK-GEN'),
  '2024-10-01', NULL, NULL);

/* WBK-004 : died during CARDIOPROTECT at St Katherine's (inactive) */
INSERT INTO dbo.Enrollment (participant_id, trial_id, site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant   WHERE study_code='WBK-004'),
  (SELECT trial_id       FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN10234567'),
  (SELECT site_id        FROM dbo.HospitalSite  WHERE site_code='STK-NOR'),
  '2023-05-20', '2023-11-10',
  (SELECT reason_id FROM dbo.InactivationReason WHERE reason_code='death'));

/* WBK-005 : active in BREATHE at Westbrook General */
INSERT INTO dbo.Enrollment (participant_id, trial_id, site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant   WHERE study_code='WBK-005'),
  (SELECT trial_id       FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN20345678'),
  (SELECT site_id        FROM dbo.HospitalSite  WHERE site_code='WBK-GEN'),
  '2024-08-05', NULL, NULL);
GO

/* ----------------------------------------------------------------------------
   ConsentSigning - append-only signing events.
   enrollment_id is resolved from (study_code, registration_number);
   consent_version_id from (registration_number, version_number).
   WBK-001 signs CARDIOPROTECT v1 then re-consents v2 (needed for Query 6 context).
   ---------------------------------------------------------------------------- */

/* WBK-001 - CARDIOPROTECT v1 at enrolment */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     WHERE e.participant_id = (SELECT participant_id FROM dbo.Participant
                               WHERE study_code = 'WBK-001')
       AND e.trial_id       = (SELECT trial_id FROM dbo.ClinicalTrial
                               WHERE registration_number = 'ISRCTN10234567')),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     WHERE cv.trial_id = (SELECT trial_id FROM dbo.ClinicalTrial
                          WHERE registration_number = 'ISRCTN10234567')
       AND cv.version_number = 1),
  '2023-03-15', N'Amara Okafor');

/* WBK-001 - CARDIOPROTECT v2 re-consent after protocol amendment */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     WHERE e.participant_id = (SELECT participant_id FROM dbo.Participant
                               WHERE study_code = 'WBK-001')
       AND e.trial_id       = (SELECT trial_id FROM dbo.ClinicalTrial
                               WHERE registration_number = 'ISRCTN10234567')),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     WHERE cv.trial_id = (SELECT trial_id FROM dbo.ClinicalTrial
                          WHERE registration_number = 'ISRCTN10234567')
       AND cv.version_number = 2),
  '2024-01-20', N'Amara Okafor');

/* WBK-002 - MOBILISE v1 */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     WHERE e.participant_id = (SELECT participant_id FROM dbo.Participant
                               WHERE study_code = 'WBK-002')
       AND e.trial_id       = (SELECT trial_id FROM dbo.ClinicalTrial
                               WHERE registration_number = 'ISRCTN30456789')),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     WHERE cv.trial_id = (SELECT trial_id FROM dbo.ClinicalTrial
                          WHERE registration_number = 'ISRCTN30456789')
       AND cv.version_number = 1),
  '2022-03-01', N'Robert Mensah');

/* WBK-002 - CARDIOPROTECT v2 (current version at time of enrolment) */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     WHERE e.participant_id = (SELECT participant_id FROM dbo.Participant
                               WHERE study_code = 'WBK-002')
       AND e.trial_id       = (SELECT trial_id FROM dbo.ClinicalTrial
                               WHERE registration_number = 'ISRCTN10234567')),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     WHERE cv.trial_id = (SELECT trial_id FROM dbo.ClinicalTrial
                          WHERE registration_number = 'ISRCTN10234567')
       AND cv.version_number = 2),
  '2025-01-10', N'Sara Patel');

/* WBK-003 - BREATHE v1 */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     WHERE e.participant_id = (SELECT participant_id FROM dbo.Participant
                               WHERE study_code = 'WBK-003')
       AND e.trial_id       = (SELECT trial_id FROM dbo.ClinicalTrial
                               WHERE registration_number = 'ISRCTN20345678')),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     WHERE cv.trial_id = (SELECT trial_id FROM dbo.ClinicalTrial
                          WHERE registration_number = 'ISRCTN20345678')
       AND cv.version_number = 1),
  '2024-06-10', N'Amara Okafor');

/* WBK-003 - CARDIOPROTECT v2 (current at enrolment) */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     WHERE e.participant_id = (SELECT participant_id FROM dbo.Participant
                               WHERE study_code = 'WBK-003')
       AND e.trial_id       = (SELECT trial_id FROM dbo.ClinicalTrial
                               WHERE registration_number = 'ISRCTN10234567')),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     WHERE cv.trial_id = (SELECT trial_id FROM dbo.ClinicalTrial
                          WHERE registration_number = 'ISRCTN10234567')
       AND cv.version_number = 2),
  '2024-10-01', N'Sara Patel');

/* WBK-004 - CARDIOPROTECT v1 (enrolled before the amendment) */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     WHERE e.participant_id = (SELECT participant_id FROM dbo.Participant
                               WHERE study_code = 'WBK-004')
       AND e.trial_id       = (SELECT trial_id FROM dbo.ClinicalTrial
                               WHERE registration_number = 'ISRCTN10234567')),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     WHERE cv.trial_id = (SELECT trial_id FROM dbo.ClinicalTrial
                          WHERE registration_number = 'ISRCTN10234567')
       AND cv.version_number = 1),
  '2023-05-20', N'Robert Mensah');

/* WBK-005 - BREATHE v1 */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     WHERE e.participant_id = (SELECT participant_id FROM dbo.Participant
                               WHERE study_code = 'WBK-005')
       AND e.trial_id       = (SELECT trial_id FROM dbo.ClinicalTrial
                               WHERE registration_number = 'ISRCTN20345678')),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     WHERE cv.trial_id = (SELECT trial_id FROM dbo.ClinicalTrial
                          WHERE registration_number = 'ISRCTN20345678')
       AND cv.version_number = 1),
  '2024-08-05', N'Sara Patel');
GO


/* NOTE: Ridgeway Community (RDG-COM) is linked to BREATHE in TrialSite but
   deliberately receives NO enrolments, so Query 5 demonstrably includes a
   site with a zero count (LEFT JOIN behaviour). */

/* WBK-005 : close out the active BREATHE enrolment (in place) */
UPDATE dbo.Enrollment
SET    inactivation_date      = '2025-03-15',
       inactivation_reason_id = (SELECT reason_id FROM dbo.InactivationReason WHERE reason_code='clinician_decision')
WHERE  participant_id = (SELECT participant_id FROM dbo.Participant   WHERE study_code='WBK-005')
  AND  trial_id       = (SELECT trial_id       FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN20345678')
  AND  site_id        = (SELECT site_id        FROM dbo.HospitalSite  WHERE site_code='WBK-GEN');

/* WBK-005 : new active enrolment - CARDIOPROTECT at St Katherine's (most recent overall) */
INSERT INTO dbo.Enrollment (participant_id, trial_id, site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant   WHERE study_code='WBK-005'),
  (SELECT trial_id       FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN10234567'),
  (SELECT site_id        FROM dbo.HospitalSite  WHERE site_code='STK-NOR'),
  '2025-04-01', NULL, NULL);

/* WBK-005 - CARDIOPROTECT v2 at St Katherine's (current version) */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     WHERE e.participant_id = (SELECT participant_id FROM dbo.Participant
                               WHERE study_code = 'WBK-005')
       AND e.trial_id       = (SELECT trial_id FROM dbo.ClinicalTrial
                               WHERE registration_number = 'ISRCTN10234567')),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     WHERE cv.trial_id = (SELECT trial_id FROM dbo.ClinicalTrial
                          WHERE registration_number = 'ISRCTN10234567')
       AND cv.version_number = 2),
  '2025-04-01', N'Amara Okafor');
GO


/* ###################### Append-Only Trigger ###################### */

/* ============================================================================
   
   Enforces the append-only rule on consent records at the DATABASE level.
   Any attempt to UPDATE or DELETE a row in ConsentSigning is rejected, so the
   consent audit trail can only ever be added to. (Supports Reflection Q3.)
   Placed after the data inserts; it only needs the ConsentSigning table to exist.
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

/* ###################### Queries  ###################### */

/* ============================================================================
   The seven clinical queries.
   Can only be run AFTER inserting the operational data.
   ============================================================================ */

USE HDS_ClinicalTrial;
GO

/* ----------------------------------------------------------------------------
   QUERY 1
   Current (most recently effective) consent wording for the CARDIOPROTECT trial.
   ---------------------------------------------------------------------------- */
SELECT TOP (1)
       cv.version_number,
       cv.effective_from,
       cv.wording_text
FROM   dbo.ConsentVersion cv
JOIN   dbo.ClinicalTrial  ct ON ct.trial_id = cv.trial_id
WHERE  ct.trial_name LIKE 'CARDIOPROTECT%'
ORDER  BY cv.effective_from DESC;
GO

/* ----------------------------------------------------------------------------
   QUERY 2
   Monthly status report: each trial, its status, days running, and whether it
   has an end date or is still ongoing. Active first, then recruiting, then rest.
   ---------------------------------------------------------------------------- */
SELECT ct.trial_name,
       ct.status,
       DATEDIFF(DAY, ct.start_date, COALESCE(ct.end_date, CAST(GETDATE() AS DATE))) AS days_running,
       CASE WHEN ct.end_date IS NULL THEN 'Ongoing' ELSE 'Ended' END               AS end_date_status
FROM   dbo.ClinicalTrial ct
ORDER  BY CASE ct.status
              WHEN 'active'     THEN 1
              WHEN 'recruiting' THEN 2
              ELSE 3
          END,
          ct.trial_name;
GO

/* ----------------------------------------------------------------------------
   QUERY 3
   Full trial history for participant WBK-003. A LEFT JOIN to InactivationReason
   keeps active enrolments (which have no reason) in the result set.
   Enrollment stores trial_id directly (composite FK to TrialSite), so
   ClinicalTrial can be joined straight off it - no TrialSite join needed.
   ---------------------------------------------------------------------------- */
SELECT ct.trial_name,
       e.enrolment_date,
       e.inactivation_date,
       ir.reason_code
FROM   dbo.Enrollment       e
JOIN   dbo.Participant      p  ON p.participant_id = e.participant_id
JOIN   dbo.ClinicalTrial    ct ON ct.trial_id      = e.trial_id
LEFT   JOIN dbo.InactivationReason ir ON ir.reason_id = e.inactivation_reason_id
WHERE  p.study_code = 'WBK-003'
ORDER  BY e.enrolment_date;
GO

/* ----------------------------------------------------------------------------
   QUERY 4
   Audit of currently ACTIVE enrolments: participant, trial, site, enrol date.
   Order by trial name then enrolment date.
   Enrollment stores trial_id and site_id directly, so ClinicalTrial and
   HospitalSite are joined straight off it - no TrialSite join needed.
   ---------------------------------------------------------------------------- */
SELECT p.study_code,
       ct.trial_name,
       hs.site_name,
       e.enrolment_date
FROM   dbo.Enrollment    e
JOIN   dbo.Participant   p  ON p.participant_id = e.participant_id
JOIN   dbo.ClinicalTrial ct ON ct.trial_id      = e.trial_id
JOIN   dbo.HospitalSite  hs ON hs.site_id       = e.site_id
WHERE  e.inactivation_date IS NULL
ORDER  BY ct.trial_name, e.enrolment_date;
GO

/* ----------------------------------------------------------------------------
   QUERY 5
   Total enrolments ever, per site, INCLUDING sites with none.
   LEFT JOIN from HospitalSite preserves sites with zero enrolments;
   COUNT(e.enrollment_id) counts rows, not NULLs, so empty sites score 0.
   Enrollment stores site_id directly, so it is joined straight off
   HospitalSite - no TrialSite join needed.
   ---------------------------------------------------------------------------- */
SELECT hs.site_name,
       hs.city,
       COUNT(e.enrollment_id) AS total_enrolments
FROM   dbo.HospitalSite hs
LEFT   JOIN dbo.Enrollment e ON e.site_id = hs.site_id
GROUP  BY hs.site_name, hs.city
ORDER  BY total_enrolments DESC;
GO

/* ----------------------------------------------------------------------------
   QUERY 6
   Trials with an amended protocol (more than one consent version issued).
   ---------------------------------------------------------------------------- */
SELECT ct.trial_name,
       ct.status,
       COUNT(cv.consent_version_id) AS version_count
FROM   dbo.ClinicalTrial  ct
JOIN   dbo.ConsentVersion cv ON cv.trial_id = ct.trial_id
GROUP  BY ct.trial_name, ct.status
HAVING COUNT(cv.consent_version_id) > 1
ORDER  BY version_count DESC;
GO

/* ----------------------------------------------------------------------------
   QUERY 7
   Most recently enrolled participant at each site (across all trials).
   RANK partitioned by site, newest enrolment first; keep rank 1. Tied dates
   share rank 1, so joint newest participants would all be returned.
   Enrollment stores trial_id and site_id directly, so ClinicalTrial and
   HospitalSite are joined straight off it - no TrialSite join needed.
   ---------------------------------------------------------------------------- */
WITH RankedEnrolments AS (
    SELECT p.study_code,
           ct.trial_name,
           hs.site_name,
           e.enrolment_date,
           RANK() OVER (PARTITION BY hs.site_id
                        ORDER BY e.enrolment_date DESC) AS rn
    FROM   dbo.Enrollment    e
    JOIN   dbo.Participant   p  ON p.participant_id = e.participant_id
    JOIN   dbo.ClinicalTrial ct ON ct.trial_id      = e.trial_id
    JOIN   dbo.HospitalSite  hs ON hs.site_id       = e.site_id
)
SELECT study_code,
       trial_name,
       site_name,
       enrolment_date
FROM   RankedEnrolments
WHERE  rn = 1
ORDER  BY site_name;
GO



/* ###################### Metadata (data dictionary) ###################### */


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
