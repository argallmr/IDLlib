; docformat = 'rst'
;
; NAME:
;
;       POLARIZATION
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
;       The purpose of this program is to determine the polarization and other polarization
;       related parameters of a wave.
;
;       IMPORTANT:
;           Matrices are stored in the mathematical sense, not in the IDL sense. As an
;           example, the power spectral matrix, J_prime, is::
;
;               J_prime = [[Hxx, Hxy, Hyz], $
;                          [Hyx, Hyy, Hyz], $
;                          [Hzx, Hzy, Hzz]]
;
;           Thus, to access the Hxy component, one must select matrix index J_prime[1,0]
;
;   Physical Notes::
;       1) The magnetic field is assumed to be detrended and in a field-aligned coordinate
;           system wtih the mean magnetic field pointing along the z-axis. If this is not
;           the case, specify the NDETREND and/or NFAR keywords.
;       2) Samson is ultimately the reference you want, followed by Means and Rankin.
;           Fowler gives pretty much the same theoretical analysis as Rankin, but is
;           slightly more detailed when it comes to averaging over time and frequency.
;       3) Without smoothing over frequencies (i.e. NFAVG=0), the polarization at each
;           frequency will be 1. Consider a monochromatic wave whose k-vector makes an
;           angle of 40 degrees with respect to the mean magnetic field direction. 100%
;           of the monochromatic wave will be polarized at this angle. That is to say,
;           without mixing frequencies, the polarization is pure at all frequencies.
;       4) References to Percival and Barakat give the same analysis as Fowler, Rankin,
;           Means, and Samson, but use an enseble average as opposed to a time average.
;           The steps are qualitatively similar and Percival especially is enlightening,
;           but to generate an enseble, one would need to create a model and run it many
;           many times.
;       5) There are two places where NaNs are explicitly used to fill array elements::
;           a) If |B| is too small, the rotation matrix into the wave normal frame cannot
;               be properly determined.
;           b) If the trace of the covariance matrix is not sufficiently large, the wave-
;               normal direction cannot be determined properly (Applicable to the `MEANS`
;               method only).
;
;   Programming Notes::
;       * If -1 < k_dot_b < 1, then 0 < kdotb_angle < 180 and 0 < ellipticity < 1. k_dot_b
;         must be positive in order for ellipticity to be calculated properly.
;       * The same problem of 0 < ellipiticy < 1 arose when the rotation was not performed
;         properly.
;
;   References::
;
;       Barakat, R., Theory of Coherency Matrix for Light of Arbitrary Spectral Bandwidth,
;           Journal of the Optical Society of America, 53, 3, 1963.
;       Fowler, R. A., et. al, Polarization Analysis of Natural and Artificially Induced
;           Geomagnetic Micropulsations, Journal of Geophysical Research, 72, 11, 1967.
;       Means, J., Use of Three-Dimensional Covariance Matrix in Analyzing the
;           Polarization Properties of Plane Waves, Journal of Geophysical Research,
;           77, 28, 1972.
;       Percival, D. and Walden, A., Spectral Analysis for Physical Applications: Multitaper
;           and Conventional Univariate Techniques, Cambridge University Press, 1993.
;       Rankin, D., and Kurtz, R., Statistical Study of Micropulsation Polarization,
;           Journal of Geophysical Research, 75, 28, 1970.
;       Samson, J. C., and Olson, J. V., Some comments on the description of polarization
;           states of waves, Geophys J. R. Astr. Soc., 115-119, 61, 1980.
;
; :Categories:
;
;       Math Utility, Polarization
;
; :Examples:
;   See the test program "test_mrpolarization.pro"
;
; :Uses:
;   Uses the following external programs::
;       nfft_intervals.pro
;       fft_freqs.pro
;       logspace.pro
;       linspace.pro
;       rotate_matrix.pro
;       MrDetrendRotate.pro
;       undefine.pro
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 113
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@wildcats.unh.edu
;
; :History::
;   Modification History::
;       03/13/2013  -   Written by Matthew Argall
;       03/29/2013  -   Added the KDOTB_ANGLE keyword.
;       03/30/2013  -   Added the METHOD keyword and incorporated the method introduced
;                           by Fowler, which uses minimum variance to determine the
;                           wave-normal direction.
;       06/13/2013  -   Added the IS_DETRENDED keyword. - MRA
;       08/02/2013  -   Renamed from "polarization" to "MrPolarization". Use MrFFT to
;                           compute FFTs before doing the polarization analysis. Keywords
;                           NDETREND and NFA were added to try to reduce the amount of
;                           prep-work. - MRA
;       08/03/2013  -   Added K_VEC keyword. - MRA
;       08/09/2013  -   Do not divide by T when creating the spectral matrix. - MRA
;       09/04/2013  -   INTENSITY was being returned as a complex array. Was not taking
;                           the arc-cosine of K_DOT_B to turn it into an angle. Fixed.
;                           Apply NFAVG to KDOTB_ANGLE and K_HAT. Properly convert
;                           KDOTB_ANGLE to an angle (in radians). Indices were being
;                           truncated when trying to negate negative values of
;                           K_HAT[2,*,*]. Fixed. - MRA
;       09/19/2013  -   Finally understand how ellipticity is calculated. See in-line
;                           comments for details. - MRA.
;       2013/11/13  -   Replaced !Null with the UNDEFINE procedure. - MRA
;       2013/11/14  -   Replaced MEAN with CMAPPLY for versions earlier than 8.0. Switched
;                           the default NFAVG to 5. - MRA
;       2014/08/23  -   Fixed numerical error that resulted in |sin(theta)| > 1. Truncate
;                           the first and last NFAVG-1 frequencies.
;       2014/10/07  -   Set /NAN flat when averaging over frequencies to prevent NANs from
;                           smearing. - MRA
;-
;***************************************************************************************
;+
;   The purpose of this function is to calculate the wave-normal direction by using
;   the imaginary, anti-symmetric part of the spectral matrix, as done in Means.
;
; :Private:
;
; :Params:
;
;       J_PRIME:                in, required, type=3x3xN numeric
;                               Spectral matrix in the frame of the observer.
;       IPOL:                   out, required, type=long
;                               Indices of the frequencies that are polarized
;       ILIN:                   out, required, type=long
;                               Indices of the frequencies that are linear (unpolarized)
;
; :Keywords:
;       K_VEC:                  out, optional, type=3xN numeric
;                               The 3 component k vector.
;
; :Returns:
;
;       K_HAT:                  The wave normal direction at each frequency.
;-
function MrPolarization_Means, J_prime, iPol, iLin, nPol, nLin, $
K_VEC = k_vec
    compile_opt idl2, hidden
    on_error, 2

    ;allocate memory
    J_prime_dims = size(J_prime, /DIMENSIONS)
    npts         = J_prime_dims[0]
    nfreqs       = J_prime_dims[1]
    ab           = fltarr(npts, nfreqs)
    k_hat        = fltarr(npts*nfreqs, 3)
    if arg_present(k_vec)   then k_vec = fltarr(npts*nfreqs, 3)
    if n_elements(tol) eq 0 then tol   = 1e-6

