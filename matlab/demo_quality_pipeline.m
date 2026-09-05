%% DEMO: Image Quality Assessment and Enhancement Pipeline
% This script runs the full pipeline on one or more fundus images:
%   1. Assess quality (focus, illumination, field of view)
%   2. If borderline -> enhance (CLAHE, illumination norm, denoise)
%   3. If ungradable -> reject with specific feedback
%
% HOW TO USE:
%   1. Upload a few fundus images to MATLAB Online (drag into the file
%      browser panel on the left, or use the Upload button).
%   2. Edit the imageFiles list below to match your uploaded filenames.
%   3. Click Run (the green triangle) or press F5.

imageFiles = {
    'sample1.png'   % <-- replace with your actual uploaded filenames
    'sample2.png'
};

for i = 1:length(imageFiles)
    imgPath = imageFiles{i};

    if ~isfile(imgPath)
        fprintf('Skipping %s - file not found. Upload it first.\n', imgPath);
        continue;
    end

    fprintf('\n========================================\n');
    fprintf('Assessing: %s\n', imgPath);
    fprintf('========================================\n');

    report = assess_image_quality(imgPath);

    fprintf('Focus score:        %.5f  [%s]\n', report.focusScore, passFailStr(report.focusPass));
    fprintf('Mean brightness:     %.3f  [%s]\n', report.meanBrightness, passFailStr(report.illuminationPass));
    fprintf('Retina field frac:  %.3f  [%s]\n', report.retinaFraction, passFailStr(report.fovPass));
    fprintf('Overall gradable:   %d\n', report.gradable);
    fprintf('Borderline:         %d\n', report.borderline);
    fprintf('Feedback: %s\n', strjoin(report.feedback, ' | '));

    originalImg = imread(imgPath);

    figure('Name', imgPath, 'Position', [100 100 900 400]);

    subplot(1,2,1);
    imshow(originalImg);
    title('Original');

    if ~report.gradable
        % Ungradable - show rejection, don't waste time enhancing
        subplot(1,2,2);
        imshow(zeros(size(originalImg)));
        title('REJECTED - see feedback in console', 'Color', 'r');
    elseif report.borderline
        % Borderline - apply enhancement and show the improved version
        enhanced = enhance_image(imgPath);
        subplot(1,2,2);
        imshow(enhanced);
        title('Enhanced (CLAHE + illumination norm)');
    else
        % Already good quality - no enhancement needed
        subplot(1,2,2);
        imshow(originalImg);
        title('Passed - no enhancement needed');
    end
end

function s = passFailStr(passed)
    if passed
        s = 'PASS';
    else
        s = 'FAIL';
    end
end
