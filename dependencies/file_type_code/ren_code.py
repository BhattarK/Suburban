

def create_block_data_ren(record_data, cursor, record, tertiary_query_data, csc_number, documentid, csc_1654_message, csc_1654_messages):
    document_lineid = getattr(record, "document_lineid")
    document_line_record_type = getattr(record, "recordtype")
    if document_line_record_type == "18":
        # if csc_number == "1654":
        #     original_code = tertiary_query_data["values"][tertiary_query_data["columns"].index("original_code")][1:-1]
        #     if csc_1654_message in csc_1654_messages:
        #         if csc_1654_message == "":
        #             csc_1654_message = csc_1654_messages[original_code]
        #         else:
        #             csc_1654_message += "\n\n" + csc_1654_messages[original_code]
        cursor.execute("SELECT contract_deviation, transaction_refrence, contract_letter, contract_base_price, contract_sub_level, contract_dollars FROM Document_Line WHERE document_lineid = ?", document_lineid)
        record = cursor.fetchone()
        contract_deviation = getattr(record, "contract_deviation")
        transaction_refrence = getattr(record, "transaction_refrence")
        contract_letter = getattr(record, "contract_letter")
        contract_base_price = getattr(record, "contract_base_price")
        contract_sub_level = getattr(record, "contract_sub_level")
        contract_dollars = getattr(record, "contract_dollars")
        record_data[documentid].append(["18", document_lineid, contract_deviation, transaction_refrence, csc_number, contract_letter, contract_base_price, contract_sub_level, contract_dollars])
    elif document_line_record_type == "21":
        cursor.execute("SELECT tax_amount FROM Document_Line WHERE document_lineid = ?", document_lineid)
        record = cursor.fetchone()
        tax_amount = getattr(record, "tax_amount")
        record_data[documentid].append(["21", document_lineid, tax_amount])
    return csc_1654_message


def update_block_data_ren(record_data, connection):
    """
    TODO:
    The 0 issue
    When single block ammount should be shifted to right
    every record in a block should have a reference number
    """
    block_data = {}
    for document_id, records in record_data.items():
        current_transaction_reference = None
        block_data[document_id] = []
        block = []
        for record in records:
            if record[0] == "18":
                if current_transaction_reference != record[3]:
                    if current_transaction_reference is not None:
                        block_data[document_id].append(block)
                        block = []
                current_transaction_reference = record[3]
            block.append(record)
        block_data[document_id].append(block)
    for document_id, blocks in block_data.items():
        for block in blocks:
            sub_total_addends = [] # This is a list so that it is easier to tell if there was only one addend which would lead to no database update
            transaction_refrence = None
            for record in block:
                if record[0] == "18":
                    sub_total_addends.append(int(record[8]))
                    contract_deviation = record[2]
                    transaction_refrence = record[3]
                    csc_number = record[4]
                    contract_letter = record[5]
                    contract_base_price = record[6]
                    contract_sub_level = record[7]
                    contract_dollars = record[8]
                    if contract_letter == "A" and contract_base_price == 1 and contract_sub_level > 0 and csc_number in ("7426", "7444", "7474"):
                        with connection.cursor() as cursor:
                            cursor.execute(
                                "UPDATE Document_Line SET contract_rate_msg = ?, contract_usage_msg = ? WHERE document_lineid = ?",
                                f"YEARLY RATE ${str(float(contract_dollars) - float(contract_deviation))}",
                                f"YEARLY USAGE DISCOUNT APPLIED ${contract_deviation}",
                                record[1]
                            )
                elif record[0] == "21":
                    sub_total_addends.append(int(record[2]))
                if transaction_refrence is not None:
                    with connection.cursor() as cursor:
                        cursor.execute(
                            "UPDATE Document_Line SET transaction_refrence = ? WHERE document_lineid = ?",
                            transaction_refrence,
                            record[1]
                        )
            with connection.cursor() as cursor:
                if len(sub_total_addends) > 1:
                    if sum(sub_total_addends) != 0:
                        cursor.execute(
                            "UPDATE Document_Line SET sub_total = ? WHERE document_lineid = ?",
                            sum(sub_total_addends),
                            record[1]
                        )
                elif len(sub_total_addends) == 1:
                    if sum(sub_total_addends) != 0:
                        cursor.execute(
                            "UPDATE Document_Line SET sub_total = ? WHERE document_lineid = ?",
                            sum(sub_total_addends),
                            record[1]
                        )

