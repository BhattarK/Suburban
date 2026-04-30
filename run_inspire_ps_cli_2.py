import subprocess

def run_InspirePSCLI(workflow, out_module, out_path, data_file_id, split, server, port, inspire_exe, logpath):
    args = [
        inspire_exe,
        "-s",
        server,
        "-p",
        port,
        workflow,   
        "-f",
        out_path,
        "-DataFileIDParam",
        data_file_id,
        "-o",
        out_module,
        "-la",
        f"{logpath}\{data_file_id}.log",
        split
    ]

    try:
        process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output_b, error = process.communicate()
        output = output_b.decode('UTF-8')

        if "Critical error 0900:Licensing:" in output or "Error accessing dongle" in output or "Number of licenses exceeded" in output:
            print("DDA is in use, please try again.")
            return -1

        if "Fatal error" in output:
            raise Exception(f"DDA: {output[output.index('Fatal error'):]}")

        if any(
            term in output
            for term in ("Critical error", "Aborting", "No valid dongle found", "Cannot open file", "Can't connect to License Manager", "WRONG_ADDRESS")
        ):
            raise Exception(f"DDA: {output}")

    except Exception as ex:
        raise

    # Wait for the process to finish
    process.wait()

    return 0


# Example usage
if __name__ == "__main__":
    # v_datafileid = "f814e1051fee4b8fa323e0d90c548fa0" #
    # v_workflow = r"\\10.180.10.87\Suburban\Quadient\STATEMENT\Suburban_Statement_Prod.wfd"
    v_datafileid = "f639113715f64e80a6a3f6b73580b7dc" #
    v_workflow = r"\\10.180.10.87\Suburban\Quadient\RENTALS\Suburban_Rental_Prod.wfd"
    # v_datafileid = "b67b2622149547f390328cf9931481ff" #
    # v_workflow = r"\\10.180.10.87\Suburban\Quadient\INVOICE\Suburban_Invoice_spl_Prod.wfd"
    # v_datafileid = "8c00efe181404ba88a64e1bb66728362" #
    # v_workflow = r"\\10.180.10.87\Suburban\Quadient\INVOICE\Suburban_Invoice_Prod.wfd"
    # v_datafileid = "1083dcbc18e2444bae9713da42368880" #
    # v_workflow = r"\\10.180.10.87\Suburban\Quadient\LETTERS\Suburban_LTR_DoC_15a.wfd"
    
    v_outpath =  r"\\10.180.10.87\Suburban\PDF_Output\test\%h03"    # ends with \%h03
    # v_inspireExe = r"C:\Program Files\Quadient\Inspire Designer\InspirePSCLI.exe"
    v_inspireExe = r"C:\Program Files\Quadient\Inspire Designer R15\InspirePSCLI.exe"
    v_outmodule = "PDF_WEB"
    v_split = "-splitbygroup"  # "-splitbygroup" or ""
    v_server = "10.2.0.194"     #"10.180.10.83"
    v_port = "30354"   # 30354 or ""
    v_logpath = r"\\10.180.10.87\Suburban\Quadient\LOG"


    run_InspirePSCLI(v_workflow, v_outmodule, v_outpath, v_datafileid, v_split, v_server, v_port, v_inspireExe, v_logpath)

