## Suburban Propane Python Code Analysis

### Core active workflow

- `suburban_propane.py`
  - Main production pipeline.
  - Downloads files from SFTP `incoming`.
  - Moves `.TXT` files into `INPUT/DECODED`, unzips `.zip` files, decodes text to Latin-1-safe output, archives originals.
  - Parses text input by record structure using JSON config files (`invoice_config.json`, `statement_config.json`, etc.).
  - Inserts into Postgres `Branch`, `Document`, `Document_Line`.
  - Generates PDF filenames and updates DB `pdffile`.
  - Generates mail-manager input files and waits for return `_BCCOUT.*` files.
  - Sends reports and emails.
  - Calls Quadient InspirePSCLI via `run_InspirePSCLI()` to create PDFs.
  - Moves generated PDFs into production folders and archives processed input.
  - Uses `sequence_number.txt` and `process.lck`.

- `suburban_propane_multiprocessing.py`
  - Attempted multiprocessing rewrite of the same pipeline.
  - Very similar logic, but uses `multiprocessing.Pool`.
  - Runs `format_letters_file.py` for `LETTERS` files.
  - Checks duplicate file processing and runs `inserts.py`.
  - Looks like a parallel-processing variant, not clearly the canonical path.

- `run_inspire_ps_cli.py`
  - Wrapper for running Quadient InspirePSCLI CLI.
  - Builds command args, captures process output, checks for licensing/fatal errors.
  - Returns 0 or raises on failure.

### Configuration

- `config.py`
  - Environment settings for production/sandbox.
  - Postgres connection string.
  - PDF folder and Quadient workflow `.wfd` paths.
  - SFTP credentials.
  - Constant message mapping for CSC 1654 and Texas Railroad message.
  - `PROD` flag selects production vs sandbox config.

### Shared utilities

- `dependencies/utility_functions.py`
  - Logging (`display_message`).
  - SQL-safe string escaping and quoting (`clean_string`).
  - SMTP email/send error email via fixed mail host.
  - Zip/unzip helpers.
  - SFTP upload/download wrappers.
  - FTP helpers.

- `dependencies/mail_manager.py`
  - Writes mail index input files to `INDEX/IN`.
  - Writes remittance IMB files to `INDEX/REMITTANCE_IMB/IN`.
  - Copies files to network share `\\10.2.0.76\ftproot`.
  - Waits for returned `_BCCOUT.idx` / `_BCCOUT.txt`.
  - Updates DB statuses.

### Document-specific business logic

- `dependencies/file_type_code/inv_code.py`
  - Invoice-specific record processing.
  - Handles Document_Line records types `12`, `13`, `17`, `18`.
  - Updates transaction/gallon data and CSC 1654 messages.
  - Post-processes blocks to set invoice numbers, address cleanup, and invoice line subtotals.

- `dependencies/file_type_code/sta_code.py`
  - Statement-specific logic.
  - Handles `12`, `13`, `17`, `20`, `22`, `18`.
  - Updates step rate formatting, late charge values, card number consistency, and address handling.

- `dependencies/file_type_code/ren_code.py`
  - Rental-specific post-processing.
  - Handles contract records (`18`, `21`).
  - Updates subtotals and contract messages based on rules.

- `dependencies/file_type_code/dun_code.py`
  - Dunning letter-specific logic.
  - Simple flagging of `letter_code` on `Document` for certain `11` records.
  - `update_block_data_dun()` is a stub.

### PDF / reporting helpers

- `dependencies/pdf_functions.py`
  - PDF merge and blank page utilities.
  - Creates mailing pages and can prepend them to PDFs.
  - Not directly used in `suburban_propane.py` or `suburban_propane_multiprocessing.py`.

### Network / job API helpers

- `dependencies/opals_functions.py`
  - OPALS job-number and shippo API helpers.
  - Not referenced by the main Suburban scripts.

- `dependencies/PostJobComponetMetric.py`
  - Sends job component metrics over HTTP.
  - Not referenced by active workflow.

### One-off / ad-hoc scripts

- `cleanup.py`
  - Deletes old files from configured folders.
  - Contains a logic bug: it sets `rc=os.path.exists(base_dir + '/LOG')`, then uses `if rc == 0` after checking other folders, so folder existence checks are incorrect.

- `globfiles.py`
  - One-off file scan tool.
  - Searches a hard-coded network path for files matching `NSTA_241130*` and prints file modification times.

