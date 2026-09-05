function [discCenter, discRadius, discMask] = locate_optic_disc(imagePath)
% LOCATE_OPTIC_DISC  Find the optic disc in a fundus photo.
%
%   [discCenter, discRadius, discMask] = locate_optic_disc(imagePath)
%
% The optic disc is where the vessels converge and enter the eye - it's
% normally the brightest, most yellowish-white circular region in a
% fundus photo. We exploit exactly that: find the brightest region, then
% use a Circle Hough Transform (a classical technique for detecting
% circular shapes) to fit a circle to it.
%
% Returns:
%   discCenter - [x, y] pixel coordinates of the disc center
%   discRadius - estimated radius in pixels
%   discMask   - binary mask of the disc region (for visualization)

    img = imread(imagePath);
    img = im2double(img);

    % The optic disc is brightest in the red/green channels combined -
    % using just the grayscale/luminance version works well here.
    gray = im2gray(img);

    % Restrict search to inside the retinal field (reuse the same idea
    % as the quality-check function - ignore black background).
    retinaMask = gray > 0.06;
    retinaMask = imfill(retinaMask, 'holes');

    % --- Step 1: find candidate bright region ---
    % The optic disc is typically among the top ~2% brightest pixels
    % within the retina. This is a coarse first guess before refining
    % with the Hough transform below.
    retinaPixelValues = gray(retinaMask);
    brightnessThreshold = quantile(retinaPixelValues, 0.98);
    brightMask = (gray >= brightnessThreshold) & retinaMask;

    % Clean up small noisy bright spots (e.g. reflections, small
    % exudates) - the real disc is a reasonably large connected blob.
    brightMask = bwareaopen(brightMask, 50);
    brightMask = imclose(brightMask, strel('disk', 5));

    % --- Step 2: Circle Hough Transform on the bright region ---
    % imfindcircles looks for circular shapes within a radius range.
    % We estimate a sensible radius range as a fraction of the retina's
    % own size, since the optic disc is a fairly consistent proportion
    % of the visible retina across images.
    retinaDiameter = sqrt(sum(retinaMask(:)) / pi) * 2;
    minRadius = max(round(retinaDiameter * 0.03), 5);
    maxRadius = max(round(retinaDiameter * 0.12), minRadius + 5);

    [centers, radii] = imfindcircles(brightMask, [minRadius maxRadius], ...
        'ObjectPolarity', 'bright', 'Sensitivity', 0.9);

    if isempty(centers)
        % Fallback: if the Hough transform doesn't find a clean circle,
        % just use the centroid of the largest bright blob instead.
        stats = regionprops(brightMask, 'Centroid', 'EquivDiameter', 'Area');
        if isempty(stats)
            warning('locate_optic_disc:notFound', ...
                'Could not locate optic disc in %s', imagePath);
            discCenter = [NaN NaN];
            discRadius = NaN;
            discMask = false(size(gray));
            return;
        end
        [~, idx] = max([stats.Area]);
        discCenter = stats(idx).Centroid;
        discRadius = stats(idx).EquivDiameter / 2;
    else
        % Take the strongest (first-ranked) detected circle.
        discCenter = centers(1, :);
        discRadius = radii(1);
    end

    % Build a mask for visualization/overlay purposes.
    [xx, yy] = meshgrid(1:size(gray, 2), 1:size(gray, 1));
    discMask = ((xx - discCenter(1)).^2 + (yy - discCenter(2)).^2) <= discRadius^2;
end
