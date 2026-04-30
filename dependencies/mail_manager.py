from datetime import datetime, date
import os
import re
import shutil
import time
from config import SFTP_PASSWORD, SFTP_SERVER, SFTP_USERNAME

from dependencies.utility_functions import display_message, send_email, sftp_upload


def get_mail_manager_files(connection, mail_manager_filenames, datafile_id):
    """_BCCOUT.txt"""
    # TODO SET UP
    #Amol test
    return_mail_manager_filenames = []
    #return return_mail_manager_filenames
    for mail_manager_filename in mail_manager_filenames:
        attempt = 1
        while True:
            try:
                attempt += 1
                shutil.copy(mail_manager_filename, r"\\10.2.0.76\ftproot")
                if "SUB_REMITADD_" not in mail_manager_filename:
                    display_message(f"    {os.path.basename(mail_manager_filename)} sent to Mail Manager.")
                    with connection.cursor() as cursor:
                        cursor.execute("UPDATE datafile SET status = 'SendToMailManager' WHERE datafileid = ?", datafile_id)
                break
            except:
                time.sleep(2)
        if "SUB_REMITADD_" in mail_manager_filename:
            return_mail_manager_filenames.append(os.path.basename(mail_manager_filename)[:-4] + "_BCCOUT.txt")    
        else:          
            return_mail_manager_filenames.append(os.path.basename(mail_manager_filename)[:-4] + "_BCCOUT.idx")
    copy_return_mail_manager_filenames = return_mail_manager_filenames.copy()
    wait_count = 0
    while len(copy_return_mail_manager_filenames) > 0 and wait_count < 180:
        for copy_return_mail_manager_filename in copy_return_mail_manager_filenames:
                try: 
                    if "SUB_REMITADD_" not in copy_return_mail_manager_filename:
                        shutil.copy(os.path.join(r"\\10.2.0.76\Suburban", copy_return_mail_manager_filename), os.path.join("INDEX", "OUT"))
                        display_message(f"    {(copy_return_mail_manager_filename)} returned from Mail Manager.")
                        with connection.cursor() as cursor:
                            cursor.execute("UPDATE datafile SET status = 'SentToPDFGeneration' WHERE datafileid = ?", datafile_id)
                    else:
                        shutil.copy(os.path.join(r"\\10.2.0.76\Suburban", copy_return_mail_manager_filename), os.path.join("INDEX", "REMITTANCE_IMB", "OUT"))
                    if os.path.exists(os.path.join(r"\\10.2.0.76\Suburban", "done", copy_return_mail_manager_filename)):
                        os.remove(os.path.join(r"\\10.2.0.76\Suburban", "done", copy_return_mail_manager_filename))
                    shutil.move(os.path.join(r"\\10.2.0.76\Suburban", copy_return_mail_manager_filename), os.path.join(r"\\10.2.0.76\Suburban", "done"))
                    copy_return_mail_manager_filenames.remove(copy_return_mail_manager_filename)
                except Exception: 
                    pass  
        if len(copy_return_mail_manager_filenames) > 0:
            #Amol Test
            time.sleep(10)
            wait_count += 1
    # if len(copy_return_mail_manager_filenames) > 0:
    #     send_email() # TODO
    return return_mail_manager_filenames


