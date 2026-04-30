## Plan: Analyze all Python scripts in Suburban

TL;DR - Review every Python file in the repository, classify it by purpose, document how the main processing workflow works, and identify any duplicated/unused script variants.

**Steps**
1. Review all top-level scripts and document their purpose.
   - `cleanup.py` - file cleanup/archival logic.
   - `globfiles.py` - directory scanning and path checks.
   - `format_letters_file.py` / `format_letters_file copy.py` - text file cleanup and formatting for letter files.
   - `run_inspire_ps_cli.py` / `run_inspire_ps_cli_2.py` - wrapper for running Quadient InspirePSCLI workflows.
   - `temp.py` - ad hoc database inspection/test script.
   - `suburban_propane.py` - main workflow for downloading, parsing, importing, and processing document files.
   - `suburban_propane_multiprocessing.py` - multiprocessing variant of the main workflow.
   - `config.py` - environment settings, DB connection, workflow paths, and constants.

2. Review shared dependency modules and document their capabilities.
   - `dependencies/utility_functions.py` - logging, string cleaning, email and FTP/SFTP helpers.
   - `dependencies/mail_manager.py` - mail manager file generation and transfer workflow.
   - `dependencies/pdf_functions.py` - PDF merge/modify utilities.
   - `dependencies/opals_functions.py` - OPALS/web API helpers.
   - `dependencies/PostJobComponetMetric.py` - likely job metric posting helper (not read yet).

3. Review business logic modules under `dependencies/file_type_code`.
   - `inv_code.py` - invoice-specific document line processing and post-processing.
   - `sta_code.py` - statement-specific processing.
   - `ren_code.py` - rentals-specific processing.
   - `dun_code.py` - dunning-specific processing.
   - Note the timestamped variants as historical/alternate layouts, likely not used by the current main scripts.

4. Create a dependency map of which modules are actually imported by the main workflow versus which appear to be legacy or duplicates.

5. Produce a final summary report by file, including:
   - primary function
   - input/output behavior
   - external systems used (SFTP, FTP, database, email, Quadient DDA, network shares)
   - any obvious issues or oddities (duplicate files, hard-coded Windows paths, incomplete error handling)

**Relevant files**
- `/Users/bhatt/Projects/Suburban/suburban_propane.py`
- `/Users/bhatt/Projects/Suburban/suburban_propane_multiprocessing.py`
- `/Users/bhatt/Projects/Suburban/config.py`
- `/Users/bhatt/Projects/Suburban/dependencies/utility_functions.py`
- `/Users/bhatt/Projects/Suburban/dependencies/mail_manager.py`
- `/Users/bhatt/Projects/Suburban/dependencies/pdf_functions.py`
- `/Users/bhatt/Projects/Suburban/dependencies/opals_functions.py`
- `/Users/bhatt/Projects/Suburban/dependencies/file_type_code/inv_code.py`
- `/Users/bhatt/Projects/Suburban/dependencies/file_type_code/sta_code.py`
- `/Users/bhatt/Projects/Suburban/dependencies/file_type_code/ren_code.py`
- `/Users/bhatt/Projects/Suburban/dependencies/file_type_code/dun_code.py`

**Verification**
1. Confirm all `.py` files have been cataloged.
2. Ensure the main workflow path is documented end to end: download, decode, parse, DB insert, mail manager, PDF generation, archive.
3. Verify which timestamped alternate file type modules are unused by the current main scripts.

**Decisions**
- Focus analysis on files actually used by the main processing scripts.
- Treat timestamped duplicate code files as secondary unless they are imported directly.

**Further Considerations**
1. Should I also produce a single narrative architecture diagram for the pipeline, or just a file-by-file written summary?
2. Do you want the analysis to include recommendations for refactoring and cleanup?