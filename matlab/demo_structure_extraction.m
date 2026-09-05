%% DEMO: Retinal Structure Extraction (Optic Disc + Vessels)
% Runs optic disc localization and vessel extraction on a fundus image
% and displays the results side by side.
%
% HOW TO USE:
%   1. Make sure locate_optic_disc.m and extract_vessels.m are uploaded.
%   2. Edit imagePath below to point at one of your test images
%      (clear_eye.jpg or dr_eye.jpg work well - use a genuinely sharp
%      image, since structure detection needs real detail to work with).
%   3. Click Run.

imagePath = 'dr_eye.jpg';   % <-- change to your actual uploaded filename

if ~isfile(imagePath)
    error('File not found: %s. Upload it first or fix the filename.', imagePath);
end

fprintf('Locating optic disc in %s...\n', imagePath);
[discCenter, discRadius, discMask] = locate_optic_disc(imagePath);

if any(isnan(discCenter))
    fprintf('Optic disc not confidently located.\n');
else
    fprintf('Optic disc found at (x=%.0f, y=%.0f), radius ~%.0f px\n', ...
        discCenter(1), discCenter(2), discRadius);
end

fprintf('Extracting vessel network...\n');
[vesselMask, vesselEnhanced] = extract_vessels(imagePath);
vesselPixelPercent = 100 * sum(vesselMask(:)) / numel(vesselMask);
fprintf('Vessel pixels: %.1f%% of image area\n', vesselPixelPercent);

%% Display results
originalImg = imread(imagePath);

figure('Name', 'Structure Extraction', 'Position', [100 100 1200 350]);

subplot(1, 4, 1);
imshow(originalImg);
title('Original');

subplot(1, 4, 2);
imshow(originalImg);
hold on;
if ~any(isnan(discCenter))
    viscircles(discCenter, discRadius, 'Color', 'r', 'LineWidth', 2);
end
hold off;
title('Optic Disc (outlined)');

subplot(1, 4, 3);
imshow(vesselEnhanced, []);
title('Vessel Enhancement (pre-threshold)');

subplot(1, 4, 4);
imshow(vesselMask);
title('Vessel Mask (binary)');

% Combined overlay - useful for a presentation slide
figure('Name', 'Combined Overlay', 'Position', [100 500 500 500]);
imshow(originalImg);
hold on;
if ~any(isnan(discCenter))
    viscircles(discCenter, discRadius, 'Color', 'r', 'LineWidth', 2);
end
[vy, vx] = find(vesselMask);
scatter(vx, vy, 1, 'g', 'filled', 'MarkerFaceAlpha', 0.3);
hold off;
title('Optic Disc + Vessel Overlay');
