

import pyodbc

from dependencies.utility_functions import clean_string
import random, string
import pandas as pd
from operator import itemgetter



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
        cursor.execute("SELECT transaction_reference, delivery_service_address, transaction_date, transaction_dollars, exception_data, original_code FROM Document_Line WHERE document_lineid = ?", document_lineid)
        record = cursor.fetchone()
        transaction_reference = getattr(record, "transaction_reference")
        transaction_date = getattr(record, "transaction_date")
        delivery_service_address = getattr(record, "delivery_service_address")
        transaction_dollars = float(getattr(record, "transaction_dollars"))     
        original_code = getattr(record, "original_code")
        record_data[documentid].append(["12", document_lineid, transaction_reference, delivery_service_address, transaction_date, transaction_dollars, csc_1654_message_document_line,original_code])
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
                #print("NA")
                #print(transaction_unit_price_2)
                cursor.execute("SELECT trim(trans_desc) trans_desc FROM public.default_trans_codes where transaction_id = ?", original_code)
                trans_record = cursor.fetchone()
                trans_desc = getattr(trans_record, "trans_desc")
                #print(trans_desc)
                expanded_transaction_gallons = str(expanded_transaction_gallons).replace(",","")
                #print(expanded_transaction_gallons)                
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
    elif document_line_record_type == "18":
        cursor.execute("SELECT transaction_invoice_comment FROM Document_Line WHERE document_lineid = ?", document_lineid)
        record = cursor.fetchone()
        transaction_invoice_comment = getattr(record, "transaction_invoice_comment")      
        record_data[documentid].append(["18", document_lineid, transaction_invoice_comment])    
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
    connection.autocommit = True 
    previous_document_id = 0
    customer_account_number = ""
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
            found_18 = False
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
                if record[0] == "18":                
                    found_18 = True                   
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
                
            with connection.cursor() as cursor:  
                cursor.execute("""SELECT 
                                    count(case when delivery_service_address = '' then 0 
                                        when delivery_service_address is null then 0 
                                        else 1 end ) as address_count
                                    FROM document_line dl1
                                    WHERE documentid = ?
                                    and recordtype in ('12','18')
                                    and transaction_reference not in ('0')
                                    and delivery_service_address is not null
                                    and delivery_service_address != ''
                                    and not exists 
                                    ( SELECT 1 FROM document_line dl2 
                                    where dl1.documentid = dl2.documentid
                                    and dl2.transaction_reference not in ('0') 
                                    and dl1.transaction_reference != dl2.transaction_reference
                                    and dl2.recordtype in ('12','18'))
                                    group by delivery_service_address""", document_id)
                
                address_count =  []
                #record = cursor.fetchone()
                #address_count = getattr(record, "address_count") 
                for record in cursor.fetchall():
                        address_count.append(getattr(record, "address_count"))                          
            if (found_18 or len(address_count) > 1 ) and previous_document_id!= document_id:   
                #print(document_id)                 
                customer_account_number = ""
                with connection.cursor() as cursor:
                        cursor.execute("SELECT customer_account_number FROM document WHERE documentid = ?", document_id)
                        document_lineids2 = {}
                        record = cursor.fetchone()
                        customer_account_number = getattr(record, "customer_account_number")
                        if "22591" in customer_account_number: 
                          print("A") 
                if  len(address_count)  > 1 :                       
                       if "53364" in customer_account_number: 
                          print("A")      
                       prev_delivery_service_address = ""      
                       with connection.cursor() as cursor:
                            cursor.execute("SELECT document_lineid FROM document_line WHERE documentid = ? and recordtype in ('12') order by rownumber", document_id)
                            document_lineids          = {} 
                            document_lineids_12blokcs =  {}       
                            for record in cursor.fetchall():
                                document_lineids[getattr(record, "document_lineid")] = None                        
                            cursor.execute("SELECT min(rownumber) minrownumber FROM document_line WHERE documentid = ?", document_id)
                            document_lineids2 = {}
                            record = cursor.fetchone()
                            min_row_number = getattr(record, "minrownumber")                               
                            rand_line_id = ''.join(random.choices(string.ascii_letters + string.digits, k=16))                                       
                       cursor.execute("""SELECT delivery_service_address  
                                       FROM document_line  where delivery_service_address is not null
                                        and delivery_service_address != ''
                                        AND documentid = ? and recordtype in ('12','18') order by rownumber""", document_id)
                       keystodelete = []
                       delivery_addresses = []  
                       for record in cursor.fetchall():
                                delivery_addresses.append(getattr(record, "delivery_service_address"))    
                       list_len = len(delivery_addresses)   
                       counter = 0      
                       for index,delivery_addresses in enumerate(delivery_addresses):
                           counter += 1
                           #print(delivery_addresses)                            
                           try:  
                              for lineid in keystodelete:                                
                                            document_lineids.pop(lineid)     
                           except Exception as err: 
                               pass                 
                           for index2,document_lineid in enumerate(document_lineids.keys()):                           
                               
                                                                                              
                                cursor.execute("""SELECT
                                                    documentid              ,
                                                    transaction_reference   ,
                                                    recordtype              , 
                                                    rownumber               , 
                                                    transaction_invoice_comment, 
                                                    transaction_dollars, 
                                                    delivery_service_address as curr_delivery_service_address, 
                                                    transaction_code, 
                                                    transaction_gallons
                                            FROM
                                                    document_line
                                            WHERE
                                                    document_lineid = ?
                                                    --and recordtype in ('12','18')
                                            order by rownumber""", document_lineid)
                                record = cursor.fetchone()
                                recordtype = getattr(record, "recordtype")
                                recordtype18 = str(recordtype).replace("'","")  
                                transaction_reference =  getattr(record, "transaction_reference") 
                                transaction_invoice_comment   =  getattr(record, "transaction_invoice_comment")   
                                curr_delivery_service_address =  getattr(record, "curr_delivery_service_address")   
                                transaction_dollars        =  getattr(record, "transaction_dollars")
                                transaction_code      =  getattr(record, "transaction_code")        
                                transaction_gallons =    getattr(record, "transaction_gallons")                               
                                row_number = getattr(record, "rownumber")                                                                                     
                                if index2 == 0: 
                                    if recordtype =='18': 
                                       document_lineids2[document_lineid] = [recordtype, row_number, transaction_reference,transaction_invoice_comment,transaction_dollars, 
                                                                          transaction_code,transaction_gallons]
                                    else: 
                                       document_lineids2[document_lineid] = [recordtype, row_number, transaction_reference,transaction_invoice_comment,transaction_dollars, 
                                                                          transaction_code,transaction_gallons]    
                                    #print(delivery_addresses)
                                    keystodelete.append(document_lineid)
                                    #del document_lineids[next(iter(document_lineids))]
                                else:                           
                                    if delivery_addresses == curr_delivery_service_address or curr_delivery_service_address =="" or curr_delivery_service_address is None: 
                                        document_lineids2[document_lineid] =  [recordtype, row_number, transaction_reference,transaction_invoice_comment,transaction_dollars, 
                                                                               transaction_code,transaction_gallons]
                                        #print(delivery_addresses) 
                                        keystodelete.append(document_lineid)
                                        #del document_lineids[next(iter(document_lineids))]                             
                                    elif delivery_addresses != curr_delivery_service_address and curr_delivery_service_address !="" and curr_delivery_service_address is not None: 
                                        #print(delivery_addresses)    
                                        document_lineids_12blokcs[rand_line_id] = document_lineids2 
                                        rand_line_id = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
                                        document_lineids2 = {}  
                                       # keystodelete = []                                      
                                        document_lineids2[document_lineid] =  [recordtype, row_number, transaction_reference,transaction_invoice_comment,transaction_dollars, 
                                                                              transaction_code,transaction_gallons]
                                        keystodelete.append(document_lineid)
                                        #del document_lineids[next(iter(document_lineids))]
                                        #if  curr_delivery_service_address 
                                        break    
                               
                       document_lineids_12blokcs[rand_line_id] = document_lineids2             
                       #print(document_lineids_12blokcs) 
                       with connection.cursor() as cursor:                                        
                                        cursor.execute(
                                            "UPDATE document_line SET rownumber = NULL WHERE documentid = ?",
                                            document_id
                                        )
                                        
                       document_lineids18       = {} 
                       with connection.cursor() as cursor:
                            cursor.execute("SELECT document_lineid FROM document_line WHERE documentid = ? and recordtype in ('18') order by rownumber", document_id)                             
                            for record in cursor.fetchall():
                                document_lineids18[getattr(record, "document_lineid")] = None                   
                       rownumbers = [] 
                       #print(document_lineids18.keys())
                       key18s =  list(document_lineids18.keys())         
                       counter = 0               
                       for document in document_lineids_12blokcs.values():                            
                                df = pd.DataFrame.from_dict(document) 
                                #print(df)
                                sub_total = 0   
                                subtotal_line_id = ""
                                prop_qty_flag = False
                                for ind, column in enumerate(df.columns):
                                    #print(ind, column)
                                    document_lineid = column
                                    subtotal_line_id = document_lineid
                                    recordtype = df.at[0, column]
                                    rownumber =   df.at[1, column] 
                                    transaction_dollars =   df.at[4, column] 
                                    transaction_code =   df.at[5, column] 
                                    transaction_gallons =   df.at[6, column] 
                                    srownumbers = set(rownumbers)                                       
                                    if  rownumber in srownumbers: 
                                        #print("A")
                                        continue
                                    sub_total = sub_total + transaction_dollars
                                    rownumbers.append(rownumber)
                                    if transaction_code == "PROPANE" : 
                                        #print("A")
                                        try: 
                                            if key18s[counter]: 
                                            # print("A")
                                                with connection.cursor() as cursor:                                                                                                           
                                                    cursor.execute(
                                                        "UPDATE document_line SET rownumber = ? WHERE document_lineid = ?",
                                                        min_row_number,
                                                        key18s[counter]
                                                    )
                                                    min_row_number  += 1  
                                                    counter +=1
                                                    prop_qty_flag = True 
                                        except Exception as err: 
                                            print(err)            
                                            pass
                                    with connection.cursor() as cursor:                                                                                                           
                                                    cursor.execute(
                                                        "UPDATE document_line SET rownumber = ? WHERE document_lineid = ?",
                                                        min_row_number,
                                                        document_lineid
                                                    )
                                                    min_row_number  += 1 
                                if prop_qty_flag == False:                    
                                    try:                     
                                        with connection.cursor() as cursor:                                                                                                           
                                            cursor.execute(
                                                "UPDATE document_line SET rownumber = ? WHERE document_lineid = ?",
                                                min_row_number,
                                                key18s[counter]
                                            )
                                            min_row_number  += 1  
                                            counter +=1 
                                    except Exception as err: 
                                        pass 
                                #print(sub_total)   
                                with connection.cursor() as cursor:                                 
                                    cursor.execute(
                                        "UPDATE Document_Line SET sub_total = ? WHERE document_lineid = ?",
                                        sub_total,
                                        subtotal_line_id
                                    )   
                                #counter +=1                                
                       cursor.execute("SELECT document_lineid FROM document_line WHERE documentid = ? and recordtype not in ('12','18')", document_id)
                       document_lineids          = {} 
                       document_lineids_12blokcs =  {}                  
                        #transaction_invoice_comment_exists = False
                       for record in cursor.fetchall():
                            document_lineids[getattr(record, "document_lineid")] = None    
                            
                       with connection.cursor() as cursor:        
                            for index,document_lineid in enumerate(document_lineids.keys()):
                                cursor.execute(
                                        "UPDATE document_line SET rownumber = ? WHERE document_lineid = ?",
                                        min_row_number,
                                        document_lineid
                                    )
                                min_row_number  += 1      
                                
                       with connection.cursor() as cursor:         
                               cursor.execute(
                                            "DELETE FROM document_line WHERE documentid = ? and rownumber is null",                                            
                                            document_id
                                        )         
                       with connection.cursor() as cursor:          
                            cursor.execute("SELECT document_lineid,rownumber FROM document_line WHERE documentid = ? and recordtype in ('18') order by rownumber desc", document_id)
                            document_lineids          = {} 
                            document_lineids_12blokcs =  {}                  
                                #transaction_invoice_comment_exists = False
                            for record in cursor.fetchall():
                                    document_lineids[getattr(record, "document_lineid")] =  getattr(record, "rownumber")   
                            #for index,key in enumerate(document_lineids.keys()):    
                            indexed_keys = dict(enumerate(document_lineids.keys()))                               
                            for index,value in enumerate(document_lineids.values()): 
                                try: 
                                  print(document_lineids[indexed_keys[index]] - document_lineids[indexed_keys[index + 1]])
                                  if document_lineids[indexed_keys[index]] - document_lineids[indexed_keys[index + 1]] == 1: 
                                      print(indexed_keys[index])
                                      with connection.cursor() as cursor:  
                                          cursor.execute(
                                            "DELETE FROM document_line WHERE document_lineid = ?",                                            
                                            indexed_keys[index]
                                        )        
                                          
                                except Exception as err: 
                                    pass  
                                    
                                #print(document_lineids.values()
                else:                               
                      with connection.cursor() as cursor:
                            cursor.execute("SELECT document_lineid FROM document_line WHERE documentid = ? and recordtype in ('12','18') order by rownumber", document_id)
                            document_lineids          = {} 
                            document_lineids_12blokcs =  {}                  
                            #transaction_invoice_comment_exists = False
                            for record in cursor.fetchall():
                                document_lineids[getattr(record, "document_lineid")] = None                        
                            cursor.execute("SELECT min(rownumber) minrownumber FROM document_line WHERE documentid = ?", document_id)
                            document_lineids2 = {}
                            record = cursor.fetchone()
                            min_row_number = getattr(record, "minrownumber")
                            max_row_number = 0
                            # customer_account_number = ""
                            # with connection.cursor() as cursor:
                            #      cursor.execute("SELECT customer_account_number FROM document WHERE documentid = ?", document_id)
                            #      document_lineids2 = {}
                            #      record = cursor.fetchone()
                            #      customer_account_number = getattr(record, "customer_account_number")
                            # if "117293" in customer_account_number: 
                            #     print("A")     
                            #transaction_invoice_comment_exists = False
                            counter = 0
                            current_transaction_reference = -1     
                            prev_transaction_reference   = -2                                  
                            rand_line_id = ''.join(random.choices(string.ascii_letters + string.digits, k=16))     
                            with connection.cursor() as cursor:        
                                for index,document_lineid in enumerate(document_lineids.keys()):
                                    cursor.execute("""SELECT
                                                    documentid              ,
                                                    transaction_reference   ,
                                                    recordtype              , 
                                                    rownumber               , 
                                                    transaction_invoice_comment, 
                                                    expanded_transaction_dollars as transaction_dollars, 
                                                    delivery_service_address as curr_delivery_service_address, 
                                                    transaction_code, 
                                                    coalesce(transaction_gallons,0) as transaction_gallons, 
                                                    sub_total 
                                                FROM
                                                        document_line
                                                WHERE
                                                        document_lineid = ?
                                                        --and recordtype in ('12','18')
                                                order by rownumber""", document_lineid)
                                    record = cursor.fetchone()
                                    recordtype = getattr(record, "recordtype")
                                    recordtype18 = str(recordtype).replace("'","")  
                                    transaction_reference =  getattr(record, "transaction_reference") 
                                    transaction_invoice_comment   =  getattr(record, "transaction_invoice_comment")   
                                    curr_delivery_service_address =  getattr(record, "curr_delivery_service_address")   
                                    transaction_dollars        =  getattr(record, "transaction_dollars")
                                    transaction_code      =  getattr(record, "transaction_code")        
                                    transaction_gallons =    getattr(record, "transaction_gallons") 
                                    sub_total       =   getattr(record, "sub_total") 
                                    row_number = getattr(record, "rownumber")                                      
                                    if index ==0:                                
                                        if recordtype =='18': 
                                            document_lineids[document_lineid] =[recordtype, row_number, transaction_reference,transaction_invoice_comment,transaction_dollars, 
                                                                          transaction_code,transaction_gallons,sub_total]
                                        #document_lineids_12blokcs[rand_line_id][index] = document_lineids[document_lineid]                                  
                                        if recordtype =='12': 
                                            document_lineids[document_lineid] = [recordtype, row_number, transaction_reference,transaction_invoice_comment,transaction_dollars, 
                                                                          transaction_code,transaction_gallons,sub_total]
                                        #document_lineids_12blokcs[rand_line_id][index] = document_lineids[document_lineid]  
                                            prev_transaction_reference = transaction_reference   
                                    else: 
                                        if prev_transaction_reference == transaction_reference and recordtype =='12': 
                                            document_lineids[document_lineid] = [recordtype, row_number, transaction_reference,transaction_invoice_comment,transaction_dollars, 
                                                                          transaction_code,transaction_gallons,sub_total]
                                        #document_lineids_12blokcs[rand_line_id][index] = document_lineids[document_lineid] 
                                            prev_transaction_reference = transaction_reference  
                                        elif recordtype =='18':
                                            document_lineids[document_lineid] = [recordtype, row_number, transaction_reference,transaction_invoice_comment,transaction_dollars, 
                                                                          transaction_code,transaction_gallons,sub_total]
                                        #document_lineids_12blokcs[rand_line_id] = document_lineids[document_lineid]                                               
                                            
                                        elif prev_transaction_reference != transaction_reference and recordtype =='12': 
                                            document_lineids_12blokcs[rand_line_id] = document_lineids 
                                            rand_line_id = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
                                            document_lineids = {}
                                            document_lineids[document_lineid] = [recordtype, row_number, transaction_reference,transaction_invoice_comment,transaction_dollars, 
                                                                          transaction_code,transaction_gallons,sub_total]
                                        #document_lineids_12blokcs[rand_line_id][index] = document_lineids[document_lineid]     
                                            prev_transaction_reference = transaction_reference                                   
                                        
                                
                                                        
                                document_lineids_12blokcs[rand_line_id] = document_lineids                             
                                with connection.cursor() as cursor:
                                        #for document_lineid in document_lineids.keys():
                                        cursor.execute(
                                            "UPDATE document_line SET rownumber = NULL WHERE documentid = ?",
                                            document_id
                                        )
                                 
                                transaction_reference = ""
                                #prev_transaction_reference = ""  
                                if "53364" in customer_account_number: 
                                    print("A")  
                                document_lineids18       = {} 
                                with connection.cursor() as cursor:
                                    cursor.execute("SELECT document_lineid FROM document_line WHERE documentid = ? and recordtype in ('18') order by rownumber", document_id)                             
                                    for record in cursor.fetchall():
                                        document_lineids18[getattr(record, "document_lineid")] = None       
                                rownumbers = []   
                                key18s =  list(document_lineids18.keys())         
                                counter = 0 
                                d = {}
                                dfcounter = 0
                                dfrange = []
                                dfrange.append(dfcounter)
                                # with connection.cursor() as cursor:                                                                                                           
                                #             cursor.execute(
                                #                 "UPDATE document_line SET sub_total = null WHERE DOCUMENTid = ?",                                                    
                                #                 document_id
                                #             )
                                d['t' + str(dfcounter)]  = pd.DataFrame(columns=['document_lineid', 'recordtype', 'rownumber',
                                                                                 'transaction_dollars','transaction_code','transaction_gallons','sub_total','transaction_reference'])
                                for document in document_lineids_12blokcs.values():                            
                                    df= pd.DataFrame.from_dict(document) 
                                    #print(df)
                                    sub_total = 0   
                                    subtotal_line_id = ""
                                    prop_qty_flag = False
                                    prev_trans_refence = 0
                                    for ind, column in enumerate(df.columns):
                                        #print(ind, column)
                                        document_lineid = column
                                        subtotal_line_id = document_lineid
                                        recordtype = df.at[0, column]
                                        rownumber =   df.at[1, column] 
                                        transaction_reference =   df.at[2, column]
                                        transaction_dollars =   df.at[4, column] 
                                        transaction_code =   df.at[5, column] 
                                        transaction_gallons =   df.at[6, column] 
                                        sub_totoal  =   df.at[7, column] 
                                        srownumbers = set(rownumbers)                                       
                                        if  rownumber in srownumbers: 
                                            #print("A")
                                            continue
                                        # sub_total = sub_total + transaction_dollars
                                        rownumbers.append(rownumber) 
                                        if recordtype == "18": 
                                            transaction_reference = prev_trans_refence
                                        #elem = [document_lineid, recordtype, rownumber,transaction_dollars,transaction_code,transaction_gallons]
                                        #df_extended =  pd.DataFrame([],columns=['document_lineid', 'recordtype'])  
                                        d['t' + str(dfcounter)] = pd.concat([pd.DataFrame([[document_lineid, recordtype, rownumber,
                                                                                            transaction_dollars,transaction_code,transaction_gallons,sub_total,transaction_reference]], 
                                                                                          columns=['document_lineid', 'recordtype', 'rownumber',
                                                                                 'transaction_dollars','transaction_code','transaction_gallons','sub_total','transaction_reference']), d['t' + str(dfcounter)]], ignore_index=True)
                                        #d['t' + str(dfcounter)]  = pd.concat([d['t' + str(dfcounter)] , df_extended])                                    
                                        #d['t' + str(dfcounter)] =  pd.concat(d['t' + str(dfcounter)],pd.DataFrame([document_lineid, recordtype, rownumber,transaction_dollars,transaction_code,transaction_gallons])) # yuck
                                        if transaction_code == "PROPANE" or ( transaction_gallons is not None and  transaction_gallons >0): 
                                            #print(d['t' + str(dfcounter)] )
                                            dfcounter += 1
                                            dfrange.append(dfcounter)
                                            d['t' + str(dfcounter)]  = pd.DataFrame(columns=['document_lineid', 'recordtype', 'rownumber',
                                                                                 'transaction_dollars','transaction_code','transaction_gallons','sub_total','transaction_reference'])
                                        prev_trans_refence = transaction_reference    
                            record17_swap_flag = False                                                   
                            for i in dfrange: 
                                #print(i)
                                #print(d['t' + str(i)] )
                                document_18line_id = ""
                                document_qtline_id = ""
                                d['t' + str(i)] = d['t' + str(i)].sort_values(by=['rownumber'],ascending=True)
                                grouped = d['t' + str(i)].groupby('transaction_reference',sort=False)
                                #print(len(grouped))          
                            # if len(grouped) == 1:                     
                                for name, group in grouped:
                                    #print(group)
                                    sub_total = 0 
                                    transaction_reference18 = -1   
                                    for idx, row in group.iterrows():
                                        document_lineid = row['document_lineid']
                                        recordtype = row['recordtype']
                                        rownumber = row['rownumber']
                                        transaction_dollars = row['transaction_dollars']
                                        transaction_code = row['transaction_code']
                                        transaction_gallons = row['transaction_gallons']
                                        #sub_total = sub_total + int(transaction_dollars)
                                        #sub_total = row['sub_total']
                                        transaction_reference = row['transaction_reference']
                                        # if recordtype == "12": 
                                        #     curr_transaction_reference = transaction_reference
                                        if recordtype == "18": 
                                            document_18line_id =  document_lineid
                                            transaction_reference18 = transaction_reference
                                            continue
                                        if transaction_code == "PROPANE" or  ( transaction_gallons is not None and  transaction_gallons >0): 
                                            document_qtline_id =  document_lineid
                                            continue
                                        # if sub_total > 0: 
                                        #    print("A")
                                        #   with connection.cursor() as cursor:                                                                                                           
                                        #     cursor.execute(
                                        #         "UPDATE document_line SET sub_total = 0 WHERE document_lineid = ?",                                                    
                                        #         document_lineid
                                        #     )
                                            #min_row_number  += 1                                              
                                        with connection.cursor() as cursor:                                                                                                           
                                            cursor.execute(
                                            "UPDATE document_line SET rownumber = ? WHERE document_lineid = ?",
                                            min_row_number,
                                            document_lineid
                                            )
                                            min_row_number  += 1 
                                    if document_18line_id != "": 
                                        with connection.cursor() as cursor:                                                                                                           
                                            cursor.execute(
                                                "SELECT SUM( CAST(coalesce(expanded_transaction_dollars, '0') AS integer)) sub_total from document_line where transaction_reference = ? and DOCUMENTid = ?",
                                                transaction_reference18,                                               
                                                document_id
                                            )
                                            record = cursor.fetchone()
                                            sub_total = getattr(record, "sub_total")
                                        with connection.cursor() as cursor:                                                                                                           
                                            cursor.execute(
                                                "UPDATE document_line SET rownumber = ?, sub_total = ?, transaction_reference = ?  WHERE document_lineid = ?",
                                                min_row_number,
                                                sub_total,
                                                transaction_reference18,
                                                document_18line_id
                                            )
                                            min_row_number  += 1   
                                        document_18line_id = ""    
                                    if document_qtline_id != "": 
                                        with connection.cursor() as cursor:                                                                                                           
                                            cursor.execute(
                                                "UPDATE document_line SET rownumber = ? WHERE document_lineid = ?",
                                                min_row_number,
                                                document_qtline_id
                                            )
                                            min_row_number  += 1 
                                        with connection.cursor() as cursor:                  
                                                cursor.execute("""SELECT document_lineid FROM document_line WHERE documentid = ?
                                                                     and recordtype = '17'""", document_id)
                                                record = cursor.fetchone()
                                                if record: 
                                                    record17_document_lineid= getattr(record, "document_lineid") 
                                                    cursor.execute(
                                                        "UPDATE document_line SET rownumber = ? WHERE document_lineid = ?",
                                                        min_row_number,
                                                        record17_document_lineid
                                                        )
                                                    min_row_number  += 1  
                                                    record17_swap_flag = True        
                                        document_qtline_id = ""                         
                            if record17_swap_flag:                 
                               cursor.execute("SELECT document_lineid, recordtype, price_prot_gallons_remaining FROM document_line WHERE documentid = ? and recordtype not in ('12','18','17')", document_id)
                            else: 
                               cursor.execute("SELECT document_lineid, recordtype, price_prot_gallons_remaining FROM document_line WHERE documentid = ? and recordtype not in ('12','18')", document_id)    
                      
                            #cursor.execute("SELECT document_lineid FROM document_line WHERE documentid = ? and recordtype not in ('12','18')", document_id)
                            document_lineids          = {} 
                            document_lineids_12blokcs =  {}                  
                            #transaction_invoice_comment_exists = False
                            for record in cursor.fetchall():
                                document_lineids[getattr(record, "document_lineid")] = None    
                                
                            with connection.cursor() as cursor:        
                                for index,document_lineid in enumerate(document_lineids.keys()):
                                    cursor.execute(
                                            "UPDATE document_line SET rownumber = ? WHERE document_lineid = ?",
                                            min_row_number,
                                            document_lineid
                                        )
                                    min_row_number  += 1   
                                    
                            with connection.cursor() as cursor:         
                               cursor.execute(
                                            "DELETE FROM document_line WHERE documentid = ? and rownumber is null",                                            
                                            document_id
                                        )    
                            with connection.cursor() as cursor:          
                                cursor.execute("SELECT document_lineid,rownumber FROM document_line WHERE documentid = ? and recordtype in ('18') order by rownumber desc", document_id)
                                document_lineids          = {} 
                                document_lineids_12blokcs =  {}                  
                                    #transaction_invoice_comment_exists = False
                                for record in cursor.fetchall():
                                        document_lineids[getattr(record, "document_lineid")] =  getattr(record, "rownumber")   
                                #for index,key in enumerate(document_lineids.keys()):    
                                indexed_keys = dict(enumerate(document_lineids.keys()))                               
                                for index,value in enumerate(document_lineids.values()): 
                                    try: 
                                        #print(document_lineids[indexed_keys[index]] - document_lineids[indexed_keys[index + 1]])
                                        if document_lineids[indexed_keys[index]] - document_lineids[indexed_keys[index + 1]] == 1: 
                                            #print(indexed_keys[index])
                                            with connection.cursor() as cursor:  
                                                cursor.execute(
                                                    "DELETE FROM document_line WHERE document_lineid = ?",                                            
                                                    indexed_keys[index]
                                                )                                                
                                    except Exception as err: 
                                        pass                                  
                previous_document_id = document_id                                   
            grand_total += sum(sub_total_addends)
        with connection.cursor() as cursor:
            cursor.execute(
                "UPDATE Document SET grand_total = ? WHERE documentid = ?",
                grand_total,
                document_id
            )

