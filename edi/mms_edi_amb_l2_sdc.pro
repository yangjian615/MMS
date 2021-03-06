; docformat = 'rst'
;
; NAME:
;    mms_edi_amb_l2_sdc
;
; PURPOSE:
;+
;   Process EDI ambient mode data to produce a level 2 data product with counts
;   sorted according to their pitch angle.
;
; :Categories:
;    MMS, EDI, L2, Ambient
;
; :Params:
;       SC:                 in, required, type=string
;                           Spacecraft ID of the data to be processed. Choices are:
;                               'mms1', 'mms2', 'mms3', 'mms4'
;       MODE:               in, required, type=string
;                           Data rate mode of the data to be processd. Choices are:
;                               'slow', 'fast', 'srvy', 'brst'
;       TSTART:             in, required, type=string
;                           Start time of the file(s) to be processed, formatted as
;                               'YYYYMMDDhhmmss' for burst mode and 'YYYYMMDD' otherwise.
;                               TSTART must match the start time in the file names to
;                               be processed.
;
; :Keywords:
;       CAL_PATH_ROOT:      in, optional, type=string, default=!mms_init.cal_path_root
;                           Root of the SDC-like directory structure where calibration
;                               files are stored. If not present, the default is taken
;                               from the CAL_PATH_ROOT environment variable.
;       DATA_PATH_ROOT:     in, optional, type=string, default=!mms_init.data_path
;                           Root of the SDC-like directory structure where data files
;                               find their final resting place.
;       DROPBOX_ROOT:       in, optional, type=string, default=!mms_init.dropbox
;                           Directory into which data files are initially saved.
;       FILE_OUT:           out, optional, type=string
;                           Named variable to receive the name of the output file.
;       HK_ROOT:            in, optional, type=string, default=!mms_init.hk_root
;                           Root of the SDC-like directory structure where housekeeping
;                               files are stored. If not present, the default is taken
;                               from the HK_ROOT environment variable.
;       LOG_PATH_ROOT:      in, optional, type=string, default=!mms_init.log_path
;                           Root directory into which log files are saved.
;       NO_LOG:             in, optional, type=boolean, default=0
;                           If set, no log file is created and all output is directed to
;                               the terminal window.
;       PRELIMINARY:        in, optional, type=boolean, default=0
;                           If set, a preliminary data set with no absolute cals is
;                              is made. This is different from QL data in that QL data
;                              does not have trajectory or error information.
;
; :Returns:
;       STATUS:             out, required, type=byte
;                           An error code. Values are:::
;                               OK      = 0
;                               Warning = 1-99
;                               Error   = 100-255
;                                   100      -  Trapped error
;                                   101      -  Bad inputs given
;                                   102      -  No EDI files found
;                                   105      -  Error from mms_edi_amb_create
;                                   110      -  Error from mms_edi_amb_ql_write
;
; :Author:
;    Matthew Argall::
;        University of New Hampshire
;        Morse Hall Room 348
;        8 College Road
;        Durham, NH 03824
;        matthew.argall@unh.edu
;
; :History:
;    Modification History::
;       2016/01/29  -   Written by Matthew Argall
;       2016/03/23  -   Added CAL_PATH_ROOT and HK_ROOT. Updated location of calibration
;                           and house-keeping files. - MRA
;       2016/03/30  -   Added PRELIMINARY keyword. - MRA
;       2018/01/12  -   Fixed indexing error when multiple modes were present in same file. - MRA
;-
function mms_edi_amb_l2_sdc, sc, mode, tstart, $
CAL_PATH_ROOT=cal_path_root, $
DATA_PATH_ROOT=data_path_root, $
DROPBOX_ROOT=dropbox_root, $
FILE_OUT=files, $
HK_ROOT=hk_root, $
LOG_PATH_ROOT=log_path_root, $
NO_LOG=no_log, $
PRELIMINARY=preliminary
	compile_opt idl2
	
	;Error handler
	catch, the_error
	if the_error ne 0 then begin
		catch, /CANCEL
		
		;Write error
		MrPrintF, 'LogErr'
		
		;Close log file
		log = MrStdLog(-2)
		
		;Unexpected trapped error
		files = ''
		if n_elements(status) eq 0 || status eq 0 $
			then status  = 100
		
		;Return error status
		return, status
	endif
	
	;Start timer
	t0 = systime(1)

	;Initialize
	;   - Setup directory structure
	unh_edi_init

