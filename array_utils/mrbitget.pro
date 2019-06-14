; docformat = 'rst'
;
; NAME:
;    MrBitGet
;
; PURPOSE:
;+
;   Get the value of a particular bit (e.g., 1=on, 0=off).
;
; :Examples:
;   IDL> mrbitget(32766S, reverse(bindgen(15)+1B))
;      1   1   1   1   1   1   1   1   1   1   1   1   1   1   0
;
; :Params:
;       A:          in, required, type=numeric
;                   Array for which bits are get.
;       BIT:        in, optional, type=integer, default=reverse(bindgen(maxbit)+1B)
;                   Bit to get. If not provided and `A` is scalar, the state of all
;                       possible bits for the given datatype will be returned, starting
;                       at bit N and decreasing to bit 1.
;
; :Keywords:
;       TYPE:       in, required, type=string/integer
;                   Assumed type of A, specified as a type code or name. The default
;                       is to use the datatype of `A`. If `A` is a floating point array
;                       then the closest matching integer class is used
;                       (float=long, double=long64).
;
; :Returns:
;       RESULT:     Adjust integers, the same type as A.
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
;       2016/09/13  -   Written by Matthew Argall
;       2017/04/03  -   If `A` is scalar, then `BIT` can be undefined. - MRA
;-
function MrBitGet, A, bit, $
TYPE=type
	compile_opt idl2
	on_error, 2
	
	;Number of elements given
	nA    = n_elements(A)
	nBits = n_elements(bit)
	
	;Check inputs
	if n_elements(type) eq 0 then type = size(A, /TNAME)
	N = nA > nBits
	if nA    gt 1 && nA    ne N then message, 'A has an incorrect number of elements.'
	if nBits gt 1 && nBits ne N then message, 'BITS has an incorrect number of elements.'
	
	;Make sure we have scalars
	if nA    eq 1 then A   = A[0]
	if nBits eq 1 then bit = bit[0]
	
	;Convert type
	if size(type, /TNAME) ne 'STRING' then begin
		case type of
			 1: tname = 'BYTE'
			 2: tname = 'INT'
			 3: tname = 'LONG'
			 4: tname = 'FLOAT'
			 5: tname = 'DOUBLE'
			 6: tname = 'COMPLEX'
			 9: tname = 'DCOMPLEX'
			12: tname = 'UINT'
			13: tname = 'ULONG'
			14: tname = 'LONG64'
			15: tname = 'ULONG64'
			else: message, 'Datatype unknown: (' + strtrim(type, 2) + ').'
		endcase
	endif else begin
		tname = type
	endelse
	
	case strupcase(tname) of
		'BYTE':     maxBit = 8
		'INT':      maxBit = 16
		'LONG':     maxBit = 32
		'FLOAT':    maxBit = 32
		'DOUBLE':   maxBit = 64
		'COMPLEX':  maxBit = 32
		'DCOMPLEX': maxBit = 64
		'UINT':     maxBit = 16
		'ULONG':    maxBit = 32
		'LONG64':   maxBit = 64
		'ULONG64':  maxBit = 64
		else: message, 'Datatype unknown: "' + type + '.'
	endcase
	
	;Default to checking all bits
	if nA eq 1 && nBits eq 0 then bit = reverse(bindgen(maxBit)+1B)
	
	;Check valid bit value
	if ~array_equal(bit gt 0 and bit le maxBit, 1) $
		then message, 'BIT is out of range for datatype: "' + tname + '".'
	
	;Does the bit need to be set?
	result = ((A and 2^(bit-1)) ne 0)

	;Return
	return, result
end