;-----------------------------------------------------
; Wave Normal Direction \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;The wave normal direction can now be determined by examining the imaginary part of
    ;the spectral density matrix (Means pg. 5554, Bakarat eq 3.19).
    
    ;Using the imaginary components.
    ;a*b = HxHy^2 + HzHx^2 + HyHz^2
    ab = sqrt(imaginary(J_prime[*,*,1,0])^2 + $     ;kz^2    = HxHy^2
              imaginary(J_prime[*,*,2,0])^2 + $     ;(-ky)^2 = HxHz^2
              imaginary(J_prime[*,*,2,1])^2)        ;kx^2    = HyHz^2

    ;The imaginary part of the power spectral matrix for linearly polarized waves
    ;is the 0-matrix. Thus, the analysis that follows cannot be undertaken. (Means
    ;pg. 5555-6). Treat them separately later.
    ;   - The minimum value of AB depends on the sampling interval, dt
    ;   - A tolerance of 1e-6 can be too large...
    iLin  = where(ab le 0, nLin, COMPLEMENT=iPol, NCOMPLEMENT=nPol)
    
    ;ILIN and IPOL are 1D subscripts into a 2D vector. Reform J_prime so that subscript-
    ;rounding does not occur (e.g. a = findgen(10) ... print, a[[20]]).
    J_prime = reform(J_prime, npts*nfreqs, 3, 3)

