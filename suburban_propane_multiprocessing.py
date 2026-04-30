"""
10.180.10.87

Ftp User : Files 
FTP Password : G******2
File Folder : \IN
File Out Folder :\OUT

Windows User : .\Developer
PW : G******2$

PGAdmin is installed in the server if required:
Database name : suburban_production
Postgres DB User : postgres
PW : G******2$


# TODO:
Rentals:

Amount being repeated (subtotals)
0.00 issue

"""

from datetime import datetime
from ftplib import FTP
import json
import os
from pprint import pprint
import re
import shutil
import sys
import operator
import time
from zipfile import ZipFile

import pyodbc
import pysftp
import requests
from config import CONNECT_STRING, DC_WFD, DDA_ENV,CSC_1654_MESSAGES, DENIED_CREDIT_CONFIG_FILENAME, DUNNING_CONFIG_FILENAME, INVOICE_CONFIG_FILENAME, LETTERS_CONFIG_FILENAME, LETTERS_WFD, PDF_FOLDER, RENTERS_CONFIG_FILENAME, SAEDUN_WFD, SAEINV_SPL_WFD, SAEINV_WFD, SAEREN_SPL_WFD, SAEREN_WFD, SAESTA_WFD, SFTP_PASSWORD, SFTP_SERVER, SFTP_USERNAME, STATEMENT_CONFIG_FILENAME, TEXAS_RAILROAD_MESSAGE
from dependencies.file_type_code.dun_code import create_block_data_dun, update_block_data_dun

from dependencies.utility_functions import clean_string, display_message, send_email, send_error_email
from dependencies.file_type_code.inv_code import create_block_data_inv, update_block_data_inv
from dependencies.file_type_code.ren_code import create_block_data_ren, update_block_data_ren
from dependencies.file_type_code.sta_code import create_block_data_sta, update_block_data_sta, update_query_data_sta
from dependencies.mail_manager import get_mail_manager_files, remittance_imb_mail_manager
from dependencies.mail_manager import mail_manager
from dependencies.mail_manager import mail_manager_database_update
from run_inspire_ps_cli import run_InspirePSCLI
from multiprocessing import Pool
import subprocess


def unzip(in_file, unzipped_folder):
    """Unzips a zip file

    Args:
        in_file (str): Path and filename of zip file to be unzipped
        unzipped_folder (str): Path of folder where contents of zip file will be unzipped to
    """
    with ZipFile(in_file, "r") as zip:
        zip.extractall(unzipped_folder)
        return zip.namelist()


def decode_file(input_filename, output_filename):
    pattern = re.compile(r'[^\x00-\xFF]+')
    with open(input_filename, "r+", encoding="latin-1") as input_file:
        cleaned_string = re.sub(pattern, ' ', input_file.read())
    with open(output_filename, "w+") as output_file:
        output_file.write(cleaned_string)
    return output_filename


def get_input_filenames(connection):
    return sorted([
    # # #     # r"INPUT\ARCHIVE\DECODED\E9_240315_SAEINV.TXT",#---------------------
    # # #     # r"INPUT\DECODED\E10_240315_SAEINV.TXT",#---------------------
    # # #     # r"INPUT\ARCHIVE\DECODED\E20_240221_SAESTA.TXT",
    # # #     r"INPUT\ARCHIVE\DECODED\E3_240323_SAEINV.TXT",
    # # #     # r"INPUT\ARCHIVE\DECODED\E16_240315_SAEINV.TXT",
    # #     r"INPUT\ARCHIVE\DECODED\E3_231115_SAEREN.TXT",
    # #     r"INPUT\ARCHIVE\DECODED\denied_credit_letters_02022024.txt",
    # #     r"INPUT\ARCHIVE\DECODED\E16_240315_SAEINV.TXT", 
    # #     r"INPUT\ARCHIVE\DECODED\E3_240125_SAEDUN.TXT", 
    # #     r"INPUT\ARCHIVE\DECODED\E3_240126_SAESTA.TXT",
          # r"INPUT\ARCHIVE\DECODED\E21_250621_SAESTA.TXT",   
            #r"INPUT\ARCHIVE\DECODED\E6_250901_SAESTA.TXT",  
            # r"INPUT\ARCHIVE\DECODED\E3_250701_SAEDUN.TXT",  
            # r"INPUT\ARCHIVE\DECODED\E3_250701_SAESTA.TXT",  
            r"INPUT\DECODED\E3_251005_SAESTA.TXT",  
    #     #         r"INPUT\ARCHIVE\DECODED\E10_240426_SAEINV.TXT",
    #     #         r"INPUT\ARCHIVE\DECODED\E11_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E12_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E13_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E14_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E15_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E16_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E17_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E18_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E19_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E20_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E21_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E2_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E4_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E5_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E6_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E7_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E8_240426_SAEINV.txt",
    #     #         r"INPUT\ARCHIVE\DECODED\E9_240426_SAEINV.txt", 
    #     #   r"INPUT\DECODED\E3_241109_SAEINV.TXT" ,
    #     #   r"INPUT\DECODED\E3_241109_SAESTA.TXT" ,
    #     #   r"INPUT\DECODED\E3_241109_SAEDUN.TXT" ,              
    #     #   r"INPUT\DECODED\LETTERS_241109.TXT",
     ],key = os.path.getsize)
    #return list(map(lambda x : os.path.join("INPUT", "DECODED", x), os.listdir(os.path.join("INPUT", "DECODED"))))
    download_filenames = sftp_download(SFTP_SERVER, SFTP_USERNAME, SFTP_PASSWORD, "incoming", os.path.join("INPUT", "ZIPPED"))
    # download_filenames = list(map(lambda x : os.path.join("INPUT", "ZIPPED", x), os.listdir(os.path.join("INPUT", "ZIPPED"))))
    input_filenames = []                                                                                                                    
    for download_filename in download_filenames:
        if ".TXT" in download_filename.upper():
            if os.path.exists(os.path.join("INPUT", "DECODED", os.path.basename(download_filename))):
                os.remove(os.path.join("INPUT", "DECODED", os.path.basename(download_filename)))
            shutil.move(download_filename, os.path.join("INPUT", "DECODED"))
            input_filenames.append(os.path.join("INPUT", "DECODED", os.path.basename(download_filename)))
            continue
        unzip_filenames = unzip(download_filename, os.path.join("INPUT", "UNZIPPED"))
        if os.path.exists(os.path.join("INPUT", "ARCHIVE", "ZIPPED", os.path.basename(download_filename))):
            os.remove(os.path.join("INPUT", "ARCHIVE", "ZIPPED", os.path.basename(download_filename)))
        shutil.move(download_filename, os.path.join("INPUT", "ARCHIVE", "ZIPPED"))
        for unzip_filename in unzip_filenames:
            input_filename = decode_file(os.path.join("INPUT", "UNZIPPED", unzip_filename), os.path.join("INPUT", "DECODED", unzip_filename))
            if os.path.exists(os.path.join("INPUT", "ARCHIVE", "UNZIPPED", unzip_filename)):
                os.remove(os.path.join("INPUT", "ARCHIVE", "UNZIPPED", unzip_filename))
            shutil.move(os.path.join("INPUT", "UNZIPPED", unzip_filename), os.path.join("INPUT", "ARCHIVE", "UNZIPPED"))
            input_filenames.append(input_filename)
        # shutil.copy(input_filename, r"\\10.2.0.116\srvnjnas1001\ClientProjects\Suburban_NEW\Downloads\\")
    with connection.cursor() as cursor:
        cursor.execute("SELECT datafilename FROM datafile")
        for record in cursor.fetchall():
            datafilename = getattr(record, "datafilename")
            if datafilename in list(map(lambda input_filename: os.path.basename(input_filename), input_filenames)):
                input_filenames.remove(os.path.join("INPUT", "DECODED", datafilename))
                os.remove(os.path.join("INPUT", "DECODED", datafilename))
                print("Skipping " + datafilename)
                
    # body =  "\n".join(str(os.path.basename(file)) for file in input_filenames)
    # body = "The following files have been downloaded:\n\n" + body            
    # send_email(
    #     f"Suburban Files Received",
    #     body ,
    #     "help_desk@contentcritical.com",
    #     [
    #         "amol.sagar@contentcritical.com",
    #         "tariq.mohamed@contentcritical.com",
    #         "riddhi.rana@contentcritical.com",
    #         "helene.fischer@contentcritical.com",
    #         "douglas.sikora@contentcritical.com",
    #         "spessoa@suburbanpropane.com", 
    #         "plucien@suburbanpropane.com",
    #         "_UC4_Operations@suburbanpropane.com",
    #         "pakasapinov@suburbanpropane.com",
    #         "smurray@suburbanpropane.com",
    #         "avillanueva@suburbanpropane.com",
    #         "scampbell@suburbanpropane.com",
    #         "cust_suburban@contentcritical.com",           
    #     ]
    # )   
             
    return sorted(input_filenames, key = os.path.getsize)