def remittance_imb_mail_manager(connection, branch_ids, document_date: datetime):
#def remittance_imb_mail_manager(connection, branch_ids, document_date):
    with open("remittance_sequence_number.txt", "r+") as sequence_number_file:
        remittance_sequence_number = sequence_number_file.read()
    with open("remittance_sequence_number.txt", "w+") as sequence_number_file:
        if remittance_sequence_number != "999":
            sequence_number_file.write(str(int(remittance_sequence_number) + 1))
        else:
            sequence_number_file.write("1")
    
    #cr_date = datetime.strptime(document_date, '%Y-%m-%d')
    if '-' in document_date: 
       document_date = datetime.strptime(document_date, "%Y-%m-%d").strftime("%Y%m%d")  
       document_date = document_date[2:]
    else: 
       document_date  = '20'+document_date
    #crrdate = cr_date.strftime(cr_date,"%m/%d/%Y")
    #remittance_prefix = f"SUB_REMITADD_{str(document_date.strftime('%y%m%d'))}_{remittance_sequence_number.zfill(3)}"
    remittance_prefix = f"SUB_REMITADD_{str(document_date)}_{remittance_sequence_number.zfill(3)}"
    #output_filename = "abcd"
    if os.path.exists(os.path.join(r"\\10.2.0.76\Suburban", remittance_prefix + "_BCCOUT.idx")):
        os.remove(os.path.join(r"\\10.2.0.76\Suburban", remittance_prefix + "_BCCOUT.idx"))      
        
    output_filename = os.path.join("INDEX", "REMITTANCE_IMB", "IN", remittance_prefix + ".TXT")
    with open(output_filename, "w+") as txt_file:
        for branch_id in branch_ids:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                        SELECT division, division_name_1, division_name_2, division_name_3, division_name_4, expanded_division_number FROM Branch
                        WHERE branchid = ?
                    """,
                    branch_id
                )
                record = cursor.fetchone()
                division = getattr(record, "division")
                division_name_1 = getattr(record, "division_name_1")
                division_name_2 = getattr(record, "division_name_2")
                division_name_3 = getattr(record, "division_name_3")
                division_name_4 = getattr(record, "division_name_4")
                expanded_division_number = getattr(record, "expanded_division_number")
                txt_file.write(f"{division}|{division_name_1}|{division_name_2}|{division_name_3}|{division_name_4}|{expanded_division_number}|{branch_id}\n")
    return output_filename


def mail_manager(connection, input_filename, address_records):
    if os.path.exists(os.path.join(r"\\10.2.0.76\Suburban", os.path.basename(input_filename)[:-4] + "_BCCOUT.idx")):
        os.remove(os.path.join(r"\\10.2.0.76\Suburban", os.path.basename(input_filename)[:-4] + "_BCCOUT.idx"))
    output_filename = os.path.join("INDEX", "IN", os.path.basename(input_filename)[:-4] + ".TXT")
    with open(output_filename, "w+") as txt_file:
        for documentid in address_records:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                        SELECT customer_name, customer_address_line_1, customer_address_line_2, town, state, zip FROM Document
                        WHERE documentid = ?
                    """,
                    documentid
                )
                record = cursor.fetchone()
                customer_name = getattr(record, "customer_name")
                customer_address_line_1 = getattr(record, "customer_address_line_1")
                customer_address_line_2 = getattr(record, "customer_address_line_2") if getattr(record, "customer_address_line_2") is not None else ""
                town = getattr(record, "town")
                state = getattr(record, "state")
                zip = getattr(record, "zip")
                customer_address_line_2 = re.sub(r"\|", "/",customer_address_line_2)  
                customer_address_line_1 = re.sub(r"\|", "/",customer_address_line_1)     
                txt_file.write(f"{customer_name}|{customer_address_line_1}|{customer_address_line_2}|{town}|{state}|{zip}|{documentid}\n")
    return output_filename


