
; docformat = 'rst'
;
; NAME:
;       MrFile_VFilter
;
;*****************************************************************************************
;   Copyright (c) 2016, University of New Hampshire                                      ;
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
;   Filter files by their time stamps.
;
;   Times within file names (as specified by FPATTERN) as well as the start and end times
;   of the data interval (TSTART and TEND as specified by TPATTERN) must be convertible
;   to ISO-8601 format by MrTimeParser (i.e. converted to '%Y-%M-%dT%H:%m:%S'). Once
;   all times are in the same format, they are converted to Julian days and compared.
;
;
; :Params:
;       FILES:          in, required, type=string/strarr
;                       File name(s) to be filterd.
;       TSTART:         in, optional, type=string, default=''
;                       An ISO-8601 string specifying the start of an interval
;                           of interest. Any file containing this start time will
;                           be included in the results. If this parameter is
;                           provided, `FILE_PATH` must contain time tokens. If
;                           `FILE_PATH` does not contain both a start and end time
;                           outlining the data interval contained in the file,
;                           the search results may include files that do not
;                           contain `TSTART`.
;       TEND:           in, optional, type=string, default=''
;                       An ISO-8601 string specifying the start of an interval
;                           of interest. Any file containing this end time will
;                           be included in the results. If this parameter is
;                           provided, `FILE_PATH` must contain time tokens. If
;                           `FILE_PATH` does not contain both a start and end time
;                           outlining the data interval contained in the file,
;                           the search results may include files that do not
;                           contain `TEND`.
;
; :Keywords:
;       CLOSEST:        in, optional, type=boolean, default=0
;                       Find the nearest file with a start time <= `TSTART`.
;                           This option is ignored unless `TSTART` is specified.
;                           If `TEND` is also given, the file that starts <= `TEND`
;                           will serve as the upper limit of files times. All
;                           files within the range are returned.
;       COUNT:          out, optional, type=integer
;                       Number of files found.
;       FPATTERN:       in, optional, type=string, default='%Y%M%d%H%m%S'
;                       A pattern recognized by MrTokens that represents how time
;                           is incorporated into the file names.
;       TPATTERN:       in, optional, type=string, default='%Y-%M-%dT%H:%m:%S'
;                       If `TSTART` and `TEND` are not ISO-8601 format, then
;                           use this parameter to specify their MrTokens pattern.
; 
;
; :Returns:
;       FILE_FILT:      out, required, type=string/strarr
;                       Those elements of `FILES` that pass the time filter.
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
;       2016-02-24  -   Written by Matthew Argall
;       2017-01-16  -   Convert times to Julian days when comparing. - MRA
;-
FUNCTION MrFile_TFilter, files, tstart, tend, $
CLOSEST=closest, $
COUNT=count, $
FPATTERN=fpattern, $
TPATTERN=tpattern
	Compile_Opt idl2
	On_Error, 2
	
	;Defaults
	tf_closest = Keyword_Set(closest)
	IF N_Elements(tstart)    EQ 0 THEN tstart    = ''
	IF N_Elements(tend)      EQ 0 THEN tend      = ''
	IF N_Elements(fpattern)  EQ 0 THEN fpattern  = '%Y%M%d%H%m%S'
	IF N_Elements(tpattern)  EQ 0 THEN tpattern  = '%Y-%M-%dT%H:%m:%S'
	outPattern = '%Y-%M-%dT%H:%m:%S'
	
	;Restrictions
	IF tstart EQ '' && tend EQ '' THEN BEGIN
		count = N_Elements(files)
		RETURN, files
	ENDIF
	IF ~array_equal(MrTokens_IsMatch(files[0], fpattern), 1) THEN Message, 'FILES must match FPATTERN.'
	IF tstart NE '' && ~MrTokens_IsMatch(tstart, tpattern)   THEN Message, 'TSTART must match TPATTERN.'
	IF tend   NE '' && ~MrTokens_IsMatch(tend,   tpattern)   THEN Message, 'TEND must match TPATTERN.'
	
	;Results
	file_filt = File_BaseName(files)
	dir_filt  = File_DirName(files)
	count     = N_Elements(files)
	
	;How to filter
	tf_tstart = tstart NE ''
	tf_tend   = tend   NE ''
	
