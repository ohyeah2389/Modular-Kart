local helpers = require("helpers")
local Physics = require("physics_object")
local ikSolver_fabrik = require("fabrik")

local DriverAnimator = class("DriverAnimator")

function DriverAnimator:initialize()
    -- Physics configuration
    self.physicsObjects = {
        bodyLat = Physics({
            posMax = 0.85,
            posMin = 0.15,
            center = 0.5,
            mass = 0.04,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.4,
            springCoef = 10,
            forceMax = 30,
            constantForce = 0,
            endstopRate = 30
        }),

        bodyVert = Physics({
            posMax = 2.0,
            posMin = -0.1,
            center = 0.0,
            mass = 0.005,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.35,
            springCoef = 2,
            forceMax = 30,
            constantForce = 0.1,
            endstopRate = 40
        }),

        bodyLong = Physics({
            posMax = 1.2,
            posMin = 0.3,
            center = 0.5,
            mass = 0.03,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.7,
            springCoef = 5,
            forceMax = 50,
            constantForce = 0,
            endstopRate = 40
        }),

        bodySteerLeanLong = Physics({
            posMax = 3.2,
            posMin = -0.2,
            center = 0.1,
            mass = 0.08,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 1.4,
            springCoef = 15,
            forceMax = 80,
            constantForce = 0,
        }),

        neckTurn = Physics({
            posMax = 0.5,
            posMin = -0.5,
            center = 0,
            mass = 0.05,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.7,
            springCoef = 4,
            forceMax = 30,
            constantForce = 0,
            endstopRate = 10
        }),

        neckTiltLat = Physics({
            posMax = 0.8,
            posMin = -0.8,
            center = 0,
            mass = 0.03,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.7,
            springCoef = 20,
            forceMax = 20,
            constantForce = 0,
            endstopRate = 60
        }),

        neckTiltLong = Physics({
            posMax = 0.2,
            posMin = -0.2,
            center = -0.15,
            mass = 0.04,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.7,
            springCoef = 20,
            forceMax = 20,
            constantForce = 2.8,
            endstopRate = 50
        }),

        legL = Physics({
            posMax = 0.6,
            posMin = -0.15,
            center = 0.0,
            mass = 0.05,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.2,
            springCoef = 5,
            forceMax = 30,
            constantForce = 0,
            endstopRate = 50
        }),

        legR = Physics({
            posMax = 0.15,
            posMin = -0.6,
            center = 0.0,
            mass = 0.05,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.2,
            springCoef = 10,
            forceMax = 30,
            constantForce = 0,
            endstopRate = 50
        }),

        handPhysics = {
            x = Physics({
                posMax = 1,
                posMin = -1,
                center = 0,
                mass = 0.04,
                frictionCoef = 0,
                staticFrictionCoef = 0,
                dampingCoef = 0.3,
                springCoef = 3,
                forceMax = 15,
                constantForce = 0,
                endstopRate = 25
            }),
            y = Physics({
                posMax = 1,
                posMin = -1,
                center = 0,
                mass = 0.02,
                frictionCoef = 0,
                staticFrictionCoef = 0,
                dampingCoef = 0.45,
                springCoef = 2,
                forceMax = 15,
                constantForce = 0,
                endstopRate = 25
            }),
            z = Physics({
                posMax = 1,
                posMin = -1,
                center = 0,
                mass = 0.03,
                frictionCoef = 0,
                staticFrictionCoef = 0,
                dampingCoef = 0.45,
                springCoef = 4,
                forceMax = 15,
                constantForce = 0,
                endstopRate = 25
            }),
        },
    }

    -- Node configuration
    self.nodes = {
        model = { node = ac.findNodes("DRIVER:DRIVER") },
        neck = { node = ac.findNodes("DRIVER:RIG_Nek") },
        head = { node = ac.findNodes("DRIVER:RIG_Head") },
        arm = {
            L = {
                clavicle = { node = ac.findNodes("DRIVER:RIG_Clave_L") },
                upper = { node = ac.findNodes("DRIVER:RIG_Arm_L") },
                forearm = { node = ac.findNodes("DRIVER:RIG_ForeArm_L"), scale = 1.05 },
                forearmEnd = { node = ac.findNodes("DRIVER:RIG_ForeArm_END_L") },
                hand = { node = ac.findNodes("DRIVER:RIG_HAND_L") }
            },
            R = {
                clavicle = { node = ac.findNodes("DRIVER:RIG_Clave_R") },
                upper = { node = ac.findNodes("DRIVER:RIG_Arm_R") },
                forearm = { node = ac.findNodes("DRIVER:RIG_ForeArm_R"), scale = 1.05 },
                forearmEnd = { node = ac.findNodes("DRIVER:RIG_ForeArm_END_R") },
                hand = { node = ac.findNodes("DRIVER:RIG_HAND_R") }
            }
        },
        foot = {
            L = { node = ac.findNodes("DRIVER:RIG_Hill_L") },
            R = { node = ac.findNodes("DRIVER:RIG_Hill_R") }
        },
        shin = {
            L = { node = ac.findNodes("DRIVER:RIG_Shin_L") },
            R = { node = ac.findNodes("DRIVER:RIG_Shin_R") }
        },
        leg = {
            L = { node = ac.findNodes("DRIVER:RIG_Leg_L") },
            R = { node = ac.findNodes("DRIVER:RIG_Leg_R") }
        },
        fingers = {
            L = {
                thumb = {
                    node1 = { node = ac.findNodes("DRIVER:HAND_L_Thumb1"), forward = nil, up = nil },
                    node2 = { node = ac.findNodes("DRIVER:HAND_L_Thumb2"), forward = nil, up = nil },
                    node3 = { node = ac.findNodes("DRIVER:HAND_L_Thumb3"), forward = nil, up = nil }
                },
                index = {
                    node1 = { node = ac.findNodes("DRIVER:HAND_Index1"), forward = nil, up = nil },
                    node2 = { node = ac.findNodes("DRIVER:HAND_Index2"), forward = nil, up = nil },
                    node3 = { node = ac.findNodes("DRIVER:HAND_Index3"), forward = nil, up = nil }
                },
                middle = {
                    node1 = { node = ac.findNodes("DRIVER:HAND_Middle1"), forward = nil, up = nil },
                    node2 = { node = ac.findNodes("DRIVER:HAND_Middle2"), forward = nil, up = nil },
                    node3 = { node = ac.findNodes("DRIVER:HAND_Middle3"), forward = nil, up = nil }
                },
                ring = {
                    node1 = { node = ac.findNodes("DRIVER:HAND_Ring1"), forward = nil, up = nil },
                    node2 = { node = ac.findNodes("DRIVER:HAND_Ring2"), forward = nil, up = nil },
                    node3 = { node = ac.findNodes("DRIVER:HAND_Ring3"), forward = nil, up = nil }
                },
                pinkie = {
                    node1 = { node = ac.findNodes("DRIVER:HAND_Pinkie1"), forward = nil, up = nil },
                    node2 = { node = ac.findNodes("DRIVER:HAND_Pinkie2"), forward = nil, up = nil },
                    node3 = { node = ac.findNodes("DRIVER:HAND_Pinkie3"), forward = nil, up = nil }
                }
            },
            R = {
                thumb = {
                    node1 = { node = ac.findNodes("DRIVER:HAND_R_Thumb1"), forward = nil, up = nil },
                    node2 = { node = ac.findNodes("DRIVER:HAND_R_Thumb2"), forward = nil, up = nil },
                    node3 = { node = ac.findNodes("DRIVER:HAND_R_Thumb3"), forward = nil, up = nil }
                },
                index = {
                    node1 = { node = ac.findNodes("DRIVER:HAND_Index4"), forward = nil, up = nil },
                    node2 = { node = ac.findNodes("DRIVER:HAND_Index5"), forward = nil, up = nil },
                    node3 = { node = ac.findNodes("DRIVER:HAND_Index6"), forward = nil, up = nil }
                },
                middle = {
                    node1 = { node = ac.findNodes("DRIVER:HAND_Middle4"), forward = nil, up = nil },
                    node2 = { node = ac.findNodes("DRIVER:HAND_Middle5"), forward = nil, up = nil },
                    node3 = { node = ac.findNodes("DRIVER:HAND_Middle6"), forward = nil, up = nil }
                },
                ring = {
                    node1 = { node = ac.findNodes("DRIVER:HAND_Ring4"), forward = nil, up = nil },
                    node2 = { node = ac.findNodes("DRIVER:HAND_Ring5"), forward = nil, up = nil },
                    node3 = { node = ac.findNodes("DRIVER:HAND_Ring6"), forward = nil, up = nil }
                },
                pinkie = {
                    node1 = { node = ac.findNodes("DRIVER:HAND_Pinkie4"), forward = nil, up = nil },
                    node2 = { node = ac.findNodes("DRIVER:HAND_Pinkie5"), forward = nil, up = nil },
                    node3 = { node = ac.findNodes("DRIVER:HAND_Pinkie6"), forward = nil, up = nil }
                }
            }
        }
    }

    ac.updateDriverModel()

    -- Initialize arm nodes with base transformations
    for side, parts in pairs(self.nodes.arm) do
        for _, data in pairs(parts) do
            data.node:storeCurrentTransformation()
            data.baseForward = data.node:getLook()
            data.baseUp = data.node:getUp()
            data.forward = data.baseForward:clone()
            data.up = data.baseUp:clone()
        end
    end

    -- Initialize paired nodes
    for _, group in pairs({ self.nodes.foot, self.nodes.shin, self.nodes.leg }) do
        for side, data in pairs(group) do
            data.node:storeCurrentTransformation()
            data.forward = data.node:getLook()
            data.up = data.node:getUp()
        end
    end

    -- Initialize finger nodes
    for side, fingers in pairs(self.nodes.fingers) do
        for _, finger in pairs(fingers) do
            for _, nodeData in pairs(finger) do
                nodeData.node:storeCurrentTransformation()
                nodeData.forward = nodeData.node:getLook()
                nodeData.up = nodeData.node:getUp()
            end
        end
    end

    -- Initialize neck node
    self.nodes.neck.node:storeCurrentTransformation()
    self.nodes.neck.forward = self.nodes.neck.node:getLook()
    self.nodes.neck.up = self.nodes.neck.node:getUp()

    -- Initialize head node
    self.nodes.head.node:storeCurrentTransformation()
    self.nodes.head.forward = self.nodes.head.node:getLook()
    self.nodes.head.up = self.nodes.head.node:getUp()

    -- Animation states
    self.states = {
        handUp = {
            active = false,
            progress = 0,
            duration = 0.6,
            timer = 0,
            held = false,
            rewinding = false,
            transitionPoint = 0.3
        },
        leanForward = {
            active = false,
            progress = 0,
            duration = 0.6,
            timer = 0,
            held = false,
            rewinding = false,
            transitionPoint = 0.35
        }
    }
