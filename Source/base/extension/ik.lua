--- Creates a 4x4 WORLD transformation matrix at a position, oriented towards a target.
-- Builds a standard matrix suitable for world space:
--   - Local +Z axis aligns with the 'forward' direction (target - origin).
--   - Local +Y aligns as close as possible to 'worldUpHint'.
--   - Local +X aligns with the 'right' direction (orthogonal to forward and up).
-- @param originWorld vec3 The desired world origin for the matrix.
-- @param lookTargetWorld vec3 The world point to look towards.
-- @param worldUpHint vec3? A world-space up vector hint (default: {0,1,0}). Used to stabilize the 'up' direction.
-- @param epsilon number? Small value for float comparisons (default: 1e-6).
-- @return mat4x4 The calculated world transformation matrix, or identity if origin and target are too close.
local function buildWorldTransformLookingAt(originWorld, lookTargetWorld, worldUpHint, epsilon)
    epsilon = epsilon or 1e-6
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
    local temp_up = worldUpHint or vec3(0, 1, 0)
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

    while math.distance(p[3], targetWorld) > tolerance and iter < iterations do
        -- Backward pass: Constrain towards root
        p[3] = targetWorld                      -- Snap end effector to target
        p[2] = p[3] - getDir(p[3], p[2]) * l[2] -- Constrain elbow based on new tip and length l2
        p[1] = p[2] - getDir(p[2], p[1]) * l[1] -- Constrain shoulder based on new elbow and length l1

        -- Forward pass: Constrain away from root
        p[1] = chainRootPos                     -- Snap shoulder back to its fixed root position
        p[2] = p[1] + getDir(p[1], p[2]) * l[1] -- Constrain elbow based on new shoulder and length l1
        p[3] = p[2] + getDir(p[2], p[3]) * l[2] -- Constrain tip based on new elbow and length l2

        iter = iter + 1
    end
    local finalDist = math.distance(p[3], targetWorld)
    log("FABRIK Result", string.format("Iterations=%d, InitialDist=%.4f, FinalDist=%.4f", iter, initialDist, finalDist))
    logVec3("Final Arm1 World Pos (FABRIK)", p[1])
    logVec3("Final Arm2 World Pos (FABRIK)", p[2])
    logVec3("Final Offset Tip World Pos (FABRIK)", p[3])

    -- === 7. Calculate Target World Transforms for Joints ===
    -- Use the solved FABRIK points to determine the desired world orientation for each joint.
    local T_target_arm1_world = buildWorldTransformLookingAt(p[1], p[2], vec3(0, 1, 0), epsilon) -- Arm1 looks at Arm2
    local T_target_arm2_world = buildWorldTransformLookingAt(p[2], p[3], vec3(0, 1, 0), epsilon) -- Arm2 looks towards the final offset tip position
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

    -- === 9. Apply Orientation & Original Position ===
    log("--- Applying Transforms ---", "")

    -- Apply to Arm 1
    local arm1_fwd_vec_apply, arm1_up_vec_apply -- Vectors to pass to setOrientation
    -- Use arm1Convention variable extracted from params
    log("Arm1 Convention", arm1Convention)

    if arm1Convention == "Z_Fwd_Y_Up" then
        -- Local Fwd=Z, Local Up=Y. Map required local F->Fwd, U->Up. Pass (F1_req_local, U1_req_local).
        arm1_fwd_vec_apply = F1_req_local
        arm1_up_vec_apply = U1_req_local
    elseif arm1Convention == "Y_Fwd_Z_Up" then
        -- Local Fwd=Y, Local Up=Z. Map required local U->Fwd, F->Up. Pass (U1_req_local, F1_req_local).
        -- Empirically found that negating both vectors is required for this convention to point correctly.
        arm1_fwd_vec_apply = -U1_req_local
        arm1_up_vec_apply = -F1_req_local
        log("Arm1", "(Applying NEGATED required U as Fwd, NEGATED required F as Up)")
    else
        log("IK Error", "Unknown arm1Convention: " .. arm1Convention); arm1_fwd_vec_apply = nil
    end

    if arm1Ref and arm1_fwd_vec_apply and arm1_up_vec_apply then
        arm1Ref:setOrientation(arm1_fwd_vec_apply, arm1_up_vec_apply)
        arm1Ref:setPosition(O_arm1_base_orig) -- Restore original local position
        log("Arm1", "Applied Orientation & Original Position")
    else
        log("IK Error", "Failed to apply transform to Arm1 (nil vectors or ref)")
    end

    -- Apply to Arm 2
    local arm2_fwd_vec_apply, arm2_up_vec_apply
    -- Use arm2Convention variable extracted from params
    log("Arm2 Convention", arm2Convention)

    if arm2Convention == "Z_Fwd_Y_Up" then
        -- Local Fwd=Z, Local Up=Y. Map required local F->Fwd, U->Up. Pass (F2_req_local, U2_req_local).
        arm2_fwd_vec_apply = F2_req_local
        arm2_up_vec_apply = U2_req_local
    elseif arm2Convention == "Y_Fwd_Z_Up" then
        -- Local Fwd=Y, Local Up=Z. Map required local U->Fwd, F->Up. Pass (U2_req_local, F2_req_local).
        -- Apply same negation logic as Arm1 for consistency.
        arm2_fwd_vec_apply = -U2_req_local
        arm2_up_vec_apply = -F2_req_local
        log("Arm2", "(Applying NEGATED required U as Fwd, NEGATED required F as Up)")
    else
        log("IK Error", "Unknown arm2Convention: " .. arm2Convention); arm2_fwd_vec_apply = nil
    end

    if arm2Ref and arm2_fwd_vec_apply and arm2_up_vec_apply then
        arm2Ref:setOrientation(arm2_fwd_vec_apply, arm2_up_vec_apply)
        arm2Ref:setPosition(O_arm2_arm1_orig) -- Restore original local position
        log("Arm2", "Applied Orientation & Original Position")
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
    -- print("--- IK Log Frame ---\n" .. table.concat(logBuffer, "\n")) -- Enable for detailed debugging
end -- End of solveFabrik2Joint


return solveFabrik2Joint