;-----------------------------------------------------
; Check Inputs \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Assume error with inputs
	status = 100

	;Check type
	if ~isa(sc,     /SCALAR, 'STRING') then message, 'SC must be a scalar string.'
	if ~isa(mode,   /SCALAR, 'STRING') then message, 'MODE must be a scalar string.'
	if ~isa(tstart, /SCALAR, 'STRING') then message, 'TSTART must be a scalar string.'
	
	;Check value
	if max(sc eq ['mms1', 'mms2', 'mms3', 'mms4']) eq 0 $
		then message, 'SC must be "mms1", "mms2", "mms3", or "mms4".'
	if max(mode eq ['brst', 'srvy']) eq 0 $
		then message, 'MODE must be "srvy" or "brst".'
	
	;Defaults
	tf_log    = ~keyword_set(no_log)
	tf_prelim = keyword_set(preliminary)
	cal_path  = n_elements(cal_path_root)  eq 0 ? !edi_init.cal_path_root  : cal_path_root
	data_path = n_elements(data_path_root) eq 0 ? !edi_init.data_path_root : data_path_root
	dropbox   = n_elements(dropbox_root)   eq 0 ? !edi_init.dropbox_root   : dropbox_root
	hk_path   = n_elements(hk_root)        eq 0 ? !edi_init.hk_root        : hk_root
	log_path  = n_elements(log_path_root)  eq 0 ? !edi_init.log_path_root  : log_path_root

	;Check permissions
	if ~file_test(log_path, /DIRECTORY, /WRITE) $
		then message, 'LOG_PATH_ROOT must exist and be writeable.'
	if ~file_test(cal_path, /DIRECTORY, /READ) $
		then message, 'CAL_PATH_ROOT directory must exist and be readable.'
	if ~file_test(data_path, /DIRECTORY, /READ) $
		then message, 'DATA_PATH_ROOT directory must exist and be readable.'
	if ~file_test(dropbox, /DIRECTORY, /READ, /WRITE) $
		then message, 'DROPBOX_ROOT directory must exist and be read- and writeable.'
	if ~file_test(hk_path, /DIRECTORY, /READ) $
		then message, 'HK_ROOT directory must exist and be readable.'

	;Constants for source files
	instr   = 'edi'
	level   = 'l1a'
	optdesc = 'amb'
	
	;Constants for destination files
	outmode    = mode
	outlevel   = 'l2'
	status     = 0

;-----------------------------------------------------
; Create Log File \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Parse input time
	mms_parse_time, tstart, syr, smo, sday, shr, smin, ssec
	
	;Current time
	caldat, systime(0, /JULIAN, /UTC), month, day, year, hour, minute, second
	now = string(FORMAT='(%"%04i%02i%02i_%02i%02i%02i")', year, month, day, hour, minute, second)

	;Build log file
	fLog = strjoin([sc, instr, mode, level, optdesc, tstart, now], '_') + '.log'
	
	;Build log directory
	;   - Create the directory if it does not exist
	;   - log_path/amb/ql/mode/year/month[/day]
	fDir = mode eq 'brst' ? filepath('', ROOT_DIR=log_path, SUBDIRECTORY=[sc, instr, mode, outlevel, optdesc, syr, smo, sday]) $
	                      : filepath('', ROOT_DIR=log_path, SUBDIRECTORY=[sc, instr, mode, outlevel, optdesc, syr, smo])
	if ~file_test(fDir, /DIRECTORY) then file_mkdir, fDir
	
	;Create the log file
	if tf_log then !Null = MrStdLog(filepath(fLog, ROOT_DIR=fDir))

