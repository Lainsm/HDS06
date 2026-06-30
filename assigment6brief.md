### **Assignment: Designing and Querying a Clinical Trial Participant Registry**

## **Assignment overview**

This assignment assesses your ability to apply advanced data retrieval
skills to design a relational database from a real-world specification,
implement that design in SQL, query the database to answer realistic
research questions, and reflect critically on the design decisions and
data governance implications. It should show a critical understanding of
database design standards and data linkage, alongside the ability to
critically evaluate data flows and demonstrate expertise in metadata
development. Your work should also evidence your ability to translate
complex clinical questions into SQL.

You are given a scenario describing the data management needs of a
clinical trials unit. You must design a database schema to meet those
needs, write SQL to build and populate the database, write SQL queries
framed as requests from clinical staff, and write a reflective account
on the design and governance considerations the scenario raises.

This assignment is assessed against the following Module 6 learning
outcomes:

- Retrieve relevant data from databases (through creation of structured
  queries), and critically-review complex datasets.

- Design and specify data flows, collection, storage and collation
  mechanisms for both qualitative and quantitative data.

- Undertake linkage of health and care data accurately and in accordance
  with the relevant information governance requirements.

- Extract, import, clean, and manipulate a wide range of quantitative
  and qualitative data.

## **The Scenario**

**Westbrook University Hospitals NHS Trust --- Clinical Trial
Participant Registry**

Westbrook University Hospitals NHS Trust runs multiple clinical trials
simultaneously across several of its hospital sites. The trust currently
manages trial participation using spreadsheets and paper records, which
has created significant data quality and audit trail problems. You have
been asked to design a relational database to replace this system.

The trust runs multiple clinical trials at any one time. Each trial has
a unique registration number, a name, a phase (I, II, III, or IV), a
status (such as recruiting, active, completed, or suspended) and a
start date. Current trials are ongoing and therefore have no end date
yet.

Each trial runs at one or more of the trust\'s hospital sites, and each
hospital site may host multiple trials simultaneously. The trust needs
to record which sites are participating in which trials, and when each
site opened and closed for recruitment on a given trial. Some sites are
still open for recruitment and have no closing date yet.

Participants are recruited from the trust\'s patient population. Each
participant is assigned a unique study code for pseudonymisation
purposes; names are not stored in the trial database. The trust records
each participant\'s date of birth, sex at birth, and the date they first
registered with the trust\'s research office. A participant may have
taken part in previous trials but may only be actively enrolled in one
trial at a time.

When a participant is enrolled in a trial they are enrolled at a
specific site. The database must record when the enrolment began. Some
participants leave the trial before it ends; the database must record
when this occurred and the reason, using a standardised set of values so
that data can be reported consistently across trials. The original
enrolment record must be preserved. A participant who left a previous
trial and later joins a new one will have more than one enrolment
record.

Clinical trials use a consent form that is tied to the trial protocol.
When the trial protocol changes --- which is common --- a new version of
the consent form must be approved and issued. The database must store
each version of the consent form for each trial, including when that
version came into effect and the full wording of the form. Old versions
must be preserved and never overwritten.

Each participant must sign the current consent form when they are
enrolled. If the protocol changes during their participation and a new
consent form is issued, they must sign the new version too. The database
must record every consent signing event --- when it happened, who
witnessed it, and which version of the form was signed. These records
must never be updated or deleted. A participant who has re-consented
after a protocol change will have more than one consent record for the
same enrolment.

## **Data Provided**

You will receive a Microsoft Excel file alongside this brief. The file
contains five sheets of reference data for the scenario. After you
design and create your tables you should add this data to your tables
using INSERT statements.

The sheets provided are:

- ClinicalTrial --- three trial records covering different phases and
  statuses

- HospitalSite --- three hospital sites

- InactivationReason --- six standardised reasons for a participant
  leaving a trial

- Participant --- five pseudonymised participant records

- ConsentVersion --- four consent form versions across the three trials

## **Submission structure**

Your submission must consist of two files:

## **4.1 Word Document Report**

> A Word document of 2,500 to 3,000 words or equivalent, structured as
> follows:

- Part 1: Database Design

- Part 2: SQL --- INSERT statements and six queries

- Part 3: Reflection

- Completed coversheet (see end of this document)

