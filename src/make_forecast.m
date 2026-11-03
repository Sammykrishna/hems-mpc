function fc = make_forecast(sc, p, k, N, noisy, rs)
% Forecast of steps k..k+N-1 as the MPC sees it at step k.
% With noisy = true the errors grow with the lead time and are correlated
% along the horizon. Prices are always known exactly.
idx  = (k:k+N-1)';
lead = (0:N-1)' * p.dt;

To = sc.To(idx);
Ppv = sc.Ppv(idx);
Pload = sc.Pload(idx);

if noisy
    To    = To + ar1_along(rs, N, 0.9) .* (0.3 + 0.3*sqrt(lead));
    Ppv   = max(0, Ppv .* (1 + ar1_along(rs, N, 0.9) .* (0.10 + 0.06*sqrt(lead))));
    Pload = max(0.05, Pload + ar1_along(rs, N, 0.9) .* (0.10 + 0.03*sqrt(lead)));
end

fc.To = To;
fc.COP = p.cop(To);
fc.Ppv = Ppv;
fc.Pload = Pload;
fc.price = sc.price(idx);
% The band applies to the temperature reached at the end of each step
fc.Tlo = sc.Tlo(idx + 1) + p.mpcMargin;
fc.Thi = sc.Thi(idx + 1) - p.mpcMargin;
end

function e = ar1_along(rs, N, rho)
w = [randn(rs, 1, 1); sqrt(1 - rho^2) * randn(rs, N-1, 1)];
e = filter(1, [1 -rho], w);
end
