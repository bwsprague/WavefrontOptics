% v_wvfSVNVer121TestData
%
% Tests that we can reconstruct PSFs computed using version 121 of the
% toolbox (BrainardLab SVN server).  This was pretty early in the
% development, April 30, 2011, and prior to various major organizational
% changes.
%
% The version that generated the test data is saved as a branch on the
% BrainardLab SVN server, with the new test program that writes out the data. 
% If we need more test cases, can generate them there.
%
% This is not really an independent test of the underlying code, but does
% serve to verify that the basic computations still work as they did
% when we first got the code from Heidi Hofer.
%
% As of 7/4/12, it appears that there has been a switch in the row
% and column convention of the code.  I believe this happened because
% Heidi's code's x/y convention was mismatched to Matlab's row/col
% convention, and one of Brian's students switched this.  The current
% code is cleaner, but I am not sure that it matches the way the PSF
% would actually look on the retina.
%
% 7/4/12  dhb  Wrote first draft.
%
% (c) Wavefront Toolbox Team, 2012

%% Initialize
s = which('v_wvfSVNVer121TestData');
cd(fileparts(s));
clear; close all;
%s_initISET;

%% Plot diffraction (tends to compress the scale of observer calcs)
PLOT_DIFFRACTION = 0;

%% Load in a test data set computed with SVN Version 121 (BrainardLab server)
%
% This is a very early version of the code as we got it from Heidi Hofer
% and serves as a test that we haven't munged anything up since that point.
theFiles = {'SVNVer121_subj1_calcpupil3_defocus0_wavelength550_sce0', ...
    'SVNVer121_subj4_calcpupil3_defocus0_wavelength550_sce0', ...
    'SVNVer121_subj1_calcpupil3_defocus0_wavelength450_sce0', ...
    'SVNVer121_subj1_calcpupil5_defocus0_wavelength550_sce0', ...
    'SVNVer121_subj1_calcpupil3_defocus2_wavelength550_sce0', ...
    'SVNVer121_subj1_calcpupil3_defocus0_wavelength550_sce1', ...
    'SVNVer121_subj1_calcpupil3_defocus1_wavelength550_sce1', ...
    };

for i = 1:length(theFiles)
    testData = load(fullfile('validationData','SVNVer121',theFiles{i}));
    
    %% Set up parameters structure to match old code, for diffraction limited computation
    wvf0 = wvfCreate;
    wvf0 = wvfSet(wvf0,'measured pupil size',testData.measpupilMM);
    wvf0 = wvfSet(wvf0,'measured wl',testData.nominalFocusWavelength);
    wvf0 = wvfSet(wvf0,'spatial samples',testData.sizeOfFieldPixels);
    wvf0 = wvfSet(wvf0,'ref pupil plane size',testData.sizeOfFieldMM);
    wvf0 = wvfSet(wvf0,'calc pupil size',testData.calcpupilMM);
    wvf0 = wvfSet(wvf0,'calc observer focus correction',testData.defocusDiopters);
    wvf0 = wvfSet(wvf0,'calc wavelengths',testData.theWavelength);
    if (testData.DOSCE == 1)
        sce = sceCreate(testData.theWavelength,'berendshot');
        wvf0 = wvfSet(wvf0,'sce params',sce);
    else
        sce = sceCreate(testData.theWavelength,'none');
        wvf0 = wvfSet(wvf0,'sce params',sce);
    end
    
    % Compute diffraction limited PSF our way
    wvf0 = wvfSet(wvf0,'zcoeffs',zeros(size(testData.theZcoeffs)));
    wvf0 = wvfComputePSF(wvf0);
    diffracpsf0 = wvfGet(wvf0,'psf',testData.theWavelength);
    diffracpsfLine0 =  diffracpsf0(wvfGet(wvf0,'middle row'),:);
    diffracpsfLine0Centered = wvfGet(wvf0,'1d psf',testData.theWavelength);
    diffracarcmin0 = wvfGet(wvf0,'samples angle','min',testData.theWavelength);
    arcminperpix0 = wvfGet(wvf0,'psf arcmin per sample',testData.theWavelength);
    
    % Compute observer PSF our way.
    wvf0 = wvfSet(wvf0,'zcoeffs',testData.theZcoeffs);
    wvf0 = wvfComputePSF(wvf0);
    psf0 = wvfGet(wvf0,'psf',testData.theWavelength);
    psfLine0 = psf0(wvfGet(wvf0,'middle row'),:);
    psfLineCentered0 = wvfGet(wvf0,'1d psf',testData.theWavelength);
    arcmin0 = wvfGet(wvf0,'samples angle','min',testData.theWavelength);
    
    % Make a comparison plot
    %
    % Notice that I need to pull out the column from the old
    % computation to match the row of the current computation.
    figure; clf; hold on
    if (PLOT_DIFFRACTION)
        plot(diffracarcmin0,diffracpsfLine0,'r','LineWidth',3);
        plot(testData.arcminutes,testData.diffracPSF(:,testData.whichRow),'g');
    end
    plot(arcmin0,psfLine0,'b','LineWidth',3);
    plot(testData.arcminutes,testData.thePSF(:,testData.whichRow),'g');
    plot(arcmin0,psfLineCentered0,'k','LineWidth',3);
    plot(testData.arcminutes,testData.thePSFCentered(:,testData.whichRow),'g');
    xlabel('arc minutes');
    ylabel('psf');
    title(LiteralUnderscore(theFiles{i}));
end