> SQL code included in the report counts as word equivalent. For each
> query, the clinical question, the SQL code, the screenshot, and the
> discussion together count as approximately 150 words equivalent. One
> INSERT statement per table counts as approximately 50 words
> equivalent. Written prose in all other sections is counted normally.
>
> Please include your total word count on the coversheet, noting the
> prose word count and the number of queries and INSERT statements
> separately.

## **4.2 SQL Script File**

> A single .sql file containing all SQL statements in the order they
> would need to be run: CREATE TABLE statements, all INSERT statements,
> and all six queries. The script must be runnable in Microsoft SQL
> Server. Name the file using the convention: HDS_DB_YOURNAME_2026.sql
>
> Your marker will run this script independently. Ensure it executes
> without errors from start to finish.

## **Assignment Task: Part 1 --- Database Design (40%)**

Using the scenario in Section 2, design a relational database schema.
You should not refer to any external sources for table names or column
names --- the design should be your own, derived from reading the
scenario carefully.

Your design section must include all four of the following components.

## **5.1 Entity Relationship Diagram (10%)**

> Produce an ERD showing all entities in your schema with their primary
> keys, foreign keys, and the relationships between them. Standard ERD
> notation should be used for cardinality (one-to-many, many-to-many).
>
> The diagram may be drawn using any software tool (draw.io, Lucidchart,
> Visio, or similar) or drawn by hand and scanned. A hand-drawn and
> scanned diagram is fully acceptable; clarity matters more than the
> tool used. Insert the diagram directly into the Word document.

## **5.2 Table Descriptions (10%)**

> Create a list of a tables and for each table in your design, provide:

- The table name and a brief description of what it holds and why it
  exists

- A list of all columns with their data types and constraints (NOT NULL,
  NULL, PRIMARY KEY, FOREIGN KEY, DEFAULT)

- Where your primary key is a subsidiary key, an explanation of what the
  unique key is and why it was chosen. If it is not a subsidiary key
  then explanation of the primary key itself. I suggest that for all
  tables you have a primary key which is an IDENTITY and one or more
  unique keys. For all unique keys an explanation is needed.

- A description of any check constrains and why was it created.

> Present this clearly --- as a written description, a structured list,
> or a formatted table. There is no single required format.

## **5.3 NULL and NOT NULL Decisions (10%)**

> For any column where you have made a deliberate decision about
> nullability --- either allowing NULL or preventing it --- explain your
> reasoning. Do not simply list which columns are nullable. Explain what
> NULL means in that specific context and why that is the correct
> choice.
>
> For example: a column that is NULL when a participant is still active
> and filled in when they leave the trial represents a meaningful
> absence of information. A column that should always have a value ---
> such as a start date --- should be NOT NULL. Both of these decisions
> need justification.

## **5.4 Relationships Between Tables (10%)**

> For each relationship between tables in your schema, state:

- Which tables are related

- The type of relationship (one-to-one,one-to-many, many-to-many)

- Which column or columns form the foreign key

- A brief explanation of what the relationship represents in the context
  of the scenario

> Where a many-to-many relationship exists between two entities, explain
> how you have resolved it in your design.

## **Assignment Task: Part 2 --- SQL (45%)**

## **6.1 INSERT Statements (10%)**

> Using the data provided in the Excel file, write INSERT statements to
> populate your database. For each table, include one INSERT statement
> in the body of your report as evidence that you understand the table
> structure and the foreign key relationships. All remaining INSERT
> statements should be in your .sql script file only.
>
> In addition to the reference data provided, you must also add your own
> data to all the other records you have designed and there should be
> enough data to answer all queries meaningfully. Follow the worked
> example below.

### **Worked Example 1--- Enrolling a participant to a trial**

> The following example shows how to enrol a participant in a trial at a
> specific site, and then record their consent. Study this pattern
> carefully before writing your own INSERT statements. Use subqueries to
> look up ID values rather than hardcoding numbers.
>
> Step 1: Enrol participant WBK-001 in the CARDIOPROTECT trial at
> Westbrook General Hospital.
>
> Step 2: Record the consent signing for that enrolment --- version 1.0
> of the CARDIOPROTECT form.
>
> Follow this pattern to add at more enrolments and their corresponding
> consent events. You must add enough data of your own to answer all
> seven queries. As a minimum ensure the following before attempting the
> queries:

- Link trials to at least two different hospital sites

- WBK-003 has at least one enrolment --- they are referenced
  specifically in Query 3

- At least one participant has signed two different consent versions for
  CARDIOPROTECT; this is needed for Query 6