end

function DriverAnimator:setState(stateName, active, held)
    if self.states[stateName] then
        local state = self.states[stateName]
        state.held = held or false

        if state.held then
            if active ~= state.active then
                state.active = active
                state.rewinding = not active

                if active then
                    state.timer = state.progress * state.duration
                end
            end
        else
            state.active = active
            if active then
                state.timer = 0
                state.progress = 0
                state.rewinding = false
            end
        end
    end
end

function DriverAnimator:updateStates(dt)
    for stateName, state in pairs(self.states) do
        if state.active or state.rewinding then
            if state.rewinding then
                state.timer = math.max(0, state.timer - dt)
                local linearProgress = state.timer / state.duration
                -- Apply sigmoid curve
                state.progress = 1 / (1 + math.exp(-6 * (linearProgress - 0.5)))
                if state.timer <= 0 then
                    state.rewinding = false
                    state.active = false
                    state.progress = 0
                end
            else
                state.timer = math.min(state.duration, state.timer + dt)
                local linearProgress = state.timer / state.duration
                -- Apply sigmoid curve
                state.progress = 1 / (1 + math.exp(-6 * (linearProgress - 0.5)))
                if state.timer >= state.duration and not state.held then
                    state.active = false
                end
            end
        end

        ac.debug(stateName .. ".active", state.active)
        ac.debug(stateName .. ".progress", state.progress)
        ac.debug(stateName .. ".held", state.held)
        ac.debug(stateName .. ".rewinding", state.rewinding)
        ac.debug(stateName .. ".timer", state.timer)
    end
