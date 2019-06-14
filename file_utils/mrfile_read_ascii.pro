; docformat = 'rst'
;
; NAME:
;    MrFile_Read_Ascii
;
;*****************************************************************************************
;   Copyright (c) 2015, Matthew Argall                                                   ;
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
;   The purpose of this program is to combine the functionality of READ_ASCII and
;   ASCII_TEMPLATE.
;
; :Examples:
;    Try the main-level example program at the end of this file::
;       IDL> .run MrFile_Read_Ascii
;
; :TODO:
;    1. If COLUMN_NAMES is empty, look for unique group members so that
;       the names are sequential.
;    2. If GROUPS is empty, analyze COLUMN_NAMES to create proper groups.
;
; :Uses:
;   Uses the following external programs::
;      MrIsA.pro
;      typeNameToCode.pro
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
;       2015/06/28  -   Written by Matthew Argall.
;       2019/06/12  -   Added NLINES and NREPEAT keywords. - MRA
;-
;*****************************************************************************************
; docformat = 'rst'
;
;+
;   Determine how many header lines exist in a file and what the datatype is of
;   each column of data. Each line is read and split with the DELIMITER into words.
;   If NREPEAT number of lines are read that contain the same number of words, those
;   lines are considered to be data lines. Everything before them is the header.
;
; :Params:
;    FILE:          in, required, type=string
;                   Name of the file for which info is requested.
;    DELIMITER:     in, optional, type=string/strarr, default=[space\, tab\, newline]
;                   Delimiter separating each column of data.
;    NNLINES:       in, required, type=integer, default=100
;                   Maximum number of lines to search before quitting.
;
; :Keywords:
;    NREPEAT:       in, optional, type=int
;                   Number of lines having the same number to be read before deciding
;                       that we have reached the data.
;
; :Returns:
;    FILE_INFO:     A structure of information about the header and type of data
;                       within each data column. Fields are::
;                           HEADER      --  Header of the file. One element per line
;                           NHEADER     --  Number of header lines.
;                           NCOLUMNS    --  Number of columns of data.
;                           COLUMNTYPES --  Datatype of each column.
;
;-
function MrFile_Read_Ascii_Header, file, delimiter, nLines, $
NREPEAT=nrepeat
	compile_opt strictarr
	on_error, 2

	;Default delimiters
	;   -  9B  Horizontal tab
	;   - 10B  Newline
	if n_elements(delimiter) eq 0 then delimiter = [' ', string(9B), string(10B)]
	if n_elements(nlines)    eq 0 then nLines    = 100
	if n_elements(nrepeat)   eq 0 then nRepeat   = 10

	;Create a regular expression from the delimiters
	;   - Find any squence of one or more delimiters
	delim = '[' + strjoin(delimiter, '|') + ']+'

;---------------------------------------------------------------------
; Test First Line of File ////////////////////////////////////////////
;---------------------------------------------------------------------
	;Store each line of the header
	header = strarr(nLines)

	;Open the file
	openr, lun, file, /GET_LUN
	
	;Read the first line of data
	line = ''
	readf, lun, line
	header[0] = line
	
	;Determine the number of columns
	values = strsplit(line, delim, /REGEX, /EXTRACT, COUNT=nColumns)

;---------------------------------------------------------------------
; Find Start of Data /////////////////////////////////////////////////
;---------------------------------------------------------------------
	;Start reading the file
	;   - Find NREPEAT number of lines with the same number of words.
	i     = 1
	count = 0
	while count lt nRepeat && i lt nLines && ~eof(lun) do begin
		;Read the next line
		readf, lun, line
		
		;Count number of columns
		field_locations = strsplit(line, delim, /REGEX, COUNT=nNew)
		
		;Test if the same number of columns
		if nNew eq nColumns $
			then count += 1 $
			else count  = 0
			
		;Procede to the next line
		header[i]  = line
		nColumns   = nNew
		i         += 1
	endwhile
	
	;Close the file and free the LUN
	free_lun, lun
	
	;Keep the current line number
	lineNumber = i
	
	;Field values
	values = strsplit(line, delim, /REGEX, /EXTRACT)
	