- Enrolments are spread across at least two different hospital sites ---
  this is needed for Query 5 and Query 7 to return meaningful results

- At least one participant has signed two different consent versions for
  CARDIOPROTECT; this is needed for Query 6 and is also mentioned in the
  worked example

- At least one participant has been inactivated --- so Query 3 returns a
  mix of active and inactive rows

## **6.2 SQL Queries (35%)**

- Write seven SQL queries answering the clinical and research questions
  outlined below. Present each query in your report using the following
  format (please see the worked example below, you can also refer to
  SQLCookbook for many other examples):

- Clinical question --- the request as stated below

- SQL --- your query, formatted clearly

- Screenshot --- a screenshot of the query output from SQL Server

- Discussion --- two or three sentences explaining how the query works,
  followed by one sentence identifying a data quality consideration
  relevant to this result

> Marks are awarded for correctness of the SQL and clarity of the
> discussion.
>
> **Query question 1**
>
> **Clinical question** Before conducting a consent discussion with a
> participant, a research nurse needs to retrieve the current wording of
> the consent form for the CARDIOPROTECT trial --- the version that came
> into effect most recently. Show the version number, the date it came
> into effect, and the full wording text.

### 

> **Query question 2**
>
> **Clinical question** A trial coordinator is preparing a monthly
> status report. She needs a summary showing each trial, its current
> status, how long it has been running in days, and whether it has an
> end date recorded or is still ongoing. Order the results with active
> trials first, then recruiting, then all others.
>
> **Query question 3**
>
> **Clinical question** A research nurse is about to meet with
> participant WBK-003 and wants to see their full trial history, every
> trial they have ever been enrolled in, when they enrolled, whether
> they are still active, and if not why they left. Show the trial name,
> enrolment date, inactivation date, and inactivation reason code,
> ordered by enrolment date. Remember that not every enrolment has an
> inactivation reason, a participant who is still active has none. Think
> carefully about which JOIN type handles this correctly.

**Query question 4**

### **Clinical question** A clinical research associate is auditing active enrolments across all trials. She needs a report showing each currently **active** participant, alongside the trial they are enrolled in, the hospital site where they are based, and the date they enrolled. Order by trial name then enrolment date.

### 

> **Query 5**
>
> **Clinical question** The research director wants to see how many
> participants have ever been enrolled at each hospital site; including
> sites that currently have no enrolments recorded. Show the site name,
> city, and total enrolment count, ordered by count descending.
>
> **Query 6**
>
> **Clinical question** The regulatory affairs team wants to identify
> trials where the protocol has been amended, meaning more than one
> consent version exists. Show the trial name, current status, and the
> number of consent versions issued, ordered by number of versions
> descending. Only show trials where more than one version has been
> recorded.
>
> **Query 7**
>
> **Clinical question** The research governance team wants to identify
> the most recently enrolled participant at each hospital site across
> all trials, to prioritise follow-up contact for new joiners. Show the
> participant study code, trial name, site name, and enrolment date.
> Only show **the most recently** enrolled participant per site.

# **7. Part 3 --- Reflection (15%)**

Answer all three questions below. Each answer should be concise and
specific to this scenario --- general statements about databases will
not score well. Aim for approximately 150 to 200 words per question.

## **Question 1**

The scenario states that participant names are not stored in the
database. Explain why this design decision was made and what
implications it has for how researchers and clinical staff would work
with the data in practice.

## **Question 2**

Identify one situation where the data in this database might be
incomplete or misleading and explain what steps a data manager could
take to identify and address the problem.

## **Question 3**

Participant consent records in this database are designed to be
append-only --- rows must never be updated or deleted. Explain why this
rule exists, what would happen to the integrity of the database if it
were broken, and what technical method you would propose to enforce this
rule at the database level.

