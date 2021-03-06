; docformat = 'rst'
;
; NAME:
;       mms_fig_fields.pro
;
;*****************************************************************************************
;   Copyright (c) 2014, Matthew Argall                                                   ;
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
;       * Neither the name of the <ORGANIZATION> nor the names of its contributors may   ;
;         be used to endorse or promote products derived from this software without      ;
;         specific prior written permission.                                             ;
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
;   Create a plot of FIELDS data
;       1) DFG Magnetic Field
;       2) EDP Electric Field
;       3) EDP Spacecraft Potential
;       4) EDI 0-degree ambient counts
;       5) EDI 180-degree ambient counts
;       6) EDI Anisotropy (0/180 counts)
;
; :Params:
;       SC:                 in, required, type=string/strarr
;                           Spacecraft for which data is to be plotted.
;       TSTART:             in, required, type=string
;                           Start time of the data interval to read, as an ISO-8601 string.
;       TEND:               in, required, type=string
;                           End time of the data interval to read, as an ISO-8601 string.
;
; :Keywords:
;       EIGVECS:        out, optional, type=3x3 float
;                       Rotation matrix (into the minimum variance coordinate system).
;-
function mms_fig_xprox, sc, tstart, tend, $
EIGVECS=eigvecs
	compile_opt strictarr

	;Catch errors
	catch, the_error
	if the_error ne 0 then begin
		catch, /cancel
		void = cgErrorMsg(/QUIET)
		return, !Null
	endif
	
	mode = 'brst' ; 'brst' | 'srvy'

;-----------------------------------------------------
; Find Data Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;FGM Magnetic Field
	mms_fgm_ql_read, sc, 'dfg', mode, 'l2pre', tstart, tend, $
	                 B_GSE = b_gse, $
	                 TIME  = t_fgm
	
	;FPI Ion Density and Velocity
	if mode eq 'srvy' then begin
		mms_fpi_sitl_read, sc, 'fast', tstart, tend, $
		                   VI_DSC = v, $
		                   N_I    = n, $
		                   TIME   = t_fpi
	endif else begin
		mms_fpi_l1b_moms_read, sc, 'des-moms', tstart, tend, $
		                       N     = n, $
		                       V_GSE = v, $
		                       TIME  = t_fpi
	endelse
		
	;EDP Electric Field
	edp_mode = mode eq 'brst' ? mode : 'fast'
	mms_edp_ql_read, sc, edp_mode, tstart, tend, $
	                 E_DSL = e_dsl, $
	                 TIME  = t_edp
	
	;SCP
	mms_edp_l2_scpot_read, sc, edp_mode, tstart, tend, $
	                       SCPOT = scpot, $
	                       TIME  = t_scpot
	
	;Get definitive attitude data
	defatt = mms_fdoa_defatt(sc, tstart, tend)
	
	;Rotate EDP to GSE
	e_gse = mms_rot_despun2gse(defatt, t_edp, temporary(e_dsl), TYPE='L')

;-----------------------------------------------------
; Plot Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	t_fgm_ssm = MrCDF_epoch2ssm(t_fgm, t_fgm[0])
	t_fpi_ssm = MrCDF_epoch2ssm(t_fpi, t_fgm[0])
	t_edp_ssm = MrCDF_epoch2ssm(t_edp, t_fgm[0])

	;MMS Colors
	mms_color = mms_color(['blue', 'green', 'red', 'black'])

	;Create the window
	win   = MrWindow(XSIZE=600, YGAP=0.5, REFRESH=0)
	
	;BL
	p_BL = MrPlot(t_fgm_ssm, b_gse[2,*], $
	              /CURRENT, $
	              COLOR       = 'Red', $
	              NAME        = 'BL', $
	              XTICKFORMAT = '(a1)', $
	              YTITLE      = 'B$\downL$!C(nT)')
	
	;BM
	p_BM = MrPlot(t_fgm_ssm, b_gse[1,*], $
	              /CURRENT, $
	              COLOR       = 'Forest Green', $
	              NAME        = 'BM', $
	              XTICKFORMAT = '(a1)', $
	              YTITLE      = 'B$\downM$!C(nT)')
	
	;NI
	p_ni = MrPlot(t_fpi_ssm, n, $
	              /CURRENT, $
	              NAME        = 'ni', $
	              XTICKFORMAT = '(a1)', $
	              YTITLE      = 'N$\downi$!C(1/cm$\up3$)')
	
	;ViL
	p_ni = MrPlot(t_fpi_ssm, v[2,*], $
	              /CURRENT, $
	              COLOR       = 'Red', $
	              NAME        = 'ViL', $
	              XTICKFORMAT = '(a1)', $
	              YTITLE      = 'V$\downiL$!C(km/s)')
	
	;EN
	p_En = MrPlot(t_edp_ssm, e_gse[2,*], $
	              /CURRENT, $
	              COLOR       = 'Blue', $
	              NAME        = 'EN', $
	              XTICKFORMAT = 'time_labels', $
	              YTITLE      = 'E$\downiN$!C(mV/m)')
	
	win -> Refresh
	return, win
end