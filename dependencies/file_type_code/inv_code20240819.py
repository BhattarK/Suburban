

import pyodbc

from dependencies.utility_functions import clean_string



def create_block_data_inv(record_data, cursor, record, tertiary_query_data, csc_number, documentid, csc_1654_message, csc_1654_messages, texas_railroad_message):
    document_lineid = getattr(record, "document_lineid")
    document_line_record_type = getattr(record, "recordtype")
    if document_line_record_type == "12":
        csc_1654_message_document_line = ""
        if csc_number == "1654":
            original_code = tertiary_query_data["values"][tertiary_query_data["columns"].index("original_code")][1:-1]
            if original_code in csc_1654_messages:
                csc_1654_message_document_line = csc_1654_messages[original_code]
                if csc_1654_message == "":
                    csc_1654_message = csc_1654_messages[original_code]
                else:
                    csc_1654_message += "\n\n" + csc_1654_messages[original_code]
        cursor.execute("SELECT transaction_reference, delivery_service_address, transaction_date, transaction_dollars, exception_data FROM Document_Line WHERE document_lineid = ?", document_lineid)
        record = cursor.fetchone()
        transaction_reference = getattr(record, "transaction_reference")
        transaction_date = getattr(record, "transaction_date")
        delivery_service_address = getattr(record, "delivery_service_address")
        transaction_dollars = float(getattr(record, "transaction_dollars"))
        record_data[documentid].append(["12", document_lineid, transaction_reference, delivery_service_address, transaction_date, transaction_dollars, csc_1654_message_document_line])
        exception_data = int(getattr(record, "exception_data"))
        if exception_data:
            cursor.execute("SELECT transaction_unit_price_2, format_with_onedecimal(cast(expanded_transaction_gallons as numeric)/10) expanded_transaction_gallons, transaction_code, original_code,transaction_code_002_quantity FROM Document_Line WHERE document_lineid = ?", document_lineid)
            record = cursor.fetchone()
            transaction_unit_price_2 = getattr(record, "transaction_unit_price_2")
            transaction_code_002_quantity = getattr(record, "transaction_code_002_quantity")
            transaction_code = getattr(record, "transaction_code")
            original_code = getattr(record, "original_code")
            expanded_transaction_gallons = getattr(record, "expanded_transaction_gallons")
            untiprice = set(str(transaction_unit_price_2))
            gallonflag = False
            if len(untiprice) == 1: 
                for e in untiprice:      
                   if e == '0':
                       gallonflag = True                
            if transaction_code == "NA" and original_code == 2 and gallonflag == True: 
                print("NA")
                print(transaction_unit_price_2)
                cursor.execute("SELECT trim(trans_desc) trans_desc FROM public.default_trans_codes where transaction_id = ?", original_code)
                trans_record = cursor.fetchone()
                trans_desc = getattr(trans_record, "trans_desc")
                print(trans_desc)
                expanded_transaction_gallons = str(expanded_transaction_gallons).replace(",","")
                print(expanded_transaction_gallons)                
                cursor.execute("UPDATE Document_Line SET transaction_code = ?,transaction_unit_price_2 = transaction_unit_price, transaction_gallons = ?  WHERE document_lineid =?", trans_desc, expanded_transaction_gallons,document_lineid)                
                #cursor.execute("UPDATE Document_Line SET transaction_code = ? WHERE document_lineid =?", trans_desc, document_lineid)                
            else: 
                cursor.execute("UPDATE Document_Line SET transaction_gallons = ?, transaction_unit_price = ? WHERE document_lineid = ?", transaction_code_002_quantity, transaction_unit_price_2, document_lineid)
        if csc_1654_message_document_line != "":
            cursor.execute(f"UPDATE document_line SET csc_1654_message = {clean_string(csc_1654_message_document_line)} WHERE document_lineid = '{document_lineid}'")
    elif document_line_record_type == "13":
        cursor.execute("SELECT delivery_address_bottom, finance_charge_dollars, price_prot_gallons_remaining, summary_product_message_bottom FROM Document_Line WHERE document_lineid = ?", document_lineid)
        record = cursor.fetchone()
        delivery_address_bottom = getattr(record, "delivery_address_bottom")
        finance_charge_dollars = getattr(record, "finance_charge_dollars")
        price_prot_gallons_remaining = getattr(record, "price_prot_gallons_remaining")
        summary_product_message_bottom = getattr(record, "summary_product_message_bottom")
        if summary_product_message_bottom != "":
            cursor.execute("UPDATE Document SET summary_product_message_bottom = ? WHERE documentid = ?", summary_product_message_bottom, documentid)
        record_data[documentid].append(["13", document_lineid, delivery_address_bottom, finance_charge_dollars, price_prot_gallons_remaining])
    elif document_line_record_type == "17":
        contract_reference_number = tertiary_query_data["values"][tertiary_query_data["columns"].index("contract_reference_number")]
        if contract_reference_number == "'Y'":
            cursor.execute(f"UPDATE document SET texas_railroad_message = {texas_railroad_message}, rec17_railroad_message = {texas_railroad_message} WHERE documentid = '{documentid}'")
        record_data[documentid].append(["17", document_lineid])
    return csc_1654_message


