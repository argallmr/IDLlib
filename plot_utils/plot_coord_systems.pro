; docformat = 'rst'
;
; NAME:
;       PLOT_COORD_SYSTEMS
;
; PURPOSE:
;+
;       Plot a second orthonormal basis within the standard (x, y, z) cartesian coordinate
;       system.
;
; :Categories:
;
;       Graphics Utility, Coordinate Systems
;
; :Examples:
;   See the main-level program at the end of this file::
;
;       IDL> .r plot_coord_systems
;
; :Params:
;
;       FRAME:          in, required, type="float(3,3)"
;                       A matrix that transforms a vector from normal (x, y, z) coordinate
;                           system into the new (x', y', z') frame. 
;                           If::
;                               x' = A * x
;
;                           then Frame = A
;       REF_FRAME:      in, optional, type=3x3 Float, default=identity(3)
;                       Reference frame from which to view `FRAME`. `FRAME` and REf_FRAME
;                           must be rotations from a common coordinate system.
;
; :Keywords:
;       AXES_LABELS:    in, optional, type=strarr(3)
;                       Labels to be placed on the FRAME coordinate system axes.
;       AX:             in, optional, type=float, default=30
;                       This keyword specifies the angle of rotation, about the X axis,
;                           in degrees towards the viewer. This changes the orientation
;                           of the 3D view.
;       AZ:             in, optional, type=float, default=-30
;                       This keyword specifies the counterclockwise angle of rotation
;                           about the Z axis. This changes the orientation of the 3D view.
;       COLORS:         in, optional, type=lonarr(3), default="cgColor['blue', 'green', 'red'])"
;                       The color of each coodinate axes of FRAME. If decomposed color is
;                           being used, the color indices cannot be loaded into indices
;                           1 or 2. Those are used for white and black, respectively.
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 113
;       8 Collge Rd.
;       Durham, NH, 03824
;       matthew.argall@wildcats.unh.edu
;
; :History:
;	Modification History::
;
;       10/29/2012  -   Written by Matthew Argall
;       11/01/2012  -   Swapped the foreground and background colors: now black on white
;       07/09/2013  -   Added the AZ and AX keywords. - MRA
;       2014/01/30  -   Replaced Load_Color with cgColor. - MRA
;       2014/03/14  -   AXIS_LABELS is now a keyword. Added the REF_FRAME param. - MRA
;       2014/03/29  -   Added the FILENAME keyword, use coyote graphics programs, Renamed
;                           AXIS_LABELS to LABELS. - MRA
;-
pro plot_coord_systems, frame, ref_frame, $
LABELS=labels, $
AX = ax, $
AZ = az, $
FILENAME=filename, $
COLORS = colors
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        MrPrintF, 'LogErr'
        return
    endif
    
    ;Defaults
    if n_elements(ax)       eq 0 then ax     = 30
    if n_elements(az)       eq 0 then az     = -30
    if n_elements(labels)   eq 0 then labels = ["X'", "Y'", "Z'"]
    if n_elements(filename) eq 0 then filename = ''
    fileroot = cgRootName(filename, DIRECTORY=directory, EXT=ext)
    ext = strupcase(ext)

    ;the reference coordinate system is the identity matrix
    ncolors = n_elements(colors)
    colors = cgColor(['Blue', 'Forest Green', 'Red'])
    ref_labels = ['X', 'Y', 'Z']
    
    ;create a circle of radius r=1
    x = findgen(101) / 50 - 1
    y = sqrt(1 - x^2)
    
    ;define the plot types.
    xy = [[0, 2], $     ;z vs. x
          [0, 1], $     ;y vs. x
          [1, 2]]       ;z vs. y
          
    ;If a reference frame was given, find the difference between the two frames
    ;
    ;   Ax = x'    =>   x = A^-1 x'     =>   B^-1 x" = A^-1 x'
    ;   Bx = x"    =>   x = B^-1 x"               x" = B A^-1 x'
    ;                   
    if n_elements(ref_frame) gt 0 $
        then frameOut = frame ## invert(ref_frame) $
        else frameOut = frame
    
;---------------------------------------------------------------------
;2D Plots ////////////////////////////////////////////////////////////
;---------------------------------------------------------------------

    ;Setup the post-script device
    if filename ne '' then begin
        fileOut = directory + fileroot + '_2D.' + ext
        hasIM = cgHasImageMagick()
        if hasIM then cgPS_Open, fileOut
    endif
    
    ;get the positions of the plots
    if (!d.flags and 256) ne 0 then window, 1, XSIZE=800, YSIZE=350
    positions = MrLayout([3,1], XGAP=9, ASPECT=1.0, CHARSIZE=1.5, WDIMS=[800,350])

    for i = 0, 2 do begin
        x0 = replicate(0,3)
        x1 = transpose(frameOut[*, xy[0,i]])
        y0 = replicate(0,3)
        y1 = transpose(frameOut[*, xy[1,i]])
        
        if i gt 0 then noerase=1
        
        ;Draw a circle of r=1 inside the plotting region to give an idea of the length of
        ;each unit vector in FRAME.
        cgPlot, x, y, $
                XTITLE=ref_labels[xy[0,i]], XRANGE=[-1,1], $
                YTITLE=ref_labels[xy[1,i]], YRANGE=[-1,1], $
                position=positions[*,i,0],  NOERASE=noerase
        cgOPlot, x, -y
        
        ;draw each unit vector in FRAME a different colored arrow
        cgArrow, x0[0], y0[0], x1[0], y1[0], /DATA, COLOR=colors[0]
        cgArrow, x0[1], y0[1], x1[1], y1[1], /DATA, COLOR=colors[1]
        cgArrow, x0[2], y0[2], x1[2], y1[2], /DATA, COLOR=colors[2]
        
        ;plot FRAME's labels on each arrow
        cgText, x1, y1, labels, /DATA, CHARSIZE=1.5, COLOR=colors
    endfor
    
;---------------------------------------------------------------------
;3D Plot /////////////////////////////////////////////////////////////
;---------------------------------------------------------------------

    ;Setup the post-script device
    if filename ne '' then begin
        fileOut = directory + fileroot + '_3D.' + ext
        hasIM = cgHasImageMagick()
        if hasIM then cgPS_Open, fileOut
    endif
    
    ;make a 3D plot
    if (!d.flags and 256) ne 0 then window, 2
    cgSurf, fltarr(2,2), /NODATA, $
            XRANGE=[-1,1], YRANGE=[-1,1], ZRANGE=[-1,1], /SAVE, $
            XSTYLE=5, YSTYLE=5, ZSTYLE=5, ROTZ=az, ROTX=ax, CHARSIZE=3, $
            POSITION=[0,0,1,1]
	
    ;draw the axes so that they intersect at the origin, not so that they are bordering
    ;the plotting region
    cgAxis, 0, /XAXIS, /T3D
    cgAxis, 0, /YAXIS, /T3D
    cgAxis, 0, /ZAXIS, /T3D
    
    ;label each axis
    cgText, 1, 0, Z=0, 'X', /DATA, /T3D, CHARSIZE=3, TEXT_AXES=2
    cgText, 0, 1, Z=0, 'Y', /DATA, /T3D, CHARSIZE=3, TEXT_AXES=2
    cgText, 0, 0, Z=1, 'Z', /DATA, /T3D, CHARSIZE=3, TEXT_AXES=2
    
    ;draw the new frame
    tri_arrow, [replicate(0,1,3), transpose(frame[*,0])], $
               [replicate(0,1,3), transpose(frame[*,1])], $
               [replicate(0,1,3), transpose(frame[*,2])], $
               COLOR=colors, LABEL=labels, /DATA
    
    ;draw lines connecting the new frame to the old frame to better visualize the
    ;relationship
    for i = 0, 2 do begin
        ;draw a line over to the z-axis
        plots, [frameOut[i,0], 0], [frameOut[i,1], 0], [frameOut[i,2], frameOut[i,2]], $
               COLOR=colors[i], LINESTYLE=2, /DATA, /T3D
        
        ;draw a line down to the xy-plane
        plots, [frameOut[i,0], frameOut[i,0]], [frameOut[i,1], frameOut[i,1]], [frameOut[i,2], 0], $
               COLOR=colors[i], LINESTYLE=2, /DATA, /T3D
        
        ;draw a line from the xy-plane to the x-axis
        plots, [frameOut[i,0], frameOut[i,0]], [frameOut[i,1], 0], [0, 0], $
               COLOR=colors[i], LINESTYLE=2, /DATA, /T3D
        
        ;draw a line from the xy-plane to the y-axis
        plots, [frameOut[i,0], 0], [frameOut[i,1], frameOut[i,1]], [0, 0], $
               COLOR=colors[i], LINESTYLE=2, /DATA, /T3D
    endfor

	;Write to file
	if filename ne '' then begin
	    if hasIM then begin
	        if ext eq 'PS' $
	            then cgPS_Close $
	            else cgPS_Close, FILETYPE=ext, /DELETE_PS
	    endif else void = cgSnapShot(FILENAME=fileOut, /NODIALOG)
	endif
end


;---------------------------------------------------
; Main Level Example Program (.r plot_coord_systems)
;---------------------------------------------------

;Say you have a coordinate system transformation x' = A ## x where
A = [[ 0.8451,  0.2598,  0.4673], $
     [-0.3757,  0.9104,  0.1732], $
     [-0.3804, -0.3219,  0.8670]]
     
;Then to see how the x' frame looks within the frame of x,
plot_coord_systems, A






end