def get_invoice_reference_data(invoice_references, invoice):
    invoice_reference_data = {}
    for record, line_number in invoice:
        record_type = record[:2]
        if record_type in invoice_references:
            reference_key_start = invoice_references[record_type]["key_start"] - 1
            reference_key_length = invoice_references[record_type]["key_length"]
            reference_key_stop = reference_key_start + reference_key_length
            reference_key = record[reference_key_start:reference_key_stop]
            reference_value_start = invoice_references[record_type]["value_start"] - 1
            reference_value_length = invoice_references[record_type]["value_length"]
            reference_value_stop = reference_value_start + reference_value_length
            reference_value = record[reference_value_start:reference_value_stop]
            if record_type not in invoice_reference_data:
                invoice_reference_data[record_type] = {}
            if "multi_line" in invoice_references[record_type]:
                if reference_key in invoice_reference_data[record_type]:
                    invoice_reference_data[record_type][reference_key] += reference_value.strip() + " " if reference_value.strip() != "" else "\n\n"
                else:
                    invoice_reference_data[record_type][reference_key] = reference_value.strip() + " " if reference_value.strip() != "" else "\n\n"
            else:
                invoice_reference_data[record_type][reference_key] = reference_value
    return invoice_reference_data


def update_sequence_number():
    if SEQUENCE_NUMBER[0] < 999999:
        SEQUENCE_NUMBER[0] += 1
    else:
        with open("sequence_number.txt", "w+") as sequence_number_file:
            sequence_number_file.write("0")
        SEQUENCE_NUMBER[0] = 0