- `format_letters_file.py`
  - Reformats a letter file by parsing `D` records and normalizing check-date formatting.
  - Creates a backup and replaces the original.

- `format_letters_file copy.py`
  - Ad-hoc alternative version.
  - Reads a command-line file, uses fixed-width parsing on lines, and adjusts date fields.
  - Contains commented-out DB metadata checking and is not part of the main pipeline.

- `temp.py`
  - Scratch/test script for DB exploration and debugging.
  - Contains many commented-out operations and is not part of the active workflow.

- `run_inspire_ps_cli_2.py`
  - Duplicate of `run_inspire_ps_cli.py`.
  - Also includes example usage.
  - Likely legacy or development copy.

### Legacy / variant modules

- `dependencies/file_type_code/inv_code_FLW20240821.py`
- `dependencies/file_type_code/inv_code20240819.py`
- `dependencies/file_type_code/inv_code20250204.py`
- `dependencies/file_type_code/inv_code_FLQ20240823.py`
- `dependencies/file_type_code/inv_code_FLQ20240819.py`
- `dependencies/file_type_code/inv_code _FLQ20240822.py`
- `dependencies/file_type_code/sta_code_FLQ20240828.py`
- `dependencies/file_type_code/sta_code_FLQ20240823.py`
- `dependencies/file_type_code/sta_code_FLQ20240826.py`
- `dependencies/file_type_code/sta_codeFLQ20240819.py`
- `dependencies/file_type_code/sta_code20240819.py`
- `dependencies/file_type_code/sta_code20250204.py`

These appear to be alternate or timestamped versions of the same invoice/statement handling logic. None are imported by `suburban_propane.py` or `suburban_propane_multiprocessing.py`, so they are likely historical variants.

---

## Main Suburban processing workflow

1. Start with `suburban_propane.py`.
2. Acquire lock file `process.lck`.
3. Read global sequence from `sequence_number.txt`.
4. Call `get_input_filenames()`:
   - Connect to SFTP using credentials from `config.py`.
   - Download `.TXT` and `.zip` files from remote `incoming`.
   - Move `.TXT` into `INPUT/DECODED`.
   - Unzip `.zip` into `INPUT/UNZIPPED`, decode text to safe Latin-1 output, archive originals.
   - Skip files already present in DB `datafile`.
5. For each new input file:
   - Skip duplicate if `datafile` already contains that filename.
   - Parse lines into invoice/document blocks.
   - Determine file type by filename token (`INV`, `STA`, `REN`, `DUN`, `LETTERS`, `denied_credit`).
   - Load matching JSON schema config.
   - For each block:
     - Extract fixed-width fields or delimiter-based columns.
     - Clean strings for SQL insertion.
     - Insert `Branch` row.
     - Insert `Document` rows.
     - Insert `Document_Line` rows.
     - Generate PDF filename and update `Document.pdffile`.
     - Use document-type helpers from `dependencies/file_type_code/*` for post-processing.
   - Call `mail_manager()` to produce mail address file.
   - Call `remittance_imb_mail_manager()` for remittance input if needed.
   - Run external `inserts.py` (not in repo) for additional processing.
   - Copy mail-manager files to network share and wait for returned files.
   - Generate a report text file under `REPORTS`.
   - Send summary email with report attachment.
   - Call `create_pdfs()`, which runs `run_InspirePSCLI()` for one or two Quadient workflows depending on file type.
   - Copy/move generated PDFs from local output to production network directories.
   - Move processed input to `INPUT/ARCHIVE/DECODED`.
6. On exit:
   - Write updated sequence number back to `sequence_number.txt`.
   - Rename `process.lck` to a timestamped log file.

---

## Key observations

- The repo is centered on a document ingestion pipeline for Suburban Propane: take batch text files, load them into DB, generate print/mail output, and build PDFs.
- The active main job is `suburban_propane.py`; `suburban_propane_multiprocessing.py` is a variant but not clearly the canonical path.
- `config.py` hard-codes production credentials and network paths, so the system is very environment-specific.
- The pipeline depends heavily on external systems:
  - PostgreSQL via `pyodbc`
  - SFTP and FTP servers
  - Windows UNC network shares
  - Quadient InspirePSCLI
  - SMTP mail server
- Several files are one-off or legacy copies, not part of the main flow.

If you want, I can next produce a cleaner diagram of the workflow steps and point out the most important cleanup/refactor opportunities.
