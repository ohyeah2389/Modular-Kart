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
    engine = {
        torqueCurveLUT = ac.DataLUT11.carData(0, 'power_ka100.lut');
        torqueTrimmer = 1.00;
        coastRPM = 10000;
        coastTorque = -2.4;
        zeroRPMTorque = -0.08;
        zeroRPMRange = 300;
        cylindersAmount = 1;
        compressionMinRPM = 2000;
        compressionMaxRPM = 5000;
        compressionIntensity = 0;
        compressionOffset = 0.5; -- (-1 to 1) typical
        compressionOffsetGamma = 1; -- (0.001 and up) typical
        throttle = {
            curveTop = 20000;
            gamma = 2.2;
            mapGamma = 1.0;
            lagMaxRPM = 5000;
            lagMinRPM = 500;
            idle = {
                startRPM = 300;
                endRPM = 1600;
                position = 1;
            }
        };
        thermal = {
            thermalResistance = 0.55; -- Thermal resistance (degree Celsius per Watt)
            thermalEfficiency = 0.8; -- Thermal efficiency of the engine
        };
    };
    battery = {
        nominalVoltage = 12.6; -- this is nominal voltage at 100%SOC, the Voltage/SOC LUT is given in relation to nominal voltage at 50%SOC
        peukertExponent = 1.2; -- Peukert exponent for a typical lead-acid battery
        startingCapacityAmpHours = 8.0; -- Nominal Amp-hours
        voltageChargeLUT = ac.DataLUT11.carData(0, 'battery_voltage_soc.lut');
    };
    starter = {
        -- Starter motor parameters
        engagementThresholdRPM = 500; -- RPM threshold for engagement
        bendixKickoffTorque = 0.5; -- Nm
    };
    electricMotors = {
        starter = {
            resistance = 0.1; -- Ohms
            inductance = 0.0001; -- Henry
            torqueConstant = 0.06; -- Nm/A
            backEMFConstant = 0.15; -- V/(rad/s)
            inertia = 0.000000001; -- kg*m^2
            frictionCoefficient = 100; -- Nm/(rad/s)
            maxCurrent = 20; -- Amps
        };
    };
    thermal = {
        components = {
            combustionGas = {
                thermalMass = 0.0005; -- kg (guessed)
                specificHeatCapacity = 1005; -- J/(kg*K) for air
                transfersTo = {'cylinderHead', 'exhaust', 'cylinderWallSleeve'};
                transferSurfaceAreas = {0.01^2, 0.05^2, 0.005^2}; -- m(^2)
                combustionHeatingCoef = 2.5;
                frictionHeatingCoef = 0.2;
                airCoolingCoef = 0.05;
                emissivity = 1.0;
                radiativeSurfaceArea = 0.5;
            };
            cylinderHead = {
                thermalMass = 1.0; -- kg (guessed)
                specificHeatCapacity = 900; -- J/(kg*K) for aluminum
                transfersTo = {'block', 'headFins', 'cylinderWallSleeve'};
                transferSurfaceAreas = {0.02^2, 0.05^2, 0.008^2}; -- m(^2)
                combustionHeatingCoef = 1.2;
                frictionHeatingCoef = 0.3;
                airCoolingCoef = 0.03;
                emissivity = 0.8; -- Emissivity of aluminum (anodized)
                radiativeSurfaceArea = 0.03; -- m^2 (estimated)
            };
            headFins = {
                thermalMass = 0.7; -- kg (guessed)
                specificHeatCapacity = 900; -- J/(kg*K) for aluminum
                transfersTo = {'cylinderHead'};
                transferSurfaceAreas = {0.05^2}; -- m(^2)
                combustionHeatingCoef = 0.0;
                frictionHeatingCoef = 0.0;
                airCoolingCoef = 1.2;
                emissivity = 0.8; -- Emissivity of aluminum (anodized)
                radiativeSurfaceArea = 0.4; -- m^2 (estimated, larger due to fins)
            };
            cylinderWallSleeve = {
                thermalMass = 0.1; -- kg (guessed)
                specificHeatCapacity = 450; -- J/(kg*K) for iron
                transfersTo = {'block', 'cylinderHead'};
                transferSurfaceAreas = {0.03^2, 0.008^2}; -- m(^2)
                combustionHeatingCoef = 0.4;
                frictionHeatingCoef = 1.5;
                airCoolingCoef = 0.02;
                emissivity = 0.7; -- Emissivity of iron (oxidized)
                radiativeSurfaceArea = 0.02; -- m^2 (estimated)
            };
            block = {
                thermalMass = 1.5; -- kg (guessed)
                specificHeatCapacity = 900; -- J/(kg*K) for aluminum
                transfersTo = {'cylinderWallSleeve', 'blockFins', 'case', 'cylinderHead', 'exhaust'};
                transferSurfaceAreas = {0.03^2, 0.05^2, 0.02^2, 0.02^2, 0.005^2}; -- m(^2)
                combustionHeatingCoef = 0.1;
                frictionHeatingCoef = 0.3;
                airCoolingCoef = 0.1;
                emissivity = 0.6; -- Emissivity of aluminum (oxidized)
                radiativeSurfaceArea = 0.05; -- m^2 (estimated)
            };
            blockFins = {
                thermalMass = 0.6; -- kg (guessed)
                specificHeatCapacity = 900; -- J/(kg*K) for aluminum
                transfersTo = {'block'};
                transferSurfaceAreas = {0.05^2}; -- m(^2)
                combustionHeatingCoef = 0.0;
                frictionHeatingCoef = 0.0;
                airCoolingCoef = 1.2;
                emissivity = 0.6; -- Emissivity of aluminum (oxidized)
                radiativeSurfaceArea = 0.42; -- m^2 (estimated, larger due to fins)
            };
            case = {
                thermalMass = 0.8; -- kg (guessed)
                specificHeatCapacity = 900; -- J/(kg*K) for aluminum
                transfersTo = {'block'};
                transferSurfaceAreas = {0.02^2}; -- m(^2)
                combustionHeatingCoef = 1.0;
                frictionHeatingCoef = 0.6;
                airCoolingCoef = 0.4;
                emissivity = 0.6; -- Emissivity of aluminum (oxidized)
                radiativeSurfaceArea = 0.04; -- m^2 (estimated)
            };
            exhaust = {
                thermalMass = 0.6; -- kg (guessed)
                specificHeatCapacity = 450; -- J/(kg*K) for iron
                transfersTo = {'block'};
                transferSurfaceAreas = {0.005^2}; -- m(^2)
                combustionHeatingCoef = 0.2;
                frictionHeatingCoef = 0.0;
                airCoolingCoef = 0.25;
                emissivity = 0.9; -- Emissivity of iron (oxidized, high temperature)
                radiativeSurfaceArea = 0.5; -- m^2 (estimated)
            };
        };
        ambientTemp = sim.ambientTemperature;
        engineThermalEfficiency = 0.8; -- guessed
        oilMixRatio = 1/16;
        heatTransferCoef = 100;
        jetCrossoverStartRPM = 5000;
        jetCrossoverEndRPM = 10000;
        heatGenerationIdeologyMix = 0.5; -- mix of heat generation ideologies (0 = torque, 1 = rpm * throttle)
    };
}


return config
