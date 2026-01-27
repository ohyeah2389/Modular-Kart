-- Modular Kart Class 2 CSP Physics Script - FFB Adjustment Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')


local ffb = {}

ffb.lastFFB = 0
ffb.oscillationCounter = 0
ffb.dampingFactor = 1

function ffb.update(dt)
    local currentFFB = game.car_cphys.ffb
    local speed = game.car_cphys.speedKmh

    -- Detect oscillation
    if math.abs(currentFFB - ffb.lastFFB) > config.misc.ffbCorrection.oscillationThreshold * math.abs(currentFFB) then
        ffb.oscillationCounter = math.min(config.misc.ffbCorrection.oscillationCounterCeiling, ffb.oscillationCounter + 1)
    else
        ffb.oscillationCounter = math.max(0, ffb.oscillationCounter - config.misc.ffbCorrection.oscillationCounterDecay)
    end

    -- Calculate damping factor
    if ffb.oscillationCounter > config.misc.ffbCorrection.oscillationCounterThreshold and 
       speed > config.misc.ffbCorrection.minSpeed and 
       speed < config.misc.ffbCorrection.maxSpeed then
        ffb.dampingFactor = math.max(0, math.min(config.misc.ffbCorrection.dampingMax, ffb.dampingFactor + config.misc.ffbCorrection.dampingStep))
    else
        ffb.dampingFactor = math.max(0, math.min(config.misc.ffbCorrection.dampingMax, ffb.dampingFactor - config.misc.ffbCorrection.dampingRecoveryStep))
    end

    -- Apply damping by weighting towards lastFFB
    local dampedFFB = currentFFB * (1 - ffb.dampingFactor) + ffb.lastFFB * ffb.dampingFactor

    ac.setSteeringFFB(dampedFFB)

    -- Update lastFFB for the next frame
    ffb.lastFFB = dampedFFB

    -- Debug output
    ac.debug('ffb: dampingFactor', ffb.dampingFactor)
    ac.debug('ffb: oscillationCounter', ffb.oscillationCounter)
    ac.debug('ffb: currentFFB', currentFFB)
    ac.debug('ffb: dampedFFB', dampedFFB)
end


return ffb
