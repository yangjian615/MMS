; docformat = 'rst'
;
; NAME:
;       mms_edi_read_l1a_efield
;
;*****************************************************************************************
;   Copyright (c) 2015, University of New Hampshire                                      ;
;   All rights reserved.                                                                 ;
;                                                                                        ;
;   Redistribution and use in source and binary forms, with or without modification,     ;
;   are permitted provided that the following conditions are met:                        ;
;                                                                                        ;
;       * Redistributions of source code must retain the above copyright notice,         ;
;         this list of conditions and the following disclaimer.                          ;
;       * Redistributions in binary form must reproduce the above copyright notice,      ;
;         this list of conditions and the following disclaimer in the documentation      ;
;         and/or other materials provided with the distribution.                         ;
;       * Neither the name of the University of New Hampshire nor the names of its       ;
;         contributors may  be used to endorse or promote products derived from this     ;
;         software without specific prior written permission.                            ;
;                                                                                        ;
;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY  ;
;   EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES ;
;   OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT  ;
;   SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,       ;
;   INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED ;
;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR   ;
;   BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN     ;
;   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN   ;
;   ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH  ;
;   DAMAGE.                                                                              ;
;*****************************************************************************************
;
; PURPOSE:
;+
;   Read EDI electric field mode data.
;
;   Steps:
;       1) Read data from file
;       2) Filter by quality
;       3) Sort by time (only if "slow" and "fast" files were given)
;       4) Compute firing vectors from firing angles
;       5) Compute chip and code periods
;       6) Determine time of flight overflow
;       7) Expand GDU energies to have same time tags as COUNTS1
;       7) Return structure or array of structures
;
; :Categories:
;   MMS, EDI, Bestarg
;
; :Params:
;       FILES:          in, required, type=string/strarr
;                       Name of the EDI e-field mode file or files to be read.
;       TSTART:         in, optional, type=string
;                       Start time of the data interval to read, as an ISO-8601 string.
;       TEND:           in, optional, type=string
;                       End time of the data interval to read, as an ISO-8601 string.
;
; :Keywords:
;       DIRECTORY:      in, optional, type=string, default=pwd
;                       Directory in which to find EDI data.
;       QUALITY:        in, optional, type=integer/intarr, default=pwd
;                       Quality of EDI beams to return. Can be a scalar or vector with
;                           values [0, 1, 2, 3].
;
; :Returns:
;       EDI:            Structure of EDI data. Fields are below. If zero beams are
;                           detected from a GD pair, its fields will be missing from
;                           the output structure. Use COUNT_GD12 and COUNT_GD21 to test.
;                             'COUNT_GD12'       -  Number of points returned
;                             'TT2000_GD12'      -  Time (cdf_time_tt2000)
;                             'AZIMUTH_GD12'     -  Azimuthal firing angle (degrees)
;                             'POLAR_GD12'       -  Polar firing angle (degrees)
;                             'FV_GD12'          -  Firing vectors
;                             'TOF_GD12'         -  Time of flight (micro-seconds)
;                             'QUALITY_GD12'     -  Quality flag
;                             'ENERGY_GD12'      -  Energy
;                             'CODE_LENGTH_GD12' -  Code length
;                             'M_GD12'           -  Correlator length
;                             'N_GD12'           -  Correlator length
;                             'MAX_ADDR_GD12'    -  Max beam hit address
;
;                             'COUNT_GD21'       -  Number of points returned
;                             'TT2000_GD21'      -  Time (cdf_time_tt2000)
;                             'AZIMUTH_GD21'     -  Azimuthal firing angle (degrees)
;                             'POLAR_GD21'       -  Polar firing angle (degrees)
;                             'FV_GD21'          -  Firing vectors
;                             'TOF_GD21'         -  Time of flight (micro-seconds)
;                             'QUALITY_GD21'     -  Quality flag
;                             'ENERGY_GD21'      -  Energy
;                             'CODE_LENGTH_GD21' -  Code length
;                             'M_GD21'           -  Correlator length
;                             'N_GD21'           -  Correlator length
;                             'MAX_ADDR_GD21'    -  Max beam hit address
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 348
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@unh.edu
;
; :History:
;   Modification History::
;       2015/05/01  -   Written by Matthew Argall
;       2015/05/05  -   Return energy, code length, correlator n and m, and max_addr. - MRA
;       2015/05/06  -   CODELENGTH was actually NUM_CHIPS. Calculate CODE_LENGTH and
;                           CHIP_WIDTH. - MRA
;       2015/05/18  -   Accept file names instead of searching for files. TSTART and TEND
;                           parameters are now keywords. - MRA
;       2015/06/01  -   Renamed from mms_edi_read_efieldmode to mms_edi_read_l1a_efield. - MRA
;       2015/08/22  -   EPOCH fields renamed to TT2000. TSTART and TEND now
;                           parameters, not keywords. - MRA
;       2015/10/18  -   Added the STRUCTARR keyword. - MRA
;       2015/10/22  -   If slow and fast mode files are given, combine into srvy product. - MRA
;       2016/02/17  -   Renamed CODE_LENGTH and CHIP_WIDTH to TCODE and TCHIP, respectively.
;                           Return TCHIP and TCODE in micro-seconds. Read word14 and word15. - MRA
;       2016/02/18  -   Return optics state. - MRA
;-
function mms_edi_read_l1a_efield, files, tstart, tend, $
QUALITY=quality, $
STRUCTARR=structarr
	compile_opt idl2
	
	catch, the_error
	if the_error ne 0 then begin
		catch, /CANCEL
		if n_elements(cdfIDs) gt 0 then $
			for i = 0, nFiles - 1 do if cdfIDs[i] ne 0 then cdf_close, cdfIDs[i]
		MrPrintF, 'LogErr'
		return, !Null
	endif

