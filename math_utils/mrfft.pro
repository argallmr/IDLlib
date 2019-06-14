; docformat = 'rst'
;
; NAME:
;
;       MrFFT
;
; PURPOSE:
;+
;   The purpose of this program is to serve as a wrapper for IDL's FFT routine::
;       `DATA` is >= 3D::
;           IDL's FFT routine is called immediately and the result is returned.
;       `DATA` is 2D and `DIMENSION`=0::
;           A 2D tapering filter can be applied to an image.
;           - WINDOW
;           - NWIN1
;           - NWIN2
;           - ALPHA
;       Otherwise::
;           Wrapper algorithms are used.
;
;   The last case is intended to apply to time series vectors or arrays of time series
;   vectors. For example, the velocity of a particle as a 1D vector or a 3D magnetic field
;   represented as an array of 3 vectors: [Bx, By, Bz]. 
;
;   In the last case, the following capabilities are available::
;       - FFT is taken along the 1st dimension by default (TRANSPOSE if DIMENSION=2)
;       - Take the FFT of an array in sections
;       - Specify the number of points per FFT
;       - Shift the FFT window by a given amount
;       - Apply a tapering window
;       - Return time stamps of each FFT bin
;
;   Notes:
;       IDL ignores empty dimensions when the "*" operator is used, so indexing ARRAY[i,*,*]
;       is the same for 2D and 3D arrays. Furthermore, trailing shallow dimensions are
;       automatically reformed, so ARRAY[*,*,i] is the same as REFORM(ARRAY[*,*,i]). For this
;       reason, the output will be kept as [time, frequency, component]
;
;   References::
;       Percival, D. and Walden, A., Spectral Analysis for Physical Applications: Multitaper
;           and Conventional Univariate Techniques, Cambridge University Press, 1993.
;
; :Categories:
;       Math Utility
;
; :Params:
;
;       DATA:               in, required, type=fltarr
;                           The data for which a spectrogram is desired.
;       NFFT:               in, optional, type=int, default=N_ELEMENTS(DATA)
;                           The number of points to use per FFT
;       DT:                 in, optional, type=float. default=1
;                           The time between data samples. If not present, unit spacing
;                               is assumed.
;       NSHIFT:             in, optional, type=int. default=0
;                           The number of points to shift ahead after each FFT.
;
; :Keywords:
;
;       ALPHA:              in, optional, type=float, default=0.5
;                           If `WINDOW` is set, then this indicates the width of the
;                               filtering window (0.5-1.0) used in creating the window.
;                               If ALPHA=0.5, the result is a "Hanning" window, if ALPHA=1.0,
;                               the result is a "Hamming" window.
;       CENTER:             in, optional, type=Boolean, default=0
;                           Perform a centered Fourier transform. In the forward direction,
;                               the zero frequency is shifted to the center of the array.
;                               In the reverse (inverse) direction, the input is assumed
;                               to be a centered FFT.
;       DIMENSION:          in, optional, type=int, default=longest dimension of `DATA`
;                           The dimension over which to take the FFT. As an example, say
;                               ARRAY is a [3,10] element array. MrFFT(ARRAY, DIMENSION=2),
;                               is the same as
;                               [MrFFT(Array[0,*]), MrFFT(Array[1,*]), MrFFT(Array[2,*])].
;       DOUBLE:             in, optional, type=boolean, default=0
;                           Force computation to be done in double precision.
;       FILLVAL:            in, optional, type=same as `DATA`
;                           A value that represents bad points within `DATA`. They will
;                               be converted to NaNs before the FFT is performed, unless
;                               the `INTERP_PCT` keyword is used.
;       FMIN:               in, optional, type=float, default=0.0
;                           The minimum positive frequency to be kept. If LOGRANGE is set,
;                               this is the minimum power of 10 (not the DC component).
;       FMAX:               in, optional, type=float, default=FNYQUIST.
;                           The maximum positive frequency to be kept. If LOGRANGE is set,
;                               this is alog10(FNYQUIST).
;       FREQUENCIES:        out, type=fltarr(NFFT)
;                           The frequency bins of the FFT
;       INTERP_PCT:         in, optional, type=float, default=0.0
;                           The maximum percentage of `FILLVAL` allowed in an FFT of size
;                               `NPTS`. Below this percent, instances of the fill value
;                               will be interpolated over. Above this percent, fill values
;                               are converted to NaNs.
;       LINRANGE:           in, optional, type=Int, default=0
;                           Indicate that the frequency range it to be reduced to
;                               LINRANGE number of linearly spaced frequencies between
;                               FMIN and FMAX. See "Limitations" in comment header.
;       LOGRANGE:           in, optional, type=Int, default=0
;                           Indicate that the frequency range it to be reduced to
;                               LOGRANGE number of logarithmically spaced frequencies
;                               between FMIN and FMAX. See "Limitations" in comment header.
;       T0:                 in, optional, type=float, default=0.0
;                           Time offset in seconds at which `TIME` begins.
;       TIME:               out, type=dblarr
;                           The time associated with each Power Spectral Density slice.
;                               Where each time tag falls within the FFT interval is
;                               determined by the `TCENTER` keyword.
;       TCENTER:            in, optional, type=Boolean, default=1
;                           Indicate that the times returned in `TIME` are centered within
;                               their respective FFT bin. A value of 0 will cause the
;                               times to correspond with the beginning of the FFT packet.
;       VERBOSE:            in, optional, type=Boolean, default=0
;                           Print information about the FFT parameters to the command window.
;       VVERBOSE:           in, optional, type=Boolean, default=0
;                           In addition to `VERBOSE`, print, percent completion.
;       WINDOW:             in. optional, type=Boolean, default=0
;                           Multiply the time series by a filtering window. This keyword
;                               is only available if `DATA` has <= 2 dimensions or if
;                               `DIMENSION` NE 0 (because I do not know how to make a
;                               window that is > 2D).
;                           
; :Returns:
;
;       fft_data:           The FFT of `DATA` with dimensions organized as 
;                               [time, frequency, component]
;
; :Uses:
;   Uses the following external programs::
;       nfft_intervals.pro
;       fft_freqs.pro
;       logspace.pro
;       linspace.pro
;       MrInterpol.pro
;       MRIsA.pro
;       MrSigGen.pro (for the example)
;       MrPlot.pro (for the example)
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 348
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@unh.edu
;
; :Copyright:
;       Matthew Argall 2013
;
; :History::
;   Modification History::
;       04/11/2013  -   Written by Matthew Argall
;       04/03/2013  -   Simplified and cleaned stuff up. LOGRANGE and LINRANGE now
;                           working. - MRA
;       05/25/2013  -   Was counting 0 twice when determining the frequencies to keep.
;                           Fixed. - MRA
;       07/05/2013  -   TCENTER keyword was being used as center_time. Negative values
;                           of DT were causing a not-so-obvious error. Fixed. - MRA
;       08/12/2013  -   Changed _EXTRA to _REF_EXTRA and call FFT with _STRICT_EXTRA. - MRA
;       09/20/2013  -   Removed support for non-time-series data, as I have never used it
;                           and did not know if it worked anyway. DIMENSION now defaults
;                           to the longest dimension of `DATA`. Removed the _REF_EXTRA
;                           keyword, as all of the function keywords to FFT are already
;                           in the list of keywords. - MRA
;       09/23/2013  -   Error when DIMENSION is a 1-element array. Fixed. - MRA
;       10/04/2013  -   Added the T0 keyword. - MRA
;       2015/01/25  -   Added the INTERP_PCT and FILLVAL keywords. Removed the INVERSE
;                           keyword. - MRA
;-
function MrFFT, data, nfft, dt, nshift, $
ALPHA = alpha, $
CENTER = center, $
DIMENSION = dimension, $
DOUBLE = double, $
FILLVAL = fillval, $
FMIN = fmin, $
FMAX = fmax, $
FREQUENCIES = frequencies, $
INTERP_PCT = interp_pct, $
LOGRANGE = logrange, $
LINRANGE = linrange, $
T0 = t0, $
TIME = time, $
TCENTER = tcenter, $
VERBOSE = verbose, $
VVERBOSE = vverbose, $
WINDOW = window
    compile_opt idl2
    on_error, 2

