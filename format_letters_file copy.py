import json
import os
from pprint import pprint
import shutil
import glob

import pyodbc
from dependencies.utility_functions import sftp_upload
import pandas as pd
import io
import sys

from suburban_propane import CONNECT_STRING, SFTP_PASSWORD, SFTP_SERVER, SFTP_USERNAME, clean_string, decode_file


def replacer(s, newstring, index, nofail=False):
    # raise an error if index is outside of the string
    if not nofail and index not in range(len(s)):
        raise ValueError("index outside given string")

    # if not erroring, but the index is still not in the correct range..
    if index < 0:  # add it to the beginning
        return newstring + s
    if index > len(s):  # add it to the end
        return s + newstring

    # insert the new string between "slices" of the original
    return s[:index] + newstring + s[index + 1:]

def insert_string(string, index, new_string):
    return string[:index] + new_string + string[index:]


def main(): 
    #file = r"C:\Code\suburban_data_processing\INPUT\ARCHIVE\DECODED\LETTERS_241221.txt"
    os.chdir(r"D:\PythonApp\suburban_data_processing")
    file = sys.argv[1]
    file_backup = os.path.dirname(file)
    file_backup = os.path.join(file_backup,os.path.basename(file[:-4] + "_BKP.txt"))
    ofile = open(file, 'r')   
    Lines = ofile.readlines() 
    with open(file_backup, "a") as myfile:
        for line in Lines: 
            if line.startswith("D"): 
                df = pd.read_fwf(io.StringIO(line), colspecs=[(4,9),(11, 51),(227, 235) ],header=None, names=['customer_account_number','customer_name','check_date'])                 
                check_date = df["check_date"].values[0]
                check_month = str(check_date).split("/")
                if len(check_month[0]) ==1:                    
                    dateindex = line.index(str(df["check_date"].values[0]))
                    line = line.replace(str(df["check_date"].values[0]),"")
                    line = insert_string(line, dateindex-1, "0" + str(df["check_date"].values[0]))              
            myfile.write(line)      
    ofile.close()                                
    os.rename(file,file[:-4]+ "_ORIG.txt")
    os.rename(file_backup,file)                                              


if __name__ == "__main__":
    main()