;-----------------------------------------------------
; Check Input Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Number of files given
	nFiles    = n_elements(files)
	tf_struct = keyword_set(structarr)
	tf_sort   = 0B

	;Dissect the file name
	mms_dissect_filename, files, $
	                      INSTR   = instr, $
	                      LEVEL   = level, $
	                      MODE    = mode, $
	                      OPTDESC = optdesc, $
	                      SC      = sc
	
	;Ensure L1A EDI files were given
	if min(file_test(files, /READ)) eq 0 then message, 'Files must exist and be readable.'
	if min(sc      eq sc[0])    eq 0 then message, 'All files must be from the same spacecraft.'
	if min(instr   eq 'edi')    eq 0 then message, 'Only EDI files are allowed.'
	if min(level   eq 'l1a')    eq 0 then message, 'Only L1A files are allowed.'
	if min(optdesc eq 'efield') eq 0 then message, 'Only EDI eField-mode files are allowed.'
	if min(mode    eq mode[0])  eq 0 then begin
		if total( (mode eq 'fast') + (mode eq 'slow') ) eq n_elements(mode) $
			then tf_sort = 1 $
			else message, 'All files must have the same MODE.'
	endif

	;We now know all the files match, so keep on the the first value.
	if nFiles gt 1 then begin
		sc      = sc[0]
		instr   = instr[0]
		mode    = mode[0]
		level   = level[0]
		optdesc = optdesc[0]
	end

