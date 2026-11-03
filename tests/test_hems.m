function test_hems()
% Checks of the building model, the scenario and the controllers.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'src'));
p = hems_params();

% The discrete model matches an ODE solver
[Ad, Bd] = hems_model(p, 1);
Q = 1.2;  To = 0;  x0 = [20; 19];
f = @(~, x) [-(1/p.Rim + 1/p.Rea)/p.Ca*x(1) + x(2)/(p.Rim*p.Ca) + (To/p.Rea + Q)/p.Ca;
              (x(1) - x(2))/(p.Rim*p.Cm)];
[~, X] = ode45(f, [0 p.dt], x0, odeset('RelTol', 1e-10, 'AbsTol', 1e-12));
assert(norm(X(end,:)' - (Ad*x0 + Bd*[Q; To])) < 1e-6, 'discretisation mismatch');
disp('ok: discrete model matches ode45');

% The scenario is reproducible and in a sensible range
s1 = generate_scenario(3, 5, p);
s2 = generate_scenario(3, 5, p);
assert(isequal(s1.To, s2.To) && isequal(s1.Ppv, s2.Ppv), 'scenario not reproducible');
assert(all(s1.Ppv >= 0) && all(s1.Pload > 0), 'negative power');
assert(all(s1.price >= 0.12 & s1.price <= 0.60), 'price out of range');
disp('ok: scenario reproducible and in range');

% Power balance and component limits hold in closed loop
sc  = generate_scenario(4, 1, p);
opt = struct('K', 2*96, 'N', 96, 'noisy', false, 'seed', 1);
k = (1:opt.K)';
for ctrl = {'baseline', 'baseline_setback', 'mpc'}
    lg = simulate_hems(ctrl{1}, sc, p, opt);
    residual = lg.Pimp - lg.Pexp - (sc.Pload(k) + lg.Php + lg.Pch - lg.Pdis - sc.Ppv(k));
    assert(max(abs(residual)) < 1e-9, '%s: grid balance violated', ctrl{1});
    assert(all(lg.E >= p.Emin - 1e-9 & lg.E <= p.Emax + 1e-9), '%s: battery window', ctrl{1});
    assert(all(lg.Php >= -1e-9 & lg.Php <= p.Php_max + 1e-9), '%s: heat pump limit', ctrl{1});
    assert(lg.nFail == 0, '%s: LP failures', ctrl{1});
end
disp('ok: power balance and limits hold');

% With an exact model and forecast the MPC stays inside the comfort band
pExact = p;
pExact.plantLossFactor = 1;
pExact.mpcMargin = 0;
lgExact = simulate_hems('mpc', sc, pExact, opt);
mExact = compute_metrics(lgExact, sc, pExact);
assert(mExact.max_violation_K < 0.05, 'comfort band violated by %.2f K', mExact.max_violation_K);
disp('ok: comfort band respected with an exact model');

% With a perfect forecast the MPC is cheaper than the setback thermostat
mb = compute_metrics(simulate_hems('baseline_setback', sc, p, opt), sc, p);
mm = compute_metrics(simulate_hems('mpc', sc, p, opt), sc, p);
fprintf('2 day cost: thermostat %.2f EUR/day, MPC %.2f EUR/day\n', ...
        mb.cost_eur_per_day, mm.cost_eur_per_day);
assert(mm.cost_eur_per_day < mb.cost_eur_per_day, 'MPC not cheaper than the thermostat');
disp('ok: MPC cheaper than the thermostat');
end