;-----------------------------------------------------
; Linear Polarization \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if nLin gt 0 then begin
        ;The power of the linearly polarized wave
        ;Tr[J'] = a^2 = Jxx + Jyy + Jzz   --   (J is purely real)
        a2 = real_part(J_prime[iLin,0,0] + J_prime[iLin,1,1] + J_prime[iLin,2,2])
        
        ;If there is no power at the frequency
        i_NoPower = where(a2 lt 1e-5, n_NoPower, COMPLEMENT=iPower, NCOMPLEMENT=nPower)
        if n_NoPower gt 0 then begin
            ;There is no direction of propagation.
            k_hat[iLin[i_NoPower],*] = replicate(!values.f_nan, 3, n_NoPower)
        endif
            
        ;Otherwise
        if nPower gt 0 then begin
            ;Calculate the direction of the linearized wave
            Lx = sqrt(real_part(J_prime[iLin[iPower],0,0]) / a2[iPower])    ;(Jxx / a^2)^(1/2)
            Ly = real_part(J_prime[iLin[iPower],1,0]) / (a2[iPower] * Lx)   ;Jxy / (a^2 * Lx)
            Lz = real_part(J_prime[iLin[iPower],2,0]) / (a2[iPower] * Lx)   ;Jxz / (a^2 * Lx)
            
            ;Store the direction of propagation
            k_hat[iLin[iPower],*] = [[Lx], [Ly], [Lz]]
        endif
    endif

;-----------------------------------------------------
; Polarized Waves \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if nPol gt 0 then begin
        ;Return the k-vector?
        if arg_present(k_vec) then begin
            k_vec[iPol,2] =  imaginary(J_prime[iPol,1,0])
            k_vec[iPol,1] = -imaginary(J_prime[iPol,2,0])
            k_vec[iPol,0] =  imaginary(J_prime[iPol,2,1])
        endif
        
        ;Note that dividing by "ab" normalizes the components.
        k_hat[iPol,2] =  imaginary(J_prime[iPol,1,0]) / ab[iPol]   ;kz =  HxHy / (a*b)
        k_hat[iPol,1] = -imaginary(J_prime[iPol,2,0]) / ab[iPol]   ;ky = -HxHz / (a*b)
        k_hat[iPol,0] =  imaginary(J_prime[iPol,2,1]) / ab[iPol]   ;kx =  HyHz / (a*b)
    endif

    ;This anaylsis has been done under the assumptions of a counter-clockwise,
    ;elliptically polarized plane wave. Thus, a clockwise polarized wave has k_hat < 0
    
    ;Reform the vectors back to their original shape
    J_prime = reform(J_prime, npts, nfreqs, 3, 3)

    return, k_hat
end


;+
;   The purpose of this function is to calculate the wave-normal direction by using
;   the real, symmetric part of the covariance matrix (the cross-spectral matrix). This
;   involves diagonalizing the real part of the covariance matrix and using the
;   vector associated with the minimum eigenvalue as the wave normal directin (i.e. we
;   obtain the wave-normal vector via a minimum variance approach, as is often stated in
;   the literature).
;
;   :Private:
;
;   :Params:
;
;       J_PRIME:                in, required, type=3x3xN numeric
;                               The real, symmetric part of the Spectral matrix in the
;                                   frame of the observer.
;
;   :Returns:
;
;       K_HAT:                  The wave normal direction at each frequency.
;-
function MrPolarization_Fowler, J_prime
    compile_opt idl2, hidden
    on_error, 2

    ;The wave normal direction can now be determined by examining either the real
    ;part of the spectral density matrix (Fowler, pg. 2873-4, Means pg. 5554, 
    ;Bakarat eq 3.19).
    
    J_prime_dims = size(J_prime, /DIMENSIONS)
    npts = J_prime_dims[2]
    nfreqs = J_prime_dims[3]
    k_hat = fltarr(3, npts, nfreqs)
    
    ;Diagonalizing the covariance matrix
    for i = 0, npts - 1 do begin
        for j = 0, nfreqs-1 do begin
            ;Calculate the eigenvectors of the covariance matrix. The wave-normal direction
            ;points along the direction of minimum variance, i.e. the direction associated
            ;with the smallest eigenvalue
            eigvals = eigenql(J_prime[*,*,i,j], /ABSOLUTE, /ASCENDING, EIGENVECTORS=eigvecs)
            k_hat[*,i,j] = eigvecs[*,0]
        endfor
    endfor

    return, k_hat
end


;+
;
;   The purpose of this program is to determine the polarization and other polarization
;   related parameters of a wave.
;
;   IMPORTANT:
;       Matrices are stored in the mathematical sense, not in the IDL sense. As an
;       example, the power spectral matrix, J_prime, is::
;
;           J_prime = [[Hxx, Hxy, Hyz], $
;                      [Hyx, Hyy, Hyz], $
;                      [Hzx, Hzy, Hzz]]
;
;       Thus, to access the Hxy component, one must select matrix index J_prime[1,0]
;
; :Params:
;       DATA:               in, required, type=string
;                           The filename of the CDF file to be opened
;       NFFT:               in, optional, type=int, default=N_ELEMENTS(DATA)
;                           The number of points to use per FFT
;       DT:                 in, optional, type=float. default=1
;                           The time between data samples. If not present, unit spacing
;                               is assumed.
;       NSHIFT:             in, optional, type=int. default=NFFT/2
;                           The number of points to shift ahead after each FFT.
;
; :Keywords:
;       COHERENCY:          out, optional, type=NxM float
;                           Coherency of the wave in the wave-normal frame. 0 indicates
;                               that the waves are incoherent while a value of 1 indicates
;                               complete coherence.
;       ELLIPTICITY:        out, optional, type=NxM float
;                           Ellipticity of the wave in the wave-normal frame. Counter-
;                               clockwise if arg(Jxy) > 0.
;       FILLVAL:            in, optional, type=same as `DATA`
;                           A value that represents bad points within `DATA`. They will
;                               be converted to NaNs before the FFT is performed, unless
;                               the `INTERP_PCT` keyword is used.
;       FREQUENCIES:        out, type=fltarr(NFFT)
;                           The frequency bins of the FFT
;       INTENSITY:          out, optional, type=NxM float
;                           Intensity of the wave in the wave-normal system.
;       INTERP_PCT:         in, optional, type=float, default=0.0
;                           The maximum percentage of `FILLVAL` allowed in an FFT of size
;                               `NPTS`. Below this percent, instances of the fill value
;                               will be interpolated over. Above this percent, fill values
;                               are converted to NaNs.
;       K_VEC:              out, optional, type=3xM float
;                           The 3 component k-vector.
;       K_HAT:              out, optional, type=3xM float
;                           A unit vector pointing in the wave-normal direction.
;       KDOTB_HAT:          out, optional, type=NxM float
;                           The angle between the wave normal direction and the mean
;                               magnetic field.
;       METHOD:             in, optional, type=int, default=1
;                           Two methods have been incorporated (with a third on the way).
;                               Method::
;                                   1 - Means, uses complex part of the covariance matrix
;                                        to determine the wave normal direction directly.
;                                   2 - Fowler diagonalizes the real part of the wave
;                                        normal direction and uses the minimum eigenvalue
;                                        as the wave-normal direction
;                                  [3]- Samson expands the covariance matrix in an ortho-
;                                        normal basis and computes the polarization
;                                        directly, without need of the wave-normal frame.
;       NDETREND:           in, optional, type=int, default=0
;                           If non-zero, `DATA` will be detrended. NDETREND number of
;                               points will be used to determine the average, background
;                               field that will be subracted from the data.
;       NFAS:               in, optional, type=in, default=0
;                           If non-zero, data will be rotated into a field-aligned
;                               coordinate system. NFA number of points will be used to
;                               determine the mean, background field. If `NDETREND` is
;                               also set, then NFAS will be set equal to NDETREND. The Z-
;                               axis then points along the background field, X is the
;                               cross product of Z and [0,1,0]. Y completes the system.
;                               [0,1,0] is the y-axis in the coordinate system of `DATA`.
;       NFAVG:              in, optional, type=int, default=7
;                           Number of frequency bins to average. Must be an odd integer
;                               <= 3.
;       POLARIZATION_ANGLE: out, optional, type=NxM float
;                           Angle of polarization, i.e. the angle between the wave-normal
;                               frame's x-axis and the major axis of the polarization
;                               ellipse.
;       SPECTRAL_MATRIX:    out, optional, type=3x3xNxM float
;                           The power spectral matrix of the waveform in the reference
;                               frame of the wave.
;       T0:                 in, optional, type=float, default=0.0
;                           Time offset in seconds at which `TIME` begins.
;       TIME:               out, type=fltarr(M)
;                           The time associated with each interval used in calculating
;                               the polarization and other parameters. This time is
;                               taken to be the center time of the interval unless
;                               `CENTER_TIME` is set to 0, in which case the initial
;                               time of the interval is taken.
;       WAVE_NORMAL_MATRIX: out, optional, type=2x2xNxM float
;                           The power spectral matrix in the wave-normal frame.
;       _REF_EXTRA:         in, optional, type=any
;                           Any keyword accepted by MrFFT is also accepted here via
;                               keyword inheritance.
;                           
; :Returns:
;       PZATION:            The plarization state of the wave.
;-
function MrPolarization, data, nfft, dt, nshift, $
COHERENCY = coherency, $
DIMENSION = dimension, $
ELLIPTICITY = ellipticity, $
FILLVAL = fillval, $
FREQUENCIES = frequencies, $
INTENSITY = intensity, $
INTERP_PCT = interp_pct, $
K_HAT = k_hat, $
K_VEC = k_vec, $
KDOTB_ANGLE = kdotb_angle, $
MEAN_FIELD = mean_field, $
METHOD = method, $
NDETREND = nDetrend, $
NFAS = nFAS, $
NFAVG = nfavg, $
POLARIZATION_ANGLE = polarization_angle, $
SPECTRAL_MATRIX = spectral_matrix, $
T0=t0, $
TIME = time, $
WAVE_NORMAL_MATRIX = wave_normal_matrix, $
_REF_EXTRA = extra
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        MrPrintF, 'LogErr'
        return, -1
    endif

;-----------------------------------------------------
;Check Inputs \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;Create defaults.
    if n_elements(nfft)        eq 0 then nfft        = floor(n_elements(data) / 4)
;    if n_elements(dt)          eq 0 then dt          = 1
    if n_elements(n_shift)     eq 0 then n_shift     = floor(nfft/2)
    if n_elements(center_time) eq 0 then center_time = 1
    if n_elements(nDetrend)    eq 0 then nDetrend    = 0
    if n_elements(nFAS)        eq 0 then nFAS        = 0
    if n_elements(nfavg)       eq 0 then nfavg       = 5
    if n_elements(method)      eq 0 then method      = 1
    
    ;Must be method 1 or 2
    if method lt 1 or method gt 2 then message, 'Invalid method. METHOD = {1 | 2}.'
    
    ;Make sure NFAVG is odd and >= 3
    if (nfavg mod 2) eq 0 or nfavg lt 3 then $
        message, 'NFAVG must be an odd integer <= 3.'
    
    ;Make sure nFA and nDetrend are equal, if both are non-zero
    if nFAS ne 0 and nDetrend ne 0 then nFAS = nDetrend
    
    ;Keep certain parameters?
    keep_coherency       = arg_present(coherency)
    keep_intensity       = arg_present(intensity)
    keep_mean_field      = arg_present(mean_field)
    keep_ellipticity     = arg_present(ellipticity)
    keep_time            = arg_present(time)
    keep_spectral_matrix = arg_present(spectral_matrix)
    keep_wave_normal     = arg_present(wave_normal_matrix)
    keep_angle           = arg_present(polarization_angle)
    keep_kvec            = arg_present(k_vec)
    keep_khat            = arg_present(k_hat)
    keep_kdotb_angle     = arg_present(kdotb_angle)
  
;-----------------------------------------------------
;Detrend the Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;Must hanlde the fill value before detrending and taking the FFT
    ;   - MrDetrendRotate will skip over NaN values when computing the background field
    ;       x Replace the fill value with NaN
    if n_elements(fillval) gt 0 then begin
        temp_data  = replace_fillval(data, fillval)
        theFillVal = !values.f_nan
    endif else begin
        temp_data  = data
    endelse

    ;Detrend the data
    if (nDetrend gt 0) or (nFAS gt 0) then begin
        temp_data = MrDetrendRotate(temp_data, nDetrend, nFAS, /NAN, $
                                    MEAN_FIELD = mean_field, $
                                    DIMENSION  = dimension)
    endif

;-----------------------------------------------------
;I. Take the FFT \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;Compute the FFT of the data
    fft_data = MrFFT2( temporary(temp_data), dt, $
                       DIMENSION    = dimension, $
                       T0           = t0, $
                       TIME         = time, $
                       FILLVAL      = theFillVal, $
                       FREQUENCIES  = frequencies, $
                       INTERP_PCT   = interp_pct, $
                       NFFT         = nfft, $
                       NSHIFT       = nshift, $
                      _STRICT_EXTRA = extra )
    
    ;Dimensions
    data_size = size(fft_data, /DIMENSIONS)
    npts      = data_size[0]
    nfreqs    = data_size[1]
    ncomps    = data_size[2]
    ifN       = nfreqs / 2.0
    
    ;Toss negative frequencies
    nDims_f   = size(frequencies, /N_DIMENSIONS)
    tf_keep_f = arg_present(frequencies)
    if tf_keep_f then begin
        if nDims_f eq 2 $
            then frequencies = frequencies[*,0:ifN] $
            else frequencies = frequencies[0:ifN]
    endif else begin
        frequencies = 0B
        void = temporary(frequencies)
    endelse

;-----------------------------------------------------
;Allocate Memory \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    
    ;allocate the polarization parameters' arrays
    if keep_coherency       then coherency          = fltarr(npts*nfreqs)
    if keep_intensity       then intensity          = fltarr(npts,nfreqs)
    if keep_ellipticity     then ellipticity        = fltarr(npts*nfreqs)
    if keep_angle           then polarization_angle = fltarr(npts*nfreqs)
    if keep_kvec            then k_vec              = fltarr(npts*nfreqs, 3)
    if keep_spectral_matrix then spectral_matrix    = complexarr(npts, nfreqs, 3, 3)
    if keep_wave_normal     then wave_normal_matrix = complexarr(npts, nfreqs, 2, 2)
    if keep_kdotb_angle     then kdotb_angle        = fltarr(npts, nfreqs)
    pzation = fltarr(npts*nfreqs)
    
    ;Variables
    J_prime = complexarr(npts, nfreqs, 3, 3)
    J       = complexarr(npts, nfreqs, 3, 3)
    Js      = complexarr(npts, nfreqs, 3, 3)
    k_hat   = fltarr(npts, nfreqs, 3)
    k_dot_b = fltarr(npts, nfreqs)
    R       = fltarr(npts, nfreqs, 3, 3)

;-----------------------------------------------------
;II. Covariance Spectral Matrix \\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    
    ;Due to the Hermetian nature of the spectral denstiy matrix (eq 3.18 Bakarat), 
    ;Means says,
    ;
    ;   The analytic representation of the real signal is easily obtained by 
    ;   multiplying the  Fourier transform of the real signal by the Heaviside step
    ;   function 
    ;
    ;       S(f) = 0        f <  0
    ;       S(f) = 1        f >= 0
    ;
    ;   and doubling the result.
    ;
    ; For a purely real time-series signal, the backwards frequencies will have the
    ; same phase and amplitude as the forward frequencies. Thus the total power
    ; can be computed as twice the power of the forward frequencies.

    ;Using Means' notation, calculate the spectral density matrix. The "prime"
    ;indicates that the spectral density matrix is NOT in the principle axis system.
    ;Dividing by the duration of the interval converts from Energy to Power.
    J_prime[0,0,0,0] = 2.0 * fft_data[*,*,0] * conj(fft_data[*,*,0])      ;HxHx
    J_prime[0,0,1,0] = 2.0 * fft_data[*,*,0] * conj(fft_data[*,*,1])      ;HxHy
    J_prime[0,0,2,0] = 2.0 * fft_data[*,*,0] * conj(fft_data[*,*,2])      ;HxHz
    J_prime[0,0,0,1] = 2.0 * fft_data[*,*,1] * conj(fft_data[*,*,0])      ;HyHx
    J_prime[0,0,1,1] = 2.0 * fft_data[*,*,1] * conj(fft_data[*,*,1])      ;HyHy
    J_prime[0,0,2,1] = 2.0 * fft_data[*,*,1] * conj(fft_data[*,*,2])      ;HyHz
    J_prime[0,0,0,2] = 2.0 * fft_data[*,*,2] * conj(fft_data[*,*,0])      ;HzHx
    J_prime[0,0,1,2] = 2.0 * fft_data[*,*,2] * conj(fft_data[*,*,1])      ;HzHy
    J_prime[0,0,2,2] = 2.0 * fft_data[*,*,2] * conj(fft_data[*,*,2])      ;HzHz

    ;This is the spectral density matrix [covariance matrix in the frequency domain]
    ;(c.f. "Technique and Theory" and eq 1 in Means or eq 3.18 in Bakarat). IDL notation
    ;is used ... J_prime[col, row, time, frequency]

;-----------------------------------------------------
;III. Wave Normal Direction \\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

    ;Means?
    if method eq 1 then begin
        ;Keep the non-normalized wave vector?
        if keep_kvec then begin
            k_hat = MrPolarization_Means(J_prime, ipol, ilin, npol, nlin, K_VEC=k_vec)
            k_vec = reform(k_vec, npts, nfreqs, 3)
            k_vec = k_vec[*, ifrange[0]:ifrange[1], *]
            
        endif else k_hat = MrPolarization_Means(J_prime, ipol, ilin, npol, nlin)
    
    ;Fowler?
    endif else if method eq 2 then begin
        k_hat = MrPolarization_Fowler(real_part(J_prime))
        ipol = lindgen(nfreqs)
        npol = nfreqs
        nlin = 0
    
    ;Samson?
    endif else if method eq 3 then begin
        ;Not implemented yet.
    endif

;-----------------------------------------------------
;IV. Wave-Normal System \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

    ;Polarization is always referenced to the magnetic field direction. A wave is
    ;right-hand polarized if it rotates in a counter-clockwise direction when looking
    ;down B_hat, and left-handed if it rotates clockwise. 
    
    ;Now, the covariance spectral matrix must be rotated into a frame in which the
    ;wave normal direction is along one of the principal axes (the z-axis). Then,
    ;choosing x-direction to be in the k_hat dot B_hat plane, for elliptiicty
    ;measurement purposes, and the y-axis to complete the system. (Means, pg. 5555)
    
    ;
    ;Means says:
    ;
    ;  It is important to note that as a result of the original assumptions this is the wave
    ;  normal direction for a counterclockwise elliptically polarized plane wave. Since the
    ;  sense of polarization of the wave changes if we let k' = k, this fact poses no real
    ;  restriction on the analysis. If a wave with a counterclockwise rotation as a wave
    ;  normal vector k, a wave with the same wave normal vector but with clockwise rotation
    ;  will, in the above analysis, result in a wave normal vector -k.
    ;
    ;  ...For right-handed waves, (k dot B) > 0, whereas, for left-handed waves,
    ;  (k dot B) < 0.
    ;
    ;Therefore, in the new coordinate system, (x', y', z'), the angle that the z'-axis
    ;makes with B must lie between 0 and 90 degrees so that left-hand polarized waves,
    ;which have a -k_hat normal vector, do not inadvertantly get turned into right-hand
    ;polarized waves by allowing k_hat to lie always along the z'-axis.
    ;
    ;As such we will create the z'-axis by taking k-hat and, wherever (k dot B) < 0,
    ;let z' = -z'.
    ;
    ;Now, because (k dot B) > 0 = right-hand polarized and (k dot B) < 0 is left-hand
    ;polarized, we really only know the direction of k with respect to the mangetic field
    ;to within +/- 90 degrees. As such, the kdotb_angle will be the angle between the
    ;z'-axis and B.
    ;
    
    ;The mean field is along the z-axis, so dotting k with [0,0,1] gives kz
    ;   - B is suppose to be rotated so that the average field is along the z-axis.
    ;   - Therefore, k \cdot B_hat = kz
    k_dot_b = k_hat[*,2]

    ;Make sure that the new z-hat direction is always parallel to B
    z_prime_hat = k_hat
    iAntiPar    = where(k_dot_b lt 0, nAntiPar)
    if nAntiPar gt 0 then begin
        z_prime_hat[iAntiPar,*] = -z_prime_hat[iAntiPar,*]
        k_dot_b = z_prime_hat[*,2]
    endif

    ;Reform the vectors
    k_hat       = reform(k_hat,       npts, nfreqs, 3)
    k_dot_b     = reform(k_dot_b,     npts, nfreqs)
    z_prime_hat = reform(z_prime_hat, npts, nfreqs, 3)

    ;Put the wave normal vector along the z-hat direction. Make "y" be in the plane
    ;perpendicular to k_hat and B_hat, then complete the system to make "x" such that
    ;"x" lies in the k-B plane.
    ;
    ;Loop over either time or frequency. Functions used below work for 3xN arrays,
    ;not 3xNxM.
    for i = 0, npts - 1 do begin
        R[i,*,*,2] = z_prime_hat[i,*,*]

        ;If k // B, then y_hat = k_hat x [0,0,1] = 0. Check for this by finding where the
        ;magnitude of y_hat = k_hat x [0,0,1] < 1e-6. In these case, use y_hat = [0,1,0].
        y_component = cross_product(reform(k_hat[i,*,*]), [0.0, 0.0, 1.0])
        iNegK = where(magnitude_vec(y_component) lt 1e-6 and k_hat[i,*,2] lt 0, nNegK)
        iPosK = where(magnitude_vec(y_component) lt 1e-6 and k_hat[i,*,2] gt 0, nPosK)
        if nNegK gt 0 then y_component[iNegK,*] = rebin([[0.0],[-1.0], [0.0]], nNegK, 3)
        if nPosK gt 0 then y_component[iPosK,*] = rebin([[0.0], [1.0], [0.0]], nPosK, 3)

        ;x- and y- components of the transformation matrix.
        R[i,*,*,1] = normalize(y_component)
        R[i,*,*,0] = normalize(cross_product(reform(R[i,*,*,1]), reform(R[i,*,*,2])))

        ;The wave-normal matrix (R) just created is the transformation matrix required
        ;to transform the current spectral density matrix (J') into the wave-normal
        ;system (J) via the rotation J = R J' R^T.

        ;Calculating the real and imaginary parts separately,
        ;NOTE: It might be pertinent to set the diagonal components of J_prime equal to
        ;      zero explicily (c.f. Means pg. 5555).
        J[i,*,*,*] = complex(rotate_matrix(reform(R[i,*,*,*]), reform(real_part(J_prime[i,*,*,*]))), $
                             rotate_matrix(reform(R[i,*,*,*]), reform(imaginary(J_prime[i,*,*,*]))))
    endfor
    undefine, R

;-----------------------------------------------------
;V. Average Over Frequency Bins \\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;Without smoothing over frequencies (i.e. NSMOOTH=0), the polarization at each
    ;frequency will be 1. Consider a monochromatic wave whose k-vector makes an
    ;angle of 40 degrees with respect to the mean magnetic field direction. 100%
    ;of the monochromatic wave will be polarized at this angle. That is to say,
    ;without mixing frequencies, the polarization is pure at all frequencies.
    
    ;The center of the averaging interval
    nfavg_half = (nfavg-1)/2

    ;step through all of the averaging intervals.
    IDLversion8 = MrCmpVersion('8.0')
    for k = 0, nfreqs - nfavg do begin
        ;Calculate index for the center, start, and end frequencies
        icenter_bin = k + nfavg_half
        istart      = icenter_bin - nfavg_half
        iend        = icenter_bin + nfavg_half

        ;Average of the frequency inteval (Js == J smoothed over frequency)
        ;   The DIMENSION keyword was added to MEAN in version 8.0.
        ;   - Without the /NaN flag, NaNs introduced in _Means when Power=0 will smear
        ;       to all frequencies.
        if IDLversion8 le 0 then begin
            Js[*,icenter_bin,*,*] = mean(J[*,istart:iend,*,*], DIMENSION=2)
            
            ;k dot B
            if keep_kdotb_angle then begin
                iNaN = where(total(finite(k_dot_b[*,istart:iend]), 2) eq 0, nNaN, COMPLEMENT=iGood, NCOMPLEMENT=nGood)
                if nGood gt 0 then k_dot_b[iGood,icenter_bin] = mean(k_dot_b[iGood,istart:iend], DIMENSION=2, /NAN)
                if nNaN  gt 0 then k_dot_b[iNaN,icenter_bin] = !values.f_nan
            endif
            
            ;k-hat
            if keep_khat then begin
                iNaN = where(total(finite(k_hat[*,istart:iend,*]), 2) eq 0, nNaN, COMPLEMENT=iGood, NCOMPLEMENT=nGood)
                if nGood gt 0 then k_hat[iGood,icenter_bin,*] = mean(k_hat[iGood,istart:iend,*], DIMENSION=2, /NAN)
                if nNaN  gt 0 then k_hat[iNaN,icenter_bin,*] = !values.f_nan
            endif
        endif else begin
            Js[*,icenter_bin,*,*] = cmapply('USER:MEAN', J[*,istart:iend,*,*], 2)
            if keep_kdotb_angle then k_dot_b[*,icenter_bin] = cmapply('USER:MEAN', k_dot_b[*,istart:iend], 2)
            if keep_khat        then k_hat[*,icenter_bin,*] = cmapply('USER:MEAN', k_hat[*,istart:iend,*], 2)
        endelse
    endfor
    undefine, J

    ;Truncate the end points that were not included in the average over frequencies.
    ;ipol may not contain all of the indices, so must search for them.
    temp_arr = lindgen(npts, nfreqs)
    temp_arr = temp_arr[*, nfavg_half:nfreqs-nfavg_half-1]
    void     = MrIsMember(temp_arr, iPol, these_iPol)
    iPol     = iPol[these_iPol]
    undefine, temp_arr
    
    ;Trim frequencies being kept
    ifrange = [nfavg_half, (nfreqs/2)-nfavg_half-1]
    if tf_keep_f then begin
        if nDims_f eq 2 $
            then frequencies = frequencies[*, ifrange[0]:ifrange[1]] $
            else frequencies = frequencies[ifrange[0]:ifrange[1]]
    endif

;-----------------------------------------------------
;VI. What to Keep? \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;Keep the spectral matrix?
    if keep_spectral_matrix then spectral_matrix = J_prime[*,ifrange[0]:ifrange[1],*,*]
    undefine, J_prime

    ;Keep k_hat?
    if keep_khat eq 0 $
        then undefine, k_hat $
        else k_hat = k_hat[*,ifrange[0]:ifrange[1],*]
    
    ;Keep the angle between k_hat and B?
    if keep_kdotb_angle then kdotb_angle = acos(k_dot_b[*,ifrange[0]:ifrange[1]])

    undefine, k_dot_b

;-----------------------------------------------------
;VI. Polarization Parameters \\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;Now we switch to the paper by Rankin and Kurtz (1970) to get the polarization
    ;parameters.
    
    ;Start with the "General Case" and note that "J" in Rankin and Kurts
    ;corresponds to the 2x2 x-y submatrix in our J.
    
    ;Recall that linearly polarized waves do not work for this analysis. Their
    ;spectral power lies only in the Jzz component, leaving Jxx, Jxy, Jyx, Jyy = 0.
    ;This causes floating point errors.

    ;Js must be reformed to a [3,3,npts*nfreqs] array in order for IPOL and ILIN to index
    ;properly. They are 1D indieces into a 2D array.
    Js = reform(Js, npts*nfreqs, 3, 3)

    ;For a wave traveling along the z-axis with perturbations in the xy-plane,
    ;   Hx = A cos(theta) + i A sin(theta)
    ;   Hy = B cos(theta) + i B sin(theta)
    ;
    ;In this wave normal frame, the spectral matrix is
    ;        | HxHx*  HxHy*  0 |
    ;   Js = | HyHx*  HyHy*  0 |
    ;        |   0      0    0 |
    ;
    ;Not that the diagonal elements are real
    ;   HxHx* = A^2
    ;   HyHy* = B^2
    ;
    ;Because of this, we set the imaginary component explicitly to zero. Without doing so,
    ;floating point underflow errors occur in the calculation of det(Js).
    Js[*,0,0] = complex(real_part(Js[*,0,0]))
    Js[*,1,1] = complex(real_part(Js[*,1,1]))

    ;A) Degree of Polarization
    ;   |J| = (Jxx * Jyy) - (Jxy * Jyx)
    ; => plrz = { 1 - [ (4*|J|) / (Jxx + Jyy)^2 ] }^(1/2)
    det_Js = real_part(Js[*,0,0]*Js[*,1,1] - Js[*,1,0]*Js[*,0,1])

    ;Save the polarization
    if nPol gt 0 then pzation[iPol] = sqrt( 1 - ((4*det_Js[iPol]) / real_part(Js[iPol,0,0] + Js[iPol,1,1])^2) )
    if nLin gt 0 then pzation[iLin] = !values.f_nan
    pzation = reform(pzation, npts, nfreqs)
    pzation = pzation[*, ifrange[0]:ifrange[1]]

    ;B) Coherency
    if keep_coherency then begin
        ;C = |Jxy| / sqrt( Jxx*Jyy )
        ;  = sqrt( Jxy*Jxy / (Jxx*Jyy) )
        if nPol gt 0 then coherency[ipol] = sqrt( real_part(Js[iPol,0,1]*Js[iPol,1,0]) / $
                                                  real_part(Js[iPol,0,0]*Js[iPol,1,1]) )
        if nLin gt 0 then coherency[iLin] = !values.f_nan
        coherency = reform(coherency, npts, nfreqs)
        coherency = coherency[*, ifrange[0]:ifrange[1]]
    endif
    
    ;C) Angle of Polarization
    ;       This is the angle between the x-axis of frame R and the major axis of the
    ;       polarization ellipse. It is NOT the angle between k and B.
    if keep_angle then begin
        ;tan(2*Theta') = 2*Re[Jxx] / (Jxx - Jyy)
        ; => Theta' = 0.5 * atan( 2*Re[Jxx] / (Jxx - Jyy) )
        if nPol gt 0 then begin
            tan2Theta = 2*real_part(Js[iPol,0,0]) / $
                        real_part(Js[iPol,0,0] - Js[iPol,1,1])
            polarization_angle[iPol] = 0.5 * atan(tan2Theta)
        endif

        if nLin gt 0 then polarization_angle[iLin] = !values.f_nan
        polarization_angle = reform(polarization_angle, npts, nfreqs)
        polarization_angle = polarization_angle[*, ifrange[0]:ifrange[1]]
    endif
    
    ;D) Ellipticity
    ;       +1 is left-hand polarized
    ;       -1 is right-hand polarized
    if keep_ellipticity then begin
        ;e = tan(B)
        ;sin(2B) = 2*Im[Jxy] / sqrt( (Jxx + Jyy)^2 - 4*|J| )
        ;  =>   e = tan(0.5 * asin[sin(2B)])
        ;Note that sin(2B) < 0 for clockwise rotation of the vector.
        if nPol gt 0 then begin
            sin2B = 2.0*imaginary(Js[iPol,1,0]) / $
                    sqrt( real_part(Js[iPol,0,0] + Js[iPol,1,1])^2 - 4.0*det_Js[iPol] )
            
            ;Occasionally, numerical error produces |sin2B| > 1 by less than 1e-7.
            ;Check and set them explicitly to +/- 1. Otherwise, produces error:
            ;   % Program caused arithmetic error: Floating illegal operand
            iGT1 = where(abs(sin2B) gt 1, nGT1)
            if nGT1 gt 0 then sin2B[iGT1] = -1.0 > sin2B[iGT1] < 1.0

            ;Compute ellipticity
            ellipticity[iPol] = tan(0.5 * asin(sin2B))
        endif
        if nLin gt 0 then ellipticity[iLin] = !values.f_nan
        ellipticity = reform(ellipticity, npts, nfreqs)
        ellipticity = ellipticity[*, ifrange[0]:ifrange[1]]
    endif

