; docformat = 'rst'
;
; NAME:
;       MrIsA
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
; PURPOSE:
;+
;       The purpose of this program is to serve as a wrapper for IDL's "isa" function.
;       In addition to the types checked by "ISA", MrIsA will also check for::
;           - Decimal
;           - Integer       - IDL 8.4 has this keyword
;           - Number        - IDL 8.1 has this keyword
;           - Null          - IDL 8.2 has this keyword
;           - Real
;           - Complex       - IDL 8.4 has this keyword
;           - Double
;           - Column   (1xN vector)
;           - Row      (Nx1 vector)
;
;       Furthermore, if `X` is a structure and `TYPE` is given, `TYPE` will be checked
;       against the name of the structure.
;
;   Note:
;       Multiple keywords can be set, but if the keywords conflict, the result will be
;       false. An example of conflicting keywords would be SCALAR and ARRAY. In other
;       words, keyword combinations are taken as AND cases, not OR.
;
; :Categories:
;       Wrapper, Type Utility
;
; :Examples:
;       See the example program at the end of this file::
;           IDL> .r MrIsA
;
; :Params:
;       X:                      in, required, type=any
;                               Check if this is of type `TYPE`
;       TYPE:                   in, required, type=optional
;                               Determine if `X` is this type. Options are:
;                                   'NUMERIC', 'REAL', 'COMPLEX', 'DOUBLE', 'COLUMN'
;                                   'ROW', or any other type accepted by IDL's ISA function.
;
; :Keywords:
;       ARRAY:                  in, optional, type=boolean, default=0
;                               If set, return 1 if `X` is an array.
;       COLUMN:                 in, optional, type=boolean, default=0
;                               If set, determine if `X` is a column vector (i.e. 1xN).
;       COMPLEX:                in, optional, type=boolean, default=0
;                               If set, determine if `X` is a complex numeric type.
;       DECIMAL:                in, optional, type=boolean, default=0
;                               If set, determine if `X` is a decimal number (non-integer)
;       DOUBLE:                 in, optional, type=boolean, default=0
;                               If set, determine if `X` is a double numeric type.
;       FILE:                   in, optional, type=boolean, default=0
;                               If set, determine if `X` is a file (with ASSOC).
;       INTEGER:                in, optional, type=boolean, default=0
;                               If set, determine if `X` is any integer class.
;       NULL:                   in, optional, type=boolean, default=0
;                               If set, determine if `X` is equal to the !NULL.
;       NUMBER:                 in, optional, type=boolean, default=0
;                               If set, determine if `X` is a numeric type.
;       REAL:                   in, optional, type=boolean, default=0
;                               If set, determine if `X` is a real numeric type.
;       ROW:                    in, optional, type=boolean, default=0
;                               If set, determine if `X` is a row vector (i.e. Nx0)
;       SCALAR:                 in, optional, type=boolean, default=0
;                               If set, return 1 if `X` is a scalar.
;
; :Returns:
;       TF_ISA:                 Is 1 if `X` is of type `TYPE` and optionally qualifies as
;                                   one of the set keywords, and 0 otherwise.
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
;       04/13/2013  -   Written by Matthew Argall
;       07/15/2013  -   Changed the functionality to work via keywords. This way, multiple
;                           keywords can be set at the same time.
;       2013/11/14  -   IDL's ISA function was introduced in 8.0. Fixed for earlier versions. - MRA
;       2014/01/14  -   In keeping with the IsA function, returns true if `X` is defined.
;                           Fixed errors with combinations of keywords from MrIsA and IsA. - MRA
;       2014/01/21  -   Conflicting cases return False immediately (e.g. /ROW, /COLUMN) - MRA
;       2014/06/19  -   Re-organized and added NULL keyword. - MRA
;       2015/03/09  -   Greatly simplified logic by removing all calls to IsA(). - MRA
;       2015/11/15  -   Null pointer/object returns true if /SCALAR is set. Special
;                           treatment of pointers and objects is limited to when they
;                           are scalars. - MRA
;       2016/07/22  -   Unintentional dependencies of NULL keyword on others. Fixed. - MRA
;       2017/06/22  -   Scalars now register as rows and columns. - MRA
;-
function MrIsA, x, type, $
 COLUMN  = column, $
 COMPLEX = complex, $
 DECIMAL = decimal, $
 DOUBLE  = double, $
 FLOAT   = float, $
 INTEGER = integer, $
 NULL    = null, $
 NUMBER  = number, $
 REAL    = real, $
 ROW     = row, $
 STRING  = string, $
 ;Keywords for IDL's IsA function
 FILE    = file, $
 ARRAY   = array, $
 SCALAR  = scalar
    compile_opt strictarr
    on_error, 2
    
    ;IDL Introuction of Keywords:
    ;   8.4  BOOLEAN, COMPLEX, FLOAT, INTEGER, STRING
    ;   8.2  NULL
    ;   8.1  NUMBER
    ;   8.0  Introduced
    
