

import pyodbc
from dependencies.file_type_code.inv_code import update_csc_message_in_block

from dependencies.utility_functions import clean_string



def create_block_data_sta(record_data, cursor, record, tertiary_query_data, csc_number, documentid, csc_1654_message, csc_1654_messages, texas_railroad_message):
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
        cursor.execute("SELECT transaction_reference, delivery_service_address, transaction_date, transaction_dollars, delivery_address_service_address_dad_sad, exception_data FROM Document_Line WHERE document_lineid = ?", document_lineid)
        record = cursor.fetchone()
        transaction_reference = getattr(record, "transaction_reference")
        transaction_date = getattr(record, "transaction_date")
        delivery_service_address = getattr(record, "delivery_service_address")
        transaction_dollars = float(getattr(record, "transaction_dollars"))
        delivery_address_service_address_dad_sad = getattr(record, "delivery_address_service_address_dad_sad")
        record_data[documentid].append(["12", document_lineid, transaction_reference, delivery_service_address, transaction_date, transaction_dollars, delivery_address_service_address_dad_sad, csc_1654_message_document_line])
        exception_data = int(getattr(record, "exception_data"))
        if exception_data:
            cursor.execute("SELECT transaction_unit_price_2, cylinder_quantities_delivered,format_with_onedecimal(cast(Expanded_Gallons_Dollars as numeric)/10) expanded_gallons_dollars, transaction_code_rec_type, original_code,transaction_code_002_quantity FROM Document_Line WHERE document_lineid = ?", document_lineid)
            record = cursor.fetchone()
            transaction_unit_price_2 = getattr(record, "transaction_unit_price_2")
            cylinder_quantities_delivered = str(int(getattr(record, "cylinder_quantities_delivered")))
            transaction_code_002_quantity = getattr(record, "transaction_code_002_quantity")
            Transaction_Code_Rec_type = getattr(record, "transaction_code_rec_type")
            original_code = getattr(record, "original_code")
            expanded_gallons_dollars = getattr(record, "expanded_gallons_dollars")
            untiprice = set(str(transaction_unit_price_2))                   
            if Transaction_Code_Rec_type == "NA": 
                # print("NA")                 
                # print(transaction_unit_price_2)
                # print(expanded_gallons_dollars)
                cursor.execute("SELECT trim(trans_desc) trans_desc FROM public.default_trans_codes where transaction_id = ?", original_code)
                trans_record = cursor.fetchone()
                trans_desc = getattr(trans_record, "trans_desc")
                #print(trans_desc)
                expanded_gallons_dollars = str(expanded_gallons_dollars).replace(",","")
                cursor.execute("UPDATE Document_Line SET transaction_code_rec_type = ?,transaction_unit_price2 = transaction_unit_price, transaction_gallons = ?  WHERE document_lineid =?", trans_desc,expanded_gallons_dollars,document_lineid)                
            else: 
                # cursor.execute("SELECT transaction_unit_price_2, cylinder_quantities_delivered FROM Document_Line WHERE document_lineid = ?", document_lineid)
                # record = cursor.fetchone()
                # cylinder_quantities_delivered = str(int(getattr(record, "cylinder_quantities_delivered")))
                # transaction_unit_price_2 = getattr(record, "transaction_unit_price_2")
                cursor.execute("UPDATE Document_Line SET transaction_gallons = ?, transaction_unit_price = ? WHERE document_lineid = ?", cylinder_quantities_delivered, transaction_unit_price_2, document_lineid)
        if csc_1654_message_document_line != "":
            cursor.execute(f"UPDATE document_line SET csc_1654_message = {clean_string(csc_1654_message_document_line)} WHERE document_lineid = '{document_lineid}'")
    elif document_line_record_type == "13":
        cursor.execute("SELECT delivery_service_address, delivery_address_bottom, finance_charge_dollars, price_prot_gallons_remaining, summary_product_message_for_bottom_of_statement, finance_charge_event_date, budget_interest_dollars, finance_charge_annual_rate, finance_charge_monthly_rate, finance_charge_avg_daily_bal FROM Document_Line WHERE document_lineid = ?", document_lineid)
        record = cursor.fetchone()
        # delivery_service_address = getattr(record, "delivery_service_address")
        delivery_address_bottom = getattr(record, "delivery_address_bottom")
        finance_charge_dollars = getattr(record, "finance_charge_dollars")
        price_prot_gallons_remaining = getattr(record, "price_prot_gallons_remaining")
        summary_product_message_for_bottom_of_statement = getattr(record, "summary_product_message_for_bottom_of_statement")
        finance_charge_event_date = getattr(record, "finance_charge_event_date")
        budget_interest_dollars = getattr(record, "budget_interest_dollars")
        finance_charge_annual_rate = getattr(record, "finance_charge_annual_rate")
        finance_charge_monthly_rate = getattr(record, "finance_charge_monthly_rate")
        finance_charge_avg_daily_bal = getattr(record, "finance_charge_avg_daily_bal")
        record_data[documentid].append(["13", document_lineid, delivery_address_bottom, finance_charge_dollars, price_prot_gallons_remaining, finance_charge_event_date, budget_interest_dollars, finance_charge_annual_rate, finance_charge_monthly_rate, finance_charge_avg_daily_bal])
        # if tertiary_query_data["values"][9] != "''":
        #     cursor.execute("UPDATE Document_Line SET delivery_address = ? WHERE document_lineid = ?", delivery_service_address, document_lineid)
        if summary_product_message_for_bottom_of_statement != "":
            cursor.execute("UPDATE Document SET summary_product_message_bottom = ? WHERE documentid = ?", summary_product_message_for_bottom_of_statement, documentid)
    elif document_line_record_type == "17":
        contract_reference_number = tertiary_query_data["values"][tertiary_query_data["columns"].index("contract_reference_number")]
        if contract_reference_number == "'Y'":
            cursor.execute(f"UPDATE document SET texas_railroad_message = {texas_railroad_message}, rec17_railroad_message = {texas_railroad_message} WHERE documentid = '{documentid}'")
        record_data[documentid].append(["17", document_lineid])
    elif document_line_record_type == "20":
        cursor.execute("SELECT remaining_gallons, remaining_dollars, plan_code FROM Document_Line WHERE document_lineid = ?", document_lineid)
        record = cursor.fetchone()
        remaining_gallons = getattr(record, "remaining_gallons")
        remaining_dollars = getattr(record, "remaining_dollars")
        plan_code = getattr(record, "plan_code")
        record_data[documentid].append(["20", document_lineid, remaining_gallons, remaining_dollars, plan_code])
    elif document_line_record_type == "22":
        # TODO: persist card lock data
        cursor.execute("SELECT original_trans_dollars_koa_including_tax_if_any, transaction_units_gal_ltr, card_number FROM Document_Line WHERE document_lineid = ?", document_lineid)
        record = cursor.fetchone()
        original_trans_dollars_koa_including_tax_if_any = getattr(record, "original_trans_dollars_koa_including_tax_if_any")
        transaction_units_gal_ltr = getattr(record, "transaction_units_gal_ltr")
        card_number = getattr(record, "card_number")
        record_data[documentid].append(["22", document_lineid, original_trans_dollars_koa_including_tax_if_any, transaction_units_gal_ltr, card_number])
    return csc_1654_message