def process_input_file(input_filename, connection):
    invoices = [] # NOTE: This variable is called invoices, but it could also represent statements.
    record_data = {}
    branch_ids = []
    address_records = []
    document_count = 0
    global document_date
    with open(input_filename, "r+") as input_file:
        if "denied_credit" in input_filename:
            current_invoice = []
        for line_number, line in enumerate(input_file.readlines()):
            if "denied_credit" in input_filename and line_number != 0:
                invoices.append([line, line_number])
                document_count += 1
            if (line[:2] == "01" or (True if "LETTERS" in input_filename and line[:2] == "HD" else False)) and "denied_credit" not in input_filename:
                if line_number != 0:
                    invoices.append(current_invoice)
                current_invoice = []
            if "denied_credit" not in input_filename:
                current_invoice.append([line, line_number])
            if (line[:2] == "11" and "denied_credit" not in input_filename)  or (True if "LETTERS" in input_filename and line[:2] == "D0" else False):
                document_count += 1
        if "denied_credit" not in input_filename:
            invoices.append(current_invoice)
    file_date = input_filename.split("_")[1][:6]
    if "denied_credit" in input_filename:
        file_date = input_filename.split("_")[-1][:-4]
        file_date = file_date[-2:] + file_date[:-4]
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
                WITH ins AS (
                    INSERT INTO datafile (datafilename, documentcount, filedate)
                    VALUES ('{os.path.basename(input_filename)}', {document_count}, '{file_date}')
                    ON CONFLICT(datafilename) DO NOTHING
                    RETURNING datafileid
                )
                SELECT datafileid FROM ins
                UNION ALL
                SELECT datafileid FROM datafile WHERE datafilename='{os.path.basename(input_filename)}'
                LIMIT 1;
            """
        )
        datafile_id = getattr(cursor.fetchone(), "datafileid")
    if "INV" in input_filename:
        config_filename = INVOICE_CONFIG_FILENAME
    elif "STA" in input_filename:
        config_filename = STATEMENT_CONFIG_FILENAME
    elif "REN" in input_filename:
        config_filename = RENTERS_CONFIG_FILENAME
    elif "DUN" in input_filename:
        config_filename = DUNNING_CONFIG_FILENAME
    elif "LETTERS" in input_filename:
        config_filename = LETTERS_CONFIG_FILENAME
    elif "denied_credit" in input_filename:
        config_filename = DENIED_CREDIT_CONFIG_FILENAME
    else:
        config_filename = INVOICE_CONFIG_FILENAME
    with open(config_filename, "rb") as invoice_config_file:
        invoice_config = json.load(invoice_config_file)
    invoice_data = invoice_config["invoiceData"]
    invoice_references = invoice_config["references"]
    if "delimiter" in invoice_config:
        delimiter = invoice_config["delimiter"]
        for invoice in invoices:
            delimited_invoice = invoice[0].split(delimiter)
            primary_table_query_data = {
                "columns": [],
                "values": []
            }
            secondary_table_query_data = {
                "columns": [],
                "values": []
            }
            for index, column_data in invoice_data.items():
                index = int(index)
                column_name, table_type = column_data
                if table_type == "primary":
                    primary_table_query_data["columns"].append(column_name)
                    primary_table_query_data["values"].append(clean_string(delimited_invoice[index]))
                elif table_type == "secondary":
                    if index == 3:
                        town = delimited_invoice[index].split(",")[0]
                        if len(delimited_invoice[index].split(",")[1].strip().split(" ")) == 2:
                            state = delimited_invoice[index].split(",")[1].strip().split(" ")[0]
                            zip = delimited_invoice[index].split(",")[1].strip().split(" ")[1]
                        elif len(delimited_invoice[index].split(",")[1].strip().split(" ")) == 1:
                            code = delimited_invoice[index].split(",")[1].strip().split(" ")[0]
                            if len(code) > 2:
                                state = "null"
                                zip = code
                        secondary_table_query_data["columns"] += ["town", "state", "zip"]
                        secondary_table_query_data["values"] += [clean_string(town), clean_string(state), clean_string(zip)]
                    else:
                        secondary_table_query_data["columns"].append(column_name)
                        secondary_table_query_data["values"].append(clean_string(delimited_invoice[index]))
            if "denied_credit" in input_filename:
                if "csc_number" in primary_table_query_data["columns"]:
                    primary_table_query_data["values"][primary_table_query_data["columns"].index("csc_number")] = "1164"
                else:
                    primary_table_query_data["columns"] += ["csc_number"]
                    primary_table_query_data["values"] += ["1164"]
                if "csc_phone" in primary_table_query_data["columns"]:
                    primary_table_query_data["values"][primary_table_query_data["columns"].index("csc_phone")] = "'(800) 776- 7263'"
                else:
                    primary_table_query_data["columns"] += ["csc_phone"]
                    primary_table_query_data["values"] += ["'(800) 776- 7263'"]
            with connection.cursor() as cursor:
                cursor.execute(
                    f"""
                        INSERT INTO Branch (
                            {", ".join(primary_table_query_data["columns"])}, document_type, datafileid
                        )
                        VALUES (
                            {", ".join(primary_table_query_data["values"])}, 'CCDENIED', '{datafile_id}'
                        )
                        RETURNING Branch.branchid, Branch.document_date, Branch.csc_number
                    """
                )
                record = cursor.fetchone()
                branchid = getattr(record, "branchid")
                branch_ids.append(branchid)
                document_date = str(getattr(record, "document_date"))
                cursor.execute(
                    f"""
                        WITH ins AS (
                            INSERT INTO Document (branchid, {", ".join(secondary_table_query_data["columns"])}, document_date)
                            VALUES ('{branchid}', {", ".join(secondary_table_query_data["values"])}, '{document_date}')
                            ON CONFLICT (branchid, customer_account_number, document_date) DO NOTHING
                            RETURNING documentid, recordtype, document_date, customer_account_number
                        )
                        SELECT documentid, recordtype, document_date, customer_account_number FROM ins
                        UNION ALL
                        SELECT documentid, recordtype, document_date, customer_account_number FROM Document
                        WHERE branchid='{branchid}' AND
                            document_date='{document_date}'
                        LIMIT 1;
                    """
                )
                record = cursor.fetchone()
                documentid = getattr(record, "documentid")
                pdf_filename = "CCDENIED_" + document_date.split("/")[2] + document_date.split("/")[0] + document_date.split("/")[1] + "_0000_000000_" + str(SEQUENCE_NUMBER[0]).zfill(6) + "_N.pdf"
                cursor.execute(
                    f"""
                        UPDATE Document
                        SET pdffile = ?
                        WHERE documentid = ?
                    """,
                    pdf_filename,
                    documentid
                )
                update_sequence_number()
                address_records.append(documentid)
        return [mail_manager(connection, input_filename, address_records)], document_count, datafile_id,document_date
    for invoice in invoices:
        invoice_reference_data = get_invoice_reference_data(invoice_references, invoice)
        primary_table_query_data = {
            "columns": [],
            "values": []
        }
        secondary_table_query_data = []
        for record, line_number in invoice:
            record_type = record[:2]
            if record_type in invoice_data:
                table_type = invoice_data[record_type]["tableType"]
                if table_type == "primary":
                    for field in invoice_data[record_type]["dataPoints"]:
                        field_column = field["column"]
                        if field_column in primary_table_query_data["columns"]:
                            continue
                        field_start = field["start"] - 1
                        field_length = field["length"]
                        field_stop = field_start + field_length
                        field_data = record[field_start:field_stop]
                        if "reference" in field:
                            field_data = invoice_reference_data[field["reference"]][field_data]
                        if "exceptions" in field:
                            if field_data in field["exceptions"]:
                                field_data = invoice_reference_data[field["exceptions"][field_data]][field_data]
                        data_type = field["dataType"]
                        if data_type == "string":
                            field_data = clean_string(field_data)
                        if data_type == "datetime":
                            field_data = f"'{field_data.strip()}'"
                            if len(field_data[1:-1]) == 0:
                                field_data = "null"
                            elif int(field_data[1:-1]) == 0:
                                field_data = "null"
                            elif "format" in field:
                                date_format = f"'{field['format']}'"
                                field_data = f"'{datetime.strptime(field_data.strip(), date_format).strftime('%Y-%m-%d')}'"
                        elif data_type == "boolean":
                            field_data = str("true" if field_data in ("1", "Y") else "false")
                        elif data_type == "int":
                            field_data = str(field_data).strip()
                            if field_data == "":
                                field_data = 'null'
                        primary_table_query_data["values"].append(field_data)
                        primary_table_query_data["columns"].append(field_column)
                    if record_type == "01":
                        primary_table_query_data["values"].append(f"'{str(line_number)}'")
                        primary_table_query_data["columns"].append("rownumber")
                elif table_type == "secondary":
                    secondary_query_data = {
                        "columns": [],
                        "values": [],
                        "tertiary_table_query_data": []
                    }
                    for field in invoice_data[record_type]["dataPoints"]:
                        field_start = field["start"] - 1
                        field_length = field["length"]
                        field_stop = field_start + field_length
                        field_data = record[field_start:field_stop]
                        if "reference" in field:
                            field_data = invoice_reference_data[field["reference"]][field_data]
                        if "exceptions" in field:
                            if field_data in field["exceptions"]:
                                field_data = invoice_reference_data[field["exceptions"][field_data]][field_data]
                        data_type = field["dataType"]
                        if data_type == "string":
                            field_data = clean_string(field_data)
                        if data_type == "datetime":
                            field_data = f"'{field_data.strip()}'"
                            if "/" in field_data:
                                field_data = "".join(field_data.split("/"))
                            if (len(field_data) > 2 and int(field_data[1:-1]) == 0) or len(field_data) == 2:
                                field_data = "null"
                            elif "format" in field:
                                date_format = f"'{field['format']}'"
                                field_data = f"'{datetime.strptime(field_data.strip(), date_format).strftime('%Y-%m-%d')}'"
                        elif data_type == "boolean":
                            field_data = str("true" if field_data in ("1", "Y") else "false")
                        elif data_type == "int":
                            field_data = str(field_data).strip()
                            if field_data == "":
                                field_data = 'null'
                        field_column = field["column"]
                        secondary_query_data["values"].append(field_data)
                        secondary_query_data["columns"].append(field_column)
                    secondary_query_data["values"].append(str(line_number))
                    secondary_query_data["columns"].append("rownumber")
                    secondary_table_query_data.append(secondary_query_data)
                elif table_type == "tertiary":
                    if record_type == "12":
                        pass
                    tertiary_table_query_data = secondary_query_data["tertiary_table_query_data"]
                    tertiary_query_data = {
                        "columns": [],
                        "values": []
                    }
                    for field in invoice_data[record_type]["dataPoints"]:
                        field_start = field["start"] - 1
                        field_length = field["length"]
                        field_stop = field_start + field_length
                        field_data = record[field_start:field_stop]
                        if field["column"] == "step_rates":
                            new_field_data = ""
                            for char_index, char in enumerate(field_data):
                                if char_index % 55 == 0 and char_index != 0:
                                    new_field_data += "\x0a"
                                new_field_data += char
                            field_data = new_field_data
                        if "reference" in field:
                            reference_key = field_data
                            field_data = invoice_reference_data[field["reference"]][field_data]
                        if "exceptions" in field:
                            if reference_key in field["exceptions"]:
                                exception = field["exceptions"][reference_key]
                                if record[exception[1]:exception[2]] not in invoice_reference_data[exception[0]]:
                                    field_data = "NA"
                                else:
                                    field_data = invoice_reference_data[exception[0]][record[exception[1]:exception[2]]]
                                tertiary_query_data["values"].append("true")
                                tertiary_query_data["columns"].append("exception_data")
                        data_type = field["dataType"]
                        if data_type == "string":
                            field_data = clean_string(field_data)
                        if data_type == "datetime":
                            field_data = f"'{field_data.strip()}'"
                            if (len(field_data) > 2 and int(field_data[1:-1]) == 0) or len(field_data) == 2:
                                field_data = "null"
                            elif "format" in field:
                                date_format = f"'{field['format']}'"
                                field_data = f"'{datetime.strptime(field_data.strip(), date_format).strftime('%Y-%m-%d')}'"
                        elif data_type == "boolean":
                            field_data = str("true" if field_data in ("1", "Y") else "false")
                        elif data_type == "int":
                            field_data = str(field_data).strip()
                            if field_data == "":
                                field_data = 'null'
                        field_column = field["column"]
                        if "replace" in field:
                            if field["replace"][0] in field_data:
                                field_data = field_data.replace(field["replace"][0], field["replace"][1]).strip()
                                if "supress" not in secondary_query_data["columns"]:
                                    secondary_query_data["values"] += ["true", "true", f"E'Data issue - found \\'{field['replace'][0]}\\' character in record {record_type}, column {field_column}'"]
                                    secondary_query_data["columns"] += ["supress", "mmsupress", "suppress_reason"]
                        tertiary_query_data["values"].append(field_data)
                        tertiary_query_data["columns"].append(field_column)
                    tertiary_query_data["values"].append(str(line_number))
                    tertiary_query_data["columns"].append("rownumber")
                    tertiary_table_query_data.append(tertiary_query_data)
        with connection.cursor() as cursor:
            if "LETTERS" in input_filename:
                primary_table_query_data["values"].append(f"'LETTERS'")
                primary_table_query_data["columns"].append("document_type")
                primary_table_query_data["values"].append(f"'02'")
                primary_table_query_data["columns"].append("record_code")
            if "DUN" in input_filename:
                csc_number = primary_table_query_data["values"][primary_table_query_data["columns"].index("division_address_1")].split("-")[-1].strip()[:-1][:4]
                try:
                    int(csc_number)
                except ValueError:
                    csc_number = "0000"
                primary_table_query_data["values"].append(f"'{csc_number}'")
                primary_table_query_data["columns"].append("csc_number")
            cursor.execute(
                f"""
                    INSERT INTO Branch (
                        {", ".join(primary_table_query_data["columns"])}, datafileid
                    )
                    VALUES (
                        {", ".join(primary_table_query_data["values"])}, '{datafile_id}'
                    )
                    RETURNING Branch.branchid, Branch.document_date, Branch.csc_number
                """
            )
            record = cursor.fetchone()
            branchid = getattr(record, "branchid")
            branch_ids.append(branchid)
            document_date = str(getattr(record, "document_date"))
            if "LETTERS" in input_filename:
                document_date = file_date
                letter_code = secondary_query_data["values"][secondary_query_data["columns"].index("letter_code")]
                if letter_code == "09":
                    secondary_query_data["columns"][secondary_query_data["columns"].index("past_due_balance")] = "check_number"
            csc_number = str(getattr(record, "csc_number"))
            for secondary_query_data in secondary_table_query_data:
                customer_account_number = secondary_query_data["values"][secondary_query_data["columns"].index("customer_account_number")]
                cursor.execute(
                    f"""
                        WITH ins AS (
                            INSERT INTO Document (branchid, {", ".join(secondary_query_data["columns"])}, document_date)
                            VALUES ('{branchid}', {", ".join(secondary_query_data["values"])}, '{document_date}')
                            ON CONFLICT (branchid, customer_account_number, document_date) DO NOTHING
                            RETURNING documentid, recordtype, document_date, customer_account_number
                        )
                        SELECT documentid, recordtype, document_date, customer_account_number FROM ins
                        UNION ALL
                        SELECT documentid, recordtype, document_date, customer_account_number FROM Document
                        WHERE branchid='{branchid}' AND
                            customer_account_number={customer_account_number} AND document_date='{document_date}'
                        LIMIT 1;
                    """
                )
                record = cursor.fetchone()
                documentid = getattr(record, "documentid")
                customer_account_number = getattr(record, "customer_account_number") if getattr(record, "customer_account_number") is not None else ""
                record_type = getattr(record, "recordtype")
                if record_type == 11:
                    address_records.append(documentid)
                if "LETTERS" in input_filename:
                    address_records.append(documentid)
                if "INV" in input_filename:
                    pdf_prefix = "NINV_"
                elif "STA" in input_filename:
                    pdf_prefix = "NSTA_"
                elif "REN" in input_filename:
                    pdf_prefix = "NREN_"
                elif "DUN" in input_filename:
                    pdf_prefix = "NDUN_"
                elif "LETTERS" in input_filename:
                    pdf_prefix = "NLET_"
                pdf_filename = pdf_prefix + document_date[2:4] + document_date[5:7] + document_date[8:] + "_" + csc_number + "_" + customer_account_number + "_" + str(SEQUENCE_NUMBER[0]).zfill(6) + "_N.pdf"
                cursor.execute(
                    f"""
                        UPDATE Document
                        SET pdffile = ?
                        WHERE documentid = ?
                    """,
                    pdf_filename,
                    documentid
                )
                update_sequence_number()
                record_data[documentid] = []
                csc_1654_message = ""
                if "STA" in input_filename:
                    update_query_data_sta(secondary_query_data)
                if "STA" in input_filename or  "INV" in input_filename or "REN" in  input_filename or "DUN" in  input_filename:
                    csc_number = primary_table_query_data["values"][primary_table_query_data["columns"].index("csc_number")]
                    csc_number = str(csc_number).replace("'","")                                            
                    #if csc_number in str(FLORIDA_CSCS):                        
                    for tertiary_query_data in secondary_query_data["tertiary_table_query_data"]:                             
                        #if "INV" in input_filename: 
                        if "REN" not in  input_filename: 
                            try: 
                                record_type = str(tertiary_query_data["values"][tertiary_query_data["columns"].index("recordType")])
                                #else: 
                                #    record_type = str(tertiary_query_data["values"][tertiary_query_data["columns"].index("recordtype")])   
                                record_type = record_type.replace("'","")                           
                                if '18' in record_type:                                 
                                    transaction_invoice_comment = str(tertiary_query_data["values"][tertiary_query_data["columns"].index("transaction_invoice_comment")])
                                    transaction_invoice_comment = transaction_invoice_comment.replace("'","")    
                                    # if csc_number in str(FLORIDA_CSCS):                               
                                    tertiary_query_data["values"][tertiary_query_data["columns"].index("transaction_invoice_comment")] = "'Work performed by " + transaction_invoice_comment + "'"
                                    # else: 
                                    #    tertiary_query_data["values"][tertiary_query_data["columns"].index("transaction_invoice_comment")] = "''"     
                            except Exception as err: 
                                print(err)                         
                                pass
                        # cursor.execute(
                        #     f"""
                        #         WITH ins AS (
                        #             INSERT INTO Document_Line (documentid, {", ".join(tertiary_query_data["columns"])})
                        #             VALUES ('{documentid}', {", ".join(tertiary_query_data["values"])})
                        #             ON CONFLICT (documentid, rownumber) DO NOTHING
                        #             RETURNING document_lineid, recordtype
                        #         )
                        #         SELECT document_lineid, recordtype FROM ins
                        #         UNION ALL
                        #         SELECT document_lineid, recordtype FROM Document_Line
                        #         WHERE documentid='{documentid}' AND rownumber={tertiary_query_data["values"][-1]}
                        #         LIMIT 1;
                        #     """
                        # )
                        # record = cursor.fetchone()
                        cursor.execute(
                        f"""
                            WITH ins AS (
                                INSERT INTO Document_Line (documentid, {", ".join(tertiary_query_data["columns"])})
                                VALUES ('{documentid}', {", ".join(tertiary_query_data["values"])})
                                ON CONFLICT (documentid, rownumber) DO NOTHING
                                RETURNING document_lineid, recordtype,transaction_reference
                            )
                            SELECT document_lineid, recordtype,transaction_reference FROM ins
                            UNION ALL
                            SELECT document_lineid, recordtype,transaction_reference FROM Document_Line
                            WHERE documentid='{documentid}' AND rownumber={tertiary_query_data["values"][-1]}
                            LIMIT 1;
                        """
                        )
                        record = cursor.fetchone()
                        transaction_reference =  getattr(record, "transaction_reference")  
                     
                        if transaction_reference != "0": 
                            cursor.execute(
                                f"""
                                UPDATE Document SET transaction_reference = '{transaction_reference}'
                                where documentid  = '{documentid}'
                                """
                            )
                    
                        if "INV" in input_filename:
                            csc_1654_message = create_block_data_inv(record_data, cursor, record, tertiary_query_data, csc_number, documentid, csc_1654_message, CSC_1654_MESSAGES, TEXAS_RAILROAD_MESSAGE)
                        if "STA" in input_filename:
                            csc_1654_message = create_block_data_sta(record_data, cursor, record, tertiary_query_data, csc_number, documentid, csc_1654_message, CSC_1654_MESSAGES, TEXAS_RAILROAD_MESSAGE)
                        if "REN" in input_filename:
                            csc_1654_message = create_block_data_ren(record_data, cursor, record, tertiary_query_data, csc_number, documentid, csc_1654_message, CSC_1654_MESSAGES)
                        if "DUN" in input_filename:
                            csc_1654_message = create_block_data_dun(record_data, cursor, record, tertiary_query_data, csc_number, documentid, csc_1654_message, CSC_1654_MESSAGES)
                    # if csc_1654_message != "":
                #     cursor.execute(f"UPDATE document SET csc_1654_message = {clean_string(csc_1654_message)} WHERE documentid = '{documentid}'")

    if "INV" in input_filename:
        update_block_data_inv(record_data, connection)
    if "STA" in input_filename:
        update_block_data_sta(record_data, connection)
    if "REN" in input_filename:
        update_block_data_ren(record_data, connection)
    if "DUN" in input_filename:
        update_block_data_dun(record_data, connection)
     
    #AMol test 
    return [mail_manager(connection, input_filename, address_records), remittance_imb_mail_manager(connection, branch_ids, document_date)], document_count, datafile_id, document_date
    #return mail_manager(connection, input_filename, address_records), document_count, datafile_id,document_date


