--- Represents a matrix.
-- @class Matrix
-- @field rows integer Number of rows.
-- @field cols integer Number of columns.
-- @field data number[] 1D array storing matrix elements row by row (data[ (row-1)*cols + col ]).
local Matrix = {}
Matrix.__index = Matrix

--- Creates a new matrix with specified dimensions, initialized to a value.
-- @param rows integer Number of rows.
-- @param cols integer Number of columns.
-- @param initialValue number? Value to initialize all elements with (default: 0).
-- @return Matrix The newly created matrix.
function Matrix.create(rows, cols, initialValue)
    initialValue = initialValue or 0
    local self = setmetatable({
        rows = rows,
        cols = cols,
        data = {}
    }, Matrix)
    local size = rows * cols
    for i = 1, size do
        self.data[i] = initialValue
    end
    return self
end

--- Gets the value of an element at a specific row and column.
-- Uses 1-based indexing.
-- @param row integer Row index (1-based).
-- @param col integer Column index (1-based).
-- @return number The value at the specified position.
function Matrix:get(row, col)
    if row < 1 or row > self.rows or col < 1 or col > self.cols then
        error(string.format("Matrix index out of bounds: trying to get (%d, %d) from %dx%d matrix", row, col, self.rows, self.cols))
    end
    return self.data[(row - 1) * self.cols + col]
end

--- Sets the value of an element at a specific row and column.
-- Uses 1-based indexing.
-- @param row integer Row index (1-based).
-- @param col integer Column index (1-based).
-- @param value number The value to set.
function Matrix:set(row, col, value)
    if row < 1 or row > self.rows or col < 1 or col > self.cols then
        error(string.format("Matrix index out of bounds: trying to set (%d, %d) in %dx%d matrix", row, col, self.rows, self.cols))
    end
    self.data[(row - 1) * self.cols + col] = value
end

--- Creates a new identity matrix of a given size.
-- @param size integer The number of rows and columns for the square identity matrix.
-- @return Matrix The newly created identity matrix.
function Matrix.identity(size)
    local mat = Matrix.create(size, size, 0)
    for i = 1, size do
        mat:set(i, i, 1)
    end
    return mat
end

--- Creates a new matrix that is the transpose of the input matrix.
-- @return Matrix The transposed matrix.
function Matrix:transpose()
    local result = Matrix.create(self.cols, self.rows)
    for r = 1, self.rows do
        for c = 1, self.cols do
            result:set(c, r, self:get(r, c))
        end
    end
    return result
end

--- Multiplies two matrices (A * B).
-- @param B Matrix The matrix to multiply by (the right-hand side).
-- @return Matrix The resulting matrix product.
function Matrix:multiply(B)
    if self.cols ~= B.rows then
        error(string.format("Matrix dimensions mismatch for multiplication: %dx%d * %dx%d", self.rows, self.cols, B.rows, B.cols))
    end

    local result = Matrix.create(self.rows, B.cols)
    for r = 1, self.rows do
        for c = 1, B.cols do
            local sum = 0
            for k = 1, self.cols do -- Or B.rows, they are the same
                sum = sum + self:get(r, k) * B:get(k, c)
            end
            result:set(r, c, sum)
        end
    end
    return result
end

