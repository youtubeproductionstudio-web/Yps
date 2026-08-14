-- boat_game.lua
local boatGameModule = {}

function boatGameModule.show(params)
    local activity = params.activity
    local prefs = params.prefs
    local editor = params.editor
    local mainUI = params.mainUI
    local gamesMenu = params.gamesMenu
    local stopParentBGM = params.stopBGM
    local playParentBGM = params.playBGM
    local bgm2Path = params.bgm2Path

    require "import"
    import "android.widget.*"
    import "android.view.*"
    import "android.content.*"
    import "android.app.*"
    import "android.graphics.Color"
    import "android.graphics.Typeface"
    import "android.os.Handler"
    import "android.os.Looper"
    import "org.json.JSONObject"

    math.randomseed(os.time())
    pcall(function() activity.setTheme(android.R.style.Theme_NoTitleBar_Fullscreen) end)

    -- IMPORT MODULES
    local Sound = require("Boat game Sound")
    local locationDB = require("locations")
    local Vedar = require("Weather")

    if Sound and Sound.initTTS then
        pcall(function() Sound.initTTS(activity) end)
    end

    -- ==========================================
    -- FORWARD DECLARATIONS
    -- ==========================================
    local openMainMenuWindow
    local openVerifyTokenWindow
    local openOceanEntryDialog
    local openGamePlayWindow
    local createEndGameListener
    local cancelFuelGraceTimer
    local hideGameButtons
    local showResultDialog
    local shareGameResult
    local awardWinCoins
    local getCoinRewardForMap

    -- UI Dialog References
    local dlgMenu = nil
    local dlgVerifyToken = nil
    local dlgOceanEntry = nil
    local dlgGame = nil
    local dlgResult = nil

    local hasAwardedWinCoins = false

    -- Win & Lose Messages Pool
    local winMessages = {
      "Sensational Navigation! You conquered the rough waves and crossed the finish line in glory!",
      "Captain Supreme! Your nautical skills left the competitor far behind in the misty waters!",
      "Master of the Ocean! You braved the perilous weather and claimed a magnificent victory!",
      "Unstoppable Mariner! High winds and dangerous swells couldn't keep you from winning!",
      "Rule the Waves! What an extraordinary drive across the sea to secure a grand win!",
      "Legendary Skipper! You outmaneuvered every obstacle and took the crown on the open sea!",
      "Ocean Dominator! Flawless speed and precise control brought you to ultimate victory!",
      "Victory at Sea! You rode the surges like a true champion and conquered the ocean route!"
    }

    local loseMessages = {
      "Capsized Dreams! The fierce waves and tough rival proved too strong this time.",
      "Sunk in Defeat! The ocean path tested your limits, but don't give up skipper!",
      "Outpaced by the Robot! Keep your hands steady on the helm and try again!",
      "Lost at Sea! Dangerous hazards and unpredictable waters ruined your winning run.",
      "Rough Seas Ahead! You fell behind in the treacherous currents today.",
      "Swallowed by the Swell! A tough loss on the open waters, but glory awaits in the next race!",
      "Shipwrecked Result! Your competitor took advantage of the rough weather to reach first.",
      "Overwhelmed by Waves! The tide turned against you this time, better luck next round!"
    }

    -- Boat Unlock State System
    local unlockedBoats = {
      pedal = prefs.getBoolean("boat_pedal", false),
      small = prefs.getBoolean("boat_small", true),
      advance = prefs.getBoolean("boat_advance", false),
      big = prefs.getBoolean("boat_big", false),
      hyper = prefs.getBoolean("boat_hyper", false)
    }

    -- Fuel System
    local ownedFuelCans = prefs.getInt("fuelCans", 0)
    local currentFuel = 100.0
    local currentRobotFuel = 100.0

    local function saveGameData()
      editor.putInt("fuelCans", ownedFuelCans)
      editor.putBoolean("boat_pedal", unlockedBoats.pedal)
      editor.putBoolean("boat_small", unlockedBoats.small)
      editor.putBoolean("boat_advance", unlockedBoats.advance)
      editor.putBoolean("boat_big", unlockedBoats.big)
      editor.putBoolean("boat_hyper", unlockedBoats.hyper)
      editor.apply()
    end

    local fuelWarning10Given = false
    local robotFuelWarning10Given = false
    local fuelEmptyGraceActive = false
    local fuelGraceTimerSeconds = 40
    local fuelGraceRunnable = nil

    local isEngineStarted = false
    local isSwipeActive = false
    local isCountingDown = false
    local isHeadlightOn = false
    local currentCalculatedSpeed = 0.0  
    local currentRobotCalculatedSpeed = 0.0 
    local selectedMapName = ""
    local selectedMapPath = ""
    local selectedMapIndex = 0
    local RACE_LIMIT = 5000 
    local currentRaceRoute = {} 
    local weatherOffset = 0 

    local playerDistance = 0.0
    local robotDistance = 0.0
    local playerDriftDistance = 0   
    local robotDriftDistance = 0   
    local robotTargetDrift = 0      
    local announceTickCounter = 0   
    local announceTurn = 0          
    local etaTickCounter = 0
    local periodicEtaCounter = 0
    local periodicEtaTurn = 0
    local isRobotSunk = false
    local wasPlayerOffTrack = false

    local robotNightStateTimer = 0.0
    local isRobotStoppedAtNight = false

    local gameTimeHours = 14
    local gameTimeMinutes = 0
    local isNight = false
    local currentTimeOfDay = ""

    local xStart, yStart = 0, 0
    local MIN_SWIPE_DISTANCE = 120 
    local isEtaTriggered = false

    local isPedalBoatSelected = false
    local expectedPedalCommand = "up"

    local activeThunderstorms = {}
    local activeHurricanes = {}
    local activeObstacles = {}

    local mainHandler = Handler(Looper.getMainLooper())
    local gameLoopRunnable = nil
    local decelerationRunnable = nil
    local timeLoopRunnable = nil

    local PEDAL_BOAT_SPEED = 5.0
    local SMALL_BOAT_SPEED = 10.0   
    local ADVANCE_BOAT_SPEED = 20.0 
    local BIG_BOAT_SPEED = 30.0     
    local HYPER_BOAT_SPEED = 50.0   

    local playerAudioPath = ""
    local robotAudioPath = ""
    local playerSpeedMultiplier = 0.0
    local robotSpeedMultiplier = 0.0
    local playerBoatName = ""
    local robotBoatName = ""

    local liveEtaTxt = nil
    local statusMessageTxt = nil
    local checkWeatherBtn = nil
    local checkLocationBtn = nil
    local checkTimeBtn = nil
    local boatHornBtn = nil
    local headlightBtn = nil
    local refillFuelBtn = nil
    local startRacingBtn = nil

    local speakStatus = function(text, isImportantCommand)
        if Sound and Sound.speakStatus then
            pcall(function() Sound.speakStatus(text, isImportantCommand, statusMessageTxt) end)
        end
    end

    local function attachBackListener(dlg, dismissCallback)
      dlg.setOnKeyListener(luajava.createProxy("android.content.DialogInterface$OnKeyListener", {
        onKey = function(dialog, keyCode, event)
          if keyCode == 4 and event.getAction() == KeyEvent.ACTION_UP then 
            if dismissCallback then dismissCallback() end
            return true
          end
          return false
        end
      }))
    end

    local function getLocObjForDistance(dist)
        for _, route in ipairs(currentRaceRoute) do
            if dist >= route.startDist and dist <= route.endDist then
                return route
            end
        end
        return {sea = "Open Ocean", nearbyCountry = "Unknown Coast", region = "Ocean"}
    end

    local function formatTimeForSpeech(seconds)
      if seconds == math.huge or seconds > 360000 then return "calculating" end
      local h = math.floor(seconds / 3600)
      local m = math.floor((seconds % 3600) / 60)
      local s = math.floor(seconds % 60)
      local res = ""
      if h > 0 then res = res .. h .. " hour " end
      if m > 0 then res = res .. m .. " minutes and " end
      res = res .. s .. " seconds"
      return res
    end

    local function formatTimeForScreen(seconds)
      if seconds == math.huge or seconds > 360000 then return "Calculating..." end
      local h = math.floor(seconds / 3600)
      local m = math.floor((seconds % 3600) / 60)
      local s = math.floor(seconds % 60)
      if h > 0 then return string.format("%d hr %d min %d sec", h, m, s) end
      if m > 0 then return string.format("%d min %d sec", m, s) end
      return string.format("%d sec", s)
    end

    local function formatDist(meters)
      return math.floor(meters) .. " meters"
    end

    local function getFormattedGameTime()
      local h = math.floor(gameTimeHours)
      local m = math.floor(gameTimeMinutes)
      local ampm = (h >= 12) and "PM" or "AM"
      local displayH = h % 12
      if displayH == 0 then displayH = 12 end
      local mStr = (m < 10) and ("0" .. m) or tostring(m)
      return string.format("%d:%s %s", displayH, mStr, ampm)
    end

    getCoinRewardForMap = function(mapIdx)
        if mapIdx == 4 then return 70       -- Pacific Ocean
        elseif mapIdx == 2 then return 50   -- Indian Ocean
        elseif mapIdx == 3 then return 40   -- Atlantic Ocean
        elseif mapIdx == 5 then return 35   -- Deep Basins
        elseif mapIdx == 1 then return 30   -- Southern Ocean
        elseif mapIdx == 0 then return 25   -- Arctic Ocean
        else return 25 end
    end

    awardWinCoins = function()
        if hasAwardedWinCoins then return 0 end
        hasAwardedWinCoins = true

        local rewardAmount = getCoinRewardForMap(selectedMapIndex)
        local getCoins = params.getSecureCoins or _G.getSecureCoins
        local setCoins = params.setSecureCoins or _G.setSecureCoins
        local currentCoins = getCoins and getCoins() or 0
        local newCoins = currentCoins + rewardAmount

        if setCoins then
            pcall(function() setCoins(newCoins) end)
        end

        local currentUname = prefs.getString("username", "")
        local currentId = prefs.getString("userid", "")
        local currentRole = prefs.getString("role", "user")

        if currentUname ~= "" then
            pcall(function()
                local firebaseUrl = "https://all-games-76b5d-default-rtdb.firebaseio.com/users/"
                local nodeKey = currentUname:lower():gsub(" ", "%%20")
                local userUrl = firebaseUrl .. nodeKey .. ".json"

                Http.get(userUrl, function(code, content)
                    if code == 200 and content and content ~= "null" then
                        local serverData = {
                          memory_keys = 0, memory_key_bought_before = false,
                          public_chat_keys = 0, public_chat_key_bought_before = false,
                          audio_ff_keys = 0, audio_ff_bought_before = false,
                          has_shotgun = false, has_ak47 = false, has_machine_gun = false,
                          has_torch = false, fuel_cans = 0, potion_revival = 0, potion_healing = 0
                        }
                        
                        pcall(function()
                            local cleanContent = content:gsub("^%s*(.-)%s*$", "%1")
                            local jsonObj = JSONObject(cleanContent)
                            local userDataObj = jsonObj
                            local keysIter = jsonObj.keys()
                            if keysIter.hasNext() then
                                local firstKey = tostring(keysIter.next())
                                if firstKey:sub(1,1) == "-" then
                                    userDataObj = jsonObj.optJSONObject(firstKey)
                                end
                            end
                            if userDataObj ~= nil then
                                serverData.memory_keys = tonumber(tostring(userDataObj.opt("memory_keys"))) or 0
                                serverData.memory_key_bought_before = userDataObj.optBoolean("memory_key_bought_before", false)
                                serverData.public_chat_keys = tonumber(tostring(userDataObj.opt("public_chat_keys"))) or 0
                                serverData.public_chat_key_bought_before = userDataObj.optBoolean("public_chat_key_bought_before", false)
                                serverData.audio_ff_keys = tonumber(tostring(userDataObj.opt("audio_ff_keys"))) or 0
                                serverData.audio_ff_bought_before = userDataObj.optBoolean("audio_ff_bought_before", false)
                                serverData.has_shotgun = userDataObj.optBoolean("has_shotgun", false)
                                serverData.has_ak47 = userDataObj.optBoolean("has_ak47", false)
                                serverData.has_machine_gun = userDataObj.optBoolean("has_machine_gun", false)
                                serverData.has_torch = userDataObj.optBoolean("has_torch", false)
                                serverData.fuel_cans = tonumber(tostring(userDataObj.opt("fuel_cans"))) or 0
                                serverData.potion_revival = tonumber(tostring(userDataObj.opt("potion_revival"))) or 0
                                serverData.potion_healing = tonumber(tostring(userDataObj.opt("potion_healing"))) or 0
                            end
                        end)

                        local jsonParts = {}
                        table.insert(jsonParts, '"userid": "' .. currentId .. '"')
                        table.insert(jsonParts, '"username": "' .. currentUname .. '"')
                        table.insert(jsonParts, '"role": "' .. currentRole .. '"')
                        table.insert(jsonParts, '"coins": ' .. newCoins)
                        table.insert(jsonParts, '"memory_keys": ' .. tostring(serverData.memory_keys))
                        table.insert(jsonParts, '"memory_key_bought_before": ' .. tostring(serverData.memory_key_bought_before))
                        table.insert(jsonParts, '"public_chat_keys": ' .. tostring(serverData.public_chat_keys))
                        table.insert(jsonParts, '"public_chat_key_bought_before": ' .. tostring(serverData.public_chat_key_bought_before))
                        table.insert(jsonParts, '"audio_ff_keys": ' .. tostring(serverData.audio_ff_keys))
                        table.insert(jsonParts, '"audio_ff_bought_before": ' .. tostring(serverData.audio_ff_bought_before))
                        table.insert(jsonParts, '"has_shotgun": ' .. tostring(serverData.has_shotgun))
                        table.insert(jsonParts, '"has_ak47": ' .. tostring(serverData.has_ak47))
                        table.insert(jsonParts, '"has_machine_gun": ' .. tostring(serverData.has_machine_gun))
                        table.insert(jsonParts, '"has_torch": ' .. tostring(serverData.has_torch))
                        table.insert(jsonParts, '"fuel_cans": ' .. tostring(serverData.fuel_cans))
                        table.insert(jsonParts, '"potion_revival": ' .. tostring(serverData.potion_revival))
                        table.insert(jsonParts, '"potion_healing": ' .. tostring(serverData.potion_healing))

                        local updateData = "{" .. table.concat(jsonParts, ", ") .. "}"
                        local updateUrl = userUrl .. "?x-http-method-override=PATCH"
                        Http.post(updateUrl, updateData, function(updCode, updContent) end)
                    end
                end)
            end)
        end

        return rewardAmount
    end

    shareGameResult = function(isWin, oceanName, boatName, randomMsg, coinsEarned)
        pcall(function()
            local intent = Intent(Intent.ACTION_SEND)
            intent.setType("text/plain")

            local shareText = ""
            if isWin then
                shareText = string.format(
                    "🏆 BOAT RACING CHAMPIONSHIP VICTORY! 🏆\n\nI conquered %s using the %s!\nResult: VICTORY!\nCoins Earned: +%d Coins\n\n\"%s\"\n\nDeveloped by Irtiza Hasan and Muzzammil Muneer\n\nDownload the APK from the link below:\nhttps://www.upload-apk.com/XpZRhOVV5NDLmmD",
                    oceanName, boatName, coinsEarned, randomMsg
                )
            else
                shareText = string.format(
                    "⚓ BOAT RACING CHAMPIONSHIP MATCH ⚓\n\nI competed in %s using the %s!\nResult: DEFEAT\n\n\"%s\"\n\nDeveloped by Irtiza Hasan and Muzzammil Muneer\n\nDownload the APK from the link below:\nhttps://www.upload-apk.com/XpZRhOVV5NDLmmD",
                    oceanName, boatName, randomMsg
                )
            end

            intent.putExtra(Intent.EXTRA_TEXT, shareText)
            local chooser = Intent.createChooser(intent, "Share Race Results via")
            activity.startActivity(chooser)
        end)
    end

    showResultDialog = function(isWin, detailText)
        if dlgResult then
            pcall(function() dlgResult.dismiss() end)
            dlgResult = nil
        end

        local randomMsg = ""
        local coinsEarned = 0

        if isWin then
            randomMsg = winMessages[math.random(1, #winMessages)]
            coinsEarned = awardWinCoins()
        else
            randomMsg = loseMessages[math.random(1, #loseMessages)]
        end

        local titleStr = isWin and "🏆 VICTORY! 🏆" or "⚠️ RACE OVER - DEFEAT ⚠️"
        local titleColor = isWin and Color.parseColor("#4CAF50") or Color.parseColor("#FF5252")
        local rewardTextStr = isWin and string.format("Reward Earned: +%d Coins", coinsEarned) or "Reward Earned: 0 Coins"
        local rewardTextColor = isWin and Color.parseColor("#FFD700") or Color.GRAY

        local resultLayout = {
          ScrollView, layout_width = "fill", layout_height = "fill", fillViewport = "true", backgroundColor = "#121212",
          { LinearLayout, orientation = "vertical", layout_width = "fill", layout_height = "wrap", gravity = "center", padding = "24dp",
            { TextView, text = titleStr, textSize = "24sp", textColor = titleColor, layout_marginBottom = "12dp", gravity = "center" },
            { TextView, text = randomMsg, textSize = "18sp", textColor = Color.WHITE, layout_marginBottom = "14dp", gravity = "center" },
            { TextView, text = detailText or "", textSize = "15sp", textColor = Color.LTGRAY, layout_marginBottom = "12dp", gravity = "center" },
            { TextView, text = rewardTextStr, textSize = "18sp", textColor = rewardTextColor, layout_marginBottom = "20dp", gravity = "center" },
            { Button, id = "playAgainBtn", text = "Play Again", layout_width = "fill", layout_marginBottom = "10dp", backgroundColor = "#388E3C", textColor = Color.WHITE, textSize = "16sp" },
            { Button, id = "shareResultsBtn", text = "Share Results", layout_width = "fill", layout_marginBottom = "10dp", backgroundColor = "#0288D1", textColor = Color.WHITE, textSize = "16sp" },
            { Button, id = "resultMainMenuBtn", text = "Back to Main Menu", layout_width = "fill", backgroundColor = "#D32F2F", textColor = Color.WHITE, textSize = "16sp" }
          }
        }

        dlgResult = LuaDialog(activity)
        dlgResult.View = loadlayout(resultLayout)
        dlgResult.setCancelable(false)

        attachBackListener(dlgResult, function()
            dlgResult.dismiss()
            if dlgGame then dlgGame.dismiss() end
            openMainMenuWindow()
        end)

        dlgResult.show()

        playAgainBtn.onClick = function()
            hasAwardedWinCoins = false
            dlgResult.dismiss()
            if dlgGame then dlgGame.dismiss() end
            openGamePlayWindow(selectedMapPath)
        end

        shareResultsBtn.onClick = function()
            shareGameResult(isWin, selectedMapName, playerBoatName, randomMsg, coinsEarned)
        end

        resultMainMenuBtn.onClick = function()
            dlgResult.dismiss()
            if dlgGame then dlgGame.dismiss() end
            openMainMenuWindow()
        end
    end

    local startGlobalClock = function()
      if timeLoopRunnable then mainHandler.removeCallbacks(timeLoopRunnable) end
      timeLoopRunnable = luajava.createProxy("java.lang.Runnable", {
        run = function()
          gameTimeMinutes = gameTimeMinutes + 1.0 
          if gameTimeMinutes >= 60 then
              gameTimeMinutes = gameTimeMinutes - 60
              gameTimeHours = gameTimeHours + 1
              if gameTimeHours >= 24 then gameTimeHours = 0 end
          end

          local newTimeOfDay = ""
          if gameTimeHours >= 5 and gameTimeHours < 12 then newTimeOfDay = "morning"
          elseif gameTimeHours >= 12 and gameTimeHours < 17 then newTimeOfDay = "afternoon"
          elseif gameTimeHours >= 17 and gameTimeHours < 20 then newTimeOfDay = "evening"
          else newTimeOfDay = "night" end

          isNight = (newTimeOfDay == "night")

          if isEngineStarted and currentTimeOfDay ~= "" and currentTimeOfDay ~= newTimeOfDay then
              if newTimeOfDay == "morning" then
                  speakStatus("Good morning! Morning has arrived.", true)
                  pcall(function()
                      if headlightBtn then
                          headlightBtn.setVisibility(View.GONE)
                          isHeadlightOn = false
                          headlightBtn.setText("Torch")
                          headlightBtn.setBackgroundColor(Color.parseColor("#F57C00"))
                      end
                  end)
              elseif newTimeOfDay == "afternoon" then
                  speakStatus("Good afternoon! The sun is high.", true)
                  pcall(function()
                      if headlightBtn then
                          headlightBtn.setVisibility(View.GONE)
                          isHeadlightOn = false
                          headlightBtn.setText("Torch")
                          headlightBtn.setBackgroundColor(Color.parseColor("#F57C00"))
                      end
                  end)
              elseif newTimeOfDay == "evening" then
                  speakStatus("Good evening! The sun is setting.", true)
                  pcall(function()
                      if headlightBtn then
                          headlightBtn.setVisibility(View.GONE)
                          isHeadlightOn = false
                          headlightBtn.setText("Torch")
                          headlightBtn.setBackgroundColor(Color.parseColor("#F57C00"))
                      end
                  end)
              elseif newTimeOfDay == "night" then
                  speakStatus("Good night! Night has arrived, robot night protocol activated.", true)
                  pcall(function()
                      if headlightBtn then
                          local hasTorch = prefs.getBoolean("has_torch", false)
                          if hasTorch then
                              headlightBtn.setVisibility(View.VISIBLE)
                          else
                              headlightBtn.setVisibility(View.GONE)
                          end
                      end
                  end)
              end
          end
          
          currentTimeOfDay = newTimeOfDay

          mainHandler.postDelayed(timeLoopRunnable, 700) 
        end
      })
      mainHandler.post(timeLoopRunnable)
    end

    local generateObstaclesAndStorms = function()
      activeThunderstorms = {}
      activeHurricanes = {}
      
      local maxStormsLimit = math.floor(RACE_LIMIT / 4000) 
      if maxStormsLimit < 2 then maxStormsLimit = 2 end
      if maxStormsLimit > 15 then maxStormsLimit = 15 end
      
      local stormCount = 0
      if math.random(1, 100) > 40 then
         stormCount = math.random(1, maxStormsLimit)
      end
      
      local lastEnd = 200 
      for i = 1, stormCount do
        if lastEnd >= RACE_LIMIT - 500 then break end
        local gap = math.random(500, 3500)
        local sStart = lastEnd + gap
        if sStart >= RACE_LIMIT - 300 then break end
        local sLength = math.random(300, 4000) 
        local sType = (math.random(1, 100) > 65) and "heavy" or "normal"
        
        table.insert(activeThunderstorms, {
          startDist = sStart, endDist = sStart + sLength, type = sType,
          warned = false, robotWarned = false, entered = false, passed = false, robotEntered = false, robotPassed = false,
          speedTimer = 0
        })
        lastEnd = sStart + sLength
      end

      if RACE_LIMIT >= 10000 and math.random(1, 5) == 1 then
         local hStart = math.random(2000, RACE_LIMIT - 3000)
         table.insert(activeHurricanes, {
            startDist = hStart, endDist = hStart + 3500,
            warned = false, robotWarned = false, entered = false, passed = false, robotEntered = false, robotPassed = false, idleTimer = 0, speedTimer = 0
         })
      end

      activeObstacles = {}
      local obstacleCount = math.floor(RACE_LIMIT / 1200) + 4
      local isColdOcean = (selectedMapIndex == 0 or selectedMapIndex == 1)
      
      for i = 1, obstacleCount do
         local obsType = ""
         if isColdOcean then 
             obsType = (math.random(1, 2) == 1) and "Iceberg" or "Large Ice Floe"
         else
             local roll = math.random(1, 3)
             if roll == 1 then obsType = "Floating Log" 
             elseif roll == 2 then obsType = "Fallen Tree" 
             else obsType = "Abandoned Buoy" end
         end
         
         -- Generate obstacles strictly on either the Right (> 0) or Left (< 0) side of the track
         local xPos = math.random(25, 80)
         if math.random(1, 2) == 1 then xPos = -xPos end

         table.insert(activeObstacles, { y = math.random(800, RACE_LIMIT - 500), x = xPos, name = obsType, warned = false, robotWarned = false, crossed = false })
      end
    end

    local getCurrentOceanWeather = function()
      local locObj = getLocObjForDistance(playerDistance)
      return Vedar.getCurrentOceanWeather(playerDistance, weatherOffset, activeHurricanes, activeThunderstorms, locObj, selectedMapIndex, isNight)
    end

    createEndGameListener = function()
      return luajava.createProxy("android.content.DialogInterface$OnClickListener", {
        onClick = function(dialog, which)
          if dlgGame then dlgGame.dismiss() end
          openMainMenuWindow()
        end
      })
    end

    hideGameButtons = function()
      pcall(function()
        if checkWeatherBtn then checkWeatherBtn.setVisibility(View.GONE) end
        if checkLocationBtn then checkLocationBtn.setVisibility(View.GONE) end
        if checkTimeBtn then checkTimeBtn.setVisibility(View.GONE) end
        if boatHornBtn then boatHornBtn.setVisibility(View.GONE) end
        if headlightBtn then headlightBtn.setVisibility(View.GONE) end
      end)
    end

    local stopAllAudio = function()
      isEngineStarted = false 
      isSwipeActive = false 
      isCountingDown = false
      isHeadlightOn = false 
      playerDriftDistance = 0 
      robotDriftDistance = 0 
      robotTargetDrift = 0
      announceTickCounter = 0 
      announceTurn = 0 
      etaTickCounter = 0
      periodicEtaCounter = 0 
      periodicEtaTurn = 0 
      wasPlayerOffTrack = false
      currentCalculatedSpeed = 0.0 
      currentRobotCalculatedSpeed = 0.0 
      expectedPedalCommand = "up" 
      isRobotSunk = false
      robotNightStateTimer = 0.0
      isRobotStoppedAtNight = false
      
      if cancelFuelGraceTimer then cancelFuelGraceTimer() end
      
      if liveEtaTxt then liveEtaTxt.setText("ETA: Stopped") end
      if statusMessageTxt then statusMessageTxt.setText("Race Stopped") end
      
      if gameLoopRunnable then mainHandler.removeCallbacks(gameLoopRunnable) end
      if timeLoopRunnable then mainHandler.removeCallbacks(timeLoopRunnable) end
      if decelerationRunnable then mainHandler.removeCallbacks(decelerationRunnable) end
      
      if Sound and Sound.stopAllAudio then pcall(Sound.stopAllAudio) end
      playerDistance = 0.0 
      robotDistance = 0.0
    end

    local handleBoatCrash = function(msgOverride)
      stopAllAudio()
      hideGameButtons()
      if Sound and Sound.playCrashSound then pcall(Sound.playCrashSound) end
      local msg = msgOverride or "Crash! You collided with the boat. Race over!"
      speakStatus(msg, true)
      showResultDialog(false, msg)
    end

    local handleBoatSink = function(reasonText)
      stopAllAudio()
      hideGameButtons()
      if Sound and Sound.playSinkingSound then pcall(Sound.playSinkingSound) end
      local msg = reasonText or "Your boat sank into the ocean!"
      speakStatus(msg, true)
      showResultDialog(false, msg)
    end

    local speakPlayerETA = function()
      if isEngineStarted then
        local speedToUse = isPedalBoatSelected and PEDAL_BOAT_SPEED or playerSpeedMultiplier
        if speedToUse < 0.5 then speedToUse = 0.5 end
        local pEtaSeconds = (RACE_LIMIT - playerDistance) / speedToUse
        speakStatus("Your ETA is " .. formatTimeForSpeech(pEtaSeconds), true)
      end
    end

    local speakRobotETA = function()
      if isEngineStarted then
        if isRobotSunk then speakStatus("Robot boat is sunk", true) return end
        local rSpeedToUse = robotSpeedMultiplier
        if rSpeedToUse < 0.5 then rSpeedToUse = 0.5 end
        local rEtaSeconds = (RACE_LIMIT - robotDistance) / rSpeedToUse
        speakStatus("Robot ETA is " .. formatTimeForSpeech(rEtaSeconds), true)
      end
    end

    cancelFuelGraceTimer = function()
      fuelEmptyGraceActive = false
      if fuelGraceRunnable then 
          mainHandler.removeCallbacks(fuelGraceRunnable) 
          fuelGraceRunnable = nil 
      end
    end

    local startFuelGraceTimer = function()
      if fuelEmptyGraceActive then return end
      fuelEmptyGraceActive = true
      fuelGraceTimerSeconds = 40
      speakStatus("Warning! Your fuel is empty. You have 40 seconds to refuel, otherwise your boat will sink!", true)
      
      fuelGraceRunnable = luajava.createProxy("java.lang.Runnable", {
        run = function()
          if not fuelEmptyGraceActive or not isEngineStarted then return end
          fuelGraceTimerSeconds = fuelGraceTimerSeconds - 1
          if fuelGraceTimerSeconds > 0 then
             if fuelGraceTimerSeconds == 30 or fuelGraceTimerSeconds == 20 or fuelGraceTimerSeconds == 10 or fuelGraceTimerSeconds <= 5 then
                 speakStatus(string.format("Warning! %d seconds remaining to refill fuel.", fuelGraceTimerSeconds), true)
             end
             mainHandler.postDelayed(fuelGraceRunnable, 1000)
          else
             handleBoatSink("Out of fuel! 40 seconds have passed and your boat sank.")
          end
        end
      })
      mainHandler.postDelayed(fuelGraceRunnable, 1000)
    end

    local startGameLoop = function()
      if gameLoopRunnable then mainHandler.removeCallbacks(gameLoopRunnable) end
      gameLoopRunnable = luajava.createProxy("java.lang.Runnable", {
        run = function()
          if isEngineStarted then
            local inHurricane = false
            local activeHurObj = nil
            for _, hur in ipairs(activeHurricanes) do
               if playerDistance >= hur.startDist and playerDistance <= hur.endDist then
                  inHurricane = true 
                  activeHurObj = hur 
                  break
               end
            end

            local inStorm = false
            local activeStormObj = nil
            for _, storm in ipairs(activeThunderstorms) do
               if playerDistance >= storm.startDist and playerDistance <= storm.endDist then
                  inStorm = true 
                  activeStormObj = storm 
                  break
               end
            end

            local playerCurrentSpeedMeters = 0.0
            if currentFuel <= 0 and not isPedalBoatSelected then
               currentCalculatedSpeed = 0.0 
               playerCurrentSpeedMeters = 0.0
            else
               if isPedalBoatSelected then
                  if currentCalculatedSpeed > 0 then
                      currentCalculatedSpeed = currentCalculatedSpeed - 0.02
                      if currentCalculatedSpeed < 0 then currentCalculatedSpeed = 0 end
                  end
                  playerCurrentSpeedMeters = currentCalculatedSpeed * PEDAL_BOAT_SPEED 
                  playerDistance = playerDistance + (playerCurrentSpeedMeters * 0.150)
               elseif currentCalculatedSpeed > 0.05 then
                  playerCurrentSpeedMeters = currentCalculatedSpeed * playerSpeedMultiplier
                  playerDistance = playerDistance + (playerCurrentSpeedMeters * 0.150)
               end
               
               if inHurricane then
                   if currentCalculatedSpeed < 0.05 and not isPedalBoatSelected then
                       activeHurObj.idleTimer = (activeHurObj.idleTimer or 0) + 0.150
                       if activeHurObj.idleTimer >= 120.0 then
                           handleBoatSink("You stayed completely still for 2 minutes inside the Hurricane Storm! Massive waves sank your boat.")
                           return
                       end
                   else
                       activeHurObj.idleTimer = 0
                   end
                   
                   if currentCalculatedSpeed > 0.1 and not isPedalBoatSelected then
                       activeHurObj.speedTimer = (activeHurObj.speedTimer or 0) + 0.150
                       if activeHurObj.speedTimer >= 2.0 then
                           activeHurObj.speedTimer = 0
                           if math.random(1, 100) <= 90 then
                               handleBoatSink("Extreme 90 percent Hurricane danger took over! You drove too fast and a violent wave sank your boat!")
                               return
                           end
                       end
                   else
                       activeHurObj.speedTimer = 0
                   end
               elseif inStorm then
                   if activeStormObj.type == "heavy" then
                       if currentCalculatedSpeed > 0.25 and not isPedalBoatSelected then
                           activeStormObj.speedTimer = (activeStormObj.speedTimer or 0) + 0.150
                           if activeStormObj.speedTimer >= 2.0 then
                               activeStormObj.speedTimer = 0
                               if math.random(1, 100) <= 60 then
                                   handleBoatSink("Heavy thunderstorm waves capsized your boat! You must drive very slowly in heavy storms.")
                                   return
                               end
                           end
                       else
                           activeStormObj.speedTimer = 0
                       end
                   else
                       if currentCalculatedSpeed > 0.6 and not isPedalBoatSelected then
                           activeStormObj.speedTimer = (activeStormObj.speedTimer or 0) + 0.150
                           if activeStormObj.speedTimer >= 2.0 then
                               activeStormObj.speedTimer = 0
                               if math.random(1, 100) <= 40 then
                                   handleBoatSink("You drove too fast in a thunderstorm! A strong wave capsized your boat.")
                                   return
                               end
                           end
                       else
                           activeStormObj.speedTimer = 0
                       end
                   end
               end
            end

            if not isPedalBoatSelected then
                local boatFuelMulti = 1.0
                if playerBoatName == "Wave Runner Mini" then boatFuelMulti = 1.0
                elseif playerBoatName == "Sea Viper Cruiser" then boatFuelMulti = 1.3
                elseif playerBoatName == "Titan" then boatFuelMulti = 1.6
                elseif playerBoatName == "Leviathan Hypercraft" then boatFuelMulti = 2.0 end

                local distanceTick = playerCurrentSpeedMeters * 0.150
                local fuelDrain = (distanceTick / 16000) * 100 * boatFuelMulti 
                
                if distanceTick > 0 and not fuelEmptyGraceActive then currentFuel = currentFuel - fuelDrain end
                if currentFuel < 0 then currentFuel = 0 end
                
                if currentFuel <= 10 and currentFuel > 9.8 and not fuelWarning10Given then
                    fuelWarning10Given = true
                    speakStatus("Critical Warning! Your fuel is at 10 percent!", true)
                    if refillFuelBtn then refillFuelBtn.setVisibility(View.VISIBLE) end
                end

                if fuelStatusTxt then
                    fuelStatusTxt.setText(string.format("Fuel: %d%%", math.floor(currentFuel)))
                    if currentFuel <= 10 then fuelStatusTxt.setTextColor(Color.RED)
                    elseif currentFuel <= 30 then fuelStatusTxt.setTextColor(Color.YELLOW)
                    else fuelStatusTxt.setTextColor(Color.GREEN) end
                end

                if currentFuel <= 0 then 
                    if not fuelEmptyGraceActive then startFuelGraceTimer() end 
                end

                if not isRobotSunk then
                    local rDistanceTick = (currentRobotCalculatedSpeed * robotSpeedMultiplier * 0.150)
                    local rBoatFuelMulti = 1.0
                    if robotBoatName == "Wave Runner Mini" then rBoatFuelMulti = 1.0
                    elseif robotBoatName == "Sea Viper Cruiser" then rBoatFuelMulti = 1.3
                    elseif robotBoatName == "Titan" then rBoatFuelMulti = 1.6
                    elseif robotBoatName == "Leviathan Hypercraft" then rBoatFuelMulti = 2.0 end
                    
                    local rFuelDrain = (rDistanceTick / 16000) * 100 * rBoatFuelMulti
                    if rDistanceTick > 0 then currentRobotFuel = currentRobotFuel - rFuelDrain end
                    
                    if currentRobotFuel <= 15 then
                        currentRobotFuel = 100.0 
                        robotFuelWarning10Given = false 
                        speakStatus("Robot smartly performed an emergency refuel.", false)
                    end
                end
            else
                if fuelStatusTxt then 
                    fuelStatusTxt.setText("Fuel: Unlimited (Pedal)") 
                    fuelStatusTxt.setTextColor(Color.CYAN) 
                end
            end

            if not isRobotSunk then
              local robotInHurricane, robotInHeavyStorm, robotInStorm = false, false, false
              for _, hur in ipairs(activeHurricanes) do
                 if robotDistance >= hur.startDist and robotDistance <= hur.endDist then
                    robotInHurricane = true
                    if not hur.robotEntered then 
                        hur.robotEntered = true 
                        speakStatus("Robot smartly adjusted speed entering hurricane storm!", false) 
                    end
                    break
                 end
              end

              for _, storm in ipairs(activeThunderstorms) do
                 if robotDistance >= storm.startDist and robotDistance <= storm.endDist then
                    robotInStorm = true
                    if storm.type == "heavy" then robotInHeavyStorm = true end
                    if not storm.robotEntered then 
                        storm.robotEntered = true 
                        speakStatus("Robot entered weather front and slowed down to prevent capsizing.", false) 
                    end
                    break
                 end
              end

              local robotTargetThrottle = 1.0
              if isNight then
                  robotNightStateTimer = robotNightStateTimer + 0.150
                  if robotNightStateTimer >= 10.0 then
                      robotNightStateTimer = 0.0
                      isRobotStoppedAtNight = not isRobotStoppedAtNight
                      if isRobotStoppedAtNight then
                          speakStatus("Robot stopped its boat at night to check surroundings safely.", false)
                      else
                          speakStatus("Robot started moving again after a brief night stop.", false)
                      end
                  end
                  if isRobotStoppedAtNight then robotTargetThrottle = 0.0 else robotTargetThrottle = 0.35 end
              else
                  isRobotStoppedAtNight = false
                  robotNightStateTimer = 0.0
                  if robotInHurricane then robotTargetThrottle = 0.08 
                  elseif robotInHeavyStorm then robotTargetThrottle = 0.20 
                  elseif robotInStorm then robotTargetThrottle = 0.50 
                  else robotTargetThrottle = 0.95 end
              end

              currentRobotCalculatedSpeed = robotTargetThrottle
              robotDistance = robotDistance + (currentRobotCalculatedSpeed * robotSpeedMultiplier * 0.150)

              local robotIsDodging = false
              for _, obs in ipairs(activeObstacles) do
                 local rDistToObs = obs.y - robotDistance
                 local nightObsLimit = isNight and 10 or 200
                 if rDistToObs > 0 and rDistToObs < nightObsLimit then
                     if math.abs(robotDriftDistance - obs.x) < 30 then
                         robotIsDodging = true
                         if obs.x > 0 then robotDriftDistance = robotDriftDistance - 10 else robotDriftDistance = robotDriftDistance + 10 end
                     end
                 end
              end

              local yDistanceGap = math.abs(playerDistance - robotDistance)
              local xDistanceGap = math.abs(playerDriftDistance - robotDriftDistance)

              if yDistanceGap < 35 and xDistanceGap < 20 then
                 robotIsDodging = true
                 if robotDriftDistance >= playerDriftDistance then robotDriftDistance = robotDriftDistance + 8 else robotDriftDistance = robotDriftDistance - 8 end
              end
              
              if not robotIsDodging and not isRobotStoppedAtNight then
                  if math.random(1, 40) == 1 or math.abs(robotDriftDistance - robotTargetDrift) < 5 then
                      robotTargetDrift = math.random(-90, 90) 
                  end
                  if robotDriftDistance < robotTargetDrift then robotDriftDistance = robotDriftDistance + 2
                  elseif robotDriftDistance > robotTargetDrift then robotDriftDistance = robotDriftDistance - 2 end
              end

              if robotDriftDistance > 98 then robotDriftDistance = 98 end
              if robotDriftDistance < -98 then robotDriftDistance = -98 end

              if math.random(1, 200) == 50 and not isRobotStoppedAtNight then
                  if Sound and Sound.playRobotHornSound then pcall(function() Sound.playRobotHornSound(yDistanceGap, robotDriftDistance - playerDriftDistance) end) end
              end

              if yDistanceGap < 8 and xDistanceGap < 10 and playerDistance > 30 then
                  handleBoatCrash("Crash! High speed collision between your boat and the robot! Both boats damaged.")
                  return 
              end
            end

            local hurWarnDist = (isNight and not isHeadlightOn) and 15 or 300
            for _, hur in ipairs(activeHurricanes) do
               local distToHur = hur.startDist - playerDistance
               if distToHur > 0 and distToHur <= hurWarnDist and not hur.warned then
                  hur.warned = true 
                  speakStatus(string.format("Warning! Extreme Hurricane storm ahead in %s!", formatDist(distToHur)), true)
               end
               if playerDistance >= hur.startDist and playerDistance <= hur.endDist then
                  if not hur.entered then
                     hur.entered = true 
                     if Sound and Sound.startHurricaneAudio then pcall(Sound.startHurricaneAudio) end
                     speakStatus("Entered Hurricane Storm! Keep low speed, do not stop completely!", true)
                  end
               end
               if playerDistance > hur.endDist and hur.entered then 
                   if Sound and Sound.stopThunderstormAudio then pcall(Sound.stopThunderstormAudio) end 
               end
            end

            local obsWarnDist = (isNight and not isHeadlightOn) and 15 or 300
            for _, obs in ipairs(activeObstacles) do
               local distToObs = obs.y - playerDistance
               if distToObs > 0 and distToObs <= obsWarnDist and not obs.warned then
                  obs.warned = true
                  local steerDir = obs.x > 0 and "Left" or "Right"
                  speakStatus(string.format("Warning! %s ahead in %s! Turn %s to avoid it!", obs.name, formatDist(distToObs), steerDir), true)
               end

               if not isRobotSunk then
                   local rDistToObs = obs.y - robotDistance
                   local robotWarnLimit = isNight and 10 or 200
                   if rDistToObs > 0 and rDistToObs <= robotWarnLimit and not obs.robotWarned then
                      obs.robotWarned = true
                      local steerDir = obs.x > 0 and "left" or "right"
                      speakStatus(string.format("Robot Warning! %s ahead in %s. Robot turning %s.", obs.name, formatDist(rDistToObs), steerDir), true)
                   end
               end

               -- OBSTACLE COLLISION DETECTOR (FIXED TO GUARANTEE 100% CRASH IF PLAYER FAILS TO DODGE)
               if not obs.crossed and playerDistance >= obs.y then
                  obs.crossed = true
                  local isCollision = false

                  if obs.x > 0 then
                      -- Obstacle is on the Right side. Player must steer Left into negative values (< 0) to avoid it.
                      if playerDriftDistance >= 0 or playerDriftDistance >= (obs.x - 30) then
                          isCollision = true
                      end
                  else
                      -- Obstacle is on the Left side. Player must steer Right into positive values (> 0) to avoid it.
                      if playerDriftDistance <= 0 or playerDriftDistance <= (obs.x + 30) then
                          isCollision = true
                      end
                  end

                  if isCollision then 
                      handleBoatCrash(string.format("Crash! You hit a %s in the water!", obs.name:lower())) 
                      return
                  else 
                      speakStatus(string.format("%s crossed successfully!", obs.name), true) 
                  end
               end
            end

            local stormWarnDist = (isNight and not isHeadlightOn) and 15 or 300
            for _, storm in ipairs(activeThunderstorms) do
              local distToStorm = storm.startDist - playerDistance
              if distToStorm > 0 and distToStorm <= stormWarnDist and not storm.warned then
                storm.warned = true
                local stormName = storm.type == "heavy" and "Heavy thunderstorm" or "Thunderstorm"
                speakStatus(string.format("Warning! %s approaching in %s!", stormName, formatDist(distToStorm)), true)
              end

              if not isRobotSunk then
                 local rDistToStorm = storm.startDist - robotDistance
                 local rStormWarnDist = isNight and 15 or 300
                 if rDistToStorm > 0 and rDistToStorm <= rStormWarnDist and not storm.robotWarned then
                    storm.robotWarned = true
                    local stormName = storm.type == "heavy" and "Heavy thunderstorm" or "Thunderstorm"
                    speakStatus(string.format("Robot Warning! %s approaching robot in %s.", stormName, formatDist(rDistToStorm)), true)
                 end
              end

              if playerDistance >= storm.startDist and playerDistance <= storm.endDist then
                if not storm.entered then
                  storm.entered = true 
                  if Sound and Sound.startThunderstormAudio then pcall(function() Sound.startThunderstormAudio(storm.type) end) end 
                  local stormName = storm.type == "heavy" and "heavy thunderstorm" or "thunderstorm"
                  speakStatus(string.format("Warning! You have entered a %s.", stormName), true)
                end
              end
              if playerDistance > storm.endDist and storm.entered and not storm.passed then
                storm.passed = true 
                if Sound and Sound.stopThunderstormAudio then pcall(Sound.stopThunderstormAudio) end 
                speakStatus("Severe weather passed successfully.", true)
              end
            end

            local playerOffsetFromRobot = math.abs(playerDriftDistance - robotDriftDistance)
            local isPlayerOutOfBounds = playerOffsetFromRobot > 100

            if isPlayerOutOfBounds and not wasPlayerOffTrack then
                wasPlayerOffTrack = true
                speakStatus("You are now more than 100 meters away from the track route!", true)
            elseif not isPlayerOutOfBounds and wasPlayerOffTrack then
                wasPlayerOffTrack = false
                speakStatus("Track route found back successfully.", true)
            end

            periodicEtaCounter = periodicEtaCounter + 150
            if periodicEtaCounter >= 46000 then 
                periodicEtaCounter = 0
                if periodicEtaTurn == 0 then 
                    speakRobotETA() 
                    periodicEtaTurn = 1 
                else 
                    speakPlayerETA() 
                    periodicEtaTurn = 0 
                end
            end

            etaTickCounter = etaTickCounter + 150
            if etaTickCounter >= 1000 then 
                local _, windNow, _, _, _ = getCurrentOceanWeather()
                if Sound and Sound.startWindyAudio and Sound.stopWindyAudio then
                    if inHurricane or windNow >= 20 then pcall(Sound.startWindyAudio) else pcall(Sound.stopWindyAudio) end
                end

                if liveEtaTxt then
                    local pSpeed = isPedalBoatSelected and PEDAL_BOAT_SPEED or playerSpeedMultiplier
                    if pSpeed < 0.5 then pSpeed = 0.5 end
                    local pEta = math.max(0, (RACE_LIMIT - playerDistance) / pSpeed)
                    
                    local rEtaStr = "Sunk"
                    if not isRobotSunk then
                      local rSpeed = robotSpeedMultiplier
                      if rSpeed < 0.5 then rSpeed = 0.5 end
                      local rEta = math.max(0, (RACE_LIMIT - robotDistance) / rSpeed)
                      rEtaStr = formatTimeForScreen(rEta)
                    end
                    liveEtaTxt.setText(string.format("Live ETA\nYou: %s\nRobot: %s", formatTimeForScreen(pEta), rEtaStr))
                end
                etaTickCounter = 0
            end

            announceTickCounter = announceTickCounter + 150
            if announceTickCounter >= 10000 then 
               announceTickCounter = 0
               local playerHazardAlert = ""
               for _, obs in ipairs(activeObstacles) do
                  if obs.warned and not obs.crossed then
                     local distToObs = obs.y - playerDistance
                     if distToObs > 0 and distToObs < 600 then
                        local steerDir = obs.x > 0 and "Left" or "Right"
                        playerHazardAlert = playerHazardAlert .. string.format(". %s is %s ahead, turn %s to avoid", obs.name, formatDist(distToObs), steerDir) 
                     end
                  end
               end

               for _, storm in ipairs(activeThunderstorms) do
                  if storm.warned and not storm.entered then
                     local distToStorm = storm.startDist - playerDistance
                     if distToStorm > 0 and distToStorm < 600 then
                        local stormName = storm.type == "heavy" and "Heavy thunderstorm" or "Thunderstorm"
                        playerHazardAlert = playerHazardAlert .. string.format(". %s is %s ahead", stormName, formatDist(distToStorm))
                     end
                  end
               end
               
               local robotHazardAlert = ""
               if not isRobotSunk then
                   for _, storm in ipairs(activeThunderstorms) do
                      if storm.robotWarned and not storm.robotEntered then
                         local rDistToStorm = storm.startDist - robotDistance
                         if rDistToStorm > 0 and rDistToStorm < 600 then
                            local stormName = storm.type == "heavy" and "Heavy thunderstorm" or "Thunderstorm"
                            robotHazardAlert = robotHazardAlert .. string.format(". %s is %s ahead of robot", stormName, formatDist(rDistToStorm))
                         end
                      end
                   end
               end
               
               if announceTurn == 0 or isRobotSunk then
                   local relX = playerDriftDistance - robotDriftDistance
                   local sideText = "aligned with robot"
                   if isRobotSunk then
                     sideText = "aligned with track"
                     if playerDriftDistance < 0 then sideText = string.format("%s left of center", formatDist(math.abs(playerDriftDistance)))
                     elseif playerDriftDistance > 0 then sideText = string.format("%s right of center", formatDist(math.abs(playerDriftDistance))) end
                     speakStatus(string.format("You %s, %s. Robot is sunk%s", formatDist(playerDistance), sideText, playerHazardAlert), false)
                   else
                     if relX < 0 then sideText = string.format("%s left of robot", formatDist(math.abs(relX)))
                     elseif relX > 0 then sideText = string.format("%s right of robot", formatDist(math.abs(relX))) end
                     local relY = math.abs(playerDistance - robotDistance)
                     local aheadBehindText = playerDistance >= robotDistance and "ahead of robot" or "behind robot"
                     speakStatus(string.format("You %s, %s, %s %s%s", formatDist(playerDistance), sideText, formatDist(relY), aheadBehindText, playerHazardAlert), false)
                   end
                   announceTurn = 1 
               else
                   local xDiffRel = robotDriftDistance - playerDriftDistance
                   local rSide = "aligned with you"
                   if xDiffRel < 0 then rSide = string.format("%s to your left", formatDist(math.abs(xDiffRel)))
                   elseif xDiffRel > 0 then rSide = string.format("%s to your right", formatDist(math.abs(xDiffRel))) end
                   local yDiffRel = math.abs(robotDistance - playerDistance)
                   local rAheadBehind = robotDistance >= playerDistance and "ahead of you" or "behind you"
                   
                   speakStatus(string.format("Robot %s, %s, %s %s%s", formatDist(robotDistance), rSide, formatDist(yDiffRel), rAheadBehind, robotHazardAlert), false)
                   announceTurn = 0 
               end
            end

            if playerDistance >= RACE_LIMIT then
                stopAllAudio()
                hideGameButtons()
                if playerOffsetFromRobot <= 100 then
                    speakStatus("Victory! You finished the race inside the track!", true)
                    showResultDialog(true, "Victory! You finished the race inside the track!")
                else
                    speakStatus("You reached the finish line, but you were outside the 100 meter track limit. No victory!", true)
                    showResultDialog(false, "You reached the finish line, but you were outside the 100 meter track limit!")
                end
                return
            elseif not isRobotSunk and robotDistance >= RACE_LIMIT then
                stopAllAudio()
                hideGameButtons()
                speakStatus("Defeat! Robot finished first.", true)
                showResultDialog(false, "Defeat! Robot finished first.")
                return
            end

            if Sound and Sound.updateDynamicHardwareAudio then
                pcall(function() Sound.updateDynamicHardwareAudio(isEngineStarted, playerAudioPath, robotAudioPath, currentCalculatedSpeed, playerDriftDistance, isPedalBoatSelected, isRobotSunk, robotDistance, playerDistance, robotDriftDistance, currentRobotCalculatedSpeed) end)
            end
            mainHandler.postDelayed(gameLoopRunnable, 150)
          end
        end
      })
      mainHandler.post(gameLoopRunnable)
    end

    local startGradualDeceleration = function()
      if decelerationRunnable then mainHandler.removeCallbacks(decelerationRunnable) end
      decelerationRunnable = luajava.createProxy("java.lang.Runnable", {
        run = function()
          if not isSwipeActive and isEngineStarted and not isPedalBoatSelected then
            if currentCalculatedSpeed > 0.05 then
              currentCalculatedSpeed = currentCalculatedSpeed - 0.02 
              if Sound and Sound.updateDynamicHardwareAudio then
                  pcall(function() Sound.updateDynamicHardwareAudio(isEngineStarted, playerAudioPath, robotAudioPath, currentCalculatedSpeed, playerDriftDistance, isPedalBoatSelected, isRobotSunk, robotDistance, playerDistance, robotDriftDistance, currentRobotCalculatedSpeed) end)
              end
              mainHandler.postDelayed(decelerationRunnable, 60)
            else
              currentCalculatedSpeed = 0.0 
              if Sound and Sound.updateDynamicHardwareAudio then
                  pcall(function() Sound.updateDynamicHardwareAudio(isEngineStarted, playerAudioPath, robotAudioPath, currentCalculatedSpeed, playerDriftDistance, isPedalBoatSelected, isRobotSunk, robotDistance, playerDistance, robotDriftDistance, currentRobotCalculatedSpeed) end)
              end
            end
          end
        end
      })
      mainHandler.post(decelerationRunnable)
    end

    local processControlsEngine = function(event, viewHeight)
      if not event then return end
      local pointerCount = event.getPointerCount()
      local action = event.getActionMasked()

      if not isEngineStarted or isCountingDown then return end
      if currentFuel <= 0 and not isPedalBoatSelected then speakStatus("You don't have fuel. Refill your fuel to drive.", true) return end

      if action == MotionEvent.ACTION_DOWN or action == MotionEvent.ACTION_POINTER_DOWN then 
        isSwipeActive = true 
        isEtaTriggered = false
        if decelerationRunnable then mainHandler.removeCallbacks(decelerationRunnable) end
        if pointerCount >= 1 then 
            xStart = event.getX(0) 
            yStart = event.getY(0) 
        end
      elseif action == MotionEvent.ACTION_MOVE then 
        if pointerCount >= 1 then
          local yCurrent = event.getY(0)
          local xCurrent = event.getX(0)
          if not xStart then xStart = xCurrent end
          if not yStart then yStart = yCurrent end
          
          if not isPedalBoatSelected then
            local ratio = math.min(1.0, math.max(0.0, (viewHeight - yCurrent) / viewHeight))
            currentCalculatedSpeed = ratio 
            if Sound and Sound.updateDynamicHardwareAudio then
                pcall(function() Sound.updateDynamicHardwareAudio(isEngineStarted, playerAudioPath, robotAudioPath, currentCalculatedSpeed, playerDriftDistance, isPedalBoatSelected, isRobotSunk, robotDistance, playerDistance, robotDriftDistance, currentRobotCalculatedSpeed) end)
            end
          end

          if pointerCount == 1 then
            local xDiff = xCurrent - xStart
            local yDiff = yCurrent - yStart
            
            if yDiff > 150 and xDiff > 150 and not isEtaTriggered then
                isEtaTriggered = true; xStart = xCurrent; yStart = yCurrent
                if Sound and Sound.playBoatHornSound then pcall(Sound.playBoatHornSound) end
            elseif yDiff < -150 and xDiff > 150 and not isEtaTriggered then
                isEtaTriggered = true; xStart = xCurrent; yStart = yCurrent
                if checkTimeBtn then checkTimeBtn.performClick() end
            elseif yDiff > 150 and xDiff < -150 and not isEtaTriggered then
                isEtaTriggered = true; xStart = xCurrent; yStart = yCurrent
                if checkLocationBtn then checkLocationBtn.performClick() end
            elseif yDiff < -150 and xDiff < -150 and not isEtaTriggered then
                isEtaTriggered = true; xStart = xCurrent; yStart = yCurrent
                if checkWeatherBtn then checkWeatherBtn.performClick() end
            elseif xDiff > MIN_SWIPE_DISTANCE and math.abs(yDiff) < 100 and not isEtaTriggered then
                isEtaTriggered = true
                playerDriftDistance = playerDriftDistance + 15 
                local steerMsg = "Steered Right"
                if isPedalBoatSelected then steerMsg = "Steered Right. Swipe " .. expectedPedalCommand end
                speakStatus(steerMsg, true) 
                xStart = xCurrent; yStart = yCurrent
            elseif xDiff < -MIN_SWIPE_DISTANCE and math.abs(yDiff) < 100 and not isEtaTriggered then
                isEtaTriggered = true
                playerDriftDistance = playerDriftDistance - 15 
                local steerMsg = "Steered Left"
                if isPedalBoatSelected then steerMsg = "Steered Left. Swipe " .. expectedPedalCommand end
                speakStatus(steerMsg, true) 
                xStart = xCurrent; yStart = yCurrent
            elseif yDiff < -MIN_SWIPE_DISTANCE and math.abs(xDiff) < 100 and isPedalBoatSelected and not isEtaTriggered then
                isEtaTriggered = true
                xStart = xCurrent; yStart = yCurrent
                if expectedPedalCommand == "up" then
                    currentCalculatedSpeed = 1.0
                    expectedPedalCommand = (math.random(1, 2) == 1) and "up" or "down"
                    speakStatus("Swipe " .. expectedPedalCommand, true)
                else
                    handleBoatSink("You swiped up but the command was swipe down! Your boat capsized.")
                end
            elseif yDiff > MIN_SWIPE_DISTANCE and math.abs(xDiff) < 100 and isPedalBoatSelected and not isEtaTriggered then
                isEtaTriggered = true
                xStart = xCurrent; yStart = yCurrent
                if expectedPedalCommand == "down" then
                    currentCalculatedSpeed = 1.0
                    expectedPedalCommand = (math.random(1, 2) == 1) and "up" or "down"
                    speakStatus("Swipe " .. expectedPedalCommand, true)
                else
                    handleBoatSink("You swiped down but the command was swipe up! Your boat capsized.")
                end
            end
          end
        end
      elseif action == MotionEvent.ACTION_UP or action == MotionEvent.ACTION_CANCEL then 
        isSwipeActive = false 
        if not isPedalBoatSelected then startGradualDeceleration() end
      end
    end

    local startCountdownSystem = function()
      isCountingDown = true
      isHeadlightOn = false 
      hasAwardedWinCoins = false
      if liveEtaTxt then liveEtaTxt.setText("ETA: Calculating...") end
      
      generateObstaclesAndStorms()
      currentFuel = 100.0 
      currentRobotFuel = 100.0
      fuelWarning10Given = false 
      robotFuelWarning10Given = false
      if refillFuelBtn then refillFuelBtn.setVisibility(View.GONE) end
      if cancelFuelGraceTimer then cancelFuelGraceTimer() end 
      
      if isPedalBoatSelected then expectedPedalCommand = (math.random(1, 2) == 1) and "up" or "down" end
      if fuelStatusTxt then fuelStatusTxt.setTextColor(Color.GREEN) end

      if Sound and Sound.playStartCountdownAudio then pcall(Sound.playStartCountdownAudio) end
      
      mainHandler.postDelayed(luajava.createProxy("java.lang.Runnable", {
        run = function()
          speakStatus("3", true)
          mainHandler.postDelayed(luajava.createProxy("java.lang.Runnable", {
            run = function()
              if not isCountingDown then return end 
              speakStatus("2", true)
              mainHandler.postDelayed(luajava.createProxy("java.lang.Runnable", {
                run = function()
                  if not isCountingDown then return end 
                  speakStatus("1", true)
                  mainHandler.postDelayed(luajava.createProxy("java.lang.Runnable", {
                    run = function()
                      if not isCountingDown then return end
                      isCountingDown = false 
                      isEngineStarted = true
                      playerDistance = 0.0 
                      robotDistance = 0.0 
                      playerDriftDistance = 0 
                      robotDriftDistance = math.random(15, 30)
                      if math.random(1, 2) == 1 then robotDriftDistance = -robotDriftDistance end
                      robotTargetDrift = math.random(-80, 80)
                      
                      announceTickCounter = 0; announceTurn = 0; etaTickCounter = 0; periodicEtaCounter = 0; periodicEtaTurn = 0
                      wasPlayerOffTrack = false; currentCalculatedSpeed = 0.0; currentRobotCalculatedSpeed = 0.0
                      isEtaTriggered = false; isRobotSunk = false; robotNightStateTimer = 0.0; isRobotStoppedAtNight = false
                      
                      if startRacingBtn then startRacingBtn.setVisibility(View.GONE) end
                      if isPedalBoatSelected then
                          speakStatus("Game Started. Swipe " .. expectedPedalCommand, true)
                      else
                          speakStatus("Game Started. Must finish within 100 meters of the track route to win!", true)
                      end
                      
                      if Sound and Sound.updateDynamicHardwareAudio then
                          pcall(function() Sound.updateDynamicHardwareAudio(isEngineStarted, playerAudioPath, robotAudioPath, 0.0, playerDriftDistance, isPedalBoatSelected, isRobotSunk, robotDistance, playerDistance, robotDriftDistance, currentRobotCalculatedSpeed) end)
                      end
                      startGameLoop()
                    end
                  }), 1000)
                end
              }), 1000)
            end
          }), 1000)
        end
      }), 1000)
    end

    local menuLayout = {
      ScrollView, layout_width = "fill", layout_height = "fill", fillViewport = "true", backgroundColor = "#121212",
      { LinearLayout, orientation = "vertical", layout_width = "fill", layout_height = "wrap", gravity = "center", padding = "24dp",
        { TextView, text = "Boat Racing Game", textSize = "28sp", textColor = Color.CYAN, layout_marginBottom = "16dp" },
        { TextView, text = "Select Your Ocean", textSize = "20sp", textColor = Color.WHITE, layout_marginBottom = "8dp" },
        { Spinner, id = "oceanSpinner", layout_width = "fill", layout_marginBottom = "24dp", backgroundColor = "#212121" },
        { TextView, text = "Select Your Boat", textSize = "20sp", textColor = Color.WHITE, layout_marginBottom = "8dp" },
        { Spinner, id = "boatSpinner", layout_width = "fill", layout_marginBottom = "30dp", backgroundColor = "#212121" },
        { Button, id = "collectTokenBtn", text = "Collect Token", layout_width = "fill", layout_marginBottom = "14dp", backgroundColor = "#0288D1", textColor = Color.WHITE, textSize = "18sp" },
        { Button, id = "exitGameBtn", text = "Back to Menu", layout_width = "fill", backgroundColor = "#D32F2F", textColor = Color.WHITE, textSize = "18sp" }
      }
    }

    local refreshBoatSpinnerOptions = function(boatSpinner)
      local boatOptions = {}
      if unlockedBoats.pedal then table.insert(boatOptions, "Aqua Glider Pedal Boat (5 m/s)") end
      if unlockedBoats.small then table.insert(boatOptions, "Wave Runner Mini (10 m/s)") end
      if unlockedBoats.advance then table.insert(boatOptions, "Sea Viper Cruiser (20 m/s)") end
      if unlockedBoats.big then table.insert(boatOptions, "Titan (30 m/s)") end
      if unlockedBoats.hyper then table.insert(boatOptions, "Leviathan Hypercraft (50 m/s)") end

      local boatAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, boatOptions)
      boatAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
      boatSpinner.setAdapter(boatAdapter)
    end

    openMainMenuWindow = function()
      local oceanCosts = {
          [0] = 5,   -- Arctic Ocean
          [1] = 10,  -- Southern Ocean
          [2] = 30,  -- Indian Ocean
          [3] = 20,  -- Atlantic Ocean
          [4] = 50,  -- Pacific Ocean
          [5] = 15   -- Deep Basins
      }

      dlgMenu = LuaDialog(activity) 
      dlgMenu.View = loadlayout(menuLayout) 
      dlgMenu.setCancelable(false)
      
      attachBackListener(dlgMenu, function()
          stopAllAudio()
          if Sound and Sound.stopMenuMusic then pcall(Sound.stopMenuMusic) end
          dlgMenu.dismiss()
          if gamesMenu and gamesMenu.show then
              gamesMenu.show(params)
          elseif mainUI then
              pcall(mainUI)
          else
              activity.finish()
          end
      end)
      dlgMenu.show() 
      if Sound and Sound.startMenuMusic then pcall(Sound.startMenuMusic) end

      local oceanOptions = { 
        "Arctic Ocean (5 kilometer)", 
        "Southern Ocean (10 kilometer)", 
        "Indian Ocean (20 kilometer)", 
        "Atlantic Ocean (30 kilometer)", 
        "Pacific Ocean (50 kilometer)",
        "Special: Inland Seas & Deep Basins (15 kilometer)"
      }
      local oceanAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, oceanOptions)
      oceanAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
      oceanSpinner.setAdapter(oceanAdapter)

      oceanSpinner.setOnItemSelectedListener(luajava.createProxy("android.widget.AdapterView$OnItemSelectedListener", {
          onItemSelected = function(parent, view, position, id)
              local cost = oceanCosts[position] or 5
              collectTokenBtn.setText(string.format("Collect Token — Cost: %d Coins", cost))
          end,
          onNothingSelected = function(parent) end
      }))
      
      unlockedBoats = {
        pedal = prefs.getBoolean("boat_pedal", false),
        small = prefs.getBoolean("boat_small", true),
        advance = prefs.getBoolean("boat_advance", false),
        big = prefs.getBoolean("boat_big", false),
        hyper = prefs.getBoolean("boat_hyper", false)
      }
      refreshBoatSpinnerOptions(boatSpinner)

      exitGameBtn.onClick = function()
          stopAllAudio()
          if Sound and Sound.stopMenuMusic then pcall(Sound.stopMenuMusic) end
          dlgMenu.dismiss()
          if gamesMenu and gamesMenu.show then
              gamesMenu.show(params)
          elseif mainUI then
              pcall(mainUI)
          else
              activity.finish()
          end
      end

      local function proceedToGame()
          gameTimeHours = math.random(0, 23)
          gameTimeMinutes = math.random(0, 59)
          
          if gameTimeHours >= 5 and gameTimeHours < 12 then currentTimeOfDay = "morning"
          elseif gameTimeHours >= 12 and gameTimeHours < 17 then currentTimeOfDay = "afternoon"
          elseif gameTimeHours >= 17 and gameTimeHours < 20 then currentTimeOfDay = "evening"
          else currentTimeOfDay = "night" end
          isNight = (currentTimeOfDay == "night")

          if selectedMapIndex == 0 then selectedMapName = "Arctic Ocean (5 kilometer)" selectedMapPath = Sound and Sound.paths and Sound.paths.arcticOcean or "" RACE_LIMIT = 5000
          elseif selectedMapIndex == 1 then selectedMapName = "Southern Ocean (10 kilometer)" selectedMapPath = Sound and Sound.paths and Sound.paths.southernOcean or "" RACE_LIMIT = 10000
          elseif selectedMapIndex == 2 then selectedMapName = "Indian Ocean (20 kilometer)" selectedMapPath = Sound and Sound.paths and Sound.paths.indianOcean or "" RACE_LIMIT = 20000
          elseif selectedMapIndex == 3 then selectedMapName = "Atlantic Ocean (30 kilometer)" selectedMapPath = Sound and Sound.paths and Sound.paths.atlanticOcean or "" RACE_LIMIT = 30000
          elseif selectedMapIndex == 4 then selectedMapName = "Pacific Ocean (50 kilometer)" selectedMapPath = Sound and Sound.paths and Sound.paths.pacificOcean or "" RACE_LIMIT = 50000
          else selectedMapName = "Inland Seas & Deep Basins (15 kilometer)" selectedMapPath = Sound and Sound.paths and Sound.paths.indianOcean or "" RACE_LIMIT = 15000 end

          local selectedBoatText = tostring(boatSpinner.getSelectedItem() or "")
          if selectedBoatText:find("Aqua Glider") then 
              playerAudioPath = Sound and Sound.paths and Sound.paths.pedalBoat or "" playerSpeedMultiplier = PEDAL_BOAT_SPEED playerBoatName = "Aqua Glider Pedal Boat" isPedalBoatSelected = true
          elseif selectedBoatText:find("Wave Runner") then 
              playerAudioPath = Sound and Sound.paths and Sound.paths.oldBoat or "" playerSpeedMultiplier = SMALL_BOAT_SPEED playerBoatName = "Wave Runner Mini" isPedalBoatSelected = false
          elseif selectedBoatText:find("Sea Viper") then 
              playerAudioPath = Sound and Sound.paths and Sound.paths.advanceBoat or "" playerSpeedMultiplier = ADVANCE_BOAT_SPEED playerBoatName = "Sea Viper Cruiser" isPedalBoatSelected = false
          elseif selectedBoatText:find("Titan") then 
              playerAudioPath = Sound and Sound.paths and Sound.paths.bigBoat or "" playerSpeedMultiplier = BIG_BOAT_SPEED playerBoatName = "Titan" isPedalBoatSelected = false
          else 
              playerAudioPath = Sound and Sound.paths and Sound.paths.hyperBoat or "" playerSpeedMultiplier = HYPER_BOAT_SPEED playerBoatName = "Leviathan Hypercraft" isPedalBoatSelected = false 
          end

          local randBoat = math.random(1, 5)
          if randBoat == 1 then robotAudioPath = Sound and Sound.paths and Sound.paths.pedalBoat or "" robotSpeedMultiplier = PEDAL_BOAT_SPEED robotBoatName = "Aqua Glider Pedal Boat"
          elseif randBoat == 2 then robotAudioPath = Sound and Sound.paths and Sound.paths.oldBoat or "" robotSpeedMultiplier = SMALL_BOAT_SPEED robotBoatName = "Wave Runner Mini"
          elseif randBoat == 3 then robotAudioPath = Sound and Sound.paths and Sound.paths.advanceBoat or "" robotSpeedMultiplier = ADVANCE_BOAT_SPEED robotBoatName = "Sea Viper Cruiser"
          elseif randBoat == 4 then robotAudioPath = Sound and Sound.paths and Sound.paths.bigBoat or "" robotSpeedMultiplier = BIG_BOAT_SPEED robotBoatName = "Titan"
          else robotAudioPath = Sound and Sound.paths and Sound.paths.hyperBoat or "" robotSpeedMultiplier = HYPER_BOAT_SPEED robotBoatName = "Leviathan Hypercraft" end

          if Sound and Sound.stopMenuMusic then pcall(Sound.stopMenuMusic) end 
          dlgMenu.dismiss() 
          openVerifyTokenWindow()
      end

      local isProcessingToken = false

      collectTokenBtn.onClick = function()
        if isProcessingToken then return end

        selectedMapIndex = oceanSpinner.getSelectedItemPosition()
        local cost = oceanCosts[selectedMapIndex] or 5
        
        local getCoins = params.getSecureCoins or _G.getSecureCoins
        local currentCoins = getCoins and getCoins() or 0
        
        if currentCoins >= cost then
            isProcessingToken = true
            
            local cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE)
            local ni = cm.getActiveNetworkInfo()
            if not (ni ~= nil and ni.isConnected()) then
               Toast.makeText(activity, "No internet connection!", 0).show()
               isProcessingToken = false
               return
            end

            local currentUname = prefs.getString("username", "")
            local currentId = prefs.getString("userid", "")
            local currentRole = prefs.getString("role", "user")

            if currentUname == "" then
              Toast.makeText(activity, "Session expired!", 0).show()
              isProcessingToken = false
              return
            end

            local pd = ProgressDialog.show(activity, "Processing", "Syncing with Firebase Server...")
            local firebaseUrl = "https://all-games-76b5d-default-rtdb.firebaseio.com/users/"
            local nodeKey = currentUname:lower():gsub(" ", "%%20")
            local userUrl = firebaseUrl .. nodeKey .. ".json"

            Http.get(userUrl, function(code, content)
                if code == 200 and content and content ~= "null" then
                    local serverData = {
                      coins = 0, memory_keys = 0, memory_key_bought_before = false,
                      public_chat_keys = 0, public_chat_key_bought_before = false,
                      audio_ff_keys = 0, audio_ff_bought_before = false,
                      has_shotgun = false, has_ak47 = false, has_machine_gun = false,
                      has_torch = false,
                      fuel_cans = 0, potion_revival = 0, potion_healing = 0
                    }
                    
                    pcall(function()
                        local cleanContent = content:gsub("^%s*(.-)%s*$", "%1")
                        local jsonObj = JSONObject(cleanContent)
                        local userDataObj = jsonObj
                        
                        local keysIter = jsonObj.keys()
                        if keysIter.hasNext() then
                            local firstKey = tostring(keysIter.next())
                            if firstKey:sub(1,1) == "-" then
                                userDataObj = jsonObj.optJSONObject(firstKey)
                            end
                        end
                        
                        if userDataObj ~= nil then
                            if userDataObj.has("coins") and not userDataObj.isNull("coins") then
                                serverData.coins = tonumber(tostring(userDataObj.get("coins"))) or 0
                            end
                            serverData.memory_keys = tonumber(tostring(userDataObj.opt("memory_keys"))) or 0
                            serverData.memory_key_bought_before = userDataObj.optBoolean("memory_key_bought_before", false)
                            serverData.public_chat_keys = tonumber(tostring(userDataObj.opt("public_chat_keys"))) or 0
                            serverData.public_chat_key_bought_before = userDataObj.optBoolean("public_chat_key_bought_before", false)
                            serverData.audio_ff_keys = tonumber(tostring(userDataObj.opt("audio_ff_keys"))) or 0
                            serverData.audio_ff_bought_before = userDataObj.optBoolean("audio_ff_bought_before", false)
                            serverData.has_shotgun = userDataObj.optBoolean("has_shotgun", false)
                            serverData.has_ak47 = userDataObj.optBoolean("has_ak47", false)
                            serverData.has_machine_gun = userDataObj.optBoolean("has_machine_gun", false)
                            serverData.has_torch = userDataObj.optBoolean("has_torch", false)
                            serverData.fuel_cans = tonumber(tostring(userDataObj.opt("fuel_cans"))) or 0
                            serverData.potion_revival = tonumber(tostring(userDataObj.opt("potion_revival"))) or 0
                            serverData.potion_healing = tonumber(tostring(userDataObj.opt("potion_healing"))) or 0
                        end
                    end)
                    
                    if serverData.coins >= cost then
                        local finalCoins = math.floor(serverData.coins - cost)
                        
                        local jsonParts = {}
                        table.insert(jsonParts, '"userid": "' .. currentId .. '"')
                        table.insert(jsonParts, '"username": "' .. currentUname .. '"')
                        table.insert(jsonParts, '"role": "' .. currentRole .. '"')
                        table.insert(jsonParts, '"coins": ' .. finalCoins)
                        table.insert(jsonParts, '"memory_keys": ' .. tostring(serverData.memory_keys))
                        table.insert(jsonParts, '"memory_key_bought_before": ' .. tostring(serverData.memory_key_bought_before))
                        table.insert(jsonParts, '"public_chat_keys": ' .. tostring(serverData.public_chat_keys))
                        table.insert(jsonParts, '"public_chat_key_bought_before": ' .. tostring(serverData.public_chat_key_bought_before))
                        table.insert(jsonParts, '"audio_ff_keys": ' .. tostring(serverData.audio_ff_keys))
                        table.insert(jsonParts, '"audio_ff_bought_before": ' .. tostring(serverData.audio_ff_bought_before))
                        table.insert(jsonParts, '"has_shotgun": ' .. tostring(serverData.has_shotgun))
                        table.insert(jsonParts, '"has_ak47": ' .. tostring(serverData.has_ak47))
                        table.insert(jsonParts, '"has_machine_gun": ' .. tostring(serverData.has_machine_gun))
                        table.insert(jsonParts, '"has_torch": ' .. tostring(serverData.has_torch))
                        table.insert(jsonParts, '"fuel_cans": ' .. tostring(serverData.fuel_cans))
                        table.insert(jsonParts, '"potion_revival": ' .. tostring(serverData.potion_revival))
                        table.insert(jsonParts, '"potion_healing": ' .. tostring(serverData.potion_healing))

                        local updateData = "{" .. table.concat(jsonParts, ", ") .. "}"
                        local updateUrl = userUrl .. "?x-http-method-override=PATCH"

                        Http.post(updateUrl, updateData, function(updCode, updContent)
                            pd.dismiss()
                            isProcessingToken = false
                            if updCode >= 200 and updCode < 300 then
                                local setCoins = params.setSecureCoins or _G.setSecureCoins
                                if setCoins then 
                                    setCoins(finalCoins) 
                                end
                                editor.putBoolean("has_torch", serverData.has_torch)
                                editor.apply()
                                speakStatus("Token collected! " .. cost .. " coins deducted.", true)
                                proceedToGame()
                            else
                                Toast.makeText(activity, "Server transaction failed! " .. updCode, 0).show()
                            end
                        end)
                    else
                        pd.dismiss()
                        isProcessingToken = false
                        speakStatus("Not enough coins! You need " .. cost .. " coins to collect this token.", true)
                    end
                else
                    pd.dismiss()
                    isProcessingToken = false
                    Toast.makeText(activity, "Server connectivity failure.", 0).show()
                end
            end)
        else
            speakStatus("Not enough coins! You need " .. cost .. " coins to collect this token.", true)
            return
        end
      end
    end

    openVerifyTokenWindow = function()
      local verifyTokenLayout = {
        LinearLayout, orientation = "vertical", layout_width = "fill", layout_height = "fill", gravity = "center", backgroundColor = "#121212", padding = "24dp",
        { TextView, text = "Verify Token", textSize = "26sp", textColor = Color.WHITE, layout_marginBottom = "20dp" },
        { TextView, id = "tokenStatusTxt", text = "Verifying your token...", textSize = "16sp", textColor = Color.YELLOW, layout_marginBottom = "30dp", gravity = "center" }
      }
      
      dlgVerifyToken = LuaDialog(activity) 
      dlgVerifyToken.View = loadlayout(verifyTokenLayout) 
      dlgVerifyToken.setCancelable(false)
      
      attachBackListener(dlgVerifyToken, nil) 
      dlgVerifyToken.show() 
      speakStatus("Verifying your token", true)

      mainHandler.postDelayed(luajava.createProxy("java.lang.Runnable", {
        run = function()
          if Sound and Sound.playTokenSound then pcall(Sound.playTokenSound) end 
          speakStatus("Token verified successfully", true)
          mainHandler.postDelayed(luajava.createProxy("java.lang.Runnable", { 
              run = function() 
                  dlgVerifyToken.dismiss() 
                  openOceanEntryDialog() 
              end 
          }), 1500)
        end
      }), 3000)
    end

    openOceanEntryDialog = function()
      local oceanEntryLayout = {
        LinearLayout, orientation = "vertical", layout_width = "fill", layout_height = "fill", gravity = "center", backgroundColor = "#1A1A1A", padding = "24dp",
        { TextView, text = selectedMapName, textSize = "26sp", textColor = Color.CYAN, layout_marginBottom = "30dp", gravity = "center" },
        { Button, id = "enterOceanBtn", text = "Enter The Ocean", layout_width = "fill", backgroundColor = "#388E3C", textColor = Color.WHITE, textSize = "18sp" }
      }

      dlgOceanEntry = LuaDialog(activity) 
      dlgOceanEntry.View = loadlayout(oceanEntryLayout) 
      dlgOceanEntry.setCancelable(false)
      
      attachBackListener(dlgOceanEntry, function() 
          dlgOceanEntry.dismiss() 
          openMainMenuWindow() 
      end) 
      dlgOceanEntry.show()

      enterOceanBtn.onClick = function() 
          dlgOceanEntry.dismiss() 
          openGamePlayWindow(selectedMapPath) 
      end
    end

    openGamePlayWindow = function(bgPath)
      local gameLayout = {
        RelativeLayout, layout_width = "fill", layout_height = "fill", backgroundColor = "#1A1A1A",
        { LinearLayout, orientation = "vertical", layout_width = "fill", layout_height = "fill", gravity = "center", padding = "16dp",
          { TextView, id = "mapTitleTxt", text = "Race Arena", textSize = "22sp", textColor = Color.CYAN, layout_marginBottom = "5dp" },
          { TextView, id = "boatTitleTxt", text = "Boat", textSize = "16sp", textColor = Color.WHITE, layout_marginBottom = "10dp" },
          { TextView, id = "fuelStatusTxt", text = "Fuel: 100%", textSize = "16sp", textColor = Color.GREEN, layout_marginBottom = "10dp", gravity = "center" },
          { TextView, id = "_liveEtaTxt", text = "Live ETA: Ready", textSize = "16sp", textColor = Color.YELLOW, layout_marginBottom = "15dp", gravity = "center" },
          { TextView, id = "_statusMessageTxt", text = "Status will appear here", textSize = "20sp", textColor = Color.parseColor("#FF5252"), layout_marginBottom = "20dp", gravity = "center" },
          { Button, id = "_refillFuelBtn", text = "Refill Fuel", backgroundColor = "#D32F2F", textColor = Color.WHITE, textSize = "16sp", layout_width = "fill", layout_marginBottom="15dp", visibility="gone" },
          { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "10dp",
            { Button, id = "_startRacingBtn", text = "Start", backgroundColor = "#388E3C", textColor = Color.WHITE, textSize = "16sp", layout_weight = "1", layout_marginRight = "5dp" },
            { Button, id = "_boatHornBtn", text = "Boat Horn", backgroundColor = "#E65100", textColor = Color.WHITE, textSize = "16sp", layout_weight = "1", layout_marginLeft = "5dp" },
          },
          { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "20dp",
            { Button, id = "_headlightBtn", text = "Torch", backgroundColor = "#F57C00", textColor = Color.WHITE, textSize = "13sp", layout_weight = "1", layout_marginRight = "2dp", visibility="gone" },
            { Button, id = "_checkWeatherBtn", text = "Weather", backgroundColor = "#F9A825", textColor = Color.WHITE, textSize = "13sp", layout_weight = "1", layout_marginRight = "2dp", layout_marginLeft="2dp" },
            { Button, id = "_checkTimeBtn", text = "Time", backgroundColor = "#7B1FA2", textColor = Color.WHITE, textSize = "13sp", layout_weight = "1", layout_marginLeft = "2dp", layout_marginRight = "2dp" },
            { Button, id = "_checkLocationBtn", text = "Location", backgroundColor = "#0288D1", textColor = Color.WHITE, textSize = "13sp", layout_weight = "1", layout_marginLeft = "2dp" },
          },
          { Button, id = "backMapBtn", text = "Quit Race", layout_width = "fill" }
        }
      }

      dlgGame = LuaDialog(activity) 
      dlgGame.View = loadlayout(gameLayout) 
      dlgGame.setCancelable(false)
      
      liveEtaTxt = _liveEtaTxt
      statusMessageTxt = _statusMessageTxt
      checkWeatherBtn = _checkWeatherBtn
      checkLocationBtn = _checkLocationBtn
      checkTimeBtn = _checkTimeBtn
      boatHornBtn = _boatHornBtn
      headlightBtn = _headlightBtn
      refillFuelBtn = _refillFuelBtn
      startRacingBtn = _startRacingBtn
      
      weatherOffset = math.random(0, 100000)
      currentRaceRoute = {}
      local pool = locationDB[selectedMapIndex]
      local currentGenDist = 0
      
      while currentGenDist < RACE_LIMIT do
          local segmentLength = math.random(200, 1500)
          local idx = math.random(1, #pool)
          table.insert(currentRaceRoute, {
              sea = pool[idx].sea,
              nearbyCountry = pool[idx].nearbyCountry,
              region = pool[idx].region,
              startDist = currentGenDist,
              endDist = currentGenDist + segmentLength
          })
          currentGenDist = currentGenDist + segmentLength
      end
      
      playerDistance = 0.0
      hasAwardedWinCoins = false
      if Vedar and Vedar.resetTemp then pcall(Vedar.resetTemp) end
      
      startGlobalClock()
      getCurrentOceanWeather()

      attachBackListener(dlgGame, function() 
          AlertDialog.Builder(activity).setTitle("Quit Race").setMessage("Are you sure you want to quit the race?")
          .setPositiveButton("Yes", luajava.createProxy("android.content.DialogInterface$OnClickListener", {
              onClick = function(dialog, which) 
                  if isEngineStarted and not isPedalBoatSelected and ownedFuelCans > 0 then
                      ownedFuelCans = ownedFuelCans - 1
                      saveGameData()
                      speakStatus("Race quit mid-way. 1 fuel can was lost.", true)
                  end
                  stopAllAudio() 
                  dlgGame.dismiss() 
                  openMainMenuWindow() 
              end
          })).setNegativeButton("No", nil).show()
      end)
      dlgGame.show()

      statusMessageTxt.setTypeface(Typeface.DEFAULT_BOLD)
      mapTitleTxt.setText(selectedMapName)
      boatTitleTxt.setText("Your Boat: " .. playerBoatName)
      refillFuelBtn.setText("Refill Fuel (Cans: " .. ownedFuelCans .. ")")
      
      if isPedalBoatSelected then
         startRacingBtn.setText("Start Aqua Glider") 
         fuelStatusTxt.setVisibility(View.GONE) 
         refillFuelBtn.setVisibility(View.GONE)
      else
         startRacingBtn.setText("Start Motor Boat") 
         fuelStatusTxt.setVisibility(View.VISIBLE) 
         refillFuelBtn.setVisibility(View.GONE) 
      end

      if Sound and Sound.startOceanBg then pcall(function() Sound.startOceanBg(bgPath) end) end
      
      if gameTimeHours >= 5 and gameTimeHours < 12 then currentTimeOfDay = "morning"
      elseif gameTimeHours >= 12 and gameTimeHours < 17 then currentTimeOfDay = "afternoon"
      elseif gameTimeHours >= 17 and gameTimeHours < 20 then currentTimeOfDay = "evening"
      else currentTimeOfDay = "night" end
      isNight = (currentTimeOfDay == "night")

      local timeGreeting = ""
      if currentTimeOfDay == "morning" then timeGreeting = "Good morning! Welcome to the open waters!"
      elseif currentTimeOfDay == "afternoon" then timeGreeting = "Good afternoon! Welcome to the open waters!"
      elseif currentTimeOfDay == "evening" then timeGreeting = "Good evening! Welcome to the open waters!"
      else timeGreeting = "Good night! It's dark, navigate carefully in the open waters!" end
      
      local hasTorch = prefs.getBoolean("has_torch", false)
      if isNight and hasTorch then headlightBtn.setVisibility(View.VISIBLE) else headlightBtn.setVisibility(View.GONE) end

      speakStatus(string.format("%s Your %s is ready to race against the robot's %s. Good luck!", timeGreeting, playerBoatName, robotBoatName), true)
      
      headlightBtn.onClick = function()
          if not isHeadlightOn then
              isHeadlightOn = true
              headlightBtn.setText("Torch ON")
              headlightBtn.setBackgroundColor(Color.parseColor("#4CAF50"))
              speakStatus("Headlight successfully turned on.", true)
          else
              isHeadlightOn = false
              headlightBtn.setText("Torch")
              headlightBtn.setBackgroundColor(Color.parseColor("#F57C00"))
              speakStatus("Headlight turned off.", true)
          end
      end

      refillFuelBtn.onClick = function()
         if ownedFuelCans > 0 then
             ownedFuelCans = ownedFuelCans - 1
             saveGameData()
             currentFuel = 100.0 
             fuelWarning10Given = false 
             if cancelFuelGraceTimer then cancelFuelGraceTimer() end
             refillFuelBtn.setText("Refill Fuel (Cans: " .. ownedFuelCans .. ")")
             fuelStatusTxt.setText("Fuel: 100%") 
             fuelStatusTxt.setTextColor(Color.GREEN) 
             refillFuelBtn.setVisibility(View.GONE)
             speakStatus("Fuel refilled successfully. You have " .. ownedFuelCans .. " cans left.", true)
         else
             speakStatus("You don't have any fuel cans left!", true)
         end
      end

      boatHornBtn.onClick = function()
          if Sound and Sound.playBoatHornSound then pcall(Sound.playBoatHornSound) end
      end

      checkWeatherBtn.onClick = function()
        local hurricaneActiveHere = false
        for _, hur in ipairs(activeHurricanes) do 
            if playerDistance >= hur.startDist and playerDistance <= hur.endDist then hurricaneActiveHere = true break end 
        end
        if hurricaneActiveHere then 
            speakStatus("The weather is Severe Hurricane Storm, 100 percent precipitation.", true)
        else
           local temp, windSpeed, humidity, condition, windDir = getCurrentOceanWeather()
           local tempString = (temp < 0) and ("minus " .. math.abs(temp)) or tostring(temp)
           local weatherMsg = string.format("%s degree Celsius %s, wind speed %d kilometer per hour from %s", tempString, condition, windSpeed, windDir)
           speakStatus(weatherMsg, true)
        end
      end

      checkLocationBtn.onClick = function()
       local locObj = getLocObjForDistance(playerDistance)
       local locationMsg = locObj.nearbyCountry and string.format("You are in %s, nearby %s.", locObj.sea, locObj.nearbyCountry) or string.format("You are in %s.", locObj.sea)
       speakStatus(locationMsg, true)
      end

      checkTimeBtn.onClick = function()
          speakStatus("Current time is " .. getFormattedGameTime(), true)
      end

      startRacingBtn.onClick = function() 
          startRacingBtn.setVisibility(View.GONE)
          startCountdownSystem() 
      end

      local decorView = dlgGame.Window.getDecorView()
      decorView.setOnTouchListener(luajava.createProxy("android.view.View$OnTouchListener", {
        onTouch = function(v, event) 
            processControlsEngine(event, decorView.getHeight()) 
            return true 
        end
      }))
      
      backMapBtn.onClick = function()
          AlertDialog.Builder(activity).setTitle("Quit Race").setMessage("Are you sure you want to quit the race?")
          .setPositiveButton("Yes", luajava.createProxy("android.content.DialogInterface$OnClickListener", {
              onClick = function(dialog, which) 
                  if isEngineStarted and not isPedalBoatSelected and ownedFuelCans > 0 then
                      ownedFuelCans = ownedFuelCans - 1
                      saveGameData()
                      speakStatus("Race quit mid-way. 1 fuel can was lost.", true)
                  end
                  stopAllAudio() 
                  dlgGame.dismiss() 
                  openMainMenuWindow() 
              end
          })).setNegativeButton("No", nil).show()
      end
    end

    openMainMenuWindow()
end

return boatGameModule