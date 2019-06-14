; docformat = 'rst'
;
; NAME:
;   MRCREATECT
;
;+
;   The purpose of this program is to create different colors tables that can be loaded
;   via TVLCT
;
; :Categories:
;   Plot Utility
;
; :Keywords:
;       CLIP:           in, optional, type=integer/intarr(2)
;                       The lower and upper bound on the color table indices to load. If
;                           CLIP is a scalar, it is the lower bound.
;       NCOLORS:        in, optional, type=boolean, default=256
;                       The number of colors used to create the color table.
;       REVERSE:        in, optional, type=boolean, default=0
;                       Reverse the selected colortable.
;       ROW:            in, optional, type=boolean, default=0
;                       TVLCT takes an Nx3 array whereas object graphics take a 3xN array.
;                           Set this keyword to return a 3xN array
;
;       BLUE:           in, optional, type=boolean, default=0
;                       A color table that ranges linearly from white to blue.
;       GREEN:          in, optional, type=boolean, default=0
;                       A color table that ranges linearly from white to green.
;       RED:            in, optional, type=boolean, default=0
;                       A color table that ranges linearly from white to red.
;       RWB:            in, optional, type=boolean, default=0
;                       A color table that ranges evenly from red to white to blue.
;
; :Returns:
;       color_table:    The color table specified by one of the keywords.
;
; :Uses:
;   Uses the following external programs::
;       linspace.pro
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
;       09/23/2013  -   Written by Matthew Argall
;       10/02/2013  -   Added the RED, GREEN, BLUE, NCOLORS and CLIP keywords.
;       12/03/2017  -   Added the NAME parameter and the 'rainbow3' color table. - MRA
;-
function MrCreateCT, name, $
CLIP = clip, $
NCOLORS = nColors, $
REVERSE = reverse, $
ROW = row, $
;Color Table Names
RED = red, $
GREEN = green, $
BLUE = blue, $
RWB = rwb
    compile_opt idl2
    on_error, 2
    
;---------------------------------------------------------------------
;Check Inputs ////////////////////////////////////////////////////////
;---------------------------------------------------------------------
    tf_name = n_elements(name) gt 0
    tf_blue  = keyword_set(blue)
    tf_green = keyword_set(green)
    tf_red   = keyword_set(red)
    tf_rwb   = keyword_set(rwb)
    if tf_name + tf_blue + tf_green + tf_red + tf_rwb gt 1 $
        then message, 'NAME, BLUE, GREEN, RED, and RWB are mutually exclusive.'
    
    case 1 of
        tf_blue:  cb_name = 'blue'
        tf_red:   cb_name = 'red'
        tf_green: cb_name = 'green'
        tf_rwb:   cb_name = 'red-white-blue'
        tf_name:  cb_name = name
        else: Message, 'Either NAME or one of {BLUE | GREEN | RED | RWB} must be set.'
    endcase
    
    reverse = keyword_set(reverse)
    row = keyword_set(row)
    if n_elements(ncolors) eq 0 then ncolors = 256
    if n_elements(clip) eq 0 then clip = [0, 255]
    if n_elements(clip) eq 1 then clip = [clip, 255]
    clip = 0 > clip < 255
    
;---------------------------------------------------------------------
;Create Color Table //////////////////////////////////////////////////
;---------------------------------------------------------------------
    
    case strlowcase(cb_name) of
        ;WHITE->BLUE
        'blue': begin
            r = linspace(255, 0, 256)
            g = linspace(255, 0, 256)
            b = bytarr(256) + 255
        endcase
        
        ;WHITE->GREEN
        'green': begin
            r = linspace(255, 0, 256)
            g = bytarr(256) + 255
            b = linspace(255, 0, 256)
        endcase
        
        ;WHITE->RED
        'red': begin
            r = bytarr(256) + 255
            g = linspace(255, 0, 256)
            b = linspace(255, 0, 256)
        endcase
        
        ;RED->WHITE->BLUE
        'red-white-blue': begin
            r = [bytarr(128)+255, linspace(255, 0, 128)]
            g = [linspace(0, 255, 128), linspace(255, 0, 128)]
            b = [linspace(0, 255, 128), bytarr(128)+255]
        endcase

        'rainbow3': begin
            ;color: black - purple - blue - cyan - green - yellow - orange - red - red7
            ;  r:     0      160       0       0      0      255      255    255    154
            ;  g:     0       32       0     255    255      255      165      0     12
            ;  b:     0      240     255     255      0        0        0      0     19
            ; idx:    0       36      71     107    143      179      214    250    255
            r = [ linspace(  0,160,37),       (linspace(160,  0,36))[1:*], (linspace(  0,  0,37))[1:*], $
                 (linspace(  0,  0,37))[1:*], (linspace(  0,255,37))[1:*], (linspace(255,255,36))[1:*], $
                 (linspace(255,255,37))[1:*], (linspace(255,154, 6))[1:*] ]
            g = [ linspace(  0, 32,37),       (linspace( 32,  0,36))[1:*], (linspace(  0,255,37))[1:*], $
                 (linspace(255,255,37))[1:*], (linspace(255,255,37))[1:*], (linspace(255,165,36))[1:*], $
                 (linspace(165,  0,37))[1:*], (linspace(  0, 12, 6))[1:*] ]
            b = [ linspace(  0,240,37),       (linspace(240,255,36))[1:*], (linspace(255,255,37))[1:*], $
                 (linspace(255,  0,37))[1:*], (linspace(  0,  0,37))[1:*], (linspace(  0,  0,36))[1:*], $
                 (linspace(  0,  0,37))[1:*], (linspace(  0, 19, 6))[1:*] ]
        endcase

        else: message, 'Colortable not recognized: "' + cb_name + '".'
    endcase
    
    ;Convert to byte arrays
	r = byte(round(r))
	g = byte(round(g))
	b = byte(round(b))
    
;---------------------------------------------------------------------
;Select Color Range //////////////////////////////////////////////////
;---------------------------------------------------------------------
    
    ;Clip the color table
    r = r[clip[0]:clip[1]]
    g = g[clip[0]:clip[1]]
    b = b[clip[0]:clip[1]]
    nClip = clip[1] - clip[0] + 1
    
    ;Select the NCOLORS
    if nColors ne nClip then begin
        iColors = (lindgen(nColors) * nClip) / (nColors-1)
        r = r[iColors]
        g = g[iColors]
        b = b[iColors]
    endif
    
    ;Create the color table and reverse it, if necessary.
    color_table = [[r], [g], [b]]
    if (reverse eq 1) then color_table = reverse(color_table, 1)
    if (row eq 1) then color_table = transpose(color_table)
    
    return, color_table
end
