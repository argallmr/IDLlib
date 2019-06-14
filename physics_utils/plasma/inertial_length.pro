; docformat = 'rst'
;
;+
;   The purpose of this program is to calculate the inertial length for species k::
;
;       \lambda_{k} = \frac{c} {\omega_{p,k}}
;
; :Categories:
;   Physics Utilties, Plasma
;
; :Params:
;       N:                  in, required, type=numeric array
;                           Plasma density in units of particles per centimeter cubed (cm^{-3}).
;       PARTICLE:           in, required, type=string, default='H+'
;                           The name of the particle for which the cyclotron frequency
;                               is to be calculated. Options are::
;                                   'H+'
;                                   'He+'
;                                   'O+'
;                                   'e-'
;
; :Returns:
;       lambda:             The inertial length (skin depth) of the species indicated
;                               by `PARTICLE`.
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
;       07/05/2013  -   Written by Matthew Argall
;       07/15/2013  -   Units are assumed to be cm^-3, km.
;-
function inertial_length, n, particle
	compile_opt idl2
	on_error, 2

	;compute the inertial length
	;   - Multiply by 1e-3 for m -> km
	omega_p = w_plasma(n, particle)
	lambda = ( 1e-3 * constants('c') ) / omega_p
	
	return, lambda
end
