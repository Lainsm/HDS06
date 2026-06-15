/* ============================================================================
   02_insert_reference_data.sql
   Reference data supplied with the brief (the five sheets).
   Run AFTER 01_create_tables.sql.
   FK look-ups use subqueries on business keys - no hard-coded IDENTITY values.
   ============================================================================ */

USE HDS_ClinicalTrial;
GO

/* ----------------------------------------------------------------------------
   ClinicalTrial  (3 trials)
   ---------------------------------------------------------------------------- */
INSERT INTO dbo.ClinicalTrial (registration_number, trial_name, phase, status, start_date, end_date)
VALUES
 ('ISRCTN10234567', N'CARDIOPROTECT: Cardiac Rehabilitation in Post-MI Patients', 'III', 'active',     '2023-03-01', NULL),
 ('ISRCTN20345678', N'BREATHE: Pulmonary Rehabilitation in COPD',                 'II',  'recruiting', '2024-06-01', NULL),
 ('ISRCTN30456789', N'MOBILISE: Early Mobilisation Following Hip Replacement',    'II',  'completed',  '2021-01-01', '2024-12-31');
GO

/* ----------------------------------------------------------------------------
   HospitalSite  (3 sites)
   ---------------------------------------------------------------------------- */
INSERT INTO dbo.HospitalSite (site_code, site_name, city, country)
VALUES
 ('WBK-GEN', N'Westbrook General Hospital',   N'London',     N'England'),
 ('STK-NOR', N'St Katherine''s Hospital',     N'Manchester', N'England'),
 ('RDG-COM', N'Ridgeway Community Hospital',  N'Bristol',    N'England');
GO

/* ----------------------------------------------------------------------------
   Participant  (5 pseudonymised participants)
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
   InactivationReason  (6 standardised reasons)
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
   ConsentVersion  (4 versions across the 3 trials)
   trial_id is looked up from the registration number.
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
