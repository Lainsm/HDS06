/* ============================================================================
   - HDS_DB_LAINSBURY_2026.sql
   - Westbrook University Hospitals NHS Trust, Clinical Trial Participant Registry
   - Microsoft SQL Server (T-SQL)
   - Ran on Linux (Ubuntu 26.04)without error in VS Code using mssql extension.
   ============================================================================ */


/* ###################### 00_create_database.sql ###################### */

/* ============================================================================
   00_create_database.sql
   Westbrook University Hospitals NHS Trust, Clinical Trial Participant Registry
   
   - Script to create the database & tables. Used an IF to allow you to run this script\ 
   even if you already created the DB from previous classmate assignments.
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


/* ###################### 01_create_tables.sql ###################### */

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
   business (natural) UNIQUE keys (as per recommendation in the brief).
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
    CONSTRAINT CK_ClinicalTrial_phase  CHECK (phase IN ('I','II','III','IV')),
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
    CONSTRAINT CK_Participant_sex    CHECK (sex_at_birth IN ('Male','Female','Intersex','Unknown')), -- controlled vocabulary for sex at birth (not gender); 'Intersex'/'Unknown' cover real registry cases
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
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.TrialSite (
    trial_site_id INT IDENTITY(1,1) NOT NULL,
    trial_id      INT               NOT NULL,
    site_id       INT               NOT NULL,
    opened_date   DATE              NOT NULL,   -- site opened for recruitment
    closed_date   DATE              NULL,        -- NULL = still open
    CONSTRAINT PK_TrialSite        PRIMARY KEY (trial_site_id),
    CONSTRAINT UQ_TrialSite        UNIQUE (trial_id, site_id),
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
   The enrolment points at a TrialSite row, so the trial AND the site are
   captured together and an enrolment can only reference a site that actually
   runs the trial. The original enrolment row is preserved; leaving the trial
   only sets inactivation_date / inactivation_reason_id.
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.Enrollment (
    enrollment_id         INT IDENTITY(1,1) NOT NULL,
    participant_id        INT               NOT NULL,
    trial_site_id         INT               NOT NULL,
    enrolment_date        DATE              NOT NULL,
    inactivation_date     DATE              NULL,   -- NULL = still active
    inactivation_reason_id INT              NULL,   -- NULL = still active
    CONSTRAINT PK_Enrollment             PRIMARY KEY (enrollment_id),
    CONSTRAINT FK_Enrollment_participant FOREIGN KEY (participant_id)         REFERENCES dbo.Participant(participant_id),
    CONSTRAINT FK_Enrollment_trialsite   FOREIGN KEY (trial_site_id)          REFERENCES dbo.TrialSite(trial_site_id),
    CONSTRAINT FK_Enrollment_reason      FOREIGN KEY (inactivation_reason_id) REFERENCES dbo.InactivationReason(reason_id),
    /* A participant cannot be enrolled in the same trial-site twice. */
    CONSTRAINT UQ_Enrollment             UNIQUE (participant_id, trial_site_id),
    /* Inactivation date and reason must both be present or both absent. */
    CONSTRAINT CK_Enrollment_inactivation CHECK (
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
    CONSTRAINT UQ_ConsentSigning          UNIQUE (enrollment_id, consent_version_id)
);
GO


/* ###################### 02_insert_reference_data.sql ###################### */

/* ============================================================================
   
   Reference data supplied (CSVs supplied).

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
   ConsentVersion - trial_id is looked up from the registration number.
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


/* ###################### 03_insert_operational_data.sql ###################### */

/* ============================================================================
   03_insert_operational_data.sql
   Operational data added by the designer to make the seven queries meaningful:
     - TrialSite      : which sites run which trials (and when they opened/closed)
     - Enrollment     : participants enrolled in trials at sites, incl. history
     - ConsentSigning : append-only consent signing events (incl. re-consent)
   Run AFTER 02_insert_reference_data.sql.
   All FK look-ups use subqueries on business keys.
   ============================================================================ */

USE HDS_ClinicalTrial;
GO

/* ----------------------------------------------------------------------------
   TrialSite - link trials to sites (each trial at >= 2 sites where possible)
     CARDIOPROTECT -> WBK-GEN, STK-NOR
     BREATHE       -> WBK-GEN, RDG-COM   (RDG-COM intentionally has 0 enrolments)
     MOBILISE      -> STK-NOR            (site closed when the trial completed)
   ---------------------------------------------------------------------------- */
INSERT INTO dbo.TrialSite (trial_id, site_id, opened_date, closed_date)
VALUES
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN10234567'),
  (SELECT site_id  FROM dbo.HospitalSite  WHERE site_code='WBK-GEN'), '2023-03-01', NULL),
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN10234567'),
  (SELECT site_id  FROM dbo.HospitalSite  WHERE site_code='STK-NOR'), '2023-04-01', NULL),
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN20345678'),
  (SELECT site_id  FROM dbo.HospitalSite  WHERE site_code='WBK-GEN'), '2024-06-01', NULL),
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN20345678'),
  (SELECT site_id  FROM dbo.HospitalSite  WHERE site_code='RDG-COM'), '2024-07-01', NULL),
 ((SELECT trial_id FROM dbo.ClinicalTrial WHERE registration_number='ISRCTN30456789'),
  (SELECT site_id  FROM dbo.HospitalSite  WHERE site_code='STK-NOR'), '2021-01-01', '2024-12-31');
