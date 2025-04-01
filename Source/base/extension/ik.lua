--- Creates a 4x4 WORLD transformation matrix at a position, oriented along a primary axis.
-- **Builds a standard matrix: Local +Z axis aligns with the 'forward' direction (target - origin),
-- Local +Y aligns close to 'worldUpHint', and Local +X aligns with the 'right' direction.**
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
        vec4(right.x, right.y, right.z, 0),
        vec4(up.x, up.y, up.z, 0),
        vec4(forward.x, forward.y, forward.z, 0),
        vec4(originWorld.x, originWorld.y, originWorld.z, 1)
    )
end

--- Solves IK for a 2-joint arm using FABRIK.
-- Chain: base -> arm1 (shoulder) -> arm2 (elbow) -> tip (end effector)
-- Target position is relative to the parent of the base node (platform).
-- Modifies the local transformations of arm1 and arm2 directly.
--
-- @param baseRef ac.SceneReference Base node (its parent defines the platform coordinate system).
-- @param arm1Ref ac.SceneReference First rotating joint (shoulder/upper arm).
-- @param arm2Ref ac.SceneReference Second rotating joint (elbow/forearm).
-- @param tipRef ac.SceneReference End effector node (the offset is relative to this node).
-- @param targetPosPlatform vec3 Target position for the offset tip point, in platform coordinates.
-- @param iterations integer? Optional: Maximum number of FABRIK iterations (default: 10).
-- @param tolerance number? Optional: Position tolerance for convergence (default: 0.01 world units).
-- @param arm1Convention string? Optional: Local axis convention for arm1 ("Z_Fwd_Y_Up" or "Y_Fwd_Z_Up", default: "Z_Fwd_Y_Up").
-- @param arm2Convention string? Optional: Local axis convention for arm2 ("Z_Fwd_Y_Up" or "Y_Fwd_Z_Up", default: "Z_Fwd_Y_Up").
local function solveFabrik2Joint(baseRef, arm1Ref, arm2Ref, tipRef, targetPosPlatform, iterations, tolerance, arm1Convention, arm2Convention)
    local fixerOffset = vec3(1000000, 1000000, 1000000)

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

    iterations = iterations or 10
    tolerance = tolerance or 0.01
    local epsilon = 1e-8

    -- === 0. Log Initial State ===
    log("--- IK Log Start ---", os.clock())
    local platformRef = baseRef:getParent() -- Make accessible to helper
    if not platformRef then
        log("IK Error", "No base parent."); return
    end
    local T_platform_world = platformRef:getWorldTransformationRaw() -- Make accessible to helper
    if not T_platform_world then
        log("IK Error", "No platform world T."); return
    end
    local platformParentRef = platformRef:getParent()
    if not platformParentRef then
        log("IK Error", "No platform parent."); return
    end
    local T_platform_parent_world = platformParentRef:getWorldTransformationRaw()
    if not T_platform_parent_world then
        log("IK Error", "No platform parent world T."); return
    end

    logVec3("fixerOffset", fixerOffset) -- Log the input offset

    -- === 1. Get Current/Initial Transforms AND Original Local Positions ===
    local T_base_platform_current = baseRef:getTransformationRaw()
    local T_arm1_base_current = arm1Ref:getTransformationRaw()
    local T_arm2_arm1_current = arm2Ref:getWorldTransformationRaw()
    local T_tip_arm2_current = tipRef:getTransformationRaw()

    if not T_base_platform_current or not T_arm1_base_current or not T_arm2_arm1_current or not T_tip_arm2_current then
        log("IK Error", "Missing current transformations.")
        print(table.concat(logBuffer, "\n"))
        return
    end

    -- Store original local positions (offsets from parent)
    local O_arm1_base_orig = arm1Ref:getPosition() -- Use getPosition() for clarity
    local O_arm2_arm1_orig = arm2Ref:getPosition() -- Use getPosition() for clarity
    logVec3("Original Local Pos Arm1 (from Base)", O_arm1_base_orig)
    logVec3("Original Local Pos Arm2 (from Arm1)", O_arm2_arm1_orig)

    -- === 2. Calculate CURRENT World Positions (for FABRIK input) ===
    -- Get world transforms directly
    local T_arm1_world_direct = arm1Ref:getWorldTransformationRaw()
    local T_arm2_world_direct = arm2Ref:getWorldTransformationRaw()
    local T_tip_world_direct  = tipRef:getWorldTransformationRaw() -- World transform of the tip node itself

    if not T_arm1_world_direct or not T_arm2_world_direct or not T_tip_world_direct then
        log("IK Error", "Missing direct world transformations for p array setup.")
        print(table.concat(logBuffer, "\n"))
        return
    end

    -- Calculate the world position of the offset tip point
    local fixerOffsetWorld = T_tip_world_direct:transformPoint(fixerOffset)
    logVec3("Initial Tip Origin World Pos", T_tip_world_direct.position)
    logVec3("Initial Tip World Pos with fixerOffset", fixerOffsetWorld)

    local p = {                               -- Chain points in WORLD space
        T_arm1_world_direct.position:clone(), -- Arm1 Origin (Shoulder)
        T_arm2_world_direct.position:clone(), -- Arm2 Origin (Elbow)
        fixerOffsetWorld:clone()              -- Offset Tip Point (End Effector Point)
    }
    local chainRootPos = p[1]:clone()         -- World position of the first MOVING joint (Arm1)

    -- Log the positions actually being used by FABRIK
    logVec3("FABRIK Input p[1] (Arm1 World Origin)", p[1])
    logVec3("FABRIK Input p[2] (Arm2 World Origin)", p[2])
    logVec3("FABRIK Input p[3] (fixerOffset Tip World Pos)", p[3])
    logVec3("FABRIK Chain Root World Pos (Arm1 Origin)", chainRootPos)

    -- Get T_base_world_current for Step 8
    local T_base_world_current = baseRef:getWorldTransformationRaw()
    if not T_base_world_current then
        log("IK Error", "Could not fetch direct T_base_world_current")
        print(table.concat(logBuffer, "\n")) -- Use simplified print
        return
    end
    logMat4("Direct T_base_world_current (for Step 8)", T_base_world_current)

    -- === 3. Calculate Segment Lengths ===
    -- Segment lengths are now from Arm1 origin to Arm2 origin,
    -- and from Arm2 origin to the OFFSET tip point.
    local l = { math.distance(p[2], p[1]), math.distance(p[3], p[2]) }
    if l[1] < epsilon or l[2] < epsilon then
        log("IK Warning", "Segment length near zero."); return
    end
    local totalLength = l[1] + l[2]
    log("Segment Lengths (Using Offset Tip)", string.format("l1=%.4f, l2=%.4f", l[1], l[2])) -- Updated log

    -- === 4. Target Position ===
    local targetWorld = T_platform_world:transformPoint(targetPosPlatform)
    logVec3("Target World Pos (for Offset Tip)", targetWorld) -- Updated log

    -- === 5. Reachability ===
    local distRootToTarget = math.distance(targetWorld, chainRootPos)
    if distRootToTarget > totalLength * (1 + epsilon) then
        local oldTarget = targetWorld:clone()
        targetWorld = chainRootPos + math.normalize(targetWorld - chainRootPos) * totalLength
        logVec3("Target Clamped From", oldTarget)
        logVec3("Target Clamped To", targetWorld)
    end

    -- === 6. FABRIK Loop ===
    -- The loop works on the p array, which now ends at the offset tip point
    local currentDistToTarget = math.distance(p[3], targetWorld)
    local iter = 0
    local initialDist = currentDistToTarget
    local getDir = function(from, to)
        local dir = to - from
        if dir:lengthSquared() > epsilon * epsilon then
            return dir:normalize()
        else
            log("IK WARN getDir", "collapsed vector"); return vec3(0, 1, 0)
        end
    end
    while currentDistToTarget > tolerance and iter < iterations do
        p[3] = targetWorld                      -- Move end point (offset tip) to target
        p[2] = p[3] - getDir(p[3], p[2]) * l[2] -- Move elbow towards new tip pos
        p[1] = p[2] - getDir(p[2], p[1]) * l[1] -- Move shoulder towards new elbow pos

        p[1] = chainRootPos                     -- Reset shoulder to base
        p[2] = p[1] + getDir(p[1], p[2]) * l[1] -- Move elbow out from base
        p[3] = p[2] + getDir(p[2], p[3]) * l[2] -- Move tip out from elbow
        currentDistToTarget = math.distance(p[3], targetWorld)
        iter = iter + 1
    end
    local final_p = { p[1]:clone(), p[2]:clone(), p[3]:clone() }
    log("FABRIK Iterations", iter)
    log("FABRIK Initial Dist (Offset Tip to Target)", initialDist)       -- Updated log
    log("FABRIK Final Dist (Offset Tip to Target)", currentDistToTarget) -- Updated log
    log("FABRIK Delta", currentDistToTarget - initialDist)
    logVec3("FABRIK Final World p[1] (Target Arm1 Origin)", final_p[1])
    logVec3("FABRIK Final World p[2] (Target Arm2 Origin)", final_p[2])
    logVec3("FABRIK Final World p[3] (Target Offset Tip Pos)", final_p[3]) -- Updated log

    -- === 7. Calculate Target World Transforms (Using Helper) ===
    -- These are still based on the JOINT positions (final_p[1] and final_p[2])
    -- and the direction towards the NEXT point in the solved chain.
    local T_target_arm1_world = buildWorldTransformLookingAt(final_p[1], final_p[2], vec3(0, 1, 0), epsilon) -- Arm1 looking at Arm2
    local T_target_arm2_world = buildWorldTransformLookingAt(final_p[2], final_p[3], vec3(0, 1, 0), epsilon) -- Arm2 looking at Offset Tip

    logMat4("T_target_arm1_world (Built)", T_target_arm1_world)
    logMat4("T_target_arm2_world (Built)", T_target_arm2_world)
    logVec3("T_target_arm1_world Pos (Should match final_p[1])", T_target_arm1_world.position)
    logVec3("T_target_arm2_world Pos (Should match final_p[2])", T_target_arm2_world.position)

    -- === 8. Calculate Required Local Orientation & Position ===
    log("--- Step 8 Calculation (Required Local Orientation and Position) ---", "")

    -- Arm 1
    local T_inv_base_world_current = T_base_world_current:inverse()
    if not T_inv_base_world_current then log("IK FATAL", "Inv Base World nil"); print(table.concat(logBuffer, "\n")); return end
    if not T_target_arm1_world then log("IK FATAL", "Target Arm1 World nil"); print(table.concat(logBuffer, "\n")); return end

    -- Extract target world orientation vectors (X=Right, Y=Up, Z=Forward for the built matrix)
    local right1_target_world = vec3(T_target_arm1_world.row1.x, T_target_arm1_world.row1.y, T_target_arm1_world.row1.z):normalize()
    local up1_target_world = vec3(T_target_arm1_world.row2.x, T_target_arm1_world.row2.y, T_target_arm1_world.row2.z):normalize()
    local forward1_target_world = vec3(T_target_arm1_world.row3.x, T_target_arm1_world.row3.y, T_target_arm1_world.row3.z):normalize()
    logVec3("Step8 Right1 Target World", right1_target_world)
    logVec3("Step8 Up1 Target World", up1_target_world)
    logVec3("Step8 Forward1 Target World", forward1_target_world)

    -- Transform world orientation vectors into parent's (Base) local space
    local right1_required_local = T_inv_base_world_current:transformVector(right1_target_world):normalize()
    local up1_required_local = T_inv_base_world_current:transformVector(up1_target_world):normalize()
    local forward1_required_local = T_inv_base_world_current:transformVector(forward1_target_world):normalize()
    -- Ensure orthogonality (optional but good practice)
    forward1_required_local = math.cross(right1_required_local, up1_required_local):normalize()
    up1_required_local = math.cross(forward1_required_local, right1_required_local):normalize()
    logVec3("Step8 Right1 Required Local (Normalized & Ortho)", right1_required_local)
    logVec3("Step8 Up1 Required Local (Normalized & Ortho)", up1_required_local)
    logVec3("Step8 Forward1 Required Local (Normalized & Ortho)", forward1_required_local)

    -- Calculate the required LOCAL POSITION vector explicitly
    local P_arm1_target_local = T_inv_base_world_current:transformPoint(final_p[1])
    logVec3("Step8 P_arm1_target_local (Explicitly Calculated)", P_arm1_target_local)

    -- Arm 2
    local T_inv_arm1_world_target = T_target_arm1_world:inverse() -- Use target world T for Arm1's inverse
    if not T_inv_arm1_world_target then log("IK FATAL", "Inv Target Arm1 World nil"); print(table.concat(logBuffer, "\n")); return end
    if not T_target_arm2_world then log("IK FATAL", "Target Arm2 World nil"); print(table.concat(logBuffer, "\n")); return end

    -- Extract target world orientation vectors
    local right2_target_world = vec3(T_target_arm2_world.row1.x, T_target_arm2_world.row1.y, T_target_arm2_world.row1.z):normalize()
    local up2_target_world = vec3(T_target_arm2_world.row2.x, T_target_arm2_world.row2.y, T_target_arm2_world.row2.z):normalize()
    local forward2_target_world = vec3(T_target_arm2_world.row3.x, T_target_arm2_world.row3.y, T_target_arm2_world.row3.z):normalize()
    logVec3("Step8 Right2 Target World", right2_target_world)
    logVec3("Step8 Up2 Target World", up2_target_world)
    logVec3("Step8 Forward2 Target World", forward2_target_world)

    -- Transform world orientation vectors into parent's (Arm1 Target) local space
    local right2_required_local = T_inv_arm1_world_target:transformVector(right2_target_world):normalize()
    local up2_required_local = T_inv_arm1_world_target:transformVector(up2_target_world):normalize()
    local forward2_required_local = T_inv_arm1_world_target:transformVector(forward2_target_world):normalize()
    -- Ensure orthogonality
    forward2_required_local = math.cross(right2_required_local, up2_required_local):normalize()
    up2_required_local = math.cross(forward2_required_local, right2_required_local):normalize()
    logVec3("Step8 Right2 Required Local (Normalized & Ortho)", right2_required_local)
    logVec3("Step8 Up2 Required Local (Normalized & Ortho)", up2_required_local)
    logVec3("Step8 Forward2 Required Local (Normalized & Ortho)", forward2_required_local)

    -- Calculate the required LOCAL POSITION vector explicitly
    local P_arm2_target_local = T_inv_arm1_world_target:transformPoint(final_p[2])
    logVec3("Step8 P_arm2_target_local (Explicitly Calculated)", P_arm2_target_local)

    -- === 9. Apply Calculated Orientation & Position ===
    log("--- Step 9 Applying Transforms ---", "")

    -- Apply Arm 1
    local arm1_fwd_vec, arm1_up_vec
    local current_arm1_convention = arm1Convention or "Z_Fwd_Y_Up" -- Default convention
    if current_arm1_convention == "Z_Fwd_Y_Up" then
        arm1_fwd_vec = forward1_required_local -- Target Z maps to Arm1 Local Z (Forward)
        arm1_up_vec = up1_required_local       -- Target Y maps to Arm1 Local Y (Up)
        log("Step9 Arm1 Convention", "Z_Fwd_Y_Up")
    elseif current_arm1_convention == "Y_Fwd_Z_Up" then
        arm1_fwd_vec = up1_required_local       -- Target Y maps to Arm1 Local Y (Forward)
        arm1_up_vec = forward1_required_local -- Target Z maps to Arm1 Local Z (Up)
        log("Step9 Arm1 Convention", "Y_Fwd_Z_Up")
    else
        log("IK Error", "Unknown arm1Convention: " .. tostring(current_arm1_convention))
        arm1_fwd_vec = nil -- Prevent application if convention is wrong
    end

    if arm1Ref and arm1_fwd_vec and arm1_up_vec and P_arm1_target_local then
        logVec3("Step9 Arm1 Applying Fwd Vector", arm1_fwd_vec)
        logVec3("Step9 Arm1 Applying Up Vector", arm1_up_vec)
        arm1Ref:setOrientation(arm1_fwd_vec, arm1_up_vec) -- Apply Look/Up vectors based on convention
        log("Applied setOrientation to arm1Ref", "")

        logVec3("Step9 Arm1 Setting Explicitly Calculated Local Pos To", P_arm1_target_local)
        arm1Ref:setPosition(P_arm1_target_local) -- Apply local position
        log("Applied setPosition to arm1Ref", "")
    else
        log("IK Error", "arm1Ref, required vectors, or P_arm1_target_local is nil or convention unknown.")
    end

    -- Apply Arm 2
    local arm2_fwd_vec, arm2_up_vec
    local current_arm2_convention = arm2Convention or "Z_Fwd_Y_Up" -- Default convention
    if current_arm2_convention == "Z_Fwd_Y_Up" then
        arm2_fwd_vec = forward2_required_local -- Target Z maps to Arm2 Local Z (Forward)
        arm2_up_vec = up2_required_local       -- Target Y maps to Arm2 Local Y (Up)
        log("Step9 Arm2 Convention", "Z_Fwd_Y_Up")
    elseif current_arm2_convention == "Y_Fwd_Z_Up" then
        arm2_fwd_vec = up2_required_local       -- Target Y maps to Arm2 Local Y (Forward)
        arm2_up_vec = forward2_required_local -- Target Z maps to Arm2 Local Z (Up)
        log("Step9 Arm2 Convention", "Y_Fwd_Z_Up")
    else
        log("IK Error", "Unknown arm2Convention: " .. tostring(current_arm2_convention))
        arm2_fwd_vec = nil -- Prevent application if convention is wrong
    end

    if arm2Ref and arm2_fwd_vec and arm2_up_vec and P_arm2_target_local then
        logVec3("Step9 Arm2 Applying Fwd Vector", arm2_fwd_vec)
        logVec3("Step9 Arm2 Applying Up Vector", arm2_up_vec)
        arm2Ref:setOrientation(arm2_fwd_vec, arm2_up_vec) -- Apply Look/Up vectors based on convention
        log("Applied setOrientation to arm2Ref", "")

        logVec3("Step9 Arm2 Setting Explicitly Calculated Local Pos To", P_arm2_target_local)
        arm2Ref:setPosition(P_arm2_target_local) -- Apply local position
        log("Applied setPosition to arm2Ref", "")
    else
        log("IK Error", "arm2Ref, required vectors, or P_arm2_target_local is nil or convention unknown.")
    end

    -- === 10. Log Final State & Verification ===
    log("--- Step 10 Final State & Verification ---", "")

    -- Verification: Read the final world position of the OFFSET tip point
    local T_tip_world_final_direct = tipRef:getWorldTransformationRaw()
    local reconstructed_offset_tip_pos_direct = T_tip_world_final_direct and
        T_tip_world_final_direct:transformPoint(fixerOffset) or
        nil -- Apply offset again

    logVec3("VERIFY Target World (Clamped)", targetWorld)
    logVec3("VERIFY FABRIK End Pos (p[3])", final_p[3])
    logVec3("VERIFY Reconstructed Offset Tip World Pos (Direct Read)", reconstructed_offset_tip_pos_direct) -- Updated log

    if reconstructed_offset_tip_pos_direct then
        log("VERIFY Dist FABRIK vs Direct Offset Read", math.distance(final_p[3], reconstructed_offset_tip_pos_direct))  -- Updated log
        log("VERIFY Dist Target vs Direct Offset Read", math.distance(targetWorld, reconstructed_offset_tip_pos_direct)) -- Updated log
    else
        log("IK Debug Error", "Could not get direct final tip world transform for offset verification.")
    end

    -- Print the buffered logs
    print("--- IK Log Frame ---\n" .. table.concat(logBuffer, "\n")) -- Simplified final print
end -- End of solveFabrik2Joint


return solveFabrik2Joint
