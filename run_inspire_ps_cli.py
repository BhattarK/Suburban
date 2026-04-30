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
    v_workflow = r"\\10.2.0.194\bgjobs\Suburban_LTR_DUN_15b.wfd"
    v_outmodule = "PDF_WEB"
    v_outpath = r"\\10.2.0.194\bgjobs\%h03"    # ends with \%h03
    v_datafileid = "91ed073f5db74a829f7b785767e4aa17" #
    v_split = "-splitbygroup"  # "-splitbygroup" or ""
    v_server = "10.2.0.194"
    v_port = "30354"   # 30354 or ""
    v_inspireExe = r"C:\Program Files\Quadient\Inspire Designer\InspirePSCLI.exe"
    v_logpath = r"\\10.180.10.87\Suburban\Quadient\LOG"


    run_InspirePSCLI(v_workflow, v_outmodule, v_outpath, v_datafileid, v_split, v_server, v_port, v_inspireExe, v_logpath)

