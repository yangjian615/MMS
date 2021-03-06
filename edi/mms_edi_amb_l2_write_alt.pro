; docformat = 'rst'
;
; NAME:
;    mms_edi_amb_l2_write_alt
;
; PURPOSE:
;+
;   Write CDF files of alternating pitch angle mode EDI ambient data.
;
; :Categories:
;    MMS, EDI, L2, Ambient
;
; :Params:
;       AMB_FILE:           in, required, type=string
;                           Name of the file to which data is written.
;       AMB_DATA:           in, required, type=struct
;                           EDI ambient data structure with the following fields::
;
; :Keywords:
;       DROPBOX_ROOT:       in, optional, type=string, default=pwd
;                           Directory into which files are saved. It is expected that
;                               externally to this program, files are moved into their
;                               final destination in `DATA_PATH`.
;       DATA_PATH_ROOT:     in, optional, type=string, default=pwd
;                           Root of an MMS SDC-like directory structure. This is used
;                               in conjunction with `DROPBOX` to determine the z-version
;                               of the output file.
;       OPTDESC:            in, optional, type=string, default='amb'
;                           Optional filename descriptor, with parts separated by a hyphen.
;       PARENTS:            in, optional, type=string/strarr, default=''
;                           Names of the parent files required to make `AMB_DATA`.
;       STATUS:             out, required, type=byte
;                           An error code. Values are:::
;                               OK      = 0
;                               Warning = 1-99
;                               Error   = 100-255
;                                   100      -  Unexpected trapped error
;
; :Returns:
;       AMB_FILE:           Name of the file created.
;
; :See Also:
;   mms_edi_amb_l2_create.pro
;   mms_edi_amb_l2_mkfile_alt.pro
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
;       2016/09/28  -   Written by Matthew Argall
;-
function mms_edi_amb_l2_write_alt, amb_file, amb_data
	compile_opt idl2
	
	catch, the_error
	if the_error ne 0 then begin
		catch, /CANCEL
		
		;Close and delete the file, if it was created
		if obj_valid(oamb) then obj_destroy, oamb
		if n_elements(amb_file) gt 0 && file_test(amb_file) then file_delete, amb_file
		
		;Report error
		if n_elements(status) eq 0 || status eq 0 then status = 100
		MrPrintF, 'LogErr'
		
		;Return
		return, status
	endif
	
	;Everything starts out ok
	status = 0
	
	;Parse the file name
	mms_dissect_filename, amb_file, SC=sc, INSTR=instr, MODE=mode, LEVEL=level, OPTDESC=optdesc
	
	;Preliminary dataset?
	tf_abscal = ~stregex(optdesc, 'noabs', /BOOLEAN)
	datatype  = tf_abscal ? 'FLOAT' : 'ULONG'