;-------------------------------------------
; Find File Start & End Times //////////////
;-------------------------------------------
	;
	; Does the file name include TStart and TEnd?
	;   - Assume TEnd takes the same form as TStart.
	;   - Assume TStart does not repeat tokens.
	;   - Filenames include TStart and TEnd IF the first token OF TStart is repeated.
	;
	; Times are put into TimeOrder and converted to integers. This allows
	; for easy comparison. 
	;

	;Extract tokens
	tokens = MrTokens_Extract(fpattern, COUNT=nTokens, POSITIONS=token_pos)
	
	;Is there an end time in the file name?
	;   - Look for a repeated token
	;   - Repeated token will be found at position TOKEN_POS[0]+2+IREPEAT
	iRepeat = strpos( strmid(fpattern, token_pos[0]+2), '%'+tokens[0] )
	tf_fend = iRepeat NE -1

	;Convert the start time of each file to an integer
	;  - MrTimeParser will take the last match (i.e. FEND)
	;  - If the file name has an END time, parse up to the first repeated token.
	IF tf_fend $
		THEN MrTimeParser, file_filt, strmid(fpattern, 0, iRepeat+2+token_pos[0]), outPattern, fstart $
		ELSE MrTimeParser, file_filt, fpattern, tpattern, fstart

	;Convert the END time to an integer
	IF tf_fend THEN BEGIN
		MrTimeParser, file_filt, strmid(fpattern, iRepeat+token_pos[0]+2), outPattern, fend
	ENDIF
	
;-------------------------------------------
; Convert to Julian Dates //////////////////
;-------------------------------------------
	;File times
	
	;Start
	MrTimeParser_Breakdown, Temporary(fstart), outPattern, $
	                        YEAR=yr, MONTH=mo, DAY=day, HOUR=hr, MINUTE=mnt, SECOND=sec
	fs_jul = JulDay( Temporary(mo), Temporary(day), Temporary(yr), Temporary(hr), Temporary(mnt), Temporary(sec) )
	
	;End
	IF tf_fend THEN BEGIN
		MrTimeParser_Breakdown, Temporary(fend), outPattern, $
		                        YEAR=yr, MONTH=mo, DAY=day, HOUR=hr, MINUTE=mnt, SECOND=sec
		fe_jul = JulDay( Temporary(mo), Temporary(day), Temporary(yr), Temporary(hr), Temporary(mnt), Temporary(sec) )
	ENDIF
	
	
	;Time interval
	temp_tstart = tstart
	temp_tend   = tend
	IF tpattern NE outpattern THEN BEGIN
		IF tf_tstart THEN MrTimeParser, tstart, tpattern, outPattern, temp_tstart
		IF tf_tend   THEN MrTimeParser, tend,   tpattern, outPattern, temp_tend
	ENDIF
		
	;Breakdown
	MrTimeParser_Breakdown, Temporary(temp_tstart), outPattern, $
	                        YEAR=syr, MONTH=smo, DAY=sday, HOUR=shr, MINUTE=smnt, SECOND=ssec
	MrTimeParser_Breakdown, Temporary(temp_tend), outPattern, $
	                        YEAR=eyr, MONTH=emo, DAY=eday, HOUR=ehr, MINUTE=emnt, SECOND=esec
	
	;Convert to Julian
	ts_jul = JulDay( Temporary(smo), Temporary(sday), Temporary(syr), Temporary(shr), Temporary(smnt), Temporary(ssec) )
	te_jul = JulDay( Temporary(emo), Temporary(eday), Temporary(eyr), Temporary(ehr), Temporary(emnt), Temporary(esec) )