GO

/* ----------------------------------------------------------------------------
   Helper pattern for enrolments
   The trial_site_id is resolved from (registration_number, site_code) so we
   never hard-code IDENTITY values.
   ---------------------------------------------------------------------------- */

/* WBK-001 : active in CARDIOPROTECT at Westbrook General (re-consents later) */
INSERT INTO dbo.Enrollment (participant_id, trial_site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant WHERE study_code='WBK-001'),
  (SELECT ts.trial_site_id FROM dbo.TrialSite ts
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     JOIN dbo.HospitalSite  hs ON hs.site_id  = ts.site_id
     WHERE ct.registration_number='ISRCTN10234567' AND hs.site_code='WBK-GEN'),
  '2023-03-15', NULL, NULL);

/* WBK-002 : completed MOBILISE (past), now active in CARDIOPROTECT at St Katherine's */
INSERT INTO dbo.Enrollment (participant_id, trial_site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant WHERE study_code='WBK-002'),
  (SELECT ts.trial_site_id FROM dbo.TrialSite ts
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     JOIN dbo.HospitalSite  hs ON hs.site_id  = ts.site_id
     WHERE ct.registration_number='ISRCTN30456789' AND hs.site_code='STK-NOR'),
  '2021-02-01', '2024-12-31',
  (SELECT reason_id FROM dbo.InactivationReason WHERE reason_code='trial_completed'));

INSERT INTO dbo.Enrollment (participant_id, trial_site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant WHERE study_code='WBK-002'),
  (SELECT ts.trial_site_id FROM dbo.TrialSite ts
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     JOIN dbo.HospitalSite  hs ON hs.site_id  = ts.site_id
     WHERE ct.registration_number='ISRCTN10234567' AND hs.site_code='STK-NOR'),
  '2025-01-10', NULL, NULL);

/* WBK-003 : withdrew from BREATHE (past), now active in CARDIOPROTECT - needed for Query 3 */
INSERT INTO dbo.Enrollment (participant_id, trial_site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant WHERE study_code='WBK-003'),
  (SELECT ts.trial_site_id FROM dbo.TrialSite ts
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     JOIN dbo.HospitalSite  hs ON hs.site_id  = ts.site_id
     WHERE ct.registration_number='ISRCTN20345678' AND hs.site_code='WBK-GEN'),
  '2024-06-10', '2024-09-15',
  (SELECT reason_id FROM dbo.InactivationReason WHERE reason_code='consent_withdrawn'));

INSERT INTO dbo.Enrollment (participant_id, trial_site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant WHERE study_code='WBK-003'),
  (SELECT ts.trial_site_id FROM dbo.TrialSite ts
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     JOIN dbo.HospitalSite  hs ON hs.site_id  = ts.site_id
     WHERE ct.registration_number='ISRCTN10234567' AND hs.site_code='WBK-GEN'),
  '2024-10-01', NULL, NULL);

/* WBK-004 : died during CARDIOPROTECT at St Katherine's (inactive) */
INSERT INTO dbo.Enrollment (participant_id, trial_site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant WHERE study_code='WBK-004'),
  (SELECT ts.trial_site_id FROM dbo.TrialSite ts
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     JOIN dbo.HospitalSite  hs ON hs.site_id  = ts.site_id
     WHERE ct.registration_number='ISRCTN10234567' AND hs.site_code='STK-NOR'),
  '2023-05-20', '2023-11-10',
  (SELECT reason_id FROM dbo.InactivationReason WHERE reason_code='death'));

