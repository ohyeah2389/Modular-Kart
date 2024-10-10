-- Modular Kart Class 2 CSP Physics Script - Clutch Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local physics = require('script_physics')


local clutch = {}


local clutchShoe = physics(1, 0, -5, 5, 0.7, 0.001, 50, 1000) -- initialize clutch shoe object


function clutch.update(dt) -- clutch percentage is calculated based off of how much force the clutch shoe(s) apply to the clutch drum
    local clutchShoePos = clutchShoe:step((game.car_cphys.rpm / 60)^2 * clutchShoe.mass * -0.05, dt) -- run physics on clutch shoe object

    ac.debug("clutchShoePos", clutchShoePos)
    ac.debug("clutchShoe.force", clutchShoe.force)

    game.car_cphys.clutch = clutchShoe.force / 100 -- divisor is a scalar for clutch force to clutch position
end


return clutch