;-----------------------------------------------------
;Check Inputs \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    
    ;Get the input type
    x_type = size(x, /TNAME)
    x_size = size(x)
    
    ;Defaults
    theType = n_elements(type) eq 0 ? '' : strupcase(type)
    array   = keyword_set(array)
    column  = keyword_set(column)
    complex = keyword_set(complex)
    decimal = keyword_set(decimal)
    double  = keyword_set(double)
    float   = keyword_set(float)
    file    = keyword_set(file)
    integer = keyword_set(integer)
    null    = keyword_set(null)
    number  = keyword_set(number)
    row     = keyword_set(row)
    real    = keyword_set(real)
    scalar  = keyword_set(scalar)
    string  = keyword_set(string)
    
    ;Count the number of keywords that are set.
    nKey = array + column + complex + decimal + double + float + file + integer + $
           null + number + row + real + scalar + string
    
    ;Take care of conflicting cases
    if real + complex    gt 1 then message, 'Keywords REAL and COMPLEX are mutually exclusive.'
    if array + scalar    gt 1 then message, 'Keywords ARRAY and SCALAR are mutually exclusive.'
    if column + row      gt 1 then message, 'Keywords COLUMN and ROW are mutually exclusive.'
    if decimal + integer gt 1 then message, 'Keywords DECIMAL and INTEGER are mutually exclusive.'
    if null && nKey ne 1      then message, 'Keyword NULL cannot be used with other keywords.'
    
;-----------------------------------------------------
; Defined? \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if theType eq '' then begin
        ;Check if the variable is defined.
        ;   - If a scalar object or pointer is given, test if it is valid
        ;       * An undefined pointer or object is still a scalar
        ;       * As a special case, return true if the /SCALAR keyword is set
        ;       * NOTE: A 1-element array will still return true. However, the
        ;               SCALAR logic below will turn it false.
        ;   - Otherwise, test if the variable contains zero elements.
        case x_type of
            'POINTER': begin
                if x_size[x_size[0]+2] eq 1 $
                    then tf_isa = ptr_valid(x) || scalar $
                    else tf_isa = x_size[x_size[0]+2] gt 0
            endcase
            'OBJREF': begin
                if x_size[x_size[0]+2] eq 1 $
                    then tf_isa = obj_valid(x) || scalar $
                    else tf_isa = x_size[x_size[0]+2] gt 0
            endcase
            else: tf_isa = x_size[x_size[0]+2] gt 0
        endcase

        ;If TYPE was not given, then (TF_ISA and TF_TYPE) needs to reflect the status
        ;of TF_ISA alone. To accomplish this, set TF_TYPE to true.
        tf_type = 1
    