;-----------------------------------------------------
; Varialble Names \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;General variable names
	optics_name = mms_construct_varname(sc, instr, 'optics')
	
	;Variable names for GD12
	;   - TOF is a detector quantity, the rest are gun quantities
	phi_gd12_name       = mms_construct_varname(sc, instr, 'phi_gd12')
	theta_gd12_name     = mms_construct_varname(sc, instr, 'theta_gd12')
	tof_gd12_name       = mms_construct_varname(sc, instr, 'tof2_us')
	q_gd12_name         = mms_construct_varname(sc, instr, 'sq_gd12')
	e_gd12_name         = mms_construct_varname(sc, instr, 'e_gd12')
	num_chips_gd12_name = mms_construct_varname(sc, instr, 'numchips_gd12')
	m_gd12_name         = mms_construct_varname(sc, instr, 'm_gd12')
	n_gd12_name         = mms_construct_varname(sc, instr, 'n_gd12')
	max_addr_gd12_name  = mms_construct_varname(sc, instr, 'max_addr_gd12')
	word14_gd12_name    = mms_construct_varname(sc, instr, 'word14_gd12')
	word15_gd12_name    = mms_construct_varname(sc, instr, 'word15_gd12')
	
	;Variable names for GD21
	phi_gd21_name       = mms_construct_varname(sc, instr, 'phi_gd21')
	theta_gd21_name     = mms_construct_varname(sc, instr, 'theta_gd21')
	tof_gd21_name       = mms_construct_varname(sc, instr, 'tof1_us')
	q_gd21_name         = mms_construct_varname(sc, instr, 'sq_gd21')
	e_gd21_name         = mms_construct_varname(sc, instr, 'e_gd21')
	num_chips_gd21_name = mms_construct_varname(sc, instr, 'numchips_gd21')
	m_gd21_name         = mms_construct_varname(sc, instr, 'm_gd21')
	n_gd21_name         = mms_construct_varname(sc, instr, 'n_gd21')
	max_addr_gd21_name  = mms_construct_varname(sc, instr, 'max_addr_gd21')
	word14_gd21_name    = mms_construct_varname(sc, instr, 'word14_gd21')
	word15_gd21_name    = mms_construct_varname(sc, instr, 'word15_gd21')

;-----------------------------------------------------
; Read Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Open the files
	cdfIDs = lonarr(nFiles)
	for i = 0, nFiles - 1 do cdfIDs[i] = cdf_open(files[i])
	
	;Optics
	;   - OPTICS is not returned when /STRUCTARR is set -- it would have to be inflated.
	optics = MrCDF_nRead(cdfIDs, optics_name, TSTART=tstart, TEND=tend, DEPEND_0=epoch_timetag)

	;Read the data for GD12
	phi_gd12 = MrCDF_nRead(cdfIDs, phi_gd12_name, $
	                       DEPEND_0 = epoch_gd12, $
	                       TSTART   = tstart, $
	                       TEND     = tend)
	theta_gd12     = MrCDF_nRead(cdfIDs, theta_gd12_name,     TSTART=tstart, TEND=tend)
	tof_gd12       = MrCDF_nRead(cdfIDs, tof_gd12_name,       TSTART=tstart, TEND=tend)
	q_gd12         = MrCDF_nRead(cdfIDs, q_gd12_name,         TSTART=tstart, TEND=tend)
	e_gd12         = MrCDF_nRead(cdfIDs, e_gd12_name,         TSTART=tstart, TEND=tend, DEPEND_0=epoch_energy)
	num_chips_gd12 = MrCDF_nRead(cdfIDs, num_chips_gd12_name, TSTART=tstart, TEND=tend)
	m_gd12         = MrCDF_nRead(cdfIDs, m_gd12_name,         TSTART=tstart, TEND=tend)
	n_gd12         = MrCDF_nRead(cdfIDs, n_gd12_name,         TSTART=tstart, TEND=tend)
	max_addr_gd12  = MrCDF_nRead(cdfIDs, max_addr_gd12_name,  TSTART=tstart, TEND=tend)
	word14_gd12    = MrCDF_nRead(cdfIDs, word14_gd12_name,    TSTART=tstart, TEND=tend)
	word15_gd12    = MrCDF_nRead(cdfIDs, word15_gd12_name,    TSTART=tstart, TEND=tend)

	;Read the data for GD21
	phi_gd21 = MrCDF_nRead(cdfIDs, phi_gd21_name, $
	                       DEPEND_0 = epoch_gd21, $
	                       TSTART   = tstart, $
	                       TEND     = tend)
	theta_gd21     = MrCDF_nRead(cdfIDs, theta_gd21_name,     TSTART=tstart, TEND=tend)
	tof_gd21       = MrCDF_nRead(cdfIDs, tof_gd21_name,       TSTART=tstart, TEND=tend)
	q_gd21         = MrCDF_nRead(cdfIDs, q_gd21_name,         TSTART=tstart, TEND=tend)
	e_gd21         = MrCDF_nRead(cdfIDs, e_gd21_name,         TSTART=tstart, TEND=tend)
	num_chips_gd21 = MrCDF_nRead(cdfIDs, num_chips_gd21_name, TSTART=tstart, TEND=tend)
	m_gd21         = MrCDF_nRead(cdfIDs, m_gd21_name,         TSTART=tstart, TEND=tend)
	n_gd21         = MrCDF_nRead(cdfIDs, n_gd21_name,         TSTART=tstart, TEND=tend)
	max_addr_gd21  = MrCDF_nRead(cdfIDs, max_addr_gd21_name,  TSTART=tstart, TEND=tend)
	word14_gd21    = MrCDF_nRead(cdfIDs, word14_gd21_name,    TSTART=tstart, TEND=tend)
	word15_gd21    = MrCDF_nRead(cdfIDs, word15_gd21_name,    TSTART=tstart, TEND=tend)
	
	;Close the files
	for i = 0, nFiles - 1 do begin
		cdf_close, cdfIDs[i]
		cdfIDs[i] = 0L
	endfor

