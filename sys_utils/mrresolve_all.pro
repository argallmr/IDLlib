; docformat = 'rst'
;
; NAME:
;       MrResolve_All
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
; PURPOSE:
;+
;   Resolve all routine return names of those routines that are subsequently compiled.
;   See IDL's `Resolve_All <http://exelisvis.com/docs/RESOLVE_ALL.html>`
;   
; :Categories:
;    Wrapper, System Utility
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
;   Change History::
;       2015/02/07  -   Written by Matthew Argall
;       2015/03/06  -   Added the FILTER_CLASS, FILTER_FUN, and FILTER_PRO keywords.
;                           Use FilePath() to determine the IDL_ROOT. - MRA
;       2017/04/03  -   Procedures and functions names that do not match the module name
;                           cannot be found by File_Which() and are removed from the
;                           FILES_PRO and FILES_FUN results. - MRA.
;       2017/04/16  -   Help does not distinguish some objects as objects. Parse the set
;                           of procedures for pros that end with __DEFINE. - MRA.
;-
;*****************************************************************************************
;+
;   Helper function for MrResolve_All. Parse routine names from the output of HELP.
;
; :Keywords:
;       COUNT:              out, optional, type=long
;                           Number of routine names parsed.
;       PROCEDURES:         in, optional, type=boolean
;                           If set, procedure names are parsed. This is the default if
;                               `FUNCTIONS` and `OBJECTS` are both 0.
;       FUNCTIONS:          in, optional, type=boolean, default=0
;                           If set, function names are parsed.
;       OBJECTS:            in, optional, type=boolean, default=0
;                           If set, object class names are parsed.
;-
function MrResolve_All_ParseHelp, $
COUNT=count, $
FUNCTIONS=functions, $
PROCEDURES=procedures, $
OBJECTS=objects
	compile_opt idl2
	on_error, 2

	functions  = keyword_set(functions)
	procedures = keyword_set(procedures)
	objects    = keyword_set(objects)
	if functions + procedures + objects eq 0 then procedures = 1

	;More than one?
	if functions + procedures + objects gt 1 then begin
		;Parse each one individually
		pros = MrResolve_All_ParseHelp(/PROCEDURES)
		funs = MrResolve_All_ParseHelp(/FUNCTIONS)
		objs = MrResolve_All_ParseHelp(/OBJECTS)
	
		;Return them all
		return, [objs, pros, funs]
	endif

;-----------------------------------------------------
; Find Routines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Objects
	if objects then begin
		;Compiled objects
		help, OUTPUT=output, OBJECTS=objects, /BRIEF
		output = strsplit( strjoin( temporary(output), ' '), ' ', /EXTRACT)
		
		;Some objects are not captured.
		;   - Look for the __DEFINE procedures
		help, OUTPUT=pros, /PROCEDURES, /BRIEF
		pros = strsplit( strjoin( temporary(pros), ' '), ' ', /EXTRACT )
		iObj = where( stregex(pros, '__DEFINE$', /BOOLEAN), nObj )
		
		;Find missing objects
		if nObj gt 0 then begin
			pros = pros[iObj]
			
			;Remove the __DEFINE
			pros = stregex(pros, '^(.*)__DEFINE$', /SUBEXP, /EXTRACT)
			pros = reform(pros[1,*])
			
			;Look for non-members
			void = MrIsMember(output, pros, COMPLEMENT=iKeep, NCOMPLEMENT=nKeep)
			if nKeep gt 0 then output = [output, temporary(pros)]
		endif
	
	;Functions or Procedures
	endif else begin
		help, OUTPUT=output, FUNCTIONS=functions, PROCEDURES=procedures, /BRIEF
		output = strsplit( strjoin( temporary(output), ' '), ' ', /EXTRACT)
	endelse
	
	;Remove
	;   - Compiled Procedures:
	;   - Compiled Functions:
	case 1 of
		objects:    ;Do nothing
		procedures: output = output[2:*]
		functions:  output = output[2:*]
		else: message, 'One of OBJECTS, PROCEDURES and FUNCTIONS must be set.'
	endcase
	count = n_elements(output)

	return, output
end