;-----------------------------------------------------
;VII. Other Useful Parameters \\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

    ;Intensity in the Wave Normal Frame
    if keep_intensity then begin
        ;I = Jxx + Jyy
        ;   Because the diagonal terms are purely real (within ~1e-8), I explicitly take
        ;   the real part to prevent INTENSITY from being converted to a complex array.
        intensity = real_part(reform(Js[*,0,0] + Js[*,1,1], npts, nfreqs))
        intensity = intensity[*, ifrange[0]:ifrange[1]]
    endif
    
    ;Power Spectral Matrix in the Wave Normal Frame.
    if keep_wave_normal then begin
;        wave_normal_matrix = reform(Js[0:1,0:1,*], 2, 2, npts, nfreqs)
        wave_normal_matrix = reform(Js, npts, nfreqs, 3, 3)
        wave_normal_matrix = wave_normal_matrix[*, ifrange[0]:ifrange[1], *, *]
    endif

;-----------------------------------------------------
;VIII. Return the Polarization \\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    return, pzation
end


                
;-----------------------------------------------------
; Main-level example program: IDL> .r MrPolarization \
;-----------------------------------------------------
;magfile    = '/Users/argall/Documents/Work/Data/RBSP/Emfisis/A/2013_gse/01/rbsp-a_magnetometer_hires-gse_emfisis-L3_20130130_v1.3.2.cdf'
;data       = MrCDF_Read(magfile, 'Mag')
acefile    = '/Users/argall/Documents/IDL/ace/test-data/ACE_MAG_LV2_RTN_HIRES_1997-246_V2.DAT'
;data       = ace_read_mag_asc(acefile, t_ssm, BMAG=Bmag, STIME=0.0, ETIME=86400.0)
nfft       = 4096
;dt         = 1.0 / 64.0
dt         = 0.333
dimension  = 2
nshift     = nfft / 2
fillval    = -999.9
interp_pct = 10.0
fmin       = df_fft(nfft, dt)
fmax       = 7.0
nfas       = 512
ndetrend   = nfas
ylog       = 1
window     = 1

