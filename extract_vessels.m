function [vesselMask, vesselEnhanced] = extract_vessels(imagePath)
% EXTRACT_VESSELS  Extract the retinal blood vessel network from a fundus photo.
%
%   [vesselMask, vesselEnhanced] = extract_vessels(imagePath)
%
% Vessels are thin, dark, curving lines against a brighter background.
% We use morphological top-hat filtering - a classical technique that
% enhances thin structures - with line-shaped structuring elements at
% several rotation angles, since vessels run in many directions and a
% single-orientation filter would miss most of them.
%
% Returns:
%   vesselMask     - binary mask of detected vessels
%   vesselEnhanced - grayscale image with vessel contrast boosted (before thresholding)

    img = imread(imagePath);
    img = im2double(img);

    % The green channel typically shows the highest vessel-to-background
    % contrast in a fundus photo (this is standard practice in retinal
    % image processing - the red channel is often overexposed, and blue
    % is too dark to be useful).
    if size(img, 3) == 3
        greenChannel = img(:, :, 2);
    else
        greenChannel = im2gray(img);
    end

    % Restrict to the retinal field, same as before.
    gray = im2gray(img);
    retinaMask = gray > 0.06;
    retinaMask = imfill(retinaMask, 'holes');

    % Mild pre-blur to suppress JPEG compression block artifacts (subtle
    % 8x8-pixel edges from compression, common in web-sourced photos).
    % Those blocky edges are themselves thin and straight, so the shape
    % filter later can mistake them for vessels - blurring them out
    % first (without erasing true vessels, which are wider) avoids that
    % confusion at the source rather than trying to filter it out after.
    greenChannel = imgaussfilt(greenChannel, 0.8);

    % Vessels are DARKER than the background, so we complement the image
    % first - this turns vessels into bright ridges, which is what the
    % top-hat filter below is designed to enhance.
    inverted = imcomplement(greenChannel);

    % Mild contrast enhancement before filtering makes faint vessels
    % easier to pick up (reuses the same CLAHE idea as enhance_image.m).
    inverted = adapthisteq(inverted, 'ClipLimit', 0.01);

    % --- Multi-orientation top-hat filtering ---
    % A top-hat filter with a LINE structuring element enhances thin
    % structures oriented along that line's angle. Since vessels branch
    % in every direction, we run this at several angles and keep the
    % strongest response at each pixel across all of them.
    angles = 0:15:165;   % 12 orientations, every 15 degrees
    lineLength = 9;       % tune based on expected vessel thickness/scale

    responseStack = zeros([size(inverted), length(angles)]);
    for i = 1:length(angles)
        se = strel('line', lineLength, angles(i));
        responseStack(:, :, i) = imtophat(inverted, se);
    end
    vesselEnhanced = max(responseStack, [], 3);

    % Suppress anything outside the retina before thresholding, so the
    % black border edge doesn't get picked up as a false "vessel."
    vesselEnhanced(~retinaMask) = 0;

    % --- Threshold to get a binary vessel map ---
    % Otsu's method (graythresh) picks a threshold automatically based
    % on the image's own intensity distribution, rather than a fixed
    % guess - more robust across images of varying contrast.
    level = graythresh(vesselEnhanced(retinaMask));
    vesselMask = imbinarize(vesselEnhanced, level * 0.6);  % slightly below
                                                             % Otsu's level,
                                                             % since vessels
                                                             % are thin and
                                                             % easy to under-detect

    % Clean up isolated noise pixels that aren't part of a real vessel.
    vesselMask = bwareaopen(vesselMask, 15);
    vesselMask = vesselMask & retinaMask;

    % --- Shape-based cleanup ---
    % The top-hat filter also responds to texture inside bright lesions
    % (exudates, hemorrhages) - that texture creates small BLOB-shaped
    % noise, whereas real vessel segments are consistently long and thin.
    % Large connected components are trusted by size alone (lesion
    % texture noise doesn't form big connected branching shapes) - the
    % ambiguous cases are the SMALL-to-medium blobs, which must pass a
    % strict elongation (eccentricity) check to survive.
    cc = bwconncomp(vesselMask);
    stats = regionprops(cc, 'Eccentricity', 'Area');

    LARGE_AREA_THRESHOLD = 100;   % big enough to be trusted as real vessel by size alone
    MIN_ECCENTRICITY = 0.90;      % strict elongation requirement for smaller blobs
    MIN_SMALL_AREA = 20;

    keepMask = false(size(vesselMask));
    for i = 1:length(stats)
        isLargeEnough = stats(i).Area >= LARGE_AREA_THRESHOLD;
        isElongatedEnough = stats(i).Eccentricity >= MIN_ECCENTRICITY && ...
                             stats(i).Area >= MIN_SMALL_AREA;
        if isLargeEnough || isElongatedEnough
            keepMask(cc.PixelIdxList{i}) = true;
        end
    end
    vesselMask = keepMask;

    % A very mild closing reconnects vessel segments that got slightly
    % fragmented by the shape filtering above, without adding back the
    % blob-shaped noise we just removed.
    vesselMask = imclose(vesselMask, strel('disk', 1));
end