;+
;   Resolve (by compiling) any unresolved procedures or functions.
;
; :Keywords:
;       CLASSES:            out, optional, type=string/strarr
;                           Names of the classes that have been resolved.
;       FILES_CLASS:        out, optional, type=string/strarr
;                           File names associated with each compiled function. Empty
;                               strings represent elements of `CLASSES` that do not have
;                               an associated CLASSES[i] + '__define.pro' file name.
;       FILES_FUN:          out, optional, type=string/strarr
;                           File names associated with each compiled function. Empty
;                               strings represent elements of `FUNCTIONS` that do not have
;                               an associated FUNCTIONS[i] + '.pro' file name.
;       FILES_PRO:          out, optional, type=string/strarr
;                           File names associated with each compiled function. Empty
;                               strings represent elements of `FUNCTIONS` that do not have
;                               an associated PROCEDURES[i] + '.pro' file name.
;       FILTER_CLASS:       in, optional, type=string, default='.*'
;                           A regex express to act as a boolean filter for  `CLASSES`
;                               and `FILES_CLASS`. Any routines that do not match are
;                               excluded from the outputs.
;       FILTER_FUN:         in, optional, type=string, default='.*'
;                           A regex express to act as a boolean filter for  `FUNCTIONS`
;                               and `FILES_FUN`. Any routines that do not match are
;                               excluded from the outputs.
;       FILTER_PRO:         in, optional, type=string, default='.*'
;                           A regex express to act as a boolean filter for  `PROCEDURES`
;                               and `FILES_PRO`. Any routines that do not match are
;                               excluded from the outputs.
;       FUNCTIONS:          out, optional, type=string/strarr
;                           Names of the functions that have been resolved.
;       IDL_ROOT:           in, optional, type=string, default=FilePath('')
;                           Location of the IDL distribution. Used with `NO_IDL_ROUTINES`.
;       METHOD_FUNS:        out, optional, type=string/strarr
;                           Names of the resolved function methods.
;       METHOD_PROS:        out, optional, type=string/strarr
;                           Names of the resolved procedures methods.
;       NCLASS:             out, optional, type=long
;                           Number of classes resolved.
;       NFUNS:              out, optional, type=long
;                           Number of functions resolved.
;       NMETHODFUNS:        out, optional, type=long
;                           Number of function methods resolved.
;       NMETHODPROS:        out, optional, type=long
;                           Number of procedure methods resolved.
;       NO_IDL_ROUTINES:    in, optional, type=boolean, default=0
;                           If set, then IDL routines are removed from `CLASSES`, `FUNCTIONS`,
;                               `PROCEDURES`, `FILES_CLASS`, `FILES_FUN`, and `FILES_PRO`.
;                               This requires that File_Which be used to determine where
;                               each compiled file is located. Files in the `IDL_ROOT`
;                               directory tree are removed.
;       NPROS:              out, optional, type=long
;                           Number of procedures resolved.
;       NUNRESOLVED:        out, optional, type=long
;                           Number of unresolved routines.
;       PROCEDURES:         out, optional, type=string/strarr
;                           Names of the procedures that have been resolved.
;       RESOLVE_CLASS:      in, optional, type=string/strarr
;                           Names of the classes to be resolved.
;       RESOLVE_PROCEDURE:  in, optional, type=string/strarr
;                           Names of the procedures to be resolved.
;       RESOLVE_FUNCTION:   in, optional, type=string/strarr
;                           Names of the functions to be resovled.
;       RESOLVE_EITHER:     in, optional, type=string/strarr
;                           Use to resolve a routine if you do not know if it is a
;                               procedure or a function.
;       SHOW:               in, optional, type=boolean, default=0
;                           If set, resolved procedures, functions, and classes will
;                               be printed to the command window.
;       SKIP_ROUTINES:      in, optional, type=string/strarr
;                           Names of the routines to skip while resolving.
;       UNRESOLVED:         out, optional, type=string/strarr
;                           Names of the unresolved routines. Routines are unresolved if
;                               their source code cannot be found and compiled. If not
;                               present, unresolved routine names will be printed to the
;                               command window with a warning message.
;-
pro MrResolve_All, $
CLASSES=classes, $
FILES_CLASS=files_class, $
FILES_FUN=files_fun, $
FILES_PRO=files_pro, $
FILTER_CLASS=filter_class, $
FILTER_FUN=filter_fun, $
FILTER_PRO=filter_pro, $
FUNCTIONS=functions, $
IDL_ROOT=idl_root, $
METHOD_PROS=method_pros, $
METHOD_FUNS=method_funs, $
NCLASS=nClass, $
NFUNS=nFuns, $
NMETHODFUNS=nMethodFuns, $
NMETHODPROS=nMethodPros, $
NO_IDL_ROUTINES=no_idl_routines, $
NPROS=nPros, $
NUNRESOLVED=nUnresolved, $
PROCEDURES=procedures, $
RESOLVE_CLASS=resolve_class, $
RESOLVE_PROCEDURE=resolve_procedure, $
RESOLVE_FUNCTION=resolve_function, $
RESOLVE_EITHER=resolve_either, $
SHOW=show, $
SKIP_ROUTINES=skip_routines, $
UNRESOLVED=unresolved, $
VERBOSE=verbose
	compile_opt strictarr
	on_error, 2
	
	;Show results?
	show            = keyword_set(show)
	quiet           = ~keyword_set(verbose)
	no_idl_routines = keyword_set(no_idl_routines)
	get_files_class = arg_present(files_class)
	get_files_pro   = arg_present(files_pro)
	get_files_fun   = arg_present(files_fun)
	if n_elements(idl_root)     eq 0 then idl_root     = filepath('')
	if n_elements(filter_class) eq 0 then filter_class = ''
	if n_elements(filter_fun)   eq 0 then filter_fun   = ''
	if n_elements(filter_pro)   eq 0 then filter_pro   = ''
	
	;Removing IDL routines requires us to get the file names
	if no_idl_routines then begin
		get_files_class = 1
		get_files_pro   = 1
		get_files_fun   = 1
	endif
	
	;Resolve all that were given
	resolve_all, /CONTINUE_ON_ERROR, $
	             CLASS             = resolve_class, $
	             QUIET             = quiet, $
	             RESOLVE_EITHER    = resolve_either, $
	             RESOLVE_PROCEDURE = resolve_procedure, $
	             RESOLVE_FUNCTION  = resolve_function, $
	             SKIP_ROUTINES     = skip_routines, $
	             UNRESOLVED        = unresolved