def sftp_download(server, username, password, directory, download_dst):
    download_filenames = []
    with pysftp.Connection(host=server, username=username, password=password) as sftp:
        sftp.cwd(f"{directory}")

        for filename in sftp.listdir():
            if ".zip" in filename.lower()[-4:] or ".txt" in filename.lower()[-4:]:
                previous_size = -1
                while True:
                    if sftp.stat(filename).st_size == previous_size:
                        sftp.get(filename, os.path.join(download_dst, filename))
                        if sftp.exists(f"done/" + filename):
                            sftp.remove(f"done/" + filename)
                        sftp.rename(filename, f"done/" + filename)
                        download_filenames.append(os.path.join("INPUT", "ZIPPED", filename))
                        break
                    previous_size = sftp.stat(filename).st_size
                    time.sleep(5)

    return download_filenames


def ftp_download(server, username, password, directory):
    download_filenames = []
    with FTP(server, username, password) as ftp:
        ftp.cwd(directory)

        for filename in ftp.nlst():
            if filename.lower()[-4:] == ".zip":
                download_filename = os.path.join("INPUT", "ZIPPED", filename)
                with open(download_filename, "wb") as file_binary:
                    ftp.retrbinary(
                        "RETR %s" % filename,
                        file_binary.write,
                        1024
                        )
                ftp.sendcmd("RNFR " + f"{filename}")
                ftp.sendcmd("RNTO " + f"done/{filename}")
                download_filenames.append(download_filename)

    return download_filenames


