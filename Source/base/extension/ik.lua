--- Creates a 4x4 WORLD transformation matrix at a position, oriented towards a target.
-- Builds a standard matrix suitable for world space:
--   - Local +Z axis aligns with the 'forward' direction (target - origin).
--   - Local +Y aligns as close as possible to 'worldUpHint'.
--   - Local +X aligns with the 'right' direction (orthogonal to forward and up).
-- @param originWorld vec3 The desired world origin for the matrix.
-- @param lookTargetWorld vec3 The world point to look towards.
-- @param worldUpHint vec3? A world-space up vector hint (default: {0,1,0}). Used to stabilize the 'up' direction.
-- @param epsilon number? Small value for float comparisons (default: 1e-6).
-- @param convention string? The local axis convention for the transformation (default: "Z_Fwd_Y_Up").
-- @return mat4x4 The calculated world transformation matrix, or identity if origin and target are too close.
local function buildWorldTransformLookingAt(originWorld, lookTargetWorld, worldUpHint, epsilon, convention)
    epsilon = epsilon or 1e-6
    convention = convention or "Z_Fwd_Y_Up" -- Default convention if not provided

    local forward = lookTargetWorld - originWorld

    -- Handle cases where origin and target are coincident
    if forward:lengthSquared() < epsilon * epsilon then
        -- Don't print warnings in the helper, let the main function decide if it's an issue.
        -- print("IK WARN buildWorldTransformLookingAt: forward vector too small!", forward)
        local m = mat4x4.identity()
        m.position = originWorld
        return m
    end
    forward:normalize()

    -- Calculate a robust 'up' vector, avoiding gimbal lock with the forward vector
    -- Select default hint based on convention
    local defaultHint
    if convention == "Y_Fwd_Z_Up" then
        -- If Node Z is semantic Up, and it naturally points down world, hint towards world down.
        defaultHint = vec3(0, -1, 0)
        -- print("IK buildWorldTransform: Using DOWN hint for Y_Fwd_Z_Up") -- Optional debug
    else
        -- Standard Z_Fwd_Y_Up or other conventions, hint towards world up.
        defaultHint = vec3(0, 1, 0)
    end
    local temp_up = worldUpHint or defaultHint -- Use provided hint, or default based on convention

    local dotProduct = math.dot(forward, temp_up)
    if math.abs(dotProduct) > (1.0 - epsilon) then -- If forward and hint are nearly parallel
        -- Try world X axis as hint
        temp_up = vec3(1, 0, 0)
        dotProduct = math.dot(forward, temp_up)
        if math.abs(dotProduct) > (1.0 - epsilon) then -- If forward is also parallel to world X
            -- Use world Z axis as hint
            temp_up = vec3(0, 0, 1)
        end
    end

    -- Calculate orthogonal right and final up vectors
    local right = math.cross(temp_up, forward)
    if right:lengthSquared() < epsilon * epsilon then
        -- Handle potential collapse if temp_up and forward were still parallel (shouldn't happen with the checks above)
        -- Rebuild basis using a fallback
        local nonParallelVec = math.abs(forward.x) > 0.9 and vec3(0,1,0) or vec3(1,0,0)
        right = math.cross(nonParallelVec, forward):normalize()
        -- Fallback logic might need adjustment depending on engine coordinate system if this becomes an issue
    else
        right:normalize()
    end

    local up = math.cross(forward, right):normalize() -- Already normalized due to cross product of normalized vectors

    -- Construct the matrix (assuming column vectors for axes)
    return mat4x4(
        vec4(right.x, right.y, right.z, 0),    -- Right vector (X axis)
        vec4(up.x, up.y, up.z, 0),          -- Up vector (Y axis)
        vec4(forward.x, forward.y, forward.z, 0), -- Forward vector (Z axis)
        vec4(originWorld.x, originWorld.y, originWorld.z, 1) -- Position (W component is 1)
    )
end

--- Clamps a local orientation (fwd, up) to a hinge constraint and optionally a twist constraint.
-- @param fwdLocal vec3 The desired local forward vector (normalized).
-- @param upLocal vec3 The desired local up vector (normalized, orthogonal to fwdLocal).
-- @param hingeAxisLocal vec3 The axis of rotation for the hinge in local space (normalized).
-- @param minAngleRad number The minimum allowed angle in radians.
-- @param maxAngleRad number The maximum allowed angle in radians.
-- @param applyTwistLimit boolean Whether to apply twist limits.
-- @param minTwistAngleRad number Minimum allowed twist angle around fwdClampedLocal (radians).
-- @param maxTwistAngleRad number Maximum allowed twist angle around fwdClampedLocal (radians).
-- @param epsilon number Small value for float comparisons.
-- @param convention string? The local axis convention ("Z_Fwd_Y_Up" or "Y_Fwd_Z_Up").
-- @return vec3 Clamped local forward vector (normalized).
-- @return vec3 Clamped local up vector (normalized, orthogonal to clamped forward).
local function clampOrientationToHingeAndTwist(fwdLocal, upLocal, hingeAxisLocal, minAngleRad, maxAngleRad, applyTwistLimit, minTwistAngleRad, maxTwistAngleRad, epsilon, convention)
    epsilon = epsilon or 1e-6
    convention = convention or "Z_Fwd_Y_Up" -- Default convention

    -- === Part 1: Hinge Constraint ===
    -- 1. Define reference perpendicular direction
    local ref_perp
    local parent_z_ref = vec3(0, 0, 1) -- Using Parent Z as the reference for hinge zero angle (could be configurable)
    local dot_z = hingeAxisLocal:dot(parent_z_ref)

    if math.abs(dot_z) < (1.0 - epsilon) then
        ref_perp = parent_z_ref - hingeAxisLocal * dot_z
    else
        -- Hinge axis is parallel to reference Z, try parent Y
        local parent_y_ref = vec3(0, 1, 0)
        local dot_y = hingeAxisLocal:dot(parent_y_ref)
        if math.abs(dot_y) < (1.0 - epsilon) then
            ref_perp = parent_y_ref - hingeAxisLocal * dot_y
        else
             -- Fallback if parallel to both Z and Y (e.g. hinge is X axis, ref_perp becomes Z)
             ref_perp = vec3(0, 0, 1)
        end
    end
    if ref_perp:lengthSquared() < epsilon * epsilon then
        print("IK Hinge WARN: Could not derive valid reference perpendicular vector. Using default.")
         if math.abs(hingeAxisLocal.x) > 0.9 then ref_perp = vec3(0,0,1)
         elseif math.abs(hingeAxisLocal.y) > 0.9 then ref_perp = vec3(0,0,1)
         else ref_perp = vec3(0,1,0) end
    end
    ref_perp:normalize()

    -- 2. Project fwdLocal onto hinge plane
    local fwd_perp = fwdLocal - hingeAxisLocal * fwdLocal:dot(hingeAxisLocal)
    local fwd_perp_len = fwd_perp:length()

    -- 3. Calculate signed angle relative to ref_perp
    local signed_angle = 0
    if fwd_perp_len > epsilon then
        fwd_perp:scale(1.0 / fwd_perp_len) -- Normalize
        local angle_cos = math.clamp(ref_perp:dot(fwd_perp), -1.0, 1.0)
        local angle = math.acos(angle_cos)
        local sign_dot = hingeAxisLocal:dot(math.cross(ref_perp, fwd_perp))
        signed_angle = (sign_dot >= 0) and angle or -angle
    end

    -- 4. Clamp hinge angle
    local clamped_angle = math.clamp(signed_angle, minAngleRad, maxAngleRad)

    -- 5. Construct hinge-clamped orientation
    local q_hinge_clamped = quat.fromAngleAxis(clamped_angle, hingeAxisLocal)
    local fwd_perp_clamped = ref_perp:clone():rotate(q_hinge_clamped)
    local fwdClampedLocal = fwd_perp_clamped:normalize()

    local q_effective_rot
    if fwd_perp_len > epsilon then
         q_effective_rot = quat.between(fwd_perp, fwdClampedLocal)
    else
        q_effective_rot = q_hinge_clamped
    end
    local upHingeClampedLocal = upLocal:clone():rotate(q_effective_rot)


    -- === Part 2: Twist Constraint ===
    local upFinalClampedLocal = upHingeClampedLocal

    if applyTwistLimit then
        -- 1. Define a "no-twist" reference up vector based on PARENT's Z axis.
        local parentUpAxis = vec3(0, 0, 1) -- Always use Parent's Local Z
        -- Project parent's Up onto the plane perpendicular to fwdClampedLocal
        local twistRefUp = parentUpAxis - fwdClampedLocal * fwdClampedLocal:dot(parentUpAxis)
        local twistRefUpLenSq = twistRefUp:lengthSquared()

        if twistRefUpLenSq < epsilon * epsilon then
            print("IK Hinge Twist WARN: Parent Z parallel to clamped forward, using fallback twist reference.")
            twistRefUp = math.cross(fwdClampedLocal, hingeAxisLocal)
            if twistRefUp:lengthSquared() < epsilon * epsilon then
                local nonParallelVec = math.abs(fwdClampedLocal.x) > 0.9 and vec3(0,1,0) or vec3(1,0,0)
                twistRefUp = math.cross(fwdClampedLocal, nonParallelVec):normalize()
            else twistRefUp:normalize() end
        else twistRefUp:normalize() end

        -- 2. Project current up vector onto twist plane
        local upProj = upHingeClampedLocal - fwdClampedLocal * fwdClampedLocal:dot(upHingeClampedLocal)
        local upProjLen = upProj:length()

        -- 3. Calculate signed twist angle
        local currentTwistAngle = 0
        if upProjLen > epsilon then
            upProj:scale(1.0 / upProjLen)
            local angle_cos = math.clamp(twistRefUp:dot(upProj), -1.0, 1.0)
            local angle = math.acos(angle_cos)
            local sign_dot = fwdClampedLocal:dot(math.cross(twistRefUp, upProj))
            currentTwistAngle = (sign_dot >= 0) and angle or -angle
        end

        -- 4. Clamp twist angle
        local clampedTwistAngle = math.clamp(currentTwistAngle, minTwistAngleRad, maxTwistAngleRad)

        -- 5. Apply twist correction
        local twistDiff = clampedTwistAngle - currentTwistAngle
        if math.abs(twistDiff) > epsilon then
            local q_twist_correction = quat.fromAngleAxis(twistDiff, fwdClampedLocal)
            upFinalClampedLocal = upHingeClampedLocal:clone():rotate(q_twist_correction)
        end
    end

    -- === Part 3: Final Orthogonalization ===
    fwdClampedLocal:normalize()
    local right = math.cross(upFinalClampedLocal, fwdClampedLocal)
    if right:lengthSquared() < epsilon * epsilon then
        right = math.cross(hingeAxisLocal, fwdClampedLocal):normalize()
        if right:lengthSquared() < epsilon * epsilon then
            local nonParallelVec = math.abs(fwdClampedLocal.x) > 0.9 and vec3(0,1,0) or vec3(1,0,0)
            right = math.cross(nonParallelVec, fwdClampedLocal):normalize()
        end
    else
        right:normalize()
    end
    local upFinal = math.cross(fwdClampedLocal, right):normalize()

    return fwdClampedLocal, upFinal
end

--- Clamps a local orientation (fwd, up) to a cone constraint and optionally a twist constraint.
-- @param fwdLocal vec3 The desired local forward vector (normalized).
-- @param upLocal vec3 The desired local up vector (normalized, orthogonal to fwdLocal).
-- @param coneAxisLocal vec3 The axis of the cone in local space (normalized).
-- @param maxAngleRad number The maximum allowed angle from the cone axis in radians.
-- @param applyTwistLimit boolean Whether to apply twist limits.
-- @param minTwistAngleRad number Minimum allowed twist angle around fwdClampedLocal (radians).
-- @param maxTwistAngleRad number Maximum allowed twist angle around fwdClampedLocal (radians).
-- @param epsilon number Small value for float comparisons.
-- @param convention string? The local axis convention ("Z_Fwd_Y_Up" or "Y_Fwd_Z_Up").
-- @return vec3 Clamped local forward vector (normalized).
-- @return vec3 Clamped local up vector (normalized, orthogonal to clamped forward).
local function clampOrientationToConeAndTwist(fwdLocal, upLocal, coneAxisLocal, maxAngleRad, applyTwistLimit, minTwistAngleRad, maxTwistAngleRad, epsilon, convention)
    epsilon = epsilon or 1e-6
    -- convention = convention or "Z_Fwd_Y_Up" -- No longer needed for twistRefUp

    -- === Part 1: Cone Constraint ===
    local dot = math.clamp(fwdLocal:dot(coneAxisLocal), -1.0, 1.0)
    local currentAngle = math.acos(dot)

    local q_clamp = quat()
    local fwdClampedLocal = fwdLocal:clone()
    local upConeClampedLocal = upLocal:clone()

    if currentAngle > maxAngleRad and maxAngleRad < (math.pi - epsilon) then
        if maxAngleRad < epsilon then
            fwdClampedLocal = coneAxisLocal:clone()
            local upTemp = upLocal - coneAxisLocal * coneAxisLocal:dot(upLocal)
            if upTemp:lengthSquared() < epsilon * epsilon then
                 local nonParallelVec = math.abs(coneAxisLocal.x) > 0.9 and vec3(0,1,0) or vec3(1,0,0)
                 upTemp = math.cross(coneAxisLocal, nonParallelVec):normalize()
            else
                upTemp:normalize()
            end
            upConeClampedLocal = upTemp
            local q_orig = quat.fromDirection(fwdLocal, upLocal)
            local q_target = quat.fromDirection(fwdClampedLocal, upConeClampedLocal)
            q_clamp = q_target * q_orig:inverse()
        else
            local rotationAxis = math.cross(coneAxisLocal, fwdLocal)
            local axisLenSq = rotationAxis:lengthSquared()
            if axisLenSq < epsilon * epsilon then
                local nonParallelVec = math.abs(coneAxisLocal.x) > 0.9 and vec3(0,1,0) or vec3(1,0,0)
                rotationAxis = math.cross(coneAxisLocal, nonParallelVec):normalize()
                local rotationAmount = math.pi - maxAngleRad
                q_clamp = quat.fromAngleAxis(rotationAmount, rotationAxis)
            else
                rotationAxis:scale(1.0 / math.sqrt(axisLenSq))
                local rotationAmount = currentAngle - maxAngleRad
                q_clamp = quat.fromAngleAxis(rotationAmount, rotationAxis)
            end
            fwdClampedLocal = fwdLocal:clone():rotate(q_clamp)
            upConeClampedLocal = upLocal:clone():rotate(q_clamp)
        end
    end

    -- === Part 2: Twist Constraint ===
    local upFinalClampedLocal = upConeClampedLocal

    if applyTwistLimit then
        -- 1. Define a "no-twist" reference up vector in the plane perpendicular to fwdClampedLocal.
        --    REVERTED: Base it geometrically on the cone axis and the clamped forward direction.
        local twistRefUp = math.cross(fwdClampedLocal, coneAxisLocal)
        local twistRefUpLenSq = twistRefUp:lengthSquared()

        if twistRefUpLenSq < epsilon * epsilon then
            -- fwdClampedLocal is aligned with coneAxisLocal. Twist reference is ambiguous.
            -- Fallback: Use original up projected.
            print("IK Cone Twist WARN: fwd parallel to cone axis, using fallback twist reference.")
            twistRefUp = upLocal - fwdClampedLocal * fwdClampedLocal:dot(upLocal)
            if twistRefUp:lengthSquared() < epsilon * epsilon then
                 -- Ultimate fallback
                local nonParallelVec = math.abs(fwdClampedLocal.x) > 0.9 and vec3(0,1,0) or vec3(1,0,0)
                twistRefUp = math.cross(fwdClampedLocal, nonParallelVec):normalize()
            else
                twistRefUp:normalize()
            end
        else
            twistRefUp:normalize()
        end

        -- 2. Project current up vector onto twist plane
        local upProj = upConeClampedLocal - fwdClampedLocal * fwdClampedLocal:dot(upConeClampedLocal)
        local upProjLen = upProj:length()

        -- 3. Calculate signed twist angle
        local currentTwistAngle = 0
        if upProjLen > epsilon then
            upProj:scale(1.0 / upProjLen) -- Normalize
            local angle_cos = math.clamp(twistRefUp:dot(upProj), -1.0, 1.0)
            local angle = math.acos(angle_cos)
            local sign_dot = fwdClampedLocal:dot(math.cross(twistRefUp, upProj))
            currentTwistAngle = (sign_dot >= 0) and angle or -angle
        end

        -- 4. Clamp twist angle
        local clampedTwistAngle = math.clamp(currentTwistAngle, minTwistAngleRad, maxTwistAngleRad)

        -- 5. Apply twist correction
        local twistDiff = clampedTwistAngle - currentTwistAngle
        if math.abs(twistDiff) > epsilon then
            local q_twist_correction = quat.fromAngleAxis(twistDiff, fwdClampedLocal)
            upFinalClampedLocal = upConeClampedLocal:clone():rotate(q_twist_correction)
        end
    end

    -- === Part 3: Final Orthogonalization ===
    fwdClampedLocal:normalize()
    local right = math.cross(upFinalClampedLocal, fwdClampedLocal)
    if right:lengthSquared() < epsilon * epsilon then
        local nonParallelVec = math.abs(fwdClampedLocal.x) > 0.9 and vec3(0,1,0) or vec3(1,0,0)
        right = math.cross(nonParallelVec, fwdClampedLocal):normalize()
    else
        right:normalize()
    end
    local upFinal = math.cross(fwdClampedLocal, right):normalize()

    return fwdClampedLocal, upFinal
end

--- Clamps ONLY the TWIST of a local orientation (fwd, up) relative to a dynamically chosen reference axis.
-- Assumes the primary constraint (cone/hinge angle) has already been enforced.
-- @param fwdLocal vec3 The desired local forward vector (normalized, assumed constraint-valid).
-- @param upLocal vec3 The desired local up vector (normalized, orthogonal to fwdLocal).
-- @param applyTwistLimit boolean Whether to apply twist limits.
-- @param minTwistAngleRad number Minimum allowed twist angle around fwdLocal (radians).
-- @param maxTwistAngleRad number Maximum allowed twist angle around fwdLocal (radians).
-- @param epsilon number Small value for float comparisons.
-- @param convention string? The local axis convention ("Z_Fwd_Y_Up" or "Y_Fwd_Z_Up"). Influences twist reference.
-- @param coneAxisLocal vec3? The cone axis, used for Y_Fwd_Z_Up twist reference calculation.
-- @return vec3 Original fwdLocal vector (passed through).
-- @return vec3 Clamped local up vector (normalized, orthogonal to fwdLocal).
local function clampTwistRelativeToReference(fwdLocal, upLocal, applyTwistLimit, minTwistAngleRad, maxTwistAngleRad, epsilon, convention, coneAxisLocal)
    epsilon = epsilon or 1e-6
    convention = convention or "Z_Fwd_Y_Up" -- Default convention

    local fwdClampedLocal = fwdLocal -- Forward vector is assumed already constraint-valid
    local upCurrentLocal = upLocal   -- Input up vector

    local upFinalClampedLocal = upCurrentLocal:clone() -- Start with current up

    if applyTwistLimit then
        -- 1. Define a "no-twist" reference up vector.
        local twistRefUp = vec3()
        local twistRefCalcSuccess = false

        -- Try convention-specific / geometric reference first for Y_Fwd_Z_Up
        if convention == "Y_Fwd_Z_Up" and coneAxisLocal then
            -- Base twist reference geometrically on the cone axis and the forward direction.
            twistRefUp = math.cross(fwdClampedLocal, coneAxisLocal, twistRefUp)
            if twistRefUp:lengthSquared() > epsilon * epsilon then
                twistRefUp:normalize()
                twistRefCalcSuccess = true
                -- print("IK Twist Ref: Using ConeAxis geometric method for Y_Fwd_Z_Up") -- Debug
            else
                 print("IK Twist WARN: fwd parallel to cone axis for Y_Fwd_Z_Up, using fallback.")
            end
        end

        -- Default/Fallback: Use Parent Z-axis
        if not twistRefCalcSuccess then
            -- print("IK Twist Ref: Using Parent Z method") -- Debug
            local parentUpAxis = vec3(0, 0, 1) -- Parent's Local Z
            twistRefUp = parentUpAxis - fwdClampedLocal * fwdClampedLocal:dot(parentUpAxis)
            if twistRefUp:lengthSquared() > epsilon * epsilon then
                twistRefUp:normalize()
                twistRefCalcSuccess = true
            else
                 print("IK Twist WARN: Parent Z parallel to clamped forward, using ultimate fallback.")
                 -- Ultimate fallback if parent Z is also parallel
                 local nonParallelVec = math.abs(fwdClampedLocal.x) > 0.9 and vec3(0,1,0) or vec3(1,0,0)
                 twistRefUp = math.cross(fwdClampedLocal, nonParallelVec):normalize()
                 twistRefCalcSuccess = true -- Assume fallback always works
            end
        end

        -- 2. Project current up vector onto twist plane
        local upProj = upCurrentLocal - fwdClampedLocal * fwdClampedLocal:dot(upCurrentLocal)
        local upProjLen = upProj:length()

        -- 3. Calculate signed twist angle
        local currentTwistAngle = 0
        if upProjLen > epsilon then
            upProj:scale(1.0 / upProjLen) -- Normalize
            local angle_cos = math.clamp(twistRefUp:dot(upProj), -1.0, 1.0)
            local angle = math.acos(angle_cos)
            local sign_dot = fwdClampedLocal:dot(math.cross(twistRefUp, upProj))
            currentTwistAngle = (sign_dot >= 0) and angle or -angle
        end

        -- 4. Clamp twist angle
        local clampedTwistAngle = math.clamp(currentTwistAngle, minTwistAngleRad, maxTwistAngleRad)

        -- 5. Apply twist correction
        local twistDiff = clampedTwistAngle - currentTwistAngle
        if math.abs(twistDiff) > epsilon then
            local q_twist_correction = quat.fromAngleAxis(twistDiff, fwdClampedLocal)
            upFinalClampedLocal = upCurrentLocal:clone():rotate(q_twist_correction)
        end
    end

    -- === Part 3: Final Orthogonalization === (Ensures result is valid basis)
    fwdClampedLocal:normalize()
    local right = math.cross(upFinalClampedLocal, fwdClampedLocal)
    if right:lengthSquared() < epsilon * epsilon then
        local nonParallelVec = math.abs(fwdClampedLocal.x) > 0.9 and vec3(0,1,0) or vec3(1,0,0)
        right = math.cross(nonParallelVec, fwdClampedLocal):normalize()
    else
        right:normalize()
    end
    local upFinal = math.cross(fwdClampedLocal, right):normalize()

    return fwdClampedLocal, upFinal -- Return fwd (unchanged) and corrected/orthogonalized up
end

--- Solves Inverse Kinematics for a 2-joint arm using FABRIK.
-- Accepts parameters via a single table.
--
-- @param params table A table containing the following fields:
--   - baseRef (ac.SceneReference): REQUIRED. The fixed base node of the IK chain.
--   - arm1Ref (ac.SceneReference): REQUIRED. The first rotating joint node (e.g., shoulder/upper arm).
--   - arm2Ref (ac.SceneReference): REQUIRED. The second rotating joint node (e.g., elbow/forearm).
--   - tipRef (ac.SceneReference): REQUIRED. The end effector node. The `fixerOffset` is applied relative to this node's transform.
--   - targetPosPlatform (vec3): REQUIRED. Target position for the offset tip point, specified in the coordinate system of the ancestor node found via `treeDepth`.
--   - iterations (integer?): Optional. Maximum number of FABRIK iterations (default: 10).
--   - tolerance (number?): Optional. Position tolerance for FABRIK convergence (default: 0.01 world units).
--   - arm1Convention (string?): Optional. Local axis convention for `arm1Ref` ("Z_Fwd_Y_Up" or "Y_Fwd_Z_Up", default: "Z_Fwd_Y_Up").
--   - arm2Convention (string?): Optional. Local axis convention for `arm2Ref` ("Z_Fwd_Y_Up" or "Y_Fwd_Z_Up", default: "Z_Fwd_Y_Up").
--   - treeDepth (integer?): Optional. Number of levels to traverse up from `baseRef` to find the reference node for `targetPosPlatform` (default: 2).
--   - arm1ConstraintType (string?): Optional. Constraint type for arm1 ("none", "cone"). Default: "none".
--   - arm1ConeAxisLocal (vec3?): Optional. Local axis in `baseRef`'s space for the cone center (e.g., vec3(0,1,0)). Default: vec3(0,1,0).
--   - arm1MaxConeAngle (number?): Optional. Max angle (degrees) from cone axis. Default: 180.
--   - arm2ConstraintType (string?): Optional. Constraint type for arm2 ("none", "hinge"). Default: "none".
--   - arm2HingeAxisLocal (vec3?): Optional. Local axis in `arm1Ref`'s space for the hinge (e.g., vec3(1,0,0)). Default: vec3(1,0,0).
--   - arm2MinHingeAngle (number?): Optional. Min hinge angle (degrees). Default: -180.
--   - arm2MaxHingeAngle (number?): Optional. Max hinge angle (degrees). Default: 180.
--   - arm1MinTwistAngle (number?): Optional. Min twist angle (degrees) around arm1's main axis. Default: -90. Requires arm1ConstraintType = "cone".
--   - arm1MaxTwistAngle (number?): Optional. Max twist angle (degrees) around arm1's main axis. Default: 90. Requires arm1ConstraintType = "cone".
--   - arm2MinTwistAngle (number?): Optional. Min twist angle (degrees) around arm2's main axis. Default: 0. Requires arm2ConstraintType = "hinge".
--   - arm2MaxTwistAngle (number?): Optional. Max twist angle (degrees) around arm2's main axis. Default: 0. Requires arm2ConstraintType = "hinge".
local function solveFabrik2Joint(params)
    -- Validate required parameters
    if not params or not params.baseRef or not params.arm1Ref or not params.arm2Ref or not params.tipRef or not params.targetPosPlatform then
        print("IK Error: Missing required parameters in params table.")
        if params then
             print("Provided params:", params.baseRef, params.arm1Ref, params.arm2Ref, params.tipRef, params.targetPosPlatform)
        end
        return
    end

    -- Extract parameters with defaults
    local baseRef = params.baseRef
    local arm1Ref = params.arm1Ref
    local arm2Ref = params.arm2Ref
    local tipRef = params.tipRef
    local targetPosPlatform = params.targetPosPlatform
    local iterations = params.iterations or 10
    local tolerance = params.tolerance or 0.01
    local arm1Convention = params.arm1Convention or "Z_Fwd_Y_Up"
    local arm2Convention = params.arm2Convention or "Z_Fwd_Y_Up"
    local treeDepth = params.treeDepth or 2
    -- Constraint parameters
    local arm1ConstraintType = params.arm1ConstraintType or "none"
    local arm1ConeAxisLocal = params.arm1ConeAxisLocal or vec3(0, 1, 0)
    local arm1MaxConeAngleRad = math.rad(params.arm1MaxConeAngle or 180)
    local arm1MinTwistAngleRad = math.rad(params.arm1MinTwistAngle or -90)
    local arm1MaxTwistAngleRad = math.rad(params.arm1MaxTwistAngle or 90)
    local arm2ConstraintType = params.arm2ConstraintType or "none"
    local arm2HingeAxisLocal = params.arm2HingeAxisLocal or vec3(1, 0, 0)
    local arm2MinHingeAngleRad = math.rad(params.arm2MinHingeAngle or -180)
    local arm2MaxHingeAngleRad = math.rad(params.arm2MaxHingeAngle or 180)
    local arm2MinTwistAngleRad = math.rad(params.arm2MinTwistAngle or 0) -- Default to no twist for elbow
    local arm2MaxTwistAngleRad = math.rad(params.arm2MaxTwistAngle or 0) -- Default to no twist for elbow

    -- Large offset applied to the tip node's transform. Intended to increase floating-point precision
    -- during FABRIK calculations by working with larger numbers further from the origin, then canceled out.
    local fixerOffset = vec3(1000000, 1000000, 1000000)

    -- Simplified Logging Setup
    local logBuffer = {}
    local log = function(key, value) table.insert(logBuffer, string.format("[%s]: %s", key, tostring(value))) end
    local logVec3 = function(key, v) log(key, v and string.format("%.4f, %.4f, %.4f", v.x, v.y, v.z) or "nil") end
    local logMat4 = function(key, m) log(key .. " (Mat4)", m and tostring(m) or "nil") end -- Keep matrix log for debugging complex issues

    local epsilon = 1e-8 -- Small value for float comparisons

    -- === 0. Initial Setup & Reference Frames ===
    log("--- IK Start ---", string.format("Iterations=%d, Tolerance=%.4f, TreeDepth=%d", iterations, tolerance, treeDepth))

    -- Find the ancestor node used as the coordinate system for the target position
    local targetReferenceNode = baseRef
    for i = 1, treeDepth do
        if targetReferenceNode then targetReferenceNode = targetReferenceNode:getParent() else
            log("IK Error", "Nil parent found traversing treeDepth at level " .. i); print(table.concat(logBuffer, "\n")); return
        end
    end
    if not targetReferenceNode then log("IK Error", "Target reference node nil after traversing depth"); print(table.concat(logBuffer, "\n")); return end

    local T_targetReference_world = targetReferenceNode:getWorldTransformationRaw()
    if not T_targetReference_world then log("IK Error", "Target reference node has no world transform"); print(table.concat(logBuffer, "\n")); return end
    -- logMat4("T_targetReference_world", T_targetReference_world) -- Optional: Log if debugging target space issues

    -- Get current world transform of the base's immediate parent (platform)
    local platformRef = baseRef:getParent()
    if not platformRef then log("IK Error", "Base node has no parent"); print(table.concat(logBuffer, "\n")); return end
    -- Note: T_platform_world is NOT used for the target, but T_base_world is needed later.
    -- local T_platform_world = platformRef:getWorldTransformationRaw()
    -- if not T_platform_world then log("IK Error", "Base parent has no world transform"); print(table.concat(logBuffer, "\n")); return end

    -- === 1. Get Original Local Positions & Current World State ===
    local O_arm1_base_orig = arm1Ref:getPosition()
    local O_arm2_arm1_orig = arm2Ref:getPosition()
    logVec3("Original Local Pos Arm1", O_arm1_base_orig)
    logVec3("Original Local Pos Arm2", O_arm2_arm1_orig)

    local T_base_world_current = baseRef:getWorldTransformationRaw()
    local T_arm1_world_current = arm1Ref:getWorldTransformationRaw()
    local T_arm2_world_current = arm2Ref:getWorldTransformationRaw()
    local T_tip_world_current  = tipRef:getWorldTransformationRaw()

    if not T_base_world_current or not T_arm1_world_current or not T_arm2_world_current or not T_tip_world_current then
        log("IK Error", "Missing initial world transformations for chain nodes.")
        print(table.concat(logBuffer, "\n"))
        return
    end

    -- === 1.5 Calculate Base Inverse Transform (needed in loop and later) ===
    local T_inv_base_world_current = T_base_world_current:inverse()
    if not T_inv_base_world_current then log("IK Error", "Failed to invert Base world matrix"); print(table.concat(logBuffer, "\n")); return end

    -- === 2. Initialize FABRIK Points ===
    -- Calculate the world position of the offset tip point using the large `fixerOffset`
    local initialOffsetTipWorld = T_tip_world_current:transformPoint(fixerOffset)
    logVec3("Initial Arm1 World Pos", T_arm1_world_current.position)
    logVec3("Initial Arm2 World Pos", T_arm2_world_current.position)
    logVec3("Initial Offset Tip World Pos", initialOffsetTipWorld)

    -- FABRIK operates on these world space points: Shoulder, Elbow, OffsetTip
    local p = {
        T_arm1_world_current.position:clone(),
        T_arm2_world_current.position:clone(),
        initialOffsetTipWorld:clone()
    }
    local chainRootPos = p[1]:clone() -- World position of the first *movable* joint (Arm1)

    -- === 3. Calculate Segment Lengths ===
    local l = { math.distance(p[2], p[1]), math.distance(p[3], p[2]) }
    if l[1] < epsilon or l[2] < epsilon then
        log("IK Warning", "Segment length near zero. l1="..l[1]..", l2="..l[2]); -- Return might be too strict, allow attempt
    end
    local totalLength = l[1] + l[2]
    log("Segment Lengths", string.format("l1=%.4f, l2=%.4f (Total=%.4f)", l[1], l[2], totalLength))

    -- === 4. Calculate Target World Position ===
    local targetWorld = T_targetReference_world:transformPoint(targetPosPlatform)
    logVec3("Target Platform Pos (Input)", targetPosPlatform)
    logVec3("Target World Pos (Raw)", targetWorld)

    -- === 5. Check Reachability & Clamp Target ===
    local distRootToTarget = math.distance(targetWorld, chainRootPos)
    if distRootToTarget > totalLength * (1 + epsilon) then
        local oldTarget = targetWorld:clone()
        targetWorld = chainRootPos + (targetWorld - chainRootPos):normalize() * totalLength
        logVec3("Target World Pos (Clamped)", targetWorld)
        -- logVec3("Target Original (Out of Reach)", oldTarget) -- Optional detail
    end

    -- === 6. FABRIK Iteration Loop ===
    local initialDist = math.distance(p[3], targetWorld)
    local iter = 0
    local getDir = function(from, to) -- Helper to get normalized direction safely
        local dir = to - from
        return (dir:lengthSquared() > epsilon * epsilon) and dir:normalize() or vec3(0, 0, 1) -- Use Z axis as fallback
    end

    -- Temporary vectors for intra-loop constraints
    local temp_dir_world = vec3()
    local temp_dir_local = vec3()
    local temp_clamped_dir_local = vec3()
    local temp_clamped_dir_world = vec3()
    local temp_rotationAxis = vec3()
    local temp_q = quat()
    -- Temp transforms for Arm2 hinge
    local temp_T_arm1_world = mat4x4()
    local temp_T_inv_arm1_world = mat4x4()
    local temp_ref_perp = vec3()
    local temp_fwd_perp = vec3()

    while math.distance(p[3], targetWorld) > tolerance and iter < iterations do
        -- Backward pass: Constrain towards root
        p[3] = targetWorld
        p[2] = p[3] - getDir(p[3], p[2]) * l[2]
        p[1] = p[2] - getDir(p[2], p[1]) * l[1]

        -- Forward pass: Constrain away from root
        p[1] = chainRootPos
        p[2] = p[1] + getDir(p[1], p[2]) * l[1]

        -- >>> Intra-Loop Constraint: Arm 1 Cone <<<
        if arm1ConstraintType == "cone" and arm1MaxConeAngleRad < (math.pi - epsilon) then
            temp_dir_world = p[2] - p[1] -- Direction of arm1 segment
            if temp_dir_world:lengthSquared() > epsilon * epsilon then
                temp_dir_world:normalize()
                -- Transform direction into parent's (baseRef) local space
                temp_dir_local = T_inv_base_world_current:transformVector(temp_dir_world, temp_dir_local):normalize()

                -- Check angle against cone axis
                local angle_dot = math.clamp(temp_dir_local:dot(arm1ConeAxisLocal), -1.0, 1.0)
                local current_cone_angle = math.acos(angle_dot)

                -- [[ Add Cone Debug Logs ]]
                if params.debug then -- Only log if debug is enabled
                    log("Iter "..iter.." ConeCheck", "-------------------------")
                    logVec3("Iter "..iter.." ConeCheck", temp_dir_local)
                    logVec3("Iter "..iter.." ConeAxis ", arm1ConeAxisLocal)
                    log("Iter "..iter.." ConeAngle", string.format("Current: %.2f, Max: %.2f", math.deg(current_cone_angle), math.deg(arm1MaxConeAngleRad)))
                end

                if current_cone_angle > arm1MaxConeAngleRad then
                     if params.debug then log("Iter "..iter.." ConeClamp", "!!! CLAMPING (New Method) !!!") end
                    -- Clamp is needed
                    -- Calculate the rotation axis perpendicular to the cone axis and the current direction
                    temp_rotationAxis = math.cross(arm1ConeAxisLocal, temp_dir_local, temp_rotationAxis)

                    if temp_rotationAxis:lengthSquared() > epsilon * epsilon then
                        temp_rotationAxis:normalize()
                        -- Rotate the CONE AXIS by the MAX ANGLE around the rotation axis
                        -- This gives the target direction on the edge of the cone boundary.
                        temp_q = quat.fromAngleAxis(arm1MaxConeAngleRad, temp_rotationAxis, temp_q)
                        temp_clamped_dir_local = arm1ConeAxisLocal:clone():rotate(temp_q) -- Start from cone axis and rotate outwards

                        if params.debug then
                            log("Iter "..iter.." ConeClamp", string.format("TargetAngle: %.2f", math.deg(arm1MaxConeAngleRad)))
                            logVec3("Iter "..iter.." ConeClamp", temp_rotationAxis)
                            logVec3("Iter "..iter.." ConeClamp", temp_clamped_dir_local)
                        end
                    else
                        -- Aligned or anti-aligned
                        if angle_dot < -0.9999 then -- Anti-aligned
                           if params.debug then log("Iter "..iter.." ConeClamp", "Anti-Parallel Case (New Method)") end
                           -- The direction is opposite the cone axis. Pick *any* direction on the cone boundary.
                           -- Need a perpendicular axis to rotate around.
                           local nonParallel = math.abs(arm1ConeAxisLocal.x) > 0.9 and vec3(0,1,0) or vec3(1,0,0)
                           temp_rotationAxis = math.cross(arm1ConeAxisLocal, nonParallel, temp_rotationAxis):normalize()
                           temp_q = quat.fromAngleAxis(arm1MaxConeAngleRad, temp_rotationAxis, temp_q)
                           temp_clamped_dir_local = arm1ConeAxisLocal:clone():rotate(temp_q)

                           if params.debug then
                               log("Iter "..iter.." ConeClamp", string.format("TargetAngle: %.2f", math.deg(arm1MaxConeAngleRad)))
                               logVec3("Iter "..iter.." ConeClamp", temp_rotationAxis)
                               logVec3("Iter "..iter.." ConeClamp", temp_clamped_dir_local)
                           end
                        else -- Aligned (Shouldn't happen if current_cone_angle > max)
                           if params.debug then log("Iter "..iter.." ConeClamp", "Aligned Case (Using Cone Axis)") end
                           -- If somehow it's perfectly aligned but angle > max (impossible?), just use cone axis.
                           temp_clamped_dir_local:set(arm1ConeAxisLocal)
                        end
                    end

                    -- Transform clamped direction back to world space
                    temp_clamped_dir_world = T_base_world_current:transformVector(temp_clamped_dir_local, temp_clamped_dir_world):normalize()
                    -- Update p[2] position based on clamped direction
                    p[2] = p[1] + temp_clamped_dir_world * l[1]
                    if params.debug then
                        logVec3("Iter "..iter.." ConeClamp", temp_clamped_dir_world)
                        logVec3("Iter "..iter.." ConeClamp", p[2])
                    end
                end
                 if params.debug then log("Iter "..iter.." ConeCheck", "-------------------------") end
            end
        end
        -- >>> End Intra-Loop Constraint <<<

        -- Update p[3] BEFORE Arm2 constraints
        p[3] = p[2] + getDir(p[2], p[3]) * l[2]

        -- >>> Intra-Loop Constraint: Arm 2 Hinge <<<
        if arm2ConstraintType == "hinge" and (arm2MinHingeAngleRad > -math.pi + epsilon or arm2MaxHingeAngleRad < math.pi - epsilon) then
             -- Need Arm1's *current* transform in the loop to get Arm2's local space
             temp_T_arm1_world = buildWorldTransformLookingAt(p[1], p[2], nil, epsilon, arm1Convention)
             temp_T_inv_arm1_world = temp_T_arm1_world:inverse()

             if temp_T_inv_arm1_world then
                 temp_dir_world = p[3] - p[2] -- Direction of arm2 segment
                 if temp_dir_world:lengthSquared() > epsilon * epsilon then
                    temp_dir_world:normalize()
                    -- Transform direction into parent's (arm1Ref) current local space
                    temp_dir_local = temp_T_inv_arm1_world:transformVector(temp_dir_world, temp_dir_local):normalize()

                    -- Hinge Logic (Adapted from clampOrientationToHingeAndTwist Part 1)
                    -- 1. Define reference perpendicular direction (using parent's Z or Y)
                    local parent_axis_ref
                    if math.abs(arm2HingeAxisLocal.z) < (1.0 - epsilon) then parent_axis_ref = vec3(0,0,1) -- Prefer Z
                    else parent_axis_ref = vec3(0,1,0) end -- Use Y if hinge is aligned with Z

                    local dot_ref = arm2HingeAxisLocal:dot(parent_axis_ref)
                    if math.abs(dot_ref) < (1.0 - epsilon) then
                         temp_ref_perp = parent_axis_ref - arm2HingeAxisLocal * dot_ref
                    else -- Hinge parallel to preferred axis, try the other one
                        local fallback_ref = (parent_axis_ref.z > 0.5) and vec3(0,1,0) or vec3(0,0,1)
                        local dot_fallback = arm2HingeAxisLocal:dot(fallback_ref)
                         if math.abs(dot_fallback) < (1.0 - epsilon) then
                              temp_ref_perp = fallback_ref - arm2HingeAxisLocal * dot_fallback
                         else -- Truly parallel to both Y and Z (e.g. X hinge), use arbitrary
                              temp_ref_perp = vec3(0,0,1) -- Fallback
                         end
                    end
                    if temp_ref_perp:lengthSquared() < epsilon * epsilon then temp_ref_perp:set(0,1,0):normalize() -- Final fallback
                    else temp_ref_perp:normalize() end

                    -- 2. Project Arm2 local dir onto hinge plane
                    temp_fwd_perp = temp_dir_local - arm2HingeAxisLocal * temp_dir_local:dot(arm2HingeAxisLocal)
                    local fwd_perp_len_sq = temp_fwd_perp:lengthSquared()

                    -- 3. Calculate signed angle relative to ref_perp
                    local signed_angle = 0
                    if fwd_perp_len_sq > epsilon * epsilon then
                        temp_fwd_perp:scale(1.0 / math.sqrt(fwd_perp_len_sq)) -- Normalize
                        local angle_cos = math.clamp(temp_ref_perp:dot(temp_fwd_perp), -1.0, 1.0)
                        local angle = math.acos(angle_cos)
                        local sign_dot = arm2HingeAxisLocal:dot(math.cross(temp_ref_perp, temp_fwd_perp))
                        signed_angle = (sign_dot >= 0) and angle or -angle
                    end

                    -- 4. Clamp hinge angle
                    local clamped_angle = math.clamp(signed_angle, arm2MinHingeAngleRad, arm2MaxHingeAngleRad)

                    -- 5. Check if clamping is needed
                    if math.abs(clamped_angle - signed_angle) > epsilon then
                        if params.debug then log("Iter "..iter.." HingeClamp", string.format("!!! CLAMPING Angle: %.2f -> %.2f !!!", math.deg(signed_angle), math.deg(clamped_angle))) end
                        -- Apply rotation to original local direction
                        temp_q = quat.fromAngleAxis(clamped_angle - signed_angle, arm2HingeAxisLocal)
                        temp_clamped_dir_local = temp_dir_local:clone():rotate(temp_q)

                        -- Transform clamped direction back to world space
                        temp_clamped_dir_world = temp_T_arm1_world:transformVector(temp_clamped_dir_local, temp_clamped_dir_world):normalize()
                        -- Update p[3] position based on clamped direction
                        p[3] = p[2] + temp_clamped_dir_world * l[2]
                        if params.debug then
                            logVec3("Iter "..iter.." HingeClamp", temp_clamped_dir_local)
                            logVec3("Iter "..iter.." HingeClamp", temp_clamped_dir_world)
                            logVec3("Iter "..iter.." HingeClamp", p[3])
                        end
                    end
                 end
             else
                  if params.debug then log("Iter "..iter.." HingeClamp","WARN: Failed to get inv Arm1 transform in loop") end
             end
        end
        -- >>> End Intra-Loop Hinge Constraint <<<

        iter = iter + 1
    end
    local finalDist = math.distance(p[3], targetWorld)
    log("FABRIK Result", string.format("Iterations=%d, InitialDist=%.4f, FinalDist=%.4f", iter, initialDist, finalDist))
    logVec3("Final Arm1 World Pos (FABRIK)", p[1])
    logVec3("Final Arm2 World Pos (FABRIK)", p[2])
    logVec3("Final Offset Tip World Pos (FABRIK)", p[3])

    -- === 7. Calculate Target World Transforms for Joints ===
    -- Use the solved FABRIK points to determine the desired world orientation for each joint.
    -- Pass the convention to influence the default worldUpHint used inside the function.
    local T_target_arm1_world = buildWorldTransformLookingAt(p[1], p[2], nil, epsilon, arm1Convention) -- Arm1 looks at Arm2
    local T_target_arm2_world = buildWorldTransformLookingAt(p[2], p[3], nil, epsilon, arm2Convention) -- Arm2 looks towards the final offset tip position
    -- logMat4("T_target_arm1_world", T_target_arm1_world) -- Optional detail
    -- logMat4("T_target_arm2_world", T_target_arm2_world) -- Optional detail

    -- === 8. Calculate Required Local Orientations ===
    -- Convert the target world orientations into the local space of each joint's parent.

    -- Arm 1 (Parent is Base)
    local T_inv_base_world_current = T_base_world_current:inverse()
    if not T_inv_base_world_current then log("IK Error", "Failed to invert Base world matrix"); print(table.concat(logBuffer, "\n")); return end

    -- Extract target world axes (Right, Up, Forward correspond to X, Y, Z of the standard matrix)
    local R1_tgt_world = vec3(T_target_arm1_world.row1.x, T_target_arm1_world.row1.y, T_target_arm1_world.row1.z):normalize()
    local U1_tgt_world = vec3(T_target_arm1_world.row2.x, T_target_arm1_world.row2.y, T_target_arm1_world.row2.z):normalize()
    local F1_tgt_world = vec3(T_target_arm1_world.row3.x, T_target_arm1_world.row3.y, T_target_arm1_world.row3.z):normalize()

    -- Transform target world axes into Base's local space
    local R1_req_local = T_inv_base_world_current:transformVector(R1_tgt_world):normalize()
    local U1_req_local = T_inv_base_world_current:transformVector(U1_tgt_world):normalize()
    local F1_req_local = T_inv_base_world_current:transformVector(F1_tgt_world):normalize()
    -- Re-orthogonalize F and U after transformation (F = R x U, U = F x R - slight drift possible)
    F1_req_local = math.cross(R1_req_local, U1_req_local):normalize()
    U1_req_local = math.cross(F1_req_local, R1_req_local):normalize()

    -- Arm 2 (Parent is Arm1 - Use Arm1's CURRENT world inverse for stability)
    local T_inv_arm1_world_current = T_arm1_world_current:inverse()
    if not T_inv_arm1_world_current then log("IK Error", "Failed to invert Arm1 current world matrix"); print(table.concat(logBuffer, "\n")); return end

    -- Extract target world axes
    local R2_tgt_world = vec3(T_target_arm2_world.row1.x, T_target_arm2_world.row1.y, T_target_arm2_world.row1.z):normalize()
    local U2_tgt_world = vec3(T_target_arm2_world.row2.x, T_target_arm2_world.row2.y, T_target_arm2_world.row2.z):normalize()
    local F2_tgt_world = vec3(T_target_arm2_world.row3.x, T_target_arm2_world.row3.y, T_target_arm2_world.row3.z):normalize()

    -- Transform target world axes into Arm1's CURRENT local space
    local R2_req_local = T_inv_arm1_world_current:transformVector(R2_tgt_world):normalize()
    local U2_req_local = T_inv_arm1_world_current:transformVector(U2_tgt_world):normalize()
    local F2_req_local = T_inv_arm1_world_current:transformVector(F2_tgt_world):normalize()
    -- Re-orthogonalize
    F2_req_local = math.cross(R2_req_local, U2_req_local):normalize()
    U2_req_local = math.cross(F2_req_local, R2_req_local):normalize()

    -- === 8.5 Apply Constraints (Post-Solve Twist/Hinge) ===
    log("--- Applying Constraints ---", "")
    -- Clamp Arm 1 Orientation (Shoulder) - ONLY applies TWIST relative to a reference (ConeAxis for Y_Fwd_Z_Up)
    local F1_clamped_local=F1_req_local:clone(); local U1_clamped_local=U1_req_local:clone()
    if arm1ConstraintType=="cone" then -- Still use "cone" type to trigger twist constraint
        log("Arm1 Constraint","Applying Post-Solve Twist Limit (Rel Reference)...")
        -- Use the cone twist function
        F1_clamped_local,U1_clamped_local=clampTwistRelativeToReference(
            F1_req_local, U1_req_local,
            true, arm1MinTwistAngleRad, arm1MaxTwistAngleRad,
            epsilon,
            arm1Convention, -- Pass convention
            arm1ConeAxisLocal -- Pass cone axis
        )
    elseif arm1ConstraintType~="none" then log("IK Warning","Unsupported arm1ConstraintType: "..arm1ConstraintType) end

    -- Clamp Arm 2 Orientation (Elbow) - ONLY applies TWIST relative to a reference (Parent Up for Y_Fwd_Z_Up)
    local F2_clamped_local=F2_req_local:clone(); local U2_clamped_local=U2_req_local:clone()
    if arm2ConstraintType=="hinge" then
        local applyArm2Twist=(arm2MinTwistAngleRad~=0 or arm2MaxTwistAngleRad~=0)
        if applyArm2Twist then
            log("Arm2 Constraint","Applying Post-Solve Twist Limit (Rel Reference)...")
             -- Use the new hinge twist function, passing Arm1's convention
            F2_clamped_local,U2_clamped_local=clampTwistRelativeToReference(
                F2_req_local, U2_req_local,
                true, arm2MinTwistAngleRad, arm2MaxTwistAngleRad,
                epsilon,
                arm1Convention, -- Pass PARENT'S convention (Arm1)
                arm2HingeAxisLocal -- Pass hinge axis for potential fallback
            )
        else
            log("Arm2 Constraint","Hinge angle applied in loop, no twist needed.")
            -- Hinge angle was done in loop, Fwd/Up vectors from Step 8 are used directly
        end
    elseif arm2ConstraintType~="none" then log("IK Warning","Unsupported arm2ConstraintType: "..arm2ConstraintType) end

    -- === 9. Apply Orientation & Original Position ===
    log("--- Applying Transforms ---", "")

    -- Apply to Arm 1
    local arm1_fwd_vec_apply, arm1_up_vec_apply -- Vectors to pass to setOrientation
    -- Use arm1Convention variable extracted from params
    log("Arm1 Convention", arm1Convention)

    if arm1Convention == "Z_Fwd_Y_Up" then
        -- Local Fwd=Z, Local Up=Y. Map CLAMPED local F->Fwd(Node Z), U->Up(Node Y).
        arm1_fwd_vec_apply = F1_clamped_local
        arm1_up_vec_apply = U1_clamped_local
    elseif arm1Convention == "Y_Fwd_Z_Up" then
        -- Local Fwd=Y, Local Up=Z. Map CLAMPED local U->Fwd(Node Z), F->Up(Node Y).
        -- REVERTING TO EMPIRICAL NEGATION based on stability feedback
        arm1_fwd_vec_apply = -U1_clamped_local
        arm1_up_vec_apply = -F1_clamped_local
        log("Arm1", "(Applying NEGATED CLAMPED U as Fwd(Node Z), NEGATED CLAMPED F as Up(Node Y))")
    else
        log("IK Error", "Unknown arm1Convention: " .. arm1Convention); arm1_fwd_vec_apply = nil
    end

    if arm1Ref and arm1_fwd_vec_apply and arm1_up_vec_apply then
        -- Ensure vectors are valid before setting
        if arm1_fwd_vec_apply:lengthSquared() > epsilon and arm1_up_vec_apply:lengthSquared() > epsilon and math.abs(arm1_fwd_vec_apply:dot(arm1_up_vec_apply)) < (1 - epsilon) then
            arm1Ref:setOrientation(arm1_fwd_vec_apply, arm1_up_vec_apply)
            arm1Ref:setPosition(O_arm1_base_orig) -- Restore original local position
            log("Arm1", "Applied Clamped Orientation & Original Position")
        else
            log("IK Error", "Failed to apply transform to Arm1 (invalid vectors after clamping/convention)")
            logVec3("Arm1 Invalid Fwd", arm1_fwd_vec_apply)
            logVec3("Arm1 Invalid Up", arm1_up_vec_apply)
        end
    else
        log("IK Error", "Failed to apply transform to Arm1 (nil vectors or ref)")
    end

    -- Apply to Arm 2
    local arm2_fwd_vec_apply, arm2_up_vec_apply
    -- Use arm2Convention variable extracted from params
    log("Arm2 Convention", arm2Convention)

    if arm2Convention == "Z_Fwd_Y_Up" then
        -- Local Fwd=Z, Local Up=Y. Map CLAMPED local F->Fwd(Node Z), U->Up(Node Y).
        arm2_fwd_vec_apply = F2_clamped_local
        arm2_up_vec_apply = U2_clamped_local
    elseif arm2Convention == "Y_Fwd_Z_Up" then
        -- Local Fwd=Y, Local Up=Z. Map CLAMPED local U->Fwd(Node Z), F->Up(Node Y).
        -- REVERTING TO EMPIRICAL NEGATION based on stability feedback
        arm2_fwd_vec_apply = -U2_clamped_local
        arm2_up_vec_apply = -F2_clamped_local
        log("Arm2", "(Applying NEGATED CLAMPED U as Fwd(Node Z), NEGATED CLAMPED F as Up(Node Y))")
    else
        log("IK Error", "Unknown arm2Convention: " .. arm2Convention); arm2_fwd_vec_apply = nil
    end

    if arm2Ref and arm2_fwd_vec_apply and arm2_up_vec_apply then
        -- Ensure vectors are valid before setting
         if arm2_fwd_vec_apply:lengthSquared() > epsilon and arm2_up_vec_apply:lengthSquared() > epsilon and math.abs(arm2_fwd_vec_apply:dot(arm2_up_vec_apply)) < (1 - epsilon) then
            arm2Ref:setOrientation(arm2_fwd_vec_apply, arm2_up_vec_apply)
            arm2Ref:setPosition(O_arm2_arm1_orig) -- Restore original local position
            log("Arm2", "Applied Clamped Orientation & Original Position")
        else
            log("IK Error", "Failed to apply transform to Arm2 (invalid vectors after clamping/convention)")
            logVec3("Arm2 Invalid Fwd", arm2_fwd_vec_apply)
            logVec3("Arm2 Invalid Up", arm2_up_vec_apply)
         end
    else
        log("IK Error", "Failed to apply transform to Arm2 (nil vectors or ref)")
    end

    -- === 10. Final Verification (Optional) ===
    log("--- Verification ---", "")
    local T_tip_world_final = tipRef:getWorldTransformationRaw()
    local finalOffsetTipPos = T_tip_world_final and T_tip_world_final:transformPoint(fixerOffset) or nil
    if finalOffsetTipPos then
    logVec3("VERIFY Target World (Clamped)", targetWorld)
        logVec3("VERIFY Final Offset Tip Pos (Direct Read)", finalOffsetTipPos)
        log("VERIFY Final Distance to Target", math.distance(targetWorld, finalOffsetTipPos))
    else
        log("IK Verify Error", "Could not get final tip world transform.")
    end

    -- Print all logs for the frame
    if params.debug then print("--- IK Log Frame ---\n" .. table.concat(logBuffer, "\n")) end -- Enable for detailed debugging
end -- End of solveFabrik2Joint


return solveFabrik2Joint
