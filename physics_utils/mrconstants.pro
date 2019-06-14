; docformat = 'rst'
;
; NAME:
;       CONSTANTS
;
; PURPOSE:
;+
;       The purpose of this program is to create a look-up table of physical constants
;       and their values. Available constants are::
;
;             au        - astronomical unit
;             c         - speed of light in a vacuum
;             epsilon_0 - permittivity of free space
;             h         - Plank consant
;             k_b       - Boltzmann constant
;             m_e       - electron mass
;             m_p       - proton mass
;             mu_0      - permeability of free space
;             n_a       - Avagadros number
;             q         - elementary charge
;             q_e       - electron charge (-q)
;             re        - Radius of Earth
;
; :Categories:
;       Physics Utilities, Physical Constants
;
; :Params:
;       CONST:          in, optional, type=string
;                       The name of the physical constant to be returned. If not given,
;                           a list of available constants will be printed to the command
;                           window.
;
; :Keywords:
;       DOUBLE:         in, optional, type=Boolean, default=0
;                       Give the constants in double precision.
;       MKS:            in, optional, type=Boolean, default=1
;                       Return values in MKS units.
;       CGS:            in, optional, type=Boolean, default=0
;                       Return values in CGS units
;
; :Returns:
;       VALUE:          The value corresponding to the desired physical constant, `const`.
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
;
;       11/03/2011  -   Written by Matthew Argall
;       03/28/2013  -   Added DOUBLE keyword. - MRA
;       2016/09/03  -   Simplified logic by converting to single precision last. Added
;                           unit conversions. Renamed from constants.pro to MrConstants.pro - MRA
;       2018/04/30  -   Convert electron volts to kelvin and vice versa. - MRA
;-
function MrConstants, const, $
;KEYWORDS
DOUBLE = double, $
MKS = mks, $
CGS = cgs

  desc = [ ['Physical Constants:'], $
	       ['  c         - speed of light in a vacuum'], $
	       ['  m_e       - electron mass'             ], $
	       ['  m_p       - proton mass'               ], $
	       ['  m_H       - proton mass'               ], $
	       ['  m_He      - helium mass'               ], $
	       ['  m_O       - oxygen mass'               ], $
	       ['  epsilon_0 - permittivity of free space'], $
	       ['  mu_0      - permeability of free space'], $
	       ['  k_b       - Boltzmann constant'        ], $
	       ['  n_a       - Avagadros number'          ], $
	       ['  q_e       - electron charge (-q)'      ], $
	       ['  q         - elementary charge'         ], $
	       ['  re        - earth radii'               ], $
	       ['  au        - astronomical unit'         ], $
	       ['  h         - Plank consant'             ], $
	       ['  RE        - Radius of Earth'           ], $
	       [''], $
	       ['Unit Conversions:'], $
	       ['  cm2m      - centimeters to meters'     ], $
	       ['  eV2J      - electron volts to joules'  ], $
	       ['  eV2K      - electron volts to kelvin'  ], $
	       ['  g2kg      - grams to kilograms'        ], $
	       ['  J2eV      - joules to electron volts'  ], $
	       ['  K2eV      - Kelvin to electron volts'  ], $
	       ['  kg2g      - kilograms to grams'        ], $
	       ['  m2km      - meters to kilometers'      ], $
	       ['  m2cm      - meters to centimeters'     ] $
	     ]

	if n_params() eq 0 then begin
		print, desc
		return, !values.f_nan
	endif

;-----------------------------------------------------
; Constants \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	case strlowcase(const) of
		;PHYSICAL CONSTANTS
		'c':         value = 299792485.0d                 ;speed of light in vacuum     ;m/s
		'm_e':       value = 9.10938188d  * 1d-31         ;electron mass                ;kg
		'm_p':       value = 1.67262158d  * 1d-27         ;proton mass                  ;kg
		'm_h':       value = 1.67262158d  * 1d-27         ;proton mass                  ;kg
		'm_he':      value = 6.64648d     * 1d-27         ;helium mass                  ;kg
		'm_o':       value = 2.65676d     * 1d-26         ;oxygen mass                  ;kg
		'epsilon_0': value = 8.85418782d  * 1d-12         ;permittivity of free space   ;A^2 s^4 / (kg m^3)
		'mu_0':      value = 1.25663706d  * 1d-6          ;permeability of free space   ;m kg / (s^2 A^2)
		'k_b':       value = 1.3806503d   * 1d-23         ;Boltzmann's Constant         ;m^2 kg / (s^2 K)
		'n_a':       value = 6.0221415d   * 1d23          ;Avagadro's Number            ;
		'q_e':       value = -1.60217646d * 1d-19         ;electron charge              ;C
		'q':         value = 1.60217646d  * 1d-19         ;elementary charge            ;C
		're':        value = 6378100.0d                   ;earth radius                 ;m
		'au':        value = 149597870700.0d              ;astronomical unit            ;m
		'h':         value = 6.626068d    * 1d-34         ;Plank's constant             ;m^2 kg /s
		're':        value = 6378100d                     ;Radius of Earth              ;m
	
		;UNIT CONVERSION FACTORS
		'cm2m':      value = 1d-2                         ;Centimeters to meters
		'ev2j':      value = 1.60218d-19                  ;Electron volts to Joules
		'ev2k':      value = 11604.505d                    ;Electron volts to Kelvin
		'g2kg':      value = 1d3                          ;Grams to kilograms
		'j2ev':      value = 6.242d18                     ;Joules to electron volts
		'k2ev':      value = 8.621738d-5                  ;Kelvin to electron volts
		'kg2g':      value = 1d-3                         ;Kilograms to grams
		'm2km':      value = 1d-3                         ;Meters to kilometers
		'm2cm':      value = 1d2                          ;Meters to centimeters
		else: begin
			print, desc
			message, 'Constant ' + const + ' not available.'
		endcase
	endcase

;-----------------------------------------------------
; Convert to CGS \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	if keyword_set(cgs) then begin
		;Conversion factors
		m2cm = 1.0d-2
		kg2g = 1.0d-3
	
		;Covnert
		case const of
			'c':         value = value * m2cm
			'm_e':       value = value * kg2g
			'm_p':       value = value * kg2g
			'epsilon_0': value = value * 1.0/(kg2g * cm2m^3)
			'mu_0':      value = value * m2cm * kg2g
			'k_b':       value = value * m2cm * kg2g
			're':        value = value * m2cm
			'au':        value = value * m2cm
			'h':         value = value * m2cm^2 * kg2g
			else: ;Do nothing. The value is already in CGS units
		endcase
	endif

;-----------------------------------------------------
; Single Precision \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	if ~keyword_set(double) then value = float(value)

	return, value
end