def get_file_data(input_filename, connection, datafile_id):
    file_data = {}
    if "INV" in input_filename:
        current_bal = "expanded_current_balance"
        total_due = "expanded_invoice_total"
    if "STA" in input_filename:
        current_bal = "expanded_current_balance"
        total_due = "total_due"
    if "REN" in input_filename:
        current_bal = "current_balance"
        total_due = "total_due"
    if "DUN" in input_filename:
        current_bal = "current_balance"
        total_due = "total_balance"
    if "LETTERS" in input_filename:
        current_bal = "letter_amount_1"
        total_due = "total_due"
    with connection.cursor() as cursor:
        cursor.execute("SELECT branchid, csc_number FROM branch WHERE datafileid = ?", datafile_id)
        for branch in cursor.fetchall():
            branchid = getattr(branch, "branchid")
            file_data[branchid] = {
                "csc_number": getattr(branch, "csc_number"),
                "Accounts": 0,
                "CurrentBal": 0,
                "TotalDue": 0,
            }
    for branchid, branch_data in file_data.items():
        with connection.cursor() as cursor:
            cursor.execute(f"SELECT {current_bal}, {total_due} FROM document WHERE branchid = ?", branchid)
            for document in cursor.fetchall():
                branch_data["Accounts"] += 1
                if "LETTERS" not in input_filename:
                    branch_data["CurrentBal"] += int(getattr(document, current_bal))
                    branch_data["TotalDue"] += int(getattr(document, total_due))
    csc_data = {}
    for branchid, branch_data in file_data.items():
        if branch_data["csc_number"] not in csc_data:
            csc_data[branch_data["csc_number"]] = {
                "Accounts": branch_data["Accounts"],
                "CurrentBal": branch_data["CurrentBal"],
                "TotalDue": branch_data["TotalDue"],
            }
        else:
            csc_data[branch_data["csc_number"]]["Accounts"] += branch_data["Accounts"]
            if "LETTERS" not in input_filename:
                csc_data[branch_data["csc_number"]]["CurrentBal"] += branch_data["CurrentBal"]
                csc_data[branch_data["csc_number"]]["TotalDue"] += branch_data["TotalDue"]
    file_data_string = ""
    sum_total_due = 0
    for csc_number, csc_datum in csc_data.items():
        accounts = str(csc_datum["Accounts"]).rjust(8)
        file_data_string += f"{csc_number}:    Accounts = {accounts}"
        if "LETTERS" not in input_filename:
            current_balance = "${:,.2f}".format(csc_datum["CurrentBal"] / 100).rjust(15)
            file_data_string += f"    CurrentBal = {current_balance}"
            sum_total_due += csc_datum["TotalDue"]
            file_data_string += f"   TotalDue = " + "${:,.2f}".format(csc_datum["TotalDue"] / 100).rjust(15)
        file_data_string += "\n"
    if "LETTERS" not in input_filename:
        file_data_string += "\n\nSum Total Due = $" + "{:,.2f}".format(sum_total_due / 100)
    return file_data_string


