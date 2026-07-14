-- 2-joint FABRIK inverse kinematics for a shoulder/elbow chain
-- optional cone constraint on arm1, hinge on arm2, plus post-solve twist limits
-- runs every frame per arm so it reuses the scratch below with out-param APIs to avoid allocations

local EPSILON = 1e-8

-- large offset moves FABRIK far from the origin for float precision, cancelled out on readback
local FIXER_OFFSET = vec3(1000000, 1000000, 1000000)

-- reusable scratch, never allocated inside the per-frame solve
local sP1, sP2, sP3, sRoot, sTarget = vec3(), vec3(), vec3(), vec3(), vec3()
local sDir, sDirLocal, sAxis, sClamped, sWorld = vec3(), vec3(), vec3(), vec3(), vec3()
local sR, sU, sF, sT1, sT2 = vec3(), vec3(), vec3(), vec3(), vec3()
local sAr, sAu, sAf = vec3(), vec3(), vec3()
local sF1, sU1, sF2, sU2 = vec3(), vec3(), vec3(), vec3()
local sRefUp, sProj, sRight, sTmp = vec3(), vec3(), vec3(), vec3()
local sHint1, sHint2 = vec3(), vec3()
local sQuat = quat()
local sBaseInv, sArm1Inv = mat4x4.identity(), mat4x4.identity()
local sLen = { 0, 0 }

-- normalizes v in place, falling back to +Z if degenerate
local function normSafe(v)
    if v:lengthSquared() > EPSILON then v:normalize() else v:set(0, 0, 1) end
    return v
end

-- writes world right/up/forward axes of a look-at frame into out vectors, local +Z looks origin to target, upHint is a world-space up reference
local function lookAtAxes(origin, target, upHint, outR, outU, outF)
    target:sub(origin, outF)
    if outF:lengthSquared() < EPSILON then
        outR:set(1, 0, 0); outU:set(0, 1, 0); outF:set(0, 0, 1); return
    end
    outF:normalize()
    outU:set(upHint)
    if math.abs(outF:dot(outU)) > 0.999999 then
        if math.abs(outF.x) > 0.999999 then outU:set(0, 0, 1) else outU:set(1, 0, 0) end
    end
    outU:cross(outF, outR):normalize()
    outF:cross(outR, outU):normalize()
end

-- sets a non-parallel helper axis for ref into out
local function fallbackAxis(ref, out)
    if math.abs(ref.x) > 0.9 then out:set(0, 1, 0) else out:set(1, 0, 0) end
    return out
end

-- clamps twist of the (f, u) basis around f against a reference up from refAxis (Y_Fwd_Z_Up) or the parent local Z, mutates u
local function clampTwist(f, u, minT, maxT, convention, refAxis)
    local haveRef = false
    if convention == "Y_Fwd_Z_Up" and refAxis then
        f:cross(refAxis, sRefUp)
        haveRef = sRefUp:lengthSquared() > EPSILON
    end
    if not haveRef then
        sRefUp:set(0, 0, 1):addScaled(f, -f.z)
        if sRefUp:lengthSquared() <= EPSILON then f:cross(fallbackAxis(f, sTmp), sRefUp) end
    end
    sRefUp:normalize()

    sProj:set(u):addScaled(f, -f:dot(u))
    if sProj:length() > EPSILON then
        sProj:normalize()
        local angle = math.acos(math.clamp(sRefUp:dot(sProj), -1, 1))
        sRefUp:cross(sProj, sTmp)
        if f:dot(sTmp) < 0 then angle = -angle end
        local diff = math.clamp(angle, minT, maxT) - angle
        if math.abs(diff) > EPSILON then u:rotate(sQuat:setAngleAxis(diff, f)) end
    end

    u:cross(f, sRight)
    if sRight:lengthSquared() <= EPSILON then fallbackAxis(f, sTmp):cross(f, sRight) end
    sRight:normalize()
    f:cross(sRight, u):normalize()
end

-- transforms world axes r, u into parent local space and reorthonormalizes into outF/outU, forward rebuilt from them
local function toLocalBasis(parentInv, r, u, outF, outU)
    parentInv:transformVectorTo(sT1, r):normalize()
    parentInv:transformVectorTo(sT2, u):normalize()
    sT1:cross(sT2, outF):normalize()
    outF:cross(sT1, outU):normalize()
end