/* WBK-005 : active in BREATHE at Westbrook General */
INSERT INTO dbo.Enrollment (participant_id, trial_site_id, enrolment_date, inactivation_date, inactivation_reason_id)
VALUES
 ((SELECT participant_id FROM dbo.Participant WHERE study_code='WBK-005'),
  (SELECT ts.trial_site_id FROM dbo.TrialSite ts
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     JOIN dbo.HospitalSite  hs ON hs.site_id  = ts.site_id
     WHERE ct.registration_number='ISRCTN20345678' AND hs.site_code='WBK-GEN'),
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
     JOIN dbo.Participant p ON p.participant_id = e.participant_id
     JOIN dbo.TrialSite  ts ON ts.trial_site_id = e.trial_site_id
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     WHERE p.study_code='WBK-001' AND ct.registration_number='ISRCTN10234567'),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = cv.trial_id
     WHERE ct.registration_number='ISRCTN10234567' AND cv.version_number=1),
  '2023-03-15', N'Nurse A. Okafor');

/* WBK-001 - CARDIOPROTECT v2 re-consent after protocol amendment */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     JOIN dbo.Participant p ON p.participant_id = e.participant_id
     JOIN dbo.TrialSite  ts ON ts.trial_site_id = e.trial_site_id
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     WHERE p.study_code='WBK-001' AND ct.registration_number='ISRCTN10234567'),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = cv.trial_id
     WHERE ct.registration_number='ISRCTN10234567' AND cv.version_number=2),
  '2024-01-20', N'Nurse A. Okafor');

/* WBK-002 - MOBILISE v1 */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     JOIN dbo.Participant p ON p.participant_id = e.participant_id
     JOIN dbo.TrialSite  ts ON ts.trial_site_id = e.trial_site_id
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     WHERE p.study_code='WBK-002' AND ct.registration_number='ISRCTN30456789'),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = cv.trial_id
     WHERE ct.registration_number='ISRCTN30456789' AND cv.version_number=1),
  '2021-02-01', N'Dr R. Mensah');

/* WBK-002 - CARDIOPROTECT v2 (current version at time of enrolment) */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     JOIN dbo.Participant p ON p.participant_id = e.participant_id
     JOIN dbo.TrialSite  ts ON ts.trial_site_id = e.trial_site_id
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     WHERE p.study_code='WBK-002' AND ct.registration_number='ISRCTN10234567'),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = cv.trial_id
     WHERE ct.registration_number='ISRCTN10234567' AND cv.version_number=2),
  '2025-01-10', N'Nurse S. Patel');

/* WBK-003 - BREATHE v1 */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     JOIN dbo.Participant p ON p.participant_id = e.participant_id
     JOIN dbo.TrialSite  ts ON ts.trial_site_id = e.trial_site_id
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     WHERE p.study_code='WBK-003' AND ct.registration_number='ISRCTN20345678'),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = cv.trial_id
     WHERE ct.registration_number='ISRCTN20345678' AND cv.version_number=1),
  '2024-06-10', N'Nurse A. Okafor');

/* WBK-003 - CARDIOPROTECT v2 (current at enrolment) */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     JOIN dbo.Participant p ON p.participant_id = e.participant_id
     JOIN dbo.TrialSite  ts ON ts.trial_site_id = e.trial_site_id
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     WHERE p.study_code='WBK-003' AND ct.registration_number='ISRCTN10234567'),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = cv.trial_id
     WHERE ct.registration_number='ISRCTN10234567' AND cv.version_number=2),
  '2024-10-01', N'Nurse S. Patel');

/* WBK-004 - CARDIOPROTECT v1 (enrolled before the amendment) */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     JOIN dbo.Participant p ON p.participant_id = e.participant_id
     JOIN dbo.TrialSite  ts ON ts.trial_site_id = e.trial_site_id
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     WHERE p.study_code='WBK-004' AND ct.registration_number='ISRCTN10234567'),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = cv.trial_id
     WHERE ct.registration_number='ISRCTN10234567' AND cv.version_number=1),
  '2023-05-20', N'Dr R. Mensah');