end

local driverArm_R_clavicle = ac.findNodes("DRIVER:RIG_Clave_R")
local driverArm_R_upper = ac.findNodes("DRIVER:RIG_Arm_R")
local driverArm_R_forearm = ac.findNodes("DRIVER:RIG_ForeArm_R")
local driverArm_R_forearmEnd = ac.findNodes("DRIVER:RIG_ForeArm_END_R")
local driverArm_R_hand = ac.findNodes("DRIVER:RIG_HAND_R")

driverArm_R_clavicle:storeCurrentTransformation()
driverArm_R_upper:storeCurrentTransformation()
driverArm_R_forearm:storeCurrentTransformation()
driverArm_R_forearmEnd:storeCurrentTransformation()
driverArm_R_hand:storeCurrentTransformation()

local driverArm_L_clavicle = ac.findNodes("DRIVER:RIG_Clave_L")
local driverArm_L_upper = ac.findNodes("DRIVER:RIG_Arm_L")
local driverArm_L_forearm = ac.findNodes("DRIVER:RIG_ForeArm_L")
local driverArm_L_forearmEnd = ac.findNodes("DRIVER:RIG_ForeArm_END_L")
local driverArm_L_hand = ac.findNodes("DRIVER:RIG_HAND_L")

driverArm_L_clavicle:storeCurrentTransformation()
driverArm_L_upper:storeCurrentTransformation()
driverArm_L_forearm:storeCurrentTransformation()
driverArm_L_forearmEnd:storeCurrentTransformation()
driverArm_L_hand:storeCurrentTransformation()

