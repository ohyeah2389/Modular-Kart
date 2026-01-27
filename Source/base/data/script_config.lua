-- Modular Kart Class 2 CSP Physics Script - Config and Parameters Module
-- Authored by ohyeah2389


local config = {
    misc = {
        brakeAutoHold = {
            torque = 30; -- Brake torque in Nm to apply when auto-holding the brakes
            speed = 5; -- Speed in kmh below which to auto-hold the brakes
        };
        ffbCorrection = {
            minMultiplier = 0.5;
            maxSpeed = 30;
            minSpeed = 5;
            fadeoutSpeed = 10;
            oscillationThreshold = 0.4; -- Threshold for detecting FFB changes (0.1 = 10%)
            oscillationCounterThreshold = 5; -- Number of consecutive oscillations before applying damping
            oscillationCounterDecay = 1; -- How quickly the oscillation counter reduces when no oscillation is detected
            oscillationCounterCeiling = 200; -- Maximum value of the oscillation counter
            dampingMax = 0.9; -- Maximum damping factor
            dampingStep = 0.08; -- How quickly the damping factor changes
            dampingRecoveryStep = 0.003; -- How quickly the damping factor recovers
        };
    };
    battery = {
        nominalVoltage = 12.6; -- this is nominal voltage at 100%SOC, the Voltage/SOC LUT is given in relation to nominal voltage at 50%SOC
        startingCapacityAmpHours = 8.0; -- Nominal Amp-hours
    };
    thermal = {
        ambientTemp = sim.ambientTemperature;
    };
}


return config
