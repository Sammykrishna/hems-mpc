function [lp, ix] = build_mpc_lp(p, Ad, Bd, x0, E0, fc)
% One MPC step as a linear program over N = numel(fc.To) steps.
%
% The decision vector is stacked in blocks of N:
%   Php, Pch, Pdis, Pimp, Pexp, sLo, sHi, Ti, Tm, E
% Step j moves the state from j-1 to j. x0 and E0 are the measured start.
%
% Cost: grid cost minus feed-in revenue, battery wear, comfort slack penalty,
% and a value on the battery energy left at the end of the horizon.
N  = numel(fc.To);
dt = p.dt;
j  = (1:N)';
j2 = (2:N)';
nv = 10 * N;
ix = struct('Php', 0, 'Pch', N, 'Pdis', 2*N, 'Pimp', 3*N, 'Pexp', 4*N, ...
            'sLo', 5*N, 'sHi', 6*N, 'Ti', 7*N, 'Tm', 8*N, 'E', 9*N);

a11 = Ad(1,1); a12 = Ad(1,2); a21 = Ad(2,1); a22 = Ad(2,2);
bq1 = Bd(1,1); bo1 = Bd(1,2); bq2 = Bd(2,1); bo2 = Bd(2,2);

% Air temperature
r1 = [j;           j;                j2;               j2];
c1 = [ix.Ti+j;     ix.Php+j;         ix.Ti+j2-1;       ix.Tm+j2-1];
v1 = [ones(N,1);  -bq1*fc.COP;      -a11*ones(N-1,1); -a12*ones(N-1,1)];

% Mass temperature
r2 = N + r1;
c2 = [ix.Tm+j;     ix.Php+j;         ix.Ti+j2-1;       ix.Tm+j2-1];
v2 = [ones(N,1);  -bq2*fc.COP;      -a21*ones(N-1,1); -a22*ones(N-1,1)];

% Battery energy
r3 = 2*N + [j; j; j; j2];
c3 = [ix.E+j; ix.Pch+j; ix.Pdis+j; ix.E+j2-1];
v3 = [ones(N,1); -dt*p.eta_c*ones(N,1); dt/p.eta_d*ones(N,1); -ones(N-1,1)];

% Power balance at the grid connection
r4 = 3*N + [j; j; j; j; j];
c4 = [ix.Pimp+j; ix.Pexp+j; ix.Php+j; ix.Pch+j; ix.Pdis+j];
v4 = [ones(N,1); -ones(N,1); -ones(N,1); -ones(N,1); ones(N,1)];

Aeq = sparse([r1; r2; r3; r4], [c1; c2; c3; c4], [v1; v2; v3; v4], 4*N, nv);
beq = [bo1*fc.To; bo2*fc.To; zeros(N,1); fc.Pload - fc.Ppv];
beq(1)     = beq(1)     + a11*x0(1) + a12*x0(2);
beq(N+1)   = beq(N+1)   + a21*x0(1) + a22*x0(2);
beq(2*N+1) = beq(2*N+1) + E0;

% Soft comfort band: Tlo - sLo <= Ti <= Thi + sHi
A = sparse([j; j; N+j; N+j], [ix.Ti+j; ix.sLo+j; ix.Ti+j; ix.sHi+j], ...
           [-ones(N,1); -ones(N,1); ones(N,1); -ones(N,1)], 2*N, nv);
b = [-fc.Tlo; fc.Thi];

lb = zeros(nv, 1);
ub = inf(nv, 1);
ub(ix.Php+j)  = p.Php_max;
ub(ix.Pch+j)  = p.Pb_max;
ub(ix.Pdis+j) = p.Pb_max;
ub(ix.Pimp+j) = p.Pgrid_max;
lb(ix.Ti+j) = -inf;
lb(ix.Tm+j) = -inf;
lb(ix.E+j) = p.Emin;
ub(ix.E+j) = p.Emax;

f = zeros(nv, 1);
f(ix.Pimp+j) = dt * fc.price;
f(ix.Pexp+j) = -dt * p.fit;
f(ix.Pch+j)  = dt * p.c_deg;
f(ix.Pdis+j) = dt * p.c_deg;
f(ix.sLo+j)  = dt * p.ws;
f(ix.sHi+j)  = dt * p.ws;
f(ix.E+N)    = f(ix.E+N) - p.vterm;

lp = struct('f', f, 'A', A, 'b', b, 'Aeq', Aeq, 'beq', beq, 'lb', lb, 'ub', ub);
end
