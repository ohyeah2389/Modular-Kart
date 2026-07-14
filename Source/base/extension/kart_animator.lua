local helpers = require("helpers")
local Physics = require("physics_object")
local NodeAnimator = require("node_animator")

local KartAnimator = class("KartAnimator")
local axisX = vec3(1, 0, 0)
local axisY = vec3(0, 1, 0)
local axisZ = vec3(0, 0, 1)
local axisNegX = vec3(-1, 0, 0)
local axisZero = vec3(0, 0, 0)
local brakeDiscPosVec = vec3()
local brakePad1PosVec = vec3()
local brakePad2PosVec = vec3()
local brakeLeverUpVec = vec3()
local pedalBrakeForwardVec = vec3()
local pedalGasForwardVec = vec3()
local tierodLPos = vec3()
local tierodRPos = vec3()

function KartAnimator:initialize()
    -- Physics configuration
    self.physics = {
        brakeDisc = Physics {
            posMax = 1,
            posMin = -1,
            center = 0,
            mass = 0.01,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.3,
            springCoef = 0,
            forceMax = 30,
            constantForce = 0,
        },
        sidepodRight = NodeAnimator {
            nodeName = "SidepodBouncerRight",
            posMax = 0.02,
            posMin = -0.02,
            center = 0,
            mass = 0.05,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.02,
            springCoef = 0,
            forceMax = 50,
            constantForce = -0.3,
            flipped = false,
            vibration = 0.0,
        },
        sidepodLeft = NodeAnimator {
            nodeName = "SidepodBouncerLeft",
            posMax = 0.02,
            posMin = -0.02,
            center = 0,
            mass = 0.05,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.02,
            springCoef = 0,
            forceMax = 50,
            constantForce = -0.3,
            flipped = true,
            vibration = 0.0,
        },
        bumperRear = NodeAnimator {
            nodeName = "RearBumperPlastic",
            posMax = 0.05,
            posMin = -0.05,
            center = 0,
            mass = 0.1,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.2,
            springCoef = 0,
            forceMax = 50,
            constantForce = -0.5,
            endstopRate = 50,
            flipped = false,
            vibration = 0.0,
        },
        bumperRearVertical = NodeAnimator {
            nodeName = "RearBumperBracket",
            posMax = 0.02,
            posMin = -0.01,
            center = 0,
            mass = 0.1,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.1,
            springCoef = 0,
            forceMax = 100,
            constantForce = -0.5,
            endstopRate = 100,
            flipped = false,
        },
        bumperRearAxial = NodeAnimator {
            nodeName = "RearBumperBracketRotator",
            posMax = 0.5,
            posMin = -0.5,
            center = 0,
            mass = 0.05,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.6,
            springCoef = 50,
            forceMax = 100,
            constantForce = 0,
            flipped = false,
        },
        nassau = NodeAnimator {
            nodeName = "NassauBouncer",
            posMax = 0.1,
            posMin = -0.1,
            center = 0,
            mass = 0.03,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.35,
            springCoef = 70,
            forceMax = 100,
            constantForce = 0.0,
            endstopRate = 70,
            vibration = 0.0,
        },
        nosecone = NodeAnimator {
            nodeName = "NoseconeBouncer",
            posMax = 0.04,
            posMin = -0.04,
            center = 0,
            mass = 0.08,
            frictionCoef = 0,
            staticFrictionCoef = 0,
            dampingCoef = 0.5,
            springCoef = 300,
            forceMax = 100,
            constantForce = 0,
            endstopRate = 120,
            vibration = 0.0,
        }
    }

    -- Node configuration
    self.nodes = {
        pedals = {
            gas = { node = "PedalGas" },
            brake = { node = "PedalBrake" }
        },
        brakeSystem = {
            lever = { node = "BrakeLever" },
            disc = { node = "BrakeDiscTabs" },
            pad1 = { node = "BrakePad.001" },
            pad2 = { node = "BrakePad.002" }
        },
        steering = {
            carNode = { node = "BODYTR" },
            tierodLTarget = { node = "DIR2_anim_tierodLF" },
            tierodRTarget = { node = "DIR2_anim_tierodRF" },
            tierodLControl = { node = "DIR_anim_tierodLF" },
            tierodRControl = { node = "DIR_anim_tierodRF" }
        },
        rearAxle = {
            axleNode = { node = "RearAxle" },
        }
    }

    -- Initialize pedal nodes
    for _, pedal in pairs(self.nodes.pedals) do
        local ref = ac.findNodes(pedal.node)
        if not ref:empty() then
            pedal.node = ref
            pedal.node:storeCurrentTransformation()
            pedal.forward = pedal.node:getLook()
            pedal.up = pedal.node:getUp()
        else
            pedal.node = nil
        end
    end

    -- Initialize brake system nodes
    for _, part in pairs(self.nodes.brakeSystem) do
        local ref = ac.findNodes(part.node)
        if not ref:empty() then
            part.node = ref
            part.node:storeCurrentTransformation()
            if part.node:getLook() then
                part.forward = part.node:getLook()
                part.up = part.node:getUp()
            end
            part.position = part.node:getPosition()
        else
            part.node = nil
        end
    end

    -- Initialize steering nodes
    for _, part in pairs(self.nodes.steering) do
        local ref = ac.findNodes(part.node)
        part.node = not ref:empty() and ref or nil
    end

    -- Initialize rear axle nodes
    for _, part in pairs(self.nodes.rearAxle) do
        local ref = ac.findNodes(part.node)
        if not ref:empty() then
            part.node = ref
            part.node:storeCurrentTransformation()
            part.forward = part.node:getLook()
            part.up = part.node:getUp()
        else
            part.node = nil
        end
    end
