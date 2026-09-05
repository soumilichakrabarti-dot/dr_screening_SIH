function report = assess_image_quality(imagePath)
% ASSESS_IMAGE_QUALITY  Check a fundus photo for gradability before diagnosis.
%
%   report = assess_image_quality(imagePath)
%
% This checks three things a real ophthalmologist would check before
% trusting a fundus photo:
%   1. FOCUS       - is the image sharp enough to see fine detail?
%   2. ILLUMINATION - is it too dark, too bright, or unevenly lit?
%   3. FIELD OF VIEW - does the photo actually capture the retina properly,
%                       or is it mostly black border / off-center?
%
% Returns a struct "report" with the scores and a pass/fail decision,
% plus specific feedback (like a real screening tool would give the
% camera operator) if something needs to be recaptured.

    img = imread(imagePath);

    % Standardize size before any measurement. Variance-of-Laplacian (our
    % focus check below) is sensitive to image resolution - a smaller or
    % more compressed photo can score lower even when it's genuinely
    % sharp, just because there's less raw pixel detail to measure. In a
    % real deployment every image comes from the same camera at the same
    % resolution, so this wouldn't matter - but our test images came from
    % different websites at different sizes, so we resize everything to
    % a consistent scale first to make scores comparable.
    STANDARD_SIZE = 700;   % target size for the longer edge, in pixels
    [h, w, ~] = size(img);
    scaleFactor = STANDARD_SIZE / max(h, w);
    img = imresize(img, scaleFactor);

    gray = im2gray(img);          % most quality checks work on grayscale
    gray = im2double(gray);       % convert to 0-1 range for consistent math

    report = struct();
    report.imagePath = imagePath;

    % ---------------------------------------------------------------
    % 0. FIELD OF VIEW / RETINA MASK - computed FIRST
    % ---------------------------------------------------------------
    % Every fundus photo has black corners outside the circular retinal
    % field - that's just how the camera works, not a quality problem.
    % We find that circular region first so every other check below can
    % ignore the black background and only look at the actual eye tissue.
    retinaMask = gray > 0.06;                  % anything not near-black
    retinaMask = imfill(retinaMask, 'holes');   % fill small dark lesions/vessels
    retinaFraction = sum(retinaMask(:)) / numel(retinaMask);

    report.retinaFraction = retinaFraction;
    FOV_MIN_FRACTION = 0.35;   % retina should fill at least ~35% of the frame
    report.fovPass = retinaFraction >= FOV_MIN_FRACTION;

    % pixel values, but ONLY from inside the retina - this is what the
    % focus and illumination checks below should actually look at.
    retinaPixels = gray(retinaMask);

    % ---------------------------------------------------------------
    % 1. FOCUS CHECK - variance of Laplacian, retina region only
    % ---------------------------------------------------------------
    % The Laplacian filter highlights edges (sharp intensity changes).
    % A sharp, in-focus image has lots of strong edges -> high variance.
    % A blurry image has soft transitions everywhere -> low variance.
    % We filter the whole image first (edges need neighboring context),
    % but only measure the variance over the retina region - a large
    % black border would otherwise dilute the score with meaningless
    % zero-variance area.
    laplacianKernel = fspecial('laplacian');
    edgeResponse = imfilter(gray, laplacianKernel, 'replicate');
    focusScore = var(edgeResponse(retinaMask));

    FOCUS_THRESHOLD = 0.0004;   % calibrated against a visually-confirmed sharp sample
    report.focusScore = focusScore;
    report.focusPass = focusScore >= FOCUS_THRESHOLD;

    % ---------------------------------------------------------------
    % 2. ILLUMINATION CHECK - brightness + over/under-exposure, retina region only
    % ---------------------------------------------------------------
    meanBrightness = mean(retinaPixels);
    % Fraction of RETINA pixels that are essentially pure black or pure
    % white - a high fraction means the camera flash was badly
    % under/over-exposed. Black corners are excluded entirely now.
    overExposedFrac = sum(retinaPixels > 0.95) / numel(retinaPixels);
    underExposedFrac = sum(retinaPixels < 0.05) / numel(retinaPixels);

    report.meanBrightness = meanBrightness;
    report.overExposedFrac = overExposedFrac;
    report.underExposedFrac = underExposedFrac;

    BRIGHTNESS_LOW = 0.15;
    BRIGHTNESS_HIGH = 0.85;
    EXPOSURE_FRAC_LIMIT = 0.10;   % more than 10% blown-out/black pixels = bad

    report.illuminationPass = ...
        meanBrightness >= BRIGHTNESS_LOW && meanBrightness <= BRIGHTNESS_HIGH && ...
        overExposedFrac <= EXPOSURE_FRAC_LIMIT && ...
        underExposedFrac <= EXPOSURE_FRAC_LIMIT;

    % ---------------------------------------------------------------
    % Overall decision + specific feedback (like the problem statement
    % asks: "reject ungradeable ones with recapture feedback")
    % ---------------------------------------------------------------
    report.gradable = report.focusPass && report.illuminationPass && report.fovPass;

    feedback = {};
    if ~report.focusPass
        feedback{end+1} = 'Image appears blurry - refocus the camera and recapture.';
    end
    if ~report.illuminationPass
        if meanBrightness < BRIGHTNESS_LOW
            feedback{end+1} = 'Image is too dark - increase flash intensity and recapture.';
        elseif meanBrightness > BRIGHTNESS_HIGH
            feedback{end+1} = 'Image is overexposed - reduce flash intensity and recapture.';
        else
            feedback{end+1} = 'Uneven illumination detected - reposition camera and recapture.';
        end
    end
    if ~report.fovPass
        feedback{end+1} = 'Retinal field of view too small/off-center - recenter on the retina and recapture.';
    end
    if isempty(feedback)
        feedback{end+1} = 'Image passed all quality checks.';
    end
    report.feedback = feedback;

    % Borderline case: technically passed, but close to a threshold -
    % flag it as a candidate for enhancement rather than a clean pass.
    borderline = report.gradable && ...
        (focusScore < FOCUS_THRESHOLD * 2 || ...
         overExposedFrac > EXPOSURE_FRAC_LIMIT * 0.5 || ...
         underExposedFrac > EXPOSURE_FRAC_LIMIT * 0.5);
    report.borderline = borderline;
end
