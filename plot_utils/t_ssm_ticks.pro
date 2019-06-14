; docformat = 'rst'
;
; NAME:
;   TIME_LABELS
;
;*****************************************************************************************
;   Copyright (c) 2013, Matthew Argall                                                   ;
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
;       * Neither the name of the <ORGANIZATION> nor the names of its contributors may   ;
;         be used to endorse or promote products derived from this software without      ;
;         specific prior written permission.                                             ;
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
; PURPOSE
;+
;   The purpose of this program is to convert the tick-lables of a variable with units of
;   seconds since midnight (SSM) to a string with format of hours-minutes-seconds
;   ('HH:MM:SS').
;
; :Categories:
;   Plot Utilities
;
; :Params:
;       AX:             in, required, type=string
;                       the axis on which the labels will be placed
;       INDEX:          in, required, type=int
;                       the index of the values passed into the function
;       VALUES:         in, required, type=fltarr
;                       a time array in seconds from midnight
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 113
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@wildcats.unh.edu
;
; :History:
;   Modification History::
;
;       09/09/2011  -   Created by Matthew Argall
;-
FUNCTION t_ssm_ticks, ax, index, values
	Compile_Opt idl2
	On_Error, 2

	COMMON c_time_ticks, cHour, cMinute, cSecond, cDecimal

	;convert seconds-from-midnight to hour, minute, seconds of the day
	hour    = Long(values)/3600
	minute  = (Long(values) - 3600*hour) / 60
	second  = Fix(values MOD 60)
	decimal = values MOD 1
	
	;First tick mark
	IF index EQ 0 THEN BEGIN
		;Store the string as:
		;   00.000
		;   HH:MM
		str = String(second, decimal*1e3, hour, minute, FORMAT='(%"%02i.%03i!C%02i:%02i")')
	
	;Successive tick marks
	ENDIF ELSE BEGIN
		CASE 1 OF
			(hour-cHour)       GT 0: str = String(second, decimal*10, hour, minute, FORMAT='(%"%02i.%1i!C%02i:%02i")')
			(minute-cMinute)   GT 0: str = String(second, decimal*10, hour, minute, FORMAT='(%"%02i.%1i!C%02i:%02i")')
			(second-cSecond)   GT 0: str = String(second, decimal*10, hour, minute, FORMAT='(%"%02i.%1i!C%02i:%02i")')
			(decimal-cDecimal) GT 0: BEGIN
				pow    = Round(ALog10(decimal - cDecimal))
				dec    = Long(decimal * 10^Abs(pow))
				str    = String(dec, FORMAT='(%".%0' + String(Abs(pow), FORMAT='(i0)') +'i")')
				str   += '!C' + String(second, FORMAT='(%":%02i")')
			ENDCASE
			ELSE: Message, 'Time range too small.'
		ENDCASE
	ENDELSE
	
	;Transfer into the common block
	cHour    = hour
	cMinute  = minute
	cSecond  = second
	cDecimal = decimal

	;Return the tick label
	RETURN, str
END