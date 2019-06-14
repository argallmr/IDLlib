; docformat = 'rst'
;
; NAME:
;    MrBitSet
;
; PURPOSE:
;+
;   Set the value of a particular bit (e.g., 1=on, 0=off). Note that Bit 1 is 2^0.
;
; :Params:
;       A:          in, required, type=numeric
;                   Array for which bits are set.
;       BIT:        in, required, type=integer
;                   Bit to set
;       V:          in, optional, type=boolean, default=1
;                   Set `BIT` to this value. 0=set, non-zero=unset
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
;       2017/04/03  -   Handle case when A is scalar and BIT is an array. - MRA
;-
function MrBitSet, A, bit, V, $
TYPE=type
	compile_opt idl2
	on_error, 2
	
	;Number of elements given
	nA    = n_elements(A)
	nBits = n_elements(bit)
	
	;Values
	if n_elements(type) eq 0 then type = size(A, /TNAME)
	if n_elements(V)    eq 0 then V    = replicate(1, nA)
	nV = n_elements(V)
	
	;Check inputs
	N = nA > nBits > nV
	if nA    gt 1 && nA    ne N then message, 'A has an incorrect number of elements.'
	if nBits gt 1 && nBits ne N then message, 'BITS has an incorrect number of elements.'
	if nV    gt 1 && nV    ne N then message, 'V has an incorrect number of elements.'

	;Make sure we have scalars
	if nBits eq 1 then bit = bit[0]
	if nV    eq 1 then V   = V[0]
	
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
	
	;Check valid bit value
	if ~array_equal(bit gt 0 and bit le maxBit, 1) $
		then message, 'BIT is out of range for datatype: "' + tname + '".'
	
	;Does the bit need to be set?
	tf_set   = ((A and 2^(bit-1)) eq 0) and (V ne 0)
	tf_unset = ((A and 2^(bit-1)) ne 0) and (V eq 0)

	;Set the proper bit
	result = A + 2^(bit-1) * tf_set - 2^(bit-1) * tf_unset
	if nA eq 1 && nBits gt 1 then result = total(result, /PRESERVE_TYPE)

	;Return
	return, result
end
