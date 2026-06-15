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
