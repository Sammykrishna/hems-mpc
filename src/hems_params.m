function p = hems_params()
% Parameters of the simulated house. Units: kW, kWh, h, degC, EUR.

p.dt = 0.25;                       % time step (15 min)

% Building, two-state RC model
p.Ca  = 1.5;                       % air heat capacity, kWh/K
p.Cm  = 12;                        % building mass heat capacity, kWh/K
p.Rim = 0.67;                      % mass to air resistance, K/kW
p.Rea = 6.7;                       % air to outside resistance, K/kW
p.plantLossFactor = 1.10;          % the simulated house loses 10 % more heat than the MPC model

% Heat pump
p.Php_max = 2.5;                   % electric power limit, kW
p.cop = @(To) min(max(3.0 + 0.08*To, 2.2), 4.2);

% Battery
p.Emin  = 1;                       % kWh
p.Emax  = 9;                       % kWh
p.Pb_max = 5;                      % kW
p.eta_c = 0.95;
p.eta_d = 0.95;
p.c_deg = 0.02;                    % wear cost, EUR per kWh of throughput

% Grid
p.Pgrid_max = 11;                  % kW
p.fit = 0.08;                      % feed-in tariff, EUR/kWh

% MPC tuning
p.vterm = 0.15;                    % value of battery energy at the end of the horizon, EUR/kWh
p.ws = 2.0;                        % comfort penalty, EUR per K*h
p.mpcMargin = 0.3;                 % the MPC plans this many K inside the comfort band

% Thermostat baselines
p.Tset_base = 22.3;                % degC
p.Kp_base = 2.0;                   % kW/K
p.Tset_night = 18.5;               % degC, setback variant
p.setbackStart = 22;               % hour of day
p.setbackEnd = 4.5;                % hour of day

% Comfort band
p.dayStart = 6;   p.dayEnd = 22;
p.Tlo_day = 21;   p.Thi_day = 23;
p.Tlo_night = 18; p.Thi_night = 23;

% Initial state
p.x0 = [21.5; 21.3];               % [Ti; Tm], degC
p.E0 = 5;                          % battery energy, kWh
end