iZero = where(Bmag eq 0, nZero)
if nZero gt 0 then data[*,iZero] = fillval
if nZero gt 0 then Bmag[*,iZero] = fillval

;Calculate the polarization
pzation   = MrPolarization(data, nfft, dt, nshift, $
                           FILLVAL            = fillval, $
                           FMIN               = fmin, $
                           FMAX               = fmax, $
                           FREQUENCIES        = f, $
                           TIME               = t, $
                           T0                 = t_ssm[0], $
                           DIMENSION          = dimension, $
                           NFAS               = nFAS, $
                           NDETREND           = nDetrend, $
                           /VERBOSE, $
                           WINDOW             = window, $
                           ELLIPTICITY        = ellipticity, $
                           INTENSITY          = intensity, $
                           INTERP_PCT         = interp_pct, $
                           POLARIZATION_ANGLE = pz_angle, $
                           COHERENCY          = coherency)

;Plot
win = MrWindow(OXMARGIN=[10,12], YGAP=0.5, XSIZE=550, YSIZE=550, REFRESH=0)
pal = MrCreateCT(/RWB, /REVERSE)

;Create a title
date  = stregex(acefile, '_([12][90][0-9]{2})', /SUBEXP, /EXTRACT)
doy   = stregex(acefile, '-([0-3][0-9][0-9])', /SUBEXP, /EXTRACT)
title = string(FORMAT='(%"ACE %s-%s")', date[1], doy[1])

