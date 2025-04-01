--- Creates a 4x4 WORLD transformation matrix at a position, oriented along a primary axis.
-- **MODIFIED: Assumes the 'forward' direction aligns with the LOCAL +X axis.**
-- @param originWorld vec3 The desired world origin for the matrix.
-- @param lookTargetWorld vec3 The world point to look towards.
-- @param worldUpHint vec3? A world-space up vector hint (default: 0,1,0).
-- @param epsilon number? Small value for float comparisons.
-- @return mat4x4 The calculated world transformation matrix.
local function buildWorldTransformLookingAt(originWorld, lookTargetWorld, worldUpHint, epsilon)
    local forward = lookTargetWorld - originWorld
    epsilon = epsilon or 1e-6
    if forward:lengthSquared() < epsilon * epsilon then
        print("IK WARN buildWorldTransformLookingAt: forward vector too small!", forward)
        local m = mat4x4.identity()
        m.position = originWorld
        return m
    end
    forward = math.normalize(forward)
    local temp_up = worldUpHint or vec3(0, 1, 0)
    local dotProduct = math.dot(forward, temp_up)
    if math.abs(dotProduct) > (1.0 - epsilon) then
        temp_up = vec3(1, 0, 0)
        dotProduct = math.dot(forward, temp_up)
        if math.abs(dotProduct) > (1.0 - epsilon) then
             temp_up = vec3(0, 0, 1)
        end
    end
    local right = math.normalize(math.cross(temp_up, forward))
    local up = math.normalize(math.cross(forward, right))
    if right:lengthSquared() < epsilon or up:lengthSquared() < epsilon then
         print("IK WARN buildWorldTransformLookingAt: right or up vector collapsed!", right, up)
    end
    return mat4x4(
        vec4(right.x,   right.y,   right.z,   0),
        vec4(up.x,      up.y,      up.z,      0),
        vec4(forward.x, forward.y, forward.z, 0),
        vec4(originWorld.x, originWorld.y, originWorld.z, 1)
    )
end

-- Helper function to orthonormalize the 3x3 rotation part of a 4x4 matrix
-- Uses Gram-Schmidt process. Assumes input matrix 'm' exists.
-- Preserves the position component of the input matrix.
local function orthonormalizeRotation(m)
    -- Extract basis vectors (rows of the rotation part)
    local row1 = vec3(m.row1.x, m.row1.y, m.row1.z)
    local row2 = vec3(m.row2.x, m.row2.y, m.row2.z)
    local row3 = vec3(m.row3.x, m.row3.y, m.row3.z)
    local epsilon = 1e-6 -- Threshold for normalization checks

    -- Orthonormalize, checking for zero length vectors
    local len1 = row1:length()
    if len1 > epsilon then row1 = row1 / len1 else row1 = vec3(1,0,0) end -- Default if zero

    row2 = row2 - row1 * row1:dot(row2)
    local len2 = row2:length()
    if len2 > epsilon then row2 = row2 / len2 else row2 = vec3(0,1,0) end -- Default if zero or parallel

    row3 = row3 - row1 * row1:dot(row3) - row2 * row2:dot(row3)
    local len3 = row3:length()
    if len3 > epsilon then row3 = row3 / len3 else row3 = vec3(0,0,1) end -- Default if zero or linearly dependent


    -- Create new matrix with orthonormalized rotation and original position row
    return mat4x4(
        vec4(row1.x, row1.y, row1.z, 0),
        vec4(row2.x, row2.y, row2.z, 0),
        vec4(row3.x, row3.y, row3.z, 0),
        m.row4:clone() -- Keep original row 4
    )
end

