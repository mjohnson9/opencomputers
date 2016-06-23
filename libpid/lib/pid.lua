-- PID library by NightExcessive
-- Ported from https://github.com/br3ttb/Arduino-PID-Library

-- checkNonNegativeArg checks that an argument is non-negative
local function checkNonNegativeArg(n, value)
	if value >= 0 then
		return
	end

	local msg = string.format("bad argument #%d (non-negative number expected, got %d)", n, value)
	error(msg, 3)
end

local PID = {}
PID.__index = PID

-- this function initializes internal variables used by the library
function PID:__init()
	local DEFUALT_SAMPLE_TIME = 0.1
	self.sampleTime = DEFUALT_SAMPLE_TIME * 1000
	self.output = 0
	self.lastInput = 0
	self.iTerm = 0
	self.inReverse = false
	self:setManual()
end

-- where the magic happens
-- this should be called every sampleTime seconds, as found by PID:getSampleTime()
function PID:compute(input)
	checkArg(1, input, "number")

	if not self.active then
		return self.output
	end

	local curError = self.target - input
	self.iTerm = self.iTerm + (self._ki * curError)
	if self.iTerm > self.outMax then
		self.iTerm = self.outMax
	elseif self.iTerm < self.outMin then
		self.iTerm = self.outMin
	end

	local deltaInput = input - self.lastInput

	local output = (self._kp * curError) + self.iTerm - (self._kd * deltaInput)

	if output > self.outMax then
		output = self.outMax
	elseif output < self.outMin then
		output = self.outMin
	end

	self.output = output

	self.lastInput = input

	return self.output
end

-- set the controller's dynamic tuning parameters
-- adjusting these will not cause output spikes
function PID:setTuningParameters(kp, ki, kd)
	checkArg(1, kp, "number")
	checkNonNegativeArg(1, kp)
	checkArg(2, ki, "number")
	checkNonNegativeArg(2, ki)
	checkArg(3, kd, "number")
	checkNonNegativeArg(3, kd)

	self.kp = kp
	self.ki = ki
	self.kd = kd

	local sampleTimeSec = self.sampleTime / 1000
	self._kp = kp
	self._ki = ki * sampleTimeSec
	self._kd = kd * sampleTimeSec

	if self.inReverse then
		self._kp = -self._kp
		self._ki = -self._ki
		self._kd = -self._kd
	end
end

-- set the controller's target value
-- this must be a number
function PID:setTarget(target)
	checkArg(1, target, "number")

	self.target = target
end

-- returns the controller's current target value
function PID:getTarget()
	return self.target
end

-- set the controller's minimum and maximum outputs
-- these default to [0, 15]
function PID:setOutputLimits(min, max)
	checkArg(1, min, "number")
	checkArg(2, max, "number")

	self.outMin = min
	self.outMax = max

	if self.output > self.outMax then
		self.output = self.outMax
	elseif self.output < self.outMin then
		self.output = self.outMin
	end

	if self.iTerm > self.outMax then
		self.iTerm = self.outMax
	elseif self.iTerm < self.outMin then
		self.iTerm = self.outMin
	end
end

-- returns the current output limits as [min, max]
function PID:getOutputLimits()
	return self.outMin, self.outMax
end

-- sets the PID to manual mode
function PID:setManual()
	self.active = false
end

-- sets the PID to automatic mode
--
-- you must provide the last set input and output to enable the bumpless
-- transfer from manual to automatic
function PID:setAutomatic(input, output)
	checkArg(1, input, "number")
	checkArg(2, output, "number")

	self.lastInput = input

	self.output = output
	if self.output > self.outMax then
		self.output = self.outMax
	elseif self.output < self.outMin then
		self.output = self.outMin
	end

	self.iTerm = output
	if self.iTerm > self.outMax then
		self.iTerm = self.outMax
	elseif self.iTerm < self.outMin then
		self.iTerm = self.outMin
	end

	self.active = true
end

-- returns the current mode; see PID.getMode for more information
function PID:getMode()
	if self.active then
		return "automatic"
	else
		return "manual"
	end
end

-- sets the direction that output should respond
-- the string "direct" should be passed for direct response
-- the string "reverse" should be passed for inverse response
function PID:setDirection(direction)
	checkArg(1, direction, "string")
	if direction ~= "direct" and direction ~= "reverse" then
		error(string.format("bad argument #1 (\"direct\" or \"reverse\" expected, got %s)", direction), 2)
	end

	local inReverse = (direction == "reverse")
	if self.inReverse ~= inReverse then
		self._kp = -self._kp
		self._ki = -self._ki
		self._kd = -self._kd

		self.inReverse = inReverse
	end
end

-- returns the current response direction; see PID.setDirection for more information
function PID:getDirection()
	if self.inReverse then
		return "reverse"
	else
		return "direct"
	end
end

-- sets the sample time in seconds (e.g.: 0.1 is 100ms)
-- defaults to 100ms
function PID:setSampleTime(t)
	checkArg(1, t, "number")

	self.sampleTime = t * 1000

	local timeInSec = self.sampleTime / 1000
	self._ki = self.ki * timeInSec
	self._kd = self.kd * timeInSec

	if self.inReverse then
		self._ki = -self._ki
		self._kd = -self._kd
	end
end

-- gets the current sample time in seconds
function PID:getSampleTime()
	return self.sampleTime / 1000
end

local function newPID(target, kp, ki, kd, direction)
	checkArg(1, target, "number")
	checkArg(2, kp, "number")
	checkNonNegativeArg(2, kp)
	checkArg(3, ki, "number")
	checkNonNegativeArg(3, ki)
	checkArg(4, kd, "number")
	checkNonNegativeArg(4, kd)
	checkArg(5, direction, "string", "nil")
	if direction ~= nil and direction ~= "direct" and direction ~= "reverse" then
		error(string.format("bad argument #5 (\"direct\" or \"reverse\" expected, got %s)", direction), 2)
	end

	local pid = {}
	setmetatable(pid, PID)

	pid:__init()

	pid:setTarget(target)
	pid:setTuningParameters(kp, ki, kd)
	if direction ~= nil then
		pid:setDirection(direction)
	end
	pid:setOutputLimits(0, 15)

	return pid
end

return {
	new = newPID
}