/* WBK-005 - BREATHE v1 */
INSERT INTO dbo.ConsentSigning (enrollment_id, consent_version_id, signed_date, witnessed_by)
VALUES
 ((SELECT e.enrollment_id FROM dbo.Enrollment e
     JOIN dbo.Participant p ON p.participant_id = e.participant_id
     JOIN dbo.TrialSite  ts ON ts.trial_site_id = e.trial_site_id
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = ts.trial_id
     WHERE p.study_code='WBK-005' AND ct.registration_number='ISRCTN20345678'),
  (SELECT cv.consent_version_id FROM dbo.ConsentVersion cv
     JOIN dbo.ClinicalTrial ct ON ct.trial_id = cv.trial_id
     WHERE ct.registration_number='ISRCTN20345678' AND cv.version_number=1),
  '2024-08-05', N'Nurse S. Patel');
GO


/* ###################### 05_append_only_trigger.sql ###################### */

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


/* ###################### 04_queries.sql ###################### */

/* ============================================================================
   04_queries.sql
   The seven clinical / research queries.
   Run AFTER 03_insert_operational_data.sql.
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
   ---------------------------------------------------------------------------- */
SELECT ct.trial_name,
       e.enrolment_date,
       e.inactivation_date,
       ir.reason_code
FROM   dbo.Enrollment       e
JOIN   dbo.Participant      p  ON p.participant_id = e.participant_id
JOIN   dbo.TrialSite        ts ON ts.trial_site_id = e.trial_site_id
JOIN   dbo.ClinicalTrial    ct ON ct.trial_id      = ts.trial_id
LEFT   JOIN dbo.InactivationReason ir ON ir.reason_id = e.inactivation_reason_id
WHERE  p.study_code = 'WBK-003'
ORDER  BY e.enrolment_date;
GO

/* ----------------------------------------------------------------------------
   QUERY 4
   Audit of currently ACTIVE enrolments: participant, trial, site, enrol date.
   Order by trial name then enrolment date.
   ---------------------------------------------------------------------------- */
SELECT p.study_code,
       ct.trial_name,
       hs.site_name,
       e.enrolment_date
FROM   dbo.Enrollment    e
JOIN   dbo.Participant   p  ON p.participant_id = e.participant_id
JOIN   dbo.TrialSite     ts ON ts.trial_site_id = e.trial_site_id
JOIN   dbo.ClinicalTrial ct ON ct.trial_id      = ts.trial_id
JOIN   dbo.HospitalSite  hs ON hs.site_id        = ts.site_id
WHERE  e.inactivation_date IS NULL
ORDER  BY ct.trial_name, e.enrolment_date;
GO

/* ----------------------------------------------------------------------------
   QUERY 5
   Total enrolments ever, per site, INCLUDING sites with none.
   LEFT JOIN from HospitalSite preserves sites with zero enrolments;
   COUNT(e.enrollment_id) counts rows, not NULLs, so empty sites score 0.
   ---------------------------------------------------------------------------- */
SELECT hs.site_name,
       hs.city,
       COUNT(e.enrollment_id) AS total_enrolments
FROM   dbo.HospitalSite hs
LEFT   JOIN dbo.TrialSite  ts ON ts.site_id        = hs.site_id
LEFT   JOIN dbo.Enrollment e  ON e.trial_site_id   = ts.trial_site_id
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
   ROW_NUMBER partitioned by site, newest enrolment first; keep rank 1.
   ---------------------------------------------------------------------------- */
WITH RankedEnrolments AS (
    SELECT p.study_code,
           ct.trial_name,
           hs.site_name,
           e.enrolment_date,
           ROW_NUMBER() OVER (PARTITION BY hs.site_id
                              ORDER BY e.enrolment_date DESC, e.enrollment_id DESC) AS rn
    FROM   dbo.Enrollment    e
    JOIN   dbo.Participant   p  ON p.participant_id = e.participant_id
    JOIN   dbo.TrialSite     ts ON ts.trial_site_id = e.trial_site_id
    JOIN   dbo.ClinicalTrial ct ON ct.trial_id      = ts.trial_id
    JOIN   dbo.HospitalSite  hs ON hs.site_id        = ts.site_id
)
SELECT study_code,
       trial_name,
       site_name,
       enrolment_date
FROM   RankedEnrolments
WHERE  rn = 1
ORDER  BY site_name;
GO



/* ###################### 06_metadata.sql ###################### */


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
