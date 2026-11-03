function run_study()
% 14 day simulation study of thermostat baselines and the MPC.
% Writes results/summary.csv, results/tables.md and results/figures/*.png.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));
figDir = fullfile(here, 'results', 'figures');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

p = hems_params();
nDays = 14;
opt.K = nDays * round(24 / p.dt);
sc = generate_scenario(nDays + 2, 1, p);       % two extra days for the longest horizon

cases = define_cases(p);
nCases = size(cases, 1);
metrics = cell(nCases, 1);
logs = cell(nCases, 1);
for i = 1:nCases
    o = struct('K', opt.K, 'N', cases{i,3}, 'noisy', cases{i,4}, 'seed', cases{i,5});
    logs{i} = simulate_hems(cases{i,2}, sc, cases{i,6}, o);
    metrics{i} = compute_metrics(logs{i}, sc, cases{i,6});
    fprintf('%-52s %6.3f EUR/day\n', cases{i,1}, metrics{i}.cost_eur_per_day);
end

T = struct2table([metrics{:}]');
T = addvars(T, string(cases(:,1)), 'Before', 1, 'NewVariableNames', 'name');
refIdx = cellfun(@(r) find(strcmp(cases(:,1), r)), cases(:,7));
T.saving_pct = 100 * (T.cost_eur_per_day(refIdx) - T.cost_eur_per_day) ./ T.cost_eur_per_day(refIdx);
writetable(T, fullfile(here, 'results', 'summary.csv'));
write_tables(T, fullfile(here, 'results', 'tables.md'), cases(:,1), cases(:,7), nDays);

make_figures(sc, p, T, logs, cases(:,1), figDir);
disp('done');
end


function cases = define_cases(p)
% name, controller, horizon in steps, noisy forecast, seed, parameters, reference case
ref = 'Thermostat, night setback';
cases = {
    'Thermostat, constant setpoint',                'baseline',         0, false, 0, p, ref
    ref,                                            'baseline_setback', 0, false, 0, p, ref
    'MPC 24 h, perfect forecast',                   'mpc',             96, false, 1, p, ref
    'MPC 24 h, noisy forecast, seed 7',             'mpc',             96, true,  7, p, ref
    'MPC 24 h, noisy forecast, seed 8',             'mpc',             96, true,  8, p, ref
    'MPC 24 h, noisy forecast, seed 9',             'mpc',             96, true,  9, p, ref
    'MPC 6 h, noisy forecast, seed 7',              'mpc',             24, true,  7, p, ref
    'MPC 12 h, noisy forecast, seed 7',             'mpc',             48, true,  7, p, ref
    'MPC 36 h, noisy forecast, seed 7',             'mpc',            144, true,  7, p, ref};

pNoBattery = p;
pNoBattery.Pb_max = 0;
refNB = 'No battery: thermostat, night setback';
cases(end+1,:) = {refNB, 'baseline_setback', 0, false, 0, pNoBattery, refNB};
cases(end+1,:) = {'No battery: MPC 24 h, noisy forecast, seed 7', 'mpc', 96, true, 7, pNoBattery, refNB};

for m = [0 0.5 1]
    pm = p;
    pm.mpcMargin = m;
    cases(end+1,:) = {sprintf('Margin %.1f K: MPC 24 h, noisy forecast, seed 7', m), ...
                      'mpc', 96, true, 7, pm, ref};
end

for c = [0.05 0.10]
    pc = p;
    pc.c_deg = c;
    refC = sprintf('Wear cost %.2f: thermostat, night setback', c);
    cases(end+1,:) = {refC, 'baseline_setback', 0, false, 0, pc, refC};
    cases(end+1,:) = {sprintf('Wear cost %.2f: MPC 24 h, noisy forecast, seed 7', c), ...
                      'mpc', 96, true, 7, pc, refC};
end
end


function write_tables(T, file, names, refs, nDays)
fid = fopen(file, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Simulation of %d days, synthetic scenario. Saving is relative to the reference case of each table.\n\n', nDays);

section(fid, T, 'Main results', { ...
    'Thermostat, constant setpoint', 'Thermostat, night setback', ...
    'MPC 24 h, perfect forecast', 'MPC 24 h, noisy forecast, seed 7', ...
    'MPC 24 h, noisy forecast, seed 8', 'MPC 24 h, noisy forecast, seed 9'}, names, refs);
section(fid, T, 'Without battery', { ...
    'No battery: thermostat, night setback', ...
    'No battery: MPC 24 h, noisy forecast, seed 7'}, names, refs);
section(fid, T, 'Prediction horizon', { ...
    'MPC 6 h, noisy forecast, seed 7', 'MPC 12 h, noisy forecast, seed 7', ...
    'MPC 24 h, noisy forecast, seed 7', 'MPC 36 h, noisy forecast, seed 7'}, names, refs);
section(fid, T, 'Comfort margin of the MPC (the main runs use 0.3 K)', { ...
    'Margin 0.0 K: MPC 24 h, noisy forecast, seed 7', ...
    'MPC 24 h, noisy forecast, seed 7', ...
    'Margin 0.5 K: MPC 24 h, noisy forecast, seed 7', ...
    'Margin 1.0 K: MPC 24 h, noisy forecast, seed 7'}, names, refs);
section(fid, T, 'Battery wear cost (EUR per kWh of throughput)', { ...
    'Thermostat, night setback', 'MPC 24 h, noisy forecast, seed 7', ...
    'Wear cost 0.05: thermostat, night setback', 'Wear cost 0.05: MPC 24 h, noisy forecast, seed 7', ...
    'Wear cost 0.10: thermostat, night setback', 'Wear cost 0.10: MPC 24 h, noisy forecast, seed 7'}, names, refs);
end


function section(fid, T, title, rows, names, refs)
fprintf(fid, '### %s\n\n', title);
fprintf(fid, '| Case | Cost [EUR/day] | Saving [%%] | Comfort violation [K h] | Max violation [K] | Battery cycles | Solve time [ms] |\n');
fprintf(fid, '|---|---|---|---|---|---|---|\n');
for n = 1:numel(rows)
    i = find(T.name == rows{n});
    if strcmp(refs{strcmp(names, rows{n})}, rows{n})
        saving = '-';
    else
        saving = sprintf('%.1f', T.saving_pct(i));
    end
    if isnan(T.solve_ms_mean(i))
        solve = '-';
    else
        solve = sprintf('%.0f', T.solve_ms_mean(i));
    end
    fprintf(fid, '| %s | %.2f | %s | %.2f | %.2f | %.1f | %s |\n', rows{n}, ...
        T.cost_eur_per_day(i), saving, T.comfort_violation_Kh(i), ...
        T.max_violation_K(i), T.battery_cycles(i), solve);
end
fprintf(fid, '\n');
end


function make_figures(sc, p, T, logs, names, figDir)
blue = [0.20 0.40 0.65];
orange = [0.85 0.40 0.10];
grey = [0.45 0.45 0.45];
idx = @(name) find(strcmp(names, name));
row = @(name) T(T.name == name, :);

r = (3*96 + 1):(7*96);
t = (r - 1) * p.dt / 24;

% Scenario
fig = new_figure(900, 700);
tiledlayout(3, 1, 'TileSpacing', 'compact');
nexttile; plot(t, sc.To(r), 'Color', blue); ylabel('Outside [\circC]'); grid on;
title('Synthetic scenario, four days');
nexttile; plot(t, sc.Ppv(r), 'Color', orange); hold on; plot(t, sc.Pload(r), 'Color', blue);
ylabel('Power [kW]'); legend('PV', 'Household load', 'Location', 'northeast'); grid on;
nexttile; stairs(t, sc.price(r), 'Color', blue); ylabel('Price [EUR/kWh]');
xlabel('Time [days]'); grid on;
save_figure(fig, fullfile(figDir, 'scenario.png'));

% Thermostat with setback versus MPC
a = logs{idx('Thermostat, night setback')};
b = logs{idx('MPC 24 h, noisy forecast, seed 7')};
fig = new_figure(900, 900);
tiledlayout(4, 1, 'TileSpacing', 'compact');
nexttile; stairs(t, sc.price(r), 'Color', grey); ylabel('Price [EUR/kWh]'); grid on;
title('Thermostat with night setback and MPC, four days');
nexttile; plot(t, a.Ti(r), 'Color', blue); hold on; plot(t, b.Ti(r), 'Color', orange);
stairs(t, sc.Tlo(r), ':k'); stairs(t, sc.Thi(r), ':k');
ylabel('Indoor [\circC]'); grid on;
legend('Thermostat', 'MPC', 'Comfort band', 'Orientation', 'horizontal', 'Location', 'southoutside');
nexttile; stairs(t, a.Php(r), 'Color', blue); hold on; stairs(t, b.Php(r), 'Color', orange);
ylabel('Heat pump [kW]'); grid on;
nexttile; plot(t, a.E(r), 'Color', blue); hold on; plot(t, b.E(r), 'Color', orange);
ylabel('Battery [kWh]'); xlabel('Time [days]'); grid on;
save_figure(fig, fullfile(figDir, 'thermostat_vs_mpc.png'));

% Cost per day
labels = {'Thermostat, constant setpoint', 'Thermostat, night setback', ...
          'MPC 24 h, noisy forecast, seed 7', ...
          'No battery: thermostat, night setback', ...
          'No battery: MPC 24 h, noisy forecast, seed 7'};
short = {'Thermostat, constant', 'Thermostat, setback', 'MPC', ...
         'No battery: thermostat, setback', 'No battery: MPC'};
cost = arrayfun(@(n) row(labels{n}).cost_eur_per_day, 1:numel(labels));
fig = new_figure(800, 380);
h = barh(flipud(cost(:)), 0.6);
h.FaceColor = 'flat';
cols = [grey; blue; orange; blue; orange];
h.CData = flipud(cols);
set(gca, 'YTickLabel', flipud(short(:)), 'YTick', 1:numel(labels));
for n = 1:numel(cost)
    text(cost(numel(cost) + 1 - n) + 0.05, n, sprintf('%.2f', cost(numel(cost) + 1 - n)), ...
         'VerticalAlignment', 'middle');
end
xlabel('Cost [EUR/day]'); xlim([0 max(cost) * 1.15]); grid on;
title('Daily cost, 14 days');
save_figure(fig, fullfile(figDir, 'cost_per_day.png'));

% Horizon
hz = [6 12 24 36];
hn = {'MPC 6 h, noisy forecast, seed 7', 'MPC 12 h, noisy forecast, seed 7', ...
      'MPC 24 h, noisy forecast, seed 7', 'MPC 36 h, noisy forecast, seed 7'};
sav = arrayfun(@(n) row(hn{n}).saving_pct, 1:4);
ms  = arrayfun(@(n) row(hn{n}).solve_ms_mean, 1:4);
fig = new_figure(800, 400);
yyaxis left; plot(hz, sav, '-o', 'Color', orange, 'LineWidth', 1.5); ylabel('Saving vs thermostat [%]');
yyaxis right; plot(hz, ms, '-s', 'Color', blue, 'LineWidth', 1.5); ylabel('Mean solve time [ms]');
xlabel('Prediction horizon [h]'); xticks(hz); grid on;
title('Effect of the prediction horizon');
ax = gca; ax.YAxis(1).Color = orange; ax.YAxis(2).Color = blue;
save_figure(fig, fullfile(figDir, 'horizon.png'));

% Comfort margin
wn = {'Margin 0.0 K: MPC 24 h, noisy forecast, seed 7', ...
      'MPC 24 h, noisy forecast, seed 7', ...
      'Margin 0.5 K: MPC 24 h, noisy forecast, seed 7', ...
      'Margin 1.0 K: MPC 24 h, noisy forecast, seed 7'};
wv = [0 0.3 0.5 1];
cv = arrayfun(@(n) row(wn{n}).comfort_violation_Kh, 1:4);
cc = arrayfun(@(n) row(wn{n}).cost_eur_per_day, 1:4);
th = row('Thermostat, night setback');
fig = new_figure(800, 420);
plot(cv, cc, '-o', 'Color', orange, 'LineWidth', 1.5); hold on;
plot(th.comfort_violation_Kh, th.cost_eur_per_day, 's', 'Color', blue, 'MarkerFaceColor', blue);
for n = 1:4
    text(cv(n) + 0.15, cc(n) + 0.02, sprintf('margin %g K', wv(n)));
end
text(th.comfort_violation_Kh + 0.15, th.cost_eur_per_day, 'Thermostat');
ylim([min(cc) - 0.2, th.cost_eur_per_day + 0.3]);
xlabel('Comfort violation over 14 days [K h]'); ylabel('Cost [EUR/day]');
title('Cost against comfort for different MPC safety margins'); grid on;
save_figure(fig, fullfile(figDir, 'comfort_tradeoff.png'));

% Battery wear cost
cw = [0.02 0.05 0.10];
mn = {'MPC 24 h, noisy forecast, seed 7', 'Wear cost 0.05: MPC 24 h, noisy forecast, seed 7', ...
      'Wear cost 0.10: MPC 24 h, noisy forecast, seed 7'};
sv = arrayfun(@(n) row(mn{n}).saving_pct, 1:3);
cy = arrayfun(@(n) row(mn{n}).battery_cycles, 1:3);
fig = new_figure(800, 400);
tiledlayout(1, 2, 'TileSpacing', 'compact');
nexttile; plot(cw, sv, '-o', 'Color', orange, 'LineWidth', 1.5);
xlabel('Wear cost [EUR/kWh]'); ylabel('Saving vs thermostat [%]'); grid on; xticks(cw);
nexttile; plot(cw, cy, '-o', 'Color', blue, 'LineWidth', 1.5);
xlabel('Wear cost [EUR/kWh]'); ylabel('MPC battery cycles in 14 days'); grid on; xticks(cw);
save_figure(fig, fullfile(figDir, 'battery_wear.png'));
end


function fig = new_figure(w, h)
fig = figure('Visible', 'off', 'Position', [100 100 w h]);
try
    theme(fig, 'light');
catch
    set(fig, 'Color', 'w');
end
end


function save_figure(fig, file)
exportgraphics(fig, file, 'Resolution', 200);
close(fig);
end
