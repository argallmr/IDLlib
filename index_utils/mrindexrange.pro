; docformat = 'rst'
;
; NAME:
;    MrIndexRange
;
; PURPOSE:
;+
;   Given a set of monotonically increasing data and a vector in the form 
;   [minimum value, maximum value] this program calculates the index range over which 
;   the min and max values span.
;
;   If the range given falls between two adjacent data points, the resulting index range
;   will indicate a single point in DATA less than RANGE[0].
;
; :Categories:
;    Index Utility
;
; :Examples:
;    IDL> density_asym
;
; :Params:
;       DATA:           in, required, type=any
;                       A vector of monotonically increasing or decreasing values.
;       RANGE:          in, required, type=integer/intarr(2\,N)
;                       The minimum and maximum values of `DATA` for which the
;                           index range is to be returned, where RANGE[0,*] is the
;                           minimum range in `DATA` and RANGE[1,*] is the maximum
;                           range in `DATA` (or vice versa). All [min,max] range
;                           pairs must be strictly ascending or descending.
;
; :Keywords:
;       STRIDE:         out, optional, type=integer
;                       If one is indexing from `IRANGE`[0] to `IRANGE`[1], then
;                           STRIDE indicates whether the stride should increase
;                           or decrease. E.g.::
;                               output = data[range[0]:range[1]:stride]
;       SORT:           in, optional, type=boolean, default=0
;                       If set, `IRANGE` will be ordered from smallest to largest.
;
; :Returns:
;       IRANGE:         A 2xN array giving the index range within `DATA`
;                           corresponding to the values of `RANGE`. If the matches
;                           are not exact, DATA[IRANGE] lie just inside of RANGE.
;
; :Author:
;    Matthew Argall::
;    University of New Hampshire
;    Morse Hall Room 113
;    8 College Road
;    Durham, NH 03824
;    matthew.argall@wildcats.unh.edu
;
; :History:
;    Modification History::
;       05/06/2013  -   Written by Matthew Argall
;       2013-10-25  -   Order `IRANGE` [min, max]. Was rounding up when range[0] > max(data).
;                           Round up if `DATA` is negative. - MRA
;       2014/01/26  -   Typo to check of RANGE is inside DATA resulted bumping exact
;                           values and leaving rounded values as is. Fixed. - MRA
;       2014/05/22  -   Typo caused ranges to be bumped when exact match was found. Fixed. - MRA
;       2014/06/02  -   Both DATA and RANGE can be in descending order. - MRA
;       2014/06/03  -   Added the STRIDE keyword. Indexing problems were occurring when
;                           RANGE fell between two adjacent points in DATA. Fixed. - MRA
;       2014/06/11  -   Added the ERANGE parameter. More than one [min,max] range pair
;                           are accepted. - MRA
;       2014/07/19  -   Typo was changing data values instead of index values. Fixed. - MRA
;       2014/10/27  -   Added the SORT keyword. Accept a single range only. Renamed from
;                           getIndexRange.pro to MrIndexRange.pro - MRA
;       2014/10/29  -   Handle case when DATA has one elements. IRANGE guaranteed to be
;                           between 0 and nPts, where nPts-1 is the number of point in DATA. - MRA
;-
function MrIndexRange, data, range, $
SORT=order, $
STRIDE=stride
    compile_opt strictarr
    on_error, 2
    
    ;Check Inputs
    nPts  = n_elements(data)
    order = keyword_set(order)
    if nPts              eq 0 then message, 'DATA must have at least 1 element.'
    if n_elements(range) ne 2 then message, 'RANGE must have 2 elements: [min, max].'

    ;Descending order?
    highLow = range[0] gt range[1] ? 1 : 0
    if nPts lt 2 $
        then ascending = 1 $
        else ascending = data[1] gt data[0] ? 1 : 0
    
    ;Stride
    ;   - If highLow and ascending are the same, then STRIDE=-1
    if (highLow and ascending) || (highLow eq 0 && ascending eq 0) $
        then stride = -1 $
        else stride = 1
    
    ;Locate the index values of RANGE within DATA
    ;   - If DATA has only 1 point, then the index range is [0,0]
    if nPts eq 1 then return, [0, 0]
    iRange = value_locate(data, range)

    ;If RANGE is smaller than DATA[0], then take index 0
    if irange[0] eq -1 then iRange[0] = 0
    if irange[1] eq -1 then iRange[1] = 0
    
    ;If the indices are the same, then they fall between two adjacent points in DATA.
    if irange[0] eq irange[1] then return, iRange

