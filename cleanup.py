import time
import os
import sys
import time
from pathlib import Path
import datetime
import re
import shutil

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
    """Deletes files older than OLDER_THAN_DAYS
    """
    """ Susan R 05/03/2024 add create logs dir if not exist  """
    rc=0
    rc=os.path.exists(base_dir + '/LOG')
    if rc == 0:
       os.mkdir(base_dir + '/LOG')

    print ( "logs dir exists is ", rc )
    print ( "cur dir ", os.getcwd() )  
    """ end addition 05/03/2024 """

    folders = config.INPUT_FOLDERS.split(",") 

    """ Susan R 05/03/2024 print out the folders """    
    print ("input dirs:")
    print (folders)
    
    files_to_delete =[]
     
    for folder in folders: 
        """ Susan R 05/06/2024 add checks for existing directory else continue """
        os.path.exists(folder)
        if rc == 0 : 
           print (" path %s doesn't exist", folder)
           continue
        else :
           print (" path %s exists", folder)
        #if "LOGS" in folder :
        #    print ("folder - ", folder)
        #else :
        #  print ("Not a log folder", folder)
        """ end of addition 05/06/2024 """
        for root, subdirs, files in os.walk(folder):             
            if subdirs: 
              for subdir in subdirs:                   
                  for file in files: 
                     isfile = Path(os.path.join(root,subdir,file))
                     try: 
                        if isfile.is_file:                           
                           file_mod_time = datetime.datetime.fromtimestamp(os.path.getmtime(os.path.join(root,subdir,file)))
                           today = datetime.datetime.today()   
                           age = today - file_mod_time                               
                           days = re.findall('^\d+', str(age) )
                           print(days[0])
                           """ Susan R 05/06/2024 add to clean out log files as well """
                           if "LOG" in subdir :
                            print ("subdir %s", subdir)
                            if(int(days[0])) > int(config.OLDER_THAN_LOG_DAYS):                 
                               files_to_delete.append(os.path.join(root,subdir,file))
                           else :
                            if(int(days[0])) > int(config.OLDER_THAN_DAYS):                 
                               files_to_delete.append(os.path.join(root,subdir,file))           
                     except Exception: 
                         pass                    
                         
            else:                 
                for file in files: 
                     isfile = Path(os.path.join(root,file))
                     try: 
                        if isfile.is_file:                         
                           file_mod_time = datetime.datetime.fromtimestamp(os.path.getmtime(os.path.join(root,file)))
                           today = datetime.datetime.today()  
                           age = today - file_mod_time                                
                           days = re.findall('^\d+', str(age) )
                           if(int(days[0])) > int(config.OLDER_THAN_DAYS): 
                               print(days[0])   
                               files_to_delete.append(os.path.join(root,file))                                       
                     except Exception: 
                         pass                                   
              
    for file in files_to_delete: 
        print ("Removing.."+file)
        display_message("Removing.."+file)
        os.remove(file)
        #break
            
     
if __name__ == "__main__":
    main()
