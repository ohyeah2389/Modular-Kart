-- Modular Kart Class 2 CSP Physics Script - Clutch Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local physics = require('script_physics')


local clutch = {}

local lastClutch = 0


local clutchShoe = physics{
    posMax = 0.02,  -- Maximum outward travel of clutch shoe (in meters)
    posMin = 0,
    center = 0,
    mass = 0.1,  -- Mass of clutch shoe in kg
    frictionCoef = 0,
    staticFrictionCoef = 0,
    springCoef = 60000,  -- Spring coefficient to return shoe to rest position
    forceMax = 100000,
    radius = 0.1,  -- Radius of clutch drum (in meters)
    centrifugal = true  -- Use centrifugal mode
}


function clutch.update(dt) -- clutch percentage is calculated based off of how much force the clutch shoe(s) apply to the clutch drum
    local engineRPM = game.car_cphys.rpm
    local angularVelocity = (engineRPM / 60) * 2 * math.pi  -- Convert RPM to rad/s

    clutchShoe:step(angularVelocity, dt) -- run physics on clutch shoe object

    game.car_cphys.clutch = math.applyLag(lastClutch, clutchShoe.position > 0.018 and math.clamp(clutchShoe.force * 0.001, 0, 1) or 0, 0.05, dt)

    if game.car_cphys.clutch > 0.8 then
        game.car_cphys.clutch = 1
    end

    if (clutchShoe.force < 0) or (clutchShoe.position < 0.018) then
        game.car_cphys.clutch = 0
    end

    lastClutch = game.car_cphys.clutch

    ac.debug("clutchShoe.position", clutchShoe.position)
    ac.debug("clutchShoe.force", clutchShoe.force)
end


return clutch