;-----------------------------------------------------
; Fine Routine Names \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	procedures = MrResolve_All_ParseHelp(COUNT=nPros,  /PROCEDURES)
	functions  = MrResolve_All_ParseHelp(COUNT=nFuns,  /FUNCTIONS)
	classes    = MrResolve_All_ParseHelp(COUNT=nClass, /OBJECTS)

;-----------------------------------------------------
; Separate Classes \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Find procedure and function methods
	iProMethod = where( ( strpos(procedures, '::') ne -1 ), nMethodPros, COMPLEMENT=iPro, NCOMPLEMENT=nPros)
	iFunMethod = where( ( strpos(functions,  '::') ne -1 ), nMethodFuns, COMPLEMENT=iFun, NCOMPLEMENT=nFuns)

	;Remove methods
	if nMethodPros gt 0 then method_pros = procedures[iProMethod] else method_pros = ''
	if nMethodFuns gt 0 then method_funs = functions[iFunMethod]  else method_funs = ''
	if nPros       gt 0 then procedures  = procedures[iPro]       else procedures  = ''
	if nFuns       gt 0 then functions   = functions[iFun]        else functions   = ''
	if nClass      eq 0 then classes     = ''

	;Find class definitions
	iClassDef = where( ( strpos(procedures, '__DEFINE') ne -1 ), nMethodPros, COMPLEMENT=iPro, NCOMPLEMENT=nPros)

	;Remove class definitions
	if nPros gt 0 then procedures = procedures[iPro] else procedures  = ''

	;Scalars?
	if nPros       eq 1 then procedures  = procedures[0]
	if nFuns       eq 1 then functions   = functions[0]
	if nClass      eq 1 then classes     = classes[0]
	if nMethodPros eq 1 then method_pros = method_pros[0]
	if nMethodFuns eq 1 then method_funs = method_funs[0]

;-----------------------------------------------------
; Show Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	if show then begin
		print, 'Compiled Classes:'
		print, '   ' + ( nClass eq 0 ? '' : reform(classes, 1, nClass) )
		print, 'Compiled Procedures:'
		print, '   ' + ( nPros eq 0 ? '' : reform(procedures, 1, nPros) )
		print, 'Compiled Functions:'
		print, '   ' + ( nFuns eq 0 ? '' : reform(functions, 1, nFuns) )
	endif