;-----------------------------------------------------
; Check Inputs \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

    ;Accept only 1D or 2D data.
    dims  = size(data, /DIMENSIONS)
    nDims = size(data, /N_DIMENSIONS)
    type  = size(data, /TNAME)
    void  = max(dims, iMaxDim)
    if nDims gt 2 then message, 'Only 1D or 2D time series data is allowed.'

    ;FFT over longest dimension
    if n_elements(dimension) eq 0 then dimension = iMaxDim + 1
    npts = dims[dimension-1]

    ;Create defaults
    tf_center   = keyword_set(center)
    tf_vverbose = keyword_set(vverbose)
    tf_verbose  = keyword_set(verbose) || tf_vverbose
    tf_fillval  = n_elements(fillval) gt 0
    if n_elements(interp_pct) eq 0 then interp_pct = 100.0
    if n_elements(nfft)       eq 0 then nfft       = npts
    if n_elements(dt)         eq 0 then dt         = 1.0
    if n_elements(nshift)     eq 0 then nshift     = floor(nfft/2)
    if n_elements(tcenter)    eq 0 then tcenter    = 1

    ;Make sure dt >= 0
    if dt le 0 then begin
        message, /INFORMATIONAL, 'dt must be > 0. Setting dt = 1.0.'
        dt = 1.0
    endif

    ;Make sure at least one FFT can be done.
    if nfft gt npts then begin
        message, string(FORMAT='(%"NFFT (%i) is longer than the data interval (%i). ' + $
                                  'Setting NFFT=%i.")', nfft, npts, npts), /INFORMATIONAL
        nfft = npts
    endif
    
    ;Keep array type the same.
    double = n_elements(double) eq 0 ? (type eq 'DOUBLE') : keyword_set(double)
    if double then out_type = 9 else out_type = 6
    
    ;Time stamp at the center of the packet or at the beginning?
    if n_elements(t0) eq 0  then t0        = 0.0
    if arg_present(time)    then keep_time = 1   else keep_time = 0
    if keyword_set(tcenter) then ct        = 0.5 else ct        = 0.0
    
    ;Check how to window the data. Default to a "Hanning" window.
    window = keyword_set(window)
    if window then begin
        if n_elements(nwin1) eq 0 then nwin1 = nfft
        if n_elements(alpha) eq 0 then alpha = 0.5
    endif

