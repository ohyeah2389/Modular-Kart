-- Modular Kart Class 2 CSP Graphics Helpers Script
-- Authored by ohyeah2389


local helpers = {}

---Calculates the car's angular acceleration based on current and previous angular velocity
---@param currentAngularVelocity vec3
---@param previousAngularVelocity vec3
---@param dt number
---@return vec3
function helpers.calculateAngularAcceleration(currentAngularVelocity, previousAngularVelocity, dt)
    return (currentAngularVelocity - previousAngularVelocity) / dt
end

return helpers