def update_csc_message_in_block(blocks, connection, record_12_csc_index):
    # TODO: For every block in blocks ake csc message from document line record and move it to last document line record
    with connection.cursor() as cursor:
        for block in blocks:
            csc_1654_message_document_line_found = False
            for record in block:
                if record[0] == "12":
                    if record[record_12_csc_index] != "":
                        csc_1654_message_document_line = record[record_12_csc_index]
                        cursor.execute("UPDATE document_line SET csc_1654_message = ? WHERE document_lineid = ?", None, record[1])
                        csc_1654_message_document_line_found = True
                        break
            if csc_1654_message_document_line_found:
                for record in reversed(block):
                    if record[0] == "12":
                        cursor.execute("UPDATE document_line SET csc_1654_message = ? WHERE document_lineid = ?", csc_1654_message_document_line, record[1])
                        break


def remove_redundant_address_data(connection, block):
    previous_address = ""
    with connection.cursor() as cursor:
        previous_record_type = previous_transaction_reference = current_transaction_reference = None
        for record in block:
            record_type = record[0]
            try: 
               if record_type == "12":
                  current_transaction_reference = record[2]
                  current_address = record[3]
                  document_lineid = record[1]
                  if current_address:  
                      if previous_record_type == record_type and previous_transaction_reference == current_transaction_reference  and current_address == previous_address:
                    #try: 
                          cursor.execute("UPDATE document_line SET delivery_service_address = ?, delivery_address_bottom = ? WHERE document_lineid = ?", "", "", document_lineid)                        
                    #except Exception as error:
                    #    print(error)
                      elif previous_record_type == record_type and previous_transaction_reference == current_transaction_reference  and current_address != previous_address:   
                          cursor.execute("UPDATE document_line SET delivery_service_address = ? WHERE document_lineid = ?", current_address,  document_lineid)
                                
                    # previous_record_type = record_type
                    # previous_transaction_reference = current_transaction_reference
            #if(current_address != ""):
                      previous_address = current_address
               previous_record_type = record_type
               previous_transaction_reference = current_transaction_reference
            except Exception as error: 
               print(error)   

