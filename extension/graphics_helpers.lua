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

-- math helper function, like Map Range in Blender
function helpers.mapRange(n, start, stop, newStart, newStop, withinBounds)
    local value = ((n - start) / (stop - start)) * (newStop - newStart) + newStart

    -- Returns basic value
    if not withinBounds then
        return value
    end

    -- Returns values constrained to exact range
    if newStart < newStop then
        return math.max(math.min(value, newStop), newStart)
    else
        return math.max(math.min(value, newStart), newStop)
    end
end

return helpers
