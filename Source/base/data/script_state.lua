-- Modular Kart Class 2 CSP Physics Script - State Module
-- Authored by ohyeah2389


local config = require('script_config')


local state = {
    engine = {
        torque = 0.0; -- The torque, in Nm, that the engine is currently applying
        angle = 0.0; -- The engine's current angle, in degrees
        compressionTorque = 0.0;
        compressionWave = 0.0;
        temp = config.thermal.ambientTemp;
        lowSpeedJet = 1.5; -- turns out from full in
        highSpeedJet = 1.5; -- turns out from full in
        previousThrottle = 0.0;
        previousIdleThrottle = 0.0;
    };
    starter = {
        engaged = false;
        current = 0.0;
        health = 1.0;
        rpm = 0.0;
        torque = 0.0;
        voltageDraw = 0.0;
        temp = config.thermal.ambientTemp;
    };
    battery = {
        voltage = config.battery.nominalVoltage;
        charge = config.battery.startingCapacityAmpHours * config.battery.nominalVoltage * 0.85; -- start session mostly charged
        effectiveCapacity = config.battery.startingCapacityAmpHours * config.battery.nominalVoltage;
    }
}


return state