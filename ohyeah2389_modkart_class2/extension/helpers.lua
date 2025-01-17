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


function helpers.getPositionInCarFrame(node, carNode)
    local carTransform = carNode:getTransformationRaw()
    local carTransformInv = carTransform:inverse()
    local nodeWorldPos = node:getWorldTransformationRaw():transformPoint(vec3())
    return carTransformInv:transformPoint(nodeWorldPos)
end


function helpers.getOrientationInCarFrame(node, carNode)
    local carTransform = carNode:getTransformationRaw()
    local nodeWorldTransform = node:getWorldTransformationRaw()
    
    -- Extract rotation matrices
    local carRotation = mat3x3(
        vec3(carTransform.row1.x, carTransform.row1.y, carTransform.row1.z),
        vec3(carTransform.row2.x, carTransform.row2.y, carTransform.row2.z),
        vec3(carTransform.row3.x, carTransform.row3.y, carTransform.row3.z)
    )
    local nodeRotation = mat3x3(
        vec3(nodeWorldTransform.row1.x, nodeWorldTransform.row1.y, nodeWorldTransform.row1.z),
        vec3(nodeWorldTransform.row2.x, nodeWorldTransform.row2.y, nodeWorldTransform.row2.z),
        vec3(nodeWorldTransform.row3.x, nodeWorldTransform.row3.y, nodeWorldTransform.row3.z)
    )
    
    -- Manually transpose carRotation
    local carRotationTransposed = mat3x3(
        vec3(carRotation.row1.x, carRotation.row2.x, carRotation.row3.x),
        vec3(carRotation.row1.y, carRotation.row2.y, carRotation.row3.y),
        vec3(carRotation.row1.z, carRotation.row2.z, carRotation.row3.z)
    )
    
    -- Manually multiply matrices
    local relativeRotation = mat3x3(
        vec3(
            carRotationTransposed.row1.x * nodeRotation.row1.x + carRotationTransposed.row1.y * nodeRotation.row2.x + carRotationTransposed.row1.z * nodeRotation.row3.x,
            carRotationTransposed.row1.x * nodeRotation.row1.y + carRotationTransposed.row1.y * nodeRotation.row2.y + carRotationTransposed.row1.z * nodeRotation.row3.y,
            carRotationTransposed.row1.x * nodeRotation.row1.z + carRotationTransposed.row1.y * nodeRotation.row2.z + carRotationTransposed.row1.z * nodeRotation.row3.z
        ),
        vec3(
            carRotationTransposed.row2.x * nodeRotation.row1.x + carRotationTransposed.row2.y * nodeRotation.row2.x + carRotationTransposed.row2.z * nodeRotation.row3.x,
            carRotationTransposed.row2.x * nodeRotation.row1.y + carRotationTransposed.row2.y * nodeRotation.row2.y + carRotationTransposed.row2.z * nodeRotation.row3.y,
            carRotationTransposed.row2.x * nodeRotation.row1.z + carRotationTransposed.row2.y * nodeRotation.row2.z + carRotationTransposed.row2.z * nodeRotation.row3.z
        ),
        vec3(
            carRotationTransposed.row3.x * nodeRotation.row1.x + carRotationTransposed.row3.y * nodeRotation.row2.x + carRotationTransposed.row3.z * nodeRotation.row3.x,
            carRotationTransposed.row3.x * nodeRotation.row1.y + carRotationTransposed.row3.y * nodeRotation.row2.y + carRotationTransposed.row3.z * nodeRotation.row3.y,
            carRotationTransposed.row3.x * nodeRotation.row1.z + carRotationTransposed.row3.y * nodeRotation.row2.z + carRotationTransposed.row3.z * nodeRotation.row3.z
        )
    )
    
    -- Extract the forward and up vectors from the relative rotation
    local forward = vec3(relativeRotation.row3.x, relativeRotation.row3.y, relativeRotation.row3.z):normalize()
    local up = vec3(relativeRotation.row2.x, relativeRotation.row2.y, relativeRotation.row2.z):normalize()
    
    return forward, up
end

function helpers.logit(x, center)
    center = center or 0.5  -- Default center is 0.5 if not provided
    local adjustedX = x - center
    return math.log(adjustedX / (1 - adjustedX))
end

return helpers