;-----------------------------------------------------
; Inflate Brst Variables \\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;
	; We want all of the data on a per-beam basis, so expand
	; all variables with time tag EPOCH_TIMETAG up to
	; EPOCH_GD[12/21].
	;
	; This is already done in the srvy files
	; It is done in brst files v0.1.0 or higher.
	;
	if n_elements(e_gd12) ne n_elements(epoch_gd12) then begin
		;Indicate we are inflating
		MrPrintF, 'LogText', 'Expanding energy to a per-beam.'
		
		;Extrapolate?
		dt    = fix(median(epoch_energy[1:*] - epoch_energy), TYPE=14)
		void  = where(epoch_gd12 lt epoch_energy[0] or $
		              epoch_gd12 gt epoch_energy[-1]+dt, nextrap_gd12)
		void  = where(epoch_gd21 lt epoch_energy[0] or $
		              epoch_gd21 gt epoch_energy[-1]+dt, nextrap_gd21)
		void = !Null
		
		;Issue warning
		if nextrap_gd12 gt 0 then $
			MrPrintF, 'LogWarn', nextrap, FORMAT='(%"Extrapolating %n points when inflating E-field GD12 data.")'
		if nextrap_gd21 gt 0 then $
			MrPrintF, 'LogWarn', nextrap, FORMAT='(%"Extrapolating %n points when inflating E-field GD21 data.")'
		
		;Locate count times within epoch timetag
		it_gd12 = value_locate(epoch_energy, epoch_gd12) > 0
		it_gd21 = value_locate(epoch_energy, epoch_gd21) > 0
		
		;Inflate variables
		e_gd12 = e_gd12[temporary(it_gd12)]
		e_gd21 = e_gd21[temporary(it_gd21)]
	endif

;-----------------------------------------------------
; Filter by Quality? \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	if n_elements(quality) gt 0 then begin
		void = MrIsMember(quality, q_gd12, it_gd12, COUNT=count_gd12, NCOMPLEMENT=nbad_gd12)
		void = MrIsMember(quality, q_gd21, iq_gd21, COUNT=count_gd21, NCOMPLEMENT=nbad_gd21)
		
		;GD12
		if nbad_gd12 gt 0 && count_gd12 gt 0 then begin
			epoch_gd12     = epoch_gd12[it_gd12]
			phi_gd12       = phi_gd12[it_gd12]
			theta_gd12     = theta_gd12[it_gd12]
			tof_gd12       = tof_gd12[it_gd12]
			q_gd12         = q_gd12[it_gd12]
			e_gd12         = e_gd12[it_gd12]
			num_chips_gd12 = num_chips_gd12[it_gd12]
			m_gd12         = m_gd12[it_gd12]
			n_gd12         = n_gd12[it_gd12]
			max_addr_gd12  = max_addr_gd12[it_gd12]
			word14_gd12    = word14_gd12[it_gd12]
			word15_gd12    = word15_gd12[it_gd12]
		endif else begin
			message, 'No beams of desired quality for GD12.', /INFORMATIONAL
		endelse
		
		;GD21
		if nbad_gd21 gt 0 && count_gd21 gt 0 then begin
			epoch_gd21     = epoch_gd21[iq_gd21]
			phi_gd21       = phi_gd21[iq_gd21]
			theta_gd21     = theta_gd21[iq_gd21]
			tof_gd21       = tof_gd21[iq_gd21]
			q_gd21         = q_gd21[iq_gd21]
			e_gd21         = e_gd21[iq_gd21]
			num_chips_gd21 = num_chips_gd21[iq_gd21]
			m_gd21         = m_gd21[iq_gd21]
			n_gd21         = n_gd21[iq_gd21]
			max_addr_gd21  = max_addr_gd21[iq_gd21]
			word14_gd21    = word14_gd21[it_gd21]
			word15_gd21    = word15_gd21[it_gd21]
		endif else begin
			message, 'No beams of desired quality for GD21.', /INFORMATIONAL
		endelse
		
		if count_gd12 + count_gd21 eq 0 then $
			message, 'No beams found of desired quality.'
			
	;No filter
	endif else begin
		count_gd12 = n_elements(epoch_gd12)
		count_gd21 = n_elements(epoch_gd21)
	endelse