-- solves 2-joint IK for the chain base->arm1->arm2->tip
-- params: baseRef/arm1Ref/arm2Ref/tipRef nodes, targetPosPlatform in the space treeDepth levels above base
-- iterations/tolerance (default 10 / 0.01), arm1Convention/arm2Convention (Z_Fwd_Y_Up or Y_Fwd_Z_Up), treeDepth (default 2)
-- arm1ConstraintType none/cone (arm1ConeAxisLocal, arm1MaxConeAngle, arm1Min/MaxTwistAngle)
-- arm2ConstraintType none/hinge (arm2HingeAxisLocal, arm2Min/MaxHingeAngle, arm2Min/MaxTwistAngle)
local function solveFabrik2Joint(params)
    if not (params and params.baseRef and params.arm1Ref and params.arm2Ref and params.tipRef and params.targetPosPlatform) then
        print("IK Error: Missing required parameters.")
        return
    end

    local baseRef, arm1Ref, arm2Ref, tipRef = params.baseRef, params.arm1Ref, params.arm2Ref, params.tipRef
    local iterations = params.iterations or 10
    local tolerance = params.tolerance or 0.01
    local arm1Convention = params.arm1Convention or "Z_Fwd_Y_Up"
    local arm2Convention = params.arm2Convention or "Z_Fwd_Y_Up"

    local arm1Cone = params.arm1ConstraintType == "cone"
    local arm1ConeAxis = params.arm1ConeAxisLocal or vec3(0, 1, 0)
    local arm1MaxCone = math.rad(params.arm1MaxConeAngle or 180)
    local arm1MinTwist = math.rad(params.arm1MinTwistAngle or -90)
    local arm1MaxTwist = math.rad(params.arm1MaxTwistAngle or 90)

    local arm2Hinge = params.arm2ConstraintType == "hinge"
    local arm2HingeAxis = params.arm2HingeAxisLocal or vec3(1, 0, 0)
    local arm2MinHinge = math.rad(params.arm2MinHingeAngle or -180)
    local arm2MaxHinge = math.rad(params.arm2MaxHingeAngle or 180)
    local arm2MinTwist = math.rad(params.arm2MinTwistAngle or 0)
    local arm2MaxTwist = math.rad(params.arm2MaxTwistAngle or 0)

    -- resolve the coordinate space the target is specified in
    local targetSpace = baseRef
    for _ = 1, params.treeDepth or 2 do
        targetSpace = targetSpace and targetSpace:getParent()
    end
    if not targetSpace then print("IK Error: target reference node not found."); return end
    local targetSpaceWorld = targetSpace:getWorldTransformationRaw()

    local baseWorld = baseRef:getWorldTransformationRaw()
    local arm1World = arm1Ref:getWorldTransformationRaw()
    local arm2World = arm2Ref:getWorldTransformationRaw()
    local tipWorld = tipRef:getWorldTransformationRaw()
    if not (targetSpaceWorld and baseWorld and arm1World and arm2World and tipWorld) then
        print("IK Error: missing world transforms."); return
    end
    sBaseInv:set(baseWorld):inverseSelf()

    -- up hints fixed in the car body frame (targetSpace) so joint roll follows the car
    if arm1Convention == "Y_Fwd_Z_Up" then sTmp:set(0, -1, 0) else sTmp:set(0, 1, 0) end
    targetSpaceWorld:transformVectorTo(sHint1, sTmp):normalize()
    if arm2Convention == "Y_Fwd_Z_Up" then sTmp:set(0, -1, 0) else sTmp:set(0, 1, 0) end
    targetSpaceWorld:transformVectorTo(sHint2, sTmp):normalize()

    local arm1LocalPos = arm1Ref:getPosition()
    local arm2LocalPos = arm2Ref:getPosition()

    -- FABRIK joint chain in world space: shoulder, elbow, offset tip
    sP1:set(arm1World.position)
    sP2:set(arm2World.position)
    tipWorld:transformPointTo(sP3, FIXER_OFFSET)
    sRoot:set(sP1)
    sLen[1] = sP2:distance(sP1)
    sLen[2] = sP3:distance(sP2)
    local totalLength = sLen[1] + sLen[2]

    -- target world position, clamped to reachable distance
    targetSpaceWorld:transformPointTo(sTarget, params.targetPosPlatform)
    if sTarget:distance(sRoot) > totalLength then
        sTarget:sub(sRoot, sDir)
        sTarget:set(sRoot):addScaled(normSafe(sDir), totalLength)
    end

    -- FABRIK iterations with intra-loop joint constraints
    local iter = 0
    while sP3:distance(sTarget) > tolerance and iter < iterations do
        -- backward reach
        sP3:set(sTarget)
        sP2:sub(sP3, sDir)
        sP2:set(sP3):addScaled(normSafe(sDir), -sLen[2])
        -- forward reach
        sP1:set(sRoot)
        sP2:sub(sP1, sDir)
        sP2:set(sP1):addScaled(normSafe(sDir), sLen[1])

        -- arm1 cone constraint keeps the segment within a cone about arm1ConeAxis
        if arm1Cone and arm1MaxCone < math.pi - EPSILON then
            sBaseInv:transformVectorTo(sDirLocal, sDir)
            normSafe(sDirLocal)
            if math.acos(math.clamp(sDirLocal:dot(arm1ConeAxis), -1, 1)) > arm1MaxCone then
                arm1ConeAxis:cross(sDirLocal, sAxis)
                if sAxis:lengthSquared() <= EPSILON then arm1ConeAxis:cross(fallbackAxis(arm1ConeAxis, sTmp), sAxis) end
                sAxis:normalize()
                sClamped:set(arm1ConeAxis):rotate(sQuat:setAngleAxis(arm1MaxCone, sAxis))
                baseWorld:transformVectorTo(sWorld, sClamped)
                sP2:set(sP1):addScaled(normSafe(sWorld), sLen[1])
            end
        end

        sP3:sub(sP2, sDir)
        sP3:set(sP2):addScaled(normSafe(sDir), sLen[2])

        -- arm2 hinge constraint restricts the elbow bend to a signed angle range
        if arm2Hinge and (arm2MinHinge > -math.pi + EPSILON or arm2MaxHinge < math.pi - EPSILON) then
            lookAtAxes(sP1, sP2, sHint1, sAr, sAu, sAf)
            sP3:sub(sP2, sDir)
            normSafe(sDir)
            sDirLocal:set(sDir:dot(sAr), sDir:dot(sAu), sDir:dot(sAf)) -- arm2 dir in arm1 frame

            sRefUp:set(0, 0, 1):addScaled(arm2HingeAxis, -arm2HingeAxis.z)
            if sRefUp:lengthSquared() <= EPSILON then
                sRefUp:set(0, 1, 0):addScaled(arm2HingeAxis, -arm2HingeAxis.y)
            end
            sRefUp:normalize()

            sProj:set(sDirLocal):addScaled(arm2HingeAxis, -sDirLocal:dot(arm2HingeAxis))
            if sProj:lengthSquared() > EPSILON then
                sProj:normalize()
                local angle = math.acos(math.clamp(sRefUp:dot(sProj), -1, 1))
                sRefUp:cross(sProj, sTmp)
                if arm2HingeAxis:dot(sTmp) < 0 then angle = -angle end
                local diff = math.clamp(angle, arm2MinHinge, arm2MaxHinge) - angle
                if math.abs(diff) > EPSILON then
                    sDirLocal:rotate(sQuat:setAngleAxis(diff, arm2HingeAxis))
                    sWorld:set(0, 0, 0):addScaled(sAr, sDirLocal.x):addScaled(sAu, sDirLocal.y):addScaled(sAf, sDirLocal.z)
                    sP3:set(sP2):addScaled(normSafe(sWorld), sLen[2])
                end
            end
        end

        iter = iter + 1
    end

    -- convert solved world orientations into each joint parent-local basis
    lookAtAxes(sP1, sP2, sHint1, sR, sU, sF)
    toLocalBasis(sBaseInv, sR, sU, sF1, sU1)
    lookAtAxes(sP2, sP3, sHint2, sR, sU, sF)
    sArm1Inv:set(arm1World):inverseSelf()
    toLocalBasis(sArm1Inv, sR, sU, sF2, sU2)

    -- post-solve twist limits
    if arm1Cone then clampTwist(sF1, sU1, arm1MinTwist, arm1MaxTwist, arm1Convention, arm1ConeAxis) end
    if arm2Hinge and (arm2MinTwist ~= 0 or arm2MaxTwist ~= 0) then
        clampTwist(sF2, sU2, arm2MinTwist, arm2MaxTwist, arm1Convention, arm2HingeAxis)
    end

    -- apply orientations mapped by convention and restore original positions
    local fwd1, up1
    if arm1Convention == "Y_Fwd_Z_Up" then
        fwd1 = sU1:scale(-1, sT1); up1 = sF1:scale(-1, sT2)
    else
        fwd1 = sF1; up1 = sU1
    end
    if fwd1:lengthSquared() > EPSILON and up1:lengthSquared() > EPSILON and math.abs(fwd1:dot(up1)) < 1 - EPSILON then
        arm1Ref:setOrientation(fwd1, up1)
        arm1Ref:setPosition(arm1LocalPos)
    end

    local fwd2, up2
    if arm2Convention == "Y_Fwd_Z_Up" then
        fwd2 = sU2:scale(-1, sT1); up2 = sF2:scale(-1, sT2)
    else
        fwd2 = sF2; up2 = sU2
    end
    if fwd2:lengthSquared() > EPSILON and up2:lengthSquared() > EPSILON and math.abs(fwd2:dot(up2)) < 1 - EPSILON then
        arm2Ref:setOrientation(fwd2, up2)
        arm2Ref:setPosition(arm2LocalPos)
    end
end

return solveFabrik2Joint