;------------------------------------;
; Check Data and Open File           ;
;------------------------------------;
	;
	; Check sizes
	;
	if ~isa(amb_data.epoch_fa,          'LONG64') then message, 'amb_data.epoch_fa must be LONG64.'
	if ~isa(amb_data.epoch_timetag,     'LONG64') then message, 'amb_data.epoch_timetag must be LONG64.'
	if ~isa(amb_data.optics,            'BYTE')   then message, 'amb_data.optics must be BYTE.'
	if ~isa(amb_data.flip_flag,         'BYTE')   then message, 'amb_data.flip_flag must be BYTE.'
	if ~isa(amb_data.energy_gdu1,       'UINT')   then message, 'amb_data.energy_gdu1 must be UINT.'
	if ~isa(amb_data.energy_gdu2,       'UINT')   then message, 'amb_data.energy_gdu2 must be UINT.'
	if ~isa(amb_data.gdu_0,             'BYTE')   then message, 'amb_data.gdu_0 must be BYTE.'
	if ~isa(amb_data.gdu_180,           'BYTE')   then message, 'amb_data.gdu_180 must be BYTE.'
	if ~isa(amb_data.dwell,             'FLOAT')  then message, 'amb_data.dwell must be FLOAT.'
	if ~isa(amb_data.counts_0,          datatype) then message, 'amb_data.counts_0 must be '       + datatype + '.'
	if ~isa(amb_data.counts_90_gdu1,    datatype) then message, 'amb_data.counts_90_gdu1 must be ' + datatype + '.'
	if ~isa(amb_data.counts_90_gdu2,    datatype) then message, 'amb_data.counts_90_gdu2 must be ' + datatype + '.'
	if ~isa(amb_data.counts_180,        datatype) then message, 'amb_data.counts_180 must be '     + datatype + '.'
	if ~isa(amb_data.delta_0,           datatype) then message, 'amb_data.delta_0 must be '        + datatype + '.'
	if ~isa(amb_data.delta_90_gdu2,     datatype) then message, 'amb_data.delta_90_gdu2 must be '  + datatype + '.'
	if ~isa(amb_data.delta_90_gdu2,     datatype) then message, 'amb_data.delta_90_gdu2 must be '  + datatype + '.'
	if ~isa(amb_data.delta_180,         datatype) then message, 'amb_data.delta_180 must be '      + datatype + '.'
	if ~isa(amb_data.traj_dbcs_0,       'FLOAT')  then message, 'amb_data.traj_dbcs_0 must be FLOAT.'
	if ~isa(amb_data.traj_dbcs_90_gdu1, 'FLOAT')  then message, 'amb_data.traj_dbcs_90_gdu1 must be FLOAT.'
	if ~isa(amb_data.traj_dbcs_90_gdu2, 'FLOAT')  then message, 'amb_data.traj_dbcs_90_gdu2 must be FLOAT.'
	if ~isa(amb_data.traj_dbcs_180,     'FLOAT')  then message, 'amb_data.traj_dbcs_180 must be FLOAT.'
	if ~isa(amb_data.traj_gse_0,        'FLOAT')  then message, 'amb_data.traj_gse_0 must be FLOAT.'
	if ~isa(amb_data.traj_gse_90_gdu1,  'FLOAT')  then message, 'amb_data.traj_gse_90_gdu1 must be FLOAT.'
	if ~isa(amb_data.traj_gse_90_gdu2,  'FLOAT')  then message, 'amb_data.traj_gse_90_gdu2 must be FLOAT.'
	if ~isa(amb_data.traj_gse_180,      'FLOAT')  then message, 'amb_data.traj_gse_180 must be FLOAT.'
;	if ~isa(amb_data.traj_gsm_0,        'FLOAT')  then message, 'amb_data.traj1_gsm_0 must be FLOAT.'
;	if ~isa(amb_data.traj_gsm_180,      'FLOAT')  then message, 'amb_data.traj1_gsm_180 must be FLOAT.'

	;Open the CDF file
	oamb = MrCDF_File(amb_file, /MODIFY)
	if obj_valid(oamb) eq 0 then message, 'Could not open file for writing: "' + amb_file + '".'

