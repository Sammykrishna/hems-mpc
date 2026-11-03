function lg = simulate_hems(ctrl, sc, p, opt)
% Closed-loop simulation of the house.
%   ctrl  'baseline', 'baseline_setback' or 'mpc'
%   opt.K      number of 15 min steps
%   opt.N      MPC horizon in steps
%   opt.noisy  true: the MPC gets erroneous forecasts
%   opt.seed   seed of the forecast errors
% The simulated house loses plantLossFactor times more heat than the model
% inside the MPC. The MPC measures [Ti; Tm; E] exactly.
K = opt.K;
[Adn, Bdn] = hems_model(p, 1);
[Adt, Bdt] = hems_model(p, p.plantLossFactor);

x = p.x0;
E = p.E0;
rs = RandStream('mt19937ar', 'Seed', opt.seed);
solverOpts = optimoptions('linprog', 'Algorithm', 'dual-simplex-highs', 'Display', 'off');

Ti = zeros(K, 1);  Tm = Ti;  Ek = Ti;
Php = Ti;  Pch = Ti;  Pdis = Ti;  Pimp = Ti;  Pexp = Ti;
solveTime = nan(K, 1);
nFail = 0;

for k = 1:K
    Ti(k) = x(1);  Tm(k) = x(2);  Ek(k) = E;

    switch ctrl
        case 'baseline'
            [Php_k, Pch_k, Pdis_k] = thermostat_action(sc, p, k, x, E, p.Tset_base);
        case 'baseline_setback'
            h = sc.h(k);
            if h >= p.setbackStart || h < p.setbackEnd
                Tset = p.Tset_night;
            else
                Tset = p.Tset_base;
            end
            [Php_k, Pch_k, Pdis_k] = thermostat_action(sc, p, k, x, E, Tset);
        case 'mpc'
            fc = make_forecast(sc, p, k, opt.N, opt.noisy, rs);
            [lp, ix] = build_mpc_lp(p, Adn, Bdn, x, E, fc);
            t0 = tic;
            [z, ~, flag] = linprog(lp.f, lp.A, lp.b, lp.Aeq, lp.beq, lp.lb, lp.ub, solverOpts);
            solveTime(k) = toc(t0);
            if flag == 1
                Php_k = z(ix.Php + 1);
                Pch_k = z(ix.Pch + 1);
                Pdis_k = z(ix.Pdis + 1);
            else
                nFail = nFail + 1;
                [Php_k, Pch_k, Pdis_k] = thermostat_action(sc, p, k, x, E, p.Tset_base);
            end
        otherwise
            error('Unknown controller: %s', ctrl);
    end

    Pch_k  = min(Pch_k,  (p.Emax - E) / (p.dt * p.eta_c));
    Pdis_k = min(Pdis_k, (E - p.Emin) * p.eta_d / p.dt);

    net = sc.Pload(k) + Php_k + Pch_k - Pdis_k - sc.Ppv(k);
    Php(k) = Php_k;  Pch(k) = Pch_k;  Pdis(k) = Pdis_k;
    Pimp(k) = max(net, 0);
    Pexp(k) = max(-net, 0);

    x = Adt * x + Bdt * [p.cop(sc.To(k)) * Php_k; sc.To(k)];
    E = E + p.dt * (p.eta_c * Pch_k - Pdis_k / p.eta_d);
end

lg = struct('Ti', Ti, 'Tm', Tm, 'E', Ek, 'Php', Php, 'Pch', Pch, 'Pdis', Pdis, ...
            'Pimp', Pimp, 'Pexp', Pexp, 'solveTime', solveTime, 'nFail', nFail, ...
            'E_end', E);
end

function [Php, Pch, Pdis] = thermostat_action(sc, p, k, x, E, Tset)
% Proportional thermostat. The battery stores PV surplus and covers the load
% deficit, without looking at prices.
Php = min(max(p.Kp_base * (Tset - x(1)), 0), p.Php_max);
net = sc.Pload(k) + Php - sc.Ppv(k);
if net < 0
    Pch = min([-net, p.Pb_max, (p.Emax - E) / (p.dt * p.eta_c)]);
    Pdis = 0;
else
    Pdis = min([net, p.Pb_max, (E - p.Emin) * p.eta_d / p.dt]);
    Pch = 0;
end
end