;---------------------------------------------------------------------
; Interpret Results //////////////////////////////////////////////////
;---------------------------------------------------------------------
	if count eq nRepeat then begin
		; Number of header lines
		;   lineNumber - nRepeat + 1 --> Number of lines in the header
		;      -1 because of the first line test
		;      -1 because we started counting repeats at 0, not 1
		nHeader = lineNumber - nRepeat - 1
		header  = header[0:nHeader-1]
	endif else begin
		nHeader  = 0
		nColumns = 0
		header   = ''
	endelse

;---------------------------------------------------------------------
; Determine Field Types //////////////////////////////////////////////
;---------------------------------------------------------------------
	type = strarr(nColumns)

	;Step through each column to determine its type
	for i = 0, nColumns - 1 do begin
		;Long Integer
		;   - (+-)########
		if stregex(values[i], '^(\+|-)?[0-9]+$', /BOOLEAN) then begin
			type[i] = 'LONG'
			
		;Float
		;   - Integers will match, so check second
		;   - (+-)###(.###) OR (+-)###(.###)eE###(.###)
		endif else if stregex(values[i], '^(\+|-)?[0-9]+\.?[0-9]*$', /BOOLEAN) || $
		              stregex(values[i], '^(\+|-)?[0-9]+\.?[0-9]*(e|E)(\+|-)?[0-9]+\.?[0-9]*$', /BOOLEAN) $
		then begin
			type[i] = 'FLOAT'
			
		;String
		endif else begin
			type[i] = 'STRING'
		endelse
	endfor

;---------------------------------------------------------------------
; Fill the Output Structure //////////////////////////////////////////
;---------------------------------------------------------------------
	file_header = { heaer:           header, $
	                nHeader:         nHeader, $
	                nColumns:        nColumns, $
	                ColumnLocations: field_locations, $
	                ColumnTypes:     type $
	              }
	              
	return, file_header
end


