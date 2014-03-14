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
function MrPolarization_Means, J_prime, ipol, ilin, npol, nlin, $
K_VEC = k_vec
    compile_opt idl2, hidden
    on_error, 2

    ;allocate memory
    J_prime_dims = size(J_prime, /DIMENSIONS)
    npts = J_prime_dims[2]
    nfreqs = J_prime_dims[3]
    ab = fltarr(npts, nfreqs)
    k_hat = fltarr(3, npts*nfreqs)
    if arg_present(k_vec) then k_vec = fltarr(3, npts*nfreqs)

    ;The wave normal direction can now be determined by examining the imaginary part of
    ;the spectral density matrix (Means pg. 5554, Bakarat eq 3.19).
    
    ;Using the imaginary components.
    ;a*b = Hxy^2 + Hzx^2 + Hyz^2
    ab = sqrt(imaginary(reform(J_prime[1,0,*,*]))^2 + $     ;Hxy^2
              imaginary(reform(J_prime[2,0,*,*]))^2 + $     ;Hxz^2
              imaginary(reform(J_prime[2,1,*,*]))^2)        ;Hyz^2

    ;The imaginary part of the power spectral matrix for linearly polarized waves
    ;is the 0-matrix. Thus, the analysis that follows cannot be undertaken. (Means
    ;pg. 5555-6). Treat them separately later.
    ilin  = where(ab eq 0, nlin, COMPLEMENT=ipol, NCOMPLEMENT=npol)
    
    ;ILIN and IPOL are 1D subscripts into a 2D vector. Reform J_prime so that subscript-
    ;rounding does not occur (e.g. a = findgen(10) ... print, a[[20]]).
    J_prime = reform(J_prime, 3, 3, npts*nfreqs)
    
    ;Treat the linearly polarized cases first.
    if nlin gt 0 then begin
        ;The power of the linearly polarized wave
        ;Tr[J'] = a^2 = Jxx + Jyy + Jzz   --   (J is purely real)
        a2 = real_part(reform(J_prime[0,0,ilin] + J_prime[1,1,ilin] + J_prime[2,2,ilin]))
        
        ;If there is no power at the frequency
        ino_power = where(a2 lt 1e-5, nno_power, COMPLEMENT=ipower, NCOMPLEMENT=npower)
        if nno_power gt 0 then begin
            ;There is no direction of propagation.
            k_hat[*,ilin[ino_power]] = replicate(!values.f_nan, 3, nno_power)
        endif
            
        ;Otherwise
        if npower gt 0 then begin
            ;Calculate the direction of the linearized wave
            Lx = sqrt(real_part(reform(J_prime[0,0,ilin[ipower]])) / a2[ipower])    ;(Jxx / a^2)^(1/2)
            Ly = real_part(reform(J_prime[1,0,ilin[ipower]])) / (a2[ipower] * Lx)   ;Jxy / (a^2 * Lx)
            Lz = real_part(reform(J_prime[2,0,ilin[ipower]])) / (a2[ipower] * Lx)   ;Jxz / (a^2 * Lx)
            
            ;Store the direction of propagation
            k_hat[*,ilin[ipower]] = transpose([[Lx], [Ly], [Lz]])
        endif
    endif

    ;Now treat polarized waves.
    if npol gt 0 then begin
        ;Return the k-vector?
        if arg_present(k_vec) then begin
            k_vec[2,ipol] =  imaginary(reform(J_prime[1,0,ipol]))
            k_vec[1,ipol] = -imaginary(reform(J_prime[2,0,ipol]))
            k_vec[0,ipol] =  imaginary(reform(J_prime[2,1,ipol]))
        endif
        
        ;Note that dividing by "ab" normalizes the components.
        k_hat[2,ipol] =  imaginary(reform(J_prime[1,0,ipol])) / ab[ipol]   ;kz =  Hxy / (a*b)
        k_hat[1,ipol] = -imaginary(reform(J_prime[2,0,ipol])) / ab[ipol]   ;ky = -Hxz / (a*b)
        k_hat[0,ipol] =  imaginary(reform(J_prime[2,1,ipol])) / ab[ipol]   ;kx =  Hyz / (a*b)
    endif

    ;This anaylsis has been done under the assumptions of a counter-clockwise,
    ;elliptically polarized plane wave. Thus, a clockwise polarized wave has k_hat < 0
    
    ;Reform the vectors back to their original shape
    J_prime = reform(J_prime, 3, 3, npts, nfreqs)

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
;       FREQUENCIES:        out, type=fltarr(NFFT)
;                           The frequency bins of the FFT
;       INTENSITY:          out, optional, type=NxM float
;                           Intensity of the wave in the wave-normal system.
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
FREQUENCIES = frequencies, $
INTENSITY = intensity, $
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
        void = cgErrorMsg()
        return, MrNull('ObjRef')
    endif

;-----------------------------------------------------
;Check Inputs \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;Create defaults.
    if n_elements(nfft) eq 0 then nfft = floor(n_elements(data) / 4)
    if n_elements(dt) eq 0 then dt = 1
    if n_elements(n_shift) eq 0 then n_shift = floor(nfft/2)
    if n_elements(center_time) eq 0 then center_time = 1
    if n_elements(nDetrend) eq 0 then nDetrend = 0
    if n_elements(nFAS) eq 0 then nFAS = 0
    if n_elements(nfavg) eq 0 then nfavg = 5
    if n_elements(method) eq 0 then method = 1
    
    ;Must be method 1 or 2
    if method lt 1 or method gt 2 then message, 'Invalid method. METHOD = {1 | 2}.'
    
    ;Make sure NFAVG is odd and >= 3
    if (nfavg mod 2) eq 0 or nfavg lt 3 then $
        message, 'NFAVG must be an odd integer <= 3.'
    
    ;Make sure nFA and nDetrend are equal, if both are non-zero
    if nFAS ne 0 and nDetrend ne 0 then nFAS = nDetrend
    
    ;Keep certain parameters?
    if arg_present(coherency)          then keep_coherency = 1       else keep_coherency = 0
    if arg_present(intensity)          then keep_intensity = 1       else keep_intensity = 0
    if arg_present(mean_field)         then keep_mean_field = 1      else keep_mean_field = 0
    if arg_present(ellipticity)        then keep_ellipticity = 1     else keep_ellipticity = 0
    if arg_present(time)               then keep_time = 1            else keep_time = 0
    if arg_present(spectral_matrix)    then keep_spectral_matrix = 1 else keep_spectral_matrix = 0
    if arg_present(wave_normal_matrix) then keep_wave_normal = 1     else keep_wave_normal = 0
    if arg_present(polarization_angle) then keep_angle = 1           else keep_angle = 0
    if arg_present(k_vec)              then keep_kvec = 1            else keep_kvec = 0
    if arg_present(k_hat)              then keep_khat = 1            else keep_khat = 0
    if arg_present(kdotb_angle)        then keep_kdotb_angle = 1     else keep_kdotb_angle = 0
  
;-----------------------------------------------------
;Detrend the Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

    if (nDetrend gt 0) or (nFAS gt 0) $
        then temp_data = MrDetrendRotate(data, nDetrend, nFAS, $
                                         MEAN_FIELD=mean_field, DIMENSION=dimension)$
        else temp_data = data

;-----------------------------------------------------
;I. Take the FFT \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    
    ;Compute the FFT of the data
    fft_data = MrFFT(temporary(temp_data), nfft, dt, nshift, $
                     DIMENSION=dimension, $
                     T0=t0, $
                     TIME=time, $
                     FREQUENCIES=frequencies, $
                    _STRICT_EXTRA=extra)

    ;Which frequency components will be kept?
    if_keep = where(frequencies gt 0)
    
    ;Keep the time?
    if arg_present(time) eq 0 $
        then undefine, time $
        else if (t0 ne 0.0) then time += t0
        
    ;Keep the actual frequencies?
    if arg_present(frequencies) eq 1 $
        then frequencies = frequencies[if_keep] $
        else undefine, frequencies

    data_size = size(fft_data, /DIMENSIONS)
    npts = data_size[0]
    nfreqs = data_size[1]
    ncomps = data_size[2]

;-----------------------------------------------------
;Allocate Memory \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    
    ;allocate the polarization parameters' arrays
    if keep_coherency       then coherency          = fltarr(npts*nfreqs)
    if keep_intensity       then intensity          = fltarr(npts,nfreqs)
    if keep_ellipticity     then ellipticity        = fltarr(npts*nfreqs)
    if keep_angle           then polarization_angle = fltarr(npts*nfreqs)
    if keep_kvec            then k_vec              = fltarr(3, npts*nfreqs)
    if keep_spectral_matrix then spectral_matrix    = complexarr(3, 3, npts, nfreqs)
    if keep_wave_normal     then wave_normal_matrix = complexarr(2, 2, npts, nfreqs)
    if keep_kdotb_angle     then kdotb_angle        = fltarr(nfreqs, npts)
    pzation = fltarr(npts*nfreqs)
    
    ;Variables
    J_prime = complexarr(3, 3, npts, nfreqs)
    J       = complexarr(3, 3, npts, nfreqs)
    Js      = complexarr(3, 3, npts, nfreqs)
    k_hat   = fltarr(3, npts, nfreqs)
    k_dot_b = fltarr(npts, nfreqs)
    R       = fltarr(3, 3, npts, nfreqs)

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

    ;Using Means' notation, calculate the spectral density matrix. The "prime"
    ;indicates that the spectral density matrix is NOT in the principle axis system.
    ;Dividing by the length of the time interval converts from Energy to Power.
    J_prime[0,0,*,*] = 2.0 * fft_data[*,*,0] * conj(fft_data[*,*,0])      ;Hxx
    J_prime[1,0,*,*] = 2.0 * fft_data[*,*,0] * conj(fft_data[*,*,1])      ;Hxy
    J_prime[2,0,*,*] = 2.0 * fft_data[*,*,0] * conj(fft_data[*,*,2])      ;Hxz
    J_prime[0,1,*,*] = 2.0 * fft_data[*,*,1] * conj(fft_data[*,*,0])      ;Hyx
    J_prime[1,1,*,*] = 2.0 * fft_data[*,*,1] * conj(fft_data[*,*,1])      ;Hyy
    J_prime[2,1,*,*] = 2.0 * fft_data[*,*,1] * conj(fft_data[*,*,2])      ;Hyz
    J_prime[0,2,*,*] = 2.0 * fft_data[*,*,2] * conj(fft_data[*,*,0])      ;Hzx
    J_prime[1,2,*,*] = 2.0 * fft_data[*,*,2] * conj(fft_data[*,*,1])      ;Hzy
    J_prime[2,2,*,*] = 2.0 * fft_data[*,*,2] * conj(fft_data[*,*,2])      ;Hzz

    ;This is the spectral density matrix [covariance matrix in the frequency domain]
    ;(c.f. "Technique and Theory" and eq 1 in Means or eq 3.18 in Bakarat).

;-----------------------------------------------------
;III. Wave Normal Direction \\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

    ;Means?
    if method eq 1 then begin
        ;Keep the non-normalized wave vector?
        if keep_kvec then begin
            k_hat = MrPolarization_Means(J_prime, ipol, ilin, npol, nlin, K_VEC=k_vec)
            k_vec = reform(k_vec, 3, npts, nfreqs)
            k_vec = k_vec[*,*,if_keep]
            
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
    ;down B_hat and left-handed if it rotates clockwise. 
    
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
    k_dot_b = reform(k_hat[2,*])
    
    ;Make sure that the new z-had direction is always parallel to B
    z_prime_hat = k_hat
    iAntiPar = where(k_dot_b lt 0, nAntiPar)
    if nAntiPar gt 0 then begin
        z_prime_hat[*,iAntiPar] = -z_prime_hat[*,iAntiPar]
        k_dot_b = reform(z_prime_hat[2,*])
    endif

    ;Reform the vectors
    k_hat = reform(k_hat, 3, npts, nfreqs)
    k_dot_b = reform(k_dot_b, npts, nfreqs)
    z_prime_hat = reform(z_prime_hat, 3, npts, nfreqs)

    ;Put the wave normal vector along the z-hat direction. Make "y" be in the plane
    ;perpendicular to k_hat and B_hat, then complete the system to make "x" such that
    ;"x" lies in the k-B plane.
    for i = 0, npts - 1 do begin
        R[*,2,i,*] = z_prime_hat[*,i,*]

        ;If k // B, then y_hat = k_hat x [0,0,1] = 0. Check for this by finding where the
        ;magnitude of y_hat = k_hat x [0,0,1] < 1e-6. In these case, use y_hat = [0,1,0].
        y_component = cross_product(reform(k_hat[*,i,*]), [0.0, 0.0, 1.0])
        iNegK = where(magnitude_vec(y_component) lt 1e-6 and k_hat[2,i,*] lt 0, nNegK)
        iPosK = where(magnitude_vec(y_component) lt 1e-6 and k_hat[2,i,*] gt 0, nPosK)
        if nNegK gt 0 then y_component[*,iNegK] = rebin([0.0,-1.0, 0.0], 3, nNegK)
        if nPosK gt 0 then y_component[*,iPosK] = rebin([0.0, 1.0, 0.0], 3, nPosK)

        R[*,1,i,*] = normalize(y_component)
        R[*,0,i,*] = normalize(cross_product(reform(R[*,1,i,*]), reform(R[*,2,i,*])))

        ;The wave-normal matrix (R) just created is the transformation matrix required
        ;to transform the current spectral density matrix (J') into the wave-normal
        ;system (J) via the rotation J = R J' R^T.

        ;Calculating the real and imaginary parts separately,
        ;NOTE: It might be pertinent to set the diagonal components of J_prime equal to
        ;      zero explicily (c.f. Means pg. 5555).
        J[*,*,i,*] = complex(rotate_matrix(reform(R[*,*,i,*]), reform(real_part(J_prime[*,*,i,*]))), $
                             rotate_matrix(reform(R[*,*,i,*]), reform(imaginary(J_prime[*,*,i,*]))))
    endfor
    undefine, R

    ;Keep the spectral matrix?
    if keep_spectral_matrix then spectral_matrix = J_prime[*,*,*,if_keep]
    undefine, J_prime
        
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
    for k = 0, nfreqs - nfavg do begin
        ;Calculate index for the center, start, and end frequencies
        icenter_bin = k + nfavg_half
        istart = icenter_bin - nfavg_half
        iend = icenter_bin + nfavg_half

        ;Average of the frequency inteval (Js == J smoothed over frequency)
        ;   The DIMENSION keyword was added to MEAN in version 8.0.
        if MrCmpVersion('8.0') le 0 then begin
            Js[*,*,*,icenter_bin] = mean(J[*,*,*,istart:iend], DIMENSION=4)
            if keep_kdotb_angle then k_dot_b[*,icenter_bin] = mean(k_dot_b[*,istart:iend], DIMENSION=2)
            if keep_khat then k_hat[*,*,icenter_bin] = mean(k_hat[*,*,istart:iend], DIMENSION=3)
        endif else begin
            Js[*,*,*,icenter_bin] = cmapply('USER:MEAN', J[*,*,*,istart:iend], 4)
            if keep_kdotb_angle then k_dot_b[*,icenter_bin] = cmapply('USER:MEAN', k_dot_b[*,istart:iend], 2)
            if keep_khat then k_hat[*,*,icenter_bin] = cmapply('USER:MEAN', k_hat[*,*,istart:iend], 3)
        endelse
    endfor
    undefine, J
    
    ;Keep k_hat?
    if keep_khat eq 0 then undefine, k_hat
    
    ;Keep the angle between k_hat and B?
    if keep_kdotb_angle then kdotb_angle = acos(k_dot_b[*,if_keep])
    undefine, k_dot_b

    ;Truncate the end points that were not included in the average over frequencies.
    ;ipol may not contain all of the indices, so must search for them.
    temp_arr = lindgen(npts, nfreqs)
    temp_arr = temp_arr[*,nfavg_half:nfreqs-nfavg_half-1]
    void = isMember(temp_arr, ipol, these_ipol)
    ipol = ipol[these_ipol]
    undefine, temp_arr

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
    Js = reform(Js, 3, 3, npts*nfreqs)

    ;A) Degree of Polarization
    ;   |J| = (Jxx * Jyy) - (Jxy * Jyx)
    ; => plrz = { 1 - [ (4*|J|) / (Jxx + Jyy)^2 ] }^(1/2)
    det_Js = real_part(reform(Js[0,0,*]*Js[1,1,*] - Js[1,0,*]*Js[0,1,*]))
    
    ;Save the polarization
    if npol gt 0 then pzation[ipol] = sqrt( 1 - ((4*det_Js[ipol]) / real_part(reform(Js[0,0,ipol] + Js[1,1,ipol]))^2) )
    if nlin gt 0 then pzation[ilin] = !values.f_nan
    pzation = reform(pzation, npts, nfreqs)
    pzation = pzation[*, if_keep]

    ;B) Coherency
    if keep_coherency then begin
        ;C = |Jxy| / sqrt( Jxx*Jyy )
        ;  = sqrt( Jxy*Jxy / (Jxx*Jyy) )
        if npol gt 0 then coherency[ipol] = reform( sqrt( real_part(Js[0,1,ipol]*Js[1,0,ipol]) / $
                                                          real_part(Js[0,0,ipol]*Js[1,1,ipol]) ) )
        if nlin gt 0 then coherency[ilin] = !values.f_nan
        coherency = reform(coherency, npts, nfreqs)
        coherency = coherency[*, if_keep]
    endif
    
    ;C) Angle of Polarization
    ;       This is the angle between the x-axis of frame R and the major axis of the
    ;       polarization ellipse. It is NOT the angle between k and B.
    if keep_angle then begin
        ;tan(2*Theta') = 2*Re[Jxx] / (Jxx - Jyy)
        ; => Theta' = 0.5 * atan( 2*Re[Jxx] / (Jxx - Jyy) )
        if npol gt 0 then begin
            tan2Theta = 2*reform( real_part(Js[0,0,ipol]) / $
                                  real_part(Js[0,0,ipol] - Js[1,1,ipol]) )
            polarization_angle[ipol] = 0.5 * atan(tan2Theta)
        endif
        if nlin gt 0 then polarization_angle[ilin] = !values.f_nan
        polarization_angle = reform(polarization_angle, npts, nfreqs)
        polarization_angle = polarization_angle[*, if_keep]
    endif
    
    ;D) Ellipticity
    ;       +1 is left-hand polarized
    ;       -1 is right-hand polarized
    if keep_ellipticity then begin
        ;e = tan(B)
        ;sin(2B) = 2*Im[Jxy] / sqrt( (Jxx + Jyy)^2 - 4*|J| )
        ;  =>   e = tan(0.5 * asin[sin(2B)])
        ;Note that sin(2B) < 0 for clockwise rotation of the vector.
        if npol gt 0 then begin
            sin2B = 2.0*imaginary(reform(Js[1,0,ipol])) / $
                    sqrt( real_part(reform(Js[0,0,ipol] + Js[1,1,ipol]))^2 - 4.0*det_Js[ipol] )
            ellipticity[ipol] = tan(0.5 * asin(sin2B))
        endif
        if nlin gt 0 then ellipticity[ilin] = !values.f_nan
        ellipticity = reform(ellipticity, npts, nfreqs)
        ellipticity = ellipticity[*, if_keep]
    endif
                
;-----------------------------------------------------
;VII. Other Useful Parameters \\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

    ;Intensity in the Wave Normal Frame
    if keep_intensity then begin
        ;I = Jxx + Jyy
        ;   Because the diagonal terms are purely real (within ~1e-8), I explicitly take
        ;   the real part to prevent INTENSITY from being converted to a complex array.
        intensity = real_part(reform(Js[0,0,*] + Js[1,1,*], npts, nfreqs))
        intensity = intensity[*, if_keep]
    endif
    
    ;Power Spectral Matrix in the Wave Normal Frame.
    if keep_wave_normal then begin
;        wave_normal_matrix = reform(Js[0:1,0:1,*], 2, 2, npts, nfreqs)
        wave_normal_matrix = reform(Js, 3, 3, npts, nfreqs)
        wave_normal_matrix = wave_normal_matrix[*, *, *, if_keep]
    endif
                
;-----------------------------------------------------
;VIII. Return the Polarization \\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    return, pzation
end