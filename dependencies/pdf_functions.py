
from datetime import datetime
import os
import time
import PyPDF2
from fpdf import FPDF



def remove_file(white_font_pdf_filename):
    if os.path.exists(white_font_pdf_filename):
        while True:
            try:
                os.remove(white_font_pdf_filename)
                if not os.path.exists(white_font_pdf_filename):
                    break
                time.sleep(1)
            except PermissionError:
                time.sleep(1)
            except FileExistsError:
                time.sleep(1)
            except FileNotFoundError:
                time.sleep(1)


def add_white_font(pdf_filename, perf, bre, BinNumber):
    reader = PyPDF2.PdfFileReader(pdf_filename, strict=False)
    writer = PyPDF2.PdfFileWriter()

    if perf:
        perfme_filename_suffix = "1"
    else:
        perfme_filename_suffix = "0"

    bin_number_filemane_suffix = "0"
    if bre:
        if "F" not in BinNumber:
            if int(BinNumber[-1]) > 4:
                bin_number_filemane_suffix = str(int(BinNumber[-1]) - 4)
            else:
                bin_number_filemane_suffix = str(int(BinNumber[-1]))

    filename_suffix = perfme_filename_suffix + bin_number_filemane_suffix

    white_font_pdf_filename = os.path.join("ASSETS", "white_font_pdf_" + filename_suffix + ".pdf")

    white_font_page = PyPDF2.PdfFileReader(white_font_pdf_filename, strict=False).getPage(0)
    for page in range(len(reader.pages)):
        if page % 2 == 0:
            reader.getPage(page).mergePage(white_font_page)
        writer.addPage(reader.getPage(page))
    with open(pdf_filename, "wb") as output_pdf:
        writer.write(output_pdf)


def add_blank_page(pdf_filename):
    reader = PyPDF2.PdfFileReader(pdf_filename, strict=False)
    writer = PyPDF2.PdfFileWriter()
    for page in range(len(reader.pages)):
        writer.addPage(reader.getPage(page))
    writer.addBlankPage()
    with open(pdf_filename, "wb") as output_pdf:
        writer.write(output_pdf)


def merge_pdfs(pdf_filenames, output_pdf_filename):
    writer = PyPDF2.PdfFileWriter()
    for pdf_filename in pdf_filenames:
        reader = PyPDF2.PdfFileReader(pdf_filename, strict=False)
        for page in range(len(reader.pages)):
            writer.addPage(reader.getPage(page))
    with open(output_pdf_filename, "wb") as output_pdf:
        writer.write(output_pdf)

