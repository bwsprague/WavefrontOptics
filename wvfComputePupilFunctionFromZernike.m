function [wvfParams] = wvfComputePupilFunctionFromZernike(wvfParams)
% [wvfParams] = wvfComputePupilFunctionFromZernike(wvfParams)
%
% Compute the monochromatic pupil fuction (amplitude and phase) over the calculated pupil size for 10 orders of Zernike
% coeffcients specified to the OSA standard. Includes SCE (Stiles-Crawford Effect) if specified.
%
% Required input fields for wvfParams struct
%   zcoeffs -           Zernike coefficients. Expects 65 coefficients numbered with the osa j index.
%                       These are up to the 10th order.  Coefficients zcoeffs(1) and zcoeffs(2) are tip and
%                       tilt, and are not entered into the calculations (i.e. treated as zero ). zcoeffs(3)
%                       through zcoeffs(5) are astigmatism and defocus.  You can pass fewer than the full 65
%                       coefficients, in which case the trailing coefficients are set to zero.
%   measpupilMM -       Size of pupil characterized by the coefficients, in MM.
%   caclpupilMM -       Size over which returned pupil function is calculated, in MM.
%                       Must be smaller than measpupilMM.
%   wl -                Wavelength to compute for, in NM.
%   sizeOfFieldPixels - Linear size of square image over which the pupil function is computed.
%                       Note that this is not the number of pixels across the pupil unless
%                       the sizeOfFieldMM parameter is equal to the calpupilMM parameter.
%                       Indeed, the number of pixels across the calculated pupil is this number
%                       times the ratio (calcpupilMM/sizeOfFieldMM).
%   sizeOfFieldMM -     Size of square image over which the pupile function is computed in MM.
%                       Setting this larger than the calculated pupil size prevents undersampling
%                       of the PSF that will ultimately be comptued from the pupil function.
%
% Optional input fields for wvfParams struct 
%   sceParams -         Parameter structure for Stiles-Crawford correction.  If missing or set to empty,
%                       no correction and is set to empty on return.  See wvfGetStilesCrawfordParams.
%
% Output fields set in wvfParams struct 
%   pupilfunc -     Calcuated pupil function
%   areapix -       Number of pixels within the computed pupil aperture
%   areapixapod -   Number of pixels within the computed pupil aperture,
%                   multiplied by the Stiles-Crawford aopdization.
%
% All aberrations other than defocus (including astigmatism) are assumed
% to be constant with wavelength, as variation with wavelength in other
% aberrations is known to be small.
%
% Transverse chromatic aberration (TCA), which is a wavelength dependent tip
% or tilt, has also not been included. 
%
% Dividing the psf computed from the returned pupil function by areapix
% (or areapixapod) squared effects a normalization so that the peak reflects
% the strehl ratio.
%
% See also: wvfComputePSFFromZernike, wvfGetStilesCrawfordParams.
%
% Code provided by Heidi Hofer.
%
% 8/20/11 dhb      Rename function and pull out of supplied routine. Reformat comments.
% 9/5/11  dhb      Rewrite for wvfParams struct i/o.  Rename.

% Handle case where not all 65 coefficients are passed
c = zeros(65,1);
c(1:length(wvfParams.zcoeffs)) = wvfParams.zcoeffs;

% Convert passed wavelengths to microns
wlInUM = wvfParams.wl/1000;

% Sanity check
if (wvfParams.calcpupilMM > wvfParams.measpupilMM)
    error('Requested size for calculation cannot exceed size over which measuremnts were made');
end
if (length(wvfParams.wl) ~= 1)
    error('Only handles one wavelength at a time');
end

% Set SCE correction params, if desired
if (~isfield(wvfParams,'sceParams') || isempty(wvfParams.sceParams))
    xo = 0;
    yo = 0;
    rho = zeros(size(wvfParams.wl));
else
    xo=wvfParams.sceParams.xo;
    yo=wvfParams.sceParams.yo;
    index = find(wvfParams.wavelengths/1000 == wlInUM);
    if (length(index) ~= 1)
        error('Pased wavelength not contained in sceParams');
    end
    rho = wvfParams.sceParams.rho(index);
end

% Set up SCE correction
if all(rho) == 0;
    A=ones(wvfParams.sizeOfFieldPixels);
else
    for ny = 1:wvfParams.sizeOfFieldPixels
        for nx = 1:wvfParams.sizeOfFieldPixels  
            xpos = ((nx-1)*(wvfParams.sizeOfFieldMM/wvfParams.sizeOfFieldPixels)-(wvfParams.sizeOfFieldMM/2));
            ypos = ((ny-1)*(wvfParams.sizeOfFieldMM/wvfParams.sizeOfFieldPixels)-(wvfParams.sizeOfFieldMM/2));
            A(nx,ny)=10^(-rho*((xpos-xo)^2+(ypos-yo)^2));
        end
    end
end