;-----------------------------------------------------
; Find FAST/BRST file \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	if mode eq 'brst' || mode eq 'srvy' || mode eq 'fast' then begin
		;fast or burst?
		fmode = mode eq 'brst' ? mode : 'fast'
	
		;Search for the file
		edi_files = mms_latest_file(dropbox, sc, instr, fmode, level, tstart, $
		                            OPTDESC=optdesc, ROOT=data_path)
		
		;No FAST/BRST files found
		if edi_files eq '' then begin
			MrPrintF, 'LogText', string(sc, instr, fmode, level, optdesc, tstart, $
			                            FORMAT='(%"No %s %s %s %s %s files found for start time %s.")')
		endif
	endif
	
;-----------------------------------------------------
; Find SLOW Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;No "slow" files if we are searching for "brst"
	if mode eq 'srvy' || mode eq 'slow' then begin
		slow_file = mms_latest_file(dropbox, sc, instr, 'slow', level, tstart, $
		                            OPTDESC=optdesc, ROOT=data_path)
		
		;No SLOW files found
		if slow_file eq '' then begin
			MrPrintF, 'LogText', string(sc, instr, 'slow', level, optdesc, tstart, $
			                            FORMAT='(%"No %s %s %s %s %s files found for start time %s.")')
		endif
		
		;Combine slow and fast
		if mode eq 'srvy' && edi_files ne '' then begin
			if slow_file ne '' then edi_files = [slow_file, edi_files]
		endif else begin
			edi_files = slow_file
		endelse
	endif

	;Zero files found
	if edi_files[0] eq '' then begin
		status = 103
		message, 'No EDI files found.'
	endif
	
;-----------------------------------------------------
; Find CAL Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	cal_file = mms_edi_amb_cal_find(sc)
	
	;No SLOW files found
	if cal_file eq '' then begin
		status = 103
		message, string(sc, instr, 'cal', 'l2', optdesc, tstart, $
		                FORMAT='(%"No %s %s %s %s %s files found for start time %s.")')
	endif
	
;-----------------------------------------------------
; Find SunPulse Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;There are no brst HK files, so we must trim the hour, minutes, and
	;seconds off TSTART in order to find the file.
	hk_time = mode eq 'brst' ? strmid(tstart, 0, 8) : tstart
	dss_file = mms_latest_file(dropbox, sc, 'fields', 'hk', 'l1b', hk_time, $
	                           OPTDESC='101', ROOT=hk_path)

	;No file found
	if dss_file eq '' then begin
		status = 103
		message, 'No DSS file found.'
	endif
	
;-----------------------------------------------------
; Find DEFATT Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	defatt_file = mms_anc_search(dropbox, sc, 'defatt', tstart, $
	                             COUNT = count, $
	                             ROOT  = data_path)
	
	;No file found
	if count eq 0 then begin
		status = 103
		message, 'No DEFATT files found.'
	endif

;-----------------------------------------------------
; Process Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Write parents to log file
	MrPrintF, 'LogText', ''
	MrPrintF, 'LogText', '---------------------------------'
	MrPrintF, 'LogText', '| Parent Files                  |'
	MrPrintF, 'LogText', '---------------------------------'
	MrPrintF, 'LogText', edi_files
	MrPrintF, 'LogText', cal_file
	MrPrintF, 'LogText', dss_file
	MrPrintF, 'LogText', defatt_file
	MrPrintF, 'LogText', '---------------------------------'
	MrPrintF, 'LogText', ''

	;Process data
	edi_data = mms_edi_amb_l2_create( edi_files, cal_file, dss_file, defatt_file, $
	                                  STATUS = status_temp, $
	                                  ABSCAL = ~tf_prelim )
	
	;Empty file?
	if status eq 102 then begin
		status     = 2B
		empty_file = 1B
		
	;Read ok
	endif else if status lt 100 then begin
		;Pick the biggest status
		status    >= status_temp
		empty_file = 0B
	
	;Error
	endif else begin
		message, 'Error created L2 data.'
	endelse

