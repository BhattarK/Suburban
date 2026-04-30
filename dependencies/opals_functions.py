
import re
import time

import pyodbc
import requests

def get_opals_job_number(app_key):
    """Obtains a new OPALS job number.

    Args:
        app_key (int): OPALS app key.

    Returns:
        str: New OPALS job number.
    """
    run_hour = time.strftime("%#I")
    run_min = time.strftime("%#M")
    run_date = time.strftime("%m/%d/%Y")
    call_url = (
        "http://10.2.0.93:8500/api/AddAutoJobWithTime.cfc?"
        + "wsdl&method=AddAutoJob"
        + "&CustomerApplicationKey=" + str(app_key)
        + "&InDate=" + run_date
        + "&InHour=" + run_hour
        + "&InMinutes=" + run_min
        + "&TurnErrorsOn=1&opid=42854046"
        )
    ret_job_number = "None"
    response = requests.get(call_url)
    body = response.content.decode("utf-8")
    search_obj = re.search(r'\d+(?=&lt;/job_number)',body,re.M|re.I)
    if search_obj:
       ret_job_number = search_obj.group(0)

    # call_url = "http://10.2.0.93:8500/api/PostJobUpdateStatus.cfc?"
    # + "wsdl&method=PostJobUpdateStatus"
    # + "&jobNo=3000656"
    # + "&opid=47246782"

    # response = requests.get(call_url)
    return ret_job_number


def get_opals_job_number_description(app_key, description):
    """Obtains a new OPALS job number.

    Args:
        app_key (int): OPALS app key.

    Returns:
        str: New OPALS job number.
    """
    run_hour = time.strftime("%#I")
    run_min = time.strftime("%#M")
    run_date = time.strftime("%m-%d-%Y")
    call_url = (
        "http://10.2.0.93:8500/API/OPALS/makeOpalsJobs.cfc?"
        + "method=MakeJob"
        + "&returnformat=plain"
        + "&filedate=" + run_date
        + "&quantity=" + "1"
        + "&fileCount=" + "0"
        + "&Desc=" + description
        + "&customerapplicationkey=" + str(app_key)
        + "&OrderID=" + ""
        + "&Name=" + description
        # "http://10.2.0.93:8500/api/AddAutoJobWithTime.cfc?"
        # + "wsdl&method=AddAutoJob"
        # + "&CustomerApplicationKey=" + str(app_key)
        # + "&InDate=" + run_date
        # + "&InHour=" + run_hour
        # + "&InMinutes=" + run_min
        # + "&TurnErrorsOn=1&opid=42854046"
        )
    ret_job_number = "None"
    response = requests.get(call_url)
    body = response.content.decode("utf-8")
    return body
    search_obj = re.search(r'\d+(?=&lt;/job_number)',body,re.M|re.I)
    if search_obj:
       ret_job_number = search_obj.group(0)

    # call_url = "http://10.2.0.93:8500/api/PostJobUpdateStatus.cfc?"
    # + "wsdl&method=PostJobUpdateStatus"
    # + "&jobNo=3000656"
    # + "&opid=47246782"

    # response = requests.get(call_url)
    return ret_job_number


def shippo_api(prod, opid, JobNo, Provider, ShipMeth, PkgType, CompanyName, Attention, Address1, Address2, City, State, ZipCode, Country, Phone, PickupDate, Weight, Price, Signature, Insurance, ShipFromAccount, TrakingNumber, VOID, PackageCount, BillToAccount):
    """
<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/"> 
    <Body>
        <postShipPo xmlns="http://api">
            <opid>69902121</opid>
            <JobNo>[string]</JobNo>
            <Provider>[string]</Provider>
            <ShipMeth>[string]</ShipMeth>
            <PkgType>[string]</PkgType>
            <CompanyName>[string]</CompanyName>
            <Attention>[string]</Attention>
            <Address1>[string]</Address1>
            <Address2>[string]</Address2>
            <City>[string]</City>
            <State>[string]</State>
            <ZipCode>[string]</ZipCode>
            <Country>[string]</Country>
            <Phone>[string]</Phone>
            <PickupDate>[string]</PickupDate>
            <Weight>[string]</Weight>
            <Price>[string]</Price>
            <Signature>[string]</Signature>
            <Insurance>[string]</Insurance>
            <ShipFromAccount>[string]</ShipFromAccount>
            <TrakingNumber>[string]</TrakingNumber>
            <VOID>[string]</VOID>
            <PackageCount>[double]</PackageCount>
            <BillToAccount>[string]</BillToAccount>
        </postShipPo>
    </Body>
</Envelope>

    """
    
    if prod == "PROD":
        url = "http://10.2.0.93:8500/api"
    elif prod == "TEST":
        url = "http://199.183.145.33/api"
    return requests.post(
        f"{url}/postShipPo.cfc?wsdl&method=postShipPo"
        + f"&opid={str(opid)}" # APP KEY
        + f"&JobNo={str(JobNo)}" # OPALS #
        + f"&Provider={str(Provider)}" # REQ (Fedex, usps, etc.) [PolicyShipper].[CarrierName]
        + f"&ShipMeth={str(ShipMeth)}" # REQ (priority, etc.) [PolicyShipper].[ServiceLevel]
        + f"&PkgType={str(PkgType)}" # REQ (Tyvak) [PolicyShippo].[ContainerDescription]
        + f"&CompanyName={str(CompanyName)}" # REQ*
        + f"&Attention={str(Attention)}" # REQ*
        + f"&Address1={str(Address1)}" # REQ
        + f"&Address2={str(Address2)}"
        + f"&City={str(City)}" # REQ
        + f"&State={str(State)}" # REQ
        + f"&ZipCode={str(ZipCode)}" # REQ
        + f"&Country={str(Country)}" # REQ*
        + f"&Phone={str(Phone)}"
        + f"&PickupDate={str(PickupDate)}" # REQ*
        + f"&Weight={str(Weight)}" # REQ
        + f"&Price={str(Price)}" # REQ
        + f"&Signature={str(Signature)}" # REQ*
        + f"&Insurance={str(Insurance)}" # REQ*
        + f"&ShipFromAccount={str(ShipFromAccount)}" # REQ (EQU, AST, etc.)
        + f"&TrakingNumber={str(TrakingNumber)}" # REQ
        + f"&VOID={str(VOID)}"
        + f"&PackageCount={str(PackageCount)}"
        + f"&BillToAccount={str(BillToAccount)}"
    )


if __name__ == "__main__":
    opals_number = get_opals_job_number_description(1585, "TEST")
    testUrl = f"http://10.2.0.93:8500/api/PostJobUpdateStatus.cfc?wsdl&method=PostJobUpdateStatus&jobNo={opals_number}&opid=47246782"
    print("Setting status to Testing")
    print(testUrl)
    #logging.info("Setting status to Testing")
    response = requests.post(testUrl)
