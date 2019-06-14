; docformat = 'rst'
;
; NAME:
;
;       FA_SYSTEM
;
; PURPOSE:
;+
;       The purpose of this program is to caluclate the average magnetic field over an
;       interval and form a coordinate system that has its z-axis pointing along the
;       average field.
;
; :Categories:
;
;       Physics Utility, Coordinate Systems
;
; :Params:
;       DATA:               in, required, type=3xN numeric
;                           The data which for which the field-aligned coordinate system
;                               is to be calculated.
;       NAVG:               in, optional, required, type=int/float
;                           The number of points to average when finding the background
;                               field strength. Required if `AVG_DATA` is not provided.
;
; :Keywords:
;       AVG_DATA:           out, optional, type=same as `DATA`
;                           Either a vector, the same size as `DATA`, specifying the mean
;                               field at each point, or a named variable into which the
;                               mean field will be returned.
;       ISMEAN:             in, optional, type=boolean
;                           If set, then `DATA` is the average, background field. In this
;                               case, no averaging will be performed.
;       EDGE_TRUNCATE:      in, optional, type=boolean, default=1
;                           If set, data will be edge-truncated. See IDL's SMOOTH function
;                               for details.
;       _REF_EXTRA:         in, optional, type=any
;                           Any additional keyword accepted by IDL's Smooth function
;                           
; :Returns:
;       FAS:                The field-aligned coordinate system.
;
; :Uses:
;   Uses the following external programs::
;       nfft_intervals.pro
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 348
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@unh.edu
;
; :Copyright:
;       Matthew Argall 2013
;
; :History::
;   Modification History::
;       04/10/2013  -   Written by Matthew Argall
;       08/02/2013  -   Renamed from "field_aligned_system" to "fa_system". AVG_DATA can
;                           now be an input. - MRA
;       08/03/2013  -   Added keyword ISMEAN. - MRA
;       2013-11-01  -   Added the EDGE_TRUNCATE and _REF_EXTRA keywords. - MRA
;       2013-11-29  -   The z-axis of the FA-system always points toward +z in the
;                           old system. Update library programs. - MRA
;       2017-11-22  -   Do not flip the z-axis if Bz < 0. FAS is ALWAYS along the field - MRA
;-
function fa_system, data, navg, $
AVG_DATA = avg_data, $
EDGE_TRUNCATE=edge_truncate, $
ISMEAN = isMean, $
_REF_EXTRA=extra
    compile_opt idl2

;-----------------------------------------------------
;Check Inputs \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

    if n_elements(edge_truncate) eq 0 then edge_truncate=1
    npts = n_elements(data[0,*])
    fas = fltarr(3,3,npts)
 
;-----------------------------------------------------
;Calculate the Field-Aligned System \\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if keyword_set(isMean) eq 0 then begin
        avg_data = fltarr(3,npts)
        avg_data[0,*] = smooth(data[0,*], navg, EDGE_TRUNCATE=edge_truncate, _STRICT_EXTRA=extra)
        avg_data[1,*] = smooth(data[1,*], navg, EDGE_TRUNCATE=edge_truncate, _STRICT_EXTRA=extra)
        avg_data[2,*] = smooth(data[2,*], navg, EDGE_TRUNCATE=edge_truncate, _STRICT_EXTRA=extra)
    endif else avg_data = data

    ;The z-axis will be along the average field direction
    z_hat = MrVector_Normalize(avg_data)

    ;Since many common coordinate systems (e.g. GSE, GSM) are defined with the x-axis
    ;pointing towards the sun, we will find the x-axis by crossing [0, 1, 0] with Z_HAT.
    x_hat = MrVector_Cross([0, 1, 0], z_hat)
    x_hat = MrVector_Normalize(x_hat)

    ;Compute y_hat
    y_hat = MrVector_Cross(z_hat, x_hat)
    y_hat = MrVector_Normalize(y_hat)

    ;Put the unit vectors along the rows.
    ;                    | x_hat(x)    x_hat(y)   x_hat(z) |
    ; fa_system[*,*,i] = | y_hat(x)    y_hat(y)   y_hat(z) |
    ;                    | z_hat(x)    z_hat(y)   z_hat(z) |
    fas = reform([temporary(x_hat), temporary(y_hat), temporary(z_hat)], 3, 3, npts)

    return, fas
end