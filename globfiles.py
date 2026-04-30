import time
import os
import sys
import time
from pathlib import Path
import datetime
import re
import shutil
import glob

#from config import INPUT_FOLDERS,OLDER_THAN_DAYS
""" Susan R 05/06/2024 just import config to access all variables set in config.py """
import config

""" Susan R 05/03/2024 add base_dir pass to join function exist  """
base_dir = "C:\Code\suburban_data_processing"

##def display_message(message, log_filename = os.path.join("LOGS", datetime.datetime.now().strftime("%Y%m%d") + ".log")):
def display_message(message, log_filename = os.path.join(base_dir,"LOG", datetime.datetime.now().strftime("%Y%m%d") + ".log")):
    """Updates a log file with a message. Also adds to log file time that message was added.

    Args:
        message (str): Message being logged.
    """
    with open(log_filename, "a+") as lock_file:
        print(message)
        lock_file.write(datetime.datetime.now().strftime("%Y:%m:%d - %H:%M:%S -- ") + message + "\n")


def main():
    path =  r"\\10.180.10.87\PDF\Production\010222024\Done"
   
    os.chdir(path)
    jpgFilenamesList = glob.glob('NSTA_241130*')
    filestosearch = []
    for file in jpgFilenamesList: 
        stat = os.stat(file)
        #print(stat.st_birthtime)
        print(stat.st_mtime)
        print("last modified: %s" % time.ctime(os.path.getmtime(file)))
        
        timeee = time.ctime(os.path.getmtime(file))
        timestmp =   str(time.ctime(os.path.getmtime(file))).split(" ")[4] 
         
        timestmps = str(timestmp).split(":")               
        
        print(timestmps[0])
        if "Dec  2" in str(timeee) and int(timestmps[0]) > 10: 
          print(timestmp) 
          filestosearch.append(file)   
    print(len(filestosearch))
            
     
if __name__ == "__main__":
    main()
