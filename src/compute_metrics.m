function m = compute_metrics(lg, sc, p)
% Cost, comfort and battery figures of one simulation run.
K = numel(lg.Php);
k = (1:K)';
dt = p.dt;
days = K * dt / 24;

gridCost = dt * sum(sc.price(k) .* lg.Pimp - p.fit * lg.Pexp);
wearCost = p.c_deg * dt * sum(lg.Pch + lg.Pdis);
dE = lg.E_end - p.E0;

% Energy left in the battery is valued like in the MPC, so draining it is not rewarded
m.cost_eur_per_day = (gridCost + wearCost - p.vterm * dE) / days;

m.import_kWh = dt * sum(lg.Pimp);
m.export_kWh = dt * sum(lg.Pexp);
m.heat_pump_kWh = dt * sum(lg.Php);

violation = max(0, sc.Tlo(k) - lg.Ti) + max(0, lg.Ti - sc.Thi(k));
m.comfort_violation_Kh = dt * sum(violation);
m.max_violation_K = max(violation);
m.battery_cycles = dt * sum(lg.Pdis) / (p.Emax - p.Emin);

m.solve_ms_mean = 1000 * mean(lg.solveTime, 'omitnan');
m.solve_ms_max = 1000 * max(lg.solveTime, [], 'omitnan');
m.lp_failures = lg.nFail;
end
