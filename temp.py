import json
import os
from pprint import pprint
import shutil

import pyodbc
from dependencies.utility_functions import sftp_upload

from suburban_propane import CONNECT_STRING, SFTP_PASSWORD, SFTP_SERVER, SFTP_USERNAME, clean_string, decode_file

def main():
    connection = pyodbc.connect(CONNECT_STRING)
    columns = ["due_date",
"california_indicator",
"open_item_flag",
"company_code_on_forms",
"miscellaneous_account_flag",
"statement_message_code",
"finance_charge_group",
"customer_account_number",
"division",
"type",
"customer_name",
"customer_address_line_1",
"customer_address_line_2",
"town",
"state",
"zip",
"previous_balance",
"invoice_total",
"current_balance",
"ocr_scan_line",
"exempt_from_card_fee_flag",
"duty_to_warn",
"invoice_number",
"special_handling",
"direct_debit_or_credit",
"expanded_account",
"credit_time_limit",
"language_flag",
"credit_limit",
"expanded_previous_balance",
"expanded_current_balance",
"expanded_invoice_total",
"discounted_amount",
"expanded_division",
"expanded_company_code",
"viewer_id",
"electronic_delivery_info",
"customer_group_code_1",
"customer_group_code_2",
"expanded_database_number",
"branchid",
"document_date",]
    branch = set()
    document = set()
    for f in ("invoice_config.json", "invoice_config.json"):
        with open(f, "r+") as fi:
            j = json.load(fi)
            for r, d in j["invoiceData"].items():
                for o in d["dataPoints"]:
                    if d["tableType"] == "primary":
                        branch.add(o["column"])
                    elif d["tableType"] == "secondary":
                        document.add(o["column"])

    branch_cols = []
    with connection.cursor() as cursor:
        for row in cursor.columns(table='branch'):
            branch_cols.append(row.column_name)
    document_cols = []
    with connection.cursor() as cursor:
        for row in cursor.columns(table='document'):
            document_cols.append(row.column_name)
    for col in columns:
        if col not in branch and col in branch_cols:
            with connection.cursor() as cursor:
                cursor.execute(f"select {col} FROM branch WHERE {col} is not null")
                print(col, cursor.fetchone())
    for col in columns:
        if col not in document and col in document_cols:
            with connection.cursor() as cursor:
                cursor.execute(f"select {col} FROM document WHERE {col} is not null")
                # print(col, cursor.fetchone())


if __name__ == "__main__":
    # main()
    connection = pyodbc.connect(CONNECT_STRING)
    pdffile_count = 0
    # x = [
    #     [[1, 2, 3], [1, 2, 3], [1, 2, 3]],
    #     [[1, 2, 3], [1, 2, 3], [1, 2, 3]],
    #     [[1, 2, 3], [1, 2, 3], [1, 2, 3]],
    # ]
    # print([item for row in x for item in row])
    x = None
    y = 10
    print(x > y)
    # sftp_upload("t.txt", SFTP_SERVER, SFTP_USERNAME, SFTP_PASSWORD, "/incoming/sub_returnedfile")
    # with connection.cursor() as cursor:
    #     cursor.execute("UPDATE datafile SET status = 'SentToPDFGeneration' WHERE datafilename in ('E3_240207_SAESTA.TXT', 'E3_240207_SAEINV.TXT', 'E3_240207_SAEDUN.TXT', 'LETTERS_240207.txt')")
        # datafileid = getattr(cursor.fetchone(), "datafileid")
        # cursor.execute("SELECT branchid FROM branch WHERE datafileid = ?", datafileid)
        # for rec in cursor.fetchall():
        #     branchid = getattr(rec, "branchid")
        #     cursor.execute("SELECT documentid, customer_account_number FROM document WHERE branchid = ?", branchid)
        #     for document in cursor.fetchall():
        #         documentid = getattr(document, "documentid")
        #         customer_account_number = getattr(document, "customer_account_number")
        #         if str(int(customer_account_number)) == "156837":
        #             cursor.execute("SELECT budget_interest_dollars FROM document_line WHERE documentid = ?", documentid)
        #             for rec in cursor.fetchall():
        #                 budget_interest_dollars = getattr(rec, "budget_interest_dollars")
        #                 print(documentid, budget_interest_dollars)
    # 1108-232538
    # for i in os.listdir(r"INPUT\UNZIPPED"):
    #     if i not in os.listdir(r"INPUT\ARCHIVE\DECODED"):
    #         print(i)
    # with open(r"INPUT\ARCHIVE\DECODED\E7_231215_SAESTA.TXT", "r+") as sta:
    #     for line_number, line in enumerate(sta.readlines()):
    #         if line[:2] == "12":
    #             if line[8:11] == "002":
    #                 print(line_number)
            

