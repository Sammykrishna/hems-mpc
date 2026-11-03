Simulation of 14 days, synthetic scenario. Saving is relative to the reference case of each table.

### Main results

| Case | Cost [EUR/day] | Saving [%] | Comfort violation [K h] | Max violation [K] | Battery cycles | Solve time [ms] |
|---|---|---|---|---|---|---|
| Thermostat, constant setpoint | 9.82 | -2.3 | 0.00 | 0.00 | 1.7 | - |
| Thermostat, night setback | 9.59 | - | 0.18 | 0.26 | 1.0 | - |
| MPC 24 h, perfect forecast | 8.14 | 15.2 | 0.00 | 0.00 | 23.9 | 11 |
| MPC 24 h, noisy forecast, seed 7 | 8.23 | 14.2 | 0.00 | 0.00 | 24.6 | 10 |
| MPC 24 h, noisy forecast, seed 8 | 8.23 | 14.1 | 0.00 | 0.01 | 24.6 | 10 |
| MPC 24 h, noisy forecast, seed 9 | 8.23 | 14.2 | 0.00 | 0.00 | 24.9 | 10 |

### Without battery

| Case | Cost [EUR/day] | Saving [%] | Comfort violation [K h] | Max violation [K] | Battery cycles | Solve time [ms] |
|---|---|---|---|---|---|---|
| No battery: thermostat, night setback | 9.66 | - | 0.18 | 0.26 | 0.0 | - |
| No battery: MPC 24 h, noisy forecast, seed 7 | 9.25 | 4.3 | 0.00 | 0.00 | 0.0 | 6 |

### Prediction horizon

| Case | Cost [EUR/day] | Saving [%] | Comfort violation [K h] | Max violation [K] | Battery cycles | Solve time [ms] |
|---|---|---|---|---|---|---|
| MPC 6 h, noisy forecast, seed 7 | 8.40 | 12.4 | 0.02 | 0.09 | 25.7 | 3 |
| MPC 12 h, noisy forecast, seed 7 | 8.34 | 13.0 | 0.02 | 0.04 | 25.8 | 5 |
| MPC 24 h, noisy forecast, seed 7 | 8.23 | 14.2 | 0.00 | 0.00 | 24.6 | 10 |
| MPC 36 h, noisy forecast, seed 7 | 8.23 | 14.2 | 0.00 | 0.00 | 24.1 | 17 |

### Comfort margin of the MPC (the main runs use 0.3 K)

| Case | Cost [EUR/day] | Saving [%] | Comfort violation [K h] | Max violation [K] | Battery cycles | Solve time [ms] |
|---|---|---|---|---|---|---|
| Margin 0.0 K: MPC 24 h, noisy forecast, seed 7 | 8.06 | 16.0 | 7.88 | 0.26 | 24.1 | 10 |
| MPC 24 h, noisy forecast, seed 7 | 8.23 | 14.2 | 0.00 | 0.00 | 24.6 | 10 |
| Margin 0.5 K: MPC 24 h, noisy forecast, seed 7 | 8.34 | 13.0 | 0.00 | 0.00 | 24.9 | 10 |
| Margin 1.0 K: MPC 24 h, noisy forecast, seed 7 | 8.65 | 9.9 | 0.00 | 0.00 | 25.7 | 11 |

### Battery wear cost (EUR per kWh of throughput)

| Case | Cost [EUR/day] | Saving [%] | Comfort violation [K h] | Max violation [K] | Battery cycles | Solve time [ms] |
|---|---|---|---|---|---|---|
| Thermostat, night setback | 9.59 | - | 0.18 | 0.26 | 1.0 | - |
| MPC 24 h, noisy forecast, seed 7 | 8.23 | 14.2 | 0.00 | 0.00 | 24.6 | 10 |
| Wear cost 0.05: thermostat, night setback | 9.62 | - | 0.18 | 0.26 | 1.0 | - |
| Wear cost 0.05: MPC 24 h, noisy forecast, seed 7 | 8.87 | 7.7 | 0.00 | 0.00 | 13.5 | 10 |
| Wear cost 0.10: thermostat, night setback | 9.67 | - | 0.18 | 0.26 | 1.0 | - |
| Wear cost 0.10: MPC 24 h, noisy forecast, seed 7 | 9.18 | 5.1 | 0.00 | 0.00 | 1.0 | 10 |

