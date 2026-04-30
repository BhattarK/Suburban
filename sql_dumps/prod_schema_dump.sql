--
-- PostgreSQL database dump
--

-- Dumped from database version 15.3
-- Dumped by pg_dump version 16.0

-- Started on 2026-01-30 17:10:08

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2 (class 3079 OID 354802)
-- Name: dblink; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;


--
-- TOC entry 4388 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION dblink; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';


--
-- TOC entry 3 (class 3079 OID 17346)
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- TOC entry 4389 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- TOC entry 433 (class 1255 OID 22707)
-- Name: calculate_new_transaction_code(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_new_transaction_code() RETURNS TABLE(transaction_code text, transaction_unit_price numeric, new_transaction_code text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        transaction_code,
        transaction_unit_price,
        CASE
            WHEN CAST(transaction_unit_price AS DECIMAL) > 0 THEN 
                CONCAT('PRICE PER GALLON ', format_decimal_new(CAST(transaction_unit_price AS DECIMAL) / 100) )
            ELSE transaction_code
        END AS new_transaction_code
    FROM document_line;
END;
$$;


ALTER FUNCTION public.calculate_new_transaction_code() OWNER TO postgres;

--
-- TOC entry 504 (class 1255 OID 372949)
-- Name: daily_estat(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.daily_estat(_inputdate date DEFAULT NULL::date) RETURNS date
    LANGUAGE plpgsql
    AS $$
DECLARE
    _fromdate DATE;
    _toDate DATE;
    _metric_pdf INTEGER;
    _metric_record INTEGER;
    _metric_compexta1 INTEGER;
    _recordExists INTEGER;
BEGIN
    -- Determine the _fromdate
    IF _inputDate IS NOT NULL THEN
        _fromdate := _inputDate;
    ELSE
        SELECT MAX(todate) INTO _fromdate
        FROM ejob;

        -- If _fromdate is NULL, set it to yesterday
        IF _fromdate IS NULL THEN
            _fromdate := CURRENT_DATE - INTERVAL '1 day';
        END IF;
    END IF;

    -- Add one day to the _fromdate
    _toDate := _fromdate + INTERVAL '1 day';

    -- Check if _toDate is today
    IF _toDate = CURRENT_DATE THEN 
        RETURN _toDate;
    END IF;

    -- Get metrics
    SELECT 
        SUM(page_count),
        COUNT(*),
        COUNT(CASE 
                 WHEN LOWER(deliverymethod) = 'paperless' 
                      AND document.valid = TRUE 
                      AND COALESCE(supress, FALSE) = FALSE 
                 THEN 1 
                 ELSE NULL 
              END)
    INTO _metric_pdf, _metric_record, _metric_compexta1
    FROM public.document 
    INNER JOIN branch ON branch.branchID = document.branchID
    INNER JOIN datafile ON datafile.datafileID = branch.datafileID
    WHERE cast(document.createdate as date) >= _fromdate 
      AND document.valid = true 
      AND datafile.valid = true 
      AND datafile.status != 'Maintenance'
	  AND datafile.ApplicationID is not null 
      AND cast(document.createdate as date) < _toDate;

    -- Check if record already exists
    SELECT COUNT(*) INTO _recordExists
    FROM ejob 
    WHERE fromdate = _fromdate
      AND todate = _toDate;

    -- Insert or update record
    IF _recordExists = 0 THEN
        INSERT INTO ejob (fromdate, todate, metric_pdf, metric_record, metric_compexta1)
        VALUES (_fromdate, _toDate, _metric_pdf, _metric_record, _metric_compexta1);
    ELSE
        UPDATE ejob 
        SET 
            metric_pdf = _metric_pdf,
            metric_record = _metric_record,
            metric_compexta1 = _metric_compexta1
        WHERE 
            fromdate = _fromdate
            AND todate = _toDate;
    END IF;

    RETURN _fromdate;
END;
$$;


ALTER FUNCTION public.daily_estat(_inputdate date) OWNER TO postgres;

--
-- TOC entry 452 (class 1255 OID 187039)
-- Name: decimal4_format_with_zero(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal4_format_with_zero(input_number numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    formatted_output TEXT;
BEGIN
    -- Handle null input
    IF input_number IS NULL THEN
        RETURN '0.0000';
    END IF;

    -- Format input number
    IF ABS(input_number) < 10000 THEN
        -- For numbers less than 10000, add leading zeros to make it 4 digits long
        formatted_output := TO_CHAR(ABS(input_number) / 10000, 'FM0.0000');
    ELSE
        -- For numbers 10000 and above, format normally
        formatted_output := TO_CHAR(ABS(input_number) / 10000, 'FM999G999G990D0000');
    END IF;

    -- Add negative sign if necessary
    IF input_number < 0 THEN
        formatted_output := '-' || formatted_output;
    END IF;

    RETURN formatted_output;
END;
$$;


ALTER FUNCTION public.decimal4_format_with_zero(input_number numeric) OWNER TO postgres;

--
-- TOC entry 445 (class 1255 OID 181779)
-- Name: decimal4_format_with_zero(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal4_format_with_zero(input_text text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    input_number NUMERIC;
    formatted_output TEXT;
BEGIN
    -- Handle empty, null, or invalid input
    IF input_text IS NULL OR input_text = '' THEN
        RETURN '0.0000';
    END IF;

    BEGIN
        input_number := input_text::NUMERIC;
    EXCEPTION WHEN OTHERS THEN
        -- In case of casting error, return '0.0000'
        RETURN '0.0000';
    END;

    -- Format input number
    IF ABS(input_number) < 10000 THEN
        -- For numbers less than 10000, add leading zeros to make it 4 digits long
        formatted_output := TO_CHAR(ABS(input_number) / 10000, 'FM0.0000');
    ELSE
        -- For numbers 10000 and above, format normally
        formatted_output := TO_CHAR(ABS(input_number) / 10000, 'FM999G999G990D0000');
    END IF;

    -- Add negative sign if necessary
    IF input_number < 0 THEN
        formatted_output := '-' || formatted_output;
    END IF;

    RETURN formatted_output;
END;
$$;


ALTER FUNCTION public.decimal4_format_with_zero(input_text text) OWNER TO postgres;

--
-- TOC entry 440 (class 1255 OID 187040)
-- Name: decimal5_format_with_zero(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal5_format_with_zero(input_number numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    formatted_output TEXT;
BEGIN
    -- Handle null input
    IF input_number IS NULL THEN
        RETURN '0.00000';
    END IF;

    -- Format input number
    IF ABS(input_number) < 100000 THEN
        -- For numbers less than 100000, add leading zeros to make it 5 digits long
        formatted_output := TO_CHAR(ABS(input_number) / 100000, 'FM0.00000');
    ELSE
        -- For numbers 100000 and above, format normally
        formatted_output := TO_CHAR(ABS(input_number) / 100000, 'FM999G999G990D00000');
    END IF;

    -- Add negative sign if necessary
    IF input_number < 0 THEN
        formatted_output := '-' || formatted_output;
    END IF;

    RETURN formatted_output;
END;
$$;


ALTER FUNCTION public.decimal5_format_with_zero(input_number numeric) OWNER TO postgres;

--
-- TOC entry 453 (class 1255 OID 182813)
-- Name: decimal5_format_with_zero(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal5_format_with_zero(input_text text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    input_number NUMERIC;
    formatted_output TEXT;
BEGIN
    -- Handle empty input
    IF input_text IS NULL OR input_text = '' THEN
        RETURN '0.00000';
    END IF;

    -- Convert input text to numeric
    input_number := input_text::NUMERIC;

    -- Format input number
    IF ABS(input_number) < 100000 THEN
        -- For numbers less than 100000, add leading zeros to make it 5 digits long
        formatted_output := TO_CHAR(ABS(input_number) / 100000, 'FM0.00000');
    ELSE
        -- For numbers 100000 and above, format normally
        formatted_output := TO_CHAR(ABS(input_number) / 100000, 'FM999G999G990D00000');
    END IF;

    -- Add negative sign if necessary
    IF input_number < 0 THEN
        formatted_output := '-' || formatted_output;
    END IF;

    RETURN formatted_output;
END;
$$;


ALTER FUNCTION public.decimal5_format_with_zero(input_text text) OWNER TO postgres;

--
-- TOC entry 442 (class 1255 OID 183177)
-- Name: decimal6_format_with_zero(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal6_format_with_zero(input_number numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    formatted_output TEXT;
BEGIN
    -- Handle null input
    IF input_number IS NULL THEN
        RETURN '0.000000';
    END IF;

    -- Format input number
    IF ABS(input_number) < 1000000 THEN
        -- For numbers less than 1000000, add leading zeros to make it 6 digits long
        formatted_output := TO_CHAR(ABS(input_number) / 1000000, 'FM0.000000');
    ELSE
        -- For numbers 1000000 and above, format normally
        formatted_output := TO_CHAR(ABS(input_number) / 1000000, 'FM999G999G990D000000');
    END IF;

    -- Add negative sign if necessary
    IF input_number < 0 THEN
        formatted_output := '-' || formatted_output;
    END IF;

    RETURN formatted_output;
END;
$$;


ALTER FUNCTION public.decimal6_format_with_zero(input_number numeric) OWNER TO postgres;

--
-- TOC entry 454 (class 1255 OID 183239)
-- Name: decimal6_format_with_zero(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal6_format_with_zero(input_text text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    input_number NUMERIC;
    formatted_output TEXT;
BEGIN
    -- Handle empty input
    IF input_text IS NULL OR input_text = '' THEN
        RETURN '0.000000';
    END IF;

    -- Convert input text to numeric
    input_number := input_text::NUMERIC;

    -- Format input number
    IF ABS(input_number) < 1000000 THEN
        -- For numbers less than 1000000, add leading zeros to make it 6 digits long
        formatted_output := TO_CHAR(ABS(input_number) / 1000000, 'FM0.000000');
    ELSE
        -- For numbers 1000000 and above, format normally
        formatted_output := TO_CHAR(ABS(input_number) / 1000000, 'FM999G999G990D000000');
    END IF;

    -- Add negative sign if necessary
    IF input_number < 0 THEN
        formatted_output := '-' || formatted_output;
    END IF;

    RETURN formatted_output;
END;
$$;


ALTER FUNCTION public.decimal6_format_with_zero(input_text text) OWNER TO postgres;

--
-- TOC entry 444 (class 1255 OID 171573)
-- Name: decimal_format_with_zero(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal_format_with_zero(input_number numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    formatted_output TEXT;
BEGIN
    -- Check for NULL input
    IF input_number IS NULL THEN
        RETURN '0.00';
    END IF;

    -- Handle negative numbers
    IF input_number < 0 THEN
        -- Apply the format for negative values less than -99
        IF input_number <= -100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM999G999G990D00');
        -- Apply the format for negative values between -1 and -99
        ELSE
            formatted_output := '-' || TO_CHAR(ABS(input_number) / 100, 'FM0D00');
        END IF;
    -- Handle non-negative numbers
    ELSE
        -- Apply the format for values less than 100
        IF input_number < 100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM0D00');
        -- Apply the format for values 100 and above
        ELSE
            formatted_output := TO_CHAR(input_number / 100, 'FM999G999G990D00');
        END IF;
    END IF;

    -- Return the formatted output
    RETURN formatted_output;
EXCEPTION WHEN OTHERS THEN
    -- In case of an error, return '0.00'
    RETURN '0.00';
END;
$$;


ALTER FUNCTION public.decimal_format_with_zero(input_number numeric) OWNER TO postgres;

--
-- TOC entry 438 (class 1255 OID 172639)
-- Name: decimal_format_with_zero(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal_format_with_zero(input_text text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    input_number NUMERIC;
    formatted_output TEXT;
BEGIN
    -- Attempt to cast input text to numeric
    BEGIN
        input_number := input_text::NUMERIC;
    EXCEPTION WHEN OTHERS THEN
        -- In case of casting error, return '0.00'
        RETURN '0.00';
    END;

    -- Check for NULL or zero value after casting
    IF input_number IS NULL OR input_number = 0 THEN
        RETURN '0.00';
    END IF;

    -- Handle negative numbers
    IF input_number < 0 THEN
        -- Apply the format for negative values less than -99
        IF input_number <= -100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM999G999G990D00');
        -- Apply the format for negative values between -1 and -99
        ELSE
            formatted_output := '-' || TO_CHAR(ABS(input_number) / 100, 'FM0D00');
        END IF;
    -- Handle non-negative numbers
    ELSE
        -- Apply the format for values less than 100
        IF input_number < 100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM0D00');
        -- Apply the format for values 100 and above
        ELSE
            formatted_output := TO_CHAR(input_number / 100, 'FM999G999G990D00');
        END IF;
    END IF;

    -- Return the formatted output
    RETURN formatted_output;
EXCEPTION WHEN OTHERS THEN
    -- In case of any other error, return '0.00'
    RETURN '0.00';
END;
$$;


ALTER FUNCTION public.decimal_format_with_zero(input_text text) OWNER TO postgres;

--
-- TOC entry 489 (class 1255 OID 228847)
-- Name: decimal_format_with_zero_plain(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal_format_with_zero_plain(input_number numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    formatted_output TEXT;
BEGIN
    -- Check for NULL input
    IF input_number IS NULL THEN
        RETURN '0.00';
    END IF;

    -- Handle negative numbers
    IF input_number < 0 THEN
        -- Apply the format for negative values less than -99
        IF input_number <= -100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM999999990D00');  
        -- Apply the format for negative values between -1 and -99
        ELSE
            formatted_output := '-' || TO_CHAR(ABS(input_number) / 100, 'FM0D00');
        END IF;
    -- Handle non-negative numbers
    ELSE
        -- Apply the format for values less than 100
        IF input_number < 100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM0D00');
        -- Apply the format for values 100 and above
        ELSE
            formatted_output := TO_CHAR(input_number / 100, 'FM999999990D00');  
        END IF;
    END IF;

    -- Return the formatted output
    RETURN formatted_output;
EXCEPTION WHEN OTHERS THEN
    -- In case of an error, return '0.00'
    RETURN '0.00';
END;
$$;


ALTER FUNCTION public.decimal_format_with_zero_plain(input_number numeric) OWNER TO postgres;

--
-- TOC entry 502 (class 1255 OID 228848)
-- Name: decimal_format_with_zero_plain(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal_format_with_zero_plain(input_text text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    input_number NUMERIC;
    formatted_output TEXT;
BEGIN
    -- Attempt to cast input text to numeric
    BEGIN
        input_number := input_text::NUMERIC;
    EXCEPTION WHEN OTHERS THEN
        -- In case of casting error, return '0.00'
        RETURN '0.00';
    END;

    -- Check for NULL or zero value after casting
    IF input_number IS NULL OR input_number = 0 THEN
        RETURN '0.00';
    END IF;

    -- Handle negative numbers
    IF input_number < 0 THEN
        -- Apply the format for negative values less than -99
        IF input_number <= -100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM999999990D00');
        -- Apply the format for negative values between -1 and -99
        ELSE
            formatted_output := '-' || TO_CHAR(ABS(input_number) / 100, 'FM0D00');
        END IF;
    -- Handle non-negative numbers
    ELSE
        -- Apply the format for values less than 100
        IF input_number < 100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM0D00');
        -- Apply the format for values 100 and above
        ELSE
            formatted_output := TO_CHAR(input_number / 100, 'FM999999990D00');
        END IF;
    END IF;

    -- Return the formatted output
    RETURN formatted_output;
EXCEPTION WHEN OTHERS THEN
    -- In case of any other error, return '0.00'
    RETURN '0.00';
END;
$$;


ALTER FUNCTION public.decimal_format_with_zero_plain(input_text text) OWNER TO postgres;

--
-- TOC entry 439 (class 1255 OID 171690)
-- Name: decimal_format_without_zero(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal_format_without_zero(input_number numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Return empty string for NULL or zero values
    IF input_number IS NULL OR input_number = 0 THEN
        RETURN '';
    END IF;

    -- Handle negative numbers
    IF input_number < 0 THEN
        -- Apply the format for negative values less than -99
        IF input_number <= -100 THEN
            RETURN TO_CHAR(input_number / 100, 'FM999G999G990D00');
        -- Apply the format for negative values between -1 and -99
        ELSE
            RETURN '-' || TO_CHAR(ABS(input_number) / 100, 'FM0D00');
        END IF;
    -- Handle non-negative numbers
    ELSE
        -- Apply the format for values less than 100
        IF input_number < 100 THEN
            RETURN TO_CHAR(input_number / 100, 'FM0D00');
        -- Apply the format for values 100 and above
        ELSE
            RETURN TO_CHAR(input_number / 100, 'FM999G999G990D00');
        END IF;
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Return empty string in case of any other error
    RETURN '';
END;
$$;


ALTER FUNCTION public.decimal_format_without_zero(input_number numeric) OWNER TO postgres;

--
-- TOC entry 443 (class 1255 OID 171689)
-- Name: decimal_format_without_zero(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.decimal_format_without_zero(input_string text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    numeric_value NUMERIC;
BEGIN
    -- Attempt to convert input string to numeric, returning empty for NULL or empty strings
    BEGIN
        numeric_value := NULLIF(input_string, '')::NUMERIC;
    EXCEPTION WHEN OTHERS THEN
        RETURN '';
    END;

    -- Return empty string for NULL or zero values
    IF numeric_value IS NULL OR numeric_value = 0 THEN
        RETURN '';
    END IF;

    -- Handle negative numbers
    IF numeric_value < 0 THEN
        -- Apply the format for negative values less than -99
        IF numeric_value <= -100 THEN
            RETURN TO_CHAR(numeric_value / 100, 'FM999G999G990D00');
        -- Apply the format for negative values between -1 and -99
        ELSE
            RETURN '-' || TO_CHAR(ABS(numeric_value) / 100, 'FM0D00');
        END IF;
    -- Handle non-negative numbers
    ELSE
        -- Apply the format for values less than 100
        IF numeric_value < 100 THEN
            RETURN TO_CHAR(numeric_value / 100, 'FM0D00');
        -- Apply the format for values 100 and above
        ELSE
            RETURN TO_CHAR(numeric_value / 100, 'FM999G999G990D00');
        END IF;
    END IF;

EXCEPTION WHEN OTHERS THEN
    -- Return empty string in case of any other error
    RETURN '';
END;
$$;


ALTER FUNCTION public.decimal_format_without_zero(input_string text) OWNER TO postgres;

--
-- TOC entry 488 (class 1255 OID 201498)
-- Name: decimal_format_without_zero_subtotal(numeric); Type: FUNCTION; Schema: public; Owner: processing
--

CREATE FUNCTION public.decimal_format_without_zero_subtotal(input_number numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    formatted_output TEXT;
BEGIN
    -- Check for NULL input
    IF input_number IS NULL THEN
        RETURN NULL;  -- Return NULL for NULL input
    END IF;

    -- Handle negative numbers
    IF input_number < 0 THEN
        -- Apply the format for negative values less than -99
        IF input_number <= -100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM999G999G990D00');
        -- Apply the format for negative values between -1 and -99
        ELSE
            formatted_output := '-' || TO_CHAR(ABS(input_number) / 100, 'FM0D00');
        END IF;
    -- Handle non-negative numbers
    ELSE
        -- Apply the format for values less than 100
        IF input_number < 100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM0D00');
        -- Apply the format for values 100 and above
        ELSE
            formatted_output := TO_CHAR(input_number / 100, 'FM999G999G990D00');
        END IF;
    END IF;

    -- Return the formatted output
    RETURN formatted_output;
EXCEPTION WHEN OTHERS THEN
    -- In case of an error, return NULL
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.decimal_format_without_zero_subtotal(input_number numeric) OWNER TO processing;

--
-- TOC entry 434 (class 1255 OID 37375)
-- Name: delete_datafile(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_datafile() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Delete from document_line through document through Branch where datafileID matches
  DELETE FROM document_line
  USING document, Branch
  WHERE document_line.documentID = document.documentID
    AND document.BranchID = Branch.BranchID
    AND Branch.datafileID = OLD.datafileID;

  -- Delete from document through Branch where datafileID matches
  DELETE FROM document
  USING Branch
  WHERE document.BranchID = Branch.BranchID
    AND Branch.datafileID = OLD.datafileID;

  -- Finally, delete from Branch where datafileID matches
  DELETE FROM Branch
  WHERE Branch.datafileID = OLD.datafileID;

  RETURN OLD;
END;
$$;


ALTER FUNCTION public.delete_datafile() OWNER TO postgres;

--
-- TOC entry 449 (class 1255 OID 222155)
-- Name: delete_maintenance_files(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_maintenance_files() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    file_record RECORD;
BEGIN
    FOR file_record IN SELECT datafileid FROM datafile WHERE datafilename LIKE '%(Maintenance)%'
    LOOP
        PERFORM public.deletefile(file_record.datafileid);
    END LOOP;
END;
$$;


ALTER FUNCTION public.delete_maintenance_files() OWNER TO postgres;

--
-- TOC entry 448 (class 1255 OID 197764)
-- Name: deletefile(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.deletefile(p_datafileid character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Delete from document_line
    DELETE FROM document_line
    WHERE documentid IN (
        SELECT d.documentID
        FROM document d
        JOIN branch b ON d.branchid = b.branchid
        WHERE b.datafileid = p_datafileid
    );

    -- Delete from document
    DELETE FROM document
    WHERE branchid IN (
        SELECT branchid
        FROM branch
        WHERE datafileid = p_datafileid
    );

    -- Delete from branch
    DELETE FROM branch
    WHERE datafileid = p_datafileid;

    -- Delete from datafile
    DELETE FROM datafile
    WHERE datafileid = p_datafileid;
END;
$$;


ALTER FUNCTION public.deletefile(p_datafileid character varying) OWNER TO postgres;

--
-- TOC entry 450 (class 1255 OID 191860)
-- Name: email_build(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.email_build() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec record;
    new_subject text;
    message text;
    mail_log_id int;
    processed_count int := 0; 
BEGIN
    FOR rec IN 
        SELECT datafile.datafileID, MailType.MailTypeID, DocumentID, 
               csc_number || '-' || customer_account_number as Account_Number,
               datafile.applicationid, customer_name as Name, deliverymethod,
               Document.email as toemail, fromaddress, TemplateID, 
               template.email as template, template.subject
        FROM Document
        INNER JOIN branch ON Document.branchid = branch.branchid
        INNER JOIN datafile ON datafile.datafileid = branch.datafileid
        INNER JOIN MailType ON MailType.applicationid =  datafile.applicationid
        INNER JOIN template ON template.MailTypeID = MailType.MailTypeID
        WHERE Document.email != '' AND COALESCE(Document.supress, false) = false 
              AND MailLogid IS NULL 
			  AND Document.valid = true
			  and datafile.valid = true 
              AND datafile.status IN (SELECT code FROM filestatus WHERE sendemail = true) 
              AND template.active = true
              AND lower(deliverymethod) = 'paperless'
              AND BuildActive = true
		LIMIT 1000
    LOOP
        new_subject := regexp_replace(rec.subject, '\{\{Name\}\}', rec.Name, 'i');
        new_subject := regexp_replace(new_subject, '\{\{Account_Number\}\}', rec.Account_Number, 'i');

        message := regexp_replace(rec.template, '<span[^>]*>\{\{Name\}\}<\/span>', rec.Name, 'i');
        message := regexp_replace(message, '<span[^>]*>\{\{Account_Number\}\}<\/span>', rec.Account_Number, 'i');
        message := regexp_replace(message, '\{\{Name\}\}', rec.Name, 'i');
        message := regexp_replace(message, '\{\{Account_Number\}\}', rec.Account_Number, 'i');

        INSERT INTO MailLog (ToAddress, FromAddress, Subject, Message, hash, MailTypeID, RecordID, TemplateID)
        SELECT rec.toemail, rec.fromaddress, new_subject, message, md5(message), rec.MailTypeID, rec.DocumentID, rec.TemplateID
        WHERE NOT EXISTS (
            SELECT 1 FROM MailLog WHERE RecordID = rec.DocumentID
        )
        RETURNING MailLogID INTO mail_log_id;

        IF FOUND THEN
            UPDATE Document 
            SET MailLogID = mail_log_id 
            WHERE DocumentID = rec.DocumentID AND MailLogID IS NULL;

            processed_count := processed_count + 1;
        END IF;
    END LOOP;

    RETURN processed_count;
END;
$$;


ALTER FUNCTION public.email_build() OWNER TO postgres;

--
-- TOC entry 447 (class 1255 OID 465886)
-- Name: email_campaign_build(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.email_campaign_build() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec record;
    new_subject text;
    message text;
    mail_log_id int;
    processed_count int := 0;
    email_campaign record;
    pending_count int;
BEGIN
    -- Query to retrieve the records
    FOR rec IN 
        SELECT emaildeliveriesid, MailType.MailTypeID, Name, Account_Number, 
               right(Account_Number, 4) AS Account_Number_Last4, 
               maskit(Account_Number) AS Account_Number_masked, 
               template.templateID, template.email AS template, template.subject, 
               emailaddress AS toemail, emailcampaigns.emailcampaignsid, 
               maillogid, fromaddress
        FROM emaildeliveries
        INNER JOIN emailcampaigns ON emailcampaigns.emailcampaignsid = emaildeliveries.emailcampaignsid
        INNER JOIN template ON emailcampaigns.templateID = template.templateID
        INNER JOIN mailType ON mailType.MailTypeID = template.MailTypeID
        WHERE emaildeliveries.valid = true 
          AND emaildeliveries.maillogid IS NULL
          AND emailcampaigns.valid = true 
          AND emailcampaigns.status = 'Processing'
          AND mailType.active = true
        LIMIT 1000
    LOOP
        -- Prepare the subject with replacements
        new_subject := regexp_replace(rec.subject, '\{\{Name\}\}', rec.Name, 'i');
        new_subject := regexp_replace(new_subject, '\{\{Account_Number\}\}', rec.Account_Number, 'i');
        new_subject := regexp_replace(new_subject, '\{\{Account_Number_Masked\}\}', rec.Account_Number_masked, 'i');
        new_subject := regexp_replace(new_subject, '\{\{Account_Number_Last4\}\}', rec.Account_Number_Last4, 'i');
        new_subject := regexp_replace(new_subject, '\{\{date\}\}', to_char(now(), 'YYYY-MM-DD'), 'i');
        
        -- Prepare the message template with replacements
        message := regexp_replace(rec.template, '<span[^>]*>\{\{Name\}\}<\/span>', rec.Name, 'i');
        message := regexp_replace(message, '<span[^>]*>\{\{Account_Number\}\}<\/span>', rec.Account_Number, 'i');
        message := regexp_replace(message, '<span[^>]*>\{\{Account_Number_Last4\}\}<\/span>', rec.Account_Number_Last4, 'i');
        message := regexp_replace(message, '<span[^>]*>\{\{Account_Number_Masked\}\}<\/span>', rec.Account_Number_masked, 'i');
        message := regexp_replace(message, '<span[^>]*>\{\{date\}\}<\/span>', to_char(now(), 'YYYY-MM-DD'), 'i');
        message := regexp_replace(message, '\{\{Name\}\}', rec.Name, 'i');
        message := regexp_replace(message, '\{\{Account_Number\}\}', rec.Account_Number, 'i');
        message := regexp_replace(message, '\{\{Account_Number_Last4\}\}', rec.Account_Number_Last4, 'i');
        message := regexp_replace(message, '\{\{Account_Number_Masked\}\}', rec.Account_Number_masked, 'i');
        message := regexp_replace(message, '\{\{date\}\}', to_char(now(), 'YYYY-MM-DD'), 'i');
        
        -- Insert into MailLog if not exists
        INSERT INTO MailLog (ToAddress, FromAddress, Subject, Message, hash, MailTypeID, RecordID, TemplateID)
        SELECT rec.toemail, rec.fromaddress, new_subject, message, md5(message), rec.MailTypeID, rec.emaildeliveriesid, rec.templateID
        WHERE NOT EXISTS (
            SELECT 1 FROM MailLog WHERE RecordID = rec.emaildeliveriesid
        )
        RETURNING MailLogID INTO mail_log_id;
        
        -- Update emaildeliveries with the MailLogID if insertion succeeded
        IF FOUND THEN
            UPDATE emaildeliveries 
            SET MailLogID = mail_log_id 
            WHERE emaildeliveriesid = rec.emaildeliveriesid AND MailLogID IS NULL;

            processed_count := processed_count + 1;
        END IF;
    END LOOP;

    -- Housekeeping: Check for email campaigns in 'Processing' status
    FOR email_campaign IN
        SELECT emailcampaignsid 
        FROM emailcampaigns
        WHERE status = 'Processing' AND valid = true
    LOOP
        -- Check if there are any pending records in emaildeliveries
        SELECT COUNT(*) INTO pending_count 
        FROM emaildeliveries
        WHERE emailcampaignsid = email_campaign.emailcampaignsid
          AND maillogid IS NULL;
        
        -- If no pending records, update the status of emailcampaign to 'Sent'
        IF pending_count = 0 THEN
            UPDATE emailcampaigns
            SET status = 'Sent'
            WHERE emailcampaignsid = email_campaign.emailcampaignsid;
        END IF;
    END LOOP;

    -- Return the number of processed emails
    RETURN processed_count;
END;
$$;


ALTER FUNCTION public.email_campaign_build() OWNER TO postgres;

--
-- TOC entry 435 (class 1255 OID 21952)
-- Name: format_decimal(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_decimal(p_value numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN COALESCE(
        CASE 
            WHEN p_value IS NULL THEN '0.00'
            WHEN p_value = 0 THEN '0.00'
            WHEN p_value >= 0 AND p_value < 1 THEN '0' || TO_CHAR(p_value, 'FM999,999,999,999,99,999.99')
            WHEN p_value >= 0 AND p_value < 10 THEN TO_CHAR(p_value, 'FM999,999,999,999,99,990.00')
            ELSE TO_CHAR(p_value, 'FM999,999,999,999,99,999.99')
        END,
        '0.00'
    );
END;
$$;


ALTER FUNCTION public.format_decimal(p_value numeric) OWNER TO postgres;

--
-- TOC entry 441 (class 1255 OID 172393)
-- Name: format_decimal(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_decimal(p_text text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    num_value numeric;
BEGIN
    -- Convert the input text to a numeric value, treat '' and NULL as 0
    num_value := COALESCE(NULLIF(p_text, '')::numeric, 0);

    -- Apply the same logic as in the format_decimal function
    RETURN COALESCE(
        CASE 
            WHEN num_value IS NULL THEN '0.00'
            WHEN num_value = 0 THEN '0.00'
            WHEN num_value >= 0 AND num_value < 1 THEN '0' || TO_CHAR(num_value, 'FM999,999,999,999,99,999.99')
            WHEN num_value >= 0 AND num_value < 10 THEN TO_CHAR(num_value, 'FM999,999,999,999,99,990.00')
            ELSE TO_CHAR(num_value, 'FM999,999,999,999,99,999.99')
        END,
        '0.00'
    );
END;
$$;


ALTER FUNCTION public.format_decimal(p_text text) OWNER TO postgres;

--
-- TOC entry 419 (class 1255 OID 22335)
-- Name: format_decimal_five(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_decimal_five(p_value numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN CASE 
    WHEN p_value >= 0 AND p_value < 1 THEN '0' || TO_CHAR(p_value, 'FM999,999,999,999.00000')
    ELSE TO_CHAR(p_value, 'FM999,999,999,999.00000')
  END;
END;
$$;


ALTER FUNCTION public.format_decimal_five(p_value numeric) OWNER TO postgres;

--
-- TOC entry 416 (class 1255 OID 22324)
-- Name: format_decimal_new(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_decimal_new(p_value numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN CASE 
    WHEN p_value >= 0 AND p_value < 1 THEN '0' || TO_CHAR(p_value, 'FM999,999,999,999.0000')
    ELSE TO_CHAR(p_value, 'FM999,999,999,999.0000')
  END;
END;
$$;


ALTER FUNCTION public.format_decimal_new(p_value numeric) OWNER TO postgres;

--
-- TOC entry 420 (class 1255 OID 22336)
-- Name: format_decimal_six(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_decimal_six(p_value numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN CASE 
    WHEN p_value >= 0 AND p_value < 1 THEN '0' || TO_CHAR(p_value, 'FM999,999,999,999.000000')
    ELSE TO_CHAR(p_value, 'FM999,999,999,999.000000')
  END;
END;
$$;


ALTER FUNCTION public.format_decimal_six(p_value numeric) OWNER TO postgres;

--
-- TOC entry 418 (class 1255 OID 20979)
-- Name: format_number(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_number(p_input_value integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN CASE
        WHEN ROUND(CAST(p_input_value AS DECIMAL) / 100, 2) < 1 THEN TO_CHAR(ROUND(CAST(p_input_value AS DECIMAL) / 100, 2), 'FM00.99')
        ELSE TO_CHAR(ROUND(CAST(p_input_value AS DECIMAL) / 100, 2), 'FM999,999,999.99')
    END;
END;
$$;


ALTER FUNCTION public.format_number(p_input_value integer) OWNER TO postgres;

--
-- TOC entry 415 (class 1255 OID 22964)
-- Name: format_transaction_unit(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_transaction_unit(p_value numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN CASE 
        WHEN p_value >= 0 AND p_value < 1 THEN '0' || LPAD(TO_CHAR(p_value, 'FM999,999,999,999.0000'), 8, '0')
        ELSE LPAD(TO_CHAR(p_value, 'FM999,999,999,999.0000'), 8, '0')
    END;
END;
$$;


ALTER FUNCTION public.format_transaction_unit(p_value numeric) OWNER TO postgres;

--
-- TOC entry 437 (class 1255 OID 172118)
-- Name: format_with_onedecimal(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_with_onedecimal(input_number numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check for NULL input
    IF input_number IS NULL THEN
        RETURN '0.0';
    END IF;

    -- Return the formatted output with one decimal point
    RETURN TO_CHAR(input_number / 10, 'FM999G999G990D0');
EXCEPTION WHEN OTHERS THEN
    -- In case of an error, return '0.0'
    RETURN '0.0';
END;
$$;


ALTER FUNCTION public.format_with_onedecimal(input_number numeric) OWNER TO postgres;

--
-- TOC entry 436 (class 1255 OID 172117)
-- Name: format_with_onedecimal(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_with_onedecimal(input_string text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    numeric_value NUMERIC;
BEGIN
    -- Check for NULL input or empty string
    IF input_string IS NULL OR TRIM(input_string) = '' THEN
        RETURN '0.0';
    END IF;

    -- Convert the input string to a numeric value
    numeric_value := CAST(input_string AS NUMERIC);

    -- Return the formatted output with one decimal point
    RETURN TO_CHAR(numeric_value / 10, 'FM999G999G990D0');
EXCEPTION WHEN OTHERS THEN
    -- In case of an error, return '0.0'
    RETURN '0.0';
END;
$$;


ALTER FUNCTION public.format_with_onedecimal(input_string text) OWNER TO postgres;

--
-- TOC entry 446 (class 1255 OID 188935)
-- Name: format_with_onedecimal(numeric, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_with_onedecimal(input_number numeric, original_code integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check for NULL input
    IF input_number IS NULL THEN
        RETURN '0.0';
    END IF;

    -- Check if original_Code is equal to 2
    IF original_code = 2 THEN
        -- Return the non-formatted value
        RETURN TO_CHAR(input_number, 'FM999G999G990D0');
    ELSE
        -- Return the formatted output with one decimal point
        RETURN TO_CHAR(input_number / 10, 'FM999G999G990D0');
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- In case of an error, return '0.0'
    RETURN '0.0';
END;
$$;


ALTER FUNCTION public.format_with_onedecimal(input_number numeric, original_code integer) OWNER TO postgres;

--
-- TOC entry 431 (class 1255 OID 171203)
-- Name: formatcurrancyfromstring(text); Type: FUNCTION; Schema: public; Owner: processing
--

CREATE FUNCTION public.formatcurrancyfromstring(s text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN CASE
               WHEN POSITION('$' IN s) = 0 THEN ''
               WHEN SPLIT_PART(s, '$', 2) = '0' THEN '0.00'
               ELSE TO_CHAR(CAST(SPLIT_PART(s, '$', 2) AS INTEGER) / 100.0, 'FM999,999,990.00')
           END;
END;
$_$;


ALTER FUNCTION public.formatcurrancyfromstring(s text) OWNER TO processing;

--
-- TOC entry 456 (class 1255 OID 263931)
-- Name: isnull(anyelement, anyelement); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."isnull"(value_to_check anyelement, replacement_value anyelement) RETURNS anyelement
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  RETURN COALESCE(value_to_check, replacement_value);
END;
$$;


ALTER FUNCTION public."isnull"(value_to_check anyelement, replacement_value anyelement) OWNER TO postgres;

--
-- TOC entry 417 (class 1255 OID 17697)
-- Name: json_to_xml(json); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.json_to_xml(json json) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    key TEXT;
    value JSON;
    result TEXT = '<root>';
BEGIN
    FOR key, value IN SELECT * FROM json_each(json)
    LOOP
        result := result || '<' || key || '>' || COALESCE(value::TEXT, '') || '</' || key || '>';
    END LOOP;
    result := result || '</root>';
    RETURN result;
END;
$$;


ALTER FUNCTION public.json_to_xml(json json) OWNER TO postgres;

--
-- TOC entry 459 (class 1255 OID 327703)
-- Name: maskit(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.maskit(input_value text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    input_length integer;
    masked_string text;
BEGIN
    -- Cast numeric input to text, just in case
    input_length := length(input_value);

    -- Check if the input length is less than or equal to 4
    IF input_length <= 4 THEN
        RETURN input_value;
    ELSE
        -- Construct the masked string
        masked_string := repeat('*', input_length - 4) || substr(input_value, input_length - 3, 4);
        RETURN masked_string;
    END IF;
END;
$$;


ALTER FUNCTION public.maskit(input_value text) OWNER TO postgres;

--
-- TOC entry 460 (class 1255 OID 327704)
-- Name: maskstring(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.maskstring(input_value numeric) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    -- Cast numeric to text and call the original maskString function
    RETURN maskString(input_value::text);
END;
$$;


ALTER FUNCTION public.maskstring(input_value numeric) OWNER TO postgres;

--
-- TOC entry 455 (class 1255 OID 223221)
-- Name: rearrange_rownumbers(character varying); Type: PROCEDURE; Schema: public; Owner: processing
--

CREATE PROCEDURE public.rearrange_rownumbers(IN _documentid character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE 
minrownum integer; 
maxrownum integer; 
BEGIN
    DROP TABLE IF EXISTS TMP_DOCID;
    CREATE TEMP TABLE TMP_DOCID AS SELECT * FROM document_line WHERE DOCUMENTID = _documentid;
	minrownum  := (SELECT MIN(rownumber) FROM TMP_DOCID);
	maxrownum  := (SELECT MAX(rownumber) FROM TMP_DOCID);	
	UPDATE TMP_DOCID SET ROWNUMBER = (maxrownum) - 1  WHERE RECORDTYPE = '79'; 
	UPDATE TMP_DOCID SET ROWNUMBER = ROWNUMBER - 1   WHERE RECORDTYPE NOT IN ('79') AND ROWNUMBER <> maxrownum;	 
	--DELETE FROM DOCUMENT_LINE WHERE DOCUMENTID = '0d33e8eb0c9546269269bc91e9cc1403';
	--INSERT INTO DOCUMENT_LINE SELECT * FROM DOCUMENT_LINE WHERE DOCUMENTID = _documentid;
END
$$;


ALTER PROCEDURE public.rearrange_rownumbers(IN _documentid character varying) OWNER TO processing;

--
-- TOC entry 451 (class 1255 OID 186774)
-- Name: text_decimal_format_with_zero(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.text_decimal_format_with_zero(input_text text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
    i_number NUMERIC;
    i_text TEXT;
    formatted_output TEXT;
    input_number NUMERIC;
BEGIN
    -- Check if input contains '$' and split accordingly
    IF position('$' in input_text) > 0 THEN
        i_text := split_part(input_text, '$', 1);
        i_number := NULLIF(split_part(input_text, '$', 2), '')::NUMERIC;
    ELSE
        RETURN input_text; -- Return the input text if it doesn't contain '$'
    END IF;

    BEGIN
        input_number := i_number::NUMERIC;
    EXCEPTION WHEN OTHERS THEN
        RETURN input_text;
    END;

    IF input_number IS NULL OR input_number = 0 THEN
        RETURN i_text || '$ ' || '0.00';
    END IF;

    IF input_number < 0 THEN
        IF input_number <= -100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM999G999G990D00');
        ELSE
            formatted_output := '-' || TO_CHAR(ABS(input_number) / 100, 'FM0D00');
        END IF;
    ELSE
        IF input_number < 100 THEN
            formatted_output := TO_CHAR(input_number / 100, 'FM0D00');
        ELSE
            formatted_output := TO_CHAR(input_number / 100, 'FM999G999G990D00');
        END IF;
    END IF;

    RETURN i_text || '$' || formatted_output;
EXCEPTION WHEN OTHERS THEN
    RETURN input_text;
END;
$_$;


ALTER FUNCTION public.text_decimal_format_with_zero(input_text text) OWNER TO postgres;

--
-- TOC entry 505 (class 1255 OID 495475)
-- Name: update_transaction_reference(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_transaction_reference(p_datafile_id text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_document_id text;
    v_transaction_reference TEXT;
BEGIN
    -- Cursor to loop through each document associated with the given datafile
    FOR v_document_id IN
        SELECT d.documentid
        FROM document d
        JOIN branch b ON b.branchid = d.branchid
        JOIN datafile df ON df.datafileid = b.datafileid
        WHERE df.datafileid = p_datafile_id::text 
    LOOP
        -- Get the first transaction reference from document_line for the current document
        SELECT dl.transaction_refrence
        INTO v_transaction_reference
        FROM document_line dl
        WHERE dl.documentid = v_document_id
        ORDER BY  rownumber
        LIMIT 1;

        -- Update the document's transaction_reference if it's null
        IF v_transaction_reference IS NOT NULL THEN
            UPDATE document
            SET transaction_reference = v_transaction_reference
            WHERE documentid = v_document_id
              AND transaction_reference IS NULL;
        END IF;
    END LOOP;
END;
$$;


ALTER FUNCTION public.update_transaction_reference(p_datafile_id text) OWNER TO postgres;

--
-- TOC entry 503 (class 1255 OID 495426)
-- Name: update_transaction_reference(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_transaction_reference(p_datafile_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update document.transaction_reference with the first document_line.transaction_refrence
    -- if document.transaction_reference is NULL
    UPDATE document d
    SET transaction_reference = subquery.transaction_refrence
    FROM (
        SELECT d.documentid, dl.transaction_refrence
        FROM document d
        JOIN branch b ON b.branchid = d.branchid
        JOIN datafile df ON df.datafileid = b.datafileid
        JOIN document_line dl ON dl.documentid = d.documentid
        WHERE df.datafileid = p_datafile_id::text
        ORDER BY dl.rownumber
    ) AS subquery
    WHERE d.documentid = subquery.documentid
      AND d.transaction_reference IS NULL;
END;
$$;


ALTER FUNCTION public.update_transaction_reference(p_datafile_id uuid) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 303 (class 1259 OID 16819)
-- Name: accesslog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accesslog (
    accesslogid integer NOT NULL,
    adminuserid character(32),
    ip character varying(20),
    useragent character varying(1000),
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    note character varying(50),
    type character(4)
);


ALTER TABLE public.accesslog OWNER TO postgres;

--
-- TOC entry 302 (class 1259 OID 16818)
-- Name: accesslog_accesslogid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.accesslog_accesslogid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.accesslog_accesslogid_seq OWNER TO postgres;

--
-- TOC entry 4390 (class 0 OID 0)
-- Dependencies: 302
-- Name: accesslog_accesslogid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accesslog_accesslogid_seq OWNED BY public.accesslog.accesslogid;


--
-- TOC entry 305 (class 1259 OID 16830)
-- Name: adminuser; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.adminuser (
    id integer NOT NULL,
    adminuserid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    firstname character varying(20) NOT NULL,
    lastname character varying(50),
    username character varying(20),
    roleid integer,
    email character varying(320),
    phone character varying(20),
    password character varying(500),
    salt character varying(35),
    retrycount smallint DEFAULT 0,
    unlockkey character varying(64),
    unlockmailsent timestamp without time zone,
    cookiekey character(35),
    active boolean,
    updatepassword boolean,
    expirepassword boolean,
    passwordexpredon timestamp without time zone,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    lastupdated timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    createdby character(32),
    updatedby character(32),
    verifyemailsentat timestamp without time zone,
    verifyemailretry smallint,
    emailverified timestamp without time zone,
    pagesize smallint DEFAULT 10,
    mfatype smallint,
    mfakey character varying(250),
    resetmailsent timestamp without time zone,
    valid boolean DEFAULT true,
    temppassword character varying(200),
    unlockmailcount smallint,
    resetmailcount smallint
);


ALTER TABLE public.adminuser OWNER TO postgres;

--
-- TOC entry 360 (class 1259 OID 228313)
-- Name: adminuser_application; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.adminuser_application (
    id integer NOT NULL,
    adminuserid character(32) NOT NULL,
    applicationid character(32) NOT NULL,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.adminuser_application OWNER TO postgres;

--
-- TOC entry 359 (class 1259 OID 228312)
-- Name: adminuser_application_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.adminuser_application_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.adminuser_application_id_seq OWNER TO postgres;

--
-- TOC entry 4391 (class 0 OID 0)
-- Dependencies: 359
-- Name: adminuser_application_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.adminuser_application_id_seq OWNED BY public.adminuser_application.id;


--
-- TOC entry 358 (class 1259 OID 228304)
-- Name: adminuser_csc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.adminuser_csc (
    id integer NOT NULL,
    adminuserid character(32) NOT NULL,
    csc_number character(32) NOT NULL,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.adminuser_csc OWNER TO postgres;

--
-- TOC entry 357 (class 1259 OID 228303)
-- Name: adminuser_csc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.adminuser_csc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.adminuser_csc_id_seq OWNER TO postgres;

--
-- TOC entry 4392 (class 0 OID 0)
-- Dependencies: 357
-- Name: adminuser_csc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.adminuser_csc_id_seq OWNED BY public.adminuser_csc.id;


--
-- TOC entry 304 (class 1259 OID 16829)
-- Name: adminuser_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.adminuser_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.adminuser_id_seq OWNER TO postgres;

--
-- TOC entry 4393 (class 0 OID 0)
-- Dependencies: 304
-- Name: adminuser_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.adminuser_id_seq OWNED BY public.adminuser.id;


--
-- TOC entry 307 (class 1259 OID 16846)
-- Name: adminuserauth; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.adminuserauth (
    adminuserauthid integer NOT NULL,
    adminuserid character(32) NOT NULL,
    cookiekey character(35) NOT NULL,
    enckey character(60),
    lastused timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    mobile boolean,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    valid boolean DEFAULT true
);


ALTER TABLE public.adminuserauth OWNER TO postgres;

--
-- TOC entry 306 (class 1259 OID 16845)
-- Name: adminuserauth_adminuserauthid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.adminuserauth_adminuserauthid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.adminuserauth_adminuserauthid_seq OWNER TO postgres;

--
-- TOC entry 4394 (class 0 OID 0)
-- Dependencies: 306
-- Name: adminuserauth_adminuserauthid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.adminuserauth_adminuserauthid_seq OWNED BY public.adminuserauth.adminuserauthid;


--
-- TOC entry 309 (class 1259 OID 16857)
-- Name: adminuseremailverify; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.adminuseremailverify (
    adminuseremailverifyid integer NOT NULL,
    email character varying(320),
    adminuserid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    valid boolean DEFAULT true
);


ALTER TABLE public.adminuseremailverify OWNER TO postgres;

--
-- TOC entry 308 (class 1259 OID 16856)
-- Name: adminuseremailverify_adminuseremailverifyid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.adminuseremailverify_adminuseremailverifyid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.adminuseremailverify_adminuseremailverifyid_seq OWNER TO postgres;

--
-- TOC entry 4395 (class 0 OID 0)
-- Dependencies: 308
-- Name: adminuseremailverify_adminuseremailverifyid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.adminuseremailverify_adminuseremailverifyid_seq OWNED BY public.adminuseremailverify.adminuseremailverifyid;


--
-- TOC entry 329 (class 1259 OID 17221)
-- Name: application; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.application (
    id integer NOT NULL,
    applicationid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    applicationname character varying(50) NOT NULL,
    programname character varying(50),
    autoapproval boolean,
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    enablefileapproval boolean,
    applicationgroupid character varying(32),
    printrunat character varying(8),
    printgrouping text,
    enable_enclosure boolean,
    enable_slip boolean,
    enable_onsert boolean,
    enable_banner boolean,
    wfdtemplate character varying(200),
    label_color character varying(20),
    allow_paperless boolean
);


ALTER TABLE public.application OWNER TO postgres;

--
-- TOC entry 328 (class 1259 OID 17220)
-- Name: application_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.application_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.application_id_seq OWNER TO postgres;

--
-- TOC entry 4396 (class 0 OID 0)
-- Dependencies: 328
-- Name: application_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.application_id_seq OWNED BY public.application.id;


--
-- TOC entry 352 (class 1259 OID 157740)
-- Name: applicationgroup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.applicationgroup (
    id integer NOT NULL,
    applicationgroupid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    applicationgroupname character varying(50) NOT NULL,
    estimatenumber character varying(50),
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    customerapplicationkey integer,
    maxrecordsperjob integer,
    domasticseperate boolean,
    sizeseperate boolean,
    printrunat character varying(8),
    regionseperate boolean,
    printgrouping text
);


ALTER TABLE public.applicationgroup OWNER TO postgres;

--
-- TOC entry 351 (class 1259 OID 157739)
-- Name: applicationgroup_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.applicationgroup_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.applicationgroup_id_seq OWNER TO postgres;

--
-- TOC entry 4397 (class 0 OID 0)
-- Dependencies: 351
-- Name: applicationgroup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.applicationgroup_id_seq OWNED BY public.applicationgroup.id;


--
-- TOC entry 376 (class 1259 OID 378773)
-- Name: archived; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.archived (
    id integer NOT NULL,
    archivedid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT now(),
    applicationid character varying(32),
    csc_number character varying(10),
    customer_account_number character varying(10),
    document_date date,
    previousbalance text,
    stmt_balance text,
    grand_total text,
    customer_info text,
    pdffile character varying(100),
    filename character varying(200),
    index integer,
    pdffile_found boolean,
    createadminuserid character(32),
    updateadminuserid character(32),
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    todelete boolean,
    size integer
);


ALTER TABLE public.archived OWNER TO postgres;

--
-- TOC entry 392 (class 1259 OID 718607)
-- Name: archived2_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.archived2_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER SEQUENCE public.archived2_id_seq OWNER TO postgres;

--
-- TOC entry 375 (class 1259 OID 378772)
-- Name: archived_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.archived_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.archived_id_seq OWNER TO postgres;

--
-- TOC entry 4398 (class 0 OID 0)
-- Dependencies: 375
-- Name: archived_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.archived_id_seq OWNED BY public.archived.id;


--
-- TOC entry 299 (class 1259 OID 16440)
-- Name: branch; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.branch (
    id integer NOT NULL,
    branchid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    createadminuserid character(32),
    record_code character varying(2),
    client_number character varying(6),
    project_number character varying(5),
    document_type character varying(25),
    document_date text,
    dbase character varying(4),
    document_message text,
    logo_indicator character varying(1),
    csc_number character varying(10),
    division integer DEFAULT 0,
    division_name_1 text,
    division_name_2 text,
    division_name_3 text,
    division_name_4 text,
    expanded_division_number integer DEFAULT 0,
    credit_dollar_limit numeric(11,2) DEFAULT 0,
    total_items integer DEFAULT 0,
    total_amount_billed text DEFAULT 0,
    expanded_total_amount_billed text DEFAULT 0,
    posting_code character varying(3),
    posting_code_desc_short character varying(5),
    posting_code_desc_long character varying(30),
    payment_disc_message character varying(256),
    typeid integer,
    month_bud_payment_due character varying(2),
    username character varying(16),
    report_form_name character varying(32),
    finance_charge_postcode character varying(3),
    budget_interest_postcode character varying(3),
    credit_card_message character varying(128),
    credit_card_short character varying(4),
    credit_card_no_length integer DEFAULT 0,
    credit_card_type character varying(6),
    credit_card_amount_charged numeric(12,0),
    balance_charged character varying(2),
    original_amount numeric(12,0) DEFAULT 0,
    discount_amount numeric(10,0) DEFAULT 0,
    charge_date date,
    budget_payment_amount numeric(9,2) DEFAULT 0,
    number_of_budget_payments integer DEFAULT 0,
    past_due_budget_amount numeric(9,2) DEFAULT 0,
    total_due numeric(9,2) DEFAULT 0.00,
    prepay_budget_credits numeric(9,2) DEFAULT 0.00,
    non_budget_charges numeric(9,2) DEFAULT 0,
    delivery_address_service_address character varying(60),
    document_datetime timestamp with time zone,
    status character varying(32) DEFAULT 'Pending'::character varying,
    prevstatus character varying(32) DEFAULT 'Pending'::character varying,
    datafileid character varying(32) NOT NULL,
    updateadminuserid character(32),
    rownumber integer,
    non_budget_letter_date date,
    budget_letter_date date,
    division_address_1 character varying(255),
    division_address_2 character varying(255),
    division_address_3 character varying(255),
    division_address_4 character varying(255),
    dunning_letter character varying(50),
    dunning_letter_line character varying(50),
    line_text text,
    credit_action_code_desc_short character varying(100),
    credit_action_code_desc_long text,
    expanded_division integer,
    due_date date,
    csc_phone character varying(20),
    remittance_imb character varying(32)
);


ALTER TABLE public.branch OWNER TO postgres;

--
-- TOC entry 361 (class 1259 OID 275799)
-- Name: component; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.component (
    id integer NOT NULL,
    componentid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    app_key integer,
    estimate_comp_metric_name text,
    calculation text,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT now(),
    updatedate timestamp without time zone DEFAULT now(),
    createadminuserid character(32),
    updateadminuserid character(32)
);


ALTER TABLE public.component OWNER TO postgres;

--
-- TOC entry 362 (class 1259 OID 275808)
-- Name: component_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.component_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.component_id_seq OWNER TO postgres;

--
-- TOC entry 4399 (class 0 OID 0)
-- Dependencies: 362
-- Name: component_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.component_id_seq OWNED BY public.component.id;


--
-- TOC entry 345 (class 1259 OID 24281)
-- Name: csc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.csc (
    id integer NOT NULL,
    cscid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    cscname character varying(50) NOT NULL,
    region character varying(10),
    csc_number character varying(10),
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.csc OWNER TO postgres;

--
-- TOC entry 344 (class 1259 OID 24280)
-- Name: csc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.csc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.csc_id_seq OWNER TO postgres;

--
-- TOC entry 4400 (class 0 OID 0)
-- Dependencies: 344
-- Name: csc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.csc_id_seq OWNED BY public.csc.id;


--
-- TOC entry 378 (class 1259 OID 403215)
-- Name: customerinfo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customerinfo (
    id integer NOT NULL,
    csc_number character varying(255) NOT NULL,
    customer_account_number character varying(255) NOT NULL,
    email text NOT NULL,
    not_found boolean,
    deliverymethod character varying,
    email_different boolean
);


ALTER TABLE public.customerinfo OWNER TO postgres;

--
-- TOC entry 377 (class 1259 OID 403214)
-- Name: customerinfo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customerinfo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customerinfo_id_seq OWNER TO postgres;

--
-- TOC entry 4401 (class 0 OID 0)
-- Dependencies: 377
-- Name: customerinfo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.customerinfo_id_seq OWNED BY public.customerinfo.id;


--
-- TOC entry 331 (class 1259 OID 17234)
-- Name: datafile; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datafile (
    id integer NOT NULL,
    datafileid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    datafilename character varying(50) NOT NULL,
    documentcount integer,
    applicationid character varying(32),
    maildate timestamp without time zone,
    printdate timestamp without time zone,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    status character varying(50) DEFAULT 'SentToPDFGeneration'::character varying,
    prevstatus character varying(50) DEFAULT 'SentToPDFGeneration'::character varying,
    jobnumber integer,
    filedate date,
    reviewreadyat timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    erroredat timestamp without time zone,
    pdffile character varying(300),
    suppress boolean DEFAULT false,
    autoapproved boolean,
    approvedat timestamp without time zone,
    insertprocessat timestamp without time zone,
    send_to_pending_at timestamp without time zone,
    application_at timestamp without time zone,
    copy boolean DEFAULT false
);


ALTER TABLE public.datafile OWNER TO postgres;

--
-- TOC entry 330 (class 1259 OID 17233)
-- Name: datafile_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.datafile_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.datafile_id_seq OWNER TO postgres;

--
-- TOC entry 4402 (class 0 OID 0)
-- Dependencies: 330
-- Name: datafile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.datafile_id_seq OWNED BY public.datafile.id;


--
-- TOC entry 336 (class 1259 OID 17358)
-- Name: datafilestatushistory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datafilestatushistory (
    id integer NOT NULL,
    datafilestatushistoryid uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    datafileid character(32) NOT NULL,
    adminuserid character(32) NOT NULL,
    filestatusid character(32) NOT NULL,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.datafilestatushistory OWNER TO postgres;

--
-- TOC entry 335 (class 1259 OID 17357)
-- Name: datafilestatushistory_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.datafilestatushistory_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.datafilestatushistory_id_seq OWNER TO postgres;

--
-- TOC entry 4403 (class 0 OID 0)
-- Dependencies: 335
-- Name: datafilestatushistory_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.datafilestatushistory_id_seq OWNED BY public.datafilestatushistory.id;


--
-- TOC entry 369 (class 1259 OID 366279)
-- Name: default_trans_codes; Type: TABLE; Schema: public; Owner: processing
--

CREATE TABLE public.default_trans_codes (
    trans_desc character varying(50),
    transaction_id numeric(10,0) NOT NULL
);


ALTER TABLE public.default_trans_codes OWNER TO processing;

--
-- TOC entry 346 (class 1259 OID 37377)
-- Name: delivery; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.delivery (
    id integer DEFAULT nextval('public.adminuser_id_seq'::regclass) NOT NULL,
    deliveryid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    valid boolean DEFAULT true,
    csc_number character varying(10),
    customer_account_number character varying(10),
    deliverymethod character varying(20) DEFAULT 'Print'::character varying,
    email character varying(320),
    createadminuserid character(32),
    updateadminuserid character(32),
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    apiupdated timestamp with time zone,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    importdate time without time zone
);


ALTER TABLE public.delivery OWNER TO postgres;

--
-- TOC entry 350 (class 1259 OID 92127)
-- Name: deliveryrule_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deliveryrule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER SEQUENCE public.deliveryrule_id_seq OWNER TO postgres;

--
-- TOC entry 4404 (class 0 OID 0)
-- Dependencies: 350
-- Name: deliveryrule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deliveryrule_id_seq OWNED BY public.datafile.id;


--
-- TOC entry 349 (class 1259 OID 92111)
-- Name: deliveryrule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deliveryrule (
    id integer DEFAULT nextval('public.deliveryrule_id_seq'::regclass) NOT NULL,
    deliveryruleid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    startdate date,
    enddate date,
    delivery character varying(20),
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    lockedby character(32),
    lockeddate timestamp without time zone,
    priority integer DEFAULT 0,
    mapping character varying,
    applicationid character(32),
    mappingsql character varying,
    mappingexplain character varying,
    code character varying(100)
);


ALTER TABLE public.deliveryrule OWNER TO postgres;

--
-- TOC entry 301 (class 1259 OID 16462)
-- Name: document; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.document (
    id integer NOT NULL,
    documentid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    california_indicator character varying DEFAULT false,
    recordtype smallint,
    open_item_flag character(1),
    company_code_on_forms integer,
    miscellaneous_account_flag character(10),
    statement_message_code integer,
    finance_charge_group character varying(2),
    customer_account_number character varying(10),
    division integer DEFAULT 0,
    type integer DEFAULT 0,
    customer_name character varying(50),
    customer_address_line_1 character varying(40),
    customer_address_line_2 character varying(40),
    town character varying(40),
    state character varying(10),
    zip character varying(9),
    previous_balance character varying(12),
    invoice_total character varying(12) DEFAULT 0.00,
    current_balance character varying(12),
    ocr_scan_line character varying(47),
    exempt_from_card_fee_flag character(1),
    duty_to_warn boolean DEFAULT false,
    invoice_number character varying(11),
    special_handling character varying DEFAULT false,
    direct_debit_or_credit character(1),
    expanded_account character varying(7),
    credit_time_limit character(1),
    language_flag character(1),
    expanded_previous_balance text,
    expanded_current_balance text,
    expanded_invoice_total text DEFAULT 0,
    discounted_amount text DEFAULT 0,
    expanded_division character varying(4),
    expanded_company_code character varying(4),
    viewer_id character varying(10),
    electronic_delivery_info character varying(250),
    customer_group_code_1 character varying(6),
    customer_group_code_2 character varying(6),
    grand_total text,
    branchid character(32),
    document_date date,
    pdffile character varying(100),
    budget_start_month character varying(3),
    budget_payment_amount integer DEFAULT 0,
    number_of_budget_payments integer DEFAULT 0,
    past_due_budget_amount integer,
    total_due integer DEFAULT 0,
    prepay_budget_credits integer,
    non_budget_charges integer,
    ldc character varying(4),
    document_ref character varying(9),
    previous_statement_date date,
    collector_number integer,
    pre_payment_amount integer,
    expanded_division_number integer,
    category_code character varying(4),
    service_contract_in_budget character varying(1),
    electronic_delivery_information character varying(250),
    statement_day character varying(3),
    budget_payment_eftable character varying(1),
    direct_deposit_amount integer,
    rownumber integer,
    payments_and_credits integer DEFAULT 0.00,
    new_activity integer DEFAULT 0.00,
    page_count integer,
    pdffound timestamp without time zone,
    statement_type character varying(2),
    transaction_invoice_comment character varying(100),
    record_code character varying(255),
    tank_number integer,
    product character varying(255),
    priority integer,
    master_account character varying(255),
    start_date date,
    end_date date,
    starting_gallons numeric,
    remaining_gallons numeric,
    starting_dollars numeric,
    remaining_dollars numeric,
    price_per_gallon numeric,
    plan_flag_follow_down character varying(255) DEFAULT false,
    plan_code character varying(255),
    starting_num_deliveries integer,
    remaining_num_deliveries integer,
    pre_buy_dollars_paid numeric,
    pre_buy_dollars_remaining numeric,
    filler character varying(255),
    installment_reference_number character varying(255),
    remaining_installment_amount numeric,
    transaction_date date,
    transaction_code_rec_type character varying(255),
    transaction_dollars_open_amount_on_a_keyoff_account numeric,
    original_trans_dollars_koa_including_tax_if_any numeric,
    transaction_units_gal_ltr numeric,
    transaction_unit_price numeric,
    transaction_reference character varying(255),
    detail_product_message character varying(255),
    net_days_day_of_month integer,
    keyoff_txn_flag character varying(255),
    transaction_text character varying(255),
    tax_rate_field numeric,
    card_number character varying(255),
    site_number integer,
    odometer numeric,
    vehicle_number character varying(255),
    transaction_number integer,
    hours integer,
    minutes integer,
    prior_odometer numeric,
    miles_per_gallon numeric,
    date date,
    "time" time without time zone,
    total_amount_billed numeric DEFAULT 0,
    statement_balance numeric DEFAULT 0.00,
    alternate_total_due_due numeric(10,2),
    invoice_statement_special_handling character varying(255),
    direct_debit_credit_card_ind character varying(1),
    expanded_customer_account character varying(255),
    expanded_company_code_on_forms character varying(255),
    document_viewer_id integer,
    customer_group_code1 character varying(10),
    customer_group_code2 character varying(10),
    late_charge character varying(9) DEFAULT 0.00,
    deliverymethod character varying(20) DEFAULT 'Print'::character varying,
    country character varying(30),
    delivery_time timestamp without time zone,
    usps_imb character varying(50),
    ncoa_code character varying(2),
    ncoa_customer_address_line_1 character varying(70),
    ncoa_customer_address_line_2 character varying(70),
    ncoa_town character varying(50),
    ncoa_state character varying(2),
    ncoa_zip character varying(10),
    enclosure1 character varying(10),
    enclosure2 character varying(10),
    enclosure3 character varying(10),
    enclosure4 character varying(10),
    insertprocessat time without time zone,
    onsert character varying(32),
    slip character varying(500),
    slip_insertsid character varying(32),
    enclosure_insertsid character varying(32),
    invoice_date character varying(6),
    delivery_address_state character varying(2),
    print_time time without time zone,
    maillogid integer,
    email character varying(320),
    ccf character varying(50),
    budget_account character varying(50),
    letter character varying(50),
    account_phone_number character varying(20),
    past_due_balance numeric(10,2),
    total_balance numeric(10,2),
    budget_amount_due numeric(10,2),
    total_a_r_balance numeric(10,2),
    balance_on_installment numeric(10,2),
    print_balance_option character varying(20),
    last_payment_date date,
    last_payment_amount numeric(10,2),
    credit_action_code character varying(10),
    credit_action_date date,
    signing_collector character varying(50),
    signing_collector_name character varying(100),
    signing_collector_title character varying(100),
    signing_collector_phone character varying(20),
    signing_collector_phone_extension character varying(10),
    signing_collector_email character varying(255),
    expanded_ccf text,
    expanded_town character varying(255),
    account_category character varying(50),
    expanded_database_number character varying(255),
    expanded_posting_code character varying(255),
    contract_letter text,
    contract_base_price numeric,
    contract_sub_level integer,
    contract_text text,
    expanded_customer_name character varying(255),
    expanded_customer_address_line_1 text,
    expanded_customer_address_line_2 text,
    total_tax numeric,
    total_contract_amount numeric,
    loyalty_credit_message text,
    total_messages integer,
    budget_flag boolean,
    prior_non_budgetable_charges numeric(10,2),
    budget_dollars_billed numeric(10,2),
    payments_to_date_adjustments numeric(10,2),
    total numeric(10,2),
    non_budget_charges_for_bto_accts numeric(10,2),
    status_adminid character(32),
    status_time timestamp without time zone DEFAULT now(),
    statusruleid character(32),
    print_opalsid integer,
    email_opalsid integer,
    maildate timestamp with time zone,
    csc_1654_message character varying(2000),
    account_number character varying(15),
    deliveryruleid character(32),
    highlight boolean,
    rec17_railroad_message character varying(255),
    letter_content character varying(2500),
    expanded_divison character varying(4),
    electronic_delivery character varying(250),
    supress boolean,
    letter_amount_1 character varying(18),
    letter_amount_2 character varying(20),
    letter_amount_3 character varying(20),
    letter_collector_telephone_number character varying(20),
    letter_file_date character varying(28),
    texas_railroad_message character varying(150),
    city character varying(255),
    check_date character varying(500),
    letter_collector_number character varying(20),
    customer_address_line_3 character varying(255),
    check_number character varying(20),
    letter_field_01 character varying(2500),
    letter_field_02 character varying(2500),
    letter_field_03 character varying(2500),
    letter_field_04 character varying(2500),
    letter_field_05 character varying(2500),
    letter_field_06 character varying(2500),
    letter_field_07 character varying(2500),
    letter_field_08 character varying(2500),
    letter_code character varying(2),
    credit_limit character varying(300),
    mmsupress boolean,
    suppress_reason character varying(200),
    due_date date,
    banner character(32),
    printdate date,
    banner_insertsid character varying(32),
    deliveryid character varying(32),
    domestic boolean DEFAULT true,
    print_pdf_transferat timestamp with time zone,
    foreign_domestic character varying(6),
    summary_product_message_bottom character varying(1536),
    record_22_dollars_grand_total integer,
    record_22_gallons_grand_total integer,
    reject boolean DEFAULT false,
    reject_reason character varying(100),
    onsert_page_count numeric,
    email_return_message_added timestamp without time zone,
    banner_at timestamp without time zone,
    onsert_at timestamp without time zone,
    slip_at timestamp without time zone,
    enclosure_at timestamp without time zone
);


ALTER TABLE public.document OWNER TO postgres;

--
-- TOC entry 402 (class 1259 OID 860510)
-- Name: document_creditdenied; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_creditdenied AS
 SELECT
        CASE
            WHEN (COALESCE(document.banner, ''::bpchar) = ''::bpchar) THEN ''::text
            ELSE (('\\10.180.10.87\87_d\Web\Valult\Suburban\Production\Banner\'::text || (document.banner)::text) || '.pdf'::text)
        END AS banner,
    COALESCE(branch.csc_phone, ''::character varying) AS csc_phone,
    lpad((document.customer_account_number)::text, 6, '0'::text) AS customer_account_number,
    COALESCE(document.customer_name, ''::character varying) AS customer_name,
    COALESCE(datafile.datafilename, ''::character varying) AS datafilename,
    COALESCE(branch.division_address_1, ''::character varying) AS division_address_1,
    COALESCE(branch.division_address_2, ''::character varying) AS division_address_2,
    COALESCE(branch.division_address_3, ''::character varying) AS division_address_3,
    COALESCE(branch.document_date, ''::text) AS branch_document_date,
    to_char((document.document_date)::timestamp with time zone, 'MM-DD-YYYY'::text) AS document_date,
    COALESCE(document.letter_code, ''::character varying) AS letter_code,
    COALESCE(document.letter_field_01, ''::character varying) AS letter_field_01,
    COALESCE(document.letter_field_02, ''::character varying) AS letter_field_02,
    COALESCE(document.letter_field_03, ''::character varying) AS letter_field_03,
    COALESCE(document.letter_field_04, ''::character varying) AS letter_field_04,
    COALESCE(document.letter_field_05, ''::character varying) AS letter_field_05,
    COALESCE(document.letter_field_06, ''::character varying) AS letter_field_06,
    COALESCE(document.letter_field_07, ''::character varying) AS letter_field_07,
    COALESCE(document.letter_field_08, ''::character varying) AS letter_field_08,
    COALESCE(document.letter_file_date, ''::character varying) AS letter_file_date,
    COALESCE(document.ncoa_customer_address_line_1, ''::character varying) AS ncoa_customer_address_line_1,
    COALESCE(document.ncoa_customer_address_line_2, ''::character varying) AS ncoa_customer_address_line_2,
    COALESCE(document.ncoa_state, ''::character varying) AS ncoa_state,
    COALESCE(document.ncoa_town, ''::character varying) AS ncoa_town,
    COALESCE(document.ncoa_zip, ''::character varying) AS ncoa_zip,
    COALESCE(document.onsert, ''::character varying) AS onsert,
    COALESCE(document.pdffile, ''::character varying) AS pdffile,
    COALESCE(document.usps_imb, ''::character varying) AS usps_imb,
    COALESCE(document.zip, ''::character varying) AS zip,
    branch.datafileid,
    document.id,
    datafile.status
   FROM ((public.branch
     JOIN public.document ON ((branch.branchid = document.branchid)))
     JOIN public.datafile ON ((datafile.datafileid = (branch.datafileid)::bpchar)))
  WHERE ((branch.document_type)::text = 'CCDENIED'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_creditdenied OWNER TO postgres;

--
-- TOC entry 399 (class 1259 OID 860490)
-- Name: document_dunning; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_dunning AS
 SELECT COALESCE(document.account_category, ''::character varying) AS account_category,
    concat('(', SUBSTRING(document.account_phone_number FROM 1 FOR 3), ') ', SUBSTRING(document.account_phone_number FROM 4 FOR 3), '-', SUBSTRING(document.account_phone_number FROM 7)) AS account_phone_number,
    COALESCE(branch.balance_charged, ''::character varying) AS balance_charged,
    public.decimal_format_with_zero(document.balance_on_installment) AS balance_on_installment,
        CASE
            WHEN (COALESCE(document.banner, ''::bpchar) = ''::bpchar) THEN ''::text
            ELSE (('\\10.180.10.87\87_d\Web\Valult\Suburban\Production\Banner\'::text || (document.banner)::text) || '.pdf'::text)
        END AS banner,
    COALESCE(branch.branchid, ''::bpchar) AS branchid,
    COALESCE(document.budget_account, ''::character varying) AS budget_account,
    public.decimal_format_with_zero(document.budget_amount_due) AS budget_amount_due,
    COALESCE(branch.budget_interest_postcode, ''::character varying) AS budget_interest_postcode,
    to_char((branch.budget_letter_date)::timestamp with time zone, 'MM/DD/YY'::text) AS budget_letter_date,
    public.decimal_format_with_zero((document.budget_payment_amount)::numeric) AS budget_payment_amount,
    COALESCE(document.ccf, ''::character varying) AS ccf,
    branch.charge_date,
    COALESCE(branch.client_number, ''::character varying) AS client_number,
    COALESCE(document.collector_number, 0) AS collector_number,
    COALESCE(document.company_code_on_forms, 0) AS company_code_on_forms,
    COALESCE(branch.createadminuserid, ''::bpchar) AS createadminuserid,
    branch.createdate,
    COALESCE(document.credit_action_code, ''::character varying) AS credit_action_code,
    to_char((document.credit_action_date)::timestamp with time zone, 'MM-DD-YY'::text) AS credit_action_date,
    COALESCE(branch.csc_number, ''::character varying) AS csc_number,
    public.decimal_format_with_zero((document.current_balance)::text) AS current_balance,
    lpad((document.customer_account_number)::text, 6, '0'::text) AS customer_account_number,
    COALESCE(document.customer_address_line_1, ''::character varying) AS customer_address_line_1,
    COALESCE(document.customer_address_line_2, ''::character varying) AS customer_address_line_2,
    COALESCE(document.customer_group_code_1, ''::character varying) AS customer_group_code_1,
    COALESCE(document.customer_group_code_2, ''::character varying) AS customer_group_code_2,
    COALESCE(document.customer_group_code1, ''::character varying) AS customer_group_code1,
    COALESCE(document.customer_group_code2, ''::character varying) AS customer_group_code2,
    COALESCE(document.customer_name, ''::character varying) AS customer_name,
    COALESCE(datafile.datafilename, ''::character varying) AS datafilename,
    document.date,
    COALESCE(branch.dbase, ''::character varying) AS dbase,
    COALESCE(branch.delivery_address_service_address, ''::character varying) AS delivery_address_service_address,
    COALESCE(branch.division, 0) AS branch_division,
    COALESCE(branch.division, 0) AS division,
    COALESCE(branch.division_address_1, ''::character varying) AS division_address_1,
    COALESCE(branch.division_address_2, ''::character varying) AS division_address_2,
    COALESCE(branch.division_address_3, ''::character varying) AS division_address_3,
    COALESCE(branch.division_address_4, ''::character varying) AS division_address_4,
    COALESCE(branch.division_name_1, ''::text) AS division_name_1,
    COALESCE(branch.division_name_2, ''::text) AS division_name_2,
    COALESCE(branch.document_date, ''::text) AS branch_document_date,
    to_char((document.document_date)::timestamp with time zone, 'MM-DD-YYYY'::text) AS document_date,
    branch.document_datetime,
    COALESCE(branch.document_type, ''::character varying) AS document_type,
    COALESCE(document.document_viewer_id, 0) AS document_viewer_id,
    COALESCE(branch.dunning_letter, ''::character varying) AS dunning_letter,
    COALESCE(branch.dunning_letter_line, ''::character varying) AS dunning_letter_line,
    COALESCE(document.electronic_delivery, ''::character varying) AS electronic_delivery,
    COALESCE(document.electronic_delivery_info, ''::character varying) AS electronic_delivery_info,
    COALESCE(document.expanded_ccf, ''::text) AS expanded_ccf,
    COALESCE(branch.expanded_division, 0) AS branch_expanded_division,
    COALESCE(branch.expanded_division_number, 0) AS branch_expanded_division_number,
    COALESCE(document.expanded_divison, ''::character varying) AS expanded_divison,
    COALESCE(document.expanded_town, ''::character varying) AS expanded_town,
    COALESCE(document.language_flag, ''::bpchar) AS language_flag,
    public.decimal_format_with_zero(document.last_payment_amount) AS last_payment_amount,
    to_char((document.last_payment_date)::timestamp with time zone, 'MM-DD-YY'::text) AS last_payment_date,
    COALESCE(document.letter, ''::character varying) AS letter,
    COALESCE(document.letter_amount_1, ''::character varying) AS letter_amount_1,
    COALESCE(document.letter_amount_2, ''::character varying) AS letter_amount_2,
    COALESCE(document.letter_amount_3, ''::character varying) AS letter_amount_3,
    COALESCE(document.letter_code, ''::character varying) AS letter_code,
    COALESCE(document.letter_content, ''::character varying) AS letter_content,
    COALESCE(document.letter_file_date, ''::character varying) AS letter_file_date,
    COALESCE(branch.logo_indicator, ''::character varying) AS logo_indicator,
    COALESCE(document.ncoa_code, ''::character varying) AS ncoa_code,
    COALESCE(document.ncoa_customer_address_line_1, ''::character varying) AS ncoa_customer_address_line_1,
    COALESCE(document.ncoa_customer_address_line_2, ''::character varying) AS ncoa_customer_address_line_2,
    COALESCE(document.ncoa_state, ''::character varying) AS ncoa_state,
    COALESCE(document.ncoa_town, ''::character varying) AS ncoa_town,
    COALESCE(document.ncoa_zip, ''::character varying) AS ncoa_zip,
    to_char((branch.non_budget_letter_date)::timestamp with time zone, 'MM/DD/YY'::text) AS non_budget_letter_date,
    COALESCE(document.ocr_scan_line, ''::character varying) AS ocr_scan_line,
    COALESCE(document.onsert, ''::character varying) AS onsert,
    public.decimal_format_with_zero(document.past_due_balance) AS past_due_balance,
    COALESCE(document.pdffile, ''::character varying) AS pdffile,
    COALESCE(branch.posting_code, ''::character varying) AS posting_code,
    COALESCE(document.print_balance_option, ''::character varying) AS print_balance_option,
    COALESCE(branch.project_number, ''::character varying) AS project_number,
    COALESCE(branch.record_code, ''::character varying) AS branch_record_code,
    COALESCE((document.recordtype)::integer, 0) AS recordtype,
    COALESCE(document.signing_collector, ''::character varying) AS signing_collector,
    COALESCE(document.signing_collector_email, ''::character varying) AS signing_collector_email,
    COALESCE(document.signing_collector_name, ''::character varying) AS signing_collector_name,
    concat(SUBSTRING(document.signing_collector_phone FROM 1 FOR 5), ' ', SUBSTRING(document.signing_collector_phone FROM 6)) AS signing_collector_phone,
    COALESCE(document.signing_collector_phone_extension, ''::character varying) AS signing_collector_phone_extension,
    COALESCE(document.signing_collector_title, ''::character varying) AS signing_collector_title,
    COALESCE(document.special_handling, ''::character varying) AS special_handling,
    COALESCE(document.state, ''::character varying) AS state,
    public.decimal_format_with_zero(document.total_a_r_balance) AS total_a_r_balance,
    public.decimal_format_with_zero(document.total_balance) AS total_balance,
    COALESCE(branch.total_items, 0) AS total_items,
    COALESCE(document.town, ''::character varying) AS town,
    COALESCE(document.type, 0) AS type,
    COALESCE(branch.typeid, 0) AS typeid,
    COALESCE(document.usps_imb, ''::character varying) AS usps_imb,
    COALESCE(document.zip, ''::character varying) AS zip,
    branch.datafileid,
    document.id,
    datafile.status
   FROM ((public.branch
     JOIN public.document ON ((branch.branchid = document.branchid)))
     JOIN public.datafile ON ((datafile.datafileid = (branch.datafileid)::bpchar)))
  WHERE ((branch.document_type)::text = 'DUNNING LETTER'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_dunning OWNER TO postgres;

--
-- TOC entry 298 (class 1259 OID 16439)
-- Name: document_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.branch ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.document_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 393 (class 1259 OID 860460)
-- Name: document_invoice; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_invoice AS
 SELECT COALESCE(branch.balance_charged, ''::character varying) AS balance_charged,
        CASE
            WHEN (COALESCE(document.banner, ''::bpchar) = ''::bpchar) THEN ''::text
            ELSE (('\\10.180.10.87\87_d\Web\Valult\Suburban\Production\Banner\'::text || (document.banner)::text) || '.pdf'::text)
        END AS banner,
    COALESCE(branch.budget_interest_postcode, ''::character varying) AS budget_interest_postcode,
    to_char((branch.budget_letter_date)::timestamp with time zone, 'MM/DD/YY'::text) AS budget_letter_date,
    public.decimal_format_with_zero(branch.budget_payment_amount) AS branch_budget_payment_amount,
    COALESCE(document.california_indicator, ''::character varying) AS california_indicator,
    branch.charge_date,
    COALESCE(document.company_code_on_forms, 0) AS company_code_on_forms,
    public.decimal_format_with_zero(branch.credit_card_amount_charged) AS credit_card_amount_charged,
    COALESCE(branch.credit_card_message, ''::character varying) AS credit_card_message,
    COALESCE(branch.credit_card_no_length, 0) AS credit_card_no_length,
    COALESCE(branch.credit_card_short, ''::character varying) AS credit_card_short,
    COALESCE(branch.credit_card_type, ''::character varying) AS credit_card_type,
    COALESCE(document.credit_time_limit, ''::bpchar) AS credit_time_limit,
    COALESCE(document.csc_1654_message, ''::character varying) AS csc_1654_message,
    COALESCE(branch.csc_number, ''::character varying) AS csc_number,
    public.decimal_format_with_zero((document.current_balance)::text) AS current_balance,
    lpad((document.customer_account_number)::text, 6, '0'::text) AS customer_account_number,
    COALESCE(document.customer_address_line_1, ''::character varying) AS customer_address_line_1,
    COALESCE(document.customer_address_line_2, ''::character varying) AS customer_address_line_2,
    COALESCE(document.customer_group_code_1, ''::character varying) AS customer_group_code_1,
    COALESCE(document.customer_group_code_2, ''::character varying) AS customer_group_code_2,
    COALESCE(document.customer_group_code2, ''::character varying) AS customer_group_code2,
    COALESCE(document.customer_name, ''::character varying) AS customer_name,
    COALESCE(datafile.datafilename, ''::character varying) AS datafilename,
    COALESCE(branch.dbase, ''::character varying) AS dbase,
    COALESCE(branch.delivery_address_service_address, ''::character varying) AS delivery_address_service_address,
    COALESCE(document.delivery_address_state, ''::character varying) AS delivery_address_state,
    COALESCE(document.detail_product_message, ''::character varying) AS detail_product_message,
    COALESCE(document.direct_debit_or_credit, ''::bpchar) AS direct_debit_or_credit,
    public.decimal_format_with_zero(document.discounted_amount) AS discounted_amount,
    COALESCE(branch.division, 0) AS branch_division,
    COALESCE(branch.division, 0) AS division,
    COALESCE(branch.division_name_1, ''::text) AS division_name_1,
    COALESCE(branch.division_name_2, ''::text) AS division_name_2,
    COALESCE(branch.division_name_3, ''::text) AS division_name_3,
    COALESCE(branch.division_name_4, ''::text) AS division_name_4,
    to_char((document.document_date)::timestamp with time zone, 'MM-DD-YYYY'::text) AS document_date,
    branch.document_datetime,
    COALESCE(branch.document_message, ''::text) AS document_message,
    COALESCE(branch.document_type, ''::character varying) AS document_type,
    COALESCE(document.documentid, ''::bpchar) AS documentid,
    COALESCE(document.duty_to_warn, false) AS duty_to_warn,
    COALESCE(document.electronic_delivery_info, ''::character varying) AS electronic_delivery_info,
    COALESCE(document.enclosure1, ''::character varying) AS enclosure1,
    COALESCE(document.enclosure2, ''::character varying) AS enclosure2,
    COALESCE(document.enclosure3, ''::character varying) AS enclosure3,
    COALESCE(document.enclosure4, ''::character varying) AS enclosure4,
    document.end_date,
    COALESCE(document.exempt_from_card_fee_flag, ''::bpchar) AS exempt_from_card_fee_flag,
    COALESCE(document.expanded_account, ''::character varying) AS expanded_account,
    COALESCE(document.expanded_company_code, ''::character varying) AS expanded_company_code,
    public.decimal_format_with_zero(document.expanded_current_balance) AS expanded_current_balance,
    COALESCE(document.expanded_customer_account, ''::character varying) AS expanded_customer_account,
    COALESCE(document.expanded_division, ''::character varying) AS expanded_division,
    COALESCE(branch.expanded_division_number, 0) AS branch_expanded_division_number,
    COALESCE(document.expanded_division_number, 0) AS expanded_division_number,
    public.decimal_format_with_zero(document.expanded_invoice_total) AS expanded_invoice_total,
    public.decimal_format_with_zero(document.expanded_previous_balance) AS expanded_previous_balance,
    COALESCE(branch.expanded_total_amount_billed, '0'::text) AS expanded_total_amount_billed,
    COALESCE(document.finance_charge_group, ''::character varying) AS finance_charge_group,
    COALESCE(branch.finance_charge_postcode, ''::character varying) AS finance_charge_postcode,
    public.decimal_format_with_zero(document.grand_total) AS grand_total,
    to_char((to_date((document.invoice_date)::text, 'MMDDYY'::text))::timestamp with time zone, 'MM-DD-YY'::text) AS invoice_date,
        CASE
            WHEN ((document.invoice_number)::text ~~ '9%'::text) THEN (((document.invoice_number)::text || to_char((to_date(split_part(split_part((datafile.datafilename)::text, '_'::text, 2), '_'::text, 1), 'YYMMDD'::text))::timestamp with time zone, 'MMDDYY'::text)))::character varying
            ELSE document.invoice_number
        END AS invoice_number,
    public.decimal_format_with_zero((document.invoice_total)::text) AS invoice_total,
    COALESCE(document.language_flag, ''::bpchar) AS language_flag,
    COALESCE(branch.logo_indicator, ''::character varying) AS logo_indicator,
    COALESCE(document.miscellaneous_account_flag, ''::bpchar) AS miscellaneous_account_flag,
    COALESCE(branch.month_bud_payment_due, ''::character varying) AS month_bud_payment_due,
    COALESCE(document.ncoa_customer_address_line_1, ''::character varying) AS ncoa_customer_address_line_1,
    COALESCE(document.ncoa_customer_address_line_2, ''::character varying) AS ncoa_customer_address_line_2,
    COALESCE(document.ncoa_state, ''::character varying) AS ncoa_state,
    COALESCE(document.ncoa_town, ''::character varying) AS ncoa_town,
    COALESCE(document.ncoa_zip, ''::character varying) AS ncoa_zip,
    COALESCE(document.net_days_day_of_month, 0) AS net_days_day_of_month,
    public.decimal_format_with_zero(branch.non_budget_charges) AS branch_non_budget_charges,
    COALESCE(branch.number_of_budget_payments, 0) AS branch_number_of_budget_payments,
    COALESCE(document.ocr_scan_line, ''::character varying) AS ocr_scan_line,
    COALESCE(document.onsert, ''::character varying) AS onsert,
    COALESCE(document.open_item_flag, ''::bpchar) AS open_item_flag,
    public.decimal_format_with_zero(branch.original_amount) AS original_amount,
    public.decimal_format_with_zero(branch.past_due_budget_amount) AS branch_past_due_budget_amount,
    COALESCE(branch.payment_disc_message, ''::character varying) AS payment_disc_message,
    COALESCE(document.pdffile, ''::character varying) AS pdffile,
    COALESCE(branch.posting_code, ''::character varying) AS posting_code,
    COALESCE(branch.posting_code_desc_long, ''::character varying) AS posting_code_desc_long,
    COALESCE(branch.posting_code_desc_short, ''::character varying) AS posting_code_desc_short,
    COALESCE(document.pre_buy_dollars_paid, (0)::numeric) AS pre_buy_dollars_paid,
    COALESCE(document.pre_buy_dollars_remaining, (0)::numeric) AS pre_buy_dollars_remaining,
    public.decimal_format_with_zero(branch.prepay_budget_credits) AS branch_prepay_budget_credits,
    public.decimal_format_with_zero((document.previous_balance)::text) AS previous_balance,
    COALESCE(document.price_per_gallon, (0)::numeric) AS price_per_gallon,
    COALESCE(document.print_balance_option, ''::character varying) AS print_balance_option,
    COALESCE(document.product, ''::character varying) AS product,
    COALESCE(branch.project_number, ''::character varying) AS project_number,
    COALESCE(document.rec17_railroad_message, ''::character varying) AS rec17_railroad_message,
    public.decimal_format_with_zero((document.record_22_dollars_grand_total)::numeric) AS record_22_dollars_grand_total,
    public.decimal_format_with_zero((document.record_22_gallons_grand_total)::numeric) AS record_22_gallons_grand_total,
    COALESCE(branch.record_code, ''::character varying) AS branch_record_code,
    COALESCE(branch.remittance_imb, ''::character varying) AS remittance_imb,
    COALESCE(branch.report_form_name, ''::character varying) AS report_form_name,
    COALESCE(branch.rownumber, 0) AS branch_rownumber,
    COALESCE(branch.rownumber, 0) AS rownumber,
    COALESCE(document.slip, ''::character varying) AS slip,
    COALESCE(document.special_handling, ''::character varying) AS special_handling,
    COALESCE(document.state, ''::character varying) AS state,
    COALESCE(document.statement_message_code, 0) AS statement_message_code,
    COALESCE(document.summary_product_message_bottom, ''::character varying) AS summary_product_message_bottom,
    COALESCE(document.texas_railroad_message, ''::character varying) AS texas_railroad_message,
    public.decimal_format_with_zero(branch.total_amount_billed) AS branch_total_amount_billed,
    public.decimal_format_with_zero((document.total_due)::numeric) AS total_due,
    COALESCE(document.town, ''::character varying) AS town,
    COALESCE(document.transaction_code_rec_type, ''::character varying) AS transaction_code_rec_type,
    COALESCE(document.transaction_dollars_open_amount_on_a_keyoff_account, (0)::numeric) AS transaction_dollars_open_amount_on_a_keyoff_account,
    COALESCE(document.transaction_reference, ''::character varying) AS transaction_reference,
    COALESCE(document.transaction_unit_price, (0)::numeric) AS transaction_unit_price,
    COALESCE(document.transaction_units_gal_ltr, (0)::numeric) AS transaction_units_gal_ltr,
    COALESCE(document.type, 0) AS type,
    COALESCE(branch.typeid, 0) AS typeid,
    COALESCE(branch.username, ''::character varying) AS username,
    COALESCE(document.usps_imb, ''::character varying) AS usps_imb,
    COALESCE(document.viewer_id, ''::character varying) AS viewer_id,
    COALESCE(document.zip, ''::character varying) AS zip,
    branch.datafileid,
    document.id,
    datafile.status
   FROM ((public.branch
     JOIN public.document ON ((branch.branchid = document.branchid)))
     JOIN public.datafile ON ((datafile.datafileid = (branch.datafileid)::bpchar)))
  WHERE ((branch.document_type)::text = 'INVOICE'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_invoice OWNER TO postgres;

--
-- TOC entry 404 (class 1259 OID 1095850)
-- Name: document_letters; Type: VIEW; Schema: public; Owner: processing
--

CREATE VIEW public.document_letters AS
 SELECT COALESCE(branch.balance_charged, ''::character varying) AS balance_charged,
        CASE
            WHEN (COALESCE(document.banner, ''::bpchar) = ''::bpchar) THEN ''::text
            ELSE (('\\10.180.10.87\87_d\Web\Valult\Suburban\Production\Banner\'::text || (document.banner)::text) || '.pdf'::text)
        END AS banner,
    to_char((branch.budget_letter_date)::timestamp with time zone, 'MM/DD/YY'::text) AS budget_letter_date,
    document.check_date,
    COALESCE(document.check_number, ''::character varying) AS check_number,
    COALESCE(branch.csc_number, ''::character varying) AS csc_number,
    lpad((document.customer_account_number)::text, 6, '0'::text) AS customer_account_number,
    COALESCE(document.customer_address_line_1, ''::character varying) AS customer_address_line_1,
    COALESCE(document.customer_address_line_2, ''::character varying) AS customer_address_line_2,
    COALESCE(document.customer_address_line_3, ''::character varying) AS customer_address_line_3,
    COALESCE(document.customer_name, ''::character varying) AS customer_name,
    COALESCE(datafile.datafilename, ''::character varying) AS datafilename,
    document.date,
    COALESCE(branch.division, 0) AS branch_division,
    COALESCE(branch.division_address_1, ''::character varying) AS division_address_1,
    COALESCE(branch.division_address_2, ''::character varying) AS division_address_2,
    COALESCE(branch.division_address_3, ''::character varying) AS division_address_3,
    COALESCE(branch.division_address_4, ''::character varying) AS division_address_4,
    COALESCE(branch.document_type, ''::character varying) AS document_type,
    COALESCE(document.letter_amount_1, ''::character varying) AS letter_amount_1,
    COALESCE(document.letter_amount_2, ''::character varying) AS letter_amount_2,
    COALESCE(document.letter_amount_3, ''::character varying) AS letter_amount_3,
    COALESCE(document.letter_code, ''::character varying) AS letter_code,
    COALESCE(document.letter_collector_number, ''::character varying) AS letter_collector_number,
    COALESCE(document.letter_file_date, ''::character varying) AS letter_file_date,
    COALESCE(document.ncoa_code, ''::character varying) AS ncoa_code,
    COALESCE(document.ncoa_customer_address_line_1, ''::character varying) AS ncoa_customer_address_line_1,
    COALESCE(document.ncoa_customer_address_line_2, ''::character varying) AS ncoa_customer_address_line_2,
    COALESCE(document.ncoa_state, ''::character varying) AS ncoa_state,
    COALESCE(document.ncoa_town, ''::character varying) AS ncoa_town,
    COALESCE(document.ncoa_zip, ''::character varying) AS ncoa_zip,
    to_char((branch.non_budget_letter_date)::timestamp with time zone, 'MM/DD/YY'::text) AS non_budget_letter_date,
    COALESCE(document.onsert, ''::character varying) AS onsert,
    COALESCE(document.past_due_balance, (0)::numeric) AS past_due_balance,
    COALESCE(document.pdffile, ''::character varying) AS pdffile,
    COALESCE(document.record_code, ''::character varying) AS record_code,
    COALESCE(document.state, ''::character varying) AS state,
    COALESCE(document.town, ''::character varying) AS town,
    COALESCE(document.usps_imb, ''::character varying) AS usps_imb,
    COALESCE(document.zip, ''::character varying) AS zip,
    branch.datafileid,
    document.id,
    datafile.status
   FROM ((public.branch
     JOIN public.document ON ((branch.branchid = document.branchid)))
     JOIN public.datafile ON ((datafile.datafileid = (branch.datafileid)::bpchar)))
  WHERE ((branch.document_type)::text = 'LETTERS'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_letters OWNER TO processing;

--
-- TOC entry 337 (class 1259 OID 17370)
-- Name: document_line; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.document_line (
    documentid character(32),
    address_line_1 character varying DEFAULT 0,
    address_line_2 character varying DEFAULT 0,
    address_line_3 character varying DEFAULT 0,
    address_line_4 character varying DEFAULT 0,
    transaction_date text,
    transaction_code character varying,
    transaction_dollars numeric DEFAULT 0,
    transaction_gallons numeric DEFAULT 0,
    transaction_unit_price text,
    transaction_reference character varying DEFAULT 0,
    delivery_service_address character varying,
    detail_product_message character varying DEFAULT 0,
    cylinder_quantities_delivered integer DEFAULT 0,
    cylinder_quantities_returned integer DEFAULT 0,
    purchase_order_number character varying DEFAULT 0,
    location character varying DEFAULT 0,
    due_date date,
    net_days character varying DEFAULT 0,
    transaction_comments character varying DEFAULT 0,
    tax_rate numeric DEFAULT 0,
    transaction_status character varying DEFAULT 0,
    expanded_transaction_gallons text DEFAULT 0,
    expanded_transaction_dollars text DEFAULT 0,
    transaction_unit_price_2 text DEFAULT 0,
    pre_buy_type character varying DEFAULT 0,
    california_indicator character varying DEFAULT false,
    delivery_type character varying DEFAULT 0,
    product_code character varying DEFAULT 0,
    expanded_tax_rate numeric DEFAULT 0,
    bpc character varying DEFAULT 0,
    bsl character varying DEFAULT 0,
    transaction_invoice_number character varying DEFAULT 0,
    delivery_address_bottom character varying DEFAULT 0,
    summary_product_message_bottom character varying(1536) DEFAULT 0,
    discount_date date,
    discount_amount text DEFAULT 0.00,
    previous_meter_reading_date date,
    previous_meter_reading integer DEFAULT 0,
    current_meter_reading integer DEFAULT 0,
    difference integer DEFAULT 0,
    meter_unit character varying(11) DEFAULT 0,
    meter_description character varying(12) DEFAULT 0,
    meter_type integer DEFAULT 0,
    meter_serial_number character varying(15) DEFAULT 0,
    pressure_altitude_conversion text DEFAULT 0,
    last_meter_reading_estimated boolean DEFAULT false,
    contract_reference_number character varying(15) DEFAULT 0,
    step_rates character varying(550) DEFAULT 0,
    conversion_factor text DEFAULT 0,
    meter_unit_price text DEFAULT 0,
    reformatted_previous_meter_reading text DEFAULT 0,
    reformatted_current_meter_reading text DEFAULT 0,
    reformatted_difference text DEFAULT 0,
    reformatted_conversion_factor text DEFAULT 0,
    document_lineid character varying(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    recordtype character(2),
    id integer NOT NULL,
    rownumber integer,
    sub_total integer,
    finance_charge_dollars character varying(9) DEFAULT 0,
    budget_interest_dollars character varying(9) DEFAULT 0,
    current_dollars character varying(9) DEFAULT 0,
    past_due_dollars1 character varying(9) DEFAULT 0,
    past_due_dollars2 character varying(9) DEFAULT 0,
    past_due_dollars3 character varying(9) DEFAULT 0,
    past_due_dollars4 character varying(9) DEFAULT 0,
    price_prot_gallons_remaining character varying(9) DEFAULT 0,
    dunning_message character varying(128) DEFAULT 0,
    summary_product_message_for_bottom_of_statement character varying(1536) DEFAULT 0,
    finance_charge_annual_rate character varying(4) DEFAULT 0,
    finance_charge_monthly_rate character varying(4) DEFAULT 0,
    finance_charge_avg_daily_bal integer DEFAULT 0,
    finance_charge_event_date character varying(8),
    finance_charge_due_date character varying(6) DEFAULT 0,
    late_fee_dollars character varying(9) DEFAULT 0,
    expanded_current_dollars character varying(12) DEFAULT 0,
    expanded_past_due1_dollars character varying(12) DEFAULT 0,
    expanded_past_due2_dollars character varying(12) DEFAULT 0,
    expanded_past_due3_dollars character varying(12) DEFAULT 0,
    expanded_past_due4_dollars character varying(12) DEFAULT 0,
    discounted_amount character varying(9) DEFAULT 0,
    finance_chg_budget_int_date character varying(6),
    finance_chg_budget_int_ref character varying(9) DEFAULT 0,
    transaction_code_rec_type character varying(32),
    dollars_amount_keyoff_account character varying(10) DEFAULT 0,
    transaction_refrence character varying(9) DEFAULT 0,
    delivery_address_service_address_dad_sad character varying(80) DEFAULT 0,
    transaction_was_minimum_chg character varying(1),
    original_trans_dollars_koa_including_tax_if_any character varying(9),
    net_days_day_of_month character varying(4),
    keyoff_txn_flag character varying(1) DEFAULT 0,
    eft_transaction_status character varying(1) DEFAULT 0,
    expanded_gallons_dollars character varying(10) DEFAULT 0,
    expanded_original_trans_dollars_koa character varying(10) DEFAULT 0,
    tank_number character varying(3) DEFAULT 0,
    budgetable_transaction character varying(1) DEFAULT 0,
    its_code character varying(9) DEFAULT 0,
    location_type character varying(1) DEFAULT 0,
    card_number character varying(8) DEFAULT 0,
    vehicle_id character varying(8) DEFAULT 0,
    hours character varying(2) DEFAULT 0,
    minutes character varying(2) DEFAULT 0,
    employee_id character varying(16),
    card_site character varying(8) DEFAULT 0,
    odometer character varying(8) DEFAULT 0,
    transaction_unit_price2 character varying(8) DEFAULT 0,
    late_charge character varying(9) DEFAULT 0,
    open_item_flag character varying(255) DEFAULT 0,
    ldc character varying(255) DEFAULT 0,
    document_ref character varying(255) DEFAULT 0,
    company_code_on_forms character varying(255) DEFAULT 0,
    miscellaneous_account_flag character varying(255) DEFAULT 0,
    duty_to_warn character varying(255) DEFAULT 0,
    alternate_total_due_due character varying(255) DEFAULT 0,
    invoice_statement_special_handling character varying(255) DEFAULT 0,
    statement_message_code character varying(255) DEFAULT 0,
    direct_debit_credit_card_ind character varying(255) DEFAULT 0,
    expanded_customer_account character varying(255) DEFAULT 0,
    launguage_flag character varying(255) DEFAULT 0,
    credit_dollar_limit numeric(10,2) DEFAULT 0,
    previous_statement_date date,
    collector_number integer DEFAULT 0,
    expanded_previous_balance numeric(10,2) DEFAULT 0,
    expanded_current_balance numeric(10,2) DEFAULT 0,
    pre_payment_amount numeric(10,2) DEFAULT 0,
    expanded_division_number integer DEFAULT 0,
    expanded_company_code_on_forms character varying(255) DEFAULT 0,
    document_viewer_id integer DEFAULT 0,
    category_code character varying(255) DEFAULT 0,
    service_contract_in_budget character varying(255) DEFAULT 0,
    electronic_delivery_information character varying(255) DEFAULT 0,
    finance_charge_group character varying(255) DEFAULT 0,
    statement_day integer DEFAULT 0,
    budget_payment_eftable character varying(255) DEFAULT 0,
    customer_group_code1 character varying(255) DEFAULT 0,
    customer_group_code2 character varying(255) DEFAULT 0,
    direct_deposit_amount numeric(10,2) DEFAULT 0,
    product character varying(255) DEFAULT 0,
    priority integer DEFAULT 0,
    master_account character varying(255) DEFAULT 0,
    status character varying(255) DEFAULT 0,
    start_date date,
    end_date date,
    starting_gallons numeric(10,2) DEFAULT 0,
    remaining_gallons numeric(10,2) DEFAULT 0,
    starting_dollars numeric(10,2) DEFAULT 0,
    remaining_dollars numeric(10,2),
    price_per_gallon numeric(10,2),
    plan_flag_follow_down integer DEFAULT 0,
    plan_code character varying(255),
    starting_num_deliveries integer DEFAULT 0,
    remaining_num_deliveries integer DEFAULT 0,
    pre_buy_dollars_paid numeric(10,2) DEFAULT 0,
    pre_buy_dollars_remaining numeric(10,2) DEFAULT 0,
    filler character varying(255) DEFAULT 0,
    transaction_invoice_comment text,
    installment_reference_number character varying(255) DEFAULT 0,
    remaining_installment_amount numeric(10,2) DEFAULT 0,
    transaction_dollars_open_amount_on_a_keyoff_account numeric(10,2) DEFAULT 0,
    transaction_units_gal_ltr numeric(10,2) DEFAULT 0,
    transaction_text text DEFAULT 0,
    tax_rate_field numeric(10,2) DEFAULT 0,
    site_number integer DEFAULT 0,
    vehicle_number character varying(255) DEFAULT 0,
    transaction_number integer DEFAULT 0,
    prior_odometer numeric(10,2),
    miles_per_gallon numeric(10,2) DEFAULT 0,
    delivery_address character varying(255) DEFAULT 0,
    dollars_amount_keyoff_account_2 character varying(10) DEFAULT 0,
    delivery_address_for_bottom_of_statement text DEFAULT 0,
    department_code character varying(4),
    terms_message_from_terms_file text,
    address_line_0 text,
    contract_letter text,
    contract_base_price numeric,
    contract_sub_level integer,
    contract_dollars numeric,
    contract_discount numeric,
    service_address text,
    coverage_period text,
    service_renewal_period text,
    consecutive_billing_months_remaining integer,
    consecutive_billing_total_months integer,
    contract_deviation text,
    service_location text,
    expanded_transaction_code text,
    tax_transaction_posting_code text,
    tax_amount numeric,
    expanded_tax_transaction_code text,
    expanded_card_vehicle_id numeric(10,2),
    transaction_price_gallon numeric(10,2),
    expanded_cylinder_quantities_delivered numeric(10,2),
    expanded_cylinder_quantities_returned numeric(10,2),
    transaction_sales_type numeric(10,2),
    expanded_its_product_code numeric(10,2),
    budget_current_dollars numeric(10,2),
    budget_past_due_1_dollars numeric(10,2),
    budget_past_due_2_dollars numeric(10,2),
    budget_past_due_3_dollars numeric(10,2),
    budget_past_due_4_dollars numeric(10,2),
    total numeric(10,2),
    contract_letter_message character varying(200),
    contract character varying(9),
    total_tax integer,
    total_contract_amount integer,
    total_messages integer,
    budget_flag character varying,
    original_code integer,
    csc_1654_message character varying(255),
    contract_rate_msg character varying(25),
    contract_usage_msg character varying(45),
    transaction_code_002_quantity integer,
    exception_data boolean DEFAULT false,
    minimum_charge_flag character(1) DEFAULT 'N'::bpchar
);
ALTER TABLE ONLY public.document_line ALTER COLUMN transaction_date SET STORAGE PLAIN;


ALTER TABLE public.document_line OWNER TO postgres;

--
-- TOC entry 403 (class 1259 OID 860515)
-- Name: document_line_creditdenied; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_line_creditdenied AS
 SELECT
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price_2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.minimum_charge_flag)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.minimum_charge_flag)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code,
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code_rec_type)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.original_code = 36) AND ((document_line.recordtype)::text = '22'::text)) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code_rec_type,
    branch.datafileid,
    document_line.id
   FROM ((public.document_line
     JOIN public.document ON ((document_line.documentid = document.documentid)))
     JOIN public.branch ON ((document.branchid = branch.branchid)))
  WHERE ((branch.document_type)::text = 'CCDENIED'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_line_creditdenied OWNER TO postgres;

--
-- TOC entry 400 (class 1259 OID 860495)
-- Name: document_line_dunning; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_line_dunning AS
 SELECT COALESCE(document_line.dunning_message, ''::character varying) AS dunning_message,
    COALESCE(document_line.address_line_4, ''::character varying) AS address_line_4,
    COALESCE(document_line.address_line_0, ''::text) AS address_line_0,
    COALESCE(document_line.collector_number, 0) AS collector_number,
    COALESCE(document_line.address_line_1, ''::character varying) AS address_line_1,
    COALESCE(document_line.card_number, ''::character varying) AS card_number,
    COALESCE(document_line.address_line_3, ''::character varying) AS address_line_3,
    COALESCE(document_line.address_line_2, ''::character varying) AS address_line_2,
    COALESCE(document_line.documentid, ''::bpchar) AS documentid,
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price_2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.minimum_charge_flag)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.minimum_charge_flag)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code,
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code_rec_type)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.original_code = 36) AND ((document_line.recordtype)::text = '22'::text)) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code_rec_type,
    branch.datafileid,
    document_line.id
   FROM ((public.document_line
     JOIN public.document ON ((document_line.documentid = document.documentid)))
     JOIN public.branch ON ((document.branchid = branch.branchid)))
  WHERE ((branch.document_type)::text = 'DUNNING LETTER'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_line_dunning OWNER TO postgres;

--
-- TOC entry 300 (class 1259 OID 16461)
-- Name: document_line_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.document ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.document_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 338 (class 1259 OID 17889)
-- Name: document_line_id_seq1; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.document_line ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.document_line_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 394 (class 1259 OID 860465)
-- Name: document_line_invoice; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_line_invoice AS
 SELECT COALESCE(document_line.bsl, ''::character varying) AS bsl,
    COALESCE(document_line.difference, 0) AS difference,
    to_char((document_line.previous_meter_reading_date)::timestamp with time zone, 'MM-DD-YY'::text) AS previous_meter_reading_date,
    COALESCE(document_line.rownumber, 0) AS rownumber,
    COALESCE(document_line.cylinder_quantities_returned, 0) AS cylinder_quantities_returned,
    public.decimal_format_with_zero(document_line.transaction_dollars_open_amount_on_a_keyoff_account) AS transaction_dollars_open_amount_on_a_keyoff_account,
    public.decimal_format_with_zero((document_line.dollars_amount_keyoff_account)::text) AS dollars_amount_keyoff_account,
    COALESCE(document_line.purchase_order_number, '0'::character varying) AS purchase_order_number,
    COALESCE(document_line.previous_meter_reading, 0) AS previous_meter_reading,
    COALESCE(document_line.product, ''::character varying) AS product,
    COALESCE(document_line.address_line_1, ''::character varying) AS address_line_1,
    COALESCE(document_line.pre_buy_type, ''::character varying) AS pre_buy_type,
    COALESCE(document_line.transaction_invoice_number, ''::character varying) AS transaction_invoice_number,
    COALESCE(document_line.meter_description, ''::character varying) AS meter_description,
    COALESCE(document_line.location, ''::character varying) AS location,
    public.decimal5_format_with_zero(document_line.reformatted_conversion_factor) AS reformatted_conversion_factor,
    document_line.discount_date,
    COALESCE(document_line.address_line_3, ''::character varying) AS address_line_3,
    COALESCE(document_line.transaction_comments, ''::character varying) AS transaction_comments,
    COALESCE(document_line.meter_type, 0) AS meter_type,
    COALESCE(document_line.contract_reference_number, ''::character varying) AS contract_reference_number,
    public.decimal6_format_with_zero(document_line.meter_unit_price) AS meter_unit_price,
    public.decimal_format_with_zero(((document_line.expanded_transaction_dollars)::character varying)::text) AS expanded_transaction_dollars,
    COALESCE(document_line.summary_product_message_bottom, ''::character varying) AS summary_product_message_bottom,
    COALESCE(document_line.transaction_invoice_comment, ''::text) AS transaction_invoice_comment,
    COALESCE(document_line.detail_product_message, '0'::character varying) AS detail_product_message,
    public.decimal4_format_with_zero(document_line.transaction_unit_price_2) AS transaction_unit_price_2,
    COALESCE(document_line.transaction_reference, ''::character varying) AS transaction_reference,
    to_char((to_date(document_line.transaction_date, 'YYYY-MM-DD'::text))::timestamp with time zone, 'MM-DD-YY'::text) AS transaction_date,
    public.decimal_format_without_zero_subtotal((document_line.sub_total)::numeric) AS sub_total,
    COALESCE(document_line.statement_day, 0) AS statement_day,
    COALESCE(document_line.minimum_charge_flag, ''::bpchar) AS minimum_charge_flag,
    COALESCE(document_line.recordtype, ''::bpchar) AS recordtype,
    public.decimal_format_with_zero(document_line.reformatted_previous_meter_reading) AS reformatted_previous_meter_reading,
    COALESCE(document_line.address_line_4, ''::character varying) AS address_line_4,
    public.decimal4_format_with_zero(document_line.conversion_factor) AS conversion_factor,
    COALESCE(document_line.california_indicator, ''::character varying) AS california_indicator,
    public.decimal_format_with_zero(document_line.reformatted_difference) AS reformatted_difference,
    COALESCE(document_line.delivery_address_bottom, ''::character varying) AS delivery_address_bottom,
    public.decimal4_format_with_zero(document_line.transaction_unit_price) AS transaction_unit_price,
    COALESCE(document_line.document_lineid, ''::character varying) AS document_lineid,
        CASE
            WHEN (document_line.original_code = 2) THEN (document_line.transaction_gallons)::text
            ELSE public.format_with_onedecimal(document_line.transaction_gallons)
        END AS transaction_gallons,
    COALESCE(document_line.csc_1654_message, ''::character varying) AS csc_1654_message,
    COALESCE(document_line.statement_message_code, ''::character varying) AS statement_message_code,
    public.decimal_format_with_zero(document_line.transaction_dollars) AS transaction_dollars,
    COALESCE(document_line.expanded_tax_rate, (0)::numeric) AS expanded_tax_rate,
    public.decimal_format_with_zero(document_line.reformatted_current_meter_reading) AS reformatted_current_meter_reading,
    document_line.due_date,
    COALESCE(document_line.installment_reference_number, ''::character varying) AS installment_reference_number,
    COALESCE(document_line.pre_payment_amount, (0)::numeric) AS pre_payment_amount,
    COALESCE(document_line.transaction_status, ''::character varying) AS transaction_status,
    COALESCE(document_line.discount_amount, ''::text) AS discount_amount,
    COALESCE(document_line.product_code, ''::character varying) AS product_code,
    public.decimal_format_with_zero((document_line.meter_unit)::text) AS meter_unit,
    COALESCE(document_line.cylinder_quantities_delivered, 0) AS cylinder_quantities_delivered,
    COALESCE(document_line.delivery_service_address, ''::character varying) AS delivery_service_address,
    COALESCE(document_line.meter_serial_number, ''::character varying) AS meter_serial_number,
    COALESCE(document_line.last_meter_reading_estimated, false) AS last_meter_reading_estimated,
    COALESCE(document_line.delivery_address, ''::character varying) AS delivery_address,
    COALESCE(document_line.tax_rate, (0)::numeric) AS tax_rate,
    COALESCE(document_line.original_code, 0) AS original_code,
    public.decimal4_format_with_zero(document_line.pressure_altitude_conversion) AS pressure_altitude_conversion,
    COALESCE(document_line.net_days, ''::character varying) AS net_days,
    COALESCE(document_line.address_line_2, ''::character varying) AS address_line_2,
    COALESCE(document_line.documentid, ''::bpchar) AS documentid,
    COALESCE(document_line.bpc, ''::character varying) AS bpc,
    COALESCE(document_line.step_rates, ''::character varying) AS step_rates,
    COALESCE(document_line.current_meter_reading, 0) AS current_meter_reading,
    COALESCE(document_line.delivery_type, ''::character varying) AS delivery_type,
    COALESCE(document_line.expanded_transaction_gallons, ''::text) AS expanded_transaction_gallons,
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price_2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.minimum_charge_flag)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.minimum_charge_flag)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code,
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code_rec_type)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.original_code = 36) AND ((document_line.recordtype)::text = '22'::text)) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code_rec_type,
    branch.datafileid,
    document_line.id
   FROM ((public.document_line
     JOIN public.document ON ((document_line.documentid = document.documentid)))
     JOIN public.branch ON ((document.branchid = branch.branchid)))
  WHERE ((branch.document_type)::text = 'INVOICE'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_line_invoice OWNER TO postgres;

--
-- TOC entry 401 (class 1259 OID 860505)
-- Name: document_line_letters; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_line_letters AS
 SELECT
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price_2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.minimum_charge_flag)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.minimum_charge_flag)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code,
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code_rec_type)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.original_code = 36) AND ((document_line.recordtype)::text = '22'::text)) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code_rec_type,
    branch.datafileid,
    document_line.id
   FROM ((public.document_line
     JOIN public.document ON ((document_line.documentid = document.documentid)))
     JOIN public.branch ON ((document.branchid = branch.branchid)))
  WHERE ((branch.document_type)::text = 'LETTERS'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_line_letters OWNER TO postgres;

--
-- TOC entry 398 (class 1259 OID 860485)
-- Name: document_line_rentals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_line_rentals AS
 SELECT COALESCE(document_line.expanded_transaction_gallons, ''::text) AS expanded_transaction_gallons,
    COALESCE(document_line.bsl, ''::character varying) AS bsl,
    public.text_decimal_format_with_zero((document_line.contract_rate_msg)::text) AS contract_rate_msg,
    COALESCE(document_line.difference, 0) AS difference,
    to_char((document_line.previous_meter_reading_date)::timestamp with time zone, 'MM-DD-YY'::text) AS previous_meter_reading_date,
    COALESCE(document_line.rownumber, 0) AS rownumber,
    COALESCE(document_line.coverage_period, ''::text) AS coverage_period,
    COALESCE(document_line.contract_letter_message, ''::character varying) AS contract_letter_message,
    COALESCE(document_line.cylinder_quantities_returned, 0) AS cylinder_quantities_returned,
    COALESCE(document_line.address_line_0, ''::text) AS address_line_0,
    public.decimal_format_with_zero((document_line.dollars_amount_keyoff_account)::text) AS dollars_amount_keyoff_account,
    COALESCE(document_line.invoice_statement_special_handling, ''::character varying) AS invoice_statement_special_handling,
    COALESCE(document_line.purchase_order_number, '0'::character varying) AS purchase_order_number,
    COALESCE(document_line.previous_meter_reading, 0) AS previous_meter_reading,
    COALESCE(document_line.expanded_company_code_on_forms, ''::character varying) AS expanded_company_code_on_forms,
    public.decimal_format_with_zero(document_line.tax_amount) AS tax_amount,
    COALESCE(document_line.address_line_1, ''::character varying) AS address_line_1,
    COALESCE(document_line.pre_buy_type, ''::character varying) AS pre_buy_type,
    COALESCE(document_line.expanded_tax_transaction_code, ''::text) AS expanded_tax_transaction_code,
    COALESCE(document_line.transaction_invoice_number, ''::character varying) AS transaction_invoice_number,
    COALESCE(document_line.meter_description, ''::character varying) AS meter_description,
    COALESCE(document_line.service_location, ''::text) AS service_location,
    COALESCE(document_line.location, ''::character varying) AS location,
    COALESCE(document_line.consecutive_billing_total_months, 0) AS consecutive_billing_total_months,
    public.decimal5_format_with_zero(document_line.reformatted_conversion_factor) AS reformatted_conversion_factor,
    COALESCE(document_line.service_renewal_period, ''::text) AS service_renewal_period,
    document_line.discount_date,
    COALESCE(document_line.address_line_3, ''::character varying) AS address_line_3,
    COALESCE(document_line.transaction_comments, ''::character varying) AS transaction_comments,
    COALESCE(document_line.meter_type, 0) AS meter_type,
    COALESCE(document_line.contract_reference_number, ''::character varying) AS contract_reference_number,
    COALESCE(document_line.transaction_refrence, '0'::character varying) AS transaction_refrence,
    public.decimal6_format_with_zero(document_line.meter_unit_price) AS meter_unit_price,
    COALESCE(document_line.category_code, ''::character varying) AS category_code,
    public.decimal_format_with_zero(((document_line.expanded_transaction_dollars)::character varying)::text) AS expanded_transaction_dollars,
    COALESCE(document_line.summary_product_message_bottom, ''::character varying) AS summary_product_message_bottom,
    COALESCE(document_line.detail_product_message, '0'::character varying) AS detail_product_message,
    public.decimal4_format_with_zero(document_line.transaction_unit_price_2) AS transaction_unit_price_2,
    COALESCE(document_line.transaction_reference, ''::character varying) AS transaction_reference,
    to_char((to_date(document_line.transaction_date, 'YYYY-MM-DD'::text))::timestamp with time zone, 'MM-DD-YY'::text) AS transaction_date,
    public.decimal_format_without_zero_subtotal((document_line.sub_total)::numeric) AS sub_total,
    COALESCE(document_line.minimum_charge_flag, ''::bpchar) AS minimum_charge_flag,
    COALESCE(document_line.recordtype, ''::bpchar) AS recordtype,
    public.decimal_format_with_zero(document_line.reformatted_previous_meter_reading) AS reformatted_previous_meter_reading,
    public.decimal_format_with_zero(document_line.contract_deviation) AS contract_deviation,
    COALESCE(document_line.filler, ''::character varying) AS filler,
    COALESCE(document_line.terms_message_from_terms_file, ''::text) AS terms_message_from_terms_file,
    COALESCE(document_line.address_line_4, ''::character varying) AS address_line_4,
    COALESCE(document_line.direct_debit_credit_card_ind, ''::character varying) AS direct_debit_credit_card_ind,
    public.decimal4_format_with_zero(document_line.conversion_factor) AS conversion_factor,
    public.text_decimal_format_with_zero((document_line.contract_usage_msg)::text) AS contract_usage_msg,
    COALESCE(document_line.contract_base_price, (0)::numeric) AS contract_base_price,
    COALESCE(document_line.california_indicator, ''::character varying) AS california_indicator,
    COALESCE(document_line.service_address, ''::text) AS service_address,
    public.decimal_format_with_zero(document_line.reformatted_difference) AS reformatted_difference,
    COALESCE(document_line.delivery_address_bottom, ''::character varying) AS delivery_address_bottom,
    public.decimal4_format_with_zero(document_line.transaction_unit_price) AS transaction_unit_price,
    COALESCE(document_line.document_lineid, ''::character varying) AS document_lineid,
        CASE
            WHEN (document_line.original_code = 2) THEN (document_line.transaction_gallons)::text
            ELSE public.format_with_onedecimal(document_line.transaction_gallons)
        END AS transaction_gallons,
    COALESCE(document_line.csc_1654_message, ''::character varying) AS csc_1654_message,
    COALESCE(document_line.delivery_address_service_address_dad_sad, '0'::character varying) AS delivery_address_service_address_dad_sad,
    public.decimal_format_with_zero(document_line.transaction_dollars) AS transaction_dollars,
    COALESCE(document_line.expanded_tax_rate, (0)::numeric) AS expanded_tax_rate,
    public.decimal_format_with_zero(document_line.reformatted_current_meter_reading) AS reformatted_current_meter_reading,
    document_line.due_date,
    COALESCE(document_line.transaction_status, ''::character varying) AS transaction_status,
    COALESCE(document_line.discount_amount, ''::text) AS discount_amount,
    public.decimal_format_with_zero(document_line.contract_dollars) AS contract_dollars,
    COALESCE(document_line.product_code, ''::character varying) AS product_code,
    public.decimal_format_with_zero((document_line.meter_unit)::text) AS meter_unit,
    COALESCE(document_line.contract_letter, ''::text) AS contract_letter,
    COALESCE(document_line.cylinder_quantities_delivered, 0) AS cylinder_quantities_delivered,
    COALESCE(document_line.consecutive_billing_months_remaining, 0) AS consecutive_billing_months_remaining,
    COALESCE(document_line.delivery_service_address, ''::character varying) AS delivery_service_address,
    COALESCE(document_line.meter_serial_number, ''::character varying) AS meter_serial_number,
    COALESCE(document_line.last_meter_reading_estimated, false) AS last_meter_reading_estimated,
    COALESCE(document_line.delivery_address, ''::character varying) AS delivery_address,
    COALESCE(document_line.tax_rate, (0)::numeric) AS tax_rate,
    COALESCE(document_line.original_code, 0) AS original_code,
    public.decimal4_format_with_zero(document_line.pressure_altitude_conversion) AS pressure_altitude_conversion,
    COALESCE(document_line.net_days, ''::character varying) AS net_days,
    COALESCE(document_line.address_line_2, ''::character varying) AS address_line_2,
    COALESCE(document_line.documentid, ''::bpchar) AS documentid,
    COALESCE(document_line.expanded_transaction_code, ''::text) AS expanded_transaction_code,
    TRIM(BOTH FROM SUBSTRING(document_line.tax_transaction_posting_code FROM (POSITION((' '::text) IN (document_line.tax_transaction_posting_code)) + 1))) AS tax_transaction_posting_code,
    public.decimal_format_with_zero(document_line.contract_discount) AS contract_discount,
    COALESCE(document_line.bpc, ''::character varying) AS bpc,
    COALESCE(document_line.step_rates, ''::character varying) AS step_rates,
    COALESCE(document_line.current_meter_reading, 0) AS current_meter_reading,
    COALESCE(document_line.department_code, ''::character varying) AS department_code,
    COALESCE(document_line.delivery_type, ''::character varying) AS delivery_type,
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price_2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.minimum_charge_flag)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.minimum_charge_flag)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code,
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code_rec_type)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.original_code = 36) AND ((document_line.recordtype)::text = '22'::text)) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code_rec_type,
    branch.datafileid,
    document_line.id
   FROM ((public.document_line
     JOIN public.document ON ((document_line.documentid = document.documentid)))
     JOIN public.branch ON ((document.branchid = branch.branchid)))
  WHERE ((branch.document_type)::text = 'SERVICE CONTRACT'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_line_rentals OWNER TO postgres;

--
-- TOC entry 396 (class 1259 OID 860475)
-- Name: document_line_statement; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_line_statement AS
 SELECT COALESCE(document_line.dunning_message, ''::character varying) AS dunning_message,
    COALESCE(document_line.location_type, ''::character varying) AS location_type,
    to_char((to_date((document_line.finance_charge_event_date)::text, 'MMDDYY'::text))::timestamp with time zone, 'MM-DD-YY'::text) AS finance_charge_event_date,
    to_char((document_line.previous_meter_reading_date)::timestamp with time zone, 'MM-DD-YY'::text) AS previous_meter_reading_date,
    COALESCE(to_char(((NULLIF((document_line.remaining_gallons)::text, ''::text))::numeric / (10)::numeric), 'FM999,999,999,9990.00'::text), '0.00'::text) AS remaining_gallons,
    public.decimal_format_with_zero((document_line.dollars_amount_keyoff_account)::text) AS dollars_amount_keyoff_account,
    COALESCE(document_line.tank_number, ''::character varying) AS tank_number,
    COALESCE(document_line.plan_flag_follow_down, 0) AS plan_flag_follow_down,
    COALESCE(document_line.keyoff_txn_flag, '0'::character varying) AS keyoff_txn_flag,
    COALESCE(document_line.priority, 0) AS priority,
    COALESCE(document_line.previous_meter_reading, 0) AS previous_meter_reading,
    COALESCE(document_line.product, ''::character varying) AS product,
    public.decimal_format_with_zero((document_line.expanded_past_due3_dollars)::text) AS expanded_past_due3_dollars,
    COALESCE(document_line.net_days_day_of_month, '0'::character varying) AS net_days_day_of_month,
    COALESCE(document_line.transaction_invoice_number, ''::character varying) AS transaction_invoice_number,
    COALESCE(document_line.finance_charge_due_date, ''::character varying) AS finance_charge_due_date,
    public.decimal5_format_with_zero(document_line.reformatted_conversion_factor) AS reformatted_conversion_factor,
    document_line.discount_date,
    COALESCE(document_line.starting_num_deliveries, 0) AS starting_num_deliveries,
    public.decimal_format_with_zero((document_line.past_due_dollars2)::text) AS past_due_dollars2,
    public.decimal6_format_with_zero(document_line.meter_unit_price) AS meter_unit_price,
    public.decimal_format_with_zero(document_line.starting_dollars) AS starting_dollars,
    COALESCE(document_line.transaction_invoice_comment, ''::text) AS transaction_invoice_comment,
    COALESCE(document_line.master_account, ''::character varying) AS master_account,
    public.decimal_format_with_zero((document_line.past_due_dollars3)::text) AS past_due_dollars3,
    to_char((to_date(document_line.transaction_date, 'YYYY-MM-DD'::text))::timestamp with time zone, 'MM-DD-YY'::text) AS transaction_date,
    COALESCE(document_line.hours, ''::character varying) AS hours,
    public.decimal_format_without_zero_subtotal((document_line.sub_total)::numeric) AS sub_total,
    public.format_with_onedecimal(document_line.miles_per_gallon) AS miles_per_gallon,
    COALESCE(document_line.statement_day, 0) AS statement_day,
    COALESCE(document_line.recordtype, ''::bpchar) AS recordtype,
    public.decimal_format_with_zero((document_line.expanded_current_dollars)::text) AS expanded_current_dollars,
    public.decimal_format_with_zero((document_line.current_dollars)::text) AS current_dollars,
    public.format_with_onedecimal((document_line.price_prot_gallons_remaining)::text) AS price_prot_gallons_remaining,
    COALESCE(document_line.filler, ''::character varying) AS filler,
    document_line.end_date,
    public.decimal_format_with_zero((document_line.expanded_past_due1_dollars)::text) AS expanded_past_due1_dollars,
    COALESCE(document_line.delivery_address_bottom, ''::character varying) AS delivery_address_bottom,
    public.decimal4_format_with_zero(document_line.transaction_unit_price) AS transaction_unit_price,
    COALESCE(document_line.csc_1654_message, ''::character varying) AS csc_1654_message,
    COALESCE(document_line.delivery_address_service_address_dad_sad, '0'::character varying) AS delivery_address_service_address_dad_sad,
    COALESCE(document_line.employee_id, '0'::character varying) AS employee_id,
    public.decimal_format_with_zero(document_line.remaining_installment_amount) AS remaining_installment_amount,
    public.decimal_format_with_zero(document_line.remaining_dollars) AS remaining_dollars,
    public.decimal_format_with_zero((document_line.finance_charge_monthly_rate)::text) AS finance_charge_monthly_rate,
    public.decimal_format_with_zero((document_line.expanded_original_trans_dollars_koa)::text) AS expanded_original_trans_dollars_koa,
    public.decimal_format_with_zero(document_line.reformatted_current_meter_reading) AS reformatted_current_meter_reading,
    COALESCE(document_line.vehicle_id, ''::character varying) AS vehicle_id,
    COALESCE(document_line.pre_payment_amount, (0)::numeric) AS pre_payment_amount,
    COALESCE(document_line.transaction_price_gallon, (0)::numeric) AS transaction_price_gallon,
    public.decimal_format_with_zero((document_line.past_due_dollars4)::text) AS past_due_dollars4,
    COALESCE(document_line.eft_transaction_status, '0'::character varying) AS eft_transaction_status,
    public.decimal_format_with_zero((document_line.meter_unit)::text) AS meter_unit,
    COALESCE(document_line.pre_buy_dollars_remaining, (0)::numeric) AS pre_buy_dollars_remaining,
    COALESCE(document_line.delivery_service_address, ''::character varying) AS delivery_service_address,
    public.decimal_format_with_zero((document_line.expanded_past_due2_dollars)::text) AS expanded_past_due2_dollars,
    COALESCE(document_line.tax_rate_field, (0)::numeric) AS tax_rate_field,
    to_char((to_date((document_line.finance_chg_budget_int_date)::text, 'MMDDYY'::text))::timestamp with time zone, 'MM-DD-YY'::text) AS finance_chg_budget_int_date,
    public.decimal_format_with_zero(document_line.budget_past_due_1_dollars) AS budget_past_due_1_dollars,
    COALESCE(document_line.last_meter_reading_estimated, false) AS last_meter_reading_estimated,
    COALESCE(document_line.delivery_address, ''::character varying) AS delivery_address,
    document_line.start_date,
    COALESCE(document_line.remaining_num_deliveries, 0) AS remaining_num_deliveries,
    COALESCE(document_line.finance_chg_budget_int_ref, ''::character varying) AS finance_chg_budget_int_ref,
    public.decimal_format_with_zero(document_line.budget_past_due_4_dollars) AS budget_past_due_4_dollars,
    COALESCE(document_line.documentid, ''::bpchar) AS documentid,
    COALESCE(document_line.transaction_sales_type, (0)::numeric) AS transaction_sales_type,
    COALESCE(document_line.price_per_gallon, (0)::numeric) AS price_per_gallon,
    COALESCE(document_line.expanded_cylinder_quantities_delivered, (0)::numeric) AS expanded_cylinder_quantities_delivered,
    COALESCE(document_line.transaction_text, ''::text) AS transaction_text,
    COALESCE(document_line.plan_code, ''::character varying) AS plan_code,
    COALESCE(document_line.difference, 0) AS difference,
    public.decimal_format_with_zero(document_line.budget_current_dollars) AS budget_current_dollars,
    COALESCE(document_line.rownumber, 0) AS rownumber,
    public.decimal_format_with_zero((document_line.finance_charge_dollars)::text) AS finance_charge_dollars,
    COALESCE(document_line.its_code, ''::character varying) AS its_code,
    COALESCE(document_line.vehicle_number, ''::character varying) AS vehicle_number,
    to_char(((document_line.original_trans_dollars_koa_including_tax_if_any)::numeric / (100)::numeric), 'FM9999999990.00'::text) AS original_trans_dollars_koa_including_tax_if_any,
    COALESCE(document_line.cylinder_quantities_returned, 0) AS cylinder_quantities_returned,
    public.decimal_format_with_zero((document_line.budget_interest_dollars)::text) AS budget_interest_dollars,
    public.decimal_format_with_zero(document_line.transaction_dollars_open_amount_on_a_keyoff_account) AS transaction_dollars_open_amount_on_a_keyoff_account,
    public.decimal_format_with_zero((document_line.finance_charge_annual_rate)::text) AS finance_charge_annual_rate,
    COALESCE(document_line.purchase_order_number, '0'::character varying) AS purchase_order_number,
    public.decimal_format_with_zero(document_line.budget_past_due_3_dollars) AS budget_past_due_3_dollars,
    COALESCE(document_line.summary_product_message_for_bottom_of_statement, ''::character varying) AS summary_product_message_for_bottom_of_statement,
    public.decimal_format_with_zero((document_line.past_due_dollars1)::text) AS past_due_dollars1,
    COALESCE(document_line.pre_buy_type, ''::character varying) AS pre_buy_type,
    COALESCE(document_line.transaction_number, 0) AS transaction_number,
    COALESCE(document_line.meter_description, ''::character varying) AS meter_description,
    COALESCE(document_line.prior_odometer, (0)::numeric) AS prior_odometer,
    public.decimal_format_with_zero((document_line.late_fee_dollars)::text) AS late_fee_dollars,
    COALESCE(document_line.meter_type, 0) AS meter_type,
    public.decimal_format_with_zero(document_line.transaction_units_gal_ltr) AS transaction_units_gal_ltr,
    COALESCE(document_line.contract_reference_number, ''::character varying) AS contract_reference_number,
    COALESCE(document_line.card_site, ''::character varying) AS card_site,
    COALESCE(document_line.transaction_refrence, '0'::character varying) AS transaction_refrence,
    public.decimal_format_with_zero(((document_line.expanded_transaction_dollars)::character varying)::text) AS expanded_transaction_dollars,
    COALESCE(document_line.detail_product_message, '0'::character varying) AS detail_product_message,
    COALESCE(document_line.expanded_its_product_code, (0)::numeric) AS expanded_its_product_code,
    public.decimal4_format_with_zero(document_line.transaction_unit_price_2) AS transaction_unit_price_2,
    COALESCE(document_line.total, (0)::numeric) AS total,
    COALESCE(document_line.transaction_reference, ''::character varying) AS transaction_reference,
    COALESCE(document_line.minimum_charge_flag, ''::bpchar) AS minimum_charge_flag,
    COALESCE(document_line.budgetable_transaction, ''::character varying) AS budgetable_transaction,
    public.decimal_format_with_zero(document_line.reformatted_previous_meter_reading) AS reformatted_previous_meter_reading,
    public.decimal4_format_with_zero((document_line.transaction_unit_price2)::text) AS transaction_unit_price2,
    COALESCE(document_line.discounted_amount, ''::character varying) AS discounted_amount,
    public.decimal4_format_with_zero(document_line.conversion_factor) AS conversion_factor,
    public.decimal_format_with_zero((document_line.late_charge)::text) AS late_charge,
    COALESCE(document_line.california_indicator, ''::character varying) AS california_indicator,
    public.decimal_format_with_zero(document_line.reformatted_difference) AS reformatted_difference,
    COALESCE(document_line.expanded_cylinder_quantities_returned, (0)::numeric) AS expanded_cylinder_quantities_returned,
        CASE
            WHEN (document_line.original_code = 2) THEN (document_line.transaction_gallons)::text
            ELSE public.format_with_onedecimal(document_line.transaction_gallons)
        END AS transaction_gallons,
    COALESCE(document_line.statement_message_code, ''::character varying) AS statement_message_code,
    COALESCE(document_line.delivery_address_for_bottom_of_statement, ''::text) AS delivery_address_for_bottom_of_statement,
    document_line.due_date,
    COALESCE(document_line.installment_reference_number, ''::character varying) AS installment_reference_number,
    COALESCE(document_line.discount_amount, ''::text) AS discount_amount,
    COALESCE(document_line.pre_buy_dollars_paid, (0)::numeric) AS pre_buy_dollars_paid,
    COALESCE(document_line.site_number, 0) AS site_number,
    COALESCE(document_line.expanded_card_vehicle_id, (0)::numeric) AS expanded_card_vehicle_id,
    COALESCE(document_line.cylinder_quantities_delivered, 0) AS cylinder_quantities_delivered,
    COALESCE(document_line.transaction_was_minimum_chg, '0'::character varying) AS transaction_was_minimum_chg,
    COALESCE(document_line.odometer, ''::character varying) AS odometer,
    COALESCE(document_line.card_number, ''::character varying) AS card_number,
    public.decimal_format_with_zero((document_line.expanded_past_due4_dollars)::text) AS expanded_past_due4_dollars,
    COALESCE(document_line.minutes, ''::character varying) AS minutes,
    COALESCE(document_line.meter_serial_number, ''::character varying) AS meter_serial_number,
    public.decimal_format_with_zero((document_line.expanded_gallons_dollars)::text) AS expanded_gallons_dollars,
    COALESCE(document_line.original_code, 0) AS original_code,
    public.decimal4_format_with_zero(document_line.pressure_altitude_conversion) AS pressure_altitude_conversion,
    COALESCE(to_char(((NULLIF((document_line.starting_gallons)::text, ''::text))::numeric / (10)::numeric), 'FM999,999,999,9990.00'::text), '0.00'::text) AS starting_gallons,
    COALESCE(document_line.status, ''::character varying) AS status,
    COALESCE(document_line.step_rates, ''::character varying) AS step_rates,
    COALESCE(document_line.current_meter_reading, 0) AS current_meter_reading,
    public.decimal_format_with_zero((document_line.finance_charge_avg_daily_bal)::numeric) AS finance_charge_avg_daily_bal,
    COALESCE(document_line.delivery_type, ''::character varying) AS delivery_type,
    public.decimal_format_with_zero(document_line.budget_past_due_2_dollars) AS budget_past_due_2_dollars,
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price_2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.minimum_charge_flag)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.minimum_charge_flag)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code,
        CASE
            WHEN (document_line.original_code = 2) THEN (((document_line.transaction_code_rec_type)::text || ' @ '::text) || to_char(((document_line.transaction_unit_price2)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            WHEN ((document_line.original_code = 36) AND ((document_line.recordtype)::text = '22'::text)) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
            WHEN ((document_line.transaction_unit_price)::numeric > (0)::numeric) THEN
            CASE
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (lower((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['true'::text, 'y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.recordtype = '12'::bpchar) AND (upper((document_line.transaction_was_minimum_chg)::text) = ANY (ARRAY['TRUE'::text, 'Y'::text]))) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                WHEN ((document_line.transaction_code_rec_type)::text ~~ '%PROPANE-AIR METER%'::text) THEN regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
                ELSE concat(regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text), ' PRICE PER GALLON ', to_char(((document_line.transaction_unit_price)::numeric / (10000)::numeric), 'FM999999.0000'::text))
            END
            ELSE regexp_replace((document_line.transaction_code_rec_type)::text, 'TX-[0-9]+'::text, '    '::text)
        END AS transaction_code_rec_type,
    branch.datafileid,
    document_line.id
   FROM ((public.document_line
     JOIN public.document ON ((document_line.documentid = document.documentid)))
     JOIN public.branch ON ((document.branchid = branch.branchid)))
  WHERE ((branch.document_type)::text = 'STATEMENT'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_line_statement OWNER TO postgres;

--
-- TOC entry 397 (class 1259 OID 860480)
-- Name: document_rentals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_rentals AS
 SELECT COALESCE(document.account_category, ''::character varying) AS account_category,
    concat('(', SUBSTRING(document.account_phone_number FROM 1 FOR 3), ') ', SUBSTRING(document.account_phone_number FROM 4 FOR 3), '-', SUBSTRING(document.account_phone_number FROM 7)) AS account_phone_number,
    COALESCE(branch.balance_charged, ''::character varying) AS balance_charged,
    public.decimal_format_with_zero(document.balance_on_installment) AS balance_on_installment,
        CASE
            WHEN (COALESCE(document.banner, ''::bpchar) = ''::bpchar) THEN ''::text
            ELSE (('\\10.180.10.87\87_d\Web\Valult\Suburban\Production\Banner\'::text || (document.banner)::text) || '.pdf'::text)
        END AS banner,
    COALESCE(document.budget_account, ''::character varying) AS budget_account,
    public.decimal_format_with_zero(document.budget_amount_due) AS budget_amount_due,
    COALESCE(document.budget_flag, false) AS budget_flag,
    COALESCE(branch.budget_interest_postcode, ''::character varying) AS budget_interest_postcode,
    to_char((branch.budget_letter_date)::timestamp with time zone, 'MM/DD/YY'::text) AS budget_letter_date,
    public.decimal_format_with_zero((document.budget_payment_amount)::numeric) AS budget_payment_amount,
    COALESCE(document.california_indicator, ''::character varying) AS california_indicator,
    COALESCE(document.category_code, ''::character varying) AS category_code,
    COALESCE(document.ccf, ''::character varying) AS ccf,
    branch.charge_date,
    COALESCE(branch.client_number, ''::character varying) AS client_number,
    COALESCE(document.company_code_on_forms, 0) AS company_code_on_forms,
    COALESCE(document.contract_base_price, (0)::numeric) AS contract_base_price,
    COALESCE(document.contract_letter, ''::text) AS contract_letter,
    COALESCE(document.contract_sub_level, 0) AS contract_sub_level,
    COALESCE(document.contract_text, ''::text) AS contract_text,
    COALESCE(document.credit_action_code, ''::character varying) AS credit_action_code,
    to_char((document.credit_action_date)::timestamp with time zone, 'MM-DD-YY'::text) AS credit_action_date,
    public.decimal_format_with_zero(branch.credit_card_amount_charged) AS credit_card_amount_charged,
    COALESCE(branch.credit_card_message, ''::character varying) AS credit_card_message,
    COALESCE(branch.credit_card_no_length, 0) AS credit_card_no_length,
    COALESCE(branch.credit_card_short, ''::character varying) AS credit_card_short,
    COALESCE(branch.credit_card_type, ''::character varying) AS credit_card_type,
    COALESCE(document.credit_time_limit, ''::bpchar) AS credit_time_limit,
    COALESCE(document.csc_1654_message, ''::character varying) AS csc_1654_message,
    COALESCE(branch.csc_number, ''::character varying) AS csc_number,
    public.decimal_format_with_zero((document.current_balance)::text) AS current_balance,
    lpad((document.customer_account_number)::text, 6, '0'::text) AS customer_account_number,
    COALESCE(document.customer_address_line_1, ''::character varying) AS customer_address_line_1,
    COALESCE(document.customer_address_line_2, ''::character varying) AS customer_address_line_2,
    COALESCE(document.customer_group_code_1, ''::character varying) AS customer_group_code_1,
    COALESCE(document.customer_group_code_2, ''::character varying) AS customer_group_code_2,
    COALESCE(document.customer_group_code2, ''::character varying) AS customer_group_code2,
    COALESCE(document.customer_name, ''::character varying) AS customer_name,
    COALESCE(datafile.datafilename, ''::character varying) AS datafilename,
    document.date,
    COALESCE(branch.dbase, ''::character varying) AS dbase,
    COALESCE(branch.delivery_address_service_address, ''::character varying) AS delivery_address_service_address,
    COALESCE(document.direct_debit_credit_card_ind, ''::character varying) AS direct_debit_credit_card_ind,
    COALESCE(document.direct_debit_or_credit, ''::bpchar) AS direct_debit_or_credit,
    public.decimal_format_with_zero(document.discounted_amount) AS discounted_amount,
    COALESCE(branch.division, 0) AS branch_division,
    COALESCE(branch.division, 0) AS division,
    COALESCE(branch.division_address_1, ''::character varying) AS division_address_1,
    COALESCE(branch.division_address_2, ''::character varying) AS division_address_2,
    COALESCE(branch.division_address_3, ''::character varying) AS division_address_3,
    COALESCE(branch.division_address_4, ''::character varying) AS division_address_4,
    COALESCE(branch.division_name_1, ''::text) AS division_name_1,
    COALESCE(branch.division_name_2, ''::text) AS division_name_2,
    COALESCE(branch.division_name_3, ''::text) AS division_name_3,
    COALESCE(branch.division_name_4, ''::text) AS division_name_4,
    COALESCE(branch.document_date, ''::text) AS branch_document_date,
    to_char((document.document_date)::timestamp with time zone, 'MM-DD-YYYY'::text) AS document_date,
    branch.document_datetime,
    COALESCE(branch.document_message, ''::text) AS document_message,
    COALESCE(document.document_ref, ''::character varying) AS document_ref,
    COALESCE(branch.document_type, ''::character varying) AS document_type,
    COALESCE(document.document_viewer_id, 0) AS document_viewer_id,
    COALESCE(document.documentid, ''::bpchar) AS documentid,
    COALESCE(document.duty_to_warn, false) AS duty_to_warn,
    COALESCE(document.electronic_delivery, ''::character varying) AS electronic_delivery,
    COALESCE(document.electronic_delivery_info, ''::character varying) AS electronic_delivery_info,
    COALESCE(document.enclosure1, ''::character varying) AS enclosure1,
    COALESCE(document.enclosure2, ''::character varying) AS enclosure2,
    COALESCE(document.enclosure3, ''::character varying) AS enclosure3,
    COALESCE(document.enclosure4, ''::character varying) AS enclosure4,
    document.end_date,
    COALESCE(document.exempt_from_card_fee_flag, ''::bpchar) AS exempt_from_card_fee_flag,
    COALESCE(document.expanded_account, ''::character varying) AS expanded_account,
    COALESCE(document.expanded_ccf, ''::text) AS expanded_ccf,
    COALESCE(document.expanded_company_code, ''::character varying) AS expanded_company_code,
    COALESCE(document.expanded_company_code_on_forms, ''::character varying) AS expanded_company_code_on_forms,
    public.decimal_format_with_zero(document.expanded_current_balance) AS expanded_current_balance,
    COALESCE(document.expanded_customer_account, ''::character varying) AS expanded_customer_account,
    COALESCE(document.expanded_customer_address_line_1, ''::text) AS expanded_customer_address_line_1,
    COALESCE(document.expanded_customer_address_line_2, ''::text) AS expanded_customer_address_line_2,
    COALESCE(document.expanded_customer_name, ''::character varying) AS expanded_customer_name,
    COALESCE(document.expanded_database_number, ''::character varying) AS expanded_database_number,
    COALESCE(branch.expanded_division, 0) AS branch_expanded_division,
    COALESCE(document.expanded_division, ''::character varying) AS expanded_division,
    COALESCE(branch.expanded_division_number, 0) AS branch_expanded_division_number,
    COALESCE(document.expanded_division_number, 0) AS expanded_division_number,
    COALESCE(document.expanded_divison, ''::character varying) AS expanded_divison,
    COALESCE(document.expanded_posting_code, ''::character varying) AS expanded_posting_code,
    public.decimal_format_with_zero(document.expanded_previous_balance) AS expanded_previous_balance,
    COALESCE(branch.expanded_total_amount_billed, '0'::text) AS expanded_total_amount_billed,
    COALESCE(document.expanded_town, ''::character varying) AS expanded_town,
    COALESCE(document.filler, ''::character varying) AS filler,
    COALESCE(document.finance_charge_group, ''::character varying) AS finance_charge_group,
    COALESCE(branch.finance_charge_postcode, ''::character varying) AS finance_charge_postcode,
    public.decimal_format_with_zero(document.grand_total) AS grand_total,
    to_char((to_date((document.invoice_date)::text, 'MMDDYY'::text))::timestamp with time zone, 'MM-DD-YY'::text) AS invoice_date,
        CASE
            WHEN ((document.invoice_number)::text ~~ '9%'::text) THEN (((document.invoice_number)::text || to_char((to_date(split_part(split_part((datafile.datafilename)::text, '_'::text, 2), '_'::text, 1), 'YYMMDD'::text))::timestamp with time zone, 'MMDDYY'::text)))::character varying
            ELSE document.invoice_number
        END AS invoice_number,
    COALESCE(document.invoice_statement_special_handling, ''::character varying) AS invoice_statement_special_handling,
    COALESCE(document.language_flag, ''::bpchar) AS language_flag,
    public.decimal_format_with_zero(document.last_payment_amount) AS last_payment_amount,
    to_char((document.last_payment_date)::timestamp with time zone, 'MM-DD-YY'::text) AS last_payment_date,
    COALESCE(document.letter_content, ''::character varying) AS letter_content,
    COALESCE(branch.logo_indicator, ''::character varying) AS logo_indicator,
    COALESCE(document.loyalty_credit_message, ''::text) AS loyalty_credit_message,
    COALESCE(document.miscellaneous_account_flag, ''::bpchar) AS miscellaneous_account_flag,
    COALESCE(branch.month_bud_payment_due, ''::character varying) AS month_bud_payment_due,
    COALESCE(document.ncoa_code, ''::character varying) AS ncoa_code,
    COALESCE(document.ncoa_customer_address_line_1, ''::character varying) AS ncoa_customer_address_line_1,
    COALESCE(document.ncoa_customer_address_line_2, ''::character varying) AS ncoa_customer_address_line_2,
    COALESCE(document.ncoa_state, ''::character varying) AS ncoa_state,
    COALESCE(document.ncoa_town, ''::character varying) AS ncoa_town,
    COALESCE(document.ncoa_zip, ''::character varying) AS ncoa_zip,
    public.decimal_format_with_zero(branch.non_budget_charges) AS branch_non_budget_charges,
    COALESCE(branch.number_of_budget_payments, 0) AS branch_number_of_budget_payments,
    COALESCE(document.ocr_scan_line, ''::character varying) AS ocr_scan_line,
    COALESCE(document.onsert, ''::character varying) AS onsert,
    COALESCE(document.open_item_flag, ''::bpchar) AS open_item_flag,
    public.decimal_format_with_zero(branch.original_amount) AS original_amount,
    public.decimal_format_with_zero(document.past_due_balance) AS past_due_balance,
    public.decimal_format_with_zero(branch.past_due_budget_amount) AS branch_past_due_budget_amount,
    COALESCE(branch.payment_disc_message, ''::character varying) AS payment_disc_message,
    COALESCE(document.pdffile, ''::character varying) AS pdffile,
    COALESCE(branch.posting_code, ''::character varying) AS posting_code,
    COALESCE(branch.posting_code_desc_long, ''::character varying) AS posting_code_desc_long,
    COALESCE(branch.posting_code_desc_short, ''::character varying) AS posting_code_desc_short,
    public.decimal_format_with_zero(branch.prepay_budget_credits) AS branch_prepay_budget_credits,
    public.decimal_format_with_zero((document.previous_balance)::text) AS previous_balance,
    COALESCE(document.print_balance_option, ''::character varying) AS print_balance_option,
    COALESCE(branch.project_number, ''::character varying) AS project_number,
    COALESCE(document.rec17_railroad_message, ''::character varying) AS rec17_railroad_message,
    COALESCE(branch.record_code, ''::character varying) AS branch_record_code,
    COALESCE((document.recordtype)::integer, 0) AS recordtype,
    COALESCE(branch.remittance_imb, ''::character varying) AS remittance_imb,
    COALESCE(branch.report_form_name, ''::character varying) AS report_form_name,
    COALESCE(branch.rownumber, 0) AS branch_rownumber,
    COALESCE(branch.rownumber, 0) AS rownumber,
    COALESCE(document.signing_collector, ''::character varying) AS signing_collector,
    COALESCE(document.signing_collector_email, ''::character varying) AS signing_collector_email,
    COALESCE(document.signing_collector_name, ''::character varying) AS signing_collector_name,
    concat(SUBSTRING(document.signing_collector_phone FROM 1 FOR 5), ' ', SUBSTRING(document.signing_collector_phone FROM 6)) AS signing_collector_phone,
    COALESCE(document.signing_collector_phone_extension, ''::character varying) AS signing_collector_phone_extension,
    COALESCE(document.signing_collector_title, ''::character varying) AS signing_collector_title,
    COALESCE(document.slip, ''::character varying) AS slip,
    COALESCE(document.special_handling, ''::character varying) AS special_handling,
    COALESCE(document.state, ''::character varying) AS state,
    COALESCE(document.statement_message_code, 0) AS statement_message_code,
    document."time",
    public.decimal_format_with_zero(document.total_a_r_balance) AS total_a_r_balance,
    public.decimal_format_with_zero(branch.total_amount_billed) AS branch_total_amount_billed,
    COALESCE(to_char(((branch.total_amount_billed)::numeric / 100.00), '0.00'::text), '0.00'::text) AS total_amount_billed,
    public.decimal_format_with_zero(document.total_balance) AS total_balance,
    public.decimal_format_with_zero(document.total_contract_amount) AS total_contract_amount,
    COALESCE(branch.total_due, (0)::numeric) AS branch_total_due,
    public.decimal_format_with_zero((document.total_due)::numeric) AS total_due,
    COALESCE(branch.total_items, 0) AS total_items,
    COALESCE(document.total_messages, 0) AS total_messages,
    public.decimal_format_with_zero(document.total_tax) AS total_tax,
    COALESCE(document.town, ''::character varying) AS town,
    document.transaction_date,
    COALESCE(document.type, 0) AS type,
    COALESCE(branch.typeid, 0) AS typeid,
    COALESCE(branch.username, ''::character varying) AS username,
    COALESCE(document.usps_imb, ''::character varying) AS usps_imb,
    COALESCE(document.viewer_id, ''::character varying) AS viewer_id,
    COALESCE(document.zip, ''::character varying) AS zip,
    branch.datafileid,
    document.id,
    datafile.status
   FROM ((public.branch
     JOIN public.document ON ((branch.branchid = document.branchid)))
     JOIN public.datafile ON ((datafile.datafileid = (branch.datafileid)::bpchar)))
  WHERE ((branch.document_type)::text = 'SERVICE CONTRACT'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_rentals OWNER TO postgres;

--
-- TOC entry 395 (class 1259 OID 860470)
-- Name: document_statement; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.document_statement AS
 SELECT COALESCE(branch.balance_charged, ''::character varying) AS balance_charged,
        CASE
            WHEN (COALESCE(document.banner, ''::bpchar) = ''::bpchar) THEN ''::text
            ELSE (('\\10.180.10.87\87_d\Web\Valult\Suburban\Production\Banner\'::text || (document.banner)::text) || '.pdf'::text)
        END AS banner,
    COALESCE(document.budget_dollars_billed, (0)::numeric) AS budget_dollars_billed,
    to_char((branch.budget_letter_date)::timestamp with time zone, 'MM/DD/YY'::text) AS budget_letter_date,
    public.decimal_format_with_zero((document.budget_payment_amount)::numeric) AS budget_payment_amount,
    COALESCE(document.budget_payment_eftable, ''::character varying) AS budget_payment_eftable,
    COALESCE(document.budget_start_month, ''::character varying) AS budget_start_month,
    COALESCE(document.california_indicator, ''::character varying) AS california_indicator,
    COALESCE(document.category_code, ''::character varying) AS category_code,
    COALESCE(branch.client_number, ''::character varying) AS client_number,
    COALESCE(document.collector_number, 0) AS collector_number,
    COALESCE(document.company_code_on_forms, 0) AS company_code_on_forms,
    COALESCE(branch.credit_card_message, ''::character varying) AS credit_card_message,
    COALESCE(branch.credit_card_short, ''::character varying) AS credit_card_short,
    COALESCE(document.csc_1654_message, ''::character varying) AS csc_1654_message,
    COALESCE(branch.csc_number, ''::character varying) AS csc_number,
    public.decimal_format_with_zero((document.current_balance)::text) AS current_balance,
    lpad((document.customer_account_number)::text, 6, '0'::text) AS customer_account_number,
    COALESCE(document.customer_address_line_1, ''::character varying) AS customer_address_line_1,
    COALESCE(document.customer_address_line_2, ''::character varying) AS customer_address_line_2,
    COALESCE(document.customer_group_code_1, ''::character varying) AS customer_group_code_1,
    COALESCE(document.customer_group_code_2, ''::character varying) AS customer_group_code_2,
    COALESCE(document.customer_group_code1, ''::character varying) AS customer_group_code1,
    COALESCE(document.customer_group_code2, ''::character varying) AS customer_group_code2,
    COALESCE(document.customer_name, ''::character varying) AS customer_name,
    COALESCE(datafile.datafilename, ''::character varying) AS datafilename,
    COALESCE(branch.dbase, ''::character varying) AS dbase,
    COALESCE(document.delivery_address_state, ''::character varying) AS delivery_address_state,
    COALESCE(document.detail_product_message, ''::character varying) AS detail_product_message,
    public.format_with_onedecimal((document.direct_deposit_amount)::numeric) AS direct_deposit_amount,
    COALESCE(branch.division, 0) AS branch_division,
    COALESCE(branch.division, 0) AS division,
    COALESCE(branch.division_name_1, ''::text) AS division_name_1,
    COALESCE(branch.division_name_2, ''::text) AS division_name_2,
    COALESCE(branch.division_name_3, ''::text) AS division_name_3,
    COALESCE(branch.division_name_4, ''::text) AS division_name_4,
    COALESCE(branch.document_date, ''::text) AS branch_document_date,
    to_char((document.document_date)::timestamp with time zone, 'MM-DD-YYYY'::text) AS document_date,
    branch.document_datetime,
    COALESCE(branch.document_message, ''::text) AS document_message,
    COALESCE(document.document_ref, ''::character varying) AS document_ref,
    COALESCE(branch.document_type, ''::character varying) AS document_type,
    COALESCE(document.documentid, ''::bpchar) AS documentid,
    COALESCE(document.duty_to_warn, false) AS duty_to_warn,
    COALESCE(document.electronic_delivery_information, ''::character varying) AS electronic_delivery_information,
    COALESCE(document.enclosure1, ''::character varying) AS enclosure1,
    COALESCE(document.enclosure2, ''::character varying) AS enclosure2,
    COALESCE(document.enclosure3, ''::character varying) AS enclosure3,
    COALESCE(document.enclosure4, ''::character varying) AS enclosure4,
    document.end_date,
    COALESCE(document.expanded_company_code, ''::character varying) AS expanded_company_code,
    public.decimal_format_with_zero(document.expanded_current_balance) AS expanded_current_balance,
    COALESCE(document.expanded_customer_account, ''::character varying) AS expanded_customer_account,
    COALESCE(document.expanded_division_number, 0) AS expanded_division_number,
    public.decimal_format_with_zero(document.expanded_previous_balance) AS expanded_previous_balance,
    COALESCE(branch.expanded_total_amount_billed, '0'::text) AS expanded_total_amount_billed,
    COALESCE(document.finance_charge_group, ''::character varying) AS finance_charge_group,
    public.decimal_format_with_zero(document.grand_total) AS grand_total,
    COALESCE(document.language_flag, ''::bpchar) AS language_flag,
    public.decimal_format_with_zero((document.late_charge)::text) AS late_charge,
    COALESCE(document.ldc, ''::character varying) AS ldc,
    COALESCE(branch.logo_indicator, ''::character varying) AS logo_indicator,
    COALESCE(branch.month_bud_payment_due, ''::character varying) AS month_bud_payment_due,
    COALESCE(document.ncoa_code, ''::character varying) AS ncoa_code,
    COALESCE(document.ncoa_customer_address_line_1, ''::character varying) AS ncoa_customer_address_line_1,
    COALESCE(document.ncoa_customer_address_line_2, ''::character varying) AS ncoa_customer_address_line_2,
    COALESCE(document.ncoa_state, ''::character varying) AS ncoa_state,
    COALESCE(document.ncoa_town, ''::character varying) AS ncoa_town,
    COALESCE(document.ncoa_zip, ''::character varying) AS ncoa_zip,
    COALESCE(document.net_days_day_of_month, 0) AS net_days_day_of_month,
    public.decimal_format_with_zero((document.new_activity)::numeric) AS new_activity,
    public.decimal_format_with_zero((document.non_budget_charges)::numeric) AS non_budget_charges,
    public.decimal_format_with_zero(document.non_budget_charges_for_bto_accts) AS non_budget_charges_for_bto_accts,
    COALESCE(document.number_of_budget_payments, 0) AS number_of_budget_payments,
    COALESCE(document.ocr_scan_line, ''::character varying) AS ocr_scan_line,
    COALESCE(document.onsert, ''::character varying) AS onsert,
    COALESCE(document.open_item_flag, ''::bpchar) AS open_item_flag,
    public.decimal_format_with_zero(document.past_due_balance) AS past_due_balance,
    public.decimal_format_with_zero((document.past_due_budget_amount)::numeric) AS past_due_budget_amount,
    COALESCE(branch.payment_disc_message, ''::character varying) AS payment_disc_message,
    public.decimal_format_with_zero((document.payments_and_credits)::numeric) AS payments_and_credits,
    COALESCE(document.payments_to_date_adjustments, (0)::numeric) AS payments_to_date_adjustments,
    COALESCE(document.pdffile, ''::character varying) AS pdffile,
    COALESCE(document.plan_code, ''::character varying) AS plan_code,
    COALESCE(branch.posting_code, ''::character varying) AS posting_code,
    COALESCE(document.pre_buy_dollars_paid, (0)::numeric) AS pre_buy_dollars_paid,
    COALESCE(document.pre_buy_dollars_remaining, (0)::numeric) AS pre_buy_dollars_remaining,
    public.decimal_format_with_zero((document.pre_payment_amount)::numeric) AS pre_payment_amount,
    public.decimal_format_with_zero((document.prepay_budget_credits)::numeric) AS prepay_budget_credits,
    public.decimal_format_with_zero((document.previous_balance)::text) AS previous_balance,
    COALESCE(document.budget_start_month, ''::character varying) AS previous_statement_date,
    COALESCE(document.price_per_gallon, (0)::numeric) AS price_per_gallon,
    COALESCE(document.print_balance_option, ''::character varying) AS print_balance_option,
    public.decimal_format_with_zero(document.prior_non_budgetable_charges) AS prior_non_budgetable_charges,
    COALESCE(document.product, ''::character varying) AS product,
    COALESCE(branch.project_number, ''::character varying) AS project_number,
    COALESCE(document.rec17_railroad_message, ''::character varying) AS rec17_railroad_message,
    public.decimal_format_with_zero((document.record_22_dollars_grand_total)::numeric) AS record_22_dollars_grand_total,
    public.decimal_format_with_zero((document.record_22_gallons_grand_total)::numeric) AS record_22_gallons_grand_total,
    COALESCE(branch.record_code, ''::character varying) AS branch_record_code,
    COALESCE((document.recordtype)::integer, 0) AS recordtype,
    public.decimal_format_with_zero(document.remaining_dollars) AS remaining_dollars,
    public.decimal_format_with_zero(document.remaining_gallons) AS remaining_gallons,
    COALESCE(branch.remittance_imb, ''::character varying) AS remittance_imb,
    COALESCE(branch.rownumber, 0) AS branch_rownumber,
    COALESCE(branch.rownumber, 0) AS rownumber,
    COALESCE(document.service_contract_in_budget, ''::character varying) AS service_contract_in_budget,
    COALESCE(document.slip, ''::character varying) AS slip,
    COALESCE(document.state, ''::character varying) AS state,
    public.decimal_format_with_zero(document.statement_balance) AS statement_balance,
    COALESCE(document.statement_day, ''::character varying) AS statement_day,
    COALESCE(document.statement_message_code, 0) AS statement_message_code,
    COALESCE(document.statement_type, ''::character varying) AS statement_type,
    COALESCE(document.summary_product_message_bottom, ''::character varying) AS summary_product_message_bottom,
    COALESCE(document.texas_railroad_message, ''::character varying) AS texas_railroad_message,
    COALESCE(document.total, (0)::numeric) AS total,
    public.decimal_format_with_zero(branch.total_amount_billed) AS branch_total_amount_billed,
    COALESCE(to_char(((branch.total_amount_billed)::numeric / 100.00), '0.00'::text), '0.00'::text) AS total_amount_billed,
    COALESCE(branch.total_due, (0)::numeric) AS branch_total_due,
    public.decimal_format_with_zero((document.total_due)::numeric) AS total_due,
    COALESCE(branch.total_items, 0) AS total_items,
    COALESCE(document.town, ''::character varying) AS town,
    COALESCE(document.transaction_code_rec_type, ''::character varying) AS transaction_code_rec_type,
    COALESCE(document.transaction_dollars_open_amount_on_a_keyoff_account, (0)::numeric) AS transaction_dollars_open_amount_on_a_keyoff_account,
    COALESCE(document.transaction_reference, ''::character varying) AS transaction_reference,
    COALESCE(document.transaction_unit_price, (0)::numeric) AS transaction_unit_price,
    COALESCE(document.transaction_units_gal_ltr, (0)::numeric) AS transaction_units_gal_ltr,
    COALESCE(document.type, 0) AS type,
    COALESCE(document.usps_imb, ''::character varying) AS usps_imb,
    COALESCE(document.vehicle_number, ''::character varying) AS vehicle_number,
    COALESCE(document.viewer_id, ''::character varying) AS viewer_id,
    COALESCE(document.zip, ''::character varying) AS zip,
    branch.datafileid,
    document.id,
    datafile.status
   FROM ((public.branch
     JOIN public.document ON ((branch.branchid = document.branchid)))
     JOIN public.datafile ON ((datafile.datafileid = (branch.datafileid)::bpchar)))
  WHERE ((branch.document_type)::text = 'STATEMENT'::text)
  ORDER BY branch.rownumber;


ALTER VIEW public.document_statement OWNER TO postgres;

--
-- TOC entry 374 (class 1259 OID 375566)
-- Name: documentarch; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.documentarch (
    id integer NOT NULL,
    documentarchid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    documenttype character varying(255),
    csc character varying(255),
    accountnumber character varying(255),
    documentdate date,
    previousbalance numeric,
    stmtbalance numeric,
    grandtotal numeric,
    customerinfo text,
    pdffilename character varying(255),
    folder character varying(255)
);


ALTER TABLE public.documentarch OWNER TO postgres;

--
-- TOC entry 373 (class 1259 OID 375565)
-- Name: documentarch_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.documentarch ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.documentarch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 340 (class 1259 OID 22054)
-- Name: documenttype; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.documenttype (
    id integer NOT NULL,
    documenttypeid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    name character varying(50) NOT NULL,
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.documenttype OWNER TO postgres;

--
-- TOC entry 339 (class 1259 OID 22053)
-- Name: documenttype_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.documenttype_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.documenttype_id_seq OWNER TO postgres;

--
-- TOC entry 4405 (class 0 OID 0)
-- Dependencies: 339
-- Name: documenttype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.documenttype_id_seq OWNED BY public.documenttype.id;


--
-- TOC entry 372 (class 1259 OID 372928)
-- Name: ejob; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ejob (
    id integer NOT NULL,
    ejobid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    opalsid integer,
    fromdate date,
    todate date,
    metric_pdf numeric,
    metric_record numeric,
    metric_compexta1 numeric,
    createdate timestamp without time zone DEFAULT now(),
    sent_to_opals timestamp without time zone,
    records_allowcated time without time zone,
    trinid character varying(20),
    postdate date,
    totamt numeric,
    salesamt numeric,
    postageamt numeric
);


ALTER TABLE public.ejob OWNER TO postgres;

--
-- TOC entry 371 (class 1259 OID 372927)
-- Name: ejob_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ejob_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ejob_id_seq OWNER TO postgres;

--
-- TOC entry 4406 (class 0 OID 0)
-- Dependencies: 371
-- Name: ejob_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ejob_id_seq OWNED BY public.ejob.id;


--
-- TOC entry 382 (class 1259 OID 465852)
-- Name: emailcampaigns; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emailcampaigns (
    id integer NOT NULL,
    emailcampaignsid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    emailcampaignsname character varying(50) NOT NULL,
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    emailcount numeric,
    templateid character(32),
    status character varying(30) DEFAULT 'Pending'::character varying,
    sentdate time without time zone
);


ALTER TABLE public.emailcampaigns OWNER TO postgres;

--
-- TOC entry 381 (class 1259 OID 465851)
-- Name: emailcampaigns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.emailcampaigns_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.emailcampaigns_id_seq OWNER TO postgres;

--
-- TOC entry 4407 (class 0 OID 0)
-- Dependencies: 381
-- Name: emailcampaigns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.emailcampaigns_id_seq OWNED BY public.emailcampaigns.id;


--
-- TOC entry 384 (class 1259 OID 465870)
-- Name: emaildeliveries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emaildeliveries (
    id integer NOT NULL,
    emaildeliveriesid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    name character varying(50) NOT NULL,
    account_number character varying(50),
    emailaddress character varying(320),
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    emailcampaignsid character(32) NOT NULL,
    maillogid integer
);


ALTER TABLE public.emaildeliveries OWNER TO postgres;

--
-- TOC entry 383 (class 1259 OID 465869)
-- Name: emaildeliveries_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.emaildeliveries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.emaildeliveries_id_seq OWNER TO postgres;

--
-- TOC entry 4408 (class 0 OID 0)
-- Dependencies: 383
-- Name: emaildeliveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.emaildeliveries_id_seq OWNED BY public.emaildeliveries.id;


--
-- TOC entry 366 (class 1259 OID 348609)
-- Name: excela_stg; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.excela_stg (
    id integer NOT NULL,
    applicationname character(1000),
    documenttype character(1000),
    csc character(1000),
    accountnumber character(1000),
    documentdate character(1000),
    previousbalance character(1000),
    stmtbalance character(1000),
    customerinfo character(1000),
    invoicenumber character(1000),
    grandtotal character(1000),
    pdffilename character(1000),
    createdate timestamp without time zone DEFAULT now() NOT NULL,
    zipfilename character(1000)
);


ALTER TABLE public.excela_stg OWNER TO postgres;

--
-- TOC entry 367 (class 1259 OID 348692)
-- Name: excela_stg_bkp; Type: TABLE; Schema: public; Owner: processing
--

CREATE TABLE public.excela_stg_bkp (
    id integer,
    applicationname character(32),
    documenttype character(32),
    csc character(32),
    accountnumber character(32),
    documentdate character(32),
    previousbalance character(32),
    stmtbalance character(32),
    customerinfo character(100),
    invoicenumber character(32),
    grandtotal character(32),
    pdffilename character(32),
    createdate timestamp without time zone
);


ALTER TABLE public.excela_stg_bkp OWNER TO processing;

--
-- TOC entry 365 (class 1259 OID 348608)
-- Name: excela_stg_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.excela_stg ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.excela_stg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 311 (class 1259 OID 16868)
-- Name: files; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.files (
    id integer NOT NULL,
    fileid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    circuit character varying(50),
    recordid character(32),
    filepath text,
    clientfile character varying(260),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    createadminuserid character(32),
    width smallint,
    height smallint,
    deletedby character(32),
    deletedtime timestamp without time zone
);


ALTER TABLE public.files OWNER TO postgres;

--
-- TOC entry 310 (class 1259 OID 16867)
-- Name: files_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.files_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.files_id_seq OWNER TO postgres;

--
-- TOC entry 4409 (class 0 OID 0)
-- Dependencies: 310
-- Name: files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.files_id_seq OWNED BY public.files.id;


--
-- TOC entry 327 (class 1259 OID 17206)
-- Name: filestatus; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.filestatus (
    id integer NOT NULL,
    filestatusid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    filestatusname character varying(50) NOT NULL,
    displayname character varying(50),
    code character varying(50) NOT NULL,
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canapprove boolean,
    active boolean DEFAULT true,
    sendemail boolean,
    canreject boolean,
    searchable boolean,
    orderby numeric,
    showjobnumbers boolean,
    apply_rules boolean
);


ALTER TABLE public.filestatus OWNER TO postgres;

--
-- TOC entry 326 (class 1259 OID 17205)
-- Name: filestatus_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.filestatus_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.filestatus_id_seq OWNER TO postgres;

--
-- TOC entry 4410 (class 0 OID 0)
-- Dependencies: 326
-- Name: filestatus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.filestatus_id_seq OWNED BY public.filestatus.id;


--
-- TOC entry 342 (class 1259 OID 22364)
-- Name: inserts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inserts (
    id integer NOT NULL,
    insertsid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    code character varying(50) NOT NULL,
    startdate date,
    enddate date,
    enclosure1 character varying(10),
    enclosure2 character varying(10),
    onsert character varying(100),
    slip character varying(500),
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    lockedby character(32),
    lockeddate timestamp without time zone,
    enclosure3 character varying(10),
    priority integer DEFAULT 0,
    onsert_active boolean,
    slip_active boolean,
    enclosure_active boolean,
    enclosure4 character varying(10),
    mapping character varying,
    applicationid character(32),
    mappingsql character varying,
    mappingexplain character varying,
    banner_active boolean,
    preview_datafileid character(32),
    preview_generated timestamp with time zone,
    active boolean,
    source_datafileid character(32),
    preview_error text,
    preview_adminuserid character varying(32),
    preview_running timestamp with time zone,
    preview_onlymatching boolean,
    onsert_page_count numeric
);


ALTER TABLE public.inserts OWNER TO postgres;

--
-- TOC entry 341 (class 1259 OID 22363)
-- Name: inserts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inserts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inserts_id_seq OWNER TO postgres;

--
-- TOC entry 4411 (class 0 OID 0)
-- Dependencies: 341
-- Name: inserts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inserts_id_seq OWNED BY public.inserts.id;


--
-- TOC entry 391 (class 1259 OID 709183)
-- Name: invoice_arch; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoice_arch (
    id integer NOT NULL,
    applicationname character varying(255),
    documenttype character varying(255),
    csc character varying(50),
    accountnumber character varying(50),
    documentdate date,
    customerinfo text,
    igoore1 text,
    pdffilename text,
    igoore2 text,
    previousbalance text,
    stmtbalance text,
    grandtotal text,
    s3 boolean,
    new boolean,
    pdffile character varying(100),
    filename character varying(100),
    size integer
);


ALTER TABLE public.invoice_arch OWNER TO postgres;

--
-- TOC entry 390 (class 1259 OID 709182)
-- Name: invoice_arch_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.invoice_arch ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.invoice_arch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 364 (class 1259 OID 320509)
-- Name: logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.logs (
    logid bigint NOT NULL,
    createdate timestamp without time zone DEFAULT now() NOT NULL,
    adminuserid character(32),
    recordid character(32),
    book character varying(50),
    color character varying(10),
    title character varying(100),
    data jsonb
);


ALTER TABLE public.logs OWNER TO postgres;

--
-- TOC entry 363 (class 1259 OID 320508)
-- Name: logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.logs_id_seq OWNER TO postgres;

--
-- TOC entry 4412 (class 0 OID 0)
-- Dependencies: 363
-- Name: logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.logs_id_seq OWNED BY public.logs.logid;


--
-- TOC entry 313 (class 1259 OID 16881)
-- Name: maillog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maillog (
    maillogid integer NOT NULL,
    messageid character varying(200),
    toaddress character varying(370),
    fromaddress character varying(370),
    subject character varying(998),
    message text,
    mailtypeid smallint,
    ready boolean DEFAULT true,
    senttime timestamp without time zone,
    returntype character varying(20),
    returnlog text,
    status character varying(20),
    diagnosticcode character varying(150),
    returntime timestamp without time zone,
    deliverytime timestamp without time zone,
    reportingmta character varying(50),
    smtpresponse character varying(250),
    sun boolean DEFAULT true,
    mon boolean DEFAULT true,
    tue boolean DEFAULT true,
    wed boolean DEFAULT true,
    thu boolean DEFAULT true,
    fri boolean DEFAULT true,
    sat boolean DEFAULT true,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    opentime timestamp without time zone,
    openip character varying(20),
    openuseragent character varying(200),
    renderingfailure boolean,
    orginalmaillogid integer,
    recordid character(32),
    templateid character(32),
    exportbody boolean,
    exportbodyziped boolean,
    duplicatechildid integer,
    duplicateparentid integer,
    priority boolean,
    resentdate timestamp without time zone,
    resentby character varying(32),
    resentmaillogid integer,
    buidtype smallint DEFAULT 1,
    processing character varying(32),
    sent boolean DEFAULT false,
    error boolean DEFAULT false,
    sendafter smallint,
    senduntil smallint,
    deletedby character varying(32),
    deleteddate timestamp without time zone,
    softbounce boolean,
    returnsubtype character varying(50),
    resenttime timestamp without time zone,
    hash character varying(32),
    adminuserid character varying(32),
    gotattachment boolean,
    print_opalsid integer,
    email_opalsid integer
);


ALTER TABLE public.maillog OWNER TO postgres;

--
-- TOC entry 312 (class 1259 OID 16880)
-- Name: maillog_maillogid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.maillog_maillogid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.maillog_maillogid_seq OWNER TO postgres;

--
-- TOC entry 4413 (class 0 OID 0)
-- Dependencies: 312
-- Name: maillog_maillogid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.maillog_maillogid_seq OWNED BY public.maillog.maillogid;


--
-- TOC entry 315 (class 1259 OID 16904)
-- Name: maillogattachment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maillogattachment (
    maillogattachmentid integer NOT NULL,
    maillogid integer,
    maillogattachmentname character varying(500),
    filesize integer,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.maillogattachment OWNER TO postgres;

--
-- TOC entry 314 (class 1259 OID 16903)
-- Name: maillogattachment_maillogattachmentid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.maillogattachment_maillogattachmentid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.maillogattachment_maillogattachmentid_seq OWNER TO postgres;

--
-- TOC entry 4414 (class 0 OID 0)
-- Dependencies: 314
-- Name: maillogattachment_maillogattachmentid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.maillogattachment_maillogattachmentid_seq OWNED BY public.maillogattachment.maillogattachmentid;


--
-- TOC entry 332 (class 1259 OID 17311)
-- Name: maillogqueue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maillogqueue (
    maillogid integer NOT NULL,
    segment smallint
);


ALTER TABLE public.maillogqueue OWNER TO postgres;

--
-- TOC entry 317 (class 1259 OID 16916)
-- Name: mailtype; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mailtype (
    mailtypeid integer NOT NULL,
    mailtypename character varying(50),
    fromaddress character varying(370),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    active boolean,
    createadminuserid character(32),
    updateadminuserid character(32),
    updatedate timestamp without time zone,
    sendafter smallint,
    senduntil smallint,
    sun boolean DEFAULT true,
    mon boolean DEFAULT true,
    tue boolean DEFAULT true,
    wed boolean DEFAULT true,
    thu boolean DEFAULT true,
    fri boolean DEFAULT true,
    sat boolean DEFAULT true,
    restricted boolean,
    opentracking boolean,
    buildactive boolean,
    dashboard boolean,
    applicationid character varying(32)
);


ALTER TABLE public.mailtype OWNER TO postgres;

--
-- TOC entry 316 (class 1259 OID 16915)
-- Name: mailtype_mailtypeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mailtype_mailtypeid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mailtype_mailtypeid_seq OWNER TO postgres;

--
-- TOC entry 4415 (class 0 OID 0)
-- Dependencies: 316
-- Name: mailtype_mailtypeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mailtype_mailtypeid_seq OWNED BY public.mailtype.mailtypeid;


--
-- TOC entry 348 (class 1259 OID 85411)
-- Name: olddata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.olddata (
    id integer NOT NULL,
    csc integer,
    account integer,
    customer_name character varying(255),
    street_1 character varying(255),
    billing_street_2 character varying(255),
    city character varying(100),
    state character varying(50),
    zip character varying(20),
    doctype character varying(50),
    invdate date,
    mail_date date,
    reference_num character varying(50),
    invoice_num character varying(50),
    duty_to_warn character varying(255),
    total_due numeric,
    current_charges numeric,
    piece_level_id character varying(50),
    dna_file_name_batch_id character varying(255),
    customer_file_name character varying(255),
    doc_view_flag character(1),
    doc_view_date date,
    failed_email_flag character(1),
    failed_email_address character varying(255),
    email_notification_date date,
    paperless character(1),
    paperless_email_address character varying(255),
    status character varying(50),
    edelivery_status character varying(50),
    print_status character varying(50),
    isforeign character(1),
    backer_version character varying(100),
    archive_date date,
    docid bigint,
    last_update_user character varying(255),
    last_update_date time without time zone,
    pages integer,
    document_indicator character(1),
    file_name character varying(255),
    datafilename character varying(255),
    document_type text,
    stmtdate date,
    statement_type character varying(255),
    open_item character varying(255),
    previous_statement_date date,
    statement_day character varying(50),
    past_due_message character varying(255),
    dtw_safety_duty_to_warn_version character varying(255),
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    pdffound boolean,
    inserted timestamp without time zone,
    s3_url character varying(500)
);


ALTER TABLE public.olddata OWNER TO postgres;

--
-- TOC entry 347 (class 1259 OID 85410)
-- Name: olddata_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.olddata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.olddata_id_seq OWNER TO postgres;

--
-- TOC entry 4416 (class 0 OID 0)
-- Dependencies: 347
-- Name: olddata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.olddata_id_seq OWNED BY public.olddata.id;


--
-- TOC entry 319 (class 1259 OID 16933)
-- Name: passwordhistory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.passwordhistory (
    id integer NOT NULL,
    adminuserid character(32) NOT NULL,
    password character varying(500)
);


ALTER TABLE public.passwordhistory OWNER TO postgres;

--
-- TOC entry 318 (class 1259 OID 16932)
-- Name: passwordhistory_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.passwordhistory_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.passwordhistory_id_seq OWNER TO postgres;

--
-- TOC entry 4417 (class 0 OID 0)
-- Dependencies: 318
-- Name: passwordhistory_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.passwordhistory_id_seq OWNED BY public.passwordhistory.id;


--
-- TOC entry 356 (class 1259 OID 161274)
-- Name: printjob; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.printjob (
    id integer NOT NULL,
    printjobid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    opalsid integer NOT NULL,
    maildate date,
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    grouprule text,
    pdf_ftp_sucess_at timestamp without time zone,
    pdf_ftp_error_at timestamp without time zone,
    pdf_ftp_start_at timestamp without time zone,
    segments integer,
    postage numeric(20,6),
    mailedpieces integer,
    printat character varying(10),
    trinid character varying(20),
    acctrefcode character varying(20),
    salesamt numeric(20,6),
    totamt numeric(20,6),
    postageamt numeric(20,6),
    postdate date,
    comp_retry_count integer,
    "comp_ verified" boolean
);


ALTER TABLE public.printjob OWNER TO postgres;

--
-- TOC entry 355 (class 1259 OID 161273)
-- Name: print_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.print_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.print_id_seq OWNER TO postgres;

--
-- TOC entry 4418 (class 0 OID 0)
-- Dependencies: 355
-- Name: print_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.print_id_seq OWNED BY public.printjob.id;


--
-- TOC entry 370 (class 1259 OID 371794)
-- Name: print_report; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.print_report AS
 SELECT count(*) AS packages,
    sum(document.page_count) AS impression,
    document.print_opalsid,
    branch.csc_number,
    application.programname,
    (printjob.createdate)::date AS printdate
   FROM ((((public.document
     JOIN public.branch ON ((branch.branchid = document.branchid)))
     JOIN public.datafile ON ((datafile.datafileid = (branch.datafileid)::bpchar)))
     JOIN public.application ON ((application.applicationid = (datafile.applicationid)::bpchar)))
     JOIN public.printjob ON ((document.print_opalsid = printjob.opalsid)))
  WHERE (((printjob.createdate)::date >= '2024-03-25'::date) AND ((printjob.createdate)::date <= '2024-04-18'::date))
  GROUP BY document.print_opalsid, branch.csc_number, application.programname, ((printjob.createdate)::date);


ALTER VIEW public.print_report OWNER TO postgres;

--
-- TOC entry 354 (class 1259 OID 159880)
-- Name: region; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.region (
    id integer NOT NULL,
    regionid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    regionname character varying(50) NOT NULL,
    deliverymethod character varying(50),
    serverip character varying(50),
    username character varying(50),
    password character varying(50),
    email character varying(320),
    createadminuserid character varying(32),
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    header text,
    columns text,
    ftpdestination character varying(500),
    enablelog boolean,
    encrypted boolean,
    pgpkey text,
    zipped boolean,
    outputfile character varying(250)
);


ALTER TABLE public.region OWNER TO postgres;

--
-- TOC entry 353 (class 1259 OID 159879)
-- Name: regon_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.regon_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.regon_id_seq OWNER TO postgres;

--
-- TOC entry 4419 (class 0 OID 0)
-- Dependencies: 353
-- Name: regon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.regon_id_seq OWNED BY public.region.id;


--
-- TOC entry 389 (class 1259 OID 603619)
-- Name: rental_arch; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rental_arch (
    id integer NOT NULL,
    applicationname character varying(255),
    documenttype character varying(255),
    csc character varying(50),
    accountnumber character varying(50),
    documentdate date,
    customerinfo text,
    igoore1 text,
    pdffilename text,
    igoore2 text,
    previousbalance text,
    stmtbalance text,
    grandtotal text,
    s3 boolean,
    size integer,
    pdffile character varying(100),
    filename character varying(100)
);


ALTER TABLE public.rental_arch OWNER TO postgres;

--
-- TOC entry 388 (class 1259 OID 603618)
-- Name: rental_arch_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.rental_arch ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.rental_arch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 321 (class 1259 OID 16943)
-- Name: role; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.role (
    roleid integer NOT NULL,
    rolename character varying(50) NOT NULL,
    code character varying(10),
    rights text,
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    createadminuserid character(32),
    updateadminuserid character(32),
    updatedate timestamp without time zone
);


ALTER TABLE public.role OWNER TO postgres;

--
-- TOC entry 320 (class 1259 OID 16942)
-- Name: role_roleid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.role_roleid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.role_roleid_seq OWNER TO postgres;

--
-- TOC entry 4420 (class 0 OID 0)
-- Dependencies: 320
-- Name: role_roleid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.role_roleid_seq OWNED BY public.role.roleid;


--
-- TOC entry 323 (class 1259 OID 16955)
-- Name: setting; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.setting (
    settingid integer NOT NULL,
    variable character varying(50),
    value text,
    valid boolean DEFAULT true,
    createdate timestamp without time zone,
    adminuserid character(32),
    setinapplication boolean
);


ALTER TABLE public.setting OWNER TO postgres;

--
-- TOC entry 322 (class 1259 OID 16954)
-- Name: setting_settingid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.setting_settingid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.setting_settingid_seq OWNER TO postgres;

--
-- TOC entry 4421 (class 0 OID 0)
-- Dependencies: 322
-- Name: setting_settingid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.setting_settingid_seq OWNED BY public.setting.settingid;


--
-- TOC entry 387 (class 1259 OID 548424)
-- Name: statement_arch; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.statement_arch (
    id integer NOT NULL,
    applicationname character varying(255),
    documenttype character varying(255),
    csc character varying(50),
    accountnumber character varying(50),
    documentdate date,
    customerinfo text,
    igoore1 text,
    pdffilename text,
    igoore2 text,
    previousbalance text,
    stmtbalance text,
    grandtotal text,
    pdffile character varying(100),
    filename character varying(100),
    s3 boolean,
    new boolean,
    size integer
);


ALTER TABLE public.statement_arch OWNER TO postgres;

--
-- TOC entry 386 (class 1259 OID 548423)
-- Name: statement_arch_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.statement_arch ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.statement_arch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 343 (class 1259 OID 24054)
-- Name: tableinfo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tableinfo (
    id integer DEFAULT nextval('public.datafile_id_seq'::regclass) NOT NULL,
    columnname character varying(100),
    tablename character varying(100),
    invoice boolean,
    statement boolean,
    note character varying,
    system boolean,
    onsert boolean,
    humanized character varying(100),
    datatype character varying(50),
    formated character varying(1000),
    customergrid integer,
    rentals boolean,
    delivery boolean,
    dunning boolean,
    letters boolean,
    invoiceformat boolean,
    statementformat boolean,
    rentalsformat boolean,
    deliveryformat boolean,
    dunningformat boolean,
    lettersformat boolean,
    creditdenied boolean,
    creditdeniedformat boolean,
    inoutput boolean,
    lock boolean DEFAULT false,
    invoiceformated character varying(3000),
    statementformated character varying(3000),
    rentalsformated character varying(3000),
    lettersformated character varying(3000),
    deliveryformated character varying(3000),
    dunningformated character varying(3000)
);


ALTER TABLE public.tableinfo OWNER TO postgres;

--
-- TOC entry 380 (class 1259 OID 424399)
-- Name: temp_paperless; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.temp_paperless (
    id integer NOT NULL,
    csc text,
    accountnumber text,
    name text,
    zip text,
    deliveryaddress text,
    deliverymethod text,
    new_email text
);


ALTER TABLE public.temp_paperless OWNER TO postgres;

--
-- TOC entry 379 (class 1259 OID 424398)
-- Name: temp_paperless_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.temp_paperless_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.temp_paperless_id_seq OWNER TO postgres;

--
-- TOC entry 4422 (class 0 OID 0)
-- Dependencies: 379
-- Name: temp_paperless_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.temp_paperless_id_seq OWNED BY public.temp_paperless.id;


--
-- TOC entry 334 (class 1259 OID 17320)
-- Name: template; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.template (
    id integer NOT NULL,
    templateid character(32) DEFAULT replace(((gen_random_uuid())::character varying)::text, '-'::text, ''::text) NOT NULL,
    subject character varying(250),
    email character varying(10485760),
    active boolean,
    updateadminuserid character varying(32),
    valid boolean DEFAULT true,
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updatedate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    createadminuserid character(32),
    code character varying(50),
    catchall boolean,
    lockeddate timestamp without time zone,
    lockedby character(32),
    mailtypeid integer
);


ALTER TABLE public.template OWNER TO postgres;

--
-- TOC entry 333 (class 1259 OID 17319)
-- Name: template_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.template ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.template_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 325 (class 1259 OID 16966)
-- Name: updatehistory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.updatehistory (
    updatehistoryid integer NOT NULL,
    circuit character varying(50),
    id character(32),
    data text,
    adminuserid character(32),
    memberid character(32),
    createdate timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.updatehistory OWNER TO postgres;

--
-- TOC entry 324 (class 1259 OID 16965)
-- Name: updatehistory_updatehistoryid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.updatehistory_updatehistoryid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.updatehistory_updatehistoryid_seq OWNER TO postgres;

--
-- TOC entry 4423 (class 0 OID 0)
-- Dependencies: 324
-- Name: updatehistory_updatehistoryid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.updatehistory_updatehistoryid_seq OWNED BY public.updatehistory.updatehistoryid;


--
-- TOC entry 385 (class 1259 OID 495444)
-- Name: v_transaction_reference; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.v_transaction_reference (
    transaction_refrence character varying(9)
);


ALTER TABLE public.v_transaction_reference OWNER TO postgres;

--
-- TOC entry 3684 (class 2604 OID 16822)
-- Name: accesslog accesslogid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accesslog ALTER COLUMN accesslogid SET DEFAULT nextval('public.accesslog_accesslogid_seq'::regclass);


--
-- TOC entry 3686 (class 2604 OID 16833)
-- Name: adminuser id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adminuser ALTER COLUMN id SET DEFAULT nextval('public.adminuser_id_seq'::regclass);


--
-- TOC entry 3964 (class 2604 OID 228316)
-- Name: adminuser_application id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adminuser_application ALTER COLUMN id SET DEFAULT nextval('public.adminuser_application_id_seq'::regclass);


--
-- TOC entry 3961 (class 2604 OID 228307)
-- Name: adminuser_csc id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adminuser_csc ALTER COLUMN id SET DEFAULT nextval('public.adminuser_csc_id_seq'::regclass);


--
-- TOC entry 3693 (class 2604 OID 16849)
-- Name: adminuserauth adminuserauthid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adminuserauth ALTER COLUMN adminuserauthid SET DEFAULT nextval('public.adminuserauth_adminuserauthid_seq'::regclass);


--
-- TOC entry 3697 (class 2604 OID 16860)
-- Name: adminuseremailverify adminuseremailverifyid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adminuseremailverify ALTER COLUMN adminuseremailverifyid SET DEFAULT nextval('public.adminuseremailverify_adminuseremailverifyid_seq'::regclass);


--
-- TOC entry 3746 (class 2604 OID 17224)
-- Name: application id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.application ALTER COLUMN id SET DEFAULT nextval('public.application_id_seq'::regclass);


--
-- TOC entry 3946 (class 2604 OID 157743)
-- Name: applicationgroup id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applicationgroup ALTER COLUMN id SET DEFAULT nextval('public.applicationgroup_id_seq'::regclass);


--
-- TOC entry 3979 (class 2604 OID 378776)
-- Name: archived id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.archived ALTER COLUMN id SET DEFAULT nextval('public.archived_id_seq'::regclass);


--
-- TOC entry 3967 (class 2604 OID 275809)
-- Name: component id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.component ALTER COLUMN id SET DEFAULT nextval('public.component_id_seq'::regclass);


--
-- TOC entry 3927 (class 2604 OID 24284)
-- Name: csc id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.csc ALTER COLUMN id SET DEFAULT nextval('public.csc_id_seq'::regclass);


--
-- TOC entry 3984 (class 2604 OID 403218)
-- Name: customerinfo id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customerinfo ALTER COLUMN id SET DEFAULT nextval('public.customerinfo_id_seq'::regclass);


--
-- TOC entry 3751 (class 2604 OID 17237)
-- Name: datafile id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datafile ALTER COLUMN id SET DEFAULT nextval('public.datafile_id_seq'::regclass);


--
-- TOC entry 3764 (class 2604 OID 17361)
-- Name: datafilestatushistory id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datafilestatushistory ALTER COLUMN id SET DEFAULT nextval('public.datafilestatushistory_id_seq'::regclass);


--
-- TOC entry 3914 (class 2604 OID 22057)
-- Name: documenttype id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documenttype ALTER COLUMN id SET DEFAULT nextval('public.documenttype_id_seq'::regclass);


--
-- TOC entry 3975 (class 2604 OID 372931)
-- Name: ejob id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ejob ALTER COLUMN id SET DEFAULT nextval('public.ejob_id_seq'::regclass);


--
-- TOC entry 3986 (class 2604 OID 465855)
-- Name: emailcampaigns id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emailcampaigns ALTER COLUMN id SET DEFAULT nextval('public.emailcampaigns_id_seq'::regclass);


--
-- TOC entry 3992 (class 2604 OID 465873)
-- Name: emaildeliveries id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emaildeliveries ALTER COLUMN id SET DEFAULT nextval('public.emaildeliveries_id_seq'::regclass);


--
-- TOC entry 3701 (class 2604 OID 16871)
-- Name: files id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.files ALTER COLUMN id SET DEFAULT nextval('public.files_id_seq'::regclass);


--
-- TOC entry 3740 (class 2604 OID 17209)
-- Name: filestatus id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.filestatus ALTER COLUMN id SET DEFAULT nextval('public.filestatus_id_seq'::regclass);


--
-- TOC entry 3919 (class 2604 OID 22367)
-- Name: inserts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inserts ALTER COLUMN id SET DEFAULT nextval('public.inserts_id_seq'::regclass);


--
-- TOC entry 3972 (class 2604 OID 320512)
-- Name: logs logid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logs ALTER COLUMN logid SET DEFAULT nextval('public.logs_id_seq'::regclass);


--
-- TOC entry 3705 (class 2604 OID 16884)
-- Name: maillog maillogid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maillog ALTER COLUMN maillogid SET DEFAULT nextval('public.maillog_maillogid_seq'::regclass);


--
-- TOC entry 3719 (class 2604 OID 16907)
-- Name: maillogattachment maillogattachmentid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maillogattachment ALTER COLUMN maillogattachmentid SET DEFAULT nextval('public.maillogattachment_maillogattachmentid_seq'::regclass);


--
-- TOC entry 3722 (class 2604 OID 16919)
-- Name: mailtype mailtypeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mailtype ALTER COLUMN mailtypeid SET DEFAULT nextval('public.mailtype_mailtypeid_seq'::regclass);


--
-- TOC entry 3938 (class 2604 OID 85414)
-- Name: olddata id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.olddata ALTER COLUMN id SET DEFAULT nextval('public.olddata_id_seq'::regclass);


--
-- TOC entry 3732 (class 2604 OID 16936)
-- Name: passwordhistory id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.passwordhistory ALTER COLUMN id SET DEFAULT nextval('public.passwordhistory_id_seq'::regclass);


--
-- TOC entry 3956 (class 2604 OID 161277)
-- Name: printjob id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.printjob ALTER COLUMN id SET DEFAULT nextval('public.print_id_seq'::regclass);


--
-- TOC entry 3951 (class 2604 OID 159883)
-- Name: region id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.region ALTER COLUMN id SET DEFAULT nextval('public.regon_id_seq'::regclass);


--
-- TOC entry 3733 (class 2604 OID 16946)
-- Name: role roleid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role ALTER COLUMN roleid SET DEFAULT nextval('public.role_roleid_seq'::regclass);


--
-- TOC entry 3736 (class 2604 OID 16958)
-- Name: setting settingid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.setting ALTER COLUMN settingid SET DEFAULT nextval('public.setting_settingid_seq'::regclass);


--
-- TOC entry 3985 (class 2604 OID 424402)
-- Name: temp_paperless id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_paperless ALTER COLUMN id SET DEFAULT nextval('public.temp_paperless_id_seq'::regclass);


--
-- TOC entry 3738 (class 2604 OID 16969)
-- Name: updatehistory updatehistoryid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.updatehistory ALTER COLUMN updatehistoryid SET DEFAULT nextval('public.updatehistory_updatehistoryid_seq'::regclass);


--
-- TOC entry 4030 (class 2606 OID 16827)
-- Name: accesslog accesslog_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accesslog
    ADD CONSTRAINT accesslog_pkey PRIMARY KEY (accesslogid);


--
-- TOC entry 4173 (class 2606 OID 228320)
-- Name: adminuser_application adminuser_application_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adminuser_application
    ADD CONSTRAINT adminuser_application_pkey PRIMARY KEY (id);


--
-- TOC entry 4171 (class 2606 OID 228311)
-- Name: adminuser_csc adminuser_csc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adminuser_csc
    ADD CONSTRAINT adminuser_csc_pkey PRIMARY KEY (id);


--
-- TOC entry 4033 (class 2606 OID 16843)
-- Name: adminuser adminuser_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adminuser
    ADD CONSTRAINT adminuser_pkey PRIMARY KEY (id);


--
-- TOC entry 4036 (class 2606 OID 16854)
-- Name: adminuserauth adminuserauth_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adminuserauth
    ADD CONSTRAINT adminuserauth_pkey PRIMARY KEY (adminuserauthid);


--
-- TOC entry 4039 (class 2606 OID 16865)
-- Name: adminuseremailverify adminuseremailverify_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.adminuseremailverify
    ADD CONSTRAINT adminuseremailverify_pkey PRIMARY KEY (adminuseremailverifyid);


--
-- TOC entry 4078 (class 2606 OID 17230)
-- Name: application application_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.application
    ADD CONSTRAINT application_pkey PRIMARY KEY (applicationid);


--
-- TOC entry 4151 (class 2606 OID 157757)
-- Name: applicationgroup applicationgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applicationgroup
    ADD CONSTRAINT applicationgroup_pkey PRIMARY KEY (applicationgroupid);


--
-- TOC entry 4195 (class 2606 OID 513593)
-- Name: archived archived_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.archived
    ADD CONSTRAINT archived_pkey PRIMARY KEY (archivedid);


--
-- TOC entry 4175 (class 2606 OID 275811)
-- Name: component componentid_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.component
    ADD CONSTRAINT componentid_pkey PRIMARY KEY (componentid);


--
-- TOC entry 4124 (class 2606 OID 24298)
-- Name: csc csc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.csc
    ADD CONSTRAINT csc_pkey PRIMARY KEY (cscid);


--
-- TOC entry 4200 (class 2606 OID 403222)
-- Name: customerinfo customerinfo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customerinfo
    ADD CONSTRAINT customerinfo_pkey PRIMARY KEY (id);


--
-- TOC entry 4082 (class 2606 OID 17243)
-- Name: datafile datafile_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datafile
    ADD CONSTRAINT datafile_pkey PRIMARY KEY (datafileid);


--
-- TOC entry 4101 (class 2606 OID 17366)
-- Name: datafilestatushistory datafilestatushistory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datafilestatushistory
    ADD CONSTRAINT datafilestatushistory_pkey PRIMARY KEY (id);


--
-- TOC entry 4182 (class 2606 OID 366283)
-- Name: default_trans_codes default_trans_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: processing
--

ALTER TABLE ONLY public.default_trans_codes
    ADD CONSTRAINT default_trans_codes_pkey PRIMARY KEY (transaction_id);


--
-- TOC entry 4146 (class 2606 OID 92122)
-- Name: deliveryrule deliveryrule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deliveryrule
    ADD CONSTRAINT deliveryrule_pkey PRIMARY KEY (deliveryruleid);


--
-- TOC entry 4104 (class 2606 OID 17648)
-- Name: document_line document_line_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.document_line
    ADD CONSTRAINT document_line_pkey PRIMARY KEY (document_lineid);


--
-- TOC entry 3998 (class 2606 OID 16981)
-- Name: branch document_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.branch
    ADD CONSTRAINT document_pkey PRIMARY KEY (branchid);


--
-- TOC entry 4008 (class 2606 OID 386500)
-- Name: document document_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.document
    ADD CONSTRAINT document_pkey1 PRIMARY KEY (documentid);


--
-- TOC entry 4189 (class 2606 OID 375573)
-- Name: documentarch documentarch_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documentarch
    ADD CONSTRAINT documentarch_pkey PRIMARY KEY (id);


--
-- TOC entry 4112 (class 2606 OID 22071)
-- Name: documenttype documenttype_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documenttype
    ADD CONSTRAINT documenttype_pkey PRIMARY KEY (documenttypeid);


--
-- TOC entry 4184 (class 2606 OID 372937)
-- Name: ejob ejob_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ejob
    ADD CONSTRAINT ejob_pkey PRIMARY KEY (id);


--
-- TOC entry 4204 (class 2606 OID 465864)
-- Name: emailcampaigns emailcampaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emailcampaigns
    ADD CONSTRAINT emailcampaigns_pkey PRIMARY KEY (emailcampaignsid);


--
-- TOC entry 4209 (class 2606 OID 465881)
-- Name: emaildeliveries emaildeliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emaildeliveries
    ADD CONSTRAINT emaildeliveries_pkey PRIMARY KEY (emaildeliveriesid);


--
-- TOC entry 4043 (class 2606 OID 16878)
-- Name: files files_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);


--
-- TOC entry 4070 (class 2606 OID 17217)
-- Name: filestatus filestatus_code_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.filestatus
    ADD CONSTRAINT filestatus_code_unique UNIQUE (code);


--
-- TOC entry 4072 (class 2606 OID 17215)
-- Name: filestatus filestatus_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.filestatus
    ADD CONSTRAINT filestatus_pkey PRIMARY KEY (filestatusid);


--
-- TOC entry 4177 (class 2606 OID 275813)
-- Name: component id_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.component
    ADD CONSTRAINT id_unique UNIQUE (id);


--
-- TOC entry 4118 (class 2606 OID 22385)
-- Name: inserts inserts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inserts
    ADD CONSTRAINT inserts_pkey PRIMARY KEY (insertsid);


--
-- TOC entry 4224 (class 2606 OID 709191)
-- Name: invoice_arch invoice_arch_pdffilename_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_arch
    ADD CONSTRAINT invoice_arch_pdffilename_unique UNIQUE (pdffilename);


--
-- TOC entry 4226 (class 2606 OID 709189)
-- Name: invoice_arch invoice_arch_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_arch
    ADD CONSTRAINT invoice_arch_pkey PRIMARY KEY (id);


--
-- TOC entry 4179 (class 2606 OID 320517)
-- Name: logs logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logs
    ADD CONSTRAINT logs_pkey PRIMARY KEY (logid);


--
-- TOC entry 4049 (class 2606 OID 16901)
-- Name: maillog maillog_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maillog
    ADD CONSTRAINT maillog_pkey PRIMARY KEY (maillogid);


--
-- TOC entry 4052 (class 2606 OID 16913)
-- Name: maillogattachment maillogattachment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maillogattachment
    ADD CONSTRAINT maillogattachment_pkey PRIMARY KEY (maillogattachmentid);


--
-- TOC entry 4055 (class 2606 OID 16930)
-- Name: mailtype mailtype_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mailtype
    ADD CONSTRAINT mailtype_pkey PRIMARY KEY (mailtypeid);


--
-- TOC entry 4144 (class 2606 OID 85418)
-- Name: olddata olddata_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.olddata
    ADD CONSTRAINT olddata_pkey PRIMARY KEY (id);


--
-- TOC entry 4138 (class 2606 OID 37505)
-- Name: delivery paperless_csc_number_customer_account_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery
    ADD CONSTRAINT paperless_csc_number_customer_account_number_key UNIQUE (csc_number, customer_account_number);


--
-- TOC entry 4140 (class 2606 OID 39079)
-- Name: delivery paperless_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery
    ADD CONSTRAINT paperless_pkey PRIMARY KEY (deliveryid);


--
-- TOC entry 4059 (class 2606 OID 16940)
-- Name: passwordhistory passwordhistory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.passwordhistory
    ADD CONSTRAINT passwordhistory_pkey PRIMARY KEY (id);


--
-- TOC entry 4095 (class 2606 OID 17315)
-- Name: maillogqueue pk_maillogqueue; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maillogqueue
    ADD CONSTRAINT pk_maillogqueue PRIMARY KEY (maillogid);


--
-- TOC entry 4167 (class 2606 OID 161291)
-- Name: printjob print_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.printjob
    ADD CONSTRAINT print_pkey PRIMARY KEY (printjobid);


--
-- TOC entry 4157 (class 2606 OID 159901)
-- Name: region regon_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.region
    ADD CONSTRAINT regon_pkey PRIMARY KEY (regionid);


--
-- TOC entry 4221 (class 2606 OID 603625)
-- Name: rental_arch rental_arch_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rental_arch
    ADD CONSTRAINT rental_arch_pkey PRIMARY KEY (id);


--
-- TOC entry 4061 (class 2606 OID 16952)
-- Name: role role_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_pkey PRIMARY KEY (roleid);


--
-- TOC entry 4064 (class 2606 OID 16963)
-- Name: setting setting_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.setting
    ADD CONSTRAINT setting_pkey PRIMARY KEY (settingid);


--
-- TOC entry 4217 (class 2606 OID 548430)
-- Name: statement_arch statement_arch_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.statement_arch
    ADD CONSTRAINT statement_arch_pkey PRIMARY KEY (id);


--
-- TOC entry 4122 (class 2606 OID 24061)
-- Name: tableinfo tableinfo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tableinfo
    ADD CONSTRAINT tableinfo_pkey PRIMARY KEY (id);


--
-- TOC entry 4202 (class 2606 OID 424406)
-- Name: temp_paperless temp_paperless_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_paperless
    ADD CONSTRAINT temp_paperless_pkey PRIMARY KEY (id);


--
-- TOC entry 4097 (class 2606 OID 17330)
-- Name: template template_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template
    ADD CONSTRAINT template_pkey PRIMARY KEY (templateid);


--
-- TOC entry 4093 (class 2606 OID 32727)
-- Name: datafile unique_datafilename; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datafile
    ADD CONSTRAINT unique_datafilename UNIQUE (datafilename);


--
-- TOC entry 4028 (class 2606 OID 92464)
-- Name: document unique_document_fields; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.document
    ADD CONSTRAINT unique_document_fields UNIQUE (branchid, customer_account_number, document_date);


--
-- TOC entry 4110 (class 2606 OID 36783)
-- Name: document_line unique_document_line_fields; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.document_line
    ADD CONSTRAINT unique_document_line_fields UNIQUE (documentid, rownumber);


--
-- TOC entry 4067 (class 2606 OID 16974)
-- Name: updatehistory updatehistory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.updatehistory
    ADD CONSTRAINT updatehistory_pkey PRIMARY KEY (updatehistoryid);


--
-- TOC entry 4031 (class 1259 OID 1020079)
-- Name: accesslogid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX accesslogid_index ON public.accesslog USING btree (accesslogid);


--
-- TOC entry 4180 (class 1259 OID 1020101)
-- Name: accountnumber_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX accountnumber_index ON public.excela_stg USING btree (accountnumber);


--
-- TOC entry 4037 (class 1259 OID 1020077)
-- Name: adminuserauthid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX adminuserauthid_index ON public.adminuserauth USING btree (adminuserauthid);


--
-- TOC entry 4040 (class 1259 OID 1020082)
-- Name: adminuseremailverifyid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX adminuseremailverifyid_index ON public.adminuseremailverify USING btree (adminuseremailverifyid);


--
-- TOC entry 4034 (class 1259 OID 1019943)
-- Name: adminuserid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX adminuserid_index ON public.adminuser USING btree (adminuserid);


--
-- TOC entry 4079 (class 1259 OID 1020018)
-- Name: application_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX application_valid ON public.application USING btree (valid);


--
-- TOC entry 4152 (class 1259 OID 1020073)
-- Name: applicationgroup_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX applicationgroup_valid ON public.applicationgroup USING btree (valid);


--
-- TOC entry 4153 (class 1259 OID 1020072)
-- Name: applicationgroupid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX applicationgroupid ON public.applicationgroup USING btree (applicationgroupid);

ALTER TABLE public.applicationgroup CLUSTER ON applicationgroupid;


--
-- TOC entry 4080 (class 1259 OID 1020017)
-- Name: applicationid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX applicationid ON public.application USING btree (applicationid);

ALTER TABLE public.application CLUSTER ON applicationid;


--
-- TOC entry 4190 (class 1259 OID 1019916)
-- Name: archived_applicationid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX archived_applicationid ON public.archived USING btree (applicationid);


--
-- TOC entry 4191 (class 1259 OID 1019913)
-- Name: archived_csc_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX archived_csc_number ON public.archived USING btree (csc_number);


--
-- TOC entry 4192 (class 1259 OID 1019914)
-- Name: archived_customer_account_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX archived_customer_account_number ON public.archived USING btree (customer_account_number);


--
-- TOC entry 4193 (class 1259 OID 1019915)
-- Name: archived_document_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX archived_document_date ON public.archived USING btree (document_date);


--
-- TOC entry 4129 (class 1259 OID 1020025)
-- Name: delivery_csc_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX delivery_csc_number ON public.delivery USING btree (csc_number);


--
-- TOC entry 4130 (class 1259 OID 1020024)
-- Name: delivery_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX delivery_email ON public.delivery USING btree (email);


--
-- TOC entry 4147 (class 1259 OID 1020105)
-- Name: deliveryrule_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX deliveryrule_valid ON public.deliveryrule USING btree (valid);


--
-- TOC entry 4148 (class 1259 OID 1020106)
-- Name: deliveryruleid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX deliveryruleid ON public.deliveryrule USING btree (deliveryruleid);

ALTER TABLE public.deliveryrule CLUSTER ON deliveryruleid;


--
-- TOC entry 4005 (class 1259 OID 1019958)
-- Name: document_domestic; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX document_domestic ON public.document USING btree (domestic);


--
-- TOC entry 4006 (class 1259 OID 1019962)
-- Name: document_highlight; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX document_highlight ON public.document USING btree (highlight);


--
-- TOC entry 4105 (class 1259 OID 1020045)
-- Name: document_line_transaction_reference; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX document_line_transaction_reference ON public.document_line USING btree (transaction_reference);


--
-- TOC entry 4113 (class 1259 OID 1020013)
-- Name: documenttype_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX documenttype_valid ON public.documenttype USING btree (valid);


--
-- TOC entry 4114 (class 1259 OID 1020012)
-- Name: documenttypeid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX documenttypeid ON public.documenttype USING btree (documenttypeid);

ALTER TABLE public.documenttype CLUSTER ON documenttypeid;


--
-- TOC entry 4205 (class 1259 OID 1020033)
-- Name: emailcampaigns_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX emailcampaigns_valid ON public.emailcampaigns USING btree (valid);


--
-- TOC entry 4206 (class 1259 OID 1020034)
-- Name: emailcampaignsid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX emailcampaignsid ON public.emailcampaigns USING btree (emailcampaignsid);

ALTER TABLE public.emailcampaigns CLUSTER ON emailcampaignsid;


--
-- TOC entry 4210 (class 1259 OID 1020038)
-- Name: emaildeliveries_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX emaildeliveries_valid ON public.emaildeliveries USING btree (valid);


--
-- TOC entry 4211 (class 1259 OID 1020039)
-- Name: emaildeliveriesid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX emaildeliveriesid ON public.emaildeliveries USING btree (emaildeliveriesid);


--
-- TOC entry 4041 (class 1259 OID 1020084)
-- Name: fileid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX fileid_index ON public.files USING btree (fileid);


--
-- TOC entry 4073 (class 1259 OID 1019898)
-- Name: filestatus_sendemail; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX filestatus_sendemail ON public.filestatus USING btree (sendemail);


--
-- TOC entry 4074 (class 1259 OID 1019896)
-- Name: filestatus_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX filestatus_valid ON public.filestatus USING btree (valid);


--
-- TOC entry 4075 (class 1259 OID 1019895)
-- Name: filestatusid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX filestatusid ON public.filestatus USING btree (filestatusid);


--
-- TOC entry 4057 (class 1259 OID 1019993)
-- Name: id_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX id_index ON public.passwordhistory USING btree (id);


--
-- TOC entry 4154 (class 1259 OID 1020070)
-- Name: idx_applicationgroup_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_applicationgroup_id ON public.applicationgroup USING btree (id);


--
-- TOC entry 4196 (class 1259 OID 1019918)
-- Name: idx_archived_query_optimization; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_archived_query_optimization ON public.archived USING btree (valid, document_date DESC, applicationid, archivedid DESC);


--
-- TOC entry 4197 (class 1259 OID 1019919)
-- Name: idx_archived_unique_doc; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_archived_unique_doc ON public.archived USING btree (applicationid, pdffile, filename);


--
-- TOC entry 4198 (class 1259 OID 1019917)
-- Name: idx_archived_unique_filename_pdffile; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_archived_unique_filename_pdffile ON public.archived USING btree (filename, pdffile);


--
-- TOC entry 3999 (class 1259 OID 1019968)
-- Name: idx_branch_branchid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_branch_branchid ON public.branch USING btree (branchid);

ALTER TABLE public.branch CLUSTER ON idx_branch_branchid;


--
-- TOC entry 4000 (class 1259 OID 1019970)
-- Name: idx_branch_client_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_branch_client_number ON public.branch USING btree (client_number);


--
-- TOC entry 4001 (class 1259 OID 1019971)
-- Name: idx_branch_csc_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_branch_csc_number ON public.branch USING btree (csc_number);


--
-- TOC entry 4002 (class 1259 OID 1019972)
-- Name: idx_branch_datafileid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_branch_datafileid ON public.branch USING btree (datafileid);


--
-- TOC entry 4003 (class 1259 OID 1019973)
-- Name: idx_branch_rownumber; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_branch_rownumber ON public.branch USING btree (rownumber);


--
-- TOC entry 4125 (class 1259 OID 1534653)
-- Name: idx_csc_csc_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_csc_csc_number ON public.csc USING btree (csc_number);


--
-- TOC entry 4126 (class 1259 OID 1020099)
-- Name: idx_csc_cscid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_csc_cscid ON public.csc USING btree (cscid);

ALTER TABLE public.csc CLUSTER ON idx_csc_cscid;


--
-- TOC entry 4127 (class 1259 OID 1020097)
-- Name: idx_csc_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_csc_id ON public.csc USING btree (id);


--
-- TOC entry 4128 (class 1259 OID 1020100)
-- Name: idx_csc_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_csc_valid ON public.csc USING btree (valid);


--
-- TOC entry 4083 (class 1259 OID 1019904)
-- Name: idx_datafile_applicationid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_datafile_applicationid ON public.datafile USING btree (applicationid);


--
-- TOC entry 4084 (class 1259 OID 1029954)
-- Name: idx_datafile_copy; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_datafile_copy ON public.datafile USING btree (copy) WHERE (copy IS NOT TRUE);


--
-- TOC entry 4085 (class 1259 OID 1019901)
-- Name: idx_datafile_datafileid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_datafile_datafileid ON public.datafile USING btree (datafileid);

ALTER TABLE public.datafile CLUSTER ON idx_datafile_datafileid;


--
-- TOC entry 4086 (class 1259 OID 1019903)
-- Name: idx_datafile_datafilename; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_datafile_datafilename ON public.datafile USING btree (datafilename);


--
-- TOC entry 4087 (class 1259 OID 1019905)
-- Name: idx_datafile_maildate; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_datafile_maildate ON public.datafile USING btree (maildate);


--
-- TOC entry 4088 (class 1259 OID 1019906)
-- Name: idx_datafile_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_datafile_status ON public.datafile USING btree (status);


--
-- TOC entry 4089 (class 1259 OID 1019908)
-- Name: idx_datafile_status_lower; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_datafile_status_lower ON public.datafile USING btree (lower((status)::text));


--
-- TOC entry 4090 (class 1259 OID 1029959)
-- Name: idx_datafile_valid_copy_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_datafile_valid_copy_status ON public.datafile USING btree (valid, copy, lower((status)::text)) WHERE ((valid = true) AND (copy IS NOT TRUE));


--
-- TOC entry 4131 (class 1259 OID 1028660)
-- Name: idx_delivery_createdate; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_delivery_createdate ON public.delivery USING btree (createdate);


--
-- TOC entry 4132 (class 1259 OID 1028659)
-- Name: idx_delivery_deliverymethod; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_delivery_deliverymethod ON public.delivery USING btree (deliverymethod);


--
-- TOC entry 4133 (class 1259 OID 1028658)
-- Name: idx_delivery_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_delivery_valid ON public.delivery USING btree (valid);


--
-- TOC entry 4134 (class 1259 OID 1028661)
-- Name: idx_delivery_valid_deliverymethod_createdate; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_delivery_valid_deliverymethod_createdate ON public.delivery USING btree (valid, deliverymethod, createdate);


--
-- TOC entry 4149 (class 1259 OID 1020104)
-- Name: idx_deliveryrule_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_deliveryrule_id ON public.deliveryrule USING btree (id);


--
-- TOC entry 4009 (class 1259 OID 1019952)
-- Name: idx_document_branchid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_branchid ON public.document USING btree (branchid);


--
-- TOC entry 4010 (class 1259 OID 1019948)
-- Name: idx_document_customer_account_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_customer_account_number ON public.document USING btree (customer_account_number);


--
-- TOC entry 4011 (class 1259 OID 1019955)
-- Name: idx_document_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_date ON public.document USING btree (document_date);


--
-- TOC entry 4012 (class 1259 OID 1019956)
-- Name: idx_document_deliveryruleid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_deliveryruleid ON public.document USING btree (deliveryruleid);


--
-- TOC entry 4013 (class 1259 OID 1019951)
-- Name: idx_document_documentid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_documentid ON public.document USING btree (documentid);


--
-- TOC entry 4014 (class 1259 OID 1534654)
-- Name: idx_document_email_opalsid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_email_opalsid ON public.document USING btree (email_opalsid) WHERE (email_opalsid IS NOT NULL);


--
-- TOC entry 4015 (class 1259 OID 1019949)
-- Name: idx_document_invoice_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_invoice_number ON public.document USING btree (invoice_number);


--
-- TOC entry 4106 (class 1259 OID 1020043)
-- Name: idx_document_line_documentid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_line_documentid ON public.document_line USING btree (documentid);


--
-- TOC entry 4107 (class 1259 OID 1029958)
-- Name: idx_document_line_po; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_line_po ON public.document_line USING btree (lower((purchase_order_number)::text));


--
-- TOC entry 4108 (class 1259 OID 1020044)
-- Name: idx_document_line_rownumber; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_line_rownumber ON public.document_line USING btree (rownumber);


--
-- TOC entry 4016 (class 1259 OID 1019946)
-- Name: idx_document_lineid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_document_lineid ON public.document USING btree (documentid);

ALTER TABLE public.document CLUSTER ON idx_document_lineid;


--
-- TOC entry 4017 (class 1259 OID 1534821)
-- Name: idx_document_maillogid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_maillogid ON public.document USING btree (maillogid) WHERE (maillogid IS NOT NULL);


--
-- TOC entry 4018 (class 1259 OID 1019947)
-- Name: idx_document_pdffile; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_pdffile ON public.document USING btree (pdffile);


--
-- TOC entry 4019 (class 1259 OID 1496814)
-- Name: idx_document_print_opalsid_branchid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_print_opalsid_branchid ON public.document USING btree (print_opalsid, branchid);


--
-- TOC entry 4020 (class 1259 OID 1019960)
-- Name: idx_document_printopalsid_nonnull; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_printopalsid_nonnull ON public.document USING btree (print_opalsid) WHERE (print_opalsid IS NOT NULL);


--
-- TOC entry 4004 (class 1259 OID 1019974)
-- Name: idx_document_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_type ON public.branch USING btree (document_type);


--
-- TOC entry 4021 (class 1259 OID 1019945)
-- Name: idx_document_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_valid ON public.document USING btree (valid);


--
-- TOC entry 4022 (class 1259 OID 1534617)
-- Name: idx_document_valid_printopalsid_branchid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_valid_printopalsid_branchid ON public.document USING btree (print_opalsid, branchid) WHERE ((valid = true) AND (print_opalsid IS NOT NULL));


--
-- TOC entry 4023 (class 1259 OID 1019950)
-- Name: idx_document_zip; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_zip ON public.document USING btree (zip);


--
-- TOC entry 4024 (class 1259 OID 1019957)
-- Name: idx_documentid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_documentid ON public.document USING btree (documentid);


--
-- TOC entry 4115 (class 1259 OID 1020010)
-- Name: idx_documenttype_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_documenttype_id ON public.documenttype USING btree (id);


--
-- TOC entry 4185 (class 1259 OID 1534647)
-- Name: idx_ejob_createdate_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ejob_createdate_date ON public.ejob USING btree (((createdate)::date));


--
-- TOC entry 4186 (class 1259 OID 1019984)
-- Name: idx_ejob_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ejob_id ON public.ejob USING btree (id);


--
-- TOC entry 4187 (class 1259 OID 1534645)
-- Name: idx_ejob_opalsid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ejob_opalsid ON public.ejob USING btree (opalsid);


--
-- TOC entry 4207 (class 1259 OID 1020035)
-- Name: idx_emailcampaigns_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_emailcampaigns_id ON public.emailcampaigns USING btree (id);


--
-- TOC entry 4076 (class 1259 OID 1019897)
-- Name: idx_filestatus_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_filestatus_id ON public.filestatus USING btree (id);

ALTER TABLE public.filestatus CLUSTER ON idx_filestatus_id;


--
-- TOC entry 4116 (class 1259 OID 1020092)
-- Name: idx_inserts_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_inserts_id ON public.inserts USING btree (id);


--
-- TOC entry 4044 (class 1259 OID 1534813)
-- Name: idx_maillog_createdate; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_maillog_createdate ON public.maillog USING btree (createdate);


--
-- TOC entry 4045 (class 1259 OID 1534819)
-- Name: idx_maillog_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_maillog_valid ON public.maillog USING btree (valid) WHERE (valid = true);


--
-- TOC entry 4046 (class 1259 OID 1534820)
-- Name: idx_maillog_valid_createdate; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_maillog_valid_createdate ON public.maillog USING btree (createdate DESC) WHERE (valid = true);


--
-- TOC entry 4047 (class 1259 OID 1534842)
-- Name: idx_maillog_valid_createdate_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_maillog_valid_createdate_id ON public.maillog USING btree (createdate, maillogid DESC) WHERE (valid = true);


--
-- TOC entry 4135 (class 1259 OID 1020022)
-- Name: idx_paperless_cscnumber_accountnumber; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_paperless_cscnumber_accountnumber ON public.delivery USING btree (csc_number, customer_account_number);


--
-- TOC entry 4091 (class 1259 OID 1019907)
-- Name: idx_paperless_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_paperless_valid ON public.datafile USING btree (valid);


--
-- TOC entry 4218 (class 1259 OID 1020110)
-- Name: idx_pdffilename; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pdffilename ON public.rental_arch USING btree (pdffilename);


--
-- TOC entry 4160 (class 1259 OID 1019977)
-- Name: idx_print_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_print_id ON public.printjob USING btree (id);


--
-- TOC entry 4025 (class 1259 OID 1019959)
-- Name: idx_print_opalsid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_print_opalsid ON public.document USING btree (print_opalsid);


--
-- TOC entry 4161 (class 1259 OID 1534614)
-- Name: idx_printjob_createdate_date_postdate; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_printjob_createdate_date_postdate ON public.printjob USING btree (((createdate)::date), postdate) WHERE (postdate IS NOT NULL);


--
-- TOC entry 4162 (class 1259 OID 1534741)
-- Name: idx_printjob_createdate_opalsid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_printjob_createdate_opalsid ON public.printjob USING btree (createdate, opalsid);


--
-- TOC entry 4163 (class 1259 OID 1534752)
-- Name: idx_printjob_createdate_postdate_opalsid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_printjob_createdate_postdate_opalsid ON public.printjob USING btree (createdate, opalsid) WHERE (postdate IS NOT NULL);


--
-- TOC entry 4164 (class 1259 OID 1019981)
-- Name: idx_printjob_opalsid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_printjob_opalsid ON public.printjob USING btree (opalsid);


--
-- TOC entry 4165 (class 1259 OID 1496813)
-- Name: idx_printjob_valid_createdate; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_printjob_valid_createdate ON public.printjob USING btree (createdate DESC) WHERE (valid = true);


--
-- TOC entry 4155 (class 1259 OID 1020027)
-- Name: idx_regon_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_regon_id ON public.region USING btree (id);


--
-- TOC entry 4219 (class 1259 OID 1020109)
-- Name: idx_rental_arch_pdffilename; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_rental_arch_pdffilename ON public.rental_arch USING btree (pdffilename);


--
-- TOC entry 4212 (class 1259 OID 1020122)
-- Name: idx_statement_arch_filename; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_statement_arch_filename ON public.statement_arch USING btree (filename) WHERE (filename IS NOT NULL);


--
-- TOC entry 4213 (class 1259 OID 1020119)
-- Name: idx_statement_arch_pdffilename; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_statement_arch_pdffilename ON public.statement_arch USING btree (pdffilename);


--
-- TOC entry 4026 (class 1259 OID 1019953)
-- Name: idx_transaction_reference; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transaction_reference ON public.document USING btree (transaction_reference);


--
-- TOC entry 4136 (class 1259 OID 1020023)
-- Name: idx_unique_delivery; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_unique_delivery ON public.delivery USING btree (csc_number, COALESCE((customer_account_number)::integer, 0));


--
-- TOC entry 4119 (class 1259 OID 1020095)
-- Name: inserts_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX inserts_valid ON public.inserts USING btree (valid);


--
-- TOC entry 4120 (class 1259 OID 1020094)
-- Name: insertsid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX insertsid ON public.inserts USING btree (insertsid);

ALTER TABLE public.inserts CLUSTER ON insertsid;


--
-- TOC entry 4222 (class 1259 OID 1020114)
-- Name: invoice_arch_filename; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX invoice_arch_filename ON public.invoice_arch USING btree (filename);


--
-- TOC entry 4053 (class 1259 OID 1019987)
-- Name: maillogattachmentid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX maillogattachmentid_index ON public.maillogattachment USING btree (maillogattachmentid);


--
-- TOC entry 4050 (class 1259 OID 1019891)
-- Name: maillogid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX maillogid_index ON public.maillog USING btree (maillogid);


--
-- TOC entry 4056 (class 1259 OID 1019888)
-- Name: mailtypeid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX mailtypeid_index ON public.mailtype USING btree (mailtypeid);


--
-- TOC entry 4141 (class 1259 OID 1020087)
-- Name: olddata_datafilename; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX olddata_datafilename ON public.olddata USING btree (datafilename);


--
-- TOC entry 4142 (class 1259 OID 1020088)
-- Name: olddata_file_name_datafilename; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX olddata_file_name_datafilename ON public.olddata USING btree (file_name, datafilename);


--
-- TOC entry 4102 (class 1259 OID 1020066)
-- Name: pk_datafilestatushistory; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX pk_datafilestatushistory ON public.datafilestatushistory USING btree (datafilestatushistoryid);


--
-- TOC entry 4168 (class 1259 OID 1019980)
-- Name: print_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX print_valid ON public.printjob USING btree (valid);


--
-- TOC entry 4169 (class 1259 OID 1019979)
-- Name: printid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX printid ON public.printjob USING btree (printjobid);

ALTER TABLE public.printjob CLUSTER ON printid;


--
-- TOC entry 4158 (class 1259 OID 1020030)
-- Name: regon_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX regon_valid ON public.region USING btree (valid);


--
-- TOC entry 4159 (class 1259 OID 1020029)
-- Name: regonid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX regonid ON public.region USING btree (regionid);

ALTER TABLE public.region CLUSTER ON regonid;


--
-- TOC entry 4062 (class 1259 OID 1019990)
-- Name: roleid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX roleid_index ON public.role USING btree (roleid);


--
-- TOC entry 4065 (class 1259 OID 1019999)
-- Name: settingid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX settingid_index ON public.setting USING btree (settingid);


--
-- TOC entry 4214 (class 1259 OID 1020120)
-- Name: statement_arch_filename; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX statement_arch_filename ON public.statement_arch USING btree (filename);


--
-- TOC entry 4215 (class 1259 OID 1020121)
-- Name: statement_arch_pdffile; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX statement_arch_pdffile ON public.statement_arch USING btree (pdffile);


--
-- TOC entry 4098 (class 1259 OID 1020007)
-- Name: template_valid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX template_valid ON public.template USING btree (valid);


--
-- TOC entry 4099 (class 1259 OID 1020008)
-- Name: templateid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX templateid ON public.template USING btree (templateid);

ALTER TABLE public.template CLUSTER ON templateid;


--
-- TOC entry 4068 (class 1259 OID 1020003)
-- Name: updatehistoryid_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX updatehistoryid_index ON public.updatehistory USING btree (updatehistoryid);


--
-- TOC entry 4227 (class 2620 OID 37376)
-- Name: datafile delete_datafile; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER delete_datafile AFTER DELETE ON public.datafile FOR EACH ROW EXECUTE FUNCTION public.delete_datafile();


-- Completed on 2026-01-30 17:10:08

--
-- PostgreSQL database dump complete
--

