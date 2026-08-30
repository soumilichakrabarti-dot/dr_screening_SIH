function enhancedImg = enhance_image(imagePath)
% ENHANCE_IMAGE  Apply adaptive enhancement to a borderline-quality fundus photo.
%
%   enhancedImg = enhance_image(imagePath)
%
% This is only meant to be run on images that assess_image_quality.m
% flagged as "borderline" (passed, but close to failing) - not on
% clearly good images (unnecessary) or clearly bad ones (enhancement
% can't fix a badly out-of-focus or badly cropped photo; those should
% be rejected and recaptured instead).
%
% Three techniques, applied in order:
%   1. Denoising            - remove sensor noise before anything else
%   2. Illumination normalization - even out lighting across the frame
%   3. CLAHE                - boost local contrast so lesions are more visible

    img = imread(imagePath);
    img = im2double(img);

    % ---------------------------------------------------------------
    % 1. DENOISE
    % ---------------------------------------------------------------
    % A mild Gaussian filter removes sensor noise without blurring away
    % the fine detail we need (microaneurysms are small - be gentle here).
    denoised = imgaussfilt(img, 0.5);

    % ---------------------------------------------------------------
    % 2. ILLUMINATION NORMALIZATION
    % ---------------------------------------------------------------
    % Fundus photos are often brighter in the center (near the flash)
    % and darker at the edges. We estimate this slowly-varying lighting
    % pattern with a heavily-blurred copy of the image, then divide it
    % out - this flattens uneven illumination across the frame.
    gray = im2gray(denoised);
    illuminationEstimate = imgaussfilt(gray, 30);  % large sigma = only slow variations
    illuminationEstimate = max(illuminationEstimate, 0.05); % avoid divide-by-zero
    normFactor = mean(illuminationEstimate(:)) ./ illuminationEstimate;

    normalized = denoised;
    for c = 1:size(denoised, 3)
        normalized(:,:,c) = denoised(:,:,c) .* normFactor;
    end
    normalized = min(max(normalized, 0), 1);  % clip back to valid range

    % ---------------------------------------------------------------
    % 3. CLAHE (Contrast Limited Adaptive Histogram Equalization)
    % ---------------------------------------------------------------
    % Regular contrast enhancement adjusts the whole image uniformly.
    % CLAHE instead enhances contrast in small local regions, which is
    % much better for medical images - it makes subtle lesions (small
    % hemorrhages, exudates) more visible without blowing out bright
    % regions elsewhere in the image.
    if size(normalized, 3) == 3
        % apply CLAHE on the lightness channel only, to avoid distorting colors
        labImg = rgb2lab(normalized);
        L = labImg(:,:,1) / 100;              % normalize L channel to 0-1
        L_eq = adapthisteq(L, 'ClipLimit', 0.01, 'Distribution', 'rayleigh');
        labImg(:,:,1) = L_eq * 100;
        enhancedImg = lab2rgb(labImg);
        enhancedImg = min(max(enhancedImg, 0), 1);
    else
        enhancedImg = adapthisteq(normalized, 'ClipLimit', 0.01);
    end
end