Rubric

  ------------------------------------------------------------------------------------------------------------
  **Criterion**   **What is being     **Weighting** **High performance**    **Satisfactory    **Limited
                  assessed**                                                performance**     performance**
  --------------- ----------------- --------------- ----------------------- ----------------- ----------------
  ERD diagram     Your ability to               10% Clear ERD showing all   ERD present and   ERD missing,
                  extract entities                  entities with correct   generally         incomplete, or
                  from a real-life                  notation for primary    correct. Minor    significantly
                  scenario and                      keys, foreign keys, and notation errors   incorrect in
                  generate an ERD                   cardinality. Readable   or missing        structure or
                  using crow\'s                     and well-organised.     elements.         notation.
                  foot notation                                                               

  Table           Your ability to               10% All tables correctly    Most tables       Significant
  descriptions    translate a plain                 identified with         correctly         tables missing
  and column      English scenario                  appropriate columns,    identified.       or incorrectly
  choices         into a correctly                  data types, and         Column choices    structured.
                  structured                        constraints. Each       are reasonable    Column choices
                  relational                        table\'s purpose is     with minor gaps   are poorly
                  database schema.                  clearly and             or errors.        justified or
                  This includes                     specifically explained. Explanations are  absent.
                  identifying the                   Design choices are      present but may   Explanations are
                  correct tables,                   justified with          lack specificity  vague or
                  choosing                          reference to the        or depth.         missing.
                  appropriate                       scenario.                                 
                  column names and                                                            
                  data types,                                                                 
                  applying suitable                                                           
                  constraints, and                                                            
                  clearly                                                                     
                  explaining the                                                              
                  purpose of each                                                             
                  table in the                                                                
                  context of the                                                              
                  scenario.                                                                   

  NULL and NOT    Your                          10% All table column        Most decisions    Decisions are
  NULL decisions  understanding of                  nullable/non-nullable   are correct with  largely
                  what NULL means                   decisions are correctly some              incorrect,
                  in a relational                   applied and explicitly  justification. A  absent, or
                  database and your                 justified. The meaning  few may be        stated without
                  ability to make                   of NULL in each context incorrect or      justification.
                  deliberate,                       is clearly explained    stated without    The meaning of
                  justified                         with reference to the   explanation.      NULL in context
                  decisions about                   scenario.                                 is not
                  nullability of                                                              addressed.
                  the columns .                                                               
                  This criterion                                                              
                  assesses whether                                                            
                  you can                                                                     
                  distinguish                                                                 
                  between a column                                                            
                  that must always                                                            
                  have a value and                                                            
                  one where the                                                               
                  absence of a                                                                
                  value carries                                                               
                  meaning, and                                                                
                  whether you can                                                             
                  explain that                                                                
                  distinction                                                                 
                  clearly with                                                                
                  reference to the                                                            
                  scenario.                                                                   

  Relationships   Your ability to               10% All relationships       Most              Significant
  between tables  identify and                      correctly identified    relationships     relationships
                  correctly                         with type and           correctly         missing or
                  characterise the                  cardinality stated.     identified. May   incorrect.
                  relationships                     Many-to-many            miss one          Many-to-many
                  between tables in                 relationship resolved   relationship or   relationship not
                  the schema ---                    with a link table. Each misidentify a     recognised or
                  including                         relationship explained  type. Some        not resolved
                  one-to-many and                   in context of the       explanation       correctly.
                  many-to-many                      scenario.               provided.         Little or no
                  relationships ---                                                           explanation.
                  and to implement                                                            
                  them correctly                                                              
                  using foreign                                                               
                  keys and, where                                                             
                  necessary, a link                                                           
                  table. This                                                                 
                  criterion also                                                              
                  assesses whether                                                            
                  you can explain                                                             
                  what each                                                                   
                  relationship                                                                
                  represents in the                                                           
                  context of the                                                              
                  scenario rather                                                             
                  than simply                                                                 
                  listing the                                                                 
                  foreign keys.                                                               

  INSERT          Your ability to               10% Correct INSERT          Correct INSERT    Significant
  statements      write correct SQL                 statements for all      statements for    errors in INSERT
                  INSERT statements                 tables. FK lookups use  all tables. FK    statements.
                  that respect the                  subqueries rather than  lookups use       Hardcoded IDs
                  foreign key                       hardcoded IDs.          subqueries rather used.
                  relationships in                  Sufficient data added   than hardcoded    Insufficient
                  your schema. This                 to support all six      IDs. Sufficient   data to support
                  includes looking                  queries. One INSERT per data added to     queries. Script
                  up related IDs by                 table in report;        support all six   missing or
                  code or name                      remainder in .SQL       queries. One      incomplete.
                  using subqueries                  script.                 INSERT per table  
                  rather than                                               in report;        
                  hardcoding                                                remainder in .SQL 
                  integer values,                                           script.           
                  and adding                                                                  
                  sufficient data                                                             
                  to the database                                                             
                  to support all                                                              
                  six queries. This                                                           
                  criterion also                                                              
                  assesses whether                                                            
                  you follow the                                                              
                  correct                                                                     
                  submission format                                                           
                  --- one INSERT                                                              
                  per table in the                                                            
                  report, the                                                                 
                  remainder in the                                                            
                  .SQL script.                                                                

  SQL queries     Your ability to               35% All queries correctly   Most queries      Significant
                  translate                         written and producing   correct with      errors in
                  realistic                         expected output. Each   minor errors.     multiple
                  clinical and                      presented in cookbook   Cookbook format   queries.
                  research                          format with clear       followed but      Discussion
                  questions into                    discussion explaining   discussion may    absent or
                  correct SQL                       the query logic and a   lack depth or     superficial. Few
                  queries, and to                   specific, relevant data miss some data    or no
                  demonstrate that                  quality observation.    quality           screenshots.
                  you understand                    Screenshots provided    considerations.   Cookbook format
                  what each query                   for all queries.        Most screenshots  not followed.
                  is doing. This                                            provided.         
                  criterion                                                                   
                  assesses the                                                                
                  correctness of                                                              
                  the SQL, the                                                                
                  appropriateness                                                             
                  of the joins and                                                            
                  filters used, the                                                           
                  quality of the                                                              
                  written                                                                     
                  discussion                                                                  
                  explaining each                                                             
                  query.                                                                      

  Reflection      Your ability to               15% Thoughtful and specific Reasonable        Superficial or
                  think critically                  responses to all three  responses to all  incomplete
                  about the design                  questions. Demonstrates three questions.  responses.
                  decisions,                        clear understanding of  Some depth but    Limited
                  governance                        the ethical and         may be general    engagement with
                  implications, and                 governance implications rather than       ethical or
                  ethical                           of the design           specific to the   technical
                  considerations                    decisions. Technical    scenario.         dimensions. One
                  that arise from                   enforcement method for  Technical method  or more
                  working with                      consent records         mentioned but not questions not
                  clinical trial                    correctly described and fully explained.  answered.
                  data. This                        justified.                                
                  criterion                                                                   
                  assesses the                                                                
                  depth and                                                                   
                  specificity of                                                              
                  your responses                                                              
                  --- answers that                                                            
                  engage directly                                                             
                  with this                                                                   
                  scenario will                                                               
                  score higher than                                                           
                  general                                                                     
                  statements about                                                            
                  databases or data                                                           
                  quality. For                                                                
                  Question 3, you                                                             
                  are also assessed                                                           
                  on whether you                                                              
                  can propose and                                                             
                  explain a                                                                   
                  concrete                                                                    
                  technical method                                                            
                  for enforcing the                                                           
                  append-only rule                                                            
                  at the database                                                             
                  level.                                                                      
  ------------------------------------------------------------------------------------------------------------