;-----------------------------------------------------
; Survey Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Do we want to make srvy data from fast and slow?
	;   - Must sort in time.
	if tf_sort then begin
		if count_gd12 gt 0 then begin
			it_gd12        = sort(epoch_gd12)
			epoch_gd12     = epoch_gd12[it_gd12]
			phi_gd12       = phi_gd12[it_gd12]
			theta_gd12     = theta_gd12[it_gd12]
			tof_gd12       = tof_gd12[it_gd12]
			q_gd12         = q_gd12[it_gd12]
			e_gd12         = e_gd12[it_gd12]
			num_chips_gd12 = num_chips_gd12[it_gd12]
			m_gd12         = m_gd12[it_gd12]
			n_gd12         = n_gd12[it_gd12]
			max_addr_gd12  = max_addr_gd12[it_gd12]
			word14_gd12    = word14_gd12[it_gd12]
			word15_gd12    = word15_gd12[it_gd12]
		endif
		
		if count_gd21 gt 0 then begin
			it_gd21        = sort(epoch_gd21)
			epoch_gd21     = epoch_gd21[it_gd21]
			phi_gd21       = phi_gd21[it_gd21]
			theta_gd21     = theta_gd21[it_gd21]
			tof_gd21       = tof_gd21[it_gd21]
			q_gd21         = q_gd21[it_gd21]
			e_gd21         = e_gd21[it_gd21]
			num_chips_gd21 = num_chips_gd21[it_gd21]
			m_gd21         = m_gd21[it_gd21]
			n_gd21         = n_gd21[it_gd21]
			max_addr_gd21  = max_addr_gd21[it_gd21]
			word14_gd21    = word14_gd21[it_gd21]
			word15_gd21    = word15_gd21[it_gd21]
		endif
	endif

;-----------------------------------------------------
; Firing Vectors \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Constant: Degrees -> Radians
	deg2rad = !pi / 180.0D
	
	if count_gd12 gt 0 then begin
		;Convert to radians
		azimuth_gd12 = phi_gd12   * deg2rad
		polar_gd12   = theta_gd12 * deg2rad
	
		;Convert to cartesian coordinates
		fv_gd12      = fltarr(3, n_elements(azimuth_gd12))
		fv_gd12[0,*] = sin(polar_gd12) * cos(azimuth_gd12)
		fv_gd12[1,*] = sin(polar_gd12) * sin(azimuth_gd12)
		fv_gd12[2,*] = cos(polar_gd12)
	endif
	
	if count_gd21 gt 0 then begin
		;Convert to radians
		azimuth_gd21 = phi_gd21   * deg2rad
		polar_gd21   = theta_gd21 * deg2rad
		
		;Convert to cartesian coordinates
		fv_gd21      = fltarr(3, n_elements(azimuth_gd21))
		fv_gd21[0,*] = sin(polar_gd21) * cos(azimuth_gd21)
		fv_gd21[1,*] = sin(polar_gd21) * sin(azimuth_gd21)
		fv_gd21[2,*] = cos(polar_gd21)
	endif