;-----------------------------------------------------
; Unresolved Items \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	nUnresolved = n_elements(unresolved)
	if (nUnresolved gt 0) && (show || (arg_present(unresolved) eq 0) ) then begin
		message, 'Unresolved Routines:', /INFORMATIONAL
		print, '   ' + reform(unresolved, 1, nUnresolved)
	endif

;-----------------------------------------------------
; Get File Names \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Classes
	if get_files_class && nClass gt 0 then begin
		files_class = strarr(nClass)
		for i = 0, nClass - 1 do files_class[i] = file_which(strlowcase(classes[i]) + '__define.pro')
		if nClass eq 1 then files_class = files_class[0]

		;Remove empty results
		;   - If two objects are contained in the same file, the function that
		;     does not share a name with the module will result in the empty string
		iGood = where(files_class ne '', nClass)
		files_class = nClass eq 0 ? '' : files_class[iGood]
	endif

	;Functions
	if get_files_fun && nFuns gt 0 then begin
		;Find the files
		files_fun = strarr(nFuns)
		for i = 0, nFuns - 1 do files_fun[i] = file_which(strlowcase(functions[i]) + '.pro')
		if nFuns eq 1 then file_fun = file_fun[0]

		;Remove empty results
		;   - If two functions are contained in the same file, the function that
		;     does not share a name with the module will result in the empty string
		iGood = where(files_fun ne '', nFuns)
		files_fun = nFuns eq 0 ? '' : files_fun[iGood]
	endif

	;Procedures
	if get_files_pro && nPros gt 0 then begin
		;Find the files
		files_pro = strarr(nPros)
		for i = 0, nPros - 1 do files_pro[i] = file_which(strlowcase(procedures[i]) + '.pro')
		if nPros eq 1 then file_pro = file_pro[0]
		
		;Remove empty results
		;   - If two procedures are contained in the same file, the function that
		;     does not share a name with the module will result in the empty string
		iGood = where(files_pro ne '', nPros)
		files_pro = nPros eq 0 ? '' : files_pro[iGood]
	endif

;-----------------------------------------------------
; Remove IDL Routines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	if no_idl_routines then begin
		;Non-IDL Classes
		if get_files_class then begin
			iClass = where(strpos(files_class, idl_root) eq -1, nClass)
			if nClass gt 0 then classes     = classes[iClass]     else classes    = ''
			if nClass gt 0 then files_class = files_class[iClass] else files_class = ''
		endif
		
		;Non-IDL Functions
		if get_files_fun then begin
			iFun = where(strpos(files_fun, idl_root) eq -1, nFuns)
			if nFuns gt 0 then functions = functions[iFun] else functions = ''
			if nFuns gt 0 then files_fun = files_fun[iFun] else files_fun = ''
		endif
		
		;Non-IDL Procedures
		if get_files_pro then begin
			iPro = where(strpos(files_pro, idl_root) eq -1, nPros)
			if nPros gt 0 then procedures = procedures[iPro] else procedures = ''
			if nPros gt 0 then files_pro  = files_pro[iPro]  else files_pro  = ''
		endif
	endif

;-----------------------------------------------------
; Apply Filters \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Classes
	if filter_class ne '' then begin
		iClass = where(stregex(files_class, filter_class, /BOOLEAN) eq 1, nFun)
		if nClass gt 0 then classes = classes[iClass] else classes = ''
		if nClass gt 0 then if get_files_class then files_class = files_class[iClass] else files_class = ''
	endif
	
	;Functions
	if filter_fun ne '' then begin
		iFun = where(stregex(files_fun, filter_fun, /BOOLEAN) eq 1, nFun)
		if nFuns gt 0 then functions = functions[iFun] else functions = ''
		if nFuns gt 0 then if get_files_fun then files_fun = files_fun[iFun] else files_fun = ''
	endif
		
	;Procedures
	if filter_pro ne '' then begin
		iPro = where(stregex(files_pro, filter_pro, /BOOLEAN) eq 1, nPro)
		if nPros gt 0 then procedures = procedures[iPro] else procedures = ''
		if nPros gt 0 then if get_files_pro then files_pro = files_pro[iPro] else files_pro  = ''
	endif
end