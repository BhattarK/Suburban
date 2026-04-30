import requests
import xml.etree.ElementTree as ET
import re

def PostJobComponentMetric(Job_Number,PdfCount,Impressions,Envelopes,Sheet,Hour,Cd,Sq_Foot,Foot,Record,Parm10=0,Parm11=0,Parm12=0,Parm13=0):
  metricName = {}
  mKey = 0
  #retStr = PostJobComponentMetric(801321,0,5588,351,0,0,0,0,0,0)
  retStr = getEstimateCompMetric()
  root = ET.fromstring(retStr)
  for child in root.iter('EstimateCompMetricName'):
      #print(child.tag, child.text)
      mKey += 1
      metricName.setdefault(mKey, child.text)
      print(child.text)
  
  #callURL = "http://199.183.145.33/api/PostJobComponentMetric.cfc?method=PostJobComponentMetric"
  callURL = "http://10.2.0.93:8500/api/PostJobComponentMetric.cfc?method=PostJobComponentMetric"
  strJobN = "&jobNo=" + str(Job_Number)
  strCompKey = "&jobComponentCountSourceKey=7"
  strPdf = "&" + metricName[1] + "=" + str(PdfCount)
  strImpressions = "&" + metricName[2] + "=" + str(Impressions)
  strEnvelopes = "&" + metricName[3] + "=" + str(Envelopes)
  strSheet = "&" + metricName[4] + "=" + str(Sheet)
  strHour = "&" + metricName[5] + "=" + str(Hour)
  strCd = "&" + metricName[6] + "=" + str(Cd)
  strSqFoot = "&" + metricName[7] + "=" + str(Sq_Foot)
  strFoot = "&" + metricName[8] + "=" +  str(Foot)
  strRecord = "&" + metricName[9] + "=" + str(Record)
  strOpid = "&opid=28263417"

  # Build extra fields
  extras = "&" + metricName[10] + "=" + str(Parm10)
  for eFields in range(11,len(metricName) + 1):
    extras = extras + "&" + metricName[eFields] + "=0"

  callURL = callURL + strJobN  + strCompKey + strPdf + strImpressions + strEnvelopes + strSheet + strHour + \
            strCd + strSqFoot + strFoot + strRecord + extras + strOpid

  print(callURL)
  response = requests.post(callURL)
    
  body = response.content.decode('utf-8')
  
  return body

def getEstimateCompMetric():
  #callURL = "http://199.183.145.33/api/getEstimateCompMetric.cfc?wsdl&method=getEstimateCompMetric&opid=68447671"
  callURL = "http://10.2.0.93:8500/api/getEstimateCompMetric.cfc?wsdl&method=getEstimateCompMetric&opid=68447671"

  print(callURL)
  response = requests.get(callURL)
    
  body = response.content #.decode('utf-8')
  
  return body

if __name__ == "__main__":
  metricName = {}
  mKey = 0
  retStr = PostJobComponentMetric(832955,0,0,0,0,0,0,0,0,54)
  # retStr = getEstimateCompMetric()
  root = ET.fromstring(retStr)
  # for child in root.iter('EstimateCompMetricName'):
  #     #print(child.tag, child.text)
  #     mKey += 1
  #     metricName.setdefault(mKey, child.text)
  
  # for mName in metricName.keys():
  #   print(mName,metricName[mName])
  print("Error {}".format(root.find("Error").text))
  print("StatusCode {}".format(root.find("StatusCode").text))
  print("ErrorDescription {}".format(root.find("ErrorDescription").text))
  print("StatusMessage {}".format(root.find("StatusMessage").text))