def address_move_update_process(connection, ncoa_documentids, return_mail_manager_filename):
    input_filename = return_mail_manager_filename[:-11] + (".TXT" if ("" in return_mail_manager_filename or "" in return_mail_manager_filename) else ".txt")
    ncoa_filename = os.path.join("ARCHIVE", "NCOA", f"{input_filename[:-4]}_ncoa.001")
    with open(ncoa_filename, "a+") as ncoa_file:
        for documentid in ncoa_documentids:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                        SELECT
                            customer_account_number,
                            customer_name,
                            customer_address_line_1,
                            customer_address_line_2,
                            town,
                            state,
                            zip,
                            ncoa_customer_address_line_1,
                            ncoa_customer_address_line_2,
                            ncoa_town,
                            ncoa_state,
                            ncoa_zip,
                            Branch.csc_number
                        FROM Document
                        JOIN Branch on Document.branchid = Branch.branchid
                        WHERE documentid = ?
                    """,
                    documentid
                )
                record = cursor.fetchone()
                csc_number = getattr(record, "csc_number")
                account_number = getattr(record, "customer_account_number")
                customer_name = getattr(record, "customer_name")
                customer_address_line_1 = getattr(record, "customer_address_line_1")
                customer_address_line_2 = getattr(record, "customer_address_line_2")
                town = getattr(record, "town")
                state = getattr(record, "state")
                zip = getattr(record, "zip")
                ncoa_customer_address_line_1 = getattr(record, "ncoa_customer_address_line_1")
                ncoa_customer_address_line_2 = getattr(record, "ncoa_customer_address_line_2")
                ncoa_town = getattr(record, "ncoa_town")
                ncoa_state = getattr(record, "ncoa_state")
                ncoa_zip = getattr(record, "ncoa_zip")
                ncoa_file.write(f'"{csc_number}"|~"{account_number}"|~"B"|~"000"|~"{customer_name}"|~"{ncoa_customer_address_line_1}"|~"{ncoa_customer_address_line_2}"|~""|~"{ncoa_town}"|~"{ncoa_state}"|~"{ncoa_zip}"|~""|~""|~"CCS"~\n')

    #sftp_upload(ncoa_filename, SFTP_SERVER, SFTP_USERNAME, SFTP_PASSWORD, "/incoming/sub_returnedfile")
    send_email(
        "Suburban Propane NCOA Report " + os.path.basename(ncoa_filename),
        os.path.basename(ncoa_filename),
        "help_desk@contentcritical.com",
        [
             "amol.sagar@contentcritical.com",
            "tariq.mohamed@contentcritical.com",
             "riddhi.rana@contentcritical.com",
             #"helene.fischer@contentcritical.com",
             "douglas.sikora@contentcritical.com",
             "spessoa@suburbanpropane.com", 
             "plucien@suburbanpropane.com",
            "_UC4_Operations@suburbanpropane.com",
            "pakasapinov@suburbanpropane.com",
            "smurray@suburbanpropane.com",
            "avillanueva@suburbanpropane.com",
            "scampbell@suburbanpropane.com",
             "cust_suburban@contentcritical.com",
            #"amol.sagar@contentcritical.com",
                
        ],
        attachment=ncoa_filename
    )


def return_mail_process(connection, return_mail_documentids, return_mail_manager_filename):
    # return
    # Full Name|Orig_Address1|Orig_Address2|Orig_City|Or|Orig_Zip|c1|Re|Delivery Address|Suite/Apt|City|St|ZIP+4|Sequence N|IM barcode Digits|

    headers = "Doc Type,Filename,CSC,Acct Number,SubID,PieceID,Mailing_Name,Mailing_Addres1,Mailing_Addres2,Mailing_Addres3,MailingCity,MailingState,Mailing5DigitZIPCode,Return_Reason,NEWAddress1,NEWAddress2,NEWCity,NEWState,NEW5DigitZIPCode,Return Date\n"

    if "INV" in return_mail_manager_filename:
        doc_type = "Invoice"
    if "STA" in return_mail_manager_filename:
        doc_type = "Statements"
    if "REN" in return_mail_manager_filename:
        doc_type = "RentalInvoice"
    if "DUN" in return_mail_manager_filename:
        doc_type = "DunningLetters"
    if "denied_credit" in return_mail_manager_filename:
        doc_type = "CreditDenialLetters"
    if "LETTERS" in return_mail_manager_filename:
        doc_type = "Collection Letters"
    input_filename = return_mail_manager_filename[:-11] + (".TXT" if ("" in return_mail_manager_filename or "" in return_mail_manager_filename) else ".txt")
    run_date = datetime.now()
    file_date = run_date.strftime("%Y%m%d")
    return_date = run_date.strftime("%m/%d/%Y")

    return_mail_filename = os.path.join("ARCHIVE", "RETURN_MAIL", f"SUBURBAN_RETURNMAIL_{file_date}_{input_filename[:-4]}_CUSTRPT.csv")

    with open(return_mail_filename, "a+") as return_mail_file:
        return_mail_file.write(headers)
        for documentid in return_mail_documentids:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                        SELECT
                            customer_account_number,
                            customer_name,
                            customer_address_line_1,
                            customer_address_line_2,
                            town,
                            state,
                            zip,
                            ncoa_customer_address_line_1,
                            ncoa_customer_address_line_2,
                            ncoa_town,
                            ncoa_state,
                            ncoa_zip,
                            suppress_reason,
                            Branch.csc_number
                        FROM Document
                        JOIN Branch on Document.branchid = Branch.branchid
                        WHERE documentid = ?
                    """,
                    documentid
                )
                record = cursor.fetchone()
                csc_number = getattr(record, "csc_number")
                account_number = getattr(record, "customer_account_number")
                customer_name = getattr(record, "customer_name").replace(",", "-")
                customer_address_line_1 = str(getattr(record, "customer_address_line_1")).replace(",", "-")
                customer_address_line_2 = str(getattr(record, "customer_address_line_2")).replace(",", "-")
                town = getattr(record, "town").replace(",", "-")
                state = getattr(record, "state")
                zip = getattr(record, "zip").replace(",", "-")
                suppress_reason = getattr(record, "suppress_reason").replace(",", "-")
                ncoa_customer_address_line_1 = str(getattr(record, "ncoa_customer_address_line_1")).replace(",", "-")
                ncoa_customer_address_line_2 = str(getattr(record, "ncoa_customer_address_line_2")).replace(",", "-")
                ncoa_town = getattr(record, "ncoa_town").replace(",", "-")
                ncoa_state = getattr(record, "ncoa_state")
                ncoa_zip = getattr(record, "ncoa_zip").replace(",", "-")
                return_mail_file.write(f"{doc_type},{input_filename},{csc_number},{account_number},SUBPRO,{documentid},{customer_name},{customer_address_line_1},{customer_address_line_2},,{town},{state},{zip},{suppress_reason},{ncoa_customer_address_line_1},{ncoa_customer_address_line_2},{ncoa_town},{ncoa_state},{ncoa_zip},{return_date}\n")

    #sftp_upload(return_mail_filename, SFTP_SERVER, SFTP_USERNAME, SFTP_PASSWORD, "/incoming/sub_returnedfile")
    send_email(
        "SUBURBAN RETURN MAIL FILE",
        os.path.basename(return_mail_filename),
        "help_desk@contentcritical.com",
        [
            "amol.sagar@contentcritical.com",
            "tariq.mohamed@contentcritical.com",
            "riddhi.rana@contentcritical.com",
            #"helene.fischer@contentcritical.com",
            "douglas.sikora@contentcritical.com",
            "spessoa@suburbanpropane.com", 
            "plucien@suburbanpropane.com",
            "cust_suburban@contentcritical.com",
            #"amol.sagar@contentcritical.com",
                
        ],
        attachment=return_mail_filename
    )


