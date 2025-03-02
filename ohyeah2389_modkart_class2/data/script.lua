-- Modular Kart Class 2 CSP Physics Script - Main Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local combustion = require('script_combustion')
local starter = require('script_starter')
local clutch = require('script_clutch')
local drivetrain = require('script_drivetrain')
local sharedData = require('script_sharedData')
local ffb = require('script_ffb')


local lastDebugTime = os.clock()


-- Shows specific variables in debug
local function showDebugValues()
    if os.clock() - lastDebugTime > 0.05 then
        lastDebugTime = os.clock()
        ac.debug("state.engine.torque", state.engine.torque)
        ac.debug("state.engine.compressionTorque", state.engine.compressionTorque)
        ac.debug("state.engine.compressionWave", state.engine.compressionWave)
        ac.debug("state.engine.angle", state.engine.angle)
        ac.debug("state.starter.rpm", state.starter.rpm)
        ac.debug("state.starter.engaged", state.starter.engaged)
        ac.debug("state.starter.torque", state.starter.torque)
        ac.debug("state.starter.voltageDraw", state.starter.voltageDraw)
    end
end


local jetHighClose = ac.ControlButton("__EXT_LIGHT_JETHIGH_CLOSE")
local jetHighOpen = ac.ControlButton("__EXT_LIGHT_JETHIGH_OPEN")
local jetLowClose = ac.ControlButton("__EXT_LIGHT_JETLOW_CLOSE")
local jetLowOpen = ac.ControlButton("__EXT_LIGHT_JETLOW_OPEN")


jetHighClose:onPressed(function()
    state.engine.highSpeedJet = math.max(0, math.min(8, state.engine.highSpeedJet - 1/16))
end)

jetHighOpen:onPressed(function()
    state.engine.highSpeedJet = math.max(0, math.min(8, state.engine.highSpeedJet + 1/16))
end)

jetLowClose:onPressed(function()
    state.engine.lowSpeedJet = math.max(0, math.min(8, state.engine.lowSpeedJet - 1/16))
end)

jetLowOpen:onPressed(function()
    state.engine.lowSpeedJet = math.max(0, math.min(8, state.engine.lowSpeedJet + 1/16))
end)


local function brakeAutoHold()
    if game.car_cphys.speedKmh < config.misc.brakeAutoHold.speed and game.car_cphys.gas < 0.01 then
        ac.overrideBrakesTorque(2, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
        ac.overrideBrakesTorque(3, config.misc.brakeAutoHold.torque, config.misc.brakeAutoHold.torque)
    else
        ac.overrideBrakesTorque(2, math.nan, math.nan)
        ac.overrideBrakesTorque(3, math.nan, math.nan)
    end
end


-- Called when car teleports to pits or session resets
---@diagnostic disable-next-line: duplicate-set-field
function script.reset()
end

ac.onCarJumped(0, script.reset)

-- Run by game every physics tick (~333 Hz)
---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.awakeCarPhysics()

    brakeAutoHold()

    --combustion.update(dt)
    --starter.update(dt)
    --drivetrain.update(dt)
    --clutch.update(dt)
    ffb.update(dt)

    --ac.overrideGasInput(1) -- physics gas input is required to be 1 at all times to correctly "override" stock engine model
    --ac.disableEngineLimiter(true)
    --ac.overrideEngineTorque(state.engine.torque + (state.starter.engaged and state.starter.torque or 0))

    sharedData.update()

    showDebugValues()
end