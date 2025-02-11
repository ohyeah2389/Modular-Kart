local helpers = require("helpers")
local Physics = require("physics_classes")

local DriverAnimator = class("DriverAnimator")

function DriverAnimator:initialize()
    -- Physics configuration
    self.physicsObjects = {
        bodyLat = Physics{
            posMax = 0.85,
            posMin = 0.15,
            center = 0.5,
            mass = 2,
            frictionCoef = 0.4,
            springCoef = 10,
            forceMax = 20,
            constantForce = 0,
            endstopRate = 30
        },

        bodyVert = Physics{
            posMax = 0.9,
            posMin = 0.1,
            center = 0.5,
            mass = 3,
            frictionCoef = 0.3,
            springCoef = 30,
            forceMax = 20,
            constantForce = 5,
            endstopRate = 40
        },

        legL = Physics{
            posMax = 0.8,
            posMin = 0.2,
            center = 0.5,
            mass = 2,
            frictionCoef = 0.4,
            springCoef = 15,
            forceMax = 20,
            constantForce = 0,
            endstopRate = 50
        },

        legR = Physics{
            posMax = 0.8,
            posMin = 0.2,
            center = 0.5,
            mass = 3,
            frictionCoef = 0.3,
            springCoef = 30,
            forceMax = 20,
            constantForce = 0,
            endstopRate = 50
        },

        handPhysics = {
            x = Physics{
                posMax = 1,
                posMin = -1,
                center = 0,
                mass = 4,
                frictionCoef = 0.3,
                springCoef = 20,
                forceMax = 15,
                constantForce = 0,
                endstopRate = 25
            },
            y = Physics{
                posMax = 1,
                posMin = -1,
                center = 0,
                mass = 2,
                frictionCoef = 0.3,
                springCoef = 10,
                forceMax = 15,
                constantForce = 0,
                endstopRate = 25
            },
            z = Physics{
                posMax = 1,
                posMin = -1,
                center = 0,
                mass = 3,
                frictionCoef = 0.4,
                springCoef = 30,
                forceMax = 15,
                constantForce = 0,
                endstopRate = 25
            }
        },
    }

    -- Node configuration
    self.nodes = {
        model = { node = "DRIVER:DRIVER" },
        arm = {
            L = {
                clavicle = { node = "DRIVER:RIG_Clave_L" },
                upper = { node = "DRIVER:RIG_Arm_L" },
                forearm = { node = "DRIVER:RIG_ForeArm_L", scale = 1.05 },
                forearmEnd = { node = "DRIVER:RIG_ForeArm_END_L" },
                hand = { node = "DRIVER:RIG_HAND_L" }
            },
            R = {
                clavicle = { node = "DRIVER:RIG_Clave_R" },
                upper = { node = "DRIVER:RIG_Arm_R" },
                forearm = { node = "DRIVER:RIG_ForeArm_R", scale = 1.05 },
                forearmEnd = { node = "DRIVER:RIG_ForeArm_END_R" },
                hand = { node = "DRIVER:RIG_HAND_R" }
            }
        },
        foot = {
            L = { node = "DRIVER:RIG_Hill_L" },
            R = { node = "DRIVER:RIG_Hill_R" }
        },
        shin = {
            L = { node = "DRIVER:RIG_Shin_L" },
            R = { node = "DRIVER:RIG_Shin_R" }
        },
        leg = {
            L = { node = "DRIVER:RIG_Leg_L" },
            R = { node = "DRIVER:RIG_Leg_R" }
        },
        fingers = {
            L = {
                thumb = {
                    node1 = { node = "DRIVER:HAND_L_Thumb1", forward = nil, up = nil },
                    node2 = { node = "DRIVER:HAND_L_Thumb2", forward = nil, up = nil },
                    node3 = { node = "DRIVER:HAND_L_Thumb3", forward = nil, up = nil }
                },
                index = { 
                    node1 = { node = "DRIVER:HAND_Index1", forward = nil, up = nil },
                    node2 = { node = "DRIVER:HAND_Index2", forward = nil, up = nil },
                    node3 = { node = "DRIVER:HAND_Index3", forward = nil, up = nil }
                },
                middle = {
                    node1 = { node = "DRIVER:HAND_Middle1", forward = nil, up = nil },
                    node2 = { node = "DRIVER:HAND_Middle2", forward = nil, up = nil },
                    node3 = { node = "DRIVER:HAND_Middle3", forward = nil, up = nil }
                },
                ring = {
                    node1 = { node = "DRIVER:HAND_Ring1", forward = nil, up = nil },
                    node2 = { node = "DRIVER:HAND_Ring2", forward = nil, up = nil },
                    node3 = { node = "DRIVER:HAND_Ring3", forward = nil, up = nil }
                },
                pinkie = {
                    node1 = { node = "DRIVER:HAND_Pinkie1", forward = nil, up = nil },
                    node2 = { node = "DRIVER:HAND_Pinkie2", forward = nil, up = nil },
                    node3 = { node = "DRIVER:HAND_Pinkie3", forward = nil, up = nil }
                }
            },
            R = {
                thumb = {
                    node1 = { node = "DRIVER:HAND_R_Thumb1", forward = nil, up = nil },
                    node2 = { node = "DRIVER:HAND_R_Thumb2", forward = nil, up = nil },
                    node3 = { node = "DRIVER:HAND_R_Thumb3", forward = nil, up = nil }
                },
                index = { 
                    node1 = { node = "DRIVER:HAND_Index4", forward = nil, up = nil },
                    node2 = { node = "DRIVER:HAND_Index5", forward = nil, up = nil },
                    node3 = { node = "DRIVER:HAND_Index6", forward = nil, up = nil }
                },
                middle = {
                    node1 = { node = "DRIVER:HAND_Middle4", forward = nil, up = nil },
                    node2 = { node = "DRIVER:HAND_Middle5", forward = nil, up = nil },
                    node3 = { node = "DRIVER:HAND_Middle6", forward = nil, up = nil }
                },
                ring = {
                    node1 = { node = "DRIVER:HAND_Ring4", forward = nil, up = nil },
                    node2 = { node = "DRIVER:HAND_Ring5", forward = nil, up = nil },
                    node3 = { node = "DRIVER:HAND_Ring6", forward = nil, up = nil }
                },
                pinkie = {
                    node1 = { node = "DRIVER:HAND_Pinkie4", forward = nil, up = nil },
                    node2 = { node = "DRIVER:HAND_Pinkie5", forward = nil, up = nil },
                    node3 = { node = "DRIVER:HAND_Pinkie6", forward = nil, up = nil }
                }
            }
        }
    }

    -- Initialize model node
    self.nodes.model.node = ac.findNodes(self.nodes.model.node)

    ac.updateDriverModel()

    -- Initialize arm nodes with base transformations
    for side, parts in pairs(self.nodes.arm) do
        for _, data in pairs(parts) do
            data.node = ac.findNodes(data.node)
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
            data.node = ac.findNodes(data.node)
            data.node:storeCurrentTransformation()
            data.forward = data.node:getLook()
            data.up = data.node:getUp()
        end
    end

    -- Initialize finger nodes
    for side, fingers in pairs(self.nodes.fingers) do
        for _, finger in pairs(fingers) do
            for _, nodeData in pairs(finger) do
                nodeData.node = ac.findNodes(nodeData.node)
                nodeData.node:storeCurrentTransformation()
                nodeData.forward = nodeData.node:getLook()
                nodeData.up = nodeData.node:getUp()
            end
        end
    end

    -- Animation states
    self.states = {
        handUp = {
            active = false,
            progress = 0,
            duration = 0.4,
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
                state.progress = state.timer / state.duration
                if state.progress <= 0 then
                    state.rewinding = false
                    state.active = false
                end
            else
                state.timer = math.min(state.duration, state.timer + dt)
                state.progress = state.timer / state.duration
                if state.progress >= 1 and not state.held then
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


function DriverAnimator:update(dt, antiResetAdder)
    self:updateStates(dt)

    local breathSine = math.sin(sim.time * 0.002)
    local breathSineHarmonic = math.sin(sim.time * 0.005)
    local breathSineHarmonic2 = math.sin(sim.time * 0.007)

    local legLForce = (car.acceleration.x * self.physicsObjects.legL.mass + (breathSineHarmonic * 0.04) + (breathSine * 0.1))
    local legRForce = (car.acceleration.x * self.physicsObjects.legR.mass + (breathSineHarmonic2 * 0.04) + (breathSine * 0.1))
    local bodyLatForce = (car.acceleration.x * self.physicsObjects.bodyLat.mass + (breathSineHarmonic * 0.02))
    local bodyVertForce = (-car.acceleration.y * self.physicsObjects.bodyVert.mass + (breathSine * 0.2))

    local legLAnimPos = self.physicsObjects.legL:step(legLForce, dt)
    local legRAnimPos = self.physicsObjects.legR:step(legRForce, dt)

    local legLPos = legLAnimPos
    local legRPos = legRAnimPos

    ac.debug("bodyLat position", self.physicsObjects.bodyLat.position)
    ac.debug("bodyLat force", self.physicsObjects.bodyLat.force)
    ac.debug("bodyVert position", self.physicsObjects.bodyVert.position)
    ac.debug("bodyVert force", self.physicsObjects.bodyVert.force)
    ac.debug("legL position", self.physicsObjects.legL.position)
    ac.debug("legL force", self.physicsObjects.legL.force)
    ac.debug("legR position", self.physicsObjects.legR.position)
    ac.debug("legR force", self.physicsObjects.legR.force)

    -- Update vertical and lateral baked animations
    self.nodes.model.node:setAnimation("../animations/latG.ksanim", math.clamp(self.physicsObjects.bodyLat:step(bodyLatForce, dt), 0.02, 0.98) + (breathSineHarmonic * 0.005) + ((antiResetAdder - 0.5) * 0.005))
    self.nodes.model.node:setAnimation("../animations/vertG.ksanim", math.clamp(self.physicsObjects.bodyVert:step(bodyVertForce, dt), 0.02, 0.98) + (breathSine * 0.01) + ((antiResetAdder - 0.5) * 0.005))

    -- Update feet
    self.nodes.foot.L.node:setOrientation(
        self.nodes.foot.L.forward + vec3(0, 0, (car.brake * 0.15) - 0.03),
        self.nodes.foot.L.up
    )
    self.nodes.foot.R.node:setOrientation(
        self.nodes.foot.R.forward + vec3(0, 0, (car.gas * 0.32) + 0.05),
        self.nodes.foot.R.up
    )

    -- Update shins
    self.nodes.shin.L.node:setOrientation(
        self.nodes.shin.L.forward + vec3(0 + (legLPos * 0.2), 0, (car.brake * 0.05) - 0.1 + ((self.physicsObjects.bodyVert.position - 0.5) * -0.2)),
        self.nodes.shin.L.up
    )
    self.nodes.shin.R.node:setOrientation(
        self.nodes.shin.R.forward + vec3(0 + (legRPos * 0.2), 0 - (legRPos * 0.2), (car.gas * 0.2) - 0.2 + ((self.physicsObjects.bodyVert.position - 0.5) * -0.2)),
        self.nodes.shin.R.up
    )

    -- Update legs
    self.nodes.leg.L.node:setOrientation(
        self.nodes.leg.L.forward + vec3(0 + (legLPos * 0.15), 0, (car.brake * 0.025) - 0.1),
        self.nodes.leg.L.up + vec3(legLPos * -0.25, legLPos * -0.6, 0)
    )
    self.nodes.leg.R.node:setOrientation(
        self.nodes.leg.R.forward + vec3(-0.03 + (legRPos * 0.15), 0, (car.gas * 0.08) - 0.15),
        self.nodes.leg.R.up + vec3(legRPos * -0.3, legRPos * 0.6, 0)
    )

    -- Update finger idle animations
    local fingerNames = {"thumb", "index", "middle", "ring", "pinkie"}
    for i, fingerName in ipairs(fingerNames) do
        local timeOffset = (i - 1) * -80
        local steeringScaleOut = helpers.mapRange(math.abs(car.steer), 0, 60, 1.5, 0, true)
        local wigglePerlinLeft = math.perlin((sim.time + timeOffset) * 0.0004, 2) ^ 5
        local wigglePerlinRight = math.perlin((sim.time + timeOffset + 30000) * 0.0004, 2) ^ 5
        local fingerWiggleLeft = wigglePerlinLeft * -steeringScaleOut
        local fingerWiggleRight = wigglePerlinRight * -steeringScaleOut

        for j = 1, 3 do
            local wiggleAmount = helpers.mapRange(j, 1, 3, 1, 1, true)
            local thumbScalar = 0.5

            if fingerName == "thumb" then
                self.nodes.fingers.L[fingerName]["node"..j].node:setOrientation(
                    self.nodes.fingers.L[fingerName]["node"..j].forward + vec3(0, fingerWiggleLeft * -wiggleAmount * thumbScalar, 0),
                    self.nodes.fingers.L[fingerName]["node"..j].up
                )
                self.nodes.fingers.R[fingerName]["node"..j].node:setOrientation(
                    self.nodes.fingers.R[fingerName]["node"..j].forward + vec3(0, fingerWiggleRight * -wiggleAmount * thumbScalar, 0),
                    self.nodes.fingers.R[fingerName]["node"..j].up
                )
            else
                self.nodes.fingers.L[fingerName]["node"..j].node:setOrientation(
                    self.nodes.fingers.L[fingerName]["node"..j].forward,
                    self.nodes.fingers.L[fingerName]["node"..j].up + vec3(fingerWiggleLeft * wiggleAmount, 0, 0)
                )
                self.nodes.fingers.R[fingerName]["node"..j].node:setOrientation(
                    self.nodes.fingers.R[fingerName]["node"..j].forward,
                    self.nodes.fingers.R[fingerName]["node"..j].up + vec3(fingerWiggleRight * -wiggleAmount, 0, 0)
                )
            end
        end
    end

    -- Animation handUp
    if (self.states.handUp.active or self.states.handUp.rewinding) and self.states.handUp.progress > 0 then
        local forceX = car.acceleration.x * self.physicsObjects.handPhysics.x.mass
        local forceY = car.acceleration.y * self.physicsObjects.handPhysics.y.mass
        local forceZ = car.acceleration.z * self.physicsObjects.handPhysics.z.mass

        local randomX = math.perlin(sim.time * 0.0007, 3)
        local randomY = math.perlin(sim.time * 0.0005, 4)
        local randomZ = math.perlin(sim.time * 0.0004, 4)

        local displacementX = self.physicsObjects.handPhysics.x:step(forceX + randomX, dt)
        local displacementY = self.physicsObjects.handPhysics.y:step(forceY + randomY, dt)
        local displacementZ = self.physicsObjects.handPhysics.z:step(forceZ + randomZ, dt)

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
                    blendedForward = currentForward + (node.baseForward - currentForward + (blendIntermediateOffsets[partName].forward * transitionScalar)) * initialBlend
                    blendedUp = currentUp + (node.baseUp - currentUp + (blendIntermediateOffsets[partName].up * transitionScalar)) * initialBlend
                else
                    blendedForward = currentForward + (node.baseForward - currentForward) * initialBlend
                    blendedUp = currentUp + (node.baseUp - currentUp) * initialBlend
                end
            else
                -- Second phase: Blend from intermediate/base position to raised position
                local raisedBlend = helpers.mapRange(progress, transitionPoint, 1, 0, 1)
                if blendIntermediateOffsets[partName] then
                    local intermediateForward = node.baseForward + (blendIntermediateOffsets[partName].forward * transitionScalar)
                    local intermediateUp = node.baseUp + (blendIntermediateOffsets[partName].up * transitionScalar)
                    blendedForward = intermediateForward + ((node.baseForward + partTarget.forward - intermediateForward) * raisedBlend)
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