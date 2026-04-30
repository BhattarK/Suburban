## Suburban Propane Cleaner Workflow Diagram

### 1. Entry and setup
- `suburban_propane.py` is the active production entry point.
- Acquire `process.lck` to prevent concurrent runs.
- Read `sequence_number.txt`.
- Connect to PostgreSQL via `config.py` settings.

### 2. File intake
- Download input files from SFTP remote `incoming`.
- For `.TXT` files: move to `INPUT/DECODED`.
- For `.zip` files:
  - unzip into `INPUT/UNZIPPED`
  - decode text for safe Latin-1 output
  - archive zip and extracted files
- Skip files already registered in the `datafile` table.

### 3. File type determination
- Identify the file type from filename content:
  - `INV` → invoice
  - `STA` → statement
  - `REN` → rental
  - `DUN` → dunning
  - `LETTERS` → letters
  - `denied_credit` → credit denial letters
- Load the corresponding JSON schema config.

### 4. Parsing and database writes
For each document block in the file:
- Extract values by fixed-width or delimiter definitions.
- Clean string values for SQL.
- Insert into database tables:
  - `Branch`
  - `Document`
  - `Document_Line`
- Generate and set PDF filename in `Document.pdffile`.
- Call helper modules in `dependencies/file_type_code/`:
  - `inv_code.py`
  - `sta_code.py`
  - `ren_code.py`
  - `dun_code.py`

### 5. Mail manager processing
- Generate mail address files via `dependencies/mail_manager.py`.
- Generate remittance IMB files when needed.
- Copy files to `\\10.2.0.76\ftproot`.
- Wait for returned `_BCCOUT.*` files.
- Update `datafile` status accordingly.

### 6. External processing and reporting
- Run external `inserts.py` for further processing.
- Build a report file in `REPORTS`.
- Send summary email with report attachment.

### 7. PDF creation
- Call `create_pdfs()`.
- Use `run_InspirePSCLI()` from `run_inspire_ps_cli.py`.
- Execute one or more Quadient workflows depending on file type.
- Move generated PDFs to production output folders.
- Archive processed input to `INPUT/ARCHIVE/DECODED`.

### 8. Shutdown
- Write back the updated sequence number to `sequence_number.txt`.
- Rename `process.lck` to a timestamped log filename.

### Supporting modules summary
- `config.py`: environment, DB, workflow, and SFTP settings.
- `dependencies/utility_functions.py`: logging, SQL cleaning, email, FTP/SFTP.
- `dependencies/mail_manager.py`: mail file generation and return-file handling.
- `run_inspire_ps_cli.py`: Quadient InspirePSCLI invocation wrapper.

### Summary
- The system is a tightly coupled batch pipeline for propane billing and mailing.
- It depends on external services and Windows network shares.
- The active path is `suburban_propane.py`; alternate scripts exist but are likely legacy.