;Time series
data   = replace_fillval(data, -999.9)
Bmag   = replace_fillval(Bmag, -999.9)
b_data = [transpose(temporary(Bmag)), (temporary(data))[1,*]]
Bplot  = MrPlot(temporary(t_ssm), temporary(b_data), $
                /CURRENT, $
                DIMENSION   = 2, $
                COLOR       = ['black', 'blue'], $
                NAME        = 'B', $
                TITLE       = title, $
                XRANGE      = [0, 86400.0], $
                XTICKV      = [0, 6, 12, 18, 24]*3600D, $
                XTICKFORMAT = '(a1)', $
                XTICKS      = 4, $
                YTITLE      = 'B (nT)')
                
!Null = MrLegend(ALIGNMENT     = 'NW', $
                 /RELATIVE, $
                 LABEL         = ['|B|', 'B$\downR$'], $
                 NAME          = 'B Legend', $
                 POSITION      = [1.05, 1.0], $
                 SAMPLE_COLOR  = ['Black', 'Blue'], $
                 SAMPLE_WIDTH  = 3.0, $
                 TARGET        = Bplot, $
                 TEXT_COLOR    = ['Black', 'Blue'])


;Intensity
intIm = MrImage(MrLog(temporary(intensity)), t, f, /CURRENT, $
                /AXES, /NAN, $
                CTINDEX=13, $
                MISSING_COLOR = 'Antique White', $
                NAME='Intensity', $
                XRANGE      = [0, 86400.0], $
                XTICKV=[0, 6, 12, 18, 24]*3600D, $
                XTICKFORMAT='(a1)', $
                XTICKS=4, $
                YLOG=ylog, $
                YTITLE='f!C(Hz)')