;-----------------------------------------------------
; Calculate Chip Width \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;
	; From Hans Vaith concerning raw data:
	;
	;    tchip = 1e6 * n * m * 2^(-23) micro-seconds
	;    tcode = tchip * number_of_chips
	;
	;    n = 1,2,4,8  (the corresponding raw values are 0,1,2,3)
	;    m = 2,4,8,16 (the corresponding raw values are 3,2,1,0)
	;    number_of_chips = 255,511,1023 (corresponding raw values: 0,1,2)
	;
	; L1A file
	;    n and m are already converted from raw values
	;
	; Terminology
	;    tchip is also referred to as the chip period or chip width
	;    tcode is also referred to as the code period or code length
	;
	if count_gd12 gt 0 then begin
		tchip_gd12 = n_gd12 * m_gd12 * (1e6 * 2D^(-23))
		tcode_gd12 = tchip_gd12 * num_chips_gd12
	endif
	if count_gd21 gt 0 then begin
		tchip_gd21 = n_gd21 * m_gd21 * (1e6 * 2D^(-23))
		tcode_gd21 = tchip_gd21 * num_chips_gd21
	endif

;-----------------------------------------------------
; Overflow Time of Flight \\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	tof_ovrflw_gd12 = tof_gd12 eq -1e31
	tof_ovrflw_gd21 = tof_gd21 eq -1e31

;-----------------------------------------------------
; Array of Structures \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Array of structures
	if tf_struct then begin
		beam_struct = { tt2000:    0LL, $
		                azimuth:   0.0, $
		                energy:    0US, $
		                fv_123:    fltarr(3), $
		                gdu:       0B, $
		                polar:     0.0, $
		                quality:   0B, $
		                tof:       0.0, $
		                tof_ovfl:  0B, $
		                tChip:     0.0D, $
		                tCode:     0.0D, $
		                numchips:  0US, $
		                m:         0B, $
		                n:         0B, $
		                max_addr:  0B, $
		                word14:    0S, $
		                word15:    0US $
		              }
		
		;Create an array of beam structures
		edi_l1a = replicate(beam_struct, count_gd12 + count_gd21)
		
		;GD12
		if count_gd12 gt 0 then begin
			edi_l1a[0:count_gd12-1].tt2000    = reform(temporary(epoch_gd12))
			edi_l1a[0:count_gd12-1].gdu       = 1B
			edi_l1a[0:count_gd12-1].azimuth   = reform(temporary(azimuth_gd12))
			edi_l1a[0:count_gd12-1].polar     = reform(temporary(polar_gd12))
			edi_l1a[0:count_gd12-1].fv_123    = temporary(fv_gd12)
			edi_l1a[0:count_gd12-1].quality   = reform(temporary(q_gd12))
			edi_l1a[0:count_gd12-1].energy    = reform(temporary(e_gd12))
			edi_l1a[0:count_gd12-1].tChip     = reform(temporary(tchip_gd12))
			edi_l1a[0:count_gd12-1].tCode     = reform(temporary(tcode_gd12))
			edi_l1a[0:count_gd12-1].numchips  = reform(temporary(num_chips_gd12))
			edi_l1a[0:count_gd12-1].m         = reform(temporary(m_gd12))
			edi_l1a[0:count_gd12-1].n         = reform(temporary(n_gd12))
			edi_l1a[0:count_gd12-1].max_addr  = reform(temporary(max_addr_gd12))
			edi_l1a[0:count_gd12-1].tof       = reform(temporary(tof_gd12))
			edi_l1a[0:count_gd12-1].tof_ovfl  = reform(temporary(tof_ovrflw_gd12))
			edi_l1a[0:count_gd12-1].word14    = reform(temporary(word14_gd12))
			edi_l1a[0:count_gd12-1].word15    = reform(temporary(word15_gd12))
		endif
		
		;GD21
		if count_gd21 gt 0 then begin
			edi_l1a[count_gd12:*].tt2000    = reform(temporary(epoch_gd21))
			edi_l1a[count_gd12:*].gdu       = 2B
			edi_l1a[count_gd12:*].azimuth   = reform(temporary(azimuth_gd21))
			edi_l1a[count_gd12:*].polar     = reform(temporary(polar_gd21))
			edi_l1a[count_gd12:*].fv_123    = temporary(fv_gd21)
			edi_l1a[count_gd12:*].quality   = reform(temporary(q_gd21))
			edi_l1a[count_gd12:*].energy    = reform(temporary(e_gd21))
			edi_l1a[count_gd12:*].tChip     = reform(temporary(tchip_gd21))
			edi_l1a[count_gd12:*].tCode     = reform(temporary(tcode_gd21))
			edi_l1a[count_gd12:*].numchips  = reform(temporary(num_chips_gd21))
			edi_l1a[count_gd12:*].m         = reform(temporary(m_gd21))
			edi_l1a[count_gd12:*].n         = reform(temporary(n_gd21))
			edi_l1a[count_gd12:*].max_addr  = reform(temporary(max_addr_gd21))
			edi_l1a[count_gd12:*].tof       = reform(temporary(tof_gd21))
			edi_l1a[count_gd12:*].tof_ovfl  = reform(temporary(tof_ovrflw_gd21))
			edi_l1a[count_gd12:*].word14    = reform(temporary(word14_gd21))
			edi_l1a[count_gd12:*].word15    = reform(temporary(word15_gd21))
		endif