end

function KartAnimator:update(dt, angularAcceleration)
    local forceSidepodRight = -car.acceleration.y + (angularAcceleration.z * 0.1)
    local forceSidepodLeft = -car.acceleration.y + (angularAcceleration.z * -0.1)
    local forceBumperRear = car.acceleration.y
    local forceBumperRearAxial = angularAcceleration.z
    local forceBumperRearVertical = -car.acceleration.y
    local forceNassau = -car.acceleration.x
    local forceNosecone = car.acceleration.y

    self.physics.sidepodRight:update(forceSidepodRight, axisX, axisZero, dt)
    self.physics.sidepodLeft:update(forceSidepodLeft, axisX, axisZero, dt)
    self.physics.bumperRear:update(forceBumperRear, axisY, axisZero, dt)
    self.physics.bumperRearAxial:update(forceBumperRearAxial, axisX, axisZero, dt)
    self.physics.bumperRearVertical:update(forceBumperRearVertical, axisZero, axisZ, dt)
    self.physics.nassau:update(forceNassau, axisX, axisZero, dt)
    self.physics.nosecone:update(forceNosecone, axisZ, axisZero, dt)

    self.physics.brakeDisc.posMax = helpers.mapRange(car.brake, 0, 0.2, 1, 0.1, true)
    self.physics.brakeDisc.posMin = helpers.mapRange(car.brake, 0, 0.2, -1, -0.1, true)
    self.physics.brakeDisc:step(car.acceleration.x * -100, dt)
    local brakeDiscAnimPos = self.physics.brakeDisc.position

    if self.nodes.brakeSystem.disc.node then
        brakeDiscPosVec:set(self.nodes.brakeSystem.disc.position):addScaled(
            axisZ,
            brakeDiscAnimPos * helpers.mapRange(car.brake, 0, 0.2, 1, 0, true) * 0.0005
        )
        self.nodes.brakeSystem.disc.node:setPosition(
            brakeDiscPosVec
        )
    end
    if self.nodes.brakeSystem.pad1.node then
        brakePad1PosVec:set(self.nodes.brakeSystem.pad1.position):addScaled(
            axisX,
            helpers.mapRange(car.brake, 0, 0.2, 0, -0.001, true)
        )
        self.nodes.brakeSystem.pad1.node:setPosition(
            brakePad1PosVec
        )
    end
    if self.nodes.brakeSystem.pad2.node then
        brakePad2PosVec:set(self.nodes.brakeSystem.pad2.position):addScaled(
            axisX,
            helpers.mapRange(car.brake, 0, 0.2, 0, 0.001, true)
        )
        self.nodes.brakeSystem.pad2.node:setPosition(
            brakePad2PosVec
        )
    end

    -- Update brake lever
    if self.nodes.brakeSystem.lever.node then
        brakeLeverUpVec:set(self.nodes.brakeSystem.lever.up):addScaled(axisY, car.brake * 0.47)
        self.nodes.brakeSystem.lever.node:setOrientation(
            self.nodes.brakeSystem.lever.forward,
            brakeLeverUpVec
        )
    end

    -- Update steering tierods
    if self.nodes.steering.tierodLTarget.node and self.nodes.steering.tierodLControl.node then
        tierodLPos:set(helpers.getPositionInCarFrame(self.nodes.steering.tierodLTarget.node, self.nodes.steering.carNode.node))
        self.nodes.steering.tierodLControl.node:setPosition(
            tierodLPos
        )
    end
    if self.nodes.steering.tierodRTarget.node and self.nodes.steering.tierodRControl.node then
        tierodRPos:set(helpers.getPositionInCarFrame(self.nodes.steering.tierodRTarget.node, self.nodes.steering.carNode.node))
        self.nodes.steering.tierodRControl.node:setPosition(
            tierodRPos
        )
    end

    -- Update pedals with converted forces
    if self.nodes.pedals.brake.node then
        pedalBrakeForwardVec:set(self.nodes.pedals.brake.forward):addScaled(axisZ, car.brake * 0.2)
        self.nodes.pedals.brake.node:setOrientation(
            pedalBrakeForwardVec,
            self.nodes.pedals.brake.up
        )
    end
    if self.nodes.pedals.gas.node then
        pedalGasForwardVec:set(self.nodes.pedals.gas.forward):addScaled(axisZ, car.gas * 0.4)
        self.nodes.pedals.gas.node:setOrientation(
            pedalGasForwardVec,
            self.nodes.pedals.gas.up
        )
    end

    -- Rotate rear axle
    if self.nodes.rearAxle.axleNode.node then
        self.nodes.rearAxle.axleNode.node:rotate(axisNegX, car.wheels[3].angularSpeed * dt)
    end
end

return KartAnimator