% Compute the pupil function
wvfParams.pupilfunc = zeros(wvfParams.sizeOfFieldPixels,wvfParams.sizeOfFieldPixels);
k=0;
for ny = 1:wvfParams.sizeOfFieldPixels
    for nx = 1:wvfParams.sizeOfFieldPixels
        xpos = ((nx-1)*(wvfParams.sizeOfFieldMM/wvfParams.sizeOfFieldPixels)-(wvfParams.sizeOfFieldMM/2));
        ypos = ((ny-1)*(wvfParams.sizeOfFieldMM/wvfParams.sizeOfFieldPixels)-(wvfParams.sizeOfFieldMM/2));
        norm_radius = (sqrt(xpos^2+ypos^2))/(wvfParams.measpupilMM/2);
        if (xpos==0 && ypos>0)
            angle = 3.1416/2;
        elseif(xpos==0 && ypos<0)
            angle = -3.1416/2;
        elseif(xpos==0 && ypos==0)
            angle = 0;
        elseif(xpos>0)
            angle = atan(ypos/xpos);
        else
            angle= 3.1416 + atan(ypos/xpos);
        end
        if norm_radius > wvfParams.calcpupilMM/wvfParams.measpupilMM
            wvfParams.pupilfunc(nx,ny)=0;
        else
            phase = 0;
            phase = 0+...
                c(5) * sqrt(6)*norm_radius^2 * cos(2 * angle) + ...
                c(3) * sqrt(6)*norm_radius^2 * sin(2 * angle) + ...
                c(4) * sqrt(3)*(2 * norm_radius^2 - 1) + ...
                c(9) *sqrt(8)* norm_radius^3 * cos(3 * angle) + ...
                c(6) *sqrt(8)* norm_radius^3 * sin(3 * angle) + ...
                c(8) *sqrt(8)* (3 * norm_radius^3 - 2 * norm_radius) * cos(angle) + ...
                c(7) *sqrt(8)* (3 * norm_radius^3 - 2 * norm_radius) * sin(angle) + ...
                c(14) * sqrt(10)*norm_radius^4 * cos(4 * angle) + ...
                c(10) * sqrt(10)*norm_radius^4 * sin(4 * angle) + ...
                c(13) * sqrt(10)*(4 * norm_radius^4 - 3 * norm_radius^2) * cos(2 * angle) + ...
                c(11) * sqrt(10)*(4 * norm_radius^4 - 3 * norm_radius^2) * sin(2 * angle) + ...
                c(12) * sqrt(5)*(6 * norm_radius^4 - 6 * norm_radius^2 + 1)+...
                c(20) * 2*sqrt(3)*norm_radius^5 * cos(5 * angle) + ...
                c(15) *2*sqrt(3)* norm_radius^5 * sin(5 * angle) + ...
                c(19) * 2*sqrt(3)*(5 * norm_radius^5 - 4 * norm_radius^3) * cos(3 * angle) + ...
                c(16) *2*sqrt(3)* (5 * norm_radius^5 - 4 * norm_radius^3) * sin(3 * angle) + ...
                c(18) *2*sqrt(3)* (10 * norm_radius^5 - 12 * norm_radius^3 + 3 * norm_radius) * cos(angle) + ...
                c(17) *2*sqrt(3)* (10 * norm_radius^5 - 12 * norm_radius^3 + 3 * norm_radius) * sin(angle) + ...
                c(27) *sqrt(14)* norm_radius^6 * cos(6 * angle) + ...
                c(21) *sqrt(14)*norm_radius^6 * sin(6 * angle) + ...
                c(26) *sqrt(14)*(6 * norm_radius^6 - 5 * norm_radius^4) * cos(4 * angle) + ...
                c(22) *sqrt(14)*(6 * norm_radius^6 - 5 * norm_radius^4) * sin(4 * angle) + ...
                c(25) *sqrt(14)* (15 * norm_radius^6 - 20 * norm_radius^4 + 6 * norm_radius^2) * cos(2 * angle) + ...
                c(23) *sqrt(14)*(15 * norm_radius^6 - 20 * norm_radius^4 + 6 * norm_radius^2) * sin(2 * angle) + ...
                c(24) *sqrt(7)* (20 * norm_radius^6 - 30 * norm_radius^4 + 12 * norm_radius^2 - 1)+...
                c(35) *4* norm_radius^7 * cos(7 * angle) + ...
                c(28) *4* norm_radius^7 * sin(7 * angle) + ...
                c(34) *4* (7 * norm_radius^7 - 6 * norm_radius^5) * cos(5 * angle) + ...
                c(29) *4* (7 * norm_radius^7 - 6 * norm_radius^5) * sin(5 * angle) + ...
                c(33) *4* (21 * norm_radius^7 - 30 * norm_radius^5 + 10 * norm_radius^3) * cos(3 * angle) + ...
                c(30) *4* (21 * norm_radius^7 - 30 * norm_radius^5 + 10 * norm_radius^3) * sin(3 * angle) + ...
                c(32) *4* (35 * norm_radius^7 - 60 * norm_radius^5 + 30 * norm_radius^3 - 4 * norm_radius) * cos(angle) + ...
                c(31) *4* (35 * norm_radius^7 - 60 * norm_radius^5 + 30 * norm_radius^3 - 4 * norm_radius) * sin(angle) +...
                c(44) *sqrt(18)* norm_radius^8 * cos(8 * angle) + ...
                c(36) *sqrt(18)* norm_radius^8 * sin(8 * angle) + ...
                c(43) *sqrt(18)* (8 * norm_radius^8 - 7 * norm_radius^6) * cos(6 * angle) + ...
                c(37) *sqrt(18)* (8 * norm_radius^8 - 7 * norm_radius^6) * sin(6 * angle) + ...
                c(42) *sqrt(18)* (28 * norm_radius^8 - 42 * norm_radius^6 + 15 * norm_radius^4) * cos(4 * angle) + ...
                c(38) *sqrt(18)* (28 * norm_radius^8 - 42 * norm_radius^6 + 15 * norm_radius^4) * sin(4 * angle) + ...
                c(41) *sqrt(18)* (56 * norm_radius^8 - 105 * norm_radius^6 + 60 * norm_radius^4 - 10 * norm_radius^2) * cos(2 * angle) + ...
                c(39) *sqrt(18)* (56 * norm_radius^8 - 105 * norm_radius^6 + 60 * norm_radius^4 - 10 * norm_radius^2) * sin(2 * angle) + ...
                c(40) *3* (70 * norm_radius^8 - 140 * norm_radius^6 + 90 * norm_radius^4 - 20 * norm_radius^2 + 1) + ...
                c(54) *sqrt(20)* norm_radius^9 * cos(9 * angle) + ...
                c(45) *sqrt(20)* norm_radius^9 * sin(9 * angle) + ...
                c(53) *sqrt(20)* (9 * norm_radius^9 - 8 * norm_radius^7) * cos(7 * angle) + ...
                c(46) *sqrt(20)* (9 * norm_radius^9 - 8 * norm_radius^7) * sin(7 * angle) + ...
                c(52) *sqrt(20)* (36 * norm_radius^9 - 56 * norm_radius^7 + 21 * norm_radius^5) * cos(5 * angle) + ...
                c(47) *sqrt(20)* (36 * norm_radius^9 - 56 * norm_radius^7 + 21 * norm_radius^5) * sin(5 * angle) + ...
                c(51) *sqrt(20)* (84 * norm_radius^9 - 168 * norm_radius^7 + 105 * norm_radius^5 - 20 * norm_radius^3) * cos(3 * angle) + ...
                c(48) *sqrt(20)* (84 * norm_radius^9 - 168 * norm_radius^7 + 105 * norm_radius^5 - 20 * norm_radius^3) * sin(3 * angle) + ...
                c(50) *sqrt(20)* (126 * norm_radius^9 - 280 * norm_radius^7 + 210 * norm_radius^5 - 60 * norm_radius^3 + 5 * norm_radius) * cos(angle) + ...
                c(49) *sqrt(20)* (126 * norm_radius^9 - 280 * norm_radius^7 + 210 * norm_radius^5 - 60 * norm_radius^3 + 5 * norm_radius) * sin(angle) + ...
                c(65) *sqrt(22)* norm_radius^10 * cos(10 * angle) + ...
                c(55) *sqrt(22)* norm_radius^10 * sin(10 * angle) + ...
                c(64) *sqrt(22)* (10 * norm_radius^10 - 9 * norm_radius^8) * cos(8 * angle) + ...
                c(56) *sqrt(22)* (10 * norm_radius^10 - 9 * norm_radius^8) * sin(8 * angle) + ...
                c(63) *sqrt(22)* (45 * norm_radius^10 - 72 * norm_radius^8 + 28 * norm_radius^6) * cos(6 * angle) + ...
                c(57) *sqrt(22)* (45 * norm_radius^10 - 72 * norm_radius^8 + 28 * norm_radius^6) * sin(6 * angle) + ...
                c(62) *sqrt(22)* (120 * norm_radius^10 - 252 * norm_radius^8 + 168 * norm_radius^6 - 35 * norm_radius^4) * cos(4 * angle) + ...
                c(58) *sqrt(22)* (120 * norm_radius^10 - 252 * norm_radius^8 + 168 * norm_radius^6 - 35 * norm_radius^4) * sin(4 * angle) + ...
                c(61) *sqrt(22)* (210 * norm_radius^10 - 504 * norm_radius^8 + 420 * norm_radius^6 - 140 * norm_radius^4 + 15 * norm_radius^2) * cos(2 * angle) + ...
                c(59) *sqrt(22)* (210 * norm_radius^10 - 504 * norm_radius^8 + 420 * norm_radius^6 - 140 * norm_radius^4 + 15 * norm_radius^2) * sin(2 * angle) + ...
                c(60) *sqrt(11)* (252 * norm_radius^10 - 630 * norm_radius^8 + 560 * norm_radius^6 - 210 * norm_radius^4 + 30 * norm_radius^2 - 1);
            wvfParams.pupilfunc(nx,ny) = A(nx,ny).*exp(-i * 2 * 3.1416 * phase/wlInUM);
            k=k+1;
        end
    end
end
wvfParams.areapix=k;
wvfParams.areapixapod=sum(sum(abs(wvfParams.pupilfunc)));
end