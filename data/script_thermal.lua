-- Modular Kart Class 2 CSP Physics Script - Thermal Simulation Module
-- Authored by ohyeah2389

local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')
local combustion = require('script_combustion')


local thermal = {}


local function radiativeHeatTransfer(temp, ambientTemp, emissivity, surfaceArea)
    local stefanBoltzmann = 5.67e-8 -- Stefan-Boltzmann constant
    return emissivity * stefanBoltzmann * surfaceArea * (temp^4 - ambientTemp^4)
end


function thermal.update(dt)
    local rpm = game.car_cphys.rpm
    local throttle = combustion.getEffectiveThrottle(game.car_cphys.gas)
    local jettingRPMFactor = helpers.mapRange(rpm, config.thermal.jetCrossoverStartRPM, config.thermal.jetCrossoverEndRPM, 0, 1, true)
    local airFuelRatioBase = helpers.mapRange(throttle, 0, 1, 8.5, 13.2, true)

    -- Apply jet needle adjustments
    local lowSpeedRichness = (state.engine.lowSpeedJet / 4) ^ 0.1
    local highSpeedRichness = (state.engine.highSpeedJet / 4) ^ 0.1
    local richnessFactor = lowSpeedRichness + (highSpeedRichness - lowSpeedRichness) * jettingRPMFactor -- linear interp
    
    -- Calculate final AFR
    state.thermal.airFuelRatio = airFuelRatioBase / richnessFactor

    -- Calculate AFR effect on heat generation
    local afrHeatEffect = helpers.mapRange(helpers.normalDistributionCDF(state.thermal.airFuelRatio, 14.7, 3), 0, 1, 0.35, 1.0, true)
    state.thermal.afrDetuneEffect = helpers.normalDistributionPDF(state.thermal.airFuelRatio, 14.7, 3)

    ac.debug("richnessFactor", richnessFactor)
    ac.debug("airFuelRatioBase", airFuelRatioBase)
    ac.debug("lowSpeedJet", state.engine.lowSpeedJet)
    ac.debug("highSpeedJet", state.engine.highSpeedJet)
    ac.debug("afrHeatEffect", afrHeatEffect)

    -- Calculate heat generation and transfer for each component
    for componentName, component in pairs(config.thermal.components) do
        local heatGeneration = 0
        local heatTransfer = 0
        local cooling = 0
        local radiativeCooling = 0

        -- Heat generation from combustion and friction
        heatGeneration = heatGeneration + (component.combustionHeatingCoef * math.lerp(math.max(0, state.engine.torque), (throttle * rpm / 1000), config.thermal.heatGenerationIdeologyMix) * 1000 * config.thermal.engineThermalEfficiency * afrHeatEffect)
        heatGeneration = heatGeneration + (component.frictionHeatingCoef * rpm)

        -- Heat transfer to other components
        for i, targetComponent in ipairs(component.transfersTo) do
            local deltaTemp = state.thermal.components[componentName].temp - state.thermal.components[targetComponent].temp
            local transferRate = deltaTemp * component.transferSurfaceAreas[i] * config.thermal.heatTransferCoef
            heatTransfer = heatTransfer + transferRate
            state.thermal.components[targetComponent].temp = state.thermal.components[targetComponent].temp + transferRate * dt / config.thermal.components[targetComponent].thermalMass
        end

        -- Cooling from airflow (convection)
        cooling = component.airCoolingCoef * game.car_cphys.speedKmh * (state.thermal.components[componentName].temp - config.thermal.ambientTemp)

        -- Radiative cooling
        radiativeCooling = radiativeHeatTransfer(
            state.thermal.components[componentName].temp,
            config.thermal.ambientTemp,
            component.emissivity,
            component.radiativeSurfaceArea
        )

        -- Update component temperature
        local netHeat = heatGeneration - heatTransfer - cooling - radiativeCooling
        state.thermal.components[componentName].temp = state.thermal.components[componentName].temp + (netHeat / (component.thermalMass * component.specificHeatCapacity)) * dt
    end
end


return thermal