!Null = MrColorbar(/CURRENT, $
                   TARGET=intIm, $
                   NAME='CB: Intensity', $
                   TITLE='Intensity', $
                   WIDTH=1)

;Ellipticity
ellIm = MrImage(temporary(ellipticity), t, f, /CURRENT, $
                /AXES, /NAN, $
                PALETTE=pal, $
                MISSING_COLOR = 'Antique White', $
                NAME='Ellipticity', $
                RANGE=[-1,1], $
                XRANGE=[0, 86400.0], $
                XTICKV=[0, 6, 12, 18, 24]*3600D, $
                XTICKFORMAT='(a1)', $
                XTICKS=4, $
                YLOG=ylog, $
                YTITLE='f!C(Hz)')

!Null = MrColorbar(/CURRENT, $
                   TARGET=ellIm, $
                   NAME='CB: Ellipticity', $
                   TITLE='Ellipticity', $
                   WIDTH=1)

;% Polarization
polWin = MrImage(temporary(pzation), t, f, /CURRENT, $
                 /AXES, /NAN, $
                 CTINDEX=0, $
                 MISSING_COLOR = 'Antique White', $
                 NAME='Polarization', $
                 RANGE=[0,1], $
                 XRANGE=[0, 86400.0], $
                 XTICKV=[0, 6, 12, 18, 24]*3600D, $
                 XTICKFORMAT='(a1)', $
                 XTICKS=4, $
                 YLOG=ylog, $
                 YTITLE='f!C(Hz)')

