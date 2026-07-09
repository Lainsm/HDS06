# HDS_ClinicalTrial — Database Structure

Westbrook University Hospitals NHS Trust, Clinical Trial Participant Registry.
SQL Server (T-SQL). Source: `script/HDS_DB_LAINSBURY_2026.sql`.

## Overview

Eight tables. Every table has a surrogate `INT IDENTITY` primary key plus at
least one business (natural) unique key, **except** `TrialSite`, which uses
a composite natural primary key `(trial_id, site_id)` — the pairing itself
is the identity of that row, so a surrogate column would be redundant.

| Table | Purpose |
|---|---|
| `ClinicalTrial` | One row per trial |
| `HospitalSite` | One row per hospital site |
| `Participant` | One row per pseudonymised participant (no names held) |
| `InactivationReason` | Controlled vocabulary of reasons a participant leaves a trial |
| `TrialSite` | Link table resolving the M:N between trials and sites |
| `ConsentVersion` | Every approved version of a trial's consent form |
| `Enrollment` | A participant enrolled in a trial at a specific site |
| `ConsentSigning` | Append-only log of every consent signing event |

## Entity relationships

```
ClinicalTrial ──< TrialSite >── HospitalSite
     │                                │
     │                                │
     ├──< ConsentVersion              │
     │         │                      │
     │         │                      │
     │         └──< ConsentSigning    │
     │                   │            │
     │                   │            │
     └──< Enrollment >───┴────────────┘
              │
              │
        Participant
```

- `Enrollment` carries `(trial_id, site_id)` as a **composite FK straight to
  `TrialSite`**, so an enrolment can only reference a site that actually
  runs that trial.
- `ConsentSigning` links to `Enrollment` (not directly to `Participant` or
  `ClinicalTrial`) and separately to `ConsentVersion`. It picks up the trial
  transitively through `Enrollment.trial_id`.

## Tables

### ClinicalTrial

One row per trial, identified externally by its ISRCTN registration number.

| Column | Type | Notes |
|---|---|---|
| `trial_id` | `INT IDENTITY(1,1)` | PK |
| `registration_number` | `VARCHAR(20)` | Business key (ISRCTN), `UNIQUE` |
| `trial_name` | `NVARCHAR(150)` | |
| `phase` | `VARCHAR(4)` | `CHECK IN ('I','II','III','IV')` |
| `status` | `VARCHAR(20)` | `CHECK IN ('recruiting','active','completed','suspended')` |
| `start_date` | `DATE` | |
| `end_date` | `DATE NULL` | `NULL` = trial still ongoing |

Constraint: `end_date IS NULL OR end_date >= start_date`.

### HospitalSite

One row per hospital site, identified operationally by its short site code.

| Column | Type | Notes |
|---|---|---|
| `site_id` | `INT IDENTITY(1,1)` | PK |
| `site_code` | `VARCHAR(10)` | Business key, `UNIQUE` |
| `site_name` | `NVARCHAR(100)` | |
| `city` | `NVARCHAR(60)` | |
| `country` | `NVARCHAR(60)` | |

### Participant

One pseudonymised participant per row; no names are held (data minimisation).

| Column | Type | Notes |
|---|---|---|
| `participant_id` | `INT IDENTITY(1,1)` | PK |
| `study_code` | `VARCHAR(15)` | Pseudonymous business key, `UNIQUE` — the only identifier ever exposed outside the research office linkage list |
| `date_of_birth` | `DATE` | |
| `sex_at_birth` | `VARCHAR(10)` | `CHECK IN ('Male','Female')` |
| `registration_date` | `DATE` | |

Constraint: `date_of_birth < registration_date`.

### InactivationReason

Controlled vocabulary of standardised reasons a participant leaves a trial,
for consistent cross-trial reporting.

| Column | Type | Notes |
|---|---|---|
| `reason_id` | `INT IDENTITY(1,1)` | PK |
| `reason_code` | `VARCHAR(30)` | Business key, `UNIQUE` |
| `reason_description` | `NVARCHAR(255)` | |

Seed values: `consent_withdrawn`, `eligibility_lost`, `clinician_decision`,
`death`, `lost_to_follow_up`, `trial_completed`.

