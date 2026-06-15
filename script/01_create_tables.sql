/* ============================================================================
   01_create_tables.sql
   Schema for the Clinical Trial Participant Registry.
   Run AFTER 00_create_database.sql.

   Design summary
   --------------
   ClinicalTrial      - one row per trial
   HospitalSite       - one row per hospital site
   Participant        - one row per pseudonymised participant (no names held)
   InactivationReason - standardised reasons a participant leaves a trial
   TrialSite          - link table resolving ClinicalTrial <-> HospitalSite (M:N)
   ConsentVersion     - each approved version of a trial's consent form
   Enrollment         - a participant enrolled in a trial at a specific site
   ConsentSigning     - append-only record of every consent signing event

   Every table has a surrogate INT IDENTITY primary key plus one or more
   business (natural) UNIQUE keys, as recommended in the brief.
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
    registration_number VARCHAR(20)         NOT NULL,   -- ISRCTN business key
    trial_name          NVARCHAR(150)       NOT NULL,
    phase               VARCHAR(4)          NOT NULL,
    status              VARCHAR(20)         NOT NULL,
    start_date          DATE                NOT NULL,
    end_date            DATE                NULL,        -- NULL = trial ongoing
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
   Participant  (pseudonymised - no names stored)
   ---------------------------------------------------------------------------- */
CREATE TABLE dbo.Participant (
    participant_id    INT IDENTITY(1,1) NOT NULL,
    study_code        VARCHAR(15)       NOT NULL,   -- pseudonymous business key
    date_of_birth     DATE              NOT NULL,
    sex_at_birth      VARCHAR(10)       NOT NULL,
    registration_date DATE              NOT NULL,
    CONSTRAINT PK_Participant        PRIMARY KEY (participant_id),
    CONSTRAINT UQ_Participant_code   UNIQUE (study_code),
    CONSTRAINT CK_Participant_sex    CHECK (sex_at_birth IN ('Male','Female','Intersex','Unknown')),
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