;------------------------------------------------------
; Variable Names                                      |
;------------------------------------------------------
	; Variable naming convention
	;   scId_instrumentId_paramName[_coordSys][_paramQualifier][_subModeLevel][_mode][_level]
	prefix  = strjoin([sc, instr], '_') + '_'
	suffix  = '_' + strjoin([mode, level], '_')
	
	t_vname                   = 'Epoch'
	t_fa_vname                = 'Epoch_0_180'
	t_perp_vname              = 'Epoch_90'
	t_tt_vname                = 'epoch_timetag'
	optics_vname              = prefix + 'optics_state'       + suffix
	flip_vname                = prefix + 'flip'               + suffix
	dwell_vname               = prefix + 'dwell'              + suffix
	e_gdu1_vname              = prefix + 'energy_gdu1'        + suffix
	e_gdu2_vname              = prefix + 'energy_gdu2'        + suffix
	gdu_0_vname               = prefix + 'gdu_0'              + suffix
	gdu_180_vname             = prefix + 'gdu_180'            + suffix
	flux1_0_vname             = prefix + 'flux1_0'            + suffix
	flux2_0_vname             = prefix + 'flux2_0'            + suffix
	flux3_0_vname             = prefix + 'flux3_0'            + suffix
	flux4_0_vname             = prefix + 'flux4_0'            + suffix
	flux1_90_gdu1_vname       = prefix + 'flux1_90_gdu1'      + suffix
	flux2_90_gdu1_vname       = prefix + 'flux2_90_gdu1'      + suffix
	flux3_90_gdu1_vname       = prefix + 'flux3_90_gdu1'      + suffix
	flux4_90_gdu1_vname       = prefix + 'flux4_90_gdu1'      + suffix
	flux1_90_gdu2_vname       = prefix + 'flux1_90_gdu2'      + suffix
	flux2_90_gdu2_vname       = prefix + 'flux2_90_gdu2'      + suffix
	flux3_90_gdu2_vname       = prefix + 'flux3_90_gdu2'      + suffix
	flux4_90_gdu2_vname       = prefix + 'flux4_90_gdu2'      + suffix
	flux1_180_vname           = prefix + 'flux1_180'          + suffix
	flux2_180_vname           = prefix + 'flux2_180'          + suffix
	flux3_180_vname           = prefix + 'flux3_180'          + suffix
	flux4_180_vname           = prefix + 'flux4_180'          + suffix
	traj1_dbcs_0_vname        = prefix + 'traj1_dbcs_0'       + suffix
	traj2_dbcs_0_vname        = prefix + 'traj2_dbcs_0'       + suffix
	traj3_dbcs_0_vname        = prefix + 'traj3_dbcs_0'       + suffix
	traj4_dbcs_0_vname        = prefix + 'traj4_dbcs_0'       + suffix
	traj1_dbcs_90_gdu1_vname  = prefix + 'traj1_dbcs_90_gdu1' + suffix
	traj2_dbcs_90_gdu1_vname  = prefix + 'traj2_dbcs_90_gdu1' + suffix
	traj3_dbcs_90_gdu1_vname  = prefix + 'traj3_dbcs_90_gdu1' + suffix
	traj4_dbcs_90_gdu1_vname  = prefix + 'traj4_dbcs_90_gdu1' + suffix
	traj1_dbcs_90_gdu2_vname  = prefix + 'traj1_dbcs_90_gdu2' + suffix
	traj2_dbcs_90_gdu2_vname  = prefix + 'traj2_dbcs_90_gdu2' + suffix
	traj3_dbcs_90_gdu2_vname  = prefix + 'traj3_dbcs_90_gdu2' + suffix
	traj4_dbcs_90_gdu2_vname  = prefix + 'traj4_dbcs_90_gdu2' + suffix
	traj1_dbcs_180_vname      = prefix + 'traj1_dbcs_180'     + suffix
	traj2_dbcs_180_vname      = prefix + 'traj2_dbcs_180'     + suffix
	traj3_dbcs_180_vname      = prefix + 'traj3_dbcs_180'     + suffix
	traj4_dbcs_180_vname      = prefix + 'traj4_dbcs_180'     + suffix
	traj1_gse_0_vname         = prefix + 'traj1_gse_0'        + suffix
	traj2_gse_0_vname         = prefix + 'traj2_gse_0'        + suffix
	traj3_gse_0_vname         = prefix + 'traj3_gse_0'        + suffix
	traj4_gse_0_vname         = prefix + 'traj4_gse_0'        + suffix
	traj1_gse_90_gdu1_vname   = prefix + 'traj1_gse_90_gdu1'  + suffix
	traj2_gse_90_gdu1_vname   = prefix + 'traj2_gse_90_gdu1'  + suffix
	traj3_gse_90_gdu1_vname   = prefix + 'traj3_gse_90_gdu1'  + suffix
	traj4_gse_90_gdu1_vname   = prefix + 'traj4_gse_90_gdu1'  + suffix
	traj1_gse_90_gdu2_vname   = prefix + 'traj1_gse_90_gdu2'  + suffix
	traj2_gse_90_gdu2_vname   = prefix + 'traj2_gse_90_gdu2'  + suffix
	traj3_gse_90_gdu2_vname   = prefix + 'traj3_gse_90_gdu2'  + suffix
	traj4_gse_90_gdu2_vname   = prefix + 'traj4_gse_90_gdu2'  + suffix
	traj1_gse_180_vname       = prefix + 'traj1_gse_180'      + suffix
	traj2_gse_180_vname       = prefix + 'traj2_gse_180'      + suffix
	traj3_gse_180_vname       = prefix + 'traj3_gse_180'      + suffix
	traj4_gse_180_vname       = prefix + 'traj4_gse_180'      + suffix