;---------------------------------------------------------------------
; Ascending Data /////////////////////////////////////////////////////
;---------------------------------------------------------------------
    if ascending then begin
        ;Descending Range
        if highLow then begin
            ;Endpoints greater (less) than the maximum (minimum) range desired?
            if data[iRange[0]] gt range[0] then iRange[0]--
            if data[iRange[1]] lt range[1] then iRange[1]++
            
        ;Ascening Range
        endif else begin
            ;Endpoints less (greater) than than the minimum (maximum) range desired?
            if data[iRange[0]] lt range[0] then iRange[0]++
            if data[iRange[1]] gt range[1] then iRange[1]--
        endelse

;---------------------------------------------------------------------
; Descending /////////////////////////////////////////////////////////
;---------------------------------------------------------------------
    endif else begin
        ;Descending Range
        if highLow then begin
            ;Endpoints greater (less) than the maximum (minimum) range desired?
            if data[iRange[0]] gt range[0] then range[0]++
            if data[iRange[1]] lt range[1] then range[1]--
        
        ;Ascending Range
        endif else begin
            ;Endpoints less (greater) than than the minimum (maximum) range desired?
            if data[iRange[0]] lt range[0] then iRange[0]--
            if data[iRange[1]] gt range[1] then iRange[1]++
        endelse
    endelse
    
    ;Order from smallest to largest?
    if order then if irange[0] gt irange[1] then irange = irange[[1,0]]
    
    ;Ensure indices do not extend outside of data range
    iRange = 0 > iRange < (nPts-1)
    
    ;Transpose the result to return a 2xN array
    return, iRange
end




;---------------------------------------------------------------------
; Main Level Example Program: IDL> .r MrIndexRange ///////////////////
;---------------------------------------------------------------------
;EXAMPLE - Ascending data
data = indgen(10) + 0.5
r1   = [0,11]
r2   = [11,0]
r3   = [2, 7]
r4   = [9, 4]
ir1  = MrIndexRange(data, r1)
ir2  = MrIndexRange(data, r2)
ir3  = MrIndexRange(data, r3)
ir4  = MrIndexRange(data, r4)
print, 'Data: [' + strjoin(string(data, FORMAT='(f0.1)'), ', ') + ']'
print, FORMAT='(%"   %s      %s      %s")', 'Range', 'Indices', 'Data'
print, FORMAT='(%"[%4.1f, %4.1f]   [%2i, %2i]   [%4.1f, %4.1f]")', r1, ir1, data[ir1]
print, FORMAT='(%"[%4.1f, %4.1f]   [%2i, %2i]   [%4.1f, %4.1f]")', r2, ir2, data[ir2]
print, FORMAT='(%"[%4.1f, %4.1f]   [%2i, %2i]   [%4.1f, %4.1f]")', r3, ir3, data[ir3]
print, FORMAT='(%"[%4.1f, %4.1f]   [%2i, %2i]   [%4.1f, %4.1f]")', r4, ir4, data[ir4]
print, ''


;EXAMPLE - Descending data
data = reverse(indgen(10)) + 0.5
r1   = [0,11]
r2   = [11,0]
r3   = [2, 7]
r4   = [9, 4]
ir1  = MrIndexRange(data, r1)
ir2  = MrIndexRange(data, r2)
ir3  = MrIndexRange(data, r3)
ir4  = MrIndexRange(data, r4)
print, '------------------------------------'
print, 'Data: [' + strjoin(string(data, FORMAT='(f0.1)'), ', ') + ']'
print, FORMAT='(%"   %s      %s      %s")', 'Range', 'Indices', 'Data'
print, FORMAT='(%"[%4.1f, %4.1f]   [%2i, %2i]   [%4.1f, %4.1f]")', r1, ir1, data[ir1]
print, FORMAT='(%"[%4.1f, %4.1f]   [%2i, %2i]   [%4.1f, %4.1f]")', r2, ir2, data[ir2]
print, FORMAT='(%"[%4.1f, %4.1f]   [%2i, %2i]   [%4.1f, %4.1f]")', r3, ir3, data[ir3]
print, FORMAT='(%"[%4.1f, %4.1f]   [%2i, %2i]   [%4.1f, %4.1f]")', r4, ir4, data[ir4]
print, ''


end