def update_block_data_inv(record_data, connection: pyodbc.Connection):
    """
    TODO:
    Only add subtotal to database if there is more than subtotal
    TODO:
    Each block should have its own address
    """
    block_data = {}
    for document_id, records in record_data.items():
        record_12_indeces = []
        # existing_12 = False
        # for record in records:
        #     if record[0] == "12":
        #         existing_12 = True
        # if not existing_12:
        #     with connection.cursor() as cursor:
        #         cursor.execute(
        #             """
        #                 UPDATE Document
        #                 SET
        #                     supress = true,
        #                     mmsupress = true,
        #                     suppress_reason = ?
        #                 WHERE documentid = ?
        #             """,
        #             "Missing record 12 details",
        #             document_id
        #         )
        if records[0][0] == "13":
            record_13_index = 0
        else:
            for record_index, record in enumerate(records):
                if record[0] == "13":
                    record_13_index = record_index
        current_transaction_reference = None
        block_data[document_id] = []
        block = []
        for record_index, record in enumerate(records):
            if record[0] == "12":
                if current_transaction_reference != record[2]:
                    record_12_indeces.append(record_index)
                    if current_transaction_reference is not None:
                        block_data[document_id].append(block)
                        block = []
                current_transaction_reference = record[2]
            block.append(record)
        block_data[document_id].append(block)
        record_12_address_exists = False
        for record_12_index in record_12_indeces:
            if records[record_12_index][3] != None:
                record_12_address_exists = True
                break
        for record_12_index in record_12_indeces:
            if records[record_12_index][3] in ("", None):
                new_delivery_service_address = records[record_13_index][2]
                with connection.cursor() as cursor:
                    cursor.execute(
                        "UPDATE Document_Line SET delivery_service_address = ?, delivery_address_bottom = ? WHERE document_lineid = ?",
                        new_delivery_service_address,
                        new_delivery_service_address,
                        records[record_12_index][1]
                    )
                if not record_12_address_exists:
                    break
    for document_id, blocks in block_data.items():
        with connection.cursor() as cursor:
            cursor.execute("SELECT branchid, customer_account_number, invoice_date FROM Document WHERE documentid = ?", document_id)
            record = cursor.fetchone()
            branchid = getattr(record, "branchid")
            customer_account_number = getattr(record, "customer_account_number")
            #amol for test
            #customer_name = getattr(record, "customer_name")
            #print(customer_account_number)
            # if("JAMES COBB" in customer_name): 
            #     print(customer_name)
            # elif("SUZANNE BENKO" in customer_name): 
            #     print(customer_name)
            # else: 
            #     continue    
            #continue
            #amol for test            
            invoice_date = str(getattr(record, "invoice_date"))
            invoice_date = invoice_date[-2:] + invoice_date[:4] # Convert from MMDDYY to YYMMDD
            cursor.execute("SELECT csc_number FROM Branch WHERE branchid = ?", branchid)
            csc_number = getattr(cursor.fetchone(), "csc_number")
        grand_total = 0
        transaction_references = []
        update_csc_message_in_block(blocks, connection, 6)
        for block in blocks:
            for record in block:
                if record[0] == "12":
                    if record[2] not in transaction_references:
                        transaction_references.append(record[2])
        if len(transaction_references) == 1:
            invoice_number = csc_number + str(transaction_references[0]).zfill(7)
        elif len(transaction_references) > 1:
            invoice_number = "9" + csc_number + customer_account_number[:-1] + str((int(invoice_date) + int(transaction_references[0])) % 10)
        with connection.cursor() as cursor:
            cursor.execute("UPDATE Document SET invoice_number = ? WHERE documentid = ?", invoice_number, document_id)
        
        for block in blocks:
            remove_redundant_address_data(connection, block)
            current_transaction_reference = None
            found_12 = False
            found_17 = False
            multiple_12 = False
            for record in block:
                if found_12 and record[0] == "12":
                   multiple_12 = True
                if record[0] == "12":
                    found_12 = True 

            for record in reversed(block):
                if record[0] == "13":
                    current_delivery_address_bottom = record[2]
                elif record[0] == "12":
                    if record[3] == None:
                        with connection.cursor() as cursor:
                            cursor.execute(
                                "UPDATE Document_Line SET delivery_service_address = ?, delivery_address_bottom = ? WHERE document_lineid = ?",
                                current_delivery_address_bottom,
                                current_delivery_address_bottom,
                                record[1]
                            )

            with connection.cursor() as cursor:
                cursor.execute("SELECT customer_account_number FROM Document WHERE documentid = ?", document_id)
                if getattr(cursor.fetchone(), "customer_account_number") == "44488":
                    print()
            sub_total_addends = [] # This is a list so that it is easier to tell if there was only one addend which would lead to no database update
            previous_document_lineid = None
            for record in block:
                if record[0] == "12":
                    if record[2] != current_transaction_reference and current_transaction_reference is not None:
                        if multiple_12:
                            with connection.cursor() as cursor:
                                if len(sub_total_addends) > 1:
                                    cursor.execute(
                                        "UPDATE Document_Line SET sub_total = ? WHERE document_lineid = ?",
                                        sum(sub_total_addends),
                                        previous_document_lineid
                                    )
                        grand_total += sum(sub_total_addends)
                        sub_total_addends = []
                    current_transaction_reference = record[2]
                    current_transaction_date = record[4]
                    sub_total_addends.append(int(record[5]))
                if record[0] == "17":
                    with connection.cursor() as cursor:
                        cursor.execute(
                            "UPDATE Document_Line SET transaction_reference = ?, transaction_date = ? WHERE document_lineid = ?",
                            current_transaction_reference,
                            current_transaction_date,
                            record[1]
                        )
                previous_document_lineid = record[1]
            for record in reversed(block):
                if record[0] == "17":
                    found_17 = True
                    break
                if record[0] == "12":
                    if multiple_12:
                        with connection.cursor() as cursor:
                            if len(sub_total_addends) > 1:
                                cursor.execute(
                                    "UPDATE Document_Line SET sub_total = ? WHERE document_lineid = ?",
                                    sum(sub_total_addends),
                                    record[1]
                                )
                    break
            #Stephen added    
            # if found_17:
            #     for record in reversed(block):
            #         if record[0] == "12":
            #             with connection.cursor() as cursor:
            #                 if len(sub_total_addends) > 1:
            #                     cursor.execute(
            #                         "UPDATE Document_Line SET sub_total = ? WHERE document_lineid = ?",
            #                         sum(sub_total_addends),
            #                         record[1]
            #                     )
            #             break
            
            if found_17:
                for record in reversed(block):
                    if record[0] == "12":
                        with connection.cursor() as cursor:
                            if len(sub_total_addends) > 1:
                                #print(block_counter)
                                block_counter = 0
                                for record in block:
                                  if record[0] == "12":
                                    block_counter += 1
                                if block_counter != len(sub_total_addends): 
                                   cursor.execute(
                                      "UPDATE Document_Line SET sub_total = ? WHERE document_lineid = ?",
                                       sum(sub_total_addends),
                                       record[1]
                                    )
                        break

            if multiple_12 == False:
                for record in block:
                    if record[0] == "12":
                        with connection.cursor() as cursor:
                            cursor.execute(
                                    "UPDATE Document_Line SET sub_total = transaction_dollars ,transaction_dollars = null WHERE document_lineid = ?",
                                    record[1]
                                )             
                
                    
            grand_total += sum(sub_total_addends)
        with connection.cursor() as cursor:
            cursor.execute(
                "UPDATE Document SET grand_total = ? WHERE documentid = ?",
                grand_total,
                document_id
            )