;	traj1_gsm_0_vname         = prefix + 'traj1_gsm_0'        + suffix
;	traj2_gsm_0_vname         = prefix + 'traj2_gsm_0'        + suffix
;	traj3_gsm_0_vname         = prefix + 'traj3_gsm_0'        + suffix
;	traj4_gsm_0_vname         = prefix + 'traj4_gsm_0'        + suffix
;	traj1_gsm_180_vname       = prefix + 'traj1_gsm_180'      + suffix
;	traj2_gsm_180_vname       = prefix + 'traj2_gsm_180'      + suffix
;	traj3_gsm_180_vname       = prefix + 'traj3_gsm_180'      + suffix
;	traj4_gsm_180_vname       = prefix + 'traj4_gsm_180'      + suffix

	delta1_0_vname       = prefix + 'flux1_0_delta'       + suffix
	delta2_0_vname       = prefix + 'flux2_0_delta'       + suffix
	delta3_0_vname       = prefix + 'flux3_0_delta'       + suffix
	delta4_0_vname       = prefix + 'flux4_0_delta'       + suffix
	delta1_90_gdu1_vname = prefix + 'flux1_90_delta_gdu1' + suffix
	delta2_90_gdu1_vname = prefix + 'flux2_90_delta_gdu1' + suffix
	delta3_90_gdu1_vname = prefix + 'flux3_90_delta_gdu1' + suffix
	delta4_90_gdu1_vname = prefix + 'flux4_90_delta_gdu1' + suffix
	delta1_90_gdu2_vname = prefix + 'flux1_90_delta_gdu2' + suffix
	delta2_90_gdu2_vname = prefix + 'flux2_90_delta_gdu2' + suffix
	delta3_90_gdu2_vname = prefix + 'flux3_90_delta_gdu2' + suffix
	delta4_90_gdu2_vname = prefix + 'flux4_90_delta_gdu2' + suffix
	delta1_180_vname     = prefix + 'flux1_180_delta'     + suffix
	delta2_180_vname     = prefix + 'flux2_180_delta'     + suffix
	delta3_180_vname     = prefix + 'flux3_180_delta'     + suffix
	delta4_180_vname     = prefix + 'flux4_180_delta'     + suffix

;------------------------------------------------------
; Write Support Data                                  |
;------------------------------------------------------

	;Write variable data to file
	oamb -> WriteVar, t_fa_vname,    amb_data.epoch_fa
	oamb -> WriteVar, t_perp_vname,  amb_data.epoch_perp
	oamb -> WriteVar, t_tt_vname,    amb_data.epoch_timetag
	oamb -> WriteVar, optics_vname,  amb_data.optics
	oamb -> WriteVar, flip_vname,    amb_data.flip_flag
	oamb -> WriteVar, e_gdu1_vname,  amb_data.energy_gdu1
	oamb -> WriteVar, e_gdu2_vname,  amb_data.energy_gdu2
	oamb -> WriteVar, gdu_0_vname,   amb_data.gdu_0
	oamb -> WriteVar, gdu_180_vname, amb_data.gdu_180
	oamb -> WriteVar, dwell_vname,   amb_data.dwell