!Null = MrColorbar(/CURRENT, $
                   TARGET=polWin, $
                   NAME='CB: Polarization', $
                   TITLE='Polarization', $
                   WIDTH=1)

;Polarization Angle
angWin = MrImage(acos(temporary(pz_angle))*!RaDeg, t, f, /CURRENT, $
                 /AXES, /NAN, $
                 CTINDEX=0, $
                 MISSING_COLOR = 'Antique White', $
                 NAME='Angle', $
                 RANGE=[0,180], $
                 XRANGE=[0, 86400.0], $
                 XTICKV=[0, 6, 12, 18, 24]*3600D, $
                 XTICKFORMAT='(a1)', $
                 XTICKS=4, $
                 YLOG=ylog, $
                 YTITLE='f!C(Hz)')

!Null = MrColorbar(/CURRENT, $
                   TARGET=angWin, $
                   NAME='CB: Angle', $
                   TITLE='Angle', $
                   YTICKINTERVAL=60, $
                   WIDTH=1)

;Coherency
angWin = MrImage(temporary(coherency), temporary(t), temporary(f), /CURRENT, $
                 /AXES, /NAN, $
                 CTINDEX=0, $
                 MISSING_COLOR = 'Antique White', $
                 NAME='Coherency', $
                 RANGE=[0,1], $
                 XRANGE=[0, 86400.0], $
                 XTICKV=[0, 6, 12, 18, 24]*3600D, $
                 XTICKFORMAT='time_labels', $
                 XTICKS=4, $
                 YLOG=ylog, $
                 YTITLE='f!C(Hz)')

!Null = MrColorbar(/CURRENT, $
                   TARGET=angWin, $
                   NAME='CB: Coherency', $
                   TITLE='Coherency', $
                   WIDTH=1)
                   
;Refresh the window
win -> Refresh
end