### TrialSite

Link table resolving the many-to-many between trials and sites; carries the
recruitment open/close dates of that pairing.

| Column | Type | Notes |
|---|---|---|
| `trial_id` | `INT` | PK part 1, FK → `ClinicalTrial` |
| `site_id` | `INT` | PK part 2, FK → `HospitalSite` |
| `opened_date` | `DATE` | Site opened for recruitment on this trial |
| `closed_date` | `DATE NULL` | `NULL` = still open |

No surrogate ID column — `(trial_id, site_id)` is a composite natural PK,
since the pairing itself is the row's identity.

### ConsentVersion

Every approved version of a trial's consent form, with effective date and
full wording. Old versions are never overwritten.

| Column | Type | Notes |
|---|---|---|
| `consent_version_id` | `INT IDENTITY(1,1)` | PK |
| `trial_id` | `INT` | FK → `ClinicalTrial`; ties the wording to the trial it belongs to |
| `version_number` | `INT` | `CHECK > 0` |
| `effective_from` | `DATE` | |
| `wording_text` | `NVARCHAR(MAX)` | Full consent text, preserved verbatim per version |

Constraint: `UNIQUE (trial_id, version_number)` — version numbers are
scoped per trial, so each trial independently starts at v1.

### Enrollment

A participant's enrolment in a trial at a specific site. Exit is recorded
in place; the original row is never deleted.

| Column | Type | Notes |
|---|---|---|
| `enrollment_id` | `INT IDENTITY(1,1)` | PK |
| `participant_id` | `INT` | FK → `Participant` |
| `trial_id` | `INT` | Composite FK part → `TrialSite` |
| `site_id` | `INT` | Composite FK part → `TrialSite` |
| `enrolment_date` | `DATE` | |
| `inactivation_date` | `DATE NULL` | `NULL` = still active |
| `inactivation_reason_id` | `INT NULL` | FK → `InactivationReason`; `NULL` = still active |

Constraints:
- `UNIQUE (participant_id, trial_id, site_id)` — can't enrol in the same
  trial-site twice.
- `inactivation_date` and `inactivation_reason_id` must be both present or
  both absent.
- `inactivation_date >= enrolment_date`.
- Filtered unique index `UX_Enrollment_OneActivePerParticipant` on
  `participant_id` `WHERE inactivation_date IS NULL` — a participant may be
  actively enrolled in only **one** trial at a time; past (inactivated)
  enrolments are unrestricted, preserving full history.

### ConsentSigning

Append-only log of every consent signing event, protected by an
`INSTEAD OF UPDATE, DELETE` trigger (`trg_ConsentSigning_AppendOnly`) —
any attempt to modify or delete a row throws error 51000.

| Column | Type | Notes |
|---|---|---|
| `consent_signing_id` | `INT IDENTITY(1,1)` | PK |
| `enrollment_id` | `INT` | FK → `Enrollment` (carries participant + trial + site transitively) |
| `consent_version_id` | `INT` | FK → `ConsentVersion` |
| `signed_date` | `DATE` | |
| `witnessed_by` | `NVARCHAR(100)` | |

Constraint: `UNIQUE (enrollment_id, consent_version_id)` — the same
enrolment can't sign the same version twice, but re-consenting to a *new*
version after a protocol change is a new row.

## Design notes

- **Business keys everywhere.** Seed data `INSERT`s resolve surrogate FKs
  via subqueries on business keys (`registration_number`, `study_code`,
  `site_code`, `reason_code`, `version_number`) rather than hardcoding
  `IDENTITY` values, so the script is safe to re-run and doesn't depend on
  insert order.
- **History is preserved, never overwritten.** Enrolments, consent
  versions, and consent signings are all append-only in spirit —
  inactivation/re-consent is modelled as a new state or new row, not an
  edit to the old one. `ConsentSigning` enforces this at the database
  level with a trigger.
- **`ConsentVersion` vs `ConsentSigning`.** These are deliberately separate:
  `ConsentVersion` is the trial-level catalogue of consent wording ("what
  versions exist for this trial"); `ConsentSigning` is the participant-level
  event log ("who signed which version, and when"). Neither table
  duplicates the other's job.