;------------------------------------------------------
; Write Flux Data                                     |
;------------------------------------------------------
	if mode eq 'brst' then begin
		;Flux
		oamb -> WriteVar, flux1_0_vname,       amb_data.counts_0[*,0]
		oamb -> WriteVar, flux2_0_vname,       amb_data.counts_0[*,1]
		oamb -> WriteVar, flux3_0_vname,       amb_data.counts_0[*,2]
		oamb -> WriteVar, flux4_0_vname,       amb_data.counts_0[*,3]
		oamb -> WriteVar, flux1_90_gdu1_vname, amb_data.counts_90_gdu1[*,0]
		oamb -> WriteVar, flux2_90_gdu1_vname, amb_data.counts_90_gdu1[*,1]
		oamb -> WriteVar, flux3_90_gdu1_vname, amb_data.counts_90_gdu1[*,2]
		oamb -> WriteVar, flux4_90_gdu1_vname, amb_data.counts_90_gdu1[*,3]
		oamb -> WriteVar, flux1_90_gdu2_vname, amb_data.counts_90_gdu2[*,0]
		oamb -> WriteVar, flux2_90_gdu2_vname, amb_data.counts_90_gdu2[*,1]
		oamb -> WriteVar, flux3_90_gdu2_vname, amb_data.counts_90_gdu2[*,2]
		oamb -> WriteVar, flux4_90_gdu2_vname, amb_data.counts_90_gdu2[*,3]
		oamb -> WriteVar, flux1_180_vname,     amb_data.counts_180[*,0]
		oamb -> WriteVar, flux2_180_vname,     amb_data.counts_180[*,1]
		oamb -> WriteVar, flux3_180_vname,     amb_data.counts_180[*,2]
		oamb -> WriteVar, flux4_180_vname,     amb_data.counts_180[*,3]
		
		;Errors
		oamb -> WriteVar, delta1_0_vname,       amb_data.delta_0[*,0]
		oamb -> WriteVar, delta2_0_vname,       amb_data.delta_0[*,1]
		oamb -> WriteVar, delta3_0_vname,       amb_data.delta_0[*,2]
		oamb -> WriteVar, delta4_0_vname,       amb_data.delta_0[*,3]
		oamb -> WriteVar, delta1_90_gdu1_vname, amb_data.delta_90_gdu1[*,0]
		oamb -> WriteVar, delta2_90_gdu1_vname, amb_data.delta_90_gdu1[*,1]
		oamb -> WriteVar, delta3_90_gdu1_vname, amb_data.delta_90_gdu1[*,2]
		oamb -> WriteVar, delta4_90_gdu1_vname, amb_data.delta_90_gdu1[*,3]
		oamb -> WriteVar, delta1_90_gdu2_vname, amb_data.delta_90_gdu2[*,0]
		oamb -> WriteVar, delta2_90_gdu2_vname, amb_data.delta_90_gdu2[*,1]
		oamb -> WriteVar, delta3_90_gdu2_vname, amb_data.delta_90_gdu2[*,2]
		oamb -> WriteVar, delta4_90_gdu2_vname, amb_data.delta_90_gdu2[*,3]
		oamb -> WriteVar, delta1_180_vname,     amb_data.delta_180[*,0]
		oamb -> WriteVar, delta2_180_vname,     amb_data.delta_180[*,1]
		oamb -> WriteVar, delta3_180_vname,     amb_data.delta_180[*,2]
		oamb -> WriteVar, delta4_180_vname,     amb_data.delta_180[*,3]
	endif else begin
		;Flux
		oamb -> WriteVar, flux1_0_vname,       amb_data.counts_0
		oamb -> WriteVar, flux1_90_gdu1_vname, amb_data.counts_90_gdu1
		oamb -> WriteVar, flux1_90_gdu2_vname, amb_data.counts_90_gdu2
		oamb -> WriteVar, flux1_180_vname,     amb_data.counts_180
		
		;Errors
		oamb -> WriteVar, delta1_0_vname,       amb_data.delta_0
		oamb -> WriteVar, delta1_90_gdu1_vname, amb_data.delta_90_gdu1
		oamb -> WriteVar, delta1_90_gdu2_vname, amb_data.delta_90_gdu2
		oamb -> WriteVar, delta1_180_vname,     amb_data.delta_180
	endelse

;------------------------------------------------------
; Write Trajectory Data                               |
;------------------------------------------------------

	;BRST
	if mode eq 'brst' then begin
		
		;DBCS Trajectories
		oamb -> WriteVar, traj1_dbcs_0_vname,       amb_data.traj_dbcs_0[*,*,0]
		oamb -> WriteVar, traj2_dbcs_0_vname,       amb_data.traj_dbcs_0[*,*,1]
		oamb -> WriteVar, traj3_dbcs_0_vname,       amb_data.traj_dbcs_0[*,*,2]
		oamb -> WriteVar, traj4_dbcs_0_vname,       amb_data.traj_dbcs_0[*,*,3]
		oamb -> WriteVar, traj1_dbcs_90_gdu1_vname, amb_data.traj_dbcs_90_gdu1[*,*,0]
		oamb -> WriteVar, traj2_dbcs_90_gdu1_vname, amb_data.traj_dbcs_90_gdu1[*,*,1]
		oamb -> WriteVar, traj3_dbcs_90_gdu1_vname, amb_data.traj_dbcs_90_gdu1[*,*,2]
		oamb -> WriteVar, traj4_dbcs_90_gdu1_vname, amb_data.traj_dbcs_90_gdu1[*,*,3]
		oamb -> WriteVar, traj1_dbcs_90_gdu2_vname, amb_data.traj_dbcs_90_gdu2[*,*,0]
		oamb -> WriteVar, traj2_dbcs_90_gdu2_vname, amb_data.traj_dbcs_90_gdu2[*,*,1]
		oamb -> WriteVar, traj3_dbcs_90_gdu2_vname, amb_data.traj_dbcs_90_gdu2[*,*,2]
		oamb -> WriteVar, traj4_dbcs_90_gdu2_vname, amb_data.traj_dbcs_90_gdu2[*,*,3]
		oamb -> WriteVar, traj1_dbcs_180_vname,     amb_data.traj_dbcs_180[*,*,0]
		oamb -> WriteVar, traj2_dbcs_180_vname,     amb_data.traj_dbcs_180[*,*,1]
		oamb -> WriteVar, traj3_dbcs_180_vname,     amb_data.traj_dbcs_180[*,*,2]
		oamb -> WriteVar, traj4_dbcs_180_vname,     amb_data.traj_dbcs_180[*,*,3]
		
		;GSE Trajectories
		oamb -> WriteVar, traj1_gse_0_vname,       amb_data.traj_gse_0[*,*,0]
		oamb -> WriteVar, traj2_gse_0_vname,       amb_data.traj_gse_0[*,*,1]
		oamb -> WriteVar, traj3_gse_0_vname,       amb_data.traj_gse_0[*,*,2]
		oamb -> WriteVar, traj4_gse_0_vname,       amb_data.traj_gse_0[*,*,3]
		oamb -> WriteVar, traj1_gse_90_gdu1_vname, amb_data.traj_gse_90_gdu1[*,*,0]
		oamb -> WriteVar, traj2_gse_90_gdu1_vname, amb_data.traj_gse_90_gdu1[*,*,1]
		oamb -> WriteVar, traj3_gse_90_gdu1_vname, amb_data.traj_gse_90_gdu1[*,*,2]
		oamb -> WriteVar, traj4_gse_90_gdu1_vname, amb_data.traj_gse_90_gdu1[*,*,3]
		oamb -> WriteVar, traj1_gse_90_gdu2_vname, amb_data.traj_gse_90_gdu2[*,*,0]
		oamb -> WriteVar, traj2_gse_90_gdu2_vname, amb_data.traj_gse_90_gdu2[*,*,1]
		oamb -> WriteVar, traj3_gse_90_gdu2_vname, amb_data.traj_gse_90_gdu2[*,*,2]
		oamb -> WriteVar, traj4_gse_90_gdu2_vname, amb_data.traj_gse_90_gdu2[*,*,3]
		oamb -> WriteVar, traj1_gse_180_vname,     amb_data.traj_gse_180[*,*,0]
		oamb -> WriteVar, traj2_gse_180_vname,     amb_data.traj_gse_180[*,*,1]
		oamb -> WriteVar, traj3_gse_180_vname,     amb_data.traj_gse_180[*,*,2]
		oamb -> WriteVar, traj4_gse_180_vname,     amb_data.traj_gse_180[*,*,3]
		
		;GSM Trajectories
