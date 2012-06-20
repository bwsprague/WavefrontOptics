%% Adaptive optics data for the human point spread function
%
% s_wvfThibosModel
%
% Using adaptive optics, a group led by Thibos collected many different
% wavefronts in the human eye for a range of pupil sizes.  They summarized
% these data using a simple statistical model of the Zernicke polynomial
% coefficients. These were published in several papers, the most recent
% being
%
%   "Retinal Image Quality for Virtual Eyes Generated by a Statistical
%   Model of Ocular Wavefront Aberrations" published in Ophthalmological
%   and Physiological Optics (2009). Thibos, Ophthalmic & Physiological
%   Optics.
%   http://onlinelibrary.wiley.com/doi/10.1111/j.1475-1313.2009.00662.x/full
%
% The data and a sample program are onlineat the bottom of the online
% article in Supporting Information.
%
% We retrieved the data and implemented our version of the calculations
% in the Wavefront toolbox. This script calculates the PSF for example
% subjects.  
%
% See also:  VirtualEyesDemo and wvfLoadHuman 
%
% Copyright Wavefront Toolbox Team, 2012

%% Initialize ISET
% Set the largest size in microns for plotting
% Set the pupil diameter in millimeters
s_initISET
maxUM = 40;    
pupilMM = 4.5; 

%%  Load the statistical wavefront properties 
% The Zernike coefficients describing the wavefront aberrations are each
% distributed as a Gaussian. There is some covariance between these
% coefficients.  The covariance is summarized in the variable S.  The mean
% values across a large sample of eyes measured by Thibos and gang are in
% the variable sample_mean.
[sample_mean S] = wvfLoadHuman(pupilMM);

%% Plot the means and covariance (not)
vcNewGraphWin([],'tall');

subplot(3,1,1)
plot(sample_mean,'--o'); grid on
xlabel('Zernike polynomial number')
ylabel('Coefficient value')
title('Mean coefficient');

subplot(3,1,2)
imagesc(S);
axis image, 
colormap(hot); colorbar
title('Coefficient covariance')

% Calculate sample eyes using the multivariate normal distribution Each
% column of Zcoeffs is an example person. Each row of R is a vector of
% Zernike coeffs
N = 10;
Zcoeffs = ieMvnrnd(sample_mean,S,N)';  

% Plot the random examples of coefficients
subplot(3,1,3)
plot(Zcoeffs); grid on
xlabel('Zernike polynomial number')
ylabel('Coefficient value')
title('Example coefficients')

%% Examine a single PSF for the subject at the sample mean

% Allocate space and fill in the lower order Zernicke coefficients
z = zeros(65,1);
z(1:13) = sample_mean(1:13);

% Create the example subject
thisGuy = wvfCreate;                                  % Initialize
thisGuy = wvfSet(thisGuy,'zcoeffs',z);                % Zernike
thisGuy = wvfSet(thisGuy,'measured pupil',pupilMM);   % Data
thisGuy = wvfSet(thisGuy,'calculated pupil',pupilMM); % What we calculate
thisGuy = wvfSet(thisGuy,'measured wl',550);
thisGuy = wvfSet(thisGuy,'wavelength',[450 100 3]);     % SToWls format
thisGuy = wvfComputePSF(thisGuy);

%% Plot the PSFs of the sample mean subject for several wavelengths
% These illustrate the strong axial chromatic aberration.

wave  = wvfGet(thisGuy,'wave');
nWave = wvfGet(thisGuy,'nwave');
vcNewGraphWin([],'tall');
for ii=1:nWave
    subplot(nWave,1,ii)
    wvfPlot(thisGuy,'image psf space','um',ii,maxUM);
    title(sprintf('%d nm',wave(ii)));
end

%% Calculate the PSFs from the coeffcients
% Here we illustrate the variance between different subjects.

% Choose example subjects
whichSubjects = 1:3:N;
nSubjects = length(whichSubjects);
z = zeros(65,1);     % Allocate space for the Zernicke coefficients

% Create the example subject
thisGuy = wvfCreate;                                % Initialize
thisGuy = wvfSet(thisGuy,'measuredpupil',pupilMM);  % Data
thisGuy = wvfSet(thisGuy,'calculatedpupil',pupilMM);% What we calculate

vcNewGraphWin([],'tall');
for ii = 1:nSubjects
    
    % Choose different coefficients and compute for each subject
    z(1:13) = Zcoeffs(1:13,whichSubjects(ii));
    thisGuy = wvfSet(thisGuy,'zcoeffs',z);              % Zernike
    thisGuy = wvfComputePSF(thisGuy);

    subplot(nSubjects,1,ii)
    wvfPlot(thisGuy,'image psf space','um',1,maxUM);
    title(sprintf('Subject %d\n',ii))
end