;+
;  Combine the functionality of READ_ASCII and ASCII_TEMPLATE
;
; :Params:
;    FILENAME:          in, optional, type=string, default=''
;                       Filename of file to read. If no file is given or the empty string,
;                           a dialog box will appear asking to pick a file. Furthermore,
;                           if `TEMPLATE`, `COLUMN_NAMES`, `COLUMN_TYPES` and `GROUP` are
;                           all undefined, Ascii_Template() will be called to assist in
;                           reading the file.
;
; :Keywords:
;    COLUMN_NAMES:      in, optional, type=strarr
;                       Names for the columns in the data; if there are groups specified,
;                           the column names should be repeated for each column in the
;                           group, so that the number of column names is always equal to
;                           the number of columns. The default is to name the columns
;                           "Field#", where "#" represents the `GROUP` it belongs to.
;    COLUMN_TYPES:      in, optional, type=strarr/lonarr, default=4 (float)
;                       SIZE type codes for the columns in the data; if there are groups
;                           specified, the column types should be repeated for each column
;                           in the group, so that the number of column types is always
;                           equal to the number of columns
;    COLUMN_LOCATIONS:  in, optional, type=lonarr, default=lindgen(nColumsn)
;                       Location of the start of each column within a row of data. A line
;                           begins at location zero.
;    COMMENT_SYMBOL:    in, optional, type=string, default=''
;                       Specifies a comment character for the lines in the file
;    COUNT:             out, optional, type=long
;                       Set to a named variable to get the number of records read
;    DATA_START:        in, optional, TYPE=long, DEFAULT=0L
;                       Number of lines to skip at the beginning of the file. If data
;                           starts on line 10, then `DATA_START` should equal 9. See the
;                           `NHEADER` keyword.
;    DELIMITER:         in, optional, type=string, default=' '
;                       Delimiter between columns of data.
;    DIALOG_PARENT:     in, optional, type=widget_id
;                       The widget ID of that will serve as the parent to the dailog
;                           windows that may appears.
;    GROUPS:            in, optional, type=lonarr
;                       Indices of groups for each column, i.e.::
;
;                               [0, 0, 0, 0, 0, 0, 0]
;
;                           indicates all seven columns are in a single group, where::
;
;                               [0, 1, 2, 3, 4, 5, 6]
;
;                           would put each column in a new group. If columns are grouped
;                           together, they will be put into a 2D array, having the same
;                           number of columns as there are members in the group. The
;                           default is to put each column in its own group.
;    HASH:              in, optional, type=boolean, default=0
;                       If set, `DATA` will be returned as a hash instead of a structure.
;                           The hash keys will be the same as `COLUMN_NAMES`.
;    HEADER:            out, optional, type=strarr
;                       Set to a named variable to get the header information skipped by
;                           `DATA_START`
;    MISSING_VALUE:     in, optional, type=scalar, default=!values.f_nan
;                       Value to use for missing items in the data
;    NFOOTER:           in, optional, type=integer, default=`DATA_START-1`
;                       Number of footer lines in the file. Will be removed from the data.
;    NHEADER:           in, optional, type=integer, default=0
;                       Number of header lines in the file to skip. A less confusing way
;                           to specify the `DATA_START` keyword.
;    NLINES:            in, optional, type=int, default=100
;                       Number of lines to scan for a header.
;    NREPEAT:           in, optional, type=int, default=10
;                       Number of lines having the same number to be read before deciding
;                           that we have reached the data.
;    NUM_RECORDS:       in, optional, type=long
;                       Number of records to read; default is to read all available records
;    RECORD_START:      in, optional, type=long, DEFAULT=0
;                       Set to index of first record to read (after `DATA_START` is taken
;                           into account)
;    SELECT:            in, opitonal, type=boolean, default=0
;                       If set, Ascii_Template() will be called to initiate a GUI from
;                           which the following keywords are specified: `COLUMN_NAMES`,
;                           `COLUMN_TYPES`, `COLUMN_LOCATIONS`, `DATA_START`,
;                           `COMMENT_SYMBOL`, `DELIMITER`, `GROUPS`, and `MISSING_VALUE`.
;    TEMPLATE:          in, out, opitonal, type=structure
;                       An template returned by Ascii_Template(). If provided, all of the
;                           keywords related to Ascii_Template will be ignored. Upon exit,
;                           the template used to read the ascii file will be returned via
;                           this keyword.
;    VARIABLE:          in, optional, type=string/integer
;                       Either the name in `COLUMN_NAMES` or the group in `GROUPS` that
;                           represents the data to be returned. If provided, `DATA` will
;                           be an array containing data only from the column(s) indicated.
;    VERBOSE:           in, optional, type=boolean
;                       Set to print runtime messages
;
; :Returns:
;    DATA:              A data structure (or hash if `HASH` is set) with each field (key)
;                           containing a `GROUP` of data. If dialog boxes were cancelled,
;                           -1 will be returned. Furthermore, if any of the Group#
;                           parameters are present, -1 will be returned.
;-
function MrFile_Read_Ascii, filename, $
DIALOG_PARENT=dialog_parent, $
HASH=to_hash, $
NHEADER=nHeader, $
NFOOTER=nFooter, $
SELECT=select, $
;Ascii_Header
NLINES=nLines, $
NREPEAT=nRepeat, $
;Ascii_Template
COLUMN_NAMES=column_names, $
COLUMN_TYPES=column_types, $
COLUMN_LOCATIONS=column_locations, $
COMMENT_SYMBOL=comment_symbol, $
DATA_START=data_start, $
DELIMITER=delimiter, $
GROUPS=groups, $
MISSING_VALUE=missingValue, $
TEMPLATE=template, $
;Read_Ascii
COUNT=count, $
HEADER=header, $
NUM_RECORDS=numRecords, $
RECORD_START=recordStart, $
VERBOSE=verbose
	compile_opt strictarr
	on_error, 2

	;Defaults
	select         = keyword_set(select)
	to_hash        = keyword_set(to_hash)
	_filename      = n_elements(filename)      eq 0  ? ''  : filename
	_commentSymbol = n_elements(commentSymbol) eq 0  ? ''  : comment_symbol
	_delimiter     = n_elements(delimiter)     eq 0  ? ' ' : delimiter
	if n_elements(nFooter) eq 0 then nFooter = 0

