import os

PROD = True
INPUT_FOLDERS  = r"\\10.180.10.87\PDF\Production\010222024\Done"
OLDER_THAN_DAYS= r"15"
OLDER_THAN_LOG_DAYS= r"15"
INVOICE_CONFIG_FILENAME = os.path.join("JSON", "invoice_config.json")
STATEMENT_CONFIG_FILENAME = os.path.join("JSON", "statement_config.json")
RENTERS_CONFIG_FILENAME = os.path.join("JSON", "renters_config.json")
DUNNING_CONFIG_FILENAME = os.path.join("JSON", "dunning_config.json")
LETTERS_CONFIG_FILENAME = os.path.join("JSON", "letters_config.json")
DENIED_CREDIT_CONFIG_FILENAME = os.path.join("JSON", "denied_credit_config.json")
if PROD:
    CONNECT_STRING = (
        "DRIVER={PostgreSQL Unicode};Trusted_connection=no;"
        + "SERVER=localhost;PORT=5432; DATABASE=suburban_production;UID=processing;PWD=processing07072"
    )
    PDF_FOLDER = r"\\10.180.10.87\PDF\Production\010222024\%h03"
    LETTERS_WFD = r"\\10.180.10.87\Suburban\Quadient\LETTERS\Suburban_LTR_COLL_15b.wfd"
    SAEDUN_WFD = r"\\10.180.10.87\Suburban\Quadient\LETTERS\Suburban_LTR_DUN_15b.wfd"
    DC_WFD = r"\\10.180.10.87\Suburban\Quadient\LETTERS\Suburban_LTR_DoC_15a.wfd"
    SAESTA_WFD = r"\\10.180.10.87\Suburban\Quadient\STATEMENT\Suburban_Statement_Prod.wfd"
    SAEINV_SPL_WFD = r"\\10.180.10.87\Suburban\Quadient\INVOICE\Suburban_Invoice_spl_Prod.wfd"
    SAEREN_SPL_WFD = r"\\10.180.10.87\Suburban\Quadient\RENTALS\Suburban_Rental_spl_Prod.wfd"
    SAEINV_WFD = r"\\10.180.10.87\Suburban\Quadient\INVOICE\Suburban_Invoice_Prod.wfd"
    SAEREN_WFD = r"\\10.180.10.87\Suburban\Quadient\RENTALS\Suburban_Rental_Prod.wfd"
else:
    CONNECT_STRING = (
        "DRIVER={PostgreSQL Unicode};Trusted_connection=no;"
        + "SERVER=localhost;PORT=5432; DATABASE=suburban_sandbox;UID=processing;PWD=processing07072"
    )
    PDF_FOLDER = r"\\10.180.10.87\PDF\Sandbox\%h03"
    LETTERS_WFD = r"\\10.180.10.87\Suburban\Quadient\LETTERS\Suburban_LTR_COLL_15b_Sandbox.wfd"
    SAEDUN_WFD = r"\\10.180.10.87\Suburban\Quadient\LETTERS\Suburban_LTR_DUN_15b_Sandbox.wfd"
    DC_WFD = r"\\10.180.10.87\Suburban\Quadient\LETTERS\Suburban_LTR_DoC_15a_Sandbox.wfd"
    SAESTA_WFD = r"\\10.180.10.87\Suburban\Quadient\STATEMENT\Suburban_Statement_Sandbox.wfd"
    SAEINV_SPL_WFD = r"\\10.180.10.87\Suburban\Quadient\INVOICE\Suburban_Invoice_spl_Sandbox.wfd"
    SAEREN_SPL_WFD = r"\\10.180.10.87\Suburban\Quadient\RENTALS\Suburban_Rental_spl_Sandbox.wfd"
    SAEINV_WFD = r"\\10.180.10.87\Suburban\Quadient\INVOICE\Suburban_Invoice_Sandbox.wfd"
    SAEREN_WFD = r"\\10.180.10.87\Suburban\Quadient\RENTALS\Suburban_Rental_Sandbox.wfd"


FTP_SERVER = "ftp0.contentcritical.com"
SFTP_SERVER = "sftp.contentcritical.com"
SFTP_USERNAME = "sbp22"
SFTP_PASSWORD = "UwYRazQ2X1cyM1z!"
DDA_ENV = "production"
CSC_1654_MESSAGES = {
    "007": "This renewable product is produced by naturally-occurring, tree-based waste stream from kraft pulp mills.",
    "008": "This product consists of 96% Propane and 4% rDME that is produced by naturally-occurring, tree-based waste stream from kraft pulp mills.",
    "014": "This product consists of 96% Propane and 4% rDME that is produced by naturally-occurring, tree-based waste stream from kraft pulp mills.",
    "009": "This renewable product consists of 96% rpropane and 4% rDME that is produced by naturally-occurring, tree-based waste stream from kraft pulp mills.",
    "015": "This renewable product consists of 96% rpropane and 4% rDME that is produced by naturally-occurring, tree-based waste stream from kraft pulp mills.",
    "025": "This renewable product consists of 84% rpropane and 16% rDME that is produced by naturally-occurring, tree-based waste stream from kraft pulp mills."
    }
TEXAS_RAILROAD_MESSAGE = "'You may notify the Railroad Commission of Texas of any service interruptions that do not involve a refusal to serve at 1-877-228-5740.'"
