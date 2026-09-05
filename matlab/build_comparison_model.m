%% BUILD_COMPARISON_MODEL
% Compares two review scenarios under the SAME patient arrival rate:
%   - "AI-Assisted": fast review enabled by the explainability module
%     (heatmap + report lets a doctor validate in under 30 seconds)
%   - "Manual": slower traditional review without that assistance
%
% This directly connects requirement #4 (explainability enabling fast
% review) to requirement #5 (resource allocation) - showing that the
% SAME number of doctors can handle the target patient volume only
% because of the faster AI-assisted review speed.
%
% HOW TO USE: same as build_screening_model.m - edit parameters, Run
% this script, then click Run inside the Simulink window that opens,
% then double-click "Comparison Scope" to see both backlog lines
% plotted together.

modelName = 'DR_Screening_Comparison';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
new_system(modelName);
open_system(modelName);

%% ---------------- PARAMETERS ----------------
patientsPerYear = 100000;
operatingDaysPerYear = 300;
hoursPerOperatingDay = 8;

numOphthalmologists = 1;   % deliberately low, to make the contrast visible

reviewsPerDoctorPerHour_AI = 60;      % ~1/minute, with the explainability module
reviewsPerDoctorPerHour_Manual = 6;   % ~10 minutes/image, without it (assumption -
                                        % state this as an estimate in your pitch,
                                        % not a measured clinical figure)

arrivalRatePerHour = patientsPerYear / operatingDaysPerYear / hoursPerOperatingDay;
capacityAI = numOphthalmologists * reviewsPerDoctorPerHour_AI;
capacityManual = numOphthalmologists * reviewsPerDoctorPerHour_Manual;

fprintf('Patient arrival rate:        %.1f images/hour\n', arrivalRatePerHour);
fprintf('AI-assisted review capacity: %.1f images/hour (%d doctor x %d/hr)\n', ...
    capacityAI, numOphthalmologists, reviewsPerDoctorPerHour_AI);
fprintf('Manual review capacity:      %.1f images/hour (%d doctor x %d/hr)\n', ...
    capacityManual, numOphthalmologists, reviewsPerDoctorPerHour_Manual);

if capacityAI >= arrivalRatePerHour
    fprintf('-> AI-assisted: capacity meets demand, backlog should stay near zero.\n');
else
    fprintf('-> AI-assisted: capacity is NOT sufficient at this staffing level.\n');
end
if capacityManual >= arrivalRatePerHour
    fprintf('-> Manual: capacity meets demand, backlog should stay near zero.\n');
else
    fprintf('-> Manual: capacity is NOT sufficient - backlog will grow.\n');
end

%% ---------------- BUILD THE MODEL ----------------

add_block('simulink/Sources/Constant', [modelName '/Patient Arrival Rate'], ...
    'Value', num2str(arrivalRatePerHour), 'Position', [40 130 180 170]);

add_block('simulink/Sources/Constant', [modelName '/AI-Assisted Capacity'], ...
    'Value', num2str(capacityAI), 'Position', [40 30 200 70]);

add_block('simulink/Sources/Constant', [modelName '/Manual Capacity'], ...
    'Value', num2str(capacityManual), 'Position', [40 230 200 270]);

add_block('simulink/Math Operations/Sum', [modelName '/Net Rate AI'], ...
    'Inputs', '+-', 'Position', [260 60 300 110]);

add_block('simulink/Math Operations/Sum', [modelName '/Net Rate Manual'], ...
    'Inputs', '+-', 'Position', [260 190 300 240]);

add_block('simulink/Continuous/Integrator', [modelName '/Backlog AI'], ...
    'Position', [360 60 410 110]);

add_block('simulink/Continuous/Integrator', [modelName '/Backlog Manual'], ...
    'Position', [360 190 410 240]);

add_block('simulink/Discontinuities/Saturation', [modelName '/Clip AI'], ...
    'LowerLimit', '0', 'UpperLimit', 'inf', 'Position', [460 60 510 110]);

add_block('simulink/Discontinuities/Saturation', [modelName '/Clip Manual'], ...
    'LowerLimit', '0', 'UpperLimit', 'inf', 'Position', [460 190 510 240]);

add_block('simulink/Signal Routing/Mux', [modelName '/Comparison Mux'], ...
    'Inputs', '2', 'Position', [570 100 590 200]);

add_block('simulink/Sinks/Scope', [modelName '/Comparison Scope'], ...
    'Position', [650 130 690 170]);

%% ---------------- WIRE THE BLOCKS TOGETHER ----------------
add_line(modelName, 'Patient Arrival Rate/1', 'Net Rate AI/1');
add_line(modelName, 'Patient Arrival Rate/1', 'Net Rate Manual/1');
add_line(modelName, 'AI-Assisted Capacity/1', 'Net Rate AI/2');
add_line(modelName, 'Manual Capacity/1', 'Net Rate Manual/2');

add_line(modelName, 'Net Rate AI/1', 'Backlog AI/1');
add_line(modelName, 'Net Rate Manual/1', 'Backlog Manual/1');

add_line(modelName, 'Backlog AI/1', 'Clip AI/1');
add_line(modelName, 'Backlog Manual/1', 'Clip Manual/1');

add_line(modelName, 'Clip AI/1', 'Comparison Mux/1');
add_line(modelName, 'Clip Manual/1', 'Comparison Mux/2');

add_line(modelName, 'Comparison Mux/1', 'Comparison Scope/1');

%% ---------------- SIMULATION SETTINGS ----------------
simHours = 24 * 30;   % simulate 30 days
set_param(modelName, 'StopTime', num2str(simHours));

save_system(modelName);
fprintf('\nModel built and saved as %s.slx\n', modelName);
fprintf('Click Run inside the Simulink window, then double-click "Comparison Scope".\n');
fprintf('You should see TWO lines: one flat (AI-assisted), one climbing (manual).\n');
