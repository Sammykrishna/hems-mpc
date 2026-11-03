function sc = generate_scenario(nDays, seed, p)
% Synthetic winter data: outside temperature, PV, household load and a
% dynamic tariff. Smooth daily shapes plus seeded random variation.
rs = RandStream('mt19937ar', 'Seed', seed);
stepsPerDay = round(24 / p.dt);
K = nDays * stepsPerDay;
k = (0:K-1)';
h = mod(k * p.dt, 24);
day = floor(k / stepsPerDay) + 1;

ar1 = @(n, rho, s) filter(sqrt(1 - rho^2) * s, [1 -rho], randn(rs, n, 1));

dayMean = 2 + 3 * filter(sqrt(1 - 0.6^2), [1 -0.6], randn(rs, nDays, 1));
sc.To = dayMean(day) + 3.5 * sin(2*pi*(h - 9)/24) + ar1(K, 0.95, 0.3);

kWp = 5;
sun = max(0, sin(pi * (h - 8) / 8)) .* (h >= 8 & h <= 16);
cloud = 0.15 + 0.85 * rand(rs, nDays, 1).^1.5;
flicker = min(max(1 + ar1(K, 0.97, 0.15), 0.3), 1.2);
sc.Ppv = kWp * 0.5 * sun .* cloud(day) .* flicker;

sc.Pload = max(0.1, 0.25 + 0.6*exp(-((h - 7.5)/1.2).^2) ...
                         + 0.3*exp(-((h - 12.5)/1.0).^2) ...
                         + 1.0*exp(-((h - 19)/1.8).^2) + ar1(K, 0.9, 0.08));

dayOffset = 0.04 * randn(rs, nDays, 1);
sc.price = 0.27 + 0.10*exp(-((h - 8)/1.5).^2) + 0.13*exp(-((h - 19)/2).^2) ...
         - 0.07*exp(-((h - 13)/2.5).^2) - 0.04*(h < 5) + dayOffset(day);
sc.price = min(max(sc.price, 0.12), 0.60);

isDay = h >= p.dayStart & h < p.dayEnd;
sc.Tlo = p.Tlo_night + (p.Tlo_day - p.Tlo_night) * isDay;
sc.Thi = p.Thi_night + (p.Thi_day - p.Thi_night) * isDay;

sc.h = h;
sc.K = K;
sc.seed = seed;
end