local driverHips = ac.findNodes("DRIVER:RIG_Hips")
driverHips:storeCurrentTransformation()

local driverCenter = ac.findNodes("DRIVER:RIG_Center")
driverCenter:storeCurrentTransformation()

-- Constant rotation basis for placing the hands on the wheel, computed once
local IK_ROT_ORIGIN = vec3(0, 0.47, 0.15)
local IK_ROT_RADIUS = -0.175
local IK_ROT_LOOK = vec3(0, 0.85, -1):normalize()
local IK_ROT_INIT_UP = vec3(1, 0, 0):normalize()
local IK_ROT_RIGHT = IK_ROT_INIT_UP:cross(IK_ROT_LOOK):normalize()
local IK_ROT_UP = IK_ROT_LOOK:cross(IK_ROT_RIGHT):normalize()
local IK_AXIS_Y = vec3(0, 1, 0)

-- Persistent IK scratch and parameter tables, reused every frame to avoid allocations
local ikRelPos = vec3()
local ikHandTargetR, ikHandTargetL = vec3(), vec3()
local ikConeAxisR, ikConeAxisL = vec3(), vec3()

local ikParamsR = {
    baseRef = driverArm_R_clavicle,
    arm1Ref = driverArm_R_upper,
    arm2Ref = driverArm_R_forearm,
    tipRef = driverArm_R_forearmEnd,
    targetPosPlatform = ikHandTargetR,
    iterations = 20,
    tolerance = 0.001,
    arm1Convention = "Y_Fwd_Z_Up",
    arm2Convention = "Y_Fwd_Z_Up",
    treeDepth = 6,
    arm1ConstraintType = "cone",
    arm1ConeAxisLocal = ikConeAxisR,
    arm1MaxConeAngle = 0,
    arm1MinTwistAngle = -120,
    arm1MaxTwistAngle = -40,
}

local ikParamsL = {
    baseRef = driverArm_L_clavicle,
    arm1Ref = driverArm_L_upper,
    arm2Ref = driverArm_L_forearm,
    tipRef = driverArm_L_forearmEnd,
    targetPosPlatform = ikHandTargetL,
    iterations = 20,
    tolerance = 0.001,
    arm1Convention = "Y_Fwd_Z_Up",
    arm2Convention = "Y_Fwd_Z_Up",
    treeDepth = 6,
    arm1ConstraintType = "cone",
    arm1ConeAxisLocal = ikConeAxisL,
    arm1MaxConeAngle = 0,
    arm1MinTwistAngle = 0,
    arm1MaxTwistAngle = 0,
}

