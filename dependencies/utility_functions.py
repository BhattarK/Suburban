

import ftplib
import os
import re
import shutil
import sys
import time
import traceback
from datetime import datetime
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from smtplib import SMTP
from zipfile import ZipFile

import pysftp



def display_message(message, lck_filename="process.lck"):
    """Updates a log file with a message. Also adds to log file time that message was added.

    Args:
        message (str): Message being logged.
    """
    with open(lck_filename, "a+") as lock_file:
        print(message)
        lock_file.write(datetime.now().strftime("%Y:%m:%d - %H:%M:%S -- ") + message + "\n")


def clean_string(field_data):
    if "'" in field_data:
        field_data = field_data.replace("'", "\\'")
    backslash_indexes = [m.start() for m in re.finditer("\\\\", field_data)]
    if backslash_indexes:
        insert_count = 0
        for backslash_index in backslash_indexes:
            if len(field_data) == backslash_index + insert_count + 1:
                field_data += "\\"
                break
            if field_data[backslash_index + insert_count + 1] != "'":
                field_data = field_data[:backslash_index + insert_count] + "\\\\" + field_data[backslash_index + insert_count + 1:]
                insert_count += 1
    field_data = f"'{field_data.strip()}'"
    if "\\'" in field_data:
        field_data = "E" + field_data
        if field_data[-2] == "\\" and field_data[-3] != "\\":
            field_data = field_data[:-2] + "\\\\'"
    return field_data


def clean_folder(folder_name):
    if os.path.exists(folder_name):
        shutil.rmtree(folder_name)
    os.mkdir(folder_name)
    return folder_name


def send_email(subject, body, sender, recipients, attachment=None):
    """Sends an email

    Args:
        subject (str): Subject of email
        body (str): body of email
        sender (str): Sender of email
        recipients (list): List of email recipients
        attachment (str, optional): Path and name of attachment. Defaults to None.
    """
    msg = MIMEMultipart()

    msg['To'] = ", ".join(recipients)
    msg['From'] = sender
    msg['Subject'] = subject
    msg.attach(MIMEText(body, "plain"))

    if attachment is not None:
        with open(attachment, "rb") as manifest_file:
            manifest_attachment = MIMEApplication(manifest_file.read(), _subtype="pdf")

        manifest_attachment.add_header(
            'Content-Disposition', 'attachment', filename=os.path.basename(attachment)
            )

        msg.attach(manifest_attachment)

    message = msg.as_string()

    with SMTP(host='198.190.195.86', port=25) as server:
        server.sendmail(sender, recipients, message)
        server.quit()


def format_exception(e):
    exception_list = traceback.format_stack()
    exception_list = exception_list[:-2]
    exception_list.extend(traceback.format_tb(sys.exc_info()[2]))
    exception_list.extend(traceback.format_exception_only(sys.exc_info()[0], sys.exc_info()[1]))

    exception_str = "Traceback (most recent call last):\n"
    exception_str += "".join(exception_list)

    return exception_str


def send_error_email(error, subject="", body=""):
    error_string = format_exception(error)
    send_email(
        f"ERROR: Error occured in SUBURBAN {subject} program. Please investigate.",
        body + "\n\n" + error_string,
        "help_desk@contentcritical.com",
        [
              "amol.sagar@contentcritical.com",
              #"tariq.mohamed@contentcritical.com",
             "riddhi.rana@contentcritical.com",
             #"helene.fischer@contentcritical.com",
             "douglas.sikora@contentcritical.com",
             "cust_suburban@contentcritical.com",
             "ticket.system@ContentCritical.com"
            #"amol.sagar@contentcritical.com",            
        ]
    )
    print(error_string)


def zip_folder(zip_filename, folder_to_be_zipped):
    """Zips a single folder

    Args:
        zip_filename (str): Path and filename of zip file to be created
        folder_to_be_zipped (str): Path and name of folder to be zipped
    """
    with ZipFile(zip_filename, "w") as zip:
        for filename in os.listdir(folder_to_be_zipped):
            zip.write(os.path.join(folder_to_be_zipped, filename), arcname=filename)
            if os.path.isdir(os.path.join(folder_to_be_zipped, filename)):
                for sub_filename in os.listdir(os.path.join(folder_to_be_zipped, filename)):
                    zip.write(
                        os.path.join(folder_to_be_zipped, filename, sub_filename),
                        arcname=os.path.join(filename, sub_filename)
                    )


def unzip(in_file, unzipped_folder):
    """Unzips a zip file

    Args:
        in_file (str): Path and filename of zip file to be unzipped
        unzipped_folder (str): Path of folder where contents of zip file will be unzipped to
    """
    with ZipFile(in_file, "r") as zip:
        zip.extractall(unzipped_folder)


def sftp_upload(file_name, sftp_host, sftp_username, sftp_password, dest, sftp_port=22):
    """Uploads a file to a server via SFTP.

    Args:
        file_name (String): Name of file that is being uploaded
        dest (String): Where on the destination server the source file will be uploaded to
    """
    with pysftp.Connection(host=sftp_host, port=sftp_port, username=sftp_username, password=sftp_password) as sftp:
        sftp.cwd(dest)
        sftp.put(file_name)


def sftp_download(file_name, sftp_host, sftp_port, sftp_username, sftp_password, dest, download_dest):
    """Uploads a file to a server via SFTP.

    Args:
        file_name (String): Name of file that is being uploaded
        dest (String): Where on the destination server the source file will be uploaded to
    """
    with pysftp.Connection(host=sftp_host, port=sftp_port, username=sftp_username, password=sftp_password) as sftp:
        sftp.cwd(dest)

        previous_size = -1

        while True:
            if file_name in sftp.listdir():
                if sftp.stat(file_name).st_size == previous_size:
                    sftp.get(file_name, os.path.join(download_dest, file_name))
                    break
                previous_size = sftp.stat(file_name).st_size
            time.sleep(5)


def ftp_mkdir(dir_name, host, username, password, dir_location):
    """Uploads a file to a server via SFTP.

    Args:
        file_name (String): Name of file that is being uploaded
        dest (String): Where on the destination server the source file will be uploaded to
    """
    with ftplib.FTP() as ftp:
        ftp.connect(host)
        ftp.login(username, password)
        if dir_name not in ftp.nlst(dir_location):
            ftp.mkd(dir_name)


def ftp_listdir(host, username, password, dir_location):
    """Uploads a file to a server via SFTP.

    Args:
        file_name (String): Name of file that is being uploaded
        dest (String): Where on the destination server the source file will be uploaded to
    """
    with ftplib.FTP() as ftp:
        ftp.connect(host)
        ftp.login(username, password)
        return ftp.nlst(dir_location)


def ftp_upload(file_name, host, username, password, dest):
    """Uploads a file to a server via SFTP.

    Args:
        file_name (String): Name of file that is being uploaded
        dest (String): Where on the destination server the source file will be uploaded to
    """
    with ftplib.FTP() as ftp:
        ftp.connect(host)
        ftp.login(username, password)
        ftp.cwd(dest)

        with open(file_name, "rb") as file_binary:
            ftp.storbinary(
                "STOR %s" % file_name,
                file_binary,
                1024
                )
