; docformat = 'rst'
;
; NAME:
;       mms_edi_read_efieldmode
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
; :Categories:
;   MMS, EDI, Bestarg
;
; :Params:
;       SC:             in, required, type=string
;                       MMS observatory/spacecraft number (e.g., 'mms1')
;       MODE:           in, required, type=string
;                       Data telemetry mode.
;       LEVEL:          in, required, type=string
;                       Data level.
;       TSTART:         in, required, type=string
;                       Start time of the data interval to read, as an ISO-8601 string.
;       TEND:           in, required, type=string
;                       End time of the data interval to read, as an ISO-8601 string.
;       EDI_DIR:        in, required, type=string
;                       Directory in which to find EDI data.
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
;                             'EPOCH_GD12'       -  Time (cdf_time_tt2000)
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
;                             'EPOCH_GD21'       -  Time (cdf_time_tt2000)
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
;-
function mms_edi_read_efieldmode, sc, mode, level, tstart, tend, $
DIRECTORY=edi_dir, $
QUALITY=quality
	compile_opt idl2
	
	catch, the_error
	if the_error ne 0 then begin
		catch, /CANCEL
		if n_elements(cdfIDs) gt 0 then $
			for i = 0, nFiles - 1 do if cdfIDs[i] ne 0 then cdf_close, cdfIDs[i]
		void = cgErrorMSG(/QUIET)
		return, !Null
	endif
	
	if n_elements(edi_dir) eq 0 then cd, CURRENT=edi_dir

;-----------------------------------------------------
; File and Varialble Names \\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Create the file name
	fname = mms_construct_filename(sc, 'edi', mode, level, $
	                               OPTDESC   = 'efield', $
	                               /TOKENS, $
	                               DIRECTORY = edi_dir)
	
	;Variable names for GD12
	phi_gd12_name         = mms_construct_varname(sc, 'edi', 'phi_gd12')
	theta_gd12_name       = mms_construct_varname(sc, 'edi', 'theta_gd12')
	tof_gd12_name         = mms_construct_varname(sc, 'edi', 'tof1_us')
	q_gd12_name           = mms_construct_varname(sc, 'edi', 'sq_gd12')
	e_gd12_name           = mms_construct_varname(sc, 'edi', 'e_gd12')
	code_length_gd12_name = mms_construct_varname(sc, 'edi', 'code_length_gd12')
	m_gd12_name           = mms_construct_varname(sc, 'edi', 'm_gd12')
	n_gd12_name           = mms_construct_varname(sc, 'edi', 'n_gd12')
	max_addr_gd12_name    = mms_construct_varname(sc, 'edi', 'max_addr_gd12')
	
	;Variable names for GD21
	phi_gd21_name         = mms_construct_varname(sc, 'edi', 'phi_gd21')
	theta_gd21_name       = mms_construct_varname(sc, 'edi', 'theta_gd21')
	tof_gd21_name         = mms_construct_varname(sc, 'edi', 'tof2_us')
	q_gd21_name           = mms_construct_varname(sc, 'edi', 'sq_gd21')
	e_gd21_name           = mms_construct_varname(sc, 'edi', 'e_gd21')
	code_length_gd21_name = mms_construct_varname(sc, 'edi', 'code_length_gd21')
	m_gd21_name           = mms_construct_varname(sc, 'edi', 'm_gd21')
	n_gd21_name           = mms_construct_varname(sc, 'edi', 'n_gd21')
	max_addr_gd21_name    = mms_construct_varname(sc, 'edi', 'max_addr_gd21')

;-----------------------------------------------------
; Read Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Search for files
	files = MrFile_Search(fname, /CLOSEST, $
	                      COUNT     = nFiles, $
	                      TSTART    = tstart, $
	                      TEND      = tend, $
	                      TIMEORDER ='%Y%M%d')
	if nFiles eq 0 then message, 'No EDI files found in "' + edi_dir + '".'

	;Open the files
	cdfIDs = lonarr(nFiles)
	for i = 0, nFiles - 1 do cdfIDs[i] = cdf_open(fname[i])

	;Read the data for GD12
	phi_gd12 = MrCDF_nRead(cdfIDs, phi_gd12_name, $
	                       DEPEND_0 = epoch_gd12, $
	                       TSTART   = tstart, $
	                       TEND     = tend)
	theta_gd12       = MrCDF_nRead(cdfIDs, theta_gd12_name,       TSTART=tstart, TEND=tend)
	tof_gd12         = MrCDF_nRead(cdfIDs, tof_gd12_name,         TSTART=tstart, TEND=tend)
	q_gd12           = MrCDF_nRead(cdfIDs, q_gd12_name,           TSTART=tstart, TEND=tend)
	e_gd12           = MrCDF_nRead(cdfIDs, e_gd12_name,           TSTART=tstart, TEND=tend)
	code_length_gd12 = MrCDF_nRead(cdfIDs, code_length_gd12_name, TSTART=tstart, TEND=tend)
	m_gd12           = MrCDF_nRead(cdfIDs, m_gd12_name,           TSTART=tstart, TEND=tend)
	n_gd12           = MrCDF_nRead(cdfIDs, n_gd12_name,           TSTART=tstart, TEND=tend)
	max_addr_gd12    = MrCDF_nRead(cdfIDs, max_addr_gd12_name,    TSTART=tstart, TEND=tend)

	;Read the data for GD21
	phi_gd21 = MrCDF_nRead(cdfIDs, phi_gd21_name, $
	                       DEPEND_0 = epoch_gd21, $
	                       TSTART   = tstart, $
	                       TEND     = tend)
	theta_gd21       = MrCDF_nRead(cdfIDs, theta_gd21_name,       TSTART=tstart, TEND=tend)
	tof_gd21         = MrCDF_nRead(cdfIDs, tof_gd21_name,         TSTART=tstart, TEND=tend)
	q_gd21           = MrCDF_nRead(cdfIDs, q_gd21_name,           TSTART=tstart, TEND=tend)
	e_gd21           = MrCDF_nRead(cdfIDs, e_gd21_name,           TSTART=tstart, TEND=tend)
	code_length_gd21 = MrCDF_nRead(cdfIDs, code_length_gd21_name, TSTART=tstart, TEND=tend)
	m_gd21           = MrCDF_nRead(cdfIDs, m_gd21_name,           TSTART=tstart, TEND=tend)
	n_gd21           = MrCDF_nRead(cdfIDs, n_gd21_name,           TSTART=tstart, TEND=tend)
	max_addr_gd21    = MrCDF_nRead(cdfIDs, max_addr_gd21_name,    TSTART=tstart, TEND=tend)
	
	;Close the files
	for i = 0, nFiles do cdf_close, cdfIDs[i]