local function driverIK(self, dt)
    local steerAngleRad = math.rad(math.clamp(car.steer, -90, 90))
    local leanProgress = self.states.leanForward.progress

    -- hand target positions on the wheel from the fixed rotation plane basis
    ikRelPos:set(IK_ROT_UP):scale(IK_ROT_RADIUS * math.cos(steerAngleRad))
        :addScaled(IK_ROT_RIGHT, IK_ROT_RADIUS * math.sin(steerAngleRad))
    ikHandTargetR:set(IK_ROT_ORIGIN):addScaled(ikRelPos, 1)
    ikHandTargetL:set(IK_ROT_ORIGIN):addScaled(ikRelPos, -1)

    -- right shoulder cone
    ikConeAxisR:set(
        -0.8 + (leanProgress * 0.3 * helpers.mapRange(car.steer, 0, -90, 0, 1, true)) + helpers.mapRange(car.steer, 0, 90, 0, -0.1, true),
        0.3 - helpers.mapRange(car.steer, -90, 0, -0.5, 0, true),
        0.5 + helpers.mapRange(car.steer, 0, 90, 0, -0.5, true)
    ):normalize()
    ikParamsR.arm1MaxConeAngle = 4 + helpers.mapRange(car.steer, -90, 0, 40, 0, true) + helpers.mapRange(car.steer, 0, 90, 0, 5, true)
    ikSolver_fabrik(ikParamsR)

    -- left shoulder cone
    ikConeAxisL:set(
        0.3 + (leanProgress * 0.3 * helpers.mapRange(car.steer, 0, -90, 0, 1, true)) + helpers.mapRange(car.steer, -90, 0, 0.8, 0, true) + helpers.mapRange(-car.steer, -90, 0, 0.1, 0, true),
        0.0 + helpers.mapRange(car.steer, -90, 0, 0.65, 0, true) + helpers.mapRange(car.steer, 0, 90, 0, 0.05, true) + (leanProgress * 0.6 * helpers.mapRange(car.steer, 0, 90, 0, 1, true)),
        0.3 + helpers.mapRange(car.steer, -90, 0, 0.5, 0, true) + (leanProgress * 0.3 * helpers.mapRange(car.steer, 0, 90, 0, 1, true))
    ):normalize()
    local arm1TargetTwistAngle = -100 + helpers.mapRange(car.steer, -20, 0, -30, 0, true)
    ikParamsL.arm1MaxConeAngle = 6 + helpers.mapRange(-car.steer, -90, 0, 40, 0, true) + helpers.mapRange(-car.steer, 0, 90, 0, 5, true)
    ikParamsL.arm1MinTwistAngle = arm1TargetTwistAngle
    ikParamsL.arm1MaxTwistAngle = arm1TargetTwistAngle - 0.2
    ikSolver_fabrik(ikParamsL)

    driverArm_R_forearmEnd:setRotation(IK_AXIS_Y, math.rad(20 + helpers.mapRange(car.steer, 0, 90, 0, -95, true) + helpers.mapRange(car.steer, -90, 0, 60, 0, true)))
    driverArm_R_hand:setOrientation(vec3(0, -0.3 + (math.clamp(car.steer, 0, 90) * 0.005), 1))

    driverArm_L_forearmEnd:setRotation(IK_AXIS_Y, math.rad(20 + helpers.mapRange(car.steer, 0, 90, 0, -120, true) + helpers.mapRange(car.steer, -90, 0, 60, 0, true)))
    local hand_L_x = -0.3 + helpers.mapRange(car.steer, -90, 0, -0.4, 0, true)
    local hand_L_y = -0.4 + helpers.mapRange(car.steer, 0, 90, 0, 0.6, true) + helpers.mapRange(car.steer, -90, 0, 1, 0, true)
    local hand_L_z = 1
    driverArm_L_hand:setOrientation(vec3(hand_L_x, hand_L_y, hand_L_z), vec3(0 + helpers.mapRange(car.steer, -90, 0, -0.5, 0, true), 1, 0))
end