def create_pdfs(input_filename, datafile_id):
    # if "SAESTA" in input_filename or "SAEDUN" in input_filename or "LETTERS" in input_filename or "denied_credit" in input_filename:
    #     if "LETTERS" in input_filename:
    #         workflow_filename = r"\\10.180.10.87\Suburban\Quadient\LETTERS\Suburban_LTR_COLL_15b.wfd"
    #     elif "SAEDUN" in input_filename:
    #         workflow_filename = r"\\10.180.10.87\Suburban\Quadient\LETTERS\Suburban_LTR_DUN_15b.wfd"
    #     elif "denied_credit" in input_filename:
    #         workflow_filename = r"\\10.180.10.87\Suburban\Quadient\LETTERS\Suburban_LTR_DoC_15a.wfd"
    #     elif "SAESTA" in input_filename:
    #         workflow_filename = r"\\10.180.10.87\Suburban\Quadient\STATEMENT\Suburban_Statement_Prod.wfd"
    #     #run_InspirePSCLI(workflow_filename, "PDF_WEB", r"\\10.180.10.87\PDF\Production\010222024\%h03", datafile_id, DDA_ENV,"-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
    #     run_InspirePSCLI(workflow_filename, "PDF_WEB", r"\\10.180.10.87\PDF\Production\010222024\%h03", datafile_id,"-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
    # if "SAEINV" in input_filename or "SAEREN" in input_filename:
    #     if "SAEINV" in input_filename:
    #         workflow_filename = r"\\10.180.10.87\Suburban\Quadient\INVOICE\Suburban_Invoice_spl_Prod.wfd"
    #     elif "SAEREN" in input_filename:
    #         workflow_filename = r"\\10.180.10.87\Suburban\Quadient\RENTALS\Suburban_Rental_spl_Prod.wfd"
    #    #run_InspirePSCLI(workflow_filename, "PDF_WEB", r"\\10.180.10.87\PDF\Production\010222024\%h03", datafile_id, DDA_ENV,"-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
    #     run_InspirePSCLI(workflow_filename, "PDF_WEB", r"\\10.180.10.87\PDF\Production\010222024\%h03", datafile_id,"-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
    #     if "SAEINV" in input_filename:
    #         workflow_filename = r"\\10.180.10.87\Suburban\Quadient\INVOICE\Suburban_Invoice_Prod.wfd"
    #     elif "SAEREN" in input_filename:
    #         workflow_filename = r"\\10.180.10.87\Suburban\Quadient\RENTALS\Suburban_Rental_Prod.wfd"
    #     #run_InspirePSCLI(workflow_filename, "PDF_WEB", r"\\10.180.10.87\PDF\Production\010222024\%h03", datafile_id, DDA_ENV,"-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
    #     run_InspirePSCLI(workflow_filename, "PDF_WEB", r"\\10.180.10.87\PDF\Production\010222024\%h03", datafile_id,"-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
    # if "SAESTA" in input_filename or "SAEDUN" in input_filename or "LETTERS" in input_filename or "denied_credit" in input_filename:
    #     if "LETTERS" in input_filename:
    #         workflow_filename = LETTERS_WFD
    #     elif "SAEDUN" in input_filename:
    #         workflow_filename = SAEDUN_WFD
    #     elif "denied_credit" in input_filename:
    #         workflow_filename = DC_WFD
    #     elif "SAESTA" in input_filename:
    #         workflow_filename = SAESTA_WFD
    #     run_InspirePSCLI(workflow_filename, "PDF_WEB", PDF_FOLDER, datafile_id, "-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
    # if "SAEINV" in input_filename or "SAEREN" in input_filename:
    #     try:
    #         if "SAEINV" in input_filename:
    #             workflow_filename = SAEINV_WFD
    #         elif "SAEREN" in input_filename:
    #             workflow_filename = SAEREN_WFD
    #         run_InspirePSCLI(workflow_filename, "PDF_WEB", PDF_FOLDER, datafile_id, "-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
    #     except Exception as err: 
    #         if "SAEINV" in input_filename:
    #            workflow_filename = SAEINV_SPL_WFD
    #         elif "SAEREN" in input_filename:
    #            workflow_filename = SAEREN_SPL_WFD
    #         run_InspirePSCLI(workflow_filename, "PDF_WEB", PDF_FOLDER, datafile_id, "-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
    #         pass
    
    if "SAESTA" in input_filename or "SAEDUN" in input_filename or "LETTERS" in input_filename or "denied_credit" in input_filename:
        if "LETTERS" in input_filename:
            workflow_filename = LETTERS_WFD
        elif "SAEDUN" in input_filename:
            workflow_filename = SAEDUN_WFD
        elif "denied_credit" in input_filename:
            workflow_filename = DC_WFD
        elif "SAESTA" in input_filename:
            workflow_filename = SAESTA_WFD
        run_InspirePSCLI(workflow_filename, "PDF_WEB", PDF_FOLDER, datafile_id, "-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
    if "SAEINV" in input_filename or "SAEREN" in input_filename:
        if "SAEINV" in input_filename:
            workflow_filename = SAEINV_SPL_WFD
        elif "SAEREN" in input_filename:
            workflow_filename = SAEREN_SPL_WFD
        run_InspirePSCLI(workflow_filename, "PDF_WEB", PDF_FOLDER, datafile_id, "-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
        if "SAEINV" in input_filename:
            workflow_filename = SAEINV_WFD
        elif "SAEREN" in input_filename:
            workflow_filename = SAEREN_WFD
        run_InspirePSCLI(workflow_filename, "PDF_WEB", PDF_FOLDER, datafile_id, "-splitbygroup", "10.2.0.194", "30354", r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe", r"\\10.180.10.87\Suburban\Quadient\LOG")
 

def process_file(input_filename):
    """Process a single file with the given logic."""
    try:
        connection = pyodbc.connect(CONNECT_STRING) # Create new connection for each process
        cursor = connection.cursor()

        # Handle LETTERS files
        if "LETTERS" in input_filename:
            result = subprocess.run(
                ["python", r"D:\PythonApp\suburban_data_processing\format_letters_file.py", input_filename],
                capture_output=True, text=True
            )
            if result.returncode != 0:
                raise Exception(f"format_letters_file.py failed: {result.stderr}")

        # Check for specific file types
        if any(x in input_filename for x in ["SAEINV", "SAESTA", "SAEREN", "SAEDUN", "LETTERS", "denied_credit"]):
            display_message(f"Processing {os.path.basename(input_filename)}")

            # Check for duplicates
            print(f"SELECT datafilename FROM DATAFILE WHERE datafilename ='{os.path.basename(input_filename)}'")
            cursor.execute(f"SELECT datafilename FROM DATAFILE WHERE datafilename = %s", (os.path.basename(input_filename)))
            datafilename = cursor.fetchone()
            if datafilename:
                email_body = f"Exiting File processing. File {os.path.basename(input_filename)} is already processed..."
                send_email(
                    f"Duplicate File - {os.path.basename(input_filename)}",
                    email_body,
                    "help_desk@contentcritical.com",
                    [
                        "amol.sagar@contentcritical.com",
                        # "tariq.mohamed@contentcritical.com",
                        # "riddhi.rana@contentcritical.com",
                        # "douglas.sikora@contentcritical.com",
                        # "spessoa@suburbanpropane.com",
                        # "plucien@suburbanpropane.com",
                        # "_UC4_Operations@suburbanpropane.com",
                        # "pakasapinov@suburbanpropane.com",
                        # "smurray@suburbanpropane.com",
                        # "avillanueva@suburbanpropane.com",
                        # "scampbell@suburbanpropane.com",
                        # "cust_suburban@contentcritical.com",
                    ],
                    None
                )
                return

            # Process file
            mail_manager_filename, document_count, datafile_id, document_date = process_input_file(input_filename, connection)

            # Run inserts.py
            result = subprocess.run(
                ["python", r"D:\Web\Online\Suburban\Process\inserts.py", os.path.basename(input_filename)],
                capture_output=True, text=True
            )
            if result.returncode != 0:
                raise Exception(f"inserts.py failed: {result.stderr}")

            # Update mail manager
            return_mail_manager_filenames = get_mail_manager_files(connection, mail_manager_filename, datafile_id)
            supress_count = mail_manager_database_update(return_mail_manager_filenames, connection)
            email_body = f"Filename - {os.path.basename(input_filename)}\n\nDocument count - {str(document_count)}\n\nSuppress count - {str(supress_count)}"

            if "denied_credit" not in input_filename:
                file_data = get_file_data(input_filename, connection, datafile_id)
                file_data_filename = os.path.join("REPORTS", os.path.basename(input_filename)[:-4] + ".rpt")
                header_for = {
                    "SAEINV": "INVOICE",
                    "SAESTA": "STATEMENT",
                    "SAEDUN": "DUNNING",
                    "LETTERS": "LETTERS",
                    "SAEREN": "RENTALS"
                }.get(next((x for x in ["SAEINV", "SAESTA", "SAEDUN", "LETTERS", "SAEREN"] if x in input_filename), ""))

                curr_time = datetime.now().strftime('%H:%M:%S')
                curr_date = datetime.now().strftime("%m/%d/%Y")
                match = re.search(r'\d{2}\d{2}\d{2}', input_filename)
                file_date = datetime.strptime(match.group(), '%y%m%d').strftime("%m/%d/%Y")
                document_date = file_date if "LETTERS" in input_filename else datetime.strptime(document_date, "%Y-%m-%d").strftime("%m/%d/%Y")

                report_header = f"""\n\n#######################################################################################\n
  {header_for} REPORT OF COUNTS FOR RUN TIME {curr_time} EST PROCESSING DATE IS {curr_date}
                                   \n#######################################################################################
                                   \n{document_date} is {header_for} Date For {header_for} COUNTS FROM {os.path.basename(input_filename)}\n
 ______________________________________________________________________________________\n
{file_data}\n 
                                 """
                report_footer = f"""\n#######################################################################################\n
  THE TOTAL # OF RECORDS FOR {os.path.basename(input_filename)} = {document_count}\n
#######################################################################################\n\n                                   
                                 """
                with open(file_data_filename, "w+") as file_data_file:
                    file_data_file.write(report_header + report_footer)
                email_body += report_header + report_footer

                send_email(
                    f"Suburban Propane Console Report- {os.path.basename(input_filename)}",
                    email_body,
                    "help_desk@contentcritical.com",
                    [
                        "amol.sagar@contentcritical.com",
                        "tariq.mohamed@contentcritical.com",
                        "riddhi.rana@contentcritical.com",
                        "douglas.sikora@contentcritical.com",
                        "spessoa@suburbanpropane.com",
                        "plucien@suburbanpropane.com",
                        "_UC4_Operations@suburbanpropane.com",
                        "pakasapinov@suburbanpropane.com",
                        "smurray@suburbanpropane.com",
                        "avillanueva@suburbanpropane.com",
                        "scampbell@suburbanpropane.com",
                        "cust_suburban@contentcritical.com",
                     ],
                    file_data_filename
                )

            # Create PDFs with retry logic
            display_message("    Creating PDFs.")
            for attempt in range(5):
                try:
                    create_pdfs(input_filename, datafile_id)
                    break
                except Exception as e:
                    display_message("        DDA Failure")
                    if attempt < 4:
                        time.sleep(10)
                    else:
                        send_error_email(e, "SUBURBAN")

            # Move PDFs
            pdf_dir = r"D:\PDF\Production\010222024"
            for pdf in os.listdir(pdf_dir):
                pdf_path = os.path.join(pdf_dir, pdf)
                if not os.path.isdir(pdf_path):
                    dest_pdf = os.path.join(r"D:\PDF\Production", os.path.basename(pdf))
                    if os.path.exists(dest_pdf):
                        os.remove(dest_pdf)
                    shutil.copy(pdf_path, r"D:\PDF\Production")
                    done_path = os.path.join(r"D:\PDF\Production\010222024\done", os.path.basename(pdf))
                    if os.path.exists(done_path):
                        os.remove(done_path)
                    shutil.move(pdf_path, r"D:\PDF\Production\010222024\done")

        # Archive file
        shutil.move(input_filename, os.path.join("INPUT", "ARCHIVE", "DECODED"))

    except Exception as error:
        send_error_email(error, body=f"Filename - {os.path.basename(input_filename)}")
    finally:
        connection.close()

def main():
    connection = pyodbc.connect(CONNECT_STRING)
    try:
        input_filenames = get_input_filenames(connection)  # Assume this function exists
        connection.close()

        # Use multiprocessing Pool
        if len(input_filenames) >0: 
            with Pool(processes=len(input_filenames)) as pool:
                pool.map(process_file, input_filenames)

    except Exception as e:
        print(f"Main error: {e}")
    # finally:
    #     if connection.open:
    #         connection.close()
 


if __name__ == "__main__":
    if os.path.exists("process.lck"):
        sys.exit()
    log_filename = os.path.join("LOG", datetime.now().strftime("%Y%m%d%H%M%S") + ".log")
    with open("process.lck", "a+") as lock_file:
        lock_file.write("Process Running\n")
    with open("sequence_number.txt", "r+") as sequence_number_file:
        SEQUENCE_NUMBER = [int(sequence_number_file.read())]
    try:
        main()
    except Exception as error:
        send_error_email(error)
    with open("sequence_number.txt", "w+") as sequence_number_file:
        sequence_number_file.write(str(SEQUENCE_NUMBER[0]))
    shutil.move("process.lck", log_filename)
