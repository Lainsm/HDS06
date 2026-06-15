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