;---------------------------------------------------------------------
; Ask for a file? ////////////////////////////////////////////////////
;---------------------------------------------------------------------
	if _filename eq '' then begin
		_filename = dialog_pickfile(/READ, /MUST_EXIST, DIALOG_PARENT=dialog_parent)
		if _filename eq '' then return, -1
	endif

;---------------------------------------------------------------------
; Template Given? ////////////////////////////////////////////////////
;---------------------------------------------------------------------
	if n_elements(template) gt 0 then begin
	    t = template

;---------------------------------------------------------------------
; Build the Template /////////////////////////////////////////////////
;---------------------------------------------------------------------
	endif else begin
		;ColumnNames, ColumnTypes, and Groups must have the same number of elements
		;or be undefined, but one of them must be defined
		nColumns = n_elements(column_types) eq 0L $
		            ? (n_elements(column_names) eq 0L $
		                ? (n_elements(groups) eq 0L $
		                    ? 0L $
		                    : n_elements(groups)) $
		                : n_elements(column_names)) $
		           : n_elements(column_types)

	;---------------------------------------------------------------------
	; Call Ascii_Template? ///////////////////////////////////////////////
	;---------------------------------------------------------------------
		;Call Ascii_Template to create a template via a GUI
		if select then begin
			t = ascii_template(_filename, $
			                   CANCEL    = cancel, $
			                   DELIMITER = _delimiter, $
			                   GROUP_ID  = dialog_parent)
			if cancel eq 1B then return, -1
		
	;---------------------------------------------------------------------
	; Create a Custom Template ///////////////////////////////////////////
	;---------------------------------------------------------------------
		endif else begin
			;If no columns are present
			if nColumns eq 0 || $
			   (n_elements(data_start) eq 0 && n_elements(nHeader) eq 0) || $
			   n_elements(column_types) eq 0 $
			then begin
				
				;Try to read the information
				info = MrFile_Read_Ascii_Header(_filename, !Null, nLines, NREPEAT=nRepeat)
				
				;Number of columns
				if nColumns eq 0 then nColumns = info.nColumns
				
				;Location of each column
				if n_elements(column_locations) eq 0 $
					then column_locations = info.ColumnLocations
			
				;Number of header lines
				if n_elements(nHeader) eq 0 $
					then nHeader = info.nHeader
			
				;Datatype of each column
				if n_elements(column_types) eq 0 $
					then column_types = info.ColumnTypes
			endif

			;Number of lines to skip
			_nHeader   = n_elements(nHeader)    eq 0 ? 0 : nHeader
			_dataStart = n_elements(data_start) eq 0 ? _nHeader : data_start

			;Pad column names with the correct number of zeros. ALog10 will return
			;the number of digits in NCOLUMNS
			colNameFormat = '(I0' + strtrim(ceil(alog10(nColumns)), 2) + ')'

			;Default to "Column#", where # indicates the column number
			_columnNames = n_elements(column_names) eq 0L $
			               ? 'Field' + string(sindgen(nColumns), FORMAT=colNameFormat) $
			               : column_names

			;Default to floats
			if n_elements(column_types) gt 0 then begin
				if MrIsA(column_types, 'STRING') $
					then _columnTypes = typeNameToCode(column_types) $
					else _columnTYpes = columnTypes
			endif else begin
				_columnTypes = lonarr(nColumns) + 4L
			endelse

			;Locations of each column
			_columnLocations = n_elements(column_locations) eq 0 $
			                   ? lindgen(nColumns) $
			                   : column_locations

			;Defualt to putting everything in its own group.
			_groups = n_elements(groups) eq 0L ? lindgen(nColumns) : groups

			;Default to !Values.F_NaN
			_missingValue = n_elements(missingValue) eq 0L $
			                ? !Values.F_NaN $
			                : missingValue

			;Create the template
			t = { version:        1.0, $
			      datastart:      _dataStart, $
			      delimiter:      byte(_delimiter), $
			      missingvalue:   _missingValue, $
			      commentsymbol:  _commentSymbol, $
			      fieldcount:     nColumns, $
			      fieldtypes:     _columnTypes, $
			      fieldnames:     _columnNames, $
			      fieldlocations: _columnLocations, $
			      fieldgroups:    _groups $
			    }
		endelse
	endelse
	
