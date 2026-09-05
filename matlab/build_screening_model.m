%% BUILD_SCREENING_MODEL
% Builds a Simulink model of the district-level DR screening workflow:
% patient images arriving for screening vs. ophthalmologist review
% capacity, to check whether a given staffing level can sustain
% 100,000+ patients/year without an ever-growing backlog.
%
% HOW TO USE:
%   1. Edit the PARAMETERS section below to match your target scenario.
%   2. Click Run (or press F5).
%   3. A Simulink model window will open automatically, already wired up.
%   4. Inside that window, click the black "Run" triangle (in the
%      Simulink toolbar, not this script) to simulate it.
%   5. Double-click the "Backlog Scope" block to see the results plotted.

modelName = 'DR_Screening_Workflow';

% Close any previous version of this model so we start clean
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
new_system(modelName);
open_system(modelName);

%% ---------------- PARAMETERS (edit these to explore scenarios) ----------------
patientsPerYear = 100000;
operatingDaysPerYear = 300;    % accounts for weekends/holidays
hoursPerOperatingDay = 8;

numOphthalmologists = 3;
reviewsPerDoctorPerHour = 60;  % ~1/minute, consistent with the <30s
                                 % review target from the explainability
                                 % module leaving room for edge cases

% --- Derived rates (images per hour) ---
arrivalRatePerHour = patientsPerYear / operatingDaysPerYear / hoursPerOperatingDay;
reviewCapacityPerHour = numOphthalmologists * reviewsPerDoctorPerHour;

fprintf('Patient arrival rate:   %.1f images/hour\n', arrivalRatePerHour);
fprintf('Review capacity:        %.1f images/hour (%d doctors x %d/hr each)\n', ...
    reviewCapacityPerHour, numOphthalmologists, reviewsPerDoctorPerHour);

if arrivalRatePerHour > reviewCapacityPerHour
    fprintf(['WARNING: arrival rate exceeds review capacity - backlog will\n' ...
             'grow without bound. Increase numOphthalmologists above and re-run.\n']);
else
    fprintf('Review capacity meets demand at steady state.\n');
end

%% ---------------- BUILD THE MODEL ----------------

% Block 1: patient images arriving per hour
add_block('simulink/Sources/Constant', [modelName '/Patient Arrival Rate'], ...
    'Value', num2str(arrivalRatePerHour), ...
    'Position', [40 40 180 80]);

% Block 2: how many images the review team can process per hour
add_block('simulink/Sources/Constant', [modelName '/Review Capacity'], ...
    'Value', num2str(reviewCapacityPerHour), ...
    'Position', [40 160 180 200]);

% Block 3: net rate = arrivals minus reviews processed
add_block('simulink/Math Operations/Sum', [modelName '/Net Rate'], ...
    'Inputs', '+-', ...
    'Position', [260 100 300 150]);

% Block 4: backlog accumulates the net rate over time (this is the
% running total of "images waiting for a doctor to review")
add_block('simulink/Continuous/Integrator', [modelName '/Backlog Queue'], ...
    'Position', [360 100 410 150]);

% Block 5: backlog can't go below zero (you can't have "negative"
% unreviewed images waiting)
add_block('simulink/Discontinuities/Saturation', [modelName '/Clip At Zero'], ...
    'LowerLimit', '0', 'UpperLimit', 'inf', ...
    'Position', [460 100 510 150]);

% Block 6: visualize the backlog over time
add_block('simulink/Sinks/Scope', [modelName '/Backlog Scope'], ...
    'Position', [570 100 610 150]);

%% ---------------- WIRE THE BLOCKS TOGETHER ----------------
add_line(modelName, 'Patient Arrival Rate/1', 'Net Rate/1');
add_line(modelName, 'Review Capacity/1', 'Net Rate/2');
add_line(modelName, 'Net Rate/1', 'Backlog Queue/1');
add_line(modelName, 'Backlog Queue/1', 'Clip At Zero/1');
add_line(modelName, 'Clip At Zero/1', 'Backlog Scope/1');

%% ---------------- SIMULATION SETTINGS ----------------
simHours = 24 * 30;   % simulate 30 days of continuous operation
set_param(modelName, 'StopTime', num2str(simHours));

save_system(modelName);
fprintf('\nModel built and saved as %s.slx\n', modelName);
fprintf('Simulation window should now be open. Click the Run button inside it,\n');
fprintf('then double-click "Backlog Scope" to see the result.\n');
