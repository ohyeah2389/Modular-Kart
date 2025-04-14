--normalized sigmoid function for new_throttle function by JPG_18, some of script by SwitchPro and Ustahl, edited by ohyeah2389 to be callable for use in Modular Kart

-- [THROTTLE_LUA]
-- THROTTLE_GAMMA=1.1 ; Defaults to 1.1 if not specified.
-- THROTTLE_SLOPE=2.5 ; Defaults to 2.5 if not specified.
-- IDLE_RPM=950 ; Defaults to 1000 if not specified.
-- IDLE_TYPE=0 ; 0=Cable Throttle, 1=Drive by Wire. Defaults to 0 if not specified. Also THROTTLE_TYPE
---------------------------------------------------------------------------------------------------

-- Get the redline RPM for calculations and coast torque for mode 1 --
local data = ac.accessCarPhysics()
local engine_ini = ac.INIConfig.carData(0, "engine.ini")
local redline = engine_ini:get("ENGINE_DATA", "LIMITER", 10000)
----------------------------------------------------------------------

-- Get coast values for idle model --
local idle_RPM = engine_ini:get("ENGINE_DATA", "MINIMUM", 1000)
local coast_RPM = engine_ini:get("COAST_REF", "RPM", 10000)
local coast_torque_ref = engine_ini:get("COAST_REF", "TORQUE", 80)
-----------------------------------

-- Load the power.lut (for idle model) -- note: this is quite risky and will not work properly in numerous situations. Usually error will be small though
local power_lut = engine_ini:get("HEADER", "POWER_CURVE", "")
local WOT_TORQUE = ac.DataLUT11.carData(0, power_lut)
-----------------------------------------

-- Custom parameters --
local gamma = engine_ini:get("THROTTLE_LUA", "THROTTLE_GAMMA", 1.1)                                               -- Throttle gamma
local slope = engine_ini:get("THROTTLE_LUA", "THROTTLE_SLOPE", 2.5)                                               -- Torque mode
local idle_type = engine_ini:get("THROTTLE_LUA", "IDLE_TYPE", engine_ini:get("THROTTLE_LUA", "THROTTLE_TYPE", 0)) -- Idle type (0 = cable, 1 = dbw)
local new_idle = engine_ini:get("THROTTLE_LUA", "IDLE_RPM", idle_RPM)                                             -- New idle RPM
-------------------------------------------------

local enableScript = true

-- Declarations/Initializations --
local isIdleInitialized = false
local idle_model_throttle
local idle_model_trqReq

local netTorqueRequest
----------------------

local function calculateTorqueReq(throttle, rpm) -- calculates the torque request per driver throttle and rpm
    local new_throttle = 1.0;
    if (rpm > 0) then
        new_throttle = ((2 / (1 + (math.exp(-((redline / rpm) ^ gamma) * slope * throttle))) - 1)) /
        ((2 / (1 + (math.exp(-((redline / rpm) ^ gamma) * slope * 1))) - 1))
    end

    return new_throttle
end

local function atanh(x) --helper fxn
    return 0.5 * math.log((1.0 + x) / (1.0 - x));
end

local function calculateTorqueInv(trqReq, rpm) --calculates the inverse of the throttle model - gets driver throttle from torque request
    if (trqReq and rpm) then
        local firstTerm = 2.0 / (slope * (redline / rpm) ^ gamma)
        local secondTerm = atanh(trqReq * math.tanh((slope * (redline / rpm) ^ gamma) / 2.0))
        return firstTerm * secondTerm
    else
        return 0.0
    end
end

local function calculateIdleTrqReq(new_idle_RPM) --calculates the torque request for idle
    local brkTrq = -(new_idle_RPM - idle_RPM) * (coast_torque_ref / (coast_RPM - idle_RPM))
    local engTrq = WOT_TORQUE:get(new_idle_RPM)
    return brkTrq / (brkTrq - engTrq)
end

local function _idleModelSetup()
    idle_model_trqReq = calculateIdleTrqReq(new_idle)
    idle_model_throttle = calculateTorqueInv(idle_model_trqReq, new_idle);
    isIdleInitialized = true
end

local throttleModel = {}

function throttleModel.update(dt)
    if (enableScript) then
        if not isIdleInitialized then _idleModelSetup() end

        local usedGas = data.gas;

        if (math.abs(car.gas - usedGas) > 0.1) then -- this is compensating for autoblip not being in data.gas. Should instead probably just rewrite autoblip code
            usedGas = car.gas
        end

        if idle_type == 0 then
            usedGas = usedGas * (1.0 - idle_model_throttle) + idle_model_throttle;
        elseif idle_type == 1 then
            usedGas = math.max(usedGas, idle_model_throttle);
        end

        netTorqueRequest = calculateTorqueReq(usedGas, data.rpm)

        --ac.log("Idle Throttle Pedal",idle_model_throttle);
        --ac.log("Idle Throttle Torque",idle_model_trqReq);
        --ac.log("Net Throttle",usedGas);
        --ac.log("Torque Request",netTorqueRequest);

        ac.overrideGasInput(netTorqueRequest)
    end
end

return throttleModel
