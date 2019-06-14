; doc_format = 'rst'
;
;+
;   The purpose of this program is to replace structure values.
;
; :Examples:
;   Try the example program at the end of this document::
;       IDL> .r MrStruct_ReplaceValue
;
; :Categories:
;
;   Structure Utilities
;
; :Params:
;       STRUCTURE:          in, required, type=structure
;                           The structure for which tags are to be renamed.
;       VALUES:             in, required, type=structure
;                           Structure of replacement values. The structure tags must
;                               be identical to those of `STRUCTURE` that are going
;                               to be replaced.
;       CURRENT_LEVEL:      in, optional, private, type=integer
;                           Current recursion level.
;
; :Keywords:
;       LEVEL:              in, optional, type=integer
;                           Level of recursion. Default is to only rename tags from the
;                               root (LEVEL=0). If `RECURSIVE` is set, the default is
;                               LEVEL=infinity. Setting LEVEL automatically sets
;                               `RECURSIVE`=1
;       RECURSIVE:          in, optional, type=boolean, default=0
;                           If set, `STRUCTURE` will be searched recursively for
;                               instances of `TAGS`.
;
; :Returns:
;       STRUCTURE:          A copy of `STRUCTURE`, but with the desired values replaced.
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
;       2015/06/28  -   Written by Matthew Argall
;       2015/06/28  -   Renamed from MrStruct_Replace_Val to MrStruct_ReplaceValue. - MRA
;-
function MrStruct_ReplaceValue, structure, value, current_level, $
LEVEL=level, $
RECURSIVE=recursive
	compile_opt idl2
	on_error, 2

	;tag_names() returns upper case strings, so convert all tags to be removed
	;to uppercase.
	oldTags = tag_names(structure)
	newTags = tag_names(value)
	nOld    = n_elements(oldTags)
	nNew    = n_elements(newTags)
	recursive = keyword_set(recursive)
	if n_elements(current_level) eq 0 then current_level = 0
	if n_elements(level) eq 0 then begin
		_level = recursive ? !values.f_infinity : 0
	endif else begin
		_level    = level
		recursive = 1
	endelse
	
	;loop through all of the STRUCT_TAGS
	;   - If we come across a tag that is in TAG, substitude for value VALUE
	for ii=0, nOld-1 do begin
		;Check if the current take is to be removed
		iCheck = where(newTags eq oldTags[ii], nMatch)
	
		;Get the new value
		;   - If the value of this tag is not being replaced, but the value
		;     itself is a structure, then recurse into the structure to look
		;     for things to replace.
		if nMatch eq 0 then begin
			type = size(structure.(ii), /TNAME)
			if (type eq 'STRUCT') && recursive && (current_level lt _level) $
				then tag_val = MrStruct_ReplaceValue(structure.(ii), value, current_level+1, RECURSIVE=recursive, LEVEL=_level) $
				else tag_val = structure.(ii)
		endif else begin
			tag_val = value.(iCheck)
		endelse
	
		;Create the output structure
		if n_elements(temp) eq 0 $
			then temp = create_struct(oldTags[ii], tag_val) $
			else temp = create_struct(temp, oldTags[ii], tag_val)
	endfor

	;Return
	current_level -= 1
	return, temp
end



;---------------------------------------------------
; Main Level Example Program (.r MrStruct_ReplaceValue)
;---------------------------------------------------
;create a structure with multiple sub-structures
struct = {tagA: 'A', $
          tagB: 'B', $
          tagC: 'C', $
          tagD: {tagi:   'i', $
                 tagii:  'ii', $
                 tagiii: {tag_a: 'a', $
                          tag_b: 'b', $
                          tag_c: 'c'}, $
                 tagiv:  'iv', $
                 tagv:   'v'}, $
          tagE: 'E', $
          tagF: 'F'}

;Remove tags at different recursion levels
values = create_struct('tagA', 'first_tag', 'tagv', 'I_am_Sam', 'tag_b', 'Shh_Secret')
struct_level0 = MrStruct_ReplaceValue(struct, values)
struct_level1 = MrStruct_ReplaceValue(struct, values, LEVEL=1)
struct_levelN = MrStruct_ReplaceValue(struct, values, /RECURSIVE)

;TODO: Display contents of tags
end