-- NEW Helper: Convert 3x3 Rotation Matrix part of mat4x4 to Axis-Angle
-- Returns axis (vec3) and angle (number, radians)
local function matrixToAxisAngle(m)
    local epsilon = 1e-6
    local epsilon2 = 1e-3 -- For angle checks near 0 and pi

    local r11, r12, r13 = m.row1.x, m.row1.y, m.row1.z
    local r21, r22, r23 = m.row2.x, m.row2.y, m.row2.z
    local r31, r32, r33 = m.row3.x, m.row3.y, m.row3.z

    local trace = r11 + r22 + r33
    local angle

    -- Clamp trace to avoid domain errors with acos due to float inaccuracies
    local trace_clamped = math.max(-1, math.min(3, trace))
    angle = math.acos((trace_clamped - 1) / 2)

    local axis = vec3(0, 1, 0) -- Default axis

    if angle < epsilon2 then -- Angle is close to 0 (identity)
        angle = 0
        axis = vec3(0, 1, 0) -- Axis is arbitrary for identity
    elseif math.abs(angle - math.pi) < epsilon2 then -- Angle is close to pi (180 degrees)
        angle = math.pi
        -- Find axis by finding largest diagonal element
        if r11 >= r22 and r11 >= r33 then
            local s = math.sqrt(r11 - r22 - r33 + 1) * 0.5
            axis.x = s
            axis.y = (r12 + r21) / (4 * s)
            axis.z = (r13 + r31) / (4 * s)
        elseif r22 > r11 and r22 > r33 then
            local s = math.sqrt(r22 - r11 - r33 + 1) * 0.5
            axis.x = (r12 + r21) / (4 * s)
            axis.y = s
            axis.z = (r23 + r32) / (4 * s)
        else
            local s = math.sqrt(r33 - r11 - r22 + 1) * 0.5
            axis.x = (r13 + r31) / (4 * s)
            axis.y = (r23 + r32) / (4 * s)
            axis.z = s
        end
    else -- General case
        local x = r32 - r23
        local y = r13 - r31
        local z = r21 - r12
        axis = vec3(x, y, z)
    end

    -- Normalize axis if necessary
    local lenSq = axis:lengthSquared()
    if lenSq > epsilon then
        axis = axis / math.sqrt(lenSq)
    elseif angle ~= 0 then -- If not identity but axis collapsed, use default
        log("IK WARN matrixToAxisAngle", "Axis collapsed for non-identity rotation, using default.")
        axis = vec3(0, 1, 0)
    end

    return axis, angle
end