function DriverAnimator:update(dt, antiResetAdder)
    self:updateStates(dt)

    local breathSine = math.sin(sim.time * 0.002)
    local breathSineHarmonic = math.sin(sim.time * 0.005)
    local breathSineHarmonic2 = math.sin(sim.time * 0.007)

    local legLForce = (car.acceleration.x + (breathSineHarmonic * 0.05) + (breathSine * 0.15))
    local legRForce = (car.acceleration.x + (breathSineHarmonic2 * 0.05) + (breathSine * 0.15))
    local bodyLatForce = (car.acceleration.x + (breathSineHarmonic * 0.005))
    local bodyVertForce = (car.acceleration.y + (breathSine * 0.1))
    local bodyLongForce = (car.acceleration.z + (breathSineHarmonic * 0.005))

    self.physicsObjects.legL:step(-legLForce, dt)
    self.physicsObjects.legR:step(-legRForce, dt)

    self.physicsObjects.neckTurn:step(car.steer * -0.04, dt)
    self.physicsObjects.neckTiltLat:step((car.acceleration.x * -0.65) + (car.steer * 0.035 * helpers.mapRange(math.abs(car.speedKmh), 0, 80, 0.1, 1, true)), dt)
    self.physicsObjects.neckTiltLong:step((car.acceleration.z * -2) + (car.acceleration.y * 0.6) + (self.states.leanForward.progress * -3), dt)

    local legLPos = self.physicsObjects.legL.position
    local legRPos = self.physicsObjects.legR.position
    local neckTurnAnimPos = self.physicsObjects.neckTurn.position
    local neckTiltLatAnimPos = self.physicsObjects.neckTiltLat.position
    local neckTiltLongAnimPos = self.physicsObjects.neckTiltLong.position

    ac.debug("bodyLat position", self.physicsObjects.bodyLat.position)
    ac.debug("bodyLat force", self.physicsObjects.bodyLat.force)
    ac.debug("bodyVert position", self.physicsObjects.bodyVert.position)
    ac.debug("bodyVert force", self.physicsObjects.bodyVert.force)
    ac.debug("bodyLong position", self.physicsObjects.bodyLong.position)
    ac.debug("bodyLong force", self.physicsObjects.bodyLong.force)
    ac.debug("legL position", self.physicsObjects.legL.position)
    ac.debug("legL force", self.physicsObjects.legL.force)
    ac.debug("legR position", self.physicsObjects.legR.position)
    ac.debug("legR force", self.physicsObjects.legR.force)
    ac.debug("neckTurn position", self.physicsObjects.neckTurn.position)
    ac.debug("neckTurn force", self.physicsObjects.neckTurn.force)
    ac.debug("neckTiltLat position", self.physicsObjects.neckTiltLat.position)
    ac.debug("neckTiltLat force", self.physicsObjects.neckTiltLat.force)
    ac.debug("neckTiltLong position", self.physicsObjects.neckTiltLong.position)
    ac.debug("neckTiltLong force", self.physicsObjects.neckTiltLong.force)
    ac.debug("neckTurnAnimPos", neckTurnAnimPos)
    ac.debug("neckTiltLatAnimPos", neckTiltLatAnimPos)
    ac.debug("neckTiltLongAnimPos", neckTiltLongAnimPos)

    self.physicsObjects.bodyLat:step(-bodyLatForce, dt)
    self.physicsObjects.bodyVert:step(-bodyVertForce, dt)
    self.physicsObjects.bodyLong:step(-bodyLongForce, dt)
    local bodyLatPos = self.physicsObjects.bodyLat.position - 0.5
    local bodyVertPos = self.physicsObjects.bodyVert.position - 0.5
    local bodyLongPos = self.physicsObjects.bodyLong.position - 0.5
    driverCenter:setPosition(vec3(0.045 + bodyLatPos * 0.05, 0.09 + bodyVertPos * 0.03, -0.16 + bodyLongPos * 0.02))

    self.physicsObjects.bodySteerLeanLong.center = math.clamp(math.remap(self.states.leanForward.progress, 0, 1, 0.1, 2.5) + ((math.sin(math.rad(math.abs(car.steer)))^3) * 0.55), 0, 3)

    self.physicsObjects.bodySteerLeanLong:step(0, dt)

    local hipsOrientX = 0.15 * (-car.steer/90) + bodyLatPos * -0.05
    local hipsOrientY = (-self.physicsObjects.bodySteerLeanLong.position) - 0.2 - bodyLongPos
    local hipsOrientZ = 1
    local hipsUpX = 0.05 * (-car.steer/90)
    local hipsUpY = 0
    local hipsUpZ = 1

    driverHips:setOrientation(vec3(hipsOrientX, hipsOrientY, hipsOrientZ), vec3(hipsUpX, hipsUpY, hipsUpZ))

    -- Update feet
    self.nodes.foot.L.node:setOrientation(
        self.nodes.foot.L.forward + vec3(0, 0, (car.brake * 0.15)),
        self.nodes.foot.L.up + vec3(legLPos * 1, legLPos * 0.5, legLPos * -2)
    )
    self.nodes.foot.R.node:setOrientation(
        self.nodes.foot.R.forward + vec3(0, 0, (car.gas * 0.3)),
        self.nodes.foot.R.up + vec3(legRPos * 1, 0, 0)
    )

    -- Update neck
    self.nodes.neck.node:setOrientation(
        self.nodes.neck.forward + vec3(0, 0 + (self.states.leanForward.progress * 0.3), bodyLongPos * 2),
        self.nodes.neck.up + vec3(0, 0, 0)
    )

    self.nodes.head.node:setOrientation(
        self.nodes.head.forward + vec3(neckTurnAnimPos, neckTiltLongAnimPos * -2, 0),
        self.nodes.head.up + vec3(neckTiltLatAnimPos, 0, neckTiltLongAnimPos * -2)
    )

    -- Update shins
    self.nodes.shin.L.node:setOrientation(
        self.nodes.shin.L.forward + vec3(0 + (legLPos * 0.2), 0 - (legLPos * 0.2), (car.brake * 0.05) + ((self.physicsObjects.bodyVert.position) * -0.2)),
        self.nodes.shin.L.up
    )
    self.nodes.shin.R.node:setOrientation(
        self.nodes.shin.R.forward + vec3(0 + (legRPos * 0.2), 0 - (legRPos * 0.2), (car.gas * 0.125) + ((self.physicsObjects.bodyVert.position) * -0.2)),
        self.nodes.shin.R.up
    )

    -- Update legs
    self.nodes.leg.L.node:setOrientation(
        self.nodes.leg.L.forward + vec3(0 + (legLPos * 0.15), 0, (car.brake * 0.025)),
        self.nodes.leg.L.up + vec3(legLPos * -0.25, legLPos * -0.6, 0)
    )
    self.nodes.leg.R.node:setOrientation(
        self.nodes.leg.R.forward + vec3(0 + (legRPos * 0.15), 0, (car.gas * 0.05)),
        self.nodes.leg.R.up + vec3(legRPos * -0.3, legRPos * 0.6, 0)
    )

    -- Update finger idle animations
    for i, fingerName in ipairs({ "thumb", "index", "middle", "ring", "pinkie" }) do
        local timeOffset = (i - 1) * -80
        local steeringScaleOut = helpers.mapRange(math.abs(car.steer), 0, 60, 1.5, 0, true)
        local wigglePerlinLeft = math.perlin((sim.time + timeOffset) * 0.0004, 2) ^ 5
        local wigglePerlinRight = math.perlin((sim.time + timeOffset + 30000) * 0.0004, 2) ^ 5
        local fingerWiggleLeft = wigglePerlinLeft * -steeringScaleOut
        local fingerWiggleRight = wigglePerlinRight * -steeringScaleOut
        local steerSplayLeft = math.clamp(math.remap(car.steer, -90, 0, 1, 0), 0, 1)
        local steerSplayRight = math.clamp(math.remap(car.steer, 90, 0, 1, 0), 0, 1)

        for j = 1, 3 do
            local wiggleAmount = helpers.mapRange(j, 1, 3, 1, 1, true)
            local thumbScalar = 0.5

            if fingerName == "thumb" then
                self.nodes.fingers.L[fingerName]["node" .. j].node:setOrientation(
                    self.nodes.fingers.L[fingerName]["node" .. j].forward +
                    vec3(0, fingerWiggleLeft * -wiggleAmount * thumbScalar, 0),
                    self.nodes.fingers.L[fingerName]["node" .. j].up
                )
                self.nodes.fingers.R[fingerName]["node" .. j].node:setOrientation(
                    self.nodes.fingers.R[fingerName]["node" .. j].forward +
                    vec3(0, fingerWiggleRight * -wiggleAmount * thumbScalar, 0),
                    self.nodes.fingers.R[fingerName]["node" .. j].up
                )
            else
                self.nodes.fingers.L[fingerName]["node" .. j].node:setOrientation(
                    self.nodes.fingers.L[fingerName]["node" .. j].forward,
                    self.nodes.fingers.L[fingerName]["node" .. j].up + vec3(fingerWiggleLeft * wiggleAmount, steerSplayLeft * (i - 2) * 0.5, 0)
                )
                self.nodes.fingers.R[fingerName]["node" .. j].node:setOrientation(
                    self.nodes.fingers.R[fingerName]["node" .. j].forward,
                    self.nodes.fingers.R[fingerName]["node" .. j].up + vec3(fingerWiggleRight * -wiggleAmount, steerSplayRight * (i - 2) * 0.3, 0)
                )
            end
        end
    end

    -- Run IK for arms
    driverIK(self, dt)

    -- Animation handUp
    if (self.states.handUp.active or self.states.handUp.rewinding) and self.states.handUp.progress > 0 then
        local forceX = car.acceleration.x
        local forceY = car.acceleration.y
        local forceZ = car.acceleration.z

        local randomX = math.perlin(sim.time * 0.0007, 3)
        local randomY = math.perlin(sim.time * 0.0005, 4)
        local randomZ = math.perlin(sim.time * 0.0004, 4)

        self.physicsObjects.handPhysics.x:step(-forceX + randomX, dt)
        self.physicsObjects.handPhysics.y:step(-forceY + randomY, dt)
        self.physicsObjects.handPhysics.z:step(-forceZ + randomZ, dt)
        local displacementX = self.physicsObjects.handPhysics.x.position
        local displacementY = self.physicsObjects.handPhysics.y.position
        local displacementZ = self.physicsObjects.handPhysics.z.position

        ac.debug("displacementX", displacementX)
        ac.debug("displacementY", displacementY)
        ac.debug("displacementZ", displacementZ)

        local targetRotations = {
            clavicle = {
                forward = vec3(0.3, 0, 0),
                up = vec3(0, 0.3, 0)
            },
            upper = {
                forward = vec3(0, -0.5 + (displacementX * 0.5) - (displacementY * 0.5), 0.5 + (displacementY * 0.2)),
                up = vec3(1 - (displacementZ * 0.5), -0.5 + displacementZ, 0)
            },
            forearm = {
                forward = vec3(1 + (displacementX * 0.5) + (displacementY * 0.5), 0.5 - (displacementZ * 0.5), -1),
                up = vec3(0, 1 - (displacementZ * 2), 0)
            },
            forearmEnd = {
                forward = vec3(0, 0, 0),
                up = vec3(0, 0, 0)
            },
            hand = {
                forward = vec3(-0.5 + (displacementZ * 1), 0.5 - (displacementZ * 0.5), 0),
                up = vec3(0, 0, 0)
            }
        }

        local blendIntermediateOffsets = {
            upper = {
                forward = vec3(0, 0.5, 0),
                up = vec3(0, 0, 0)
            }
        }

        -- Apply blended rotations based on animation progress
        for partName, partTarget in pairs(targetRotations) do
            local node = self.nodes.arm.L[partName]
            local progress = self.states.handUp.progress
            local transitionScalar = helpers.mapRange(math.abs(car.steer), 0, 20, 0.5, 1, true)
            local transitionPoint = self.states.handUp.transitionPoint * transitionScalar

            -- current steering animation position
            local currentForward = node.node:getLook()
            local currentUp = node.node:getUp()
            local blendedForward, blendedUp
            if progress <= transitionPoint then
                -- First phase: Blend from current position to base position
                local initialBlend = helpers.mapRange(progress, 0, transitionPoint, 0, 1)
                if blendIntermediateOffsets[partName] then
                    blendedForward = currentForward +
                        (node.baseForward - currentForward + (blendIntermediateOffsets[partName].forward * transitionScalar)) *
                        initialBlend
                    blendedUp = currentUp +
                        (node.baseUp - currentUp + (blendIntermediateOffsets[partName].up * transitionScalar)) *
                        initialBlend
                else
                    blendedForward = currentForward + (node.baseForward - currentForward) * initialBlend
                    blendedUp = currentUp + (node.baseUp - currentUp) * initialBlend
                end
            else
                -- Second phase: Blend from intermediate/base position to raised position
                local raisedBlend = helpers.mapRange(progress, transitionPoint, 1, 0, 1)
                if blendIntermediateOffsets[partName] then
                    local intermediateForward = node.baseForward +
                        (blendIntermediateOffsets[partName].forward * transitionScalar)
                    local intermediateUp = node.baseUp + (blendIntermediateOffsets[partName].up * transitionScalar)
                    blendedForward = intermediateForward +
                        ((node.baseForward + partTarget.forward - intermediateForward) * raisedBlend)
                    blendedUp = intermediateUp + ((node.baseUp + partTarget.up - intermediateUp) * raisedBlend)
                else
                    blendedForward = node.baseForward + (partTarget.forward * raisedBlend)
                    blendedUp = node.baseUp + (partTarget.up * raisedBlend)
                end
            end
            node.node:setOrientation(blendedForward, blendedUp)
        end

        -- Apply finger closing animation
        for side, fingers in pairs(self.nodes.fingers) do
            if side == "L" then
                for fingerName, finger in pairs(fingers) do
                    for j, nodeData in pairs(finger) do
                        if fingerName == "thumb" then
                            nodeData.node:setOrientation(
                                nodeData.forward + (vec3(0, 0.3, 0) * self.states.handUp.progress),
                                nodeData.up
                            )
                        else
                            nodeData.node:setOrientation(
                                nodeData.forward,
                                nodeData.up + (vec3(-1 * (fingerName == "index" and 0.7 or
                                    fingerName == "middle" and 0.8 or
                                    fingerName == "ring" and 0.85 or 0.95), 0, 0) * self.states.handUp.progress)
                            )
                        end
                    end
                end
            end
        end
    end
end

return DriverAnimator
