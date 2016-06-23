local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")

local pid = require("pid")

local MAX_ENERGY = 10000000 -- maximum energy that the reactor can hold
local TARGET_ENERGY = MAX_ENERGY * 0.50
local SAMPLE_TIME = 0.25 -- PID sample time

local reactor = component.br_reactor
-- 1500 / TARGET_ENERGY, 5 / TARGET_ENERGY, 0
local reactorPID = pid.new(TARGET_ENERGY, 1500 / TARGET_ENERGY, 5 / TARGET_ENERGY, 20000 / TARGET_ENERGY, "reverse")
reactorPID:setSampleTime(SAMPLE_TIME)
reactorPID:setOutputLimits(0, 100)

local function getControlRodPercent()
	return reactor.getControlRodLevel(0)
end

local function getEnergyAmount()
	return reactor.getEnergyStored()
end


local function round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

local function component_unavailable(_, component_name)
	if component_name == "br_reactor" then
		reactor = nil

		reactorPID:setManual()
	end
end

local function component_available(_, component_name)
	if component_name == "br_reactor" then
		reactor = component.br_reactor

		reactorPID:setAutomatic(getEnergyAmount(), getControlRodPercent())
	end
end

local function doSample() -- reactor management timer
	term.clear()

	if not reactor then
		print("PID: no reactor connected")
		-- no reactor connected
		return
	end

	local energyAmount = getEnergyAmount()
	local deltaEnergy = energyAmount - reactorPID.lastInput
	local controlRodTarget = round(reactorPID:compute(energyAmount))
	local controlRodCurrent = getControlRodPercent()
	if controlRodCurrent ~= controlRodTarget then
		reactor.setAllControlRodLevels(controlRodTarget)
	end

	print("Reactor connected")
	print(string.format("Energy levels at %d%%", energyAmount / MAX_ENERGY * 100))
	print(string.format("Control rods set to %d%%", controlRodCurrent))

	local kTerm = reactorPID._kp * (reactorPID.target - energyAmount)
	local dTerm = reactorPID._kd * deltaEnergy

	print("p: " .. round(reactorPID.kp, 5) .. " (" .. round(kTerm, 2) .. ")")
	print("i: " .. round(reactorPID.ki, 5) .. " (" .. round(reactorPID.iTerm, 2) .. ")")
	print("d: " .. round(reactorPID.kd, 5) .. " (" .. round(dTerm, 2) .. ")")
	print("delta energy: " .. deltaEnergy)
	print("pid out: " .. round(reactorPID.output, 3))
	print("cur: " .. round(energyAmount) .. ", " .. reactorPID:getTarget())
	print("direction: " .. reactorPID:getDirection())
	print("error: " .. round(reactorPID.iTerm, 2))
end

do
	-- initialize the PID if the reactor is connected
	if reactor then
		reactorPID:setAutomatic(getEnergyAmount(), getControlRodPercent())
	end
end

local nextSample = computer.uptime()

while true do
	local curUptime = computer.uptime()

	do
		local retVal = {event.pull(nextSample - curUptime)}
		local eventName = table.remove(retVal, 1)
		if eventName == "component_unavailable" then
			component_unavailable(table.unpack(retVal))
		elseif eventName == "component_available" then
			component_available(table.unpack(retVal))
		end
	end

	if curUptime >= nextSample then
		doSample()
		nextSample = curUptime + SAMPLE_TIME
	end
end
