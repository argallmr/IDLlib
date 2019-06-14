; docformat = 'rst'
;
; NAME:
;       MrFile_VersionCompare
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
;         contributors may be used to endorse or promote products derived from this      ;
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
;    Compare the version of one file with that of another.
;
; :Categories:
;   System tools, File utility
;
; :Params:
;       FILE1:          in, required, type=string/strarr
;                       File name for which the version is to be compared against that
;                           of `FILE2`
;       FILE2:          in, required, type=string/strarr
;                       Compare the version of `FILE1` against this file's version.
;       PATHSEP:        out, optional, type=string, default=path_sep()
;                       Specify the regular expression REGEX used to extract version
;                           numbers. Used with the 'tokens' flag set in regexp(), i.e.
;                           each numeric component of the version number should be
;                           enclosed in parentheses so that they can be extracted. For a
;                           version number v0.3.2, a regex of 'v(0)\.(3)\.(2)' will match
;                           'v0.3.2' and extract '0', '3', '2'.
;
; :Returns:
;       RESULT:         Returns -1 if FILE1 is older than FILE2
;                                0 if FILE1 is the same as FILE2
;                                1 if FILE1 is newer than FILE2
;
; :Examples:
;   Compare the versions of two files::
;       IDL> print, MrFile_VersionCompare('file_v0.1.0.txt', 'file_v1.0.0.txt')
;              1
;
;   Compare arrays of files with a version number "v0.0"
;       IDL> files1 = ['file_v0.0.txt', 'file_v0.1.txt', 'file_v1.0.txt']
;       IDL> file2  = 'file_v0.1.txt'
;       IDL> print, MrFile_VersionCompare(files1, file2, '([0-9])\.([0-9]+)')
;             -1       0       1
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
;       2015-04-28  -   Written by Matthew Argall
;       2015-08-21  -   Keep only subexpressions in regex matching. - MRA
;-
function MrFile_VersionCompare, file1, file2, regex
	compile_opt idl2
	on_error, 2

	nFiles = n_elements(file1)
	_file2 = n_elements(file2) eq 1 ? replicate(file2, nFiles) : file2
	if n_elements(_file2) ne nFiles then $
		message, 'FILE1 and FILE2 must have the same number of elements.'

	;Default regex for finding file version parts
	if n_elements(regex) eq 0 then regex = '([0-9]+)\.([0-9]+)\.([0-9]+)'

	;Find the file version
	vfile1 = fix( (stregex( file1, regex, /SUBEXP, /EXTRACT))[1:*,*] )
	vfile2 = fix( (stregex(_file2, regex, /SUBEXP, /EXTRACT))[1:*,*] )

	;Compare
	i      = 0
	iEqual = lindgen(nFiles)
	nEqual = nFiles
	result = intarr(nFiles)
	while nEqual gt 0 && i lt n_elements(vfile1[*,0]) do begin
		;Make the comparison
		result[iEqual] = fix( vfile1[i,iEqual] gt vfile2[i,iEqual] ) - $
		                 fix( vfile1[i,iEqual] lt vfile2[i,iEqual] )

		;Find versions that are still equal
		inds = where(result[iEqual] eq 0, nEqual)
		if nEqual gt 0 then iEqual = iEqual[inds]
	
		;Next version number
		i++
	endwhile

	return, result
end