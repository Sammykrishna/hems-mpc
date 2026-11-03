function [Ad, Bd] = hems_model(p, lossFactor)
% Discrete-time building model x(k+1) = Ad*x(k) + Bd*u(k).
%   x = [Ti; Tm]      air and building mass temperature
%   u = [Qhp; To]     thermal heat pump power and outside temperature
% lossFactor scales the heat loss to the outside (1 = nominal model).
if nargin < 2
    lossFactor = 1;
end
Rea = p.Rea / lossFactor;

Ac = [-(1/p.Rim + 1/Rea)/p.Ca,  1/(p.Rim*p.Ca);
       1/(p.Rim*p.Cm),         -1/(p.Rim*p.Cm)];
Bc = [1/p.Ca, 1/(Rea*p.Ca);
      0,      0];

M  = expm([Ac, Bc; zeros(2, 4)] * p.dt);   % exact zero-order hold
Ad = M(1:2, 1:2);
Bd = M(1:2, 3:4);
end
