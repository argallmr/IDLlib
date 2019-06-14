; docformat = 'rst'
;
;+
;   Compute the derivative of the velocity of a relativistic particle with a given energy
;   (does not account for massless particles).
;
;   Starting with
;       E = m c^{2} ( \gamma - 1 )
;
;   solve for v in \gamma
;       v = sqrt{ c^{2} \left[ 1 - \left( \frac{1} { \frac{KE}{m c^{2}} + 1 } \right)^{2} \right] }
;
;   Pulling m c^{2} out of the denominator and noting that the rest energe E0 = mc^2.
;       v = c sqrt{ 1 - \left( \frac{ E_{0} } { E_{0} + E } \right)^{2} }
;
;   Compute the derivative
;       dv = \frac{ 2 c E_{0}^{2} } { E_{0} + E }^{3} dE
;
; :Categories:
;   Plasma Physics Utilties
;
; :Params:
;       E:                  in, required, type=fltarr
;                           Kinetic energy of the particle in electron volts (eV)
;       DE:                 in, required, type=fltarr
;                           Derivative of `E` of the particle in electron volts (eV)
;       M:                  in, required, type=float
;                           The mass of a particle species in kilograms (Kg).
;
; :Returns:
;       DV:                 Derivative of the velocity of the particle. (km/s)
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
;       2017/01/03  -   Written by Matthew Argall
;-
FUNCTION mrrel_dv, E, dE, m
	Compile_Opt strictarr
	On_Error, 2

	;Compute the gamma factor
	c    = MrConstants('c')
	J2eV = MrConstants('J2eV')

	;Rest mass
	E0 = J2eV * m * c^2
	
	;Relativistic velocity
	dv = 2 * c * E0^2 * dE / (E0 + E)^3

	RETURN, dv * 1e-3
END