;		oamb -> WriteVar, traj1_gsm_0_vname,   amb_data.traj_gsm_0[*,*,0]
;		oamb -> WriteVar, traj2_gsm_0_vname,   amb_data.traj_gsm_0[*,*,1]
;		oamb -> WriteVar, traj3_gsm_0_vname,   amb_data.traj_gsm_0[*,*,2]
;		oamb -> WriteVar, traj4_gsm_0_vname,   amb_data.traj_gsm_0[*,*,3]
;		oamb -> WriteVar, traj1_gsm_180_vname, amb_data.traj_gsm_180[*,*,0]
;		oamb -> WriteVar, traj2_gsm_180_vname, amb_data.traj_gsm_180[*,*,1]
;		oamb -> WriteVar, traj3_gsm_180_vname, amb_data.traj_gsm_180[*,*,2]
;		oamb -> WriteVar, traj4_gsm_180_vname, amb_data.traj_gsm_180[*,*,3]
	
	;'SRVY'
	endif else begin
		;DBCS
		oamb -> WriteVar, traj1_dbcs_0_vname,       amb_data.traj_dbcs_0
		oamb -> WriteVar, traj1_dbcs_90_gdu1_vname, amb_data.traj_dbcs_90_gdu1
		oamb -> WriteVar, traj1_dbcs_90_gdu2_vname, amb_data.traj_dbcs_90_gdu2
		oamb -> WriteVar, traj1_dbcs_180_vname,     amb_data.traj_dbcs_180
		
		;GSE
		oamb -> WriteVar, traj1_gse_0_vname,       amb_data.traj_gse_0
		oamb -> WriteVar, traj1_gse_90_gdu1_vname, amb_data.traj_gse_90_gdu1
		oamb -> WriteVar, traj1_gse_90_gdu2_vname, amb_data.traj_gse_90_gdu2
		oamb -> WriteVar, traj1_gse_180_vname,     amb_data.traj_gse_180
		
		;GSM
;		oamb -> WriteVar, traj1_gsm_0_vname,   amb_data.traj_gsm_0
;		oamb -> WriteVar, traj1_gsm_180_vname, amb_data.traj_gsm_180
	endelse
	
;------------------------------------------------------
; Close the File                                      |
;------------------------------------------------------
	obj_destroy, oamb
	return, status
end