;-----------------------------------------------------
; Type \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    endif else begin
        ;Does the given type match the variable type?
        ;   - Check structure name
        ;   - Check object class (for scalar objects or 1-element ojbect arrays)
        ;       * A LIST is a scalar object with more than one element.
        ;   - Compare against the variable's actual type.
        case x_type of
            'STRUCT':    tf_type = theType eq 'STRUCT' ? 1 : size(x, /SNAME) eq theType
            'OBJREF': begin
                if x_size[x_size[0]+2] eq 1 $
                    then tf_type = theType eq 'OBJREF' ? 1 : obj_isa(x, theType) $
                    else tf_type = theType eq 'OBJREF' || theType eq 'LIST'
            endcase
            else: tf_type = theType eq x_type
        endcase

        tf_isa = 1
    endelse
    
;-----------------------------------------------------
; File \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if file then message, 'I do not know how to implement the FILE keyword. Use IsA().'
    
;-----------------------------------------------------
; Array \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if array then begin
        ;One or more dimensions
        if x_size[0] ge 1 $
            then tf_isa = 1 and tf_isa $
            else tf_isa = 0
    endif
    
;-----------------------------------------------------
; Scalar \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if scalar then begin
        ;Zero dimensions and one element
        if x_size[0] eq 0 && x_size[x_size[0]+2] eq 1 $
            then tf_isa = 1 and tf_isa $
            else tf_isa = 0
    endif

;-----------------------------------------------------
; Column \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if column then begin
        ;Two dimensions, the first being of size 1 (i.e. a 1xN array)
        if x_size[0] eq 0 || (x_size[0] eq 2 && x_size[1] eq 1) $
            then tf_isa = 1 and tf_isa $
            else tf_isa = 0
    endif

;-----------------------------------------------------
; Complex \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if complex then begin
        case x_type of
            'COMPLEX':  tf_isa = 1 and tf_isa
            'DCOMPLEX': tf_isa = 1 and tf_isa
            else:       tf_isa = 0
        endcase
    endif
    
;-----------------------------------------------------
; Decimal \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if decimal || float then begin
        case x_type of
            'FLOAT':     tf_isa = 1 and tf_isa
            'DOUBLE':    tf_isa = 1 and tf_isa
            'COMPLEX':   tf_isa = 1 and tf_isa
            'DCOMPLEX':  tf_isa = 1 and tf_isa
            else:        tf_isa = 0
        endcase
    endif

;-----------------------------------------------------
; Double \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if double then begin    
        case x_type of
             'DOUBLE':   tf_isa = 1 and tf_isa      ;double
             'DCOMPLEX': tf_isa = 1 and tf_isa      ;dcomplex
            else:        tf_isa = 0
        endcase
    endif

;-----------------------------------------------------
; Integer \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if integer then begin
        case x_type of
            'BYTE':      tf_isa = 1 and tf_isa
            'INT':       tf_isa = 1 and tf_isa
            'LONG':      tf_isa = 1 and tf_isa
            'UINT':      tf_isa = 1 and tf_isa
            'ULONG':     tf_isa = 1 and tf_isa
            'LONG64':    tf_isa = 1 and tf_isa
            'ULONG64':   tf_isa = 1 and tf_isa
            else:        tf_isa = 0
        endcase
    endif

;-----------------------------------------------------
; Null \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if null then begin
        ;Parse the Help string
        ;   - [variable name]   UNDEFINED = !Null
        ;   - /NULL cannot be used with any other keyword, so ignore
        ;     any previous value of TF_ISA
        ;   - The Help output can some times have more than one element.
        ;     "!NULL" is always contained in the last.
        help, x, OUTPUT=helpStr
        tf_isa = stregex(helpStr[n_elements(helpStr)-1], '!NULL', /BOOLEAN, /FOLD_CASE)
    endif

;-----------------------------------------------------
; Number \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if number then begin
        case x_type of
            'BYTE':      tf_isa = 1 and tf_isa
            'INT':       tf_isa = 1 and tf_isa
            'LONG':      tf_isa = 1 and tf_isa
            'FLOAT':     tf_isa = 1 and tf_isa
            'DOUBLE':    tf_isa = 1 and tf_isa
            'COMPLEX':   tf_isa = 1 and tf_isa
            'DCOMPLEX':  tf_isa = 1 and tf_isa
            'UINT':      tf_isa = 1 and tf_isa
            'ULONG':     tf_isa = 1 and tf_isa
            'LONG64':    tf_isa = 1 and tf_isa
            'ULONG64':   tf_isa = 1 and tf_isa
            else:        tf_isa = 0
        endcase
    endif
        