--- Multiplies this matrix by a vector.
-- Treats the vector as a column vector (Nx1).
-- The input vector can be a vec3 or a table {x, y, z, ...}.
-- The output will be a simple Lua table representing the resulting column vector.
-- @param vec vec3|table The vector to multiply by. It must have self.cols elements.
-- @return table The resulting vector as a Lua table.
function Matrix:multiplyVector(vec)
    local vecSize
    local isVec3Type = vec3.isvec3 and vec3.isvec3(vec) -- Check if it's the specific vec3 type

    if isVec3Type then
        vecSize = 3 -- Known size for vec3
    elseif type(vec) == "table" and #vec > 0 then
         vecSize = #vec -- Array-like table
    elseif type(vec) == "table" then -- Check for {x=..., y=..., z=...} style
        vecSize=0
        if vec.x then vecSize=vecSize+1 end
        if vec.y then vecSize=vecSize+1 end
        if vec.z then vecSize=vecSize+1 end
        if vec.w then vecSize=vecSize+1 end -- Handle potential vec4-like tables
        if vecSize == 0 then vecSize = table.maxn(vec) end -- Less reliable fallback
    else
        error("Unsupported vector type for matrix multiplication")
    end

    if self.cols ~= vecSize then
        error(string.format("Matrix/vector dimensions mismatch for multiplication: %dx%d * %dx1", self.rows, self.cols, vecSize))
    end

    local result = {}
    for r = 1, self.rows do
        local sum = 0
        for c = 1, self.cols do
            local vecVal
            -- Access based on type
            if isVec3Type then
                if c == 1 then vecVal = vec.x
                elseif c == 2 then vecVal = vec.y
                elseif c == 3 then vecVal = vec.z
                else error(string.format("Trying to access component %d of a vec3", c)) end -- Should not happen if vecSize is correct
            elseif type(vec) == "table" then
                 -- Try component names first for {x,y,z} tables
                if c == 1 and vec.x then vecVal = vec.x
                elseif c == 2 and vec.y then vecVal = vec.y
                elseif c == 3 and vec.z then vecVal = vec.z
                elseif c == 4 and vec.w then vecVal = vec.w
                 -- Fallback to numerical index for array-like tables
                elseif vec[c] then vecVal = vec[c]
                else error(string.format("Cannot access element %d of input table vector", c)) end
            else
                 error("Internal error: Vector type check failed in loop.") -- Should not be reached
            end
            sum = sum + self:get(r, c) * vecVal
        end
        result[r] = sum
    end
    return result
end


--- Adds two matrices (A + B).
-- @param B Matrix The matrix to add.
-- @return Matrix The resulting matrix sum.
function Matrix:add(B)
    if self.rows ~= B.rows or self.cols ~= B.cols then
        error(string.format("Matrix dimensions mismatch for addition: %dx%d + %dx%d", self.rows, self.cols, B.rows, B.cols))
    end

    local result = Matrix.create(self.rows, self.cols)
    for i = 1, #self.data do
        result.data[i] = self.data[i] + B.data[i]
    end
    return result
end

--- Scales a matrix by a scalar value.
-- @param scalar number The scalar multiplier.
-- @return Matrix The resulting scaled matrix.
function Matrix:scale(scalar)
    local result = Matrix.create(self.rows, self.cols)
    for i = 1, #self.data do
        result.data[i] = self.data[i] * scalar
    end
    return result
end

--- Calculates the determinant of a 3x3 matrix.
-- @return number The determinant.
function Matrix:determinant3x3()
    if self.rows ~= 3 or self.cols ~= 3 then
        error("Matrix must be 3x3 to calculate determinant3x3")
    end
    local d = self.data
    -- Indices based on row-major order: (row-1)*cols + col
    -- 1: (1-1)*3+1, 2: (1-1)*3+2, 3: (1-1)*3+3
    -- 4: (2-1)*3+1, 5: (2-1)*3+2, 6: (2-1)*3+3
    -- 7: (3-1)*3+1, 8: (3-1)*3+2, 9: (3-1)*3+3
    return d[1] * (d[5] * d[9] - d[6] * d[8]) -
           d[2] * (d[4] * d[9] - d[6] * d[7]) +
           d[3] * (d[4] * d[8] - d[5] * d[7])
end

