; docformat = 'rst'
;
; NAME:
;       MrReciprocalGradient
;
;*****************************************************************************************
;   Copyright (c) 2014, University of New Hampshire                                      ;
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
;   Compute the gradient of a scalar or vector field using reciprocal vectors.
;
; References:
;   Paschmann, G, Daly, P.W., Analysis Methods for Multi-Spacecraft Data, ISSI Scientific
;       Report, 1998 (Chp 16.2)
;       http://geo.phys.spbu.ru/~runov/Cluster/analysis_methods_1_1.pdf
;
;   Maszl, C., The Curlometer Method and Cluster II, 2004
;       http://www.space.irfu.se/exjobb/2004_christian_maszl/Documentation/projectwork_maszl.pdf
;
;   Dunlop, W. M., Southwood, D. J., Glassmeier, K.-H., and Neubauer, F. M.: 
;       Analysis of multipoint magnetometer data, Adv. Space Res., 8, 9–10, 1988.
;       http://ac.els-cdn.com/027311778890141X/1-s2.0-027311778890141X-main.pdf?_tid=b19d7876-fa0c-11e1-91d7-00000aacb360&acdnat=1347147002_b1b1630516e6b3576e8e43063c6bf475
;
; :Categories:
;       Cluster
;
; :Params:
;       R1:         in, required, type=Nx3 float
;                   Position vectors (kilometers) of the first tetrahedron vertex.
;       R2:         in, required, type=Nx3 float
;                   Position vectors (kilometers) of the second tetrahedron vertex.
;       R3:         in, required, type=Nx3 float
;                   Position vectors (kilometers) of the third tetrahedron vertex.
;       R4:         in, required, type=Nx3 float
;                   Position vectors (kilometers) of the fourth tetrahedron vertex.
;       V1:         in, required, type=Nx3 float
;                   Scalar or vector field measured at the first tetrahedron vertex.
;       V2:         in, required, type=Nx3 float
;                   Scalar or vector field measured at the second tetrahedron vertex.
;       V3:         in, required, type=Nx3 float
;                   Scalar or vector field vectors of the third tetrahedron vertex.
;       V4:         in, required, type=Nx3 float
;                   Scalar or vector field measured at the fourth tetrahedron vertex.
;
; :Returns:
;       DIV_V:      Gradient of the input scalar or vector field (units * m^-1)
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
;       2015-10-13  -   Written by Matthew Argall
;-
function MrReciprocalGradient, r1, r2, r3, r4, v1, v2, v3, v4
	compile_opt idl2
	
	catch, the_error
	if the_error ne 0 then begin
		catch, /CANCEL
		if n_elements(pv) gt 0 then ptr_free, pv
		MrPrintF, 'LogErr'
		return, -1
	endif

	;Check magnetic field inputs
	sz1 = size(v1)
	sz2 = size(v2)
	sz3 = size(v3)
	sz4 = size(v4)
	if (sz1[0] gt 2) || (sz1[0] eq 2 && (sz1[1] ne 1 && sz1[1] ne 3)) $
		then message, 'V1 must be a scalar or vector field.'
	if sz2[1] ne sz1[1] || sz3[1] ne sz1[1] || sz4[1] ne sz1[1] $
		then message, 'Inputs must be all scalar fields or all vector fields.'
	if (sz1[0] eq 2) && (sz2[2] ne sz1[2] || sz3[2] ne sz1[2] || sz4[2] ne sz1[2]) $
		then message, 'Inputs must contain the same number of elements.'

	;Tensor order and number of vectors
	order = (sz1[0] eq 0) ? 0 : (sz1[0] eq 2 && sz1[1] eq 1) ? 1 : 3
	nv    = sz1[0] eq 1 ? 1 : sz1[2]

	;Create a pointer array to cycle through quantities.
	;   - Transpose to be [time, component]
	pv = ptrarr(4)
	if order eq 0 then begin
		pv[0] = ptr_new(v1)
		pv[1] = ptr_new(v2)
		pv[2] = ptr_new(v3)
		pv[3] = ptr_new(v4)
	endif else begin 
		pv[0] = ptr_new(transpose(v1))
		pv[1] = ptr_new(transpose(v2))
		pv[2] = ptr_new(transpose(v3))
		pv[3] = ptr_new(transpose(v4))
	endelse
	
	;Get the reciprocal vectors
	;   - Order as [time, component, vertex]
	recvec = MrReciprocalVectors(r1, r2, r3, r4)
	recvec = transpose(recvec, [1,0,2])
	
	;
	; Gradient of a scalar
	;   - grad(s) = ∂_i S
	;             = (dS/dx, dS/dy, dS/dz)
	;
	; Gradient of a vector
	;   - grad(v) = ∂_i V_j
	;             = (dvx/dx + dvx/dy + dvx/dz)_x
	;               (dvy/dx + dvy/dy + dvy/dz)_y
	;               (dvz/dx + dvz/dy + dvz/dz)_z
	;
	; Sum the contribution at each vertex.
	;
	; Indices in comments refer to
	;   - i : component i
	;   - j : component j
	;   - v : tetrahedron vertex v
	;   - t : time
	; and where
	;   - S : scalar
	;   - V : vector
	;   - T : tensor
	; 
	
	;SCALAR Field
	if order le 1 then begin
		grad = fltarr(nv, 3)
		for i = 0, 3 do begin
			grad[*,0] += ( recvec[*,0,i] * *pv[i] )  ; dS / dx
			grad[*,1] += ( recvec[*,1,i] * *pv[i] )  ; dS / dy
			grad[*,2] += ( recvec[*,2,i] * *pv[i] )  ; dS / dz
		endfor
		;Transpose to [component, time]: V_it
		grad = transpose(grad, [1,0])
	
	;VECTOR Field
	endif else begin
		grad = fltarr(nv, 3, 3)
		for i = 0, 3 do begin
			;T_tij = ∆_tiv * V_tj
			grad[*,0,0] += ( recvec[*,0,i] * (*pv[i])[*,0] )  ; dvx / dx  --> T_xx
			grad[*,0,1] += ( recvec[*,1,i] * (*pv[i])[*,0] )  ; dvy / dx  --> T_xy
			grad[*,0,2] += ( recvec[*,2,i] * (*pv[i])[*,0] )  ; dvz / dx  --> T_xz
			grad[*,1,0] += ( recvec[*,0,i] * (*pv[i])[*,1] )  ; dvx / dy  --> T_yx
			grad[*,1,1] += ( recvec[*,1,i] * (*pv[i])[*,1] )  ; dvy / dy  --> T_yy
			grad[*,1,2] += ( recvec[*,2,i] * (*pv[i])[*,1] )  ; dvz / dy  --> T_yz
			grad[*,2,0] += ( recvec[*,0,i] * (*pv[i])[*,2] )  ; dvx / dz  --> T_zx
			grad[*,2,1] += ( recvec[*,1,i] * (*pv[i])[*,2] )  ; dvy / dz  --> T_zy
			grad[*,2,2] += ( recvec[*,2,i] * (*pv[i])[*,2] )  ; dvz / dz  --> T_zz
		endfor
		;Transpose to [component, component, vertex]
		;   - This is such that T_tij --> T_jit
		;   - When T_jit is printed, it appears math-like
		;   - To dot T_jit into a 3xN vector:
		;       ∑_j ( T_jit * V_jt )
		grad = transpose(grad, [1,2,0])
	endelse
	
	;Free pointers
	ptr_free, pv

	return, grad
end