def cass_process(connection, cass_documentids):
    return
    with open(r"SUBURBAN_RETURNMAIL_230921_WO_IOHXZ_000_CUSTRPT.csv") as cass_file:
        cass_file.write()


def mail_manager_database_update(return_mail_manager_filenames, connection):
    supress_codes = {
        "10": "10-Invalid Address",
        "11": "11-Invalid City, State etc., Insufficient Data",
        "12": "12-Invalid State",
        "13": "13-Invalid city",
        "17": "17-Insufficient data",
        # "21": "21-Address Not found",
        "23": "23-New address could not be provided",
        "26": "26-Post Office Box has been closed -created from USPS-filed COA",
        "27": "27-Customer has moved and left no forwarding address - created from a USPS-files COA",
        "28": "28-Foreign Move. No Forwarding given",
        # "33": "33-Non-Deliverable",
        "36": "36-Individual move",
        "37": "37-Family move",
        "38": "38-Business move",
    }
    supress_count = 0
    for return_mail_manager_filename in return_mail_manager_filenames:
        if "SUB_REMITADD_" in return_mail_manager_filename:
            with open(os.path.join("INDEX", "REMITTANCE_IMB", "OUT", return_mail_manager_filename), "r+") as return_mail_manager_file:
                for line in return_mail_manager_file.readlines():
                    line_data = line.split("|")
                    branch_id = line_data[6]
                    remittance_imb = line_data[7]
                    with connection.cursor() as cursor:
                        cursor.execute("UPDATE Branch SET remittance_imb = ? WHERE branchid = ?", remittance_imb,branch_id)
            continue
        ncoa_documentids = []
        return_mail_documentids = []
        cass_documentids = []
        empty_usps_imbs = ""
        with open(os.path.join("INDEX", "OUT", return_mail_manager_filename), "r+") as return_mail_manager_file:
            for line in return_mail_manager_file.readlines():
                line_data = line.split("|")
                documentid = line_data[6]
                ncoa_code = line_data[7]
                ncoa_customer_address_line_1 = line_data[8]
                ncoa_customer_address_line_2 = line_data[9]
                ncoa_town = line_data[10]
                ncoa_state = line_data[11]
                ncoa_zip = line_data[12]
                if bool(re.search('[a-zA-Z]', ncoa_zip)) or ncoa_zip == "00001":
                    FD = "F"
                    ncoa_zip = None
                else:
                    FD = "D"
                # documentid = line_data[13]
                usps_imb = line_data[14]
                if usps_imb == "": 
                    empty_usps_imbs = empty_usps_imbs + line
                with connection.cursor() as cursor:
                    cursor.execute(
                        """
                            UPDATE Document
                            SET
                                ncoa_code = ?,
                                ncoa_customer_address_line_1 = ?,
                                ncoa_customer_address_line_2 = ?,
                                ncoa_town = ?,
                                ncoa_state = ?,
                                ncoa_zip = ?,
                                usps_imb = ?,
                                foreign_domestic = ?
                            WHERE documentid = ?
                        """,
                        ncoa_code,
                        ncoa_customer_address_line_1,
                        ncoa_customer_address_line_2,
                        ncoa_town,
                        ncoa_state,
                        ncoa_zip,
                        usps_imb,
                        FD,
                        documentid
                    )
                    if "SAEINV" in return_mail_manager_filename or "SAESTA" in return_mail_manager_filename or "SAEREN" in return_mail_manager_filename or "SAEDUN" in return_mail_manager_filename or "LETTERS" in return_mail_manager_filename:
                        if ncoa_code in supress_codes and FD != "F":
                            cursor.execute(
                                """
                                    UPDATE Document
                                    SET
                                        supress = true,
                                        mmsupress = true,
                                        suppress_reason = ?
                                    WHERE documentid = ?
                                """,
                                supress_codes[ncoa_code],
                                documentid
                            )
                            supress_count += 1
                            return_mail_documentids.append(documentid)
                            cass_documentids.append(documentid)
                    if ncoa_code in ("36", "37", "38"):
                        cursor.execute(
                            """
                                UPDATE Document
                                SET
                                    suppress_reason = ?
                                WHERE documentid = ?
                            """,
                            supress_codes[ncoa_code],
                            documentid
                        )
                        if FD != "F":
                            ncoa_documentids.append(documentid)
                            return_mail_documentids.append(documentid)
                            cass_documentids.append(documentid)
            if empty_usps_imbs != "":                
                send_email(
                    "SUBURBAN USPS IMBS MAIL MANAGER ERROR",
                    f"BELOW RECORDS HAVE NO USPS IMBS. FILE NAME {return_mail_manager_filename}\n\n\n" + empty_usps_imbs,
                    "help_desk@contentcritical.com",
                    [
                        "amol.sagar@contentcritical.com",
                        "tariq.mohamed@contentcritical.com",
                        "riddhi.rana@contentcritical.com",                       
                        "douglas.sikora@contentcritical.com",                        
                        "cust_suburban@contentcritical.com",                         
                            
                    ],
                    None
                )                  
        address_move_update_process(connection, ncoa_documentids, return_mail_manager_filename)
        return_mail_process(connection, return_mail_documentids, return_mail_manager_filename)
        cass_process(connection, cass_documentids)
    return supress_count