;-----------------------------------------------------
; Filter by Quality? \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	if n_elements(quality) gt 0 then begin
		void = MrIsMember(quality, q_gd12, iq_gd12, COUNT=count_gd12)
		void = MrIsMember(quality, q_gd21, iq_gd21, COUNT=count_gd21)
		
		;GD12
		if count_gd12 gt 0 then begin
			epoch_gd12       = epoch_gd12[iq_gd12]
			phi_gd12         = phi_gd12[iq_gd12]
			theta_gd12       = theta_gd12[iq_gd12]
			tof_gd12         = tof_gd12[iq_gd12]
			q_gd12           = q_gd12[iq_gd12]
			e_gd12           = e_gd12[iq_gd12]
			code_length_gd12 = code_length_gd12[iq_gd12]
			m_gd12           = m_gd12[iq_gd12]
			n_gd12           = n_gd12[iq_gd12]
			max_addr_gd12    = max_addr_gd12[iq_gd12]
		endif else begin
			message, 'No beams of desired quality for GD12.', /INFORMATIONAL
		endelse
		
		;GD21
		if count_gd21 gt 0 then begin
			epoch_gd21       = epoch_gd21[iq_gd21]
			phi_gd21         = phi_gd21[iq_gd21]
			theta_gd21       = theta_gd21[iq_gd21]
			tof_gd21         = tof_gd21[iq_gd21]
			q_gd21           = q_gd21[iq_gd21]
			e_gd21           = e_gd21[iq_gd21]
			code_length_gd21 = code_length_gd21[iq_gd12]
			m_gd21           = m_gd21[iq_gd21]
			n_gd21           = n_gd21[iq_gd21]
			max_addr_gd21    = max_addr_gd21[iq_gd21]
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
; Firing Vectors \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Constant: Degrees -> Radians
	deg2rad = !pi / 180.0D
	
	if n_gd12 gt 0 then begin
		;Convert to radians
		azimuth_gd12 = phi_gd12   * deg2rad
		polar_gd12   = theta_gd12 * deg2rad
	
		;Convert to cartesian coordinates
		fv_gd12      = fltarr(3, n_elements(azimuth_gd12))
		fv_gd12[0,*] = sin(polar_gd12) * cos(azimuth_gd12)
		fv_gd12[1,*] = sin(polar_gd12) * sin(azimuth_gd12)
		fv_gd12[2,*] = cos(polar_gd12)
	endif
	
	if n_gd21 gt 0 then begin
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
; Return Structure \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;All data
	if n_gd12 gt 0 then begin
		edi_gd12 = { count_gd12:       n_gd12, $
		             epoch_gd12:       epoch_gd12, $
		             azimuth_gd12:     phi_gd12, $
		             polar_gd12:       theta_gd12, $
		             fv_gd12:          fv_gd12, $
		             tof_gd12:         tof_gd12, $
		             quality_gd12:     q_gd12, $
		             energy_gd12:      e_gd12, $
		             code_length_gd12: code_length_gd12, $
		             m_gd12:           m_gd12, $
		             n_gd12:           n_gd12, $
		             max_addr_gd12:    max_addr_gd12 $
		           }
	;Number of points found
	endif else edi_gd12 = {count_gd21: count_gd21}
	
	;All data
	if n_gd21 gt 0 then begin
		edi_gd21 = { count_gd21:       n_gd21, $
		             epoch_gd21:       epoch_gd21, $
		             azimuth_gd21:     phi_gd21, $
		             polar_gd21:       theta_gd21, $
		             fv_gd21:          fv_gd21, $
		             tof_gd21:         tof_gd21, $
		             quality_gd21:     q_gd21 $
		             energy_gd21:      e_gd21, $
		             code_length_gd21: code_length_gd21, $
		             m_gd21:           m_gd21, $
		             n_gd21:           n_gd21, $
		             max_addr_gd21:    max_addr_gd21 $
		           }
	;Number of points found
	endif else edi_gd12 = {count_gd21: count_gd21}
	
	;Return the data
	return, create_struct(edi_gd12, edi_gd21)
end