def make_mailing_page(working_folder, index_record, reader, mailing_type, package_numbers):
    # certified
    # if mailing_type == 2:
    # certified mailing tracking number
    # package type
    # check box and line to sign


    # bulk
    # elif mailing_type > 2:
    mailing_pdf_filename = os.path.join(working_folder, "temp_mailing_page.pdf")
    mailing_pdf = FPDF("P", "in", tuple(map(lambda x: x / 72, reader.getPage(0).mediaBox[2:])))
    mailing_pdf.add_page()
    mailing_pdf.set_font("courier", "", 8)

    total_page_count = index_record[8]
    recipient_1 = index_record[9]
    recipient_2 = index_record[10]
    address_line_1 = index_record[11]
    address_line_2 = index_record[12]
    address_line_3 = index_record[13]
    city = index_record[14]
    state = index_record[15]
    postal_code = index_record[16]
    country = index_record[17]
    bre, bin_number, item_code = index_record[19].split("~")
    certified_mailing_tracking_number = "*" + index_record[22] + "*"

    mailing_pdf.set_text_color(0, 0, 0)

    mailing_pdf.text(3.6, .4, "USPS CERTIFIED MAIL")
    mailing_pdf.code39(certified_mailing_tracking_number, 3, .5, .02, .3)
    mailing_pdf.text(
        3.4,
        .95,
        certified_mailing_tracking_number[:5]
        + " " + certified_mailing_tracking_number[5:9]
        + " " + certified_mailing_tracking_number[9:13]
        + " " + certified_mailing_tracking_number[13:17]
        + " " + certified_mailing_tracking_number[17:]
        )

    y = 3
    if recipient_1 != "":
        mailing_pdf.text(1, y, recipient_1)
        y += .1
    if recipient_2 != "":
        mailing_pdf.text(1, y, recipient_2)
        y += .1
    if address_line_1 != "":
        mailing_pdf.text(1, y, address_line_1)
        y += .1
    if address_line_2 != "":
        mailing_pdf.text(1, y, address_line_2)
        y += .1
    if address_line_3 != "":
        mailing_pdf.text(1, y, address_line_3)
        y += .1
    if city != "":
        mailing_pdf.text(1, y, city + " " + state + " " + postal_code)
        y += .1
    if country != "":
        mailing_pdf.text(1, y, country)

    if mailing_type == 2:
        package_number = package_numbers["certified"]
    elif mailing_type > 2:
        package_number = package_numbers["bulk"]

    mailing_pdf.text(5, 9, "Package Number: " + str(package_number))
    mailing_pdf.text(5, 9.25, "Total Pages: " + total_page_count)
    mailing_pdf.text(5, 9.5, bin_number)
    mailing_pdf.text(5, 9.75, "Item Code: " + item_code)

    if mailing_type == 2:
        package_numbers["certified"] += 1
    elif mailing_type > 2:
        package_numbers["bulk"] += 1

    if mailing_type == 2:
        mailing_pdf.text(
            3,
            5,
            "Certified Mailing Tracking Number: " + certified_mailing_tracking_number[1:-1]
        )
        # package type
        # check box and line to sign
        mailing_pdf.set_line_width(.01)
        mailing_pdf.line(1.25, 10.25, 4, 10.25)
        mailing_pdf.line(1, 10, 1.1, 10)
        mailing_pdf.line(1, 10, 1, 10.1)
        mailing_pdf.line(1.1, 10, 1.1, 10.1)
        mailing_pdf.line(1, 10.1, 1.1, 10.1)

    mailing_pdf.output(mailing_pdf_filename, "F")
    return mailing_pdf_filename


def prepend_page_to_pdf(pdf_filename, working_folder, index_record, mailing_type, package_numbers):
    writer = PyPDF2.PdfFileWriter()
    reader = PyPDF2.PdfFileReader(pdf_filename, strict=False)
    page_pdf_filename = make_mailing_page(working_folder, index_record, reader, mailing_type, package_numbers)
    page_reader = PyPDF2.PdfFileReader(page_pdf_filename, strict=False)
    writer.addPage(page_reader.getPage(0))
    writer.addBlankPage()
    for page in range(reader.getNumPages()):
        writer.addPage(reader.getPage(page))
    with open(pdf_filename, "wb") as output:
        writer.write(output)
    remove_file(page_pdf_filename)


def prepend_pages_to_pdfs(out_files_pdf_data, package_numbers, working_folder):
    for pdf, mailing_type, index_record, add_mailing_page in out_files_pdf_data:
        if add_mailing_page:
            prepend_page_to_pdf(pdf, working_folder, index_record, mailing_type, package_numbers)


def create_white_font_pdfs():
    for i in range(2):
        for j in range(5):
            pdf = FPDF("P", "in")
            pdf.add_page()
            pdf.set_font("courier")
            pdf.set_text_color(255, 255, 255)
            if i == 0:
                p = "        "
            if i == 1:
                p = "<PERFME>"
            pdf.text(1, 1, p + "0" + str(j))
            pdf.output("ASSETS\white_font_pdf_" + str(i) + str(j) + ".pdf", "F")


if __name__ == "__main__":
    start_time = datetime.now()
    make_mailing_page(
        "WORK",
        "220721|9304631|1437|HOM910014093|PolChngQTE5008230209048553890|HOM|PolicyChange|ACG_PolicyChange_DEC_PolChngQTE5008230209048553890_07082022_concat.pdf|12|Vinay Salwan||1234 N Griffin St|||Danville|IL|61832-3328|United States|Regular|~BIN3~CM-GW01||IL|9314869904400066305423|0".split("|"),
        PyPDF2.PdfFileReader(os.path.join("WORK", "ACG_Submission_DEC_NewBusQTE2000048452673995277_07212022_concat.pdf")),
        2,
        {
            "certified": 0,
            "bulk": 0
        }
        )
    print(datetime.now() - start_time)