--- Calculates the inverse of a 3x3 matrix.
-- Uses the determinant and adjugate method.
-- Returns nil if the matrix is singular (determinant is close to zero).
-- @param epsilon number? Tolerance for checking if determinant is zero (default: 1e-10).
-- @return Matrix? The inverted matrix, or nil if singular.
function Matrix:invert3x3(epsilon)
    epsilon = epsilon or 1e-10
    if self.rows ~= 3 or self.cols ~= 3 then
        error("Matrix must be 3x3 to calculate inverse3x3")
    end

    local det = self:determinant3x3()
    if math.abs(det) < epsilon then
        return nil -- Matrix is singular, cannot invert
    end

    local invDet = 1.0 / det
    local result = Matrix.create(3, 3)
    local d = self.data

    result.data[1] = (d[5] * d[9] - d[6] * d[8]) * invDet
    result.data[2] = (d[3] * d[8] - d[2] * d[9]) * invDet
    result.data[3] = (d[2] * d[6] - d[3] * d[5]) * invDet
    result.data[4] = (d[6] * d[7] - d[4] * d[9]) * invDet
    result.data[5] = (d[1] * d[9] - d[3] * d[7]) * invDet
    result.data[6] = (d[3] * d[4] - d[1] * d[6]) * invDet
    result.data[7] = (d[4] * d[8] - d[5] * d[7]) * invDet
    result.data[8] = (d[2] * d[7] - d[1] * d[8]) * invDet
    result.data[9] = (d[1] * d[5] - d[2] * d[4]) * invDet

    return result
end

--- Creates a string representation of the matrix for printing.
-- @return string
function Matrix:__tostring()
    local s = string.format("Matrix (%dx%d):\n", self.rows, self.cols)
    for r = 1, self.rows do
        local rowStr = ""
        for c = 1, self.cols do
            rowStr = rowStr .. string.format("%10.4f ", self:get(r, c))
        end
        s = s .. "[" .. rowStr .. "]\n"
    end
    return s
end

--- Calculates the signed angle (in radians) between two vectors projected onto a plane defined by a normal axis.
-- Positive angle follows the right-hand rule around the axis. Uses atan2 for better stability near +/- PI.
-- @param v1 vec3 First vector.
-- @param v2 vec3 Second vector.
-- @param axis vec3 The normal vector of the plane (axis of rotation).
-- @param epsilon number? Small tolerance for float comparisons (default: 1e-6).
-- @return number Signed angle in radians [-PI, PI], or 0 if vectors are degenerate or parallel to the axis.
local function getSignedAngle(v1, v2, axis, epsilon)
    epsilon = epsilon or 1e-6

    -- Project vectors onto the plane perpendicular to the axis
    -- Avoid modifying input vectors if they are used elsewhere after this call
    local proj1 = v1 - axis * v1:dot(axis)
    local proj2 = v2 - axis * v2:dot(axis)

    local len1Sq = proj1:lengthSquared()
    local len2Sq = proj2:lengthSquared()

    if len1Sq < epsilon*epsilon or len2Sq < epsilon*epsilon then
        return 0 -- One or both vectors are parallel to the axis or zero length
    end

    proj1:normalize()
    proj2:normalize()

    -- Calculate components for atan2
    -- Dot product represents the cosine relationship (X component for atan2)
    local dotProd = proj1:dot(proj2)
    -- The component of the cross product along the axis represents the sine relationship (Y component for atan2)
    local crossDotAxis = math.cross(proj1, proj2):dot(axis)

    -- Use atan2 for robustness, directly returns signed angle in [-PI, PI]
    local angle = math.atan2(crossDotAxis, dotProd)

    return angle
end

--- Attempts to extract Euler angles (ZYX order: Yaw, Pitch, Roll) from a 3x3 or 4x4 rotation matrix.
-- Note: Prone to gimbal lock when pitch is near +/- 90 degrees.
-- @param mat mat4x4 The rotation matrix (assumes orthonormal upper 3x3).
-- @param epsilon number? Tolerance for singularity check (default: 1e-6).
-- @return number Yaw (Z rotation) in radians.
-- @return number Pitch (Y rotation) in radians.
-- @return number Roll (X rotation) in radians.
local function matrixToEulerZYX(mat, epsilon)
    epsilon = epsilon or 1e-6
    local sy = -mat.row3.x -- sin(pitch)

    local x, y, z
    if math.abs(sy) < 1.0 - epsilon then -- Not at gimbal lock
        -- Unique solution
        y = math.asin(sy) -- Pitch (Y)
        local cy = math.cos(y)
        x = math.atan2(mat.row3.y / cy, mat.row3.z / cy) -- Roll (X)
        z = math.atan2(mat.row2.x / cy, mat.row1.x / cy) -- Yaw (Z)
    else
        -- Gimbal lock: Pitch is +/- 90 degrees
        y = math.pi / 2.0 * math.sign(sy) -- Pitch (Y) is +/- pi/2
        -- Set Roll (X) to 0, solve for Yaw (Z) based on convention
        x = 0.0 -- Roll (X)
        z = math.atan2(-mat.row1.y, mat.row2.y) -- Yaw (Z)
        -- Note: At gimbal lock, Yaw and Roll are coupled; only Yaw + Roll or Yaw - Roll is determined.
        -- Setting Roll to 0 is a common convention.
    end
    return z, y, x