;---------------------------------------------------------------------
; Read the Data //////////////////////////////////////////////////////
;---------------------------------------------------------------------
	
	data = read_ascii(filename, $
	                  COUNT        = count, $
	                  HEADER       = header, $
	                  TEMPLATE     = t, $
	                  NUM_RECORDS  = numRecords, $
	                  RECORD_START = recordStart, $
	                  VERBOSE      = verbose)
	
;---------------------------------------------------------------------
; Remove Footer //////////////////////////////////////////////////////
;---------------------------------------------------------------------
	if nFooter gt 0 then begin
		fields  = tag_names(data)
		nFields = n_tags(data)
		
		;Trim the footer
		for i = 0, nFields - 1 do begin
			;Number of data points
			sz      = size(data.(i))
			nDims   = sz[0]
			dims    = sz[1:ndims]
			type    = sz[sz[0]+1]
			nPts    = ndims eq 1 ? dims[0] : dims[1]
			
			;New size of array
			newNPts = nPts - nFooter
			newDims = nDims eq 1 ? newNPts : [dims[0], newNPts]
			
			;Create the field
			if i eq 0 $
				then data_tmp = create_struct(fields[i], make_array(newDims, TYPE=type)) $
				else data_tmp = create_struct(data_tmp, fields[i], make_array(newDims, TYPE=type))
			
			;Set the data
			if nDims eq 1 $
				then data_tmp.(i) = data.(i)[0:newNPts-1] $
				else data_tmp.(i) = data.(i)[*,0:newNPts-1]
		endfor
		
		;Replace the data
		data = temporary(data_tmp)
	endif


;---------------------------------------------------------------------
;Return a Hash or Structure? /////////////////////////////////////////
;---------------------------------------------------------------------
	;Return the template
	template = temporary(t)

	;Return a hash or structure?
	if to_hash $
		then return, hash(data, /EXTRACT) $
		else return, data
end


;---------------------------------------------------------------------
;Main level program: IDL> .r MrAscii_Template ////////////////////////
;---------------------------------------------------------------------
;An example using column names and types, skipping a header, and putting
;everthing into its own group.
;col_names = ['lon', 'lat', 'elev', 'temp', 'dewpt', 'wind_speed', 'wind_dir']
;wdata = MrRead_Ascii(file_which('ascii.txt'), DATA_START=5, $
;                     COLUMN_TYPES=[4, 4, 3, 3, 3, 3, 3], $
;                     COLUMN_NAMES=col_names, $
;                     GROUPS=lindgen(7), COUNT=nrows)
;help, wdata

;This time, put each column into the same group and look for missing values.
;adata = MrRead_Ascii(file_which('ascii.dat'), DATA_START=3, $
;                     DELIMITER=string(9B), COMMENT_SYMBOL='%', $
;                     GROUPS=lonarr(4), MISSING_VALUE=-999.)
;print, adata.field0

;end