**University of Cambridge: Marking Scheme for Postgraduate Awards**

+------------------+------------------+-----------------------------------------+---------------------+
| **Score **       | **Mark           | **Student's work shows **               | **Quiz feedback**   |
|                  | Awarded **       |                                         |                     |
+:=================+:=================+:========================================+:====================+
| **Excellent **                                                                |                     |
+------------------+------------------+-----------------------------------------+---------------------+
| 80-100           | Pass with        | Evidence of the exceptional quality in  | Excellent work,     |
|                  | distinction.     | relation to the criteria listed for     | you've shown a      |
|                  |                  | the award of 70-79% and outstanding     | clear and confident |
|                  |                  | critical insights and thought-          | understanding of    |
|                  |                  | provoking arguments.                    | the material, with  |
|                  |                  |                                         | well-developed      |
|                  |                  |                                         | reasoning and       |
|                  |                  |                                         | consistently        |
|                  |                  |                                         | accurate responses  |
|                  |                  |                                         | across the quiz     |
+------------------+------------------+-----------------------------------------+---------------------+
| 75-79            | Pass with        | An accessible, accurate and clear       | Excellent work,     |
|                  | distinction.     | account. Clear assimilation and         | you've shown a      |
|                  |                  | understanding of the                    | clear and confident |
|                  |                  | evidence. Well informed by a wide range | understanding of    |
|                  |                  | of relevant ideas. Excellent            | the material, with  |
|                  |                  | analyses, arguments and                 | well-developed      |
|                  |                  | explanations. Exceptionally good        | reasoning and       |
|                  |                  | structuring of the material with clear  | consistently        |
|                  |                  | progression and development as the work | accurate responses  |
|                  |                  | proceeds.                               | across the quiz     |
+------------------+------------------+-----------------------------------------+---------------------+
| **Good **                                                                     |                     |
+------------------+------------------+-----------------------------------------+---------------------+
| 70-74            | Pass             | An accessible, accurate and direct      | Very good           |
|                  |                  | account. Clear assimilation and         | performance, you've |
|                  |                  | understanding of the                    | demonstrated a      |
|                  |                  | evidence. Well informed by current      | strong grasp of the |
|                  |                  | ideas. Very                             | key concepts and    |
|                  |                  | good analyses, arguments and            | applied them        |
|                  |                  | explanations. Very good insights and    | effectively across  |
|                  |                  | personal reflections on the             | most questions,     |
|                  |                  | material. Carefully structured and      | with thoughtful     |
|                  |                  | organised presentation.                 | engagement and      |
|                  |                  |                                         | clear               |
|                  |                  |                                         | understanding.      |
+------------------+------------------+-----------------------------------------+---------------------+
| **Competent **                                                                |                     |
+------------------+------------------+-----------------------------------------+---------------------+
| 65-69            | Pass             | An accessible, accurate and direct      | Competent           |
|                  |                  | account. Good analyses, arguments and   | performance, you've |
|                  |                  | explanations. Good insights and         | shown sound         |
|                  |                  | personal reflections on the             | understanding of    |
|                  |                  | material. Well-organised presentation.  | the main concepts   |
|                  |                  |                                         | covered in the      |
|                  |                  |                                         | quiz, though a few  |
|                  |                  |                                         | areas would benefit |
|                  |                  |                                         | from deeper review  |
|                  |                  |                                         | or clarification.   |
+------------------+------------------+-----------------------------------------+---------------------+
| 60-64            | Pass             | An accessible, accurate and direct      | A satisfactory      |
|                  |                  | account. Fair analyses, arguments and   | performance, you've |
|                  |                  | explanation but with some remaining     | demonstrated a      |
|                  |                  | gaps or confusion. Fair degree of       | reasonable          |
|                  |                  | personal insight. Reasonably            | understanding of    |
|                  |                  | well organised presentation.            | the material,       |
|                  |                  |                                         | though some areas   |
|                  |                  |                                         | show partial grasp  |
|                  |                  |                                         | or uncertainty.     |
|                  |                  |                                         | Further review will |
|                  |                  |                                         | strengthen your     |
|                  |                  |                                         | overall             |
|                  |                  |                                         | comprehension.      |
+------------------+------------------+-----------------------------------------+---------------------+
| **Pass Threshold **                                                           |                     |
+------------------+------------------+-----------------------------------------+---------------------+
| 50-59            | Fail             | Reliance on a restricted range of       | Your responses      |
|                  |                  | evidence, or irrelevant material        | indicate some       |
|                  |                  | introduced. Weaknesses of factual       | understanding of    |
|                  |                  | description. Weaknesses in the          | the material, but   |
|                  |                  | analyses, arguments and                 | key concepts were   |
|                  |                  | explanations. Weaknesses in the         | missed or applied   |
|                  |                  | insights and reflections on the         | inconsistently.     |
|                  |                  | material. Weakly-organised presentation | Revisiting the core |
|                  |                  | with a poor progression through the     | topics will help    |
|                  |                  | work.                                   | consolidate your    |
|                  |                  |                                         | learning.           |
|                  |                  |                                         |                     |
|                  |                  |                                         | 50: Your responses  |
|                  |                  |                                         | suggest limited     |
|                  |                  |                                         | understanding of    |
|                  |                  |                                         | the material at     |
|                  |                  |                                         | this stage. Focus   |
|                  |                  |                                         | on reviewing the    |
|                  |                  |                                         | foundational        |
|                  |                  |                                         | concepts and quiz   |
|                  |                  |                                         | feedback to build a |
|                  |                  |                                         | stronger base of    |
|                  |                  |                                         | knowledge.          |
+------------------+------------------+-----------------------------------------+---------------------+
| 0-49             | Fail             | Limited range of evidence or lack of    |                     |
|                  |                  | focus. Weak understanding of the        |                     |
|                  |                  | material presented. Lack of coherent    |                     |
|                  |                  | argument. Absence of personal           |                     |
|                  |                  | insight. Serious weaknesses in          |                     |
|                  |                  | the organisation of the presentation.   |                     |
+------------------+------------------+-----------------------------------------+---------------------+