;-----------------------------------------------------
; Real \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if real then begin
        case x_type of
            'UNDEFINED': tf_isa = 0
            'COMPLEX':   tf_isa = 0
            'STRING':    tf_isa = 0
            'STRUCT':    tf_isa = 0
            'DCOMPLEX':  tf_isa = 0
            'POINTER':   tf_isa = 0
            'OBJREF':    tf_isa = 0
            else:        tf_isa = 1 and tf_isa    ;any other non-complex numeric type
        endcase
    endif
        
;-----------------------------------------------------
; Row \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if row then begin
        ;One dimension
        if x_size[0] eq 0 || x_size[0] eq 1 $
            then tf_isa = 1 and tf_isa $
            else tf_isa = 0
    endif
        
;-----------------------------------------------------
; String \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if string then begin
        if x_type eq 'STRING' $
            then tf_isa = 1 and tf_isa $
            else tf_isa = 0
    endif
    
;-----------------------------------------------------
;Combine Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
        
    result = tf_isa and tf_type
    return, result
end

;-----------------------------------------------------
;Main Level Example Program \\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

print, FORMAT='(a25, 4x, a-18, 2x, a6)',  'VARIABLE',                 'MrIsA()',          'RESULT'
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '<undefined>',              '',                 MrIsA(foo)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '1.0d',                     '/NUMBER',          MrIsA(1.0d, /NUMBER)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '1.0d',                     '/FLOAT',           MrIsA(1.0d, /FLOAT)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '1.0d',                     '"Float"',          MrIsA(1.0d, 'Float')
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '1.0d',                     '/SCALAR',          MrIsA(1.0d, /SCALAR)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '1.0d',                     '/SCALAR, /FLOAT',  MrIsA(1.0d, /SCALAR, /FLOAT)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '"Hello"',                  '/STRING',          MrIsA('hello', /STRING)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '"Hello"',                  '/STRING, /SCALAR', MrIsA('hello', /STRING, /SCALAR)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '"Hello"',                  '/STRING, /ARRAY',  MrIsA('hello', /STRING, /ARRAY)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  'List(1,2,3)',              '"List"',           MrIsA(List(1,2,3), 'List')
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  'List(1,2,3)',              '/ARRAY',           MrIsA(List(1,2,3), /ARRAY)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '{MyStruct, Field1: "hi"}', '',                 MrIsA({MyStruct, Field1: "hi"})
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '{MyStruct, Field1: "hi"}', '"MyStruct"',       MrIsA({MyStruct, Field1: "hi"}, 'MyStruct')
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  '{MyStruct, Field1: "hi"}', '/ARRAY',           MrIsA({MyStruct, Field1: "hi"}, /ARRAY)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  'Ptr_New()',                '',                 MrIsA(Ptr_New())
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  'Ptr_New()',                '"Pointer"',        MrIsA(Ptr_New(), 'Pointer')
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  'Ptr_New()',                '/SCALAR',          MrIsA(Ptr_New(), /SCALAR)
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  'Obj_New("IDLgrModel")',    '"ObjRef"',         MrIsA(Obj_New('IDLgrModel'), 'ObjRef')
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  'Obj_New("IDLgrModel")',    '"IDLgrModel"',     MrIsA(Obj_New('IDLgrModel'), 'IDLgrModel')
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  'Obj_New("IDLgrModel")',    '"IDLitComponent"', MrIsA(Obj_New('IDLgrModel'), 'IDLitComponent')
print, FORMAT='(a25, 4x, a-20, 2x, i1)',  'Obj_New("IDLgrModel")',    '"IDLgrView"',      MrIsA(Obj_New('IDLgrModel'), 'IDLgrView')

end