;-----------------------------------------------------
; Structure of Arrays \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	endif else begin
		edi = { epoch_timetag: temporary(epoch_timetag), $
		        optics:        temporary(optics) $
		      }

		if count_gd12 gt 0 then begin
			edi_gd12 = { count_gd12:       temporary(count_gd12), $
			             tt2000_gd12:      temporary(epoch_gd12), $
			             azimuth_gd12:     temporary(phi_gd12), $
			             polar_gd12:       temporary(theta_gd12), $
			             fv_gd12_123:      temporary(fv_gd12), $
			             tof_gd12:         temporary(tof_gd12), $
			             quality_gd12:     temporary(q_gd12), $
			             energy_gd12:      temporary(e_gd12), $
			             tchip_gd12:       temporary(tchip_gd12), $
			             tcode_gd12:       temporary(tcode_gd12), $
			             num_chips_gd12:   temporary(num_chips_gd12), $
			             m_gd12:           temporary(m_gd12), $
			             n_gd12:           temporary(n_gd12), $
			             max_addr_gd12:    temporary(max_addr_gd12), $
			             word14_gd12:      temporary(word14_gd12), $
			             word15_gd12:      temporary(word15_gd12) $
			           }
		;Number of points found
		endif else edi_gd12 = {count_gd21: count_gd21}
		
		;All data
		if count_gd21 gt 0 then begin
			edi_gd21 = { count_gd21:       temporary(count_gd21), $
			             tt2000_gd21:      temporary(epoch_gd21), $
			             azimuth_gd21:     temporary(phi_gd21), $
			             polar_gd21:       temporary(theta_gd21), $
			             fv_gd21_123:      temporary(fv_gd21), $
			             tof_gd21:         temporary(tof_gd21), $
			             quality_gd21:     temporary(q_gd21), $
			             energy_gd21:      temporary(e_gd21), $
			             tchip_gd21:       temporary(tchip_gd21), $
			             tcode_gd21:       temporary(tcode_gd21), $
			             num_chips_gd21:   temporary(num_chips_gd21), $
			             m_gd21:           temporary(m_gd21), $
			             n_gd21:           temporary(n_gd21), $
			             max_addr_gd21:    temporary(max_addr_gd21), $
			             word14_gd21:      temporary(word14_gd21), $
			             word15_gd21:      temporary(word15_gd21) $
			           }
		;Number of points found
		endif else edi_gd12 = {count_gd21: count_gd21}
		
		;Combine structures
		edi_l1a = create_struct(temporary(edi), temporary(edi_gd12), temporary(edi_gd21))
	endelse
	
	;Return the data
	return, edi_l1a
end