![](media/image3.png){width="2.9166666666666665in"
height="1.186917104111986in"}

**MSt Healthcare Data Science**

# Authentication of practice

  ----------------------------------------------------------------- ---------
  I confirm that I have fully read and understood the [assignment   **Y/N**
  brief](https://vle.pace.cam.ac.uk/mod/page/view.php?id=2419694)   
  for this module.                                                  

  ----------------------------------------------------------------- ---------

# Details

+-----------------------------+-------------------------------------------------------+
| Name                        | Name surname                                          |
+:============================+:============================+:========================+
| Submission Date: DD -- MM -- YY                           |                         |
+-----------------------------------------------------------+-------------------------+
| Word Count: whole assignment including codes              |                         |
+-----------------------------------------------------------+-------------------------+
| Word Count: Main body excluding abstract, references and  |                         |
| supplementary materials                                   |                         |
+-----------------------------------------------------------+-------------------------+

# Permission to share your assignment: delete as appropriate

**I do/do not give permission to share my assignment with future MSt
participants.**

# University statement of originality

This assignment is the result of my own work and includes nothing which
is the outcome of work done in collaboration except as declared in the
Preface and specified in the text. It is not substantially the same as
any that I have previously submitted for a degree or diploma or other
qualification at the University of Cambridge or any other university or
similar institution, or that is being concurrently submitted, except as
declared in the Preface and specific in the text. I further state that
no substantial part of my Portfolio has already been submitted, nor is
being concurrently submitted for any such degree, diploma or other
qualification at the University of Cambridge or any other university or
similar institution except as declared in the Preface and specified in
the text.

  -------------------------------------------------------- ---------
  I confirm the statement of originality as above          **Y/N**

  -------------------------------------------------------- ---------

Please use the second page of this coversheet if you wish to declare use
of AI in your submission.

# Questions for reflection

Self-assessment is an important aspect of feedback literacy, which is,
in turn, key to the development of expertise. As you proceed through the
MSt Healthcare data science programme, we hope that you will make use of
the following prompts to assess your own work on assignments. Specific
assignment briefs will likely indicate which of these to address for
which assessments, but, in general, we expect you to respond to one or
two for each assignment on your course.

For each of the questions, do not spend too long answering -- keep it
brief. For each question you answer, limit yourself to no more than
three items. And please remember, this is optional and developmental:
these cover sheets are designed to create space for self-assessment and
feedback dialogue, rather than additional assignment workload.

1\. Which aspects of this assignment are you most uncertain about and/or
would most like to receive feedback on?

2\. What elements are you left pondering after this assignment that you
would like to discuss further?

3\. How have you incorporated feedback from peers and tutors into this
assignment?

4\. How, and to what extent, have you been able to incorporate feedback
on previous course work into this assignment?

5\. Using the wording in the rubric, how would you describe the quality
of the different aspects of your work?

Declaration of the use of generative AI

Where students engage in permitted use of generative AI in summative
assessments, this should be clearly acknowledged. Please ensure that you
have included a brief statement about whether you have used AI during
the preparation of this assignment. Please see the guidance document and
University guidelines on the use of AI on the assignment pages of the
VLE. We suggest that you take the time to look at the following guidance
on the University of Cambridge blended learning service webpages:
<https://blendedlearning.cam.ac.uk/artificial-intelligence-and-education/generative-ai-literacy-course>

You should include a brief statement using the heading 'Use of
generative artificial intelligence' that indicates what source(s) you
used and how you used them.

If you did not use generative AI to help with any part of your
assignment you must also make this clear. Some example statements are
below: 

- *I used chatGPT to help brainstorm the specific content for this
  assignment, draft the introduction section, and rewrite our draft text
  to meet the word limit. *

- *I used Gemini to generate a graphical overview of my theoretical
  model.*

- *I did not use any generative artificial intelligence in preparing
  this assignment*.

  ---------------------------------------------------------------
  Which permitted use of          
  generative AI are you           
  acknowledging?                  
  ------------------------------- -------------------------------
  Which generative AI tool did    
  you use (name and version)?     

  What did you use the tool for?  

  How have you used or changed    
  the generative AI's output?     
  ---------------------------------------------------------------

You can incorporate this line of code to read the image of this file
into your RMD document:

\![**filename**\](FILE path/ **filename**)

Example: \![cover\](C:/Users/Documents/cover.JPG)