;-------------------------------------------
; Filter by Time ///////////////////////////
;-------------------------------------------
	;
	; We decide which files to keep by first considering what happens when
	; we have all information: tstart, tend, fStart, and fEnd. In this
	; CASE, we want to choose any files that contain any portion OF the
	; time interval [tstart, tend]. 
	;
	;                    |----Time Interval----|
	;   [--File Interval--]        ....       [--File Interval--]
	;
	; This means any interval such that
	;   ( (tstart >= fStart) & (tstart <  fEnd) )
	; OR
	;   ( (tend   >  fStart) & (tend   <= fEnd) )
	;
	; If we have less information, we simply remove the clause containing
	; the missing information.
	;
	
	;File name includes END times
	IF tf_fend THEN BEGIN
		CASE 1 OF
			(tf_tstart && tf_tend): ikeep = Where( ( (ts_jul GE fs_jul) and (ts_jul LE fe_jul) ) or $
			                                       ( (te_jul GE fs_jul) and (te_jul LE fe_jul) ), count )
			tf_tstart:              ikeep = Where( (ts_jul GE fs_jul) and (ts_jul LE fe_jul), count )
			tf_tend:                ikeep = Where( (te_jul GE fs_jul) and (te_jul LE fe_jul), count )
		END
		
	;File name does not include END times
	ENDIF ELSE BEGIN
		CASE 1 OF
			(tf_tstart && tf_tend): ikeep = Where( (ts_jul GE fs_jul) or (te_jul GE fs_jul), count )
			tf_tstart:              ikeep = Where(ts_jul GE fs_jul, count)
			tf_tend:                ikeep = Where(te_jul GE fs_jul, count)
		END
	ENDELSE
	
	;Select the subset OF files
	IF count GT 0 THEN BEGIN
		dir_filt  = dir_filt[ikeep]
		file_filt = file_filt[ikeep]
		fs_jul    = fs_jul[ikeep]
		IF tf_fend THEN fe_jul = fe_jul[ikeep]
	ENDIF ELSE BEGIN
		dir_filt  = ''
		file_filt = ''
	ENDELSE

;-------------------------------------------
; Closest Time /////////////////////////////
;-------------------------------------------
	;
	; We want to find the closes time to 'TStart'
	;   - If the file has both a start and END time, there is
	;     sufficient information to select the appropriate files.
	;     We do not need to check anything.
	;   - If only a start time exists in the file name, THEN the
	;     selection process above may be too liberal. Find the
	;     file that starts at or just before 'TStart'.
	;   - If 'TEnd' was also given, find the file that starts
	;     just before 'TEnd', and select all files between
	;     'TStart' and 'TEnd'. Otherwise, just pick the file
	;     associated with 'TStart'.
	;
	IF tf_closest && ~tf_fend && count GT 0 THEN BEGIN
		;
		; Find the file that starts closest in time to TSTART
		;

		;Find the largest start time <= TSTART
		istart = Where(fs_jul LE ts_jul, nstart)
		IF nstart EQ 0 THEN BEGIN
			istart = 0
			nstart = 1
		ENDIF
		void   = max(fs_jul[istart], imax)
		istart = istart[imax]
		
		;Find the smallest END time >= TEND
		IF tf_tend THEN BEGIN
			iend = Where(fs_jul LE te_jul, nend)
			void = Max(fs_jul[iend], imax)
			iend = iend[imax]
		ENDIF ELSE BEGIN
			iend = istart
			nend = 0
		ENDELSE

		;Select the found files
		IF nstart + nend GT 0 THEN BEGIN
			IF istart GT iend THEN Message, 'TSTART must be before TEND.'
			dir_filt  = dir_filt[istart:iend]
			file_filt = file_filt[istart:iend]
			count     = iend - istart + 1
		ENDIF ELSE BEGIN
			dir_filt  = ''
			file_filt = ''
			count     = 0
		ENDELSE
	ENDIF

;-------------------------------------------
; Finish Up ////////////////////////////////
;-------------------------------------------
	;Combine the directories and file names
	FOR i = 0, count - 1 do file_filt[i] = FilePath(file_filt[i], ROOT_DIR=dir_filt[i])
	
	;Return scalar IF one result
	IF i EQ 1 THEN file_filt = file_filt[0]
	RETURN, file_filt
END