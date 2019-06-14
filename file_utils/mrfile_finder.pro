; docformat = 'rst'
;
; NAME:
;       MrFile_Finder
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
;    Search for files using a file pattern.
;
; :Categories:
;   System tools, File utility
;
; :Params:
;       PATTERN:        in, required, type=string
;                       A file path to be matched in a recursive search through the file
;                           system. The pattern may contain regular expressions as well as
;                           any token recognized by MrTokens_ToRegexp.
;
; :Keywords:
;       COUNT:          out, optional, type=integer
;                       A named variable to hold the number of files found.
;       PATHSEP:        out, optional, type=string, default=path_sep()
;                       Path separator between directories.
;
; :Returns:
;       TREE:           An array of file names that match `PATTERN`.
;
; :Examples:
;   Given the directory and file structures::
;       IDL> dir  = '/Users/argall/Documents/Work/Data/RBSP/Ephemeris/A/2013/03/'
;       IDL> file = 'rbspa_def_MagEphem_TS04D_20130321_v0.0.0.h5'
;
;   Create a pattern to search for. "%(" and "%)" protect the regular expression "(A|B)"
;   from being interpreted literally as a directory. "%Y", "%M", and "%d" represent year,
;   month, and day, respectively::
;       IDL> dir_pattern    = '/Users/argall/Documents/Work/Data/RBSP/Ephemeris/%((A|B)%)/%Y/%M/'
;       IDL> file_pattern   = 'rbsp%((a|b)%)_def_MagEphem_TS04D_%Y%M%d_v*.h5'
;       IDL> search_pattern = filepath(file_pattern, ROOT_DIR=dir_pattern)
;
;   Search for files
;       IDL> files = MrFile_Finder(search_pattern, COUNT=count)
;       IDL> print, count
;                122
;       IDL> print, files   ;Show 8 of 122
;           /Users/argall/Documents/Work/Data/RBSP/Ephemeris/A/2013/11/rbspa_def_MagEphem_TS04D_20131101_v1.0.0.h5
;           /Users/argall/Documents/Work/Data/RBSP/Ephemeris/A/2013/11/rbspa_def_MagEphem_TS04D_20131102_v1.0.0.h5
;           /Users/argall/Documents/Work/Data/RBSP/Ephemeris/A/2013/12/rbspa_def_MagEphem_TS04D_20131201_v1.0.0.h5
;           /Users/argall/Documents/Work/Data/RBSP/Ephemeris/A/2013/12/rbspa_def_MagEphem_TS04D_20131202_v1.0.0.h5
;           /Users/argall/Documents/Work/Data/RBSP/Ephemeris/B/2013/11/rbspb_def_MagEphem_TS04D_20131101_v1.0.0.h5
;           /Users/argall/Documents/Work/Data/RBSP/Ephemeris/B/2013/11/rbspb_def_MagEphem_TS04D_20131102_v1.0.0.h5
;           /Users/argall/Documents/Work/Data/RBSP/Ephemeris/B/2013/12/rbspb_def_MagEphem_TS04D_20131201_v1.0.0.h5
;           /Users/argall/Documents/Work/Data/RBSP/Ephemeris/B/2013/12/rbspb_def_MagEphem_TS04D_20131202_v1.0.0.h5
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
;       2015-03-30  -   Written by Matthew Argall
;       2015-04-28  -   Renamed from MrFile_Search to MrFile_Finder. Removed
;                          SysRoot keywords. Sandwich path elements between "^"
;                          and "$" to search for whole words. Added example. - MRA
;       2016-12-20  -   Recognizes the "*" wildcard. - MRA
;-
function MrFile_Finder, pattern, $
COUNT=count, $
PATHSEP=pathsep
	compile_opt idl2
	
	catch, the_error
	if the_error ne 0 then begin
		catch, /CANCEL
		cd, pwd
		MrPrintF, 'LogErr'
		count = 0
		return, ''
	endif
	
	;Get the current directory for save keeping
	count = 0
	cd, CURRENT=pwd
	if n_elements(pathsep) eq 0 then pathsep = path_sep()

	;Look for the system root specifier.
	;   - Searching for MrTokens requires me to split FILEPATH at each SEP
	;   - Unix root is '/', so will be removed. Windows is C:, so will not be removed
	case !version.os_family of
		'unix':    sysroot = '/'
		'windows': sysroot = ''
		else: begin
			message, 'Unexpected file system. Errors may occur.', /INFORMATIONAL
			sysroot = ''
		endcase
	endcase

;---------------------------------------------------------------------
; First Token ////////////////////////////////////////////////////////
;---------------------------------------------------------------------
	
	;Break the directory pattern into parts
	parts = strsplit(pattern, pathsep, COUNT=nParts, /EXTRACT)

	;Find the directory elements with a "%" token identifier
	allTokens = strjoin(MrTokens())
	iToken    = where(stregex(parts, '(%|\*)', /BOOLEAN), nTokens)

	;Parse the pattern into a part without tokens and a part with tokens
	;   root       - Leading path segments without tokens
	;   subpattern - Trailing path segments with tokens
	case iToken[0] of
		;Zero tokens.
		-1: begin
			root       = file_dirname(pattern)
			subpattern = file_basename(pattern)
		endcase
		
		;Token is in the first directory of the directory tree
		0: begin
			root       = sysroot
			subpattern = parts[0]
		endcase
		
		;Token is in the middle of the directory tree
		else: begin
			root       = filepath('', ROOT_DIR=sysroot, SUBDIR=parts[0:iToken[0]-1])
			subpattern = parts[iToken[0]]
			subpattern = MrTokens_ToRegex(subpattern)
		endcase
	endcase

	;Look for whole words
	subpattern = '^' + subpattern + '$'

;---------------------------------------------------------------------
; Parse This Piece ///////////////////////////////////////////////////
;---------------------------------------------------------------------
	;Change to the directory
	if file_test(root) $
		then cd, root $
		else return, ''
	
	;Get all of the files in the current directory
	MrLS, subpattern, COUNT=count, OUTPUT=pathOut, /REGEX
	if count eq 0 then begin
		cd, pwd
		return, ''
	endif

	;Combine the matches with the root
	; - Nothing left to parse if there are no more tokens or if we are at the last token.
	; - Append the remaining parts together.
	if nTokens eq 0 || iToken[0] eq nParts-1 $
		then remainder = '' $
		else remainder = filepath('', ROOT_DIR=pathsep, SUBDIR=parts[iToken[0]+1:nParts-1])

;---------------------------------------------------------------------
; Parse Next Piece ///////////////////////////////////////////////////
;---------------------------------------------------------------------
	if remainder ne '' then begin
		;Step through each directory found
		for i = 0, count - 1 do begin
			;Append the directory to the root
			; - root / dirOut[i] / remainder
			next = filepath(remainder, ROOT_DIR=root, SUBDIR=pathOut[i])
			
			;Search again
			tempTree = MrFile_Finder(next, COUNT=tempCount)
		
			;Create the tree
			if tempCount gt 0 then begin
				if n_elements(tree) eq 0 $
					then tree = temporary(tempTree) $
					else tree = [tree, temporary(tempTree)]
			endif
		endfor

;---------------------------------------------------------------------
; Parse Last Piece ///////////////////////////////////////////////////
;---------------------------------------------------------------------
	endif else begin
		;Form the complete file path
		tree = filepath(pathOut, ROOT_DIR=root)
	endelse
	
	;Switch back to the original directory
	cd, pwd

	;Count the results
	count = n_elements(tree)
	if count eq 0 then tree = ''

	return, tree
end