;-----------------------------------------------------
; FFT Parameters \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;get the sampling frequency at which the data was recorded, the frequency spacing,
    ;the number of FFT intervals and an array of the frequency bins.
    ;sampling_rate = 1.0 / dt
    df = 1 / (nfft * dt)
    n_intervals = nfft_intervals(npts, nfft, nshift)
    frequencies = fft_freqs(nfft, dt, FNYQUIST=fnyquist, INYQUIST=inyquist)

    ;Set the default FMIN
    if n_elements(fmin) eq 0 then begin
        if n_elements(logrange) eq 0 $
            then fmin = frequencies[0] $
            else fmin = alog10(frequencies[1])
    endif

    ;Set the default FMAX
    if n_elements(fmax) eq 0 then begin
        if n_elements(logrange) eq 0 $
            then fmax = frequencies[iNyquist] $
            else fmax = alog10(frequencies[iNyquist])
    endif

;-----------------------------------------------------
; Print FFT Parameters \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if nDims eq 1 $
        then dims = [dims, 1] $
        else dims = dims

    if tf_verbose then begin
        print, FORMAT='(%"data size     = [%i,%i]")', dims
        print, FORMAT='(%"dimension     = %i")',      dimension
        print, FORMAT='(%"sample period = %f s")',    dt
        print, FORMAT='(%"sample rate   = %f Hz")',   1.0 / dt
        print, FORMAT='(%"sample intrvl = %f s")',    nfft*dt
        print, FORMAT='(%"df            = %f Hz")',   df
        print, FORMAT='(%"f_min         = %f Hz")',   fmin
        print, FORMAT='(%"f_max         = %f Hz")',   fmax
        print, FORMAT='(%"NFFT          = %i")',      nfft
        print, FORMAT='(%"NSHIFT        = %i")',      nshift
        print, FORMAT='(%"t_shift       = %i s")',    nshift*dt
    endif

