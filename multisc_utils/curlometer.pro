;+
; NAME:
;       CURLOMETER
;
; PURPOSE:
;
;       Calculate the reciprocal vectors for a 4-spacecraft tetrahedron configuration.
;       See references for details. Magnetic field is assumed to be in nano-Tesla while
;       positions are assumed to be given in kilometers.
;
; AUTHOR:
;
;       Matthew Argall
;		University of New Hampshire
;		Morse Hall, Room 113
;       8 Collge Rd.
;		Durham, NH, 03824
;       mry27@wildcats.unh.edu
;
; CATEGORY:
;
;       Data Analysis
;
; CALLING SEQUENCE:
;
;       J = reciprocalVectors(positions, fields)
;
; INPUT POSITIONAL PARAMETERS
;
;       POSITIONS   -   In. Required. Type=ptrarr(4) <- fltarr(3,*).
;                       3-component position (km) vectors for each of the 4-spacecraft
;                           that make up the tetrahedron.
;       FIELDS      -   In. Required. Type=ptrarr(4) <- fltarr(3,*).
;                       3-component magnetic field vector (nT) for each of the
;                           4 spacecraft that make up the tetrahedron. All position and
;                           field arrays must have the same number of elements and are
;                           assumed to be time-synchronized.
;
; RETURN VALUE:
;
;       J           -   The current density (micro-A / m^2)
;
; REFERENCES
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
; MODIFICATION HISTORY
;   10/26/2012  -   Current through each surface is summed together to give the total
;                   current through the tetrahedron.
;
;-
;******************************************************************************************;
function curlometer, positions, fields
    compile_opt idl2
    
    ;permeability of free space and conversion factors
    mu_0 = 1.25663706e-6                ;m kg s-2 A-2
    nT_to_microT = 1.0e-3
    km_to_m = 1.0e3
    
    ;number of spacecraft and number of data points
    n_sc = n_elements(positions)
    spacecraft = indgen(n_sc) + 1
    
    ;count the number of points per component and create a 3x3 identity matrix
    npts = n_elements((*positions[0])[0,*])
    eye = identity(3)
    
    ;allocate space for the current, then store the current through each of the faces of
    ;the tetrahedron in a pointer array
    J_surface = fltarr(3, npts)
    J = fltarr(3, npts)
    
    ;The spacecraft that make up each of the four surfaces of the tetrahedron
    vertex = [[1, 2, 3], $
              [1, 2, 4], $
              [1, 3, 4], $
              [2, 3, 4]] - 1        ;convert spacecraft number to 0-based index
    
    ;for the surfaces opposite to each spacecraft in the tetrahedron,
    foreach surf, spacecraft-1 do begin
        ;the difference in the fields of REF_SC and spacecraft K (M).
        B_ij = (*fields[vertex[0,surf]] - *fields[vertex[1,surf]]) * nT_to_microT
        B_ik = (*fields[vertex[0,surf]] - *fields[vertex[2,surf]]) * nT_to_microT
        
        ;the distance between REF_SC and spacecraft K (M).
        R_ij = (*positions[vertex[0,surf]] - *positions[vertex[1,surf]]) * km_to_m
        R_ik = (*positions[vertex[0,surf]] - *positions[vertex[2,surf]]) * km_to_m

        ;mu_0 * J . (R_ij x R_ik) = (B_ij . R_ik) - (B_ik . R_ij)
        rhs = dot_product(B_ij, R_ik) - dot_product(B_ik, R_ij)
        lhs = mu_0 * cross_product(R_ij, R_ik)
            
        ;for each component of the current density, J
        for component = 0, 2 do begin            
            ;divide the rhs by the i-th component of the lhs to get J
            J_surface[component,*] = rhs / dot_product(lhs, eye[*,component])
        endfor
        
        ;Sum the current through each surface to get the total current moving past the
        ;tetrahedron.
        J += J_surface          ;microA / m^2
    endforeach
    
    return, J
end