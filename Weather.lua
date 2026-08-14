-- vedar.lua
local Vedar = {}

local WIND_DIRECTIONS = {"North", "North East", "East", "South East", "South", "South West", "West", "North West"}
local currentOceanTemp = nil
local targetOceanTemp = nil

function Vedar.resetTemp()
  currentOceanTemp = nil
  targetOceanTemp = nil
end

function Vedar.getClimateForLocationObj(region, selectedMapIndex, isHurricaneActive)
    if isHurricaneActive then return 28 end
    if region == "Arctic Ocean" then return math.random(-18, 2)
    elseif region == "Southern Ocean" then return math.random(-25, -2)
    elseif region == "Indian Ocean" then return math.random(26, 36)
    elseif region == "Atlantic Ocean" or region == "North Atlantic Ocean" then return math.random(15, 28)
    elseif region == "Pacific Ocean" or region == "Deep Pacific Ocean" then return math.random(18, 30)
    elseif selectedMapIndex == 5 then return math.random(20, 32) 
    else return 22 end
end

function Vedar.getCurrentOceanWeather(playerDistance, weatherOffset, activeHurricanes, activeThunderstorms, locObj, selectedMapIndex, isNight)
  local windDirIndex = (math.floor((playerDistance + weatherOffset) / 4000) % 8) + 1
  local currentWindDirection = WIND_DIRECTIONS[windDirIndex]

  -- Dynamic random humidity between 0% and 100%
  local humidCycle = math.sin((playerDistance + weatherOffset) / 350)
  local currentHumidity = math.floor(((humidCycle + 1) / 2) * 100) + math.random(-3, 3)
  if currentHumidity > 100 then currentHumidity = 100 end
  if currentHumidity < 0 then currentHumidity = 0 end

  local hurricaneActiveHere = false
  for _, hur in ipairs(activeHurricanes) do
      if playerDistance >= hur.startDist and playerDistance <= hur.endDist then 
          hurricaneActiveHere = true 
          break 
      end
  end

  -- HURRICANE ANNOUNCEMENT
  if hurricaneActiveHere then
      local announcement = "Temperature, Severe Hurricane Storm with 100 percent precipitation, and the humidity is 100 percent."
      return 28, 95, 100, announcement, currentWindDirection
  end

  local baseTemp = Vedar.getClimateForLocationObj(locObj.region, selectedMapIndex, false)
  local weatherFront = math.sin((playerDistance + weatherOffset) / 2000) 
  
  -- Din aur raat ke hisaab se temperature logic
  local timeModifier = 0
  if isNight then
      timeModifier = -4 -- Raat mein temperature 4 degree tak girega
  else
      timeModifier = 2  -- Din mein temperature thoda badhega
  end
  
  targetOceanTemp = math.floor(baseTemp + (weatherFront * 4) + timeModifier)
  
  if currentOceanTemp == nil then currentOceanTemp = targetOceanTemp end

  if currentOceanTemp < targetOceanTemp then
      currentOceanTemp = currentOceanTemp + 0.1
      if currentOceanTemp > targetOceanTemp then currentOceanTemp = targetOceanTemp end
  elseif currentOceanTemp > targetOceanTemp then
      currentOceanTemp = currentOceanTemp - 0.1
      if currentOceanTemp < targetOceanTemp then currentOceanTemp = targetOceanTemp end
  end

  local tempVal = math.floor(currentOceanTemp)
  local isFreezing = currentOceanTemp <= 0

  local activeStorm = nil
  for _, storm in ipairs(activeThunderstorms) do
    if playerDistance >= storm.startDist and playerDistance <= storm.endDist then activeStorm = storm break end
  end

  -- STORM ANNOUNCEMENT
  if activeStorm then
     local stormCondition = ""
     if isFreezing then 
         stormCondition = (activeStorm.type == "heavy") and "Heavy Snowstorm" or "Snowstorm"
     else 
         stormCondition = (activeStorm.type == "heavy") and "Heavy Rain and Heavy Thunderstorm" or "Rain and Thunderstorm" 
     end
     local stormWind = math.random(35, 60)
     local stormPrecip = (activeStorm.type == "heavy") and math.random(85, 100) or math.random(65, 80)
     
     local stormAnnouncement = "Temperature, " .. stormCondition .. " with " .. stormPrecip .. " percent precipitation, and the humidity is " .. currentHumidity .. " percent."
     return tempVal, stormWind, currentHumidity, stormAnnouncement, currentWindDirection
  end

  local cloudCycle = (math.sin((playerDistance + weatherOffset) / 1200) + 1) / 2 
  local windCycle = (math.cos((playerDistance + weatherOffset) / 900) + 1) / 2 
  local precipCycle = math.sin((playerDistance + weatherOffset) / 2500) 

  local conditionStr = "Sunny"
  if cloudCycle > 0.8 then conditionStr = "Cloudy"
  elseif cloudCycle > 0.5 then conditionStr = "Mostly Cloudy"
  elseif cloudCycle > 0.25 then conditionStr = "Partly Cloudy"
  else conditionStr = "Sunny" end

  if isNight then
      if conditionStr == "Sunny" then conditionStr = "Clear"
      elseif conditionStr == "Partly Cloudy" or conditionStr == "Mostly Cloudy" then
          conditionStr = "Clear with Periodic Clouds"
      end
  end

  local currentWindSpeed = math.floor(windCycle * 30) + math.random(2, 6)
  if currentWindSpeed >= 20 then 
      if conditionStr == "Sunny" or conditionStr == "Clear" then 
          conditionStr = conditionStr .. " and Windy"
      else 
          conditionStr = "Windy and " .. conditionStr:lower() 
      end
  end

  local precipitation = 0
  local precipString = ""
  if precipCycle > 0.75 then
      if isFreezing then 
         conditionStr = "Light Snow" 
      else 
         conditionStr = "Light Rain" 
      end
      precipitation = math.random(10, 25)
      precipString = " with " .. precipitation .. " percent precipitation"
  end

  -- FINAL NORMAL WEATHER ANNOUNCEMENT
  local fullAnnouncement = "Temperature, conditions are " .. conditionStr .. precipString .. ", and the humidity is " .. currentHumidity .. " percent."

  return tempVal, currentWindSpeed, currentHumidity, fullAnnouncement, currentWindDirection
end

return Vedar