;-----------------------------------------------------
; Frequency Range \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

    ;Will we need to interpolate to match the desired frequencies? This will be
    ;true if either of the LOGSPACE or LINSPACE keywords are set.
    tf_interp = 0

    ;LOGRANGE
    if keyword_set(logrange) then begin
        tf_interp = 1
        if logrange eq 1 then logrange = floor(n_elements(frequencies)/10)
        
        ;Create a logarithmically spaced array of frequencies, symmetric about 0
        interp_freqs = logspace(fmin, fmax, logrange)
        interp_freqs = [interp_freqs, -reverse(interp_freqs)]
        
        nfreqs = n_elements(interp_freqs)
        iMax_interp = logrange - 1

    ;LINRANGE
    endif else if keyword_set(linrange) then begin
        tf_interp = 1
        if linrange eq 1 then linrange = 50
        
        ;Create a linearly spaced array of frequencies, symmetric about 0
        interp_freq = linspace(fmin, fmax, linrange)
        if interp_freq[0] eq 0 $
            then interp_freqs = [interp_freqs, -reverse(interp_freqs[1:*])] $
            else interp_freqs = [interp_freqs, -reverse(interp_freqs)]
            
        nfreqs = n_elements(interp_freqs)
        iMax_interp = linrange - 1

    ;NORMAL
    endif else begin
        ;Find the frequency range for which the FFT is to be calculated. We do not
        ;want 0 counted twice.
        if fmin eq 0 then fmin_neg = frequencies[1] $
                     else fmin_neg = fmin
        negFreqs = where(frequencies le -fmin_neg and $
                         frequencies ge -fmax, nneg)
        posFreqs = where(frequencies ge fmin and $
                         frequencies le fmax, npos)
    
        nfreqs = npos + nneg

        ;If no frequencies fall within the desired range, pick everything
        if nfreqs eq 0 then begin
            theseFreqs = lindgen(iNyquist)
            iMax = iNyquist - 1
        
        ;Otherwise, organize the frequency indices with positive first
        endif else begin
            ;Put the positive freuqn
            theseFreqs = [posFreqs[sort(posFreqs)], negFreqs[sort(negFreqs)]]
            iMax = npos - 1
        endelse
    endelse

;-----------------------------------------------------
; Allocate Memory \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;IDL ignores empty dimensions when the "*" operator is used, so indexing ARRAY[i,*]
    ;is the same for 1D and 2D arrays. Therefore, put the dimension over which we are
    ;taking the FFT first so that the 1D and 2D cases can be treated equally. Dimensions
    ;will now be ordered (time[, component]).
    case dimension of
        0: data_temp = temporary(data)
        1: data_temp = temporary(data)
        2: data_temp = transpose(temporary(data))
        else: message, 'DIMENSION is out of range.'
    endcase
    if double then data_temp = double(temporary(data_temp))
    
    ;Allocate memory to the output array. It will have an extra dimension. Arrange
    ;dimensions as (time, frequency[, component])
    ndims = size(data_temp, /N_DIMENSIONS)
    dims  = size(data_temp, /DIMENSIONS)

    if ndims eq 1 $
        then fft_data = make_array(n_intervals, nfreqs, TYPE=out_type) $
        else fft_data = make_array(n_intervals, nfreqs, dims[1], TYPE=out_type)
        
    ;make a time array
    if keep_time then time = fltarr(n_intervals)
 
