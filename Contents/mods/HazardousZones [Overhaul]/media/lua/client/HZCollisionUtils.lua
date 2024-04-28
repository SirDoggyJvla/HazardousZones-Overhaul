local printDebug = false

local HZ = HazardousZones.Client
local HZUtils = HazardousZones.Shared.Utils
local HZData = HazardousZones.Data

local function onCollision(player, data)
    if isDebugEnabled() and printDebug then
        print(string.format(player:getUsername().." is colliding with a %s zone", data.zone.hazard.type))
    end

    if not player:isGodMod() then
        HZ:increasePlayerExposure(data.zone, data.gradualModifier)
    end
end

-- from SirDoggyJvla: hooked up to the function
local function _detectCollision(zones)
    local player = getPlayer(); if not player then return end
    local playerX = player:getX()
    local playerY = player:getY()

    local distanceFromEpicentre
    local isPlayerCollide = false

    local inZone = false
    if HZUtils:getTableLength(zones) then
        for _,zone in pairs(zones) do
            local zRadius = zone.radius
            local hazardType = zone.hazard.type

            distanceFromEpicentre = IsoUtils.DistanceTo(playerX, playerY, zone.epicentre.x, zone.epicentre.y)

            isPlayerCollide = distanceFromEpicentre < zRadius

            if isPlayerCollide then        
                local gradualModifier = distanceFromEpicentre / zRadius
                local gain = (1 - gradualModifier) * 100

                if not zone.gradualExposure then
                    gain = zone.hazard.exposurePerInGameMinute * 6
                end

                local collision = {
                    zone = zone,
                    gain = gain,
                    gradualModifier = gradualModifier,
                    distanceFromEpicentre = distanceFromEpicentre
                }
                onCollision(player, collision)
                HZ:increaseGain(hazardType, gain);

                inZone = true
            end
        end
    end

    if inZone then
        return true
    end
    return false
end

function HZ:detectCollision()
    local inZone = _detectCollision(HZData.Zones)

    if SandboxVars.HZ.RandomZones then
        inZone = _detectCollision(HZData.RndZones) or inZone
    else
        print("[HZ_DETECT_COLLISION] Collision detection is disabled for random zones because it's disabled in the Sandbox Settings")
        return
    end

    if not inZone then
        local playerModData = getPlayer():getModData()
        if not playerModData["Susceptible_Overhaul"] then
            playerModData["Susceptible_Overhaul"] = {}
        end
        if not playerModData["Susceptible_Overhaul"].DamageProtection then
            playerModData["Susceptible_Overhaul"].DamageProtection = {}
        end
        if playerModData["Susceptible_Overhaul"].DamageProtection.HZ then
            playerModData["Susceptible_Overhaul"].DamageProtection.HZ = nil
        end

        if SandboxVars.HazardousZones.HazardLevelNaturalLoss then
            local exposures = HZ:getPlayerExposures()
            if exposures then
                local newValue
                for hazardType, exposureValue in pairs(exposures) do
                    print(hazardType)
                    print(exposureValue)
                    if exposureValue > 0 then
                        newValue = exposureValue - SandboxVars.HazardousZones.ExposureLossCoefficient / (60*24)
                        if newValue < 0 then
                            newValue = 0
                        end
                        HZ:setPlayerExposure(hazardType, newValue)
                    end
                end
            end
        end
    end
end