end

--- Solves Inverse Kinematics for a 2-joint arm (Ball + Hinge) using Jacobian DLS.
-- @param params table A table containing solver parameters:
--   - targetPosWorld (vec3): REQUIRED. Target position in world space.
--   - baseRef (ac.SceneReference): REQUIRED. The fixed base node.
--   - shoulderRef (ac.SceneReference): REQUIRED. The first rotating joint (ball joint).
--   - elbowRef (ac.SceneReference): REQUIRED. The second rotating joint (hinge).
--   - tipRef (ac.SceneReference): REQUIRED. The end effector node.
--   - iterations (integer?): Optional. Max iterations (default: 30).
--   - tolerance (number?): Optional. Position tolerance for convergence (default: 0.001).
--   - damping (number?): Optional. DLS damping factor (lambda^2) (default: 0.03).
--   - shoulderConstraints (table?): Optional. Constraints for the shoulder ball joint.
--      - minX, maxX, minY, maxY, minZ, maxZ (number?): Euler angle limits (radians) relative to parent. Order ZYX usually. Defaults allow full rotation.
--   - elbowConstraints (table?): Optional. Constraints for the elbow hinge joint.
--      - min, max (number?): Hinge angle limits (radians). Default allows full rotation.
--      - axis (vec3?): Local hinge axis relative to shoulderRef (default: vec3(1,0,0)).
--   - debug (boolean?): Optional. Enable printing debug info (default: false).
local function solveJacobianDLS(params)
    -- 1. Parameter Validation and Defaults
    if not params or not params.targetPosWorld or not params.baseRef or not params.shoulderRef or not params.elbowRef or not params.tipRef then
        print("IK Jacobian Error: Missing required parameters.")
        return false, "Missing parameters"
    end

    local targetPosWorld = params.targetPosWorld
    local baseRef = params.baseRef
    local shoulderRef = params.shoulderRef
    local elbowRef = params.elbowRef
    local tipRef = params.tipRef
    local maxIterations = params.iterations or 50
    local tolerance = params.tolerance or 0.001
    local toleranceSq = tolerance * tolerance
    -- Adaptive damping parameters -- Restore adaptive damping
    local minDampingLambdaSq = 0.03 -- INCREASED minimum damping slightly
    local maxDampingLambdaSq = 0.2
    local errorScaleForDamping = 0.02 -- DECREASED further from 0.2
    -- local fixedDampingLambdaSq = 0.05 -- Commented out again
    local debug = params.debug or false

    -- Simplified constraint setup (using Euler limits for ball joint for now)
    local shoulderLimits = params.shoulderConstraints or {}
    local elbowLimits = params.elbowConstraints or {}
    local elbowAxisLocal = elbowLimits.axis or vec3(1, 0, 0) -- Local axis relative to shoulderRef
    -- TODO: Refine constraint representation and application if needed

    local logBuffer = {}
    -- Minimal logging setup - Include current damping again
    local logIter = function(iter, err, damp, elbAngle, dThetaRaw, dThetaApplied, scaleInfo) -- Added damp
        if debug then
            local scaleStr = scaleInfo and string.format(", Scale=%.3f", scaleInfo) or ""
            -- Updated format string to include damping (D=%.4f)
            table.insert(logBuffer, string.format("Iter %d: Err=%.5f, D=%.4f, Elb=%.1f, dRaw={%.3f, %.3f, %.3f, %.3f}, dApp={%.3f, %.3f, %.3f, %.3f}%s",
                iter, err, damp, math.deg(elbAngle), -- Use the damping value passed in
                dThetaRaw[1] or 0, dThetaRaw[2] or 0, dThetaRaw[3] or 0, dThetaRaw[4] or 0,
                dThetaApplied[1] or 0, dThetaApplied[2] or 0, dThetaApplied[3] or 0, dThetaApplied[4] or 0,
                scaleStr
            ))
        end
    end
    -- Remove or comment out detailed loggers if not needed
    -- local logVec3 = function(key, v) if debug then table.insert(logBuffer, string.format("[%s]: %s", key, v and string.format("%.4f, %.4f, %.4f", v.x, v.y, v.z) or "nil")) end end
    -- local logMatrix = function(key, m) if debug then table.insert(logBuffer, string.format("[%s (%dx%d)]:\n%s", key, m.rows, m.cols, tostring(m))) end end

    local epsilon = 1e-6

    -- 2. Initialization
    -- Update log message for adaptive damping
    if debug then table.insert(logBuffer, string.format("--- IK Start: Iter=%d, Tol=%.4f, DampRange=[%.4f-%.4f], DampErrScale=%.4f ---", maxIterations, tolerance, minDampingLambdaSq, maxDampingLambdaSq, errorScaleForDamping)) end

    -- Define Degrees of Freedom (DoF) - 3 for shoulder (X, Y, Z rotation), 1 for elbow (hinge)
    local numDOF = 4
    -- Define Task Space Dimensions (position only)
    local numTaskDims = 3

    -- Allocate Matrices/Vectors (Using the Matrix class from earlier)
    local J = Matrix.create(numTaskDims, numDOF) -- Jacobian
    local e = vec3()                             -- Error vector (world space)
    local deltaTheta = {}                        -- Resulting angle changes (will be a table {d1, d2, d3, d4})
    local tempVec = vec3()                      -- Reusable temporary vector
    local tempVec2 = vec3()                     -- Another reusable vector

    -- Store initial local transforms if needed for constraints or reset later (Optional)
    -- local initialShoulderLocalT = shoulderRef:getTransformationRaw():clone()
    -- local initialElbowLocalT = elbowRef:getTransformationRaw():clone()

    -- Add storage for current angles if needed across iterations (or recompute each time)
    local currentShoulderAngles = {x=0, y=0, z=0}
    local currentElbowAngle = 0

    -- Allocate inverse parent transform
    local invBaseWorldT = mat4x4()

    -- 3. Iteration Loop
    local iter = 0
    local success = false
    local finalError = -1

    -- Temporary storage for world positions/axes needed in the loop
    local shoulderPosWorld = vec3()
    local elbowPosWorld = vec3()
    local tipPosWorld = vec3()
    local shoulderAxisXWorld = vec3()
    local shoulderAxisYWorld = vec3()
    local shoulderAxisZWorld = vec3()
    local elbowAxisWorld = vec3()


    while iter < maxIterations do
        iter = iter + 1
        -- Simplified log start
        -- log("--- Iteration", iter .. " ---")

        -- 4. Forward Kinematics & Error Calculation
        local baseWorldT = baseRef:getWorldTransformationRaw() -- Get base transform *once* per iteration
        if not baseWorldT then logIter(iter, -1, 0, {0,0,0,0}, {0,0,0,0}, nil); success = false; break end
        local shoulderWorldT = shoulderRef:getWorldTransformationRaw()
        local elbowWorldT = elbowRef:getWorldTransformationRaw()
        local tipWorldT = tipRef:getWorldTransformationRaw()

        if not shoulderWorldT or not elbowWorldT or not tipWorldT then
             if debug then table.insert(logBuffer, "IK Error: Missing transforms") end
             finalError = -1; success = false; break
        end

        -- Get current world positions
        shoulderPosWorld:set(shoulderWorldT.position)
        elbowPosWorld:set(elbowWorldT.position)
        tipPosWorld:set(tipWorldT.position)
        -- logVec3("Current Tip Pos", tipPosWorld) -- Removed

        -- Calculate error vector and distance
        e:set(targetPosWorld):sub(tipPosWorld)
        local errorDistSq = e:lengthSquared()
        finalError = math.sqrt(errorDistSq)
        -- log("Error Distance", finalError) -- Will be logged in logIter

        -- Check for convergence
        if errorDistSq < toleranceSq then
            if debug then table.insert(logBuffer, "IK Success: Converged.") end
            success = true
            break
        end

        -- 5. Calculate Jacobian (J)
        -- Column = Axis_World x (TipPos_World - JointPos_World)
        -- Uses the joint's *local* axes transformed to world space.

        -- Shoulder Rotations (using Shoulder's *OWN* local axes transformed to world)
        shoulderWorldT:transformVectorTo(shoulderAxisXWorld, vec3(1,0,0)):normalize() -- Shoulder's Local X in World
        tempVec:set(tipPosWorld):sub(shoulderPosWorld)
        tempVec2 = math.cross(shoulderAxisXWorld, tempVec)
        J:set(1, 1, tempVec2.x); J:set(2, 1, tempVec2.y); J:set(3, 1, tempVec2.z) -- Corresponds to deltaTheta[1]

        shoulderWorldT:transformVectorTo(shoulderAxisYWorld, vec3(0,1,0)):normalize() -- Shoulder's Local Y in World (NOTE: Assumed Bone Axis by user)
        tempVec2 = math.cross(shoulderAxisYWorld, tempVec)
        J:set(1, 2, tempVec2.x); J:set(2, 2, tempVec2.y); J:set(3, 2, tempVec2.z) -- Corresponds to deltaTheta[2] (Twist/Roll)

        shoulderWorldT:transformVectorTo(shoulderAxisZWorld, vec3(0,0,1)):normalize() -- Shoulder's Local Z in World
        tempVec2 = math.cross(shoulderAxisZWorld, tempVec)
        J:set(1, 3, tempVec2.x); J:set(2, 3, tempVec2.y); J:set(3, 3, tempVec2.z) -- Corresponds to deltaTheta[3]

        -- Elbow Hinge Rotation (Local Hinge Axis of Shoulder transformed to world)
        shoulderWorldT:transformVectorTo(elbowAxisWorld, elbowAxisLocal):normalize() -- Elbow hinge axis in World
        tempVec:set(tipPosWorld):sub(elbowPosWorld) -- Vector from elbow to tip
        tempVec2 = math.cross(elbowAxisWorld, tempVec)
        J:set(1, 4, tempVec2.x); J:set(2, 4, tempVec2.y); J:set(3, 4, tempVec2.z) -- Corresponds to deltaTheta[4]

        -- logMatrix("Jacobian J", J) -- Removed

        -- 6. Calculate Delta Theta (Δθ) using DLS with Adaptive Damping
        -- Restore adaptive damping calculation
        local dampingRatio = math.max(0, 1.0 - (finalError / errorScaleForDamping))
        local currentDampingLambdaSq = minDampingLambdaSq + (maxDampingLambdaSq - minDampingLambdaSq) * dampingRatio
        -- local currentDampingLambdaSq = fixedDampingLambdaSq -- Commented out

        local JT = J:transpose()
        local JJT = J:multiply(JT)
        local dampingMat = Matrix.identity(numTaskDims):scale(currentDampingLambdaSq)
        local JJT_Damped = JJT:add(dampingMat)
        local InvTerm = JJT_Damped:invert3x3(epsilon)

        if not InvTerm then
            if debug then table.insert(logBuffer, "IK Warn: Matrix inversion failed.") end
            success = false; finalError = -1
            break
        end

        local FullTerm = JT:multiply(InvTerm)
        deltaTheta = FullTerm:multiplyVector(e)

        -- 7. Apply Constraints & Scale step size
        local deltaThetaApplied = {0, 0, 0, 0}
        deltaThetaApplied[1] = deltaTheta[1] or 0
        deltaThetaApplied[2] = deltaTheta[2] or 0
        deltaThetaApplied[3] = deltaTheta[3] or 0
        currentElbowAngle = getSignedAngle(elbowPosWorld - shoulderPosWorld, tipPosWorld - elbowPosWorld, elbowAxisWorld, epsilon)
        deltaThetaApplied[4] = deltaTheta[4] or 0

        -- Apply scaling -- REMOVED the error threshold scaling
        local stepScale = 1.0
        local scaleInfo = nil -- For logging
        -- local errorThresholdForScaling = tolerance * 5.0 -- Removed threshold
        -- if finalError < errorThresholdForScaling and errorThresholdForScaling > epsilon then -- Removed condition
        --     stepScale = math.max(0.001, finalError / errorThresholdForScaling) -- Simple scaling removed for now
        --     scaleInfo = stepScale
        -- end
        -- No scaling applied here anymore, rely on damping and clamp below
        -- for i = 1, #deltaThetaApplied do
        --    deltaThetaApplied[i] = deltaThetaApplied[i] * stepScale
        -- end

        -- Clamp maximum rotation per step for robustness
        local maxAngleStep = 1.0 -- Max radians (~57 degrees) - INCREASED back from 0.5
        for i = 1, #deltaThetaApplied do
            deltaThetaApplied[i] = math.clamp(deltaThetaApplied[i], -maxAngleStep, maxAngleStep)
        end
        -- Note: If clamping occurs, the scaleInfo logged might not reflect the *final* applied scaling effect.

        -- Log essential iteration info (with damping value)
        logIter(iter, finalError, currentDampingLambdaSq, currentElbowAngle, deltaTheta, deltaThetaApplied, scaleInfo) -- Pass currentDampingLambdaSq

        -- 8. Update Joint Transforms using the SCALED and CLAMPED deltaThetaApplied
        -- Apply shoulder rotations intrinsically (ZYX order relative to the transforming frame)
        local shoulderT = shoulderRef:getTransformationRaw() -- Need the matrix for axis transforms

        if math.abs(deltaThetaApplied[3]) > epsilon then
             local currentLocalZ_InWorld = shoulderT:transformVector(vec3(0,0,1))
             shoulderRef:rotate(currentLocalZ_InWorld, deltaThetaApplied[3])
             shoulderT = shoulderRef:getTransformationRaw() -- Update matrix state after rotation
        end
        if math.abs(deltaThetaApplied[2]) > epsilon then
             local currentLocalY_InWorld = shoulderT:transformVector(vec3(0,1,0))
             shoulderRef:rotate(currentLocalY_InWorld, deltaThetaApplied[2])
             shoulderT = shoulderRef:getTransformationRaw() -- Update matrix state after rotation
        end
        if math.abs(deltaThetaApplied[1]) > epsilon then
            local currentLocalX_InWorld = shoulderT:transformVector(vec3(1,0,0))
            shoulderRef:rotate(currentLocalX_InWorld, deltaThetaApplied[1])
            -- No need to update shoulderT after the last rotation unless used later
        end

        -- Elbow: Apply rotation around the hinge axis calculated earlier (relative to shoulder orientation *at start of iter*)
        if math.abs(deltaThetaApplied[4]) > epsilon then
             elbowRef:rotate(elbowAxisWorld, deltaThetaApplied[4]) -- elbowAxisWorld is still the hinge axis in world space calculated in step 5
        end

        -- Clear motion history
        shoulderRef:clearMotion()
        elbowRef:clearMotion()

    end -- End of iteration loop

    -- 9. Finalization
    if iter == maxIterations and not success then
        if debug then table.insert(logBuffer, "IK Warn: Reached max iterations.") end
    end

    if debug then
        table.insert(logBuffer, string.format("--- IK End: Success=%s, Iter=%d, Err=%.5f ---", tostring(success), iter, finalError))
        print(table.concat(logBuffer, "\n"))
    end

    return success, finalError
end


return solveJacobianDLS