--- Solves IK for a 2-joint arm using FABRIK.
-- Chain: base -> arm1 (shoulder) -> arm2 (elbow) -> tip (end effector)
-- Target position is relative to the parent of the base node (platform).
-- Modifies the local transformations of arm1 and arm2 directly.
--
-- @param baseRef ac.SceneReference Base node (its parent defines the platform coordinate system).
-- @param arm1Ref ac.SceneReference First rotating joint (shoulder/upper arm).
-- @param arm2Ref ac.SceneReference Second rotating joint (elbow/forearm).
-- @param tipRef ac.SceneReference End effector node (its origin is the point to control).
-- @param targetPosPlatform vec3 Target position for the tipRef origin, in platform coordinates.
-- @param iterations integer? Optional: Maximum number of FABRIK iterations (default: 10).
-- @param tolerance number? Optional: Position tolerance for convergence (default: 0.01 world units).
local function solveFabrik2Joint(baseRef, arm1Ref, arm2Ref, tipRef, targetPosPlatform, iterations, tolerance)
    local logBuffer = {}
    -- Modified log functions to store pre-formatted strings
    local log = function(key, value)
        table.insert(logBuffer, string.format("[%s]: %s", key, tostring(value)))
    end
    local logVec3 = function(key, v)
        local valueStr
        if v and type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number" then
            valueStr = string.format("%.4f, %.4f, %.4f", v.x, v.y, v.z)
        elseif v then
            valueStr = string.format("INVALID COMPONENTS x:%s, y:%s, z:%s", tostring(v.x), tostring(v.y), tostring(v.z))
        else
            valueStr = "nil"
        end
        table.insert(logBuffer, string.format("[%s (Vec3)]: %s", key, valueStr))
    end
    local logMat4 = function(key, m)
        local valueStr = m and tostring(m) or "nil"
        table.insert(logBuffer, string.format("[%s (Mat4)]: %s", key, valueStr))
    end

    -- NEW HELPER: Logs detailed state of a SceneReference (uses modified log functions)
    local logObjectState = function(prefix, ref)
        if not ref then
            log(prefix .. " Object", "nil reference")
            return
        end
        -- These calls now automatically add pre-formatted strings to logBuffer
        logVec3(prefix .. " Local Pos (:getPosition)", ref:getPosition())
        logVec3(prefix .. " Local Look (:getLook)", ref:getLook())
        logVec3(prefix .. " Local Up (:getUp)", ref:getUp())
        logMat4(prefix .. " Local Transform (:getTransformationRaw)", ref:getTransformationRaw())
        logMat4(prefix .. " World Transform (:getWorldTransformationRaw)", ref:getWorldTransformationRaw())
    end

    local logMatDiff = function(keyPrefix, m1, m2)
        local diff = false
        if not m1 or not m2 then diff = true; log(keyPrefix, "One matrix is nil"); return end
        for i=1,4 do if m1['row'..i] ~= m2['row'..i] then diff = true; break end end
        log(keyPrefix .. " Different?", tostring(diff))
    end

    iterations = iterations or 10
    tolerance = tolerance or 0.01
    local epsilon = 1e-6

    -- === 0. Log Initial State ===
    log("--- IK Log Start ---", os.clock()) -- Use os.clock for higher resolution time
    local platformRef = baseRef:getParent() -- Make accessible to helper
    if not platformRef then log("IK Error", "No base parent."); return end -- Use simplified print
    local T_platform_world = platformRef:getWorldTransformationRaw() -- Make accessible to helper
    if not T_platform_world then log("IK Error", "No platform world T."); return end -- Use simplified print
    local platformParentRef = platformRef:getParent()
    if not platformParentRef then log("IK Error", "No platform parent."); return end -- Use simplified print
    local T_platform_parent_world = platformParentRef:getWorldTransformationRaw()
    if not T_platform_parent_world then log("IK Error", "No platform parent world T."); return end -- Use simplified print

    logObjectState("[Initial] Platform Parent", platformParentRef)
    logObjectState("[Initial] Platform", platformRef)
    logObjectState("[Initial] Base", baseRef)
    logObjectState("[Initial] Arm1", arm1Ref)
    logObjectState("[Initial] Arm2", arm2Ref)
    logObjectState("[Initial] Tip", tipRef)

    -- === 1. Get Current/Initial Transforms AND Original Local Positions ===
    local T_base_platform_current = baseRef:getTransformationRaw()
    local T_arm1_base_current = arm1Ref:getTransformationRaw()
    local T_arm2_arm1_current = arm2Ref:getTransformationRaw()
    local T_tip_arm2_current = tipRef:getTransformationRaw()

    if not T_base_platform_current or not T_arm1_base_current or not T_arm2_arm1_current or not T_tip_arm2_current then
        log("IK Error", "Missing current transformations.")
        print(table.concat(logBuffer, "\n")) -- Use simplified print
        return
    end

    -- Store original local positions (offsets from parent)
    local O_arm1_base_orig = arm1Ref:getPosition() -- Use getPosition() for clarity
    local O_arm2_arm1_orig = arm2Ref:getPosition() -- Use getPosition() for clarity
    logVec3("Original Local Pos Arm1 (from Base)", O_arm1_base_orig)
    logVec3("Original Local Pos Arm2 (from Arm1)", O_arm2_arm1_orig)

    -- === 2. Calculate CURRENT World Positions (for FABRIK input) ===
    -- NOTE: Instead of using the .position from manually multiplied matrices,
    -- get the world positions directly from the node references AFTER the hierarchy
    -- should be up-to-date from reading the local transforms above.
    local T_arm1_world_direct = arm1Ref:getWorldTransformationRaw()
    local T_arm2_world_direct = arm2Ref:getWorldTransformationRaw()
    local T_tip_world_direct  = tipRef:getWorldTransformationRaw()

    if not T_arm1_world_direct or not T_arm2_world_direct or not T_tip_world_direct then
         log("IK Error", "Missing direct world transformations for p array setup.")
         print(table.concat(logBuffer, "\n")) -- Use simplified print
         return
    end

    local p = { -- Chain points in WORLD space
        T_arm1_world_direct.position:clone(), -- Arm1 Origin (Shoulder) = Root of moving chain
        T_arm2_world_direct.position:clone(), -- Arm2 Origin (Elbow)
        T_tip_world_direct.position:clone()   -- Tip Origin (End Effector)
    }
    -- Also update chainRootPos to be consistent
    local chainRootPos = p[1]:clone() -- World position of the first MOVING joint (Arm1)

    -- Log the positions actually being used by FABRIK
    logVec3("FABRIK Input p[1] (Arm1 World Origin)", p[1])
    logVec3("FABRIK Input p[2] (Arm2 World Origin)", p[2])
    logVec3("FABRIK Input p[3] (Tip World Origin)", p[3])
    logVec3("FABRIK Chain Root World Pos (Arm1 Origin)", chainRootPos)

    -- We need T_base_world_current later for calculating local transforms.
    -- Fetch it directly, like we did for the p array points, to avoid potential
    -- matrix multiplication/accessor issues.
    local T_base_world_current = baseRef:getWorldTransformationRaw()
    if not T_base_world_current then
        log("IK Error", "Could not fetch direct T_base_world_current") -- Changed error message
        print(table.concat(logBuffer, "\n")) -- Use simplified print
        return
    end
    logMat4("Direct T_base_world_current (for Step 8)", T_base_world_current) -- Changed log key

    -- === 3. Calculate Segment Lengths ===
    local l = { math.distance(p[2], p[1]), math.distance(p[3], p[2]) }
    if l[1] < epsilon or l[2] < epsilon then log("IK Warning", "Segment length near zero."); return end -- Use simplified print
    local totalLength = l[1] + l[2]
    log("Segment Lengths", string.format("l1=%.4f, l2=%.4f", l[1], l[2]))

    -- === 4. Target Position ===
    targetWorld = T_platform_world:transformPoint(targetPosPlatform) -- Make accessible
    logVec3("Target World Pos", targetWorld)

    -- === 5. Reachability ===
    local distRootToTarget = math.distance(targetWorld, chainRootPos)
    if distRootToTarget > totalLength * (1 + epsilon) then
        local oldTarget = targetWorld:clone()
        targetWorld = chainRootPos + math.normalize(targetWorld - chainRootPos) * totalLength
        logVec3("Target Clamped From", oldTarget)
        logVec3("Target Clamped To", targetWorld)
    end

    -- === 6. FABRIK Loop ===
    local currentDistToTarget = math.distance(p[3], targetWorld)
    local iter = 0
    local initialDist = currentDistToTarget
    local getDir = function(from, to)
        local dir = to - from
        if dir:lengthSquared() > epsilon * epsilon then return dir:normalize()
        else log("IK WARN getDir", "collapsed vector"); return vec3(0, 1, 0) end
    end
    while currentDistToTarget > tolerance and iter < iterations do
        p[3] = targetWorld
        p[2] = p[3] - getDir(p[3], p[2]) * l[2]
        p[1] = p[2] - getDir(p[2], p[1]) * l[1]
        p[1] = chainRootPos
        p[2] = p[1] + getDir(p[1], p[2]) * l[1]
        p[3] = p[2] + getDir(p[2], p[3]) * l[2]
        currentDistToTarget = math.distance(p[3], targetWorld)
        iter = iter + 1
    end
    local final_p = { p[1]:clone(), p[2]:clone(), p[3]:clone() }
    log("FABRIK Iterations", iter)
    log("FABRIK Initial Dist", initialDist)
    log("FABRIK Final Dist", currentDistToTarget)
    logVec3("FABRIK Final World p[1] (Target Arm1 Origin)", final_p[1])
    logVec3("FABRIK Final World p[2] (Target Arm2 Origin)", final_p[2])
    logVec3("FABRIK Final World p[3] (Target Tip Origin)", final_p[3])

    -- === 7. Calculate Target World Transforms (Using Helper) ===
    -- Build transform for arm1 JOINT looking towards arm2 JOINT
    local T_target_arm1_world = buildWorldTransformLookingAt(final_p[1], final_p[2], vec3(0, 1, 0), epsilon)
    -- Build transform for arm2 JOINT looking towards tip TARGET
    local T_target_arm2_world = buildWorldTransformLookingAt(final_p[2], final_p[3], vec3(0, 1, 0), epsilon)

    logMat4("T_target_arm1_world (Built)", T_target_arm1_world)
    logMat4("T_target_arm2_world (Built)", T_target_arm2_world)
    logVec3("T_target_arm1_world Pos (Should match final_p[1])", T_target_arm1_world.position)
    logVec3("T_target_arm2_world Pos (Should match final_p[2])", T_target_arm2_world.position)

    -- === 8. Calculate Required Local Orientation & Position === -- Changed Step Title
    log("--- Step 8 Calculation (Required Local Orientation and Position) ---", "")

    -- Arm 1
    local T_inv_base_world_current = T_base_world_current:inverse()
    if not T_inv_base_world_current then log("IK FATAL", "Inv Base World nil"); return end
    if not T_target_arm1_world then log("IK FATAL", "Target Arm1 World nil"); return end

    -- Extract target world orientation vectors (Look = Z axis, Up = Y axis)
    local look1_target_world = vec3(T_target_arm1_world.row3.x, T_target_arm1_world.row3.y, T_target_arm1_world.row3.z):normalize()
    local up1_target_world = vec3(T_target_arm1_world.row2.x, T_target_arm1_world.row2.y, T_target_arm1_world.row2.z):normalize()
    logVec3("Step8 look1_target_world", look1_target_world)
    logVec3("Step8 up1_target_world", up1_target_world)

    -- Transform world orientation vectors into parent's (Base) local space
    -- Use transformVector which ignores translation part of the matrix
    local look1_required_local = T_inv_base_world_current:transformVector(look1_target_world):normalize()
    local up1_required_local = T_inv_base_world_current:transformVector(up1_target_world):normalize()
    -- Ensure they are orthogonal after transformation (optional but good practice)
    local right1_required_local = math.cross(up1_required_local, look1_required_local):normalize()
    up1_required_local = math.cross(look1_required_local, right1_required_local):normalize()
    logVec3("Step8 look1_required_local (Normalized)", look1_required_local)
    logVec3("Step8 up1_required_local (Normalized & Ortho)", up1_required_local)

    -- Calculate the required LOCAL POSITION vector explicitly (Should be 0,0,0.3)
    local P_arm1_target_local = T_inv_base_world_current:transformPoint(final_p[1])
    logVec3("Step8 P_arm1_target_local (Explicitly Calculated)", P_arm1_target_local)

    -- Arm 2
    local T_inv_arm1_world_target = T_target_arm1_world:inverse() -- Use target world T for Arm1's inverse
    if not T_inv_arm1_world_target then log("IK FATAL", "Inv Target Arm1 World nil"); return end
    if not T_target_arm2_world then log("IK FATAL", "Target Arm2 World nil"); return end

    -- Extract target world orientation vectors
    local look2_target_world = vec3(T_target_arm2_world.row3.x, T_target_arm2_world.row3.y, T_target_arm2_world.row3.z):normalize()
    local up2_target_world = vec3(T_target_arm2_world.row2.x, T_target_arm2_world.row2.y, T_target_arm2_world.row2.z):normalize()
    logVec3("Step8 look2_target_world", look2_target_world)
    logVec3("Step8 up2_target_world", up2_target_world)

    -- Transform world orientation vectors into parent's (Arm1 Target) local space
    local look2_required_local = T_inv_arm1_world_target:transformVector(look2_target_world):normalize()
    local up2_required_local = T_inv_arm1_world_target:transformVector(up2_target_world):normalize()
    -- Ensure they are orthogonal after transformation
    local right2_required_local = math.cross(up2_required_local, look2_required_local):normalize()
    up2_required_local = math.cross(look2_required_local, right2_required_local):normalize()
    logVec3("Step8 look2_required_local (Normalized)", look2_required_local)
    logVec3("Step8 up2_required_local (Normalized & Ortho)", up2_required_local)

    -- Calculate the required LOCAL POSITION vector explicitly (Should be 0,0,0.3)
    local P_arm2_target_local = T_inv_arm1_world_target:transformPoint(final_p[2])
    logVec3("Step8 P_arm2_target_local (Explicitly Calculated)", P_arm2_target_local)

    -- === 9. Apply Calculated Orientation & Position === -- Changed Step Title
    log("--- Step 9 Applying Transforms ---", "")

    -- Apply Arm 1
    if arm1Ref and look1_required_local and up1_required_local and P_arm1_target_local then
        logVec3("Step9 Arm1 Applying Look Vector", look1_required_local)
        logVec3("Step9 Arm1 Applying Up Vector", up1_required_local)
        arm1Ref:setOrientation(look1_required_local, up1_required_local) -- Apply Look/Up vectors
        log("Applied setOrientation to arm1Ref", "")

        logVec3("Step9 Arm1 Setting Explicitly Calculated Local Pos To", P_arm1_target_local)
        arm1Ref:setPosition(P_arm1_target_local) -- Apply local position (0,0,0.3)
        log("Applied setPosition to arm1Ref", "")
    else log("IK Error", "arm1Ref, look1_required_local, up1_required_local or P_arm1_target_local is nil.") end

    -- Apply Arm 2
    if arm2Ref and look2_required_local and up2_required_local and P_arm2_target_local then
        logVec3("Step9 Arm2 Applying Look Vector", look2_required_local)
        logVec3("Step9 Arm2 Applying Up Vector", up2_required_local)
        arm2Ref:setOrientation(look2_required_local, up2_required_local) -- Apply Look/Up vectors
        log("Applied setOrientation to arm2Ref", "")

        logVec3("Step9 Arm2 Setting Explicitly Calculated Local Pos To", P_arm2_target_local)
        arm2Ref:setPosition(P_arm2_target_local) -- Apply local position (0,0,0.3)
        log("Applied setPosition to arm2Ref", "")
    else log("IK Error", "arm2Ref, look2_required_local, up2_required_local or P_arm2_target_local is nil.") end

    -- === 10. Log Final State & Verification ===
    log("--- Step 10 Final State & Verification ---", "")
    logObjectState("[Final] Platform", platformParentRef) -- Use platformParentRef for consistency
    logObjectState("[Final] Base", baseRef)
    logObjectState("[Final] Arm1", arm1Ref)
    logObjectState("[Final] Arm2", arm2Ref)
    logObjectState("[Final] Tip", tipRef)

    -- Verification: Read the final world position DIRECTLY from the tip node
    local T_tip_world_final_direct = tipRef:getWorldTransformationRaw()
    local reconstructed_tip_pos_direct = T_tip_world_final_direct and T_tip_world_final_direct.position or nil

    logVec3("VERIFY Target World (Clamped)", targetWorld) -- Log the clamped target
    logVec3("VERIFY FABRIK End Pos (p[3])", final_p[3])  -- Log FABRIK's calculated end point
    logVec3("VERIFY Reconstructed Tip World Pos (Direct Read)", reconstructed_tip_pos_direct) -- Log position from direct read

    if reconstructed_tip_pos_direct then
        log("VERIFY Dist FABRIK vs Direct Read", math.distance(final_p[3], reconstructed_tip_pos_direct))
        log("VERIFY Dist Target vs Direct Read", math.distance(targetWorld, reconstructed_tip_pos_direct))
    else
        log("IK Debug Error", "Could not get direct final tip world transform for verification.")
    end

    -- Print the buffered logs - Directly concatenate the pre-formatted strings
    --print("--- IK Log Frame ---\n" .. table.concat(logBuffer, "\n")) -- Simplified final print

end -- End of solveFabrik2Joint

-- Return the solver function so it can be used via require()
return solveFabrik2Joint