;-----------------------------------------------------
; Take the FFT \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

    ;Create the window
    if window then begin
        theWindow = hanning(nfft, ALPHA=alpha)
        if ndims eq 2 then theWindow = rebin(theWindow, [nfft, dims[1]])
    endif

    sindex = 0
    eindex = nfft - 1
    ;for each fft interval...
    for i = 0, n_intervals-1 do begin
        ;Print progress
        if tf_vverbose and i mod 100 eq 0 then $
            print, FORMAT='(%"%5.1f percent done. Interval %i of %i")', $
                   (float(i)+1)/float(n_intervals)*100, i+1, n_intervals
        
    ;-----------------------------------------------------
    ; Handle Fill Values \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    ;-----------------------------------------------------
        ;Replace a fill value?
        fill_data = data_temp[sindex:eindex, *]
        if tf_fillval then begin
            ;Find the fill values
            if finite(fillval) $
                then iFill = where(fill_data eq fillval, nFill) $
                else iFill = where(finite(fill_data) eq 0, nFill)
            pct_fill = float(nFill) / float(nfft*dims[1]) * 100.0
            
            ;Interpolate if we can.
            if nFill gt 0 && pct_fill le interp_pct then begin
                if tf_vverbose then print, FORMAT='(%"Interval %i of %i is %0.1f\% fill values. Interpolating.")', i+1, n_intervals, pct_fill
                for j = 0, dims[1] - 1 do $
                    fill_data[0,j] = MrInterpol(fill_data[*,j], fillval, findgen(nfft))
            ;Replace if we must.
            endif else if pct_fill gt 0.0 then begin
                if tf_verbose then print, FORMAT='(%"Interval %i of %i is %0.1f\% fill values (> %0.1f\%)")', i+1, n_intervals, pct_fill, interp_pct
                fill_data = replace_fillval(fill_data, fillval)
            endif
        endif
        
    ;-----------------------------------------------------
    ; Calculate the FFT \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    ;-----------------------------------------------------
        ;If the second dimension is empty, IDL will ignore it.
        if window then fill_data *= theWindow
        fft_temp = fft(temporary(fill_data), DIMENSION=1, DOUBLE=double)

    ;-----------------------------------------------------
    ; Pick Desired Frequencies \\\\\\\\\\\\\\\\\\\\\\\\\\\
    ;-----------------------------------------------------
        ;Do we need to interpolate?
        if tf_interp then begin
            ;to interpolate, frequencies must be monotonic, so put negative
            ;frequencies first.

            frequencies  = shift(frequencies, iNyquist-1)
            interp_freqs = shift(interp_freqs, iMax_interp+1)
            
            ;If the FFT is not centered, then center it for interpolation
            if keyword_set(center) eq 0 then begin
                case ndims of
                    1: fft_temp = shift(fft_temp, iNyquist-1)
                    2: fft_temp = shift(fft_temp, iNyquist-1, 0)
                endcase
            endif

            ;Interpolate.
            fft_temp = MrInterpol(fft_temp, frequencies, interp_freqs)
            
            ;If the FFT is not centered, then we have to shift everything back
            if keyword_set(center) eq 0 then begin
                frequencies = shift(frequencies, -(iNyquist-1))
                interp_freqs = shift(interp_freqs, -(iMax_interp+1))
                case ndims of
                    1: fft_temp = shift(fft_temp, -(iMax_interp+1))
                    2: fft_temp = shift(fft_temp, -(iMax_interp+1), 0)
                endcase
            endif

        ;No interpolation
        endif else begin
            ;Put the DC frequency in the middle if requested
            if keyword_set(center) then theseFreqs = shift(theseFreqs, iMax)
        
            ;Pick out the amplitudes of the requested frequencies. If FFT_TEMP is 1D,
            ;the extra * will be ignored
            fft_temp = fft_temp[theseFreqs,*]
        endelse

    ;-----------------------------------------------------
    ; Move to Next Interval \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    ;-----------------------------------------------------
        ;Store the FFT such that the dimensions are arranged as (time, frequency[, component])
        ;IDL ignores the last "*" operator if FFT_DATA is only 2D. Multiply by 1/dt to
        ;convert to physical units (IDL multiplies by 1/N within FFT()).
        fft_data[i,*,*] = 1.0/dt * temporary(fft_temp)
        
        ;Create the time tag.
        if keep_time then time[i] = (i + ct) * nshift * dt

        ;shift the fft by the desired number of points
        sindex += nshift
        eindex += nshift
    endfor

;-----------------------------------------------------
; Finish Up \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    ;Return DATA_TEMP to DATA
    case dimension of
        0: data = temporary(data_temp)
        1: data = temporary(data_temp)
        2: data = transpose(temporary(data_temp))
    endcase
    
    ;Apply the time offset
    if (keep_time eq 1) and (t0 ne 0.0) then time += t0

    ;Output only the desired frequencies
    if tf_interp $
        then frequencies = interp_freqs $
        else frequencies = frequencies[theseFreqs]
        
    return, fft_data
end