# Concrete Implementation Plan: Oracle XML Adapter

## Goal
Add Oracle XML input support for `INV`, `STA`, and `REN` files while preserving the existing database targets (`Branch`, `Document`, `Document_Line`) and Quadient workflow behavior.

## Overview
The idea is to replace only the input parsing layer. Keep the current pipeline, DB inserts, mail manager steps, and Quadient PDF generation unchanged.

## File changes
- `suburban_propane.py`
  - extend input acquisition to accept `.xml`
  - route XML files through a new XML parsing adapter
  - factor parsing and ingestion so the same DB insertion path works for TXT and XML
- `dependencies/xml_parser.py`
  - create the XML adapter module
  - parse Oracle XML into the same internal document model used by `suburban_propane.py`
- `config.py` (optional)
  - add XML file detection or folder constants if needed

## Detailed steps

### Step 1: Add a new XML adapter module
Create `dependencies/xml_parser.py` with these responsibilities:
- `get_file_type_from_xml(input_filename)`
  - infer `INV`, `STA`, or `REN` from XML content or filename
- `parse_xml_file(input_filename)`
  - load XML using `xml.etree.ElementTree` or `lxml`
  - normalize namespaces if present
- `build_internal_records(file_type, xml_root)`
  - translate XML structure into the same logical objects the pipeline expects
  - return a list of invoice/document blocks or a normalized data structure like:
    - `branch_data`
    - `documents` list
    - `document_lines` list

The output format should mimic the current `process_input_file()` input model enough that the same insertion logic can be reused.

### Step 2: Extend input acquisition in `suburban_propane.py`
Modify `get_input_filenames()` so it detects XML files as input sources.
- If `.xml` arrives via SFTP or in a zip, keep it in the same intake flow.
- Normalize XML into the local intake folders just like TXT:
  - move/rename into `INPUT/DECODED` or `INPUT/XML`
  - archive original files
- Update the `download_filenames` filtering logic to include `.xml` and `.zip` containing XML.
- Keep duplicate skipping logic based on `datafile` filename.

### Step 3: Refactor parsing abstraction in `suburban_propane.py`
Add a new parsing abstraction around existing TXT parsing.
- Create `parse_txt_invoices(input_filename)` from the current line-reading code.
- Add `parse_xml_invoices(input_filename)` that calls `dependencies.xml_parser.parse_xml_file()`.
- Add a shared helper such as `parse_input_file(input_filename)`:
  - if file is XML, call `parse_xml_invoices`
  - else call `parse_txt_invoices`

This will make the ingestion logic configurable by input format without duplicating downstream insert code.

### Step 4: Extract common DB ingestion logic
Refactor `process_input_file()` into two layers:
1. parse the input into a normalized internal model
2. ingest the normalized model into the DB

Suggested structure:
- `process_input_file(input_filename, connection)`
  - determine file type
  - invoices = `parse_input_file(input_filename)`
  - call `insert_invoices_to_db(input_filename, invoices, connection)`
- `insert_invoices_to_db(input_filename, invoices, connection)`
  - current logic that chooses config file and writes `Branch`, `Document`, `Document_Line`
  - existing PDF filename generation
  - existing post-processing via `inv_code`, `sta_code`, `ren_code`, `dun_code`

By isolating the parsing layer, XML and TXT share the same insertion flow.

### Step 5: Preserve downstream workflow
Keep the rest of `suburban_propane.py` unchanged except for the new parser integration:
- `datafile` duplicate check remains the same
- `mail_manager()` and `remittance_imb_mail_manager()` remain the same
- `get_mail_manager_files()` and return-file logic remain unchanged
- `get_file_data()` remains unchanged
- `create_pdfs()` remains unchanged
- PDF output relocation remains unchanged
- email/reporting remains unchanged

This ensures the only new code is the XML-specific adapter and parser branch.

### Step 6: Add XML-to-DB mapping details
Design the XML adapter to produce the same logical fields as the TXT parser.
- map XML header fields to `Branch`
- map XML document entries to `Document`
- map XML line item entries to `Document_Line`
- preserve key fields used by existing logic:
  - `document_date`
  - `customer_account_number`
  - `csc_number`
  - `recordtype`
  - `pdffile`
  - `letter_code` for `DUN` / `LETTERS`

If the XML structure differs from current record types, define a field mapping config or adapter logic for each file type.

### Step 7: Handle file type selection
Use a deterministic rule to choose `INV`, `STA`, or `REN`:
- filename patterns like `INV`, `STA`, `REN`
- or XML root element/tag content
- or explicit XML attributes in the Oracle XML

Then select existing helper code:
- `dependencies/file_type_code/inv_code.py`
- `dependencies/file_type_code/sta_code.py`
- `dependencies/file_type_code/ren_code.py`

If the new XML format also includes `LETTERS`, treat it the same way as existing `LETTERS` logic.

### Step 8: Validate and roll out gradually
1. Implement XML adapter and keep TXT support active.
2. Add a small XML-only test file and verify DB inserts match expected values.
3. Confirm generated `Document.pdffile` names still match the expected format.
4. Confirm mail-manager file generation still works.
5. Confirm `create_pdfs()` still invokes Quadient correctly.
6. Once XML is stable, optionally remove or deprecate old TXT-only branches.

## Suggested file additions and edits
- Add: `dependencies/xml_parser.py`
- Modify: `suburban_propane.py`
  - `get_input_filenames()`
  - `parse_input_file()` / new `parse_xml_invoices()`
  - `process_input_file()` refactor
- Optional: `config.py`
  - add XML input handling constants or detection helpers

## Why this works
- The database model is unchanged.
- The Quadient workflows are unchanged.
- Only the input format changes.
- A clean adapter layer makes XML support maintainable and extensible.

## Next step
If you want, I can also write the exact starter code for `dependencies/xml_parser.py` and the specific `suburban_propane.py` edits. 