def update_block_data_sta(record_data, connection: pyodbc.Connection):
    block_data = {}
    for document_id, records in record_data.items():
        with connection.cursor() as cursor:
            cursor.execute("SELECT customer_account_number FROM Document WHERE documentid = ?", document_id)
            customer_account_number = getattr(cursor.fetchone(), "customer_account_number")
            # if customer_account_number == "101147":
            #     print("S")
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
            if records[record_12_index][3] == None:
                if records[record_12_index][6] != "":
                    new_delivery_service_address = records[record_12_index][6]
                else:
                    new_delivery_service_address = records[record_13_index][2]
                with connection.cursor() as cursor:
                    cursor.execute(
                        "UPDATE Document_Line SET delivery_service_address = ?, delivery_address_bottom = ? WHERE document_lineid = ?",
                        new_delivery_service_address,
                        new_delivery_service_address,
                        records[record_12_index][1]
                    )
                if not record_12_address_exists and records[record_13_index][2] != "":
                    break
    for document_id, blocks in block_data.items():
        payments_and_credits = new_activity = grand_total = record_22_dollars_grand_total = record_22_gallons_grand_total = 0
        record_22_found = False
        update_csc_message_in_block(blocks, connection, 7)
        swap_13 = False
        budget_interest_dollars = False
        for block in blocks:
            current_transaction_units_gal_ltr = previous_card_number = None
            for record in block:
                if record[0] == "22":
                    record_22_found = True
                    document_lineid = record[1]
                    record_22_dollars_grand_total += int(record[2])
                    record_22_gallons_grand_total += int(record[3])
                    card_number = record[4]
                    if int(record[3]) != current_transaction_units_gal_ltr:
                        if int(record[3]) != 0:
                            current_transaction_units_gal_ltr = int(record[3])
                        else:
                            with connection.cursor() as cursor:
                                cursor.execute(
                                    "UPDATE Document_Line SET transaction_units_gal_ltr = ? WHERE document_lineid = ?",
                                    int(record[3]),
                                    document_lineid
                                )
                    if card_number != previous_card_number:
                        if int(card_number) == 0:
                            with connection.cursor() as cursor:
                                cursor.execute(
                                    "UPDATE Document_Line SET card_number = ? WHERE document_lineid = ?",
                                    previous_card_number,
                                    document_lineid
                                )
                        else:
                            previous_card_number = card_number
            if block[0][0] == "13":
                for record in reversed(block):
                    if record[0] == "12":
                        # with connection.cursor() as cursor:
                        #     cursor.execute(
                        #         "UPDATE Document_Line SET late_charge = ?, finance_charge_annual_rate = ?, finance_charge_monthly_rate = ?, finance_charge_avg_daily_bal = ? WHERE document_lineid = ?",
                        #         None,
                        #         None,
                        #         None,
                        #         None,
                        #         block[0][1]
                        #     )
                        #     swap_13 = {
                        #         "late_charge": block[0][3],
                        #         "finance_charge_event_date": block[0][5],
                        #         "finance_charge_annual_rate": block[0][7],
                        #         "finance_charge_monthly_rate": block[0][8],
                        #         "finance_charge_avg_daily_bal": block[0][9],
                        #     }
                            break
            current_transaction_reference = None
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT statement_type, statement_message_code FROM Document WHERE documentid = ?",
                    document_id
                )
                record = cursor.fetchone()
                statement_type = getattr(record, "statement_type")
                statement_message_code = getattr(record, "statement_message_code")
            if statement_type in ("BN", "BS", "BZ", "BD", "B1", "B2", "SS"):
                if statement_message_code == 7:
                    remaining_gallons = 0
                    remaining_dollars = 0
                    for record in block:
                        if record[0] == "20" and record[4] in ("EB", "FEB"):
                            remaining_gallons += record[2]
                            remaining_dollars += record[3]
                            plan_code = record[4]
                    if record[4] in ("EB", "FEB"):
                        with connection.cursor() as cursor:
                            cursor.execute(
                                "UPDATE Document SET remaining_gallons = ?, remaining_dollars = ?, plan_code = ? WHERE documentid = ?",
                                remaining_gallons,
                                remaining_dollars,
                                plan_code,
                                document_id
                            )
                else:
                    for record in block:
                        if record[0] == "13":
                            with connection.cursor() as cursor:
                                cursor.execute(
                                    "UPDATE Document SET remaining_gallons = ? WHERE documentid = ?",
                                    int(record[4]) if record[4] != "" else 0,
                                    document_id
                                )

            if block[0][0] == "12":
                if len(block) > 1:
                    if block[1][0] == "12":
                        for record in block:
                            if record[0] == "12":
                                with connection.cursor() as cursor:
                                    cursor.execute(
                                        "SELECT dollars_amount_keyoff_account FROM Document_Line WHERE document_lineid = ?",
                                        record[1]
                                    )
                                    dollars_amount_keyoff_account_record = cursor.fetchone()
                                    if dollars_amount_keyoff_account_record is not None:
                                        dollars_amount_keyoff_account = getattr(dollars_amount_keyoff_account_record, "dollars_amount_keyoff_account")
                                        cursor.execute(
                                            "UPDATE Document_Line SET dollars_amount_keyoff_account_2 = ? WHERE document_lineid = ?",
                                            dollars_amount_keyoff_account,
                                            record[1]
                                        )
            sub_total_addends = []
            previous_document_lineid = None
            for record in block:
                if record[0] == "12":
                    with connection.cursor() as cursor:
                        cursor.execute("SELECT dollars_amount_keyoff_account FROM Document_Line WHERE document_lineid = ?", record[1])
                        record[5] = getattr(cursor.fetchone(), "dollars_amount_keyoff_account")
                    if record[2] != current_transaction_reference and current_transaction_reference is not None:
                        with connection.cursor() as cursor:
                            # if len(sub_total_addends) > 1:
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
                    if int(record[5]) > 0:
                        new_activity += int(record[5])
                    if int(record[5]) < 0:
                        payments_and_credits += int(record[5])
                elif record[0] == "13":
                    with connection.cursor() as cursor:
                        cursor.execute(
                            "UPDATE Document SET late_charge = ? WHERE documentid = ?",
                            record[3],
                            document_id
                        )
                    if int(record[6]) != 0:
                        with connection.cursor() as cursor:
                            cursor.execute(
                                "INSERT INTO Document_Line (recordtype, budget_interest_dollars, rownumber, documentid) VALUES (79, ?, 1, ?)",
                                record[6],
                                document_id
                            )
                        budget_interest_dollars = {
                            "budget_interest_dollars": record[6],
                            "finance_charge_event_date": record[5],
                        }
                        with connection.cursor() as cursor:
                            cursor.execute("SELECT document_lineid FROM document_line WHERE documentid = ?", document_id)
                            document_lineids = {}
                            max_row_number = 0
                            late_charge_exists = False
                            for record in cursor.fetchall():
                                document_lineids[getattr(record, "document_lineid")] = None
                        with connection.cursor() as cursor:
                            for document_lineid in document_lineids.keys():
                                cursor.execute("SELECT recordtype, rownumber, late_charge FROM document_line WHERE document_lineid = ?", document_lineid)
                                record = cursor.fetchone()
                                recordtype = getattr(record, "recordtype")
                                row_number = getattr(record, "rownumber")
                                if row_number + 1 > max_row_number:
                                    max_row_number = row_number + 1
                                late_charge = getattr(record, "late_charge")
                                if late_charge:
                                    late_charge_exists = True
                                document_lineids[document_lineid] = [recordtype, row_number, late_charge]
                        with connection.cursor() as cursor:
                            for document_lineid in document_lineids.keys():
                                cursor.execute(
                                    "UPDATE document_line SET rownumber = NULL WHERE document_lineid = ?",
                                    document_lineid
                                )
                        with connection.cursor() as cursor:
                            for document_lineid, document_line_data in document_lineids.items():
                                recordtype, row_number, late_charge = document_line_data
                                if recordtype == "79":
                                    new_row_number = max_row_number - (1 if late_charge_exists else 0)
                                else:
                                    if late_charge_exists:
                                        if row_number == max_row_number:
                                            new_row_number = row_number
                                        else:
                                            new_row_number = row_number - 1
                                    else:
                                        new_row_number = row_number - 1
                                cursor.execute(
                                    "UPDATE document_line SET rownumber = ? WHERE document_lineid = ?",
                                    new_row_number,
                                    document_lineid
                                )
                elif record[0] == "17":
                    with connection.cursor() as cursor:
                        cursor.execute(
                            "UPDATE Document_Line SET transaction_reference = ?, transaction_date = ? WHERE document_lineid = ?",
                            current_transaction_reference,
                            current_transaction_date,
                            record[1]
                        )
                previous_document_lineid = record[1]
            found_12 = False
            found_17 = False
            for record in reversed(block):
                if record[0] == "17" and not found_12:
                    found_17 = True
                    break
                if record[0] == "12":
                    found_12 = True
                    with connection.cursor() as cursor:
                        # if len(sub_total_addends) > 1:
                        cursor.execute(
                            "UPDATE Document_Line SET sub_total = ? WHERE document_lineid = ?",
                            sum(sub_total_addends),
                            record[1]
                        )
                    break
            if found_17:
                for record in block:
                    if record[0] == "12":
                        with connection.cursor() as cursor:
                            # if len(sub_total_addends) > 1:
                            cursor.execute(
                                "UPDATE Document_Line SET sub_total = ? WHERE document_lineid = ?",
                                sum(sub_total_addends),
                                record[1]
                            )
                        break

            grand_total += sum(sub_total_addends)
        if swap_13:
            print("A")
            # with connection.cursor() as cursor:
            #     cursor.execute(
            #         "UPDATE Document_Line SET late_charge = ?, finance_charge_event_date = ?, finance_charge_annual_rate = ?, finance_charge_monthly_rate = ?, finance_charge_avg_daily_bal = ? WHERE document_lineid = ?",
            #         swap_13["late_charge"],
            #         swap_13["finance_charge_event_date"],
            #         swap_13["finance_charge_annual_rate"],
            #         swap_13["finance_charge_monthly_rate"],
            #         swap_13["finance_charge_avg_daily_bal"],
            #         block[-1][1]
            #     )
        budget_interest_dollars_amount = 0
        if budget_interest_dollars:
            budget_interest_dollars_amount = int(budget_interest_dollars["budget_interest_dollars"])
            # with connection.cursor() as cursor:
            #     cursor.execute(
            #         "UPDATE Document_Line SET budget_interest_dollars = ?, finance_charge_event_date = ? WHERE document_lineid = ?",
            #         budget_interest_dollars_amount,
            #         budget_interest_dollars["finance_charge_event_date"],
            #         [record for block in blocks for record in block][-2 if swap_13 else -1][1]
            #     )
            #     print("#########################")
            #     print(budget_interest_dollars_amount, [record for block in blocks for record in block], [record for block in blocks for record in block][-2 if swap_13 else -1][1])
            #     print("#########################")
        reference_numbers = []
        for block in blocks:
            if block[0][0] == "12":
                if block[0][2] not in reference_numbers:
                    reference_numbers.append(block[0][2])
                    continue
                else:
                    with connection.cursor() as cursor:
                        cursor.execute(
                            "UPDATE Document_Line SET delivery_service_address = NULL, delivery_address_bottom = NULL WHERE document_lineid = ?",
                            block[0][1]
                        )
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE Document
                SET grand_total = ?, payments_and_credits = ?, new_activity = ?, record_22_dollars_grand_total = ?, record_22_gallons_grand_total = ?
                WHERE documentid = ?
                RETURNING Document.previous_balance, Document.late_charge
                """,
                grand_total,
                payments_and_credits,
                new_activity,
                record_22_dollars_grand_total if record_22_found else None,
                record_22_gallons_grand_total if record_22_found else None,
                document_id
            )
            record = cursor.fetchone()
            previous_balance = getattr(record, "previous_balance") if getattr(record, "previous_balance") is not None else 0
            late_charge = getattr(record, "late_charge") if getattr(record, "late_charge") is not None else 0
            cursor.execute(
                """
                UPDATE Document
                SET statement_balance = ?
                WHERE documentid = ?
                """,
                int(previous_balance) + payments_and_credits + new_activity + int(late_charge) + budget_interest_dollars_amount + record_22_dollars_grand_total,
                document_id
            )


def update_query_data_sta(secondary_query_data):
    # TODO: If swapped move late_charge to last record in block
    record_13_swapped = False
    tertiary_table_query_data = secondary_query_data["tertiary_table_query_data"]
    first_row = tertiary_table_query_data[0]["values"][tertiary_table_query_data[0]["columns"].index("rownumber")]
    for record_number, record in enumerate(tertiary_table_query_data):
        if record["values"][0] == "'13'":
            if record["values"][9] != "''":
                tertiary_table_query_data.insert(0, tertiary_table_query_data.pop(record_number))
                record_13_swapped = True
                break
    if record_13_swapped:
        tertiary_table_query_data[0]["values"][tertiary_table_query_data[0]["columns"].index("rownumber")] = first_row
        for tertiary_table_query_datum_number, tertiary_table_query_datum in enumerate(tertiary_table_query_data):
            if tertiary_table_query_datum_number == 0:
                continue
            tertiary_table_query_datum["values"][tertiary_table_query_datum["columns"].index("rownumber")] = str(int(tertiary_table_query_datum["values"][tertiary_table_query_datum["columns"].index("rownumber")]) + 1)

