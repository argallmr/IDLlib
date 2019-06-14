; docformat = 'rst'
;
;+
;   The purpose of this program is to calculate the lower hybrid frequency::
;
;       \omega_{lh} = ( \frac{1}{\Omega_{i} \Omega_{e}} + \frac{1}{\Omega_{i}^{2}} )^{-1/2}
;
; :Categories:
;   Physics Utilties
;
; :Params:
;       B:                  in, required, type=fltarr
;                           Magnitude of the magnetic field, |B|, in units of nano-Tesla (nT).
;       N:                  in, required, type=numeric array
;                           Plasma density in units of particles per centimeter cubed (cm^{-3}).
;
; :Keywords:
;       PARTICLE:           in, optional, type=string, default='H+'
;                           The name of the particle for which the cyclotron frequency
;                               is to be calculated. Options are::
;                                   'H+'
;                                   'He+'
;                                   'O+'
;                                   'e-'
;
; :Returns:
;       OMEGA_LH:           Cyclotron frequency in Hertz (rad/sec)
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 113
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@wildcats.unh.edu
;
; :History:
;   Modification History::
;       01/29/2012  -   Written by Matthew Argall
;       07/15/2013  -   Units are now assumed to be nT and cm^-3. Angular frequency is
;                           returned, not frequency. - MRA
;       2016/12/08  -   Quantity raised to negative square root (not positive). - MRA
;-
function w_lower_hybrid, B, n_i
    compile_opt idl2
    on_error, 2

;---------------------------------------------------------------------
;CALCULATE THE LOWER HYBRID FREQUENCY ////////////////////////////////
;---------------------------------------------------------------------
	omega_lh = (1.0 / (w_cyclotron(B, 'e-') * w_cyclotron(B, 'H+')) + $
	            1.0 / w_plasma(n_i, 'H+')^2)^(-1.0/2.0)
	
	return, omega_lh
end