;-----------------------------------------------------
; Data Products \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	
	;Parent files
	parents = file_basename([edi_files, cal_file, dss_file, defatt_file])

	;Data products to be written
	outoptdesc = tag_names(edi_data)
	nOptDesc   = n_elements(outoptdesc)
	files      = strarr(nOptDesc)
	
	;Loop over data sets
	for i = 0, nOptDesc - 1  do begin
		;Convert underscores to hyphens
		outdesc = strlowcase(strjoin(strsplit(outoptdesc[i], '_', /EXTRACT), '-'))
		if tf_prelim then outdesc += '-noabs'

	;-----------------------------------------------------
	; Make Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		;ALTERNATING
		;   - Must come before field-aligned mode ("amb" matches "amb-alt" and "amb-perp")
		if stregex(outdesc, 'amb-alt', /BOOLEAN) then begin
			;Create the file
			files[i] = mms_edi_amb_l2_mkfile_alt(sc, mode, outdesc, tstart, $
			                                     BRST           = (mode eq 'brst'), $
			                                     DROPBOX_ROOT   = dropbox, $
			                                     DATA_PATH_ROOT = data_path, $
			                                     EMPTY_FILE     = empty_file, $
			                                     PARENTS        = parents, $
			                                     STATUS         = stemp)
		
		;FIELD-ALIGNED
		endif else if stregex(outdesc, '^amb', /BOOLEAN) then begin
			;Create the file
			files[i] = mms_edi_amb_l2_mkfile_fa(sc, mode, outdesc, tstart, $
			                                    BRST           = (mode eq 'brst'), $
			                                    DROPBOX_ROOT   = dropbox, $
			                                    DATA_PATH_ROOT = data_path, $
			                                    EMPTY_FILE     = empty_file, $
			                                    PARENTS        = parents, $
			                                    STATUS         = stemp)
		
		;????
		endif else begin
			message, 'Unknown data product: "' + outoptdesc + '".'
		endelse

		;Check status
		status >= stemp
		if files[i] eq '' then begin
			MrPrintF, 'LogErr', 'Error making ' + instr + ' ' + outlevel + ' ' + outdesc + ' file.'
			continue
		endif

	;-----------------------------------------------------
	; Write Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		;ALTERNATING
		;   - Must come before field-aligned mode ("amb" matches "amb-alt" and "amb-perp")
		;   - After data is written to the file, it is removed from the structure
		;       * Data structure element 0 (zero) always contains the data to be written
		if stregex(outdesc, 'amb-alt', /BOOLEAN) then begin
			if ~empty_file then stemp = mms_edi_amb_l2_write_alt(files[i], edi_data.(0))
		
		;FIELD-ALIGNED
		endif else if stregex(outdesc, 'amb', /BOOLEAN) then begin
			if ~empty_file then stemp = mms_edi_amb_l2_write_fa(files[i], edi_data.(0))
		
		;????
		endif else begin
			message, 'Unknown data product: "' + outoptdesc + '".'
		endelse
		
		;Free up some data
		edi_data = MrStruct_RemoveTags(edi_data, outoptdesc[i])

		;Check status
		status >= stemp
		if stemp ge 100 then begin
			MrPrintF, 'LogErr', 'Error writing to L2 file.'
			continue
		endif
	endfor

;-----------------------------------------------------
; Finish Up \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Time elapsed
	dt     = systime(1) - t0
	dt_hr  = floor((dt) / 3600.0)
	dt_min = floor( (dt mod 3600.0) / 60.0 )
	dt_sec = dt mod 60
	
	;Write destination to log file
	MrPrintF, 'LogText', files, FORMAT='(%"File written to:    \"%s\".")'
	MrPrintF, 'LogText', dt_hr, dt_min, dt_sec, FORMAT='(%"Total process time: %ihr %imin %0.3fs")'
	
	;Close the log file by returning  output to stderr
	!Null = MrStdLog('stderr')
	
	;Return STATUS: 0 => everything OK
	return, status
end