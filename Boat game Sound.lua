local Sound = {}

import "android.media.MediaPlayer"
import "android.media.PlaybackParams"
import "android.speech.tts.TextToSpeech"
import "java.util.Locale"
import "android.os.Build"
import "android.os.Handler"
import "android.os.Looper"

local mainHandler = Handler(Looper.getMainLooper())

-- Audio File Names (Paths removed, only names kept)
local fileNames = {
  arcticOcean = "Arctic Ocean .mp3",
  southernOcean = "Southern ocean .mp3",
  indianOcean = "Indian Ocean .mp3",
  atlanticOcean = "Atlantic Ocean .mp3",
  pacificOcean = "Pacific Ocean .mp3",
  pedalBoat = "pedal boat .mp3",
  oldBoat = "personal motor board .mp3",
  advanceBoat = "advance motor boat .mp3",
  bigBoat = "big board .mp3",
  hyperBoat = "boat .mp3",
  crashSound = "boat crash .mp3",
  sinkingSound = "sinking sound .mp3",
  boatHorn = "boat horn .mp3",
  tokenSound = "tool tax token .mp3",
  menuMusic = "board game menu .mp3",
  heavyThunderstorm = "heavy thunderstorm .mp3",
  normalThunderstorm = "thunderstorm .mp3",
  windySound = "windy sound .mp3",
  startCountdown = "start countdown .mp3",
  hurricaneStorm = "Hurricane Storm .mp3"
}

-- Dynamic Audio Path Resolver
local function findSoundPath(fileName)
    local searchPaths = {}
    local currentActivity = activity or _G.activity

    if currentActivity then
        local luaDir = tostring(currentActivity.getLuaDir())
        table.insert(searchPaths, luaDir .. "/sounds/" .. fileName)
        table.insert(searchPaths, luaDir .. "/sound/" .. fileName)
        table.insert(searchPaths, luaDir .. "/" .. fileName)
        table.insert(searchPaths, luaDir .. "/Tools/boat racing game/" .. fileName)

        pcall(function()
            if currentActivity.getFilesDir() then
                local filesDir = tostring(currentActivity.getFilesDir().getAbsolutePath())
                table.insert(searchPaths, filesDir .. "/sounds/" .. fileName)
                table.insert(searchPaths, filesDir .. "/sound/" .. fileName)
                table.insert(searchPaths, filesDir .. "/" .. fileName)
                table.insert(searchPaths, filesDir .. "/Tools/boat racing game/" .. fileName)
            end
        end)
    end

    -- Fallback to original hardcoded path just in case
    table.insert(searchPaths, "/storage/emulated/0/解说/Tools/boat racing game/" .. fileName)

    -- Check which path actually exists and is readable
    for _, path in ipairs(searchPaths) do
        local f = io.open(path, "rb")
        if f then
            f:close()
            return path
        end
    end

    -- If no file is found, return a default fallback string
    if currentActivity then
        return tostring(currentActivity.getLuaDir()) .. "/sounds/" .. fileName
    else
        return "/storage/emulated/0/解说/Tools/boat racing game/" .. fileName
    end
end

-- Lazy-loaded Audio Paths (Uses Metatable to fetch paths automatically when requested)
Sound.paths = setmetatable({}, {
    __index = function(t, k)
        if fileNames[k] then
            local resolvedPath = findSoundPath(fileNames[k])
            rawset(t, k, resolvedPath) -- Caches the path so it only searches once
            return resolvedPath
        end
        return nil
    end
})

-- Players and Audio Engine States
Sound.bgPlayer = nil
Sound.racingPlayer = nil
Sound.robotPlayer = nil
Sound.menuPlayer = nil
Sound.thunderPlayer = nil
Sound.windPlayer = nil
Sound.ttsEngine = nil
Sound.isTtsReady = false
Sound.activeLoopers = {}

-- Initialize TTS Engine
function Sound.initTTS(context)
  local ttsListener = luajava.createProxy("android.speech.tts.TextToSpeech$OnInitListener", {
    onInit = function(status)
      if status == TextToSpeech.SUCCESS and Sound.ttsEngine then
        Sound.ttsEngine.setLanguage(Locale.US)
        Sound.ttsEngine.setPitch(1.0)
        Sound.ttsEngine.setSpeechRate(1.5)
        Sound.isTtsReady = true
      end
    end
  })
  pcall(function() Sound.ttsEngine = TextToSpeech(context, ttsListener) end)
end

function Sound.speakStatus(text, isImportantCommand, statusMessageTxt)
  if Sound.ttsEngine and Sound.isTtsReady then
    local queueMode = isImportantCommand and TextToSpeech.QUEUE_FLUSH or TextToSpeech.QUEUE_ADD
    if Build.VERSION.SDK_INT >= 21 then
      Sound.ttsEngine.speak(text, queueMode, nil, "BoatRaceTTS_" .. tostring(os.time()))
    else
      Sound.ttsEngine.speak(text, queueMode, nil)
    end
  end
  mainHandler.post(luajava.createProxy("java.lang.Runnable", {
    run = function()
      if statusMessageTxt then statusMessageTxt.setText(text) end
    end
  }))
end

function Sound.applyGaplessLoop(mp, loopId)
  pcall(function()
    mp.setLooping(false)
    if Sound.activeLoopers[loopId] then mainHandler.removeCallbacks(Sound.activeLoopers[loopId]) end
    local duration = mp.getDuration()
    Sound.activeLoopers[loopId] = luajava.createProxy("java.lang.Runnable", {
      run = function()
        pcall(function()
          if mp and mp.isPlaying() then
            local pos = mp.getCurrentPosition()
            if duration > 0 and (duration - pos) <= 55 then mp.seekTo(0) end
            mainHandler.postDelayed(Sound.activeLoopers[loopId], 15)
          end
        end)
      end
    })
    mainHandler.post(Sound.activeLoopers[loopId])
  end)
end

function Sound.playBoatHornSound()
  pcall(function()
    local hornMp = MediaPlayer()
    hornMp.setDataSource(Sound.paths.boatHorn)
    hornMp.prepare()
    hornMp.setVolume(1.0, 1.0)
    hornMp.start()
    hornMp.setOnCompletionListener(luajava.createProxy("android.media.MediaPlayer$OnCompletionListener", {
      onCompletion = function(mp) mp.release() end
    }))
  end)
end

function Sound.playRobotHornSound(distanceGap, xGap)
  if distanceGap > 1000.0 then return end
  pcall(function()
    local hornMp = MediaPlayer()
    hornMp.setDataSource(Sound.paths.boatHorn)
    hornMp.prepare()
    local fade = 1.0 - (distanceGap / 1000.0)
    if fade <= 0.0 then return end
    local pan = math.max(-1.0, math.min(1.0, xGap / 50.0))
    local leftVol = fade * math.min(1.0, 1.0 - pan)
    local rightVol = fade * math.min(1.0, 1.0 + pan)
    hornMp.setVolume(leftVol, rightVol)
    hornMp.start()
    hornMp.setOnCompletionListener(luajava.createProxy("android.media.MediaPlayer$OnCompletionListener", {
      onCompletion = function(mp) mp.release() end
    }))
  end)
end

function Sound.playCrashSound()
  pcall(function()
    local crashMp = MediaPlayer()
    crashMp.setDataSource(Sound.paths.crashSound)
    crashMp.prepare()
    crashMp.start()
    crashMp.setOnCompletionListener(luajava.createProxy("android.media.MediaPlayer$OnCompletionListener", {
      onCompletion = function(mp) mp.release() end
    }))
  end)
end

function Sound.playSinkingSound()
  pcall(function()
    local sinkMp = MediaPlayer()
    sinkMp.setDataSource(Sound.paths.sinkingSound)
    sinkMp.prepare()
    sinkMp.start()
    sinkMp.setOnCompletionListener(luajava.createProxy("android.media.MediaPlayer$OnCompletionListener", {
      onCompletion = function(mp) mp.release() end
    }))
  end)
end

function Sound.playTokenSound()
  pcall(function()
    local tokenMp = MediaPlayer()
    tokenMp.setDataSource(Sound.paths.tokenSound)
    tokenMp.prepare()
    tokenMp.start()
    tokenMp.setOnCompletionListener(luajava.createProxy("android.media.MediaPlayer$OnCompletionListener", {
      onCompletion = function(mp) mp.release() end
    }))
  end)
end

function Sound.playStartCountdownAudio()
  pcall(function()
    local cntMp = MediaPlayer()
    cntMp.setDataSource(Sound.paths.startCountdown)
    cntMp.prepare()
    cntMp.start()
    cntMp.setOnCompletionListener(luajava.createProxy("android.media.MediaPlayer$OnCompletionListener", {
      onCompletion = function(mp) mp.release() end
    }))
  end)
end

function Sound.startMenuMusic()
  pcall(function()
    if Sound.menuPlayer == nil then
      Sound.menuPlayer = MediaPlayer()
      Sound.menuPlayer.setDataSource(Sound.paths.menuMusic)
      Sound.menuPlayer.prepare()
      Sound.menuPlayer.setLooping(true)
    end
    if not Sound.menuPlayer.isPlaying() then Sound.menuPlayer.start() end
  end)
end

function Sound.stopMenuMusic()
  pcall(function()
    if Sound.menuPlayer then
      if Sound.menuPlayer.isPlaying() then Sound.menuPlayer.stop() end
      Sound.menuPlayer.release()
      Sound.menuPlayer = nil
    end
  end)
end

function Sound.startThunderstormAudio(stormType)
  pcall(function()
    if Sound.thunderPlayer == nil then
      Sound.thunderPlayer = MediaPlayer()
      local path = (stormType == "heavy") and Sound.paths.heavyThunderstorm or Sound.paths.normalThunderstorm
      Sound.thunderPlayer.setDataSource(path)
      Sound.thunderPlayer.prepare()
      Sound.thunderPlayer.setLooping(true)
    end
    if not Sound.thunderPlayer.isPlaying() then
      Sound.thunderPlayer.setVolume(0.8, 0.8)
      Sound.thunderPlayer.start()
    end
  end)
end

function Sound.stopThunderstormAudio()
  pcall(function()
    if Sound.thunderPlayer then
      if Sound.thunderPlayer.isPlaying() then Sound.thunderPlayer.stop() end
      Sound.thunderPlayer.release()
      Sound.thunderPlayer = nil
    end
  end)
end

function Sound.startHurricaneAudio()
  pcall(function()
    if Sound.thunderPlayer == nil then
      Sound.thunderPlayer = MediaPlayer()
      Sound.thunderPlayer.setDataSource(Sound.paths.hurricaneStorm)
      Sound.thunderPlayer.prepare()
      Sound.thunderPlayer.setLooping(true)
    end
    if not Sound.thunderPlayer.isPlaying() then
      Sound.thunderPlayer.setVolume(0.9, 0.9)
      Sound.thunderPlayer.start()
    end
  end)
end

function Sound.startWindyAudio()
  pcall(function()
    if Sound.windPlayer == nil then
      Sound.windPlayer = MediaPlayer()
      Sound.windPlayer.setDataSource(Sound.paths.windySound)
      Sound.windPlayer.prepare()
      Sound.windPlayer.setLooping(true)
    end
    if not Sound.windPlayer.isPlaying() then
      Sound.windPlayer.setVolume(0.6, 0.6)
      Sound.windPlayer.start()
    end
  end)
end

function Sound.stopWindyAudio()
  pcall(function()
    if Sound.windPlayer then
      if Sound.windPlayer.isPlaying() then Sound.windPlayer.stop() end
      Sound.windPlayer.release()
      Sound.windPlayer = nil
    end
  end)
end

function Sound.startOceanBg(path)
  pcall(function()
    if Sound.bgPlayer == nil then
      Sound.bgPlayer = MediaPlayer()
      Sound.bgPlayer.setDataSource(path)
      Sound.bgPlayer.prepare()
    end
    if not Sound.bgPlayer.isPlaying() then
      local bgVol = 0.35
      Sound.bgPlayer.setVolume(bgVol, bgVol)
      Sound.bgPlayer.start()
      Sound.applyGaplessLoop(Sound.bgPlayer, "bg_loop")
    end
  end)
end

function Sound.updateDynamicHardwareAudio(isEngineStarted, playerAudioPath, robotAudioPath, targetSpeed, playerDriftDistance, isPedalBoatSelected, isRobotSunk, robotDistance, playerDistance, robotDriftDistance, currentRobotCalculatedSpeed)
  pcall(function()
    if not isEngineStarted then return end
    
    if Sound.racingPlayer == nil then
      Sound.racingPlayer = MediaPlayer()
      Sound.racingPlayer.setDataSource(playerAudioPath)
      Sound.racingPlayer.prepare()
    end
    if not Sound.racingPlayer.isPlaying() then
      Sound.racingPlayer.start()
      Sound.applyGaplessLoop(Sound.racingPlayer, "player_loop")
    end

    local pLeftVol, pRightVol = 1.0, 1.0
    if playerDriftDistance < -5 then pRightVol = 0.8
    elseif playerDriftDistance > 5 then pLeftVol = 0.8
    end
    Sound.racingPlayer.setVolume(1.0 * pLeftVol, 1.0 * pRightVol)
    
    if Build.VERSION.SDK_INT >= 23 and not isPedalBoatSelected then
      local dynamicPitch = 0.7 + (targetSpeed * 0.8)
      if targetSpeed <= 0.05 then dynamicPitch = 0.7 end
      local pParams = PlaybackParams()
      pParams.setPitch(dynamicPitch)
      pParams.setSpeed(dynamicPitch)
      Sound.racingPlayer.setPlaybackParams(pParams)
    end

    if not isRobotSunk then
      local yDistanceGap = math.abs(robotDistance - playerDistance)
      local distanceFade = 1.0 - (yDistanceGap / 800.0)
      
      if distanceFade <= 0.0 then
        distanceFade = 0.0
        if Sound.robotPlayer and Sound.robotPlayer.isPlaying() then Sound.robotPlayer.pause() end
      else
        if Sound.robotPlayer == nil then
          Sound.robotPlayer = MediaPlayer()
          Sound.robotPlayer.setDataSource(robotAudioPath)
          Sound.robotPlayer.prepare()
        end
        if not Sound.robotPlayer.isPlaying() then
          Sound.robotPlayer.start()
          Sound.applyGaplessLoop(Sound.robotPlayer, "robot_loop")
        end

        local xDistanceRel = robotDriftDistance - playerDriftDistance
        local pan = math.max(-1.0, math.min(1.0, xDistanceRel / 50.0))
        local rLeftVol = distanceFade * math.min(1.0, 1.0 - pan)
        local rRightVol = distanceFade * math.min(1.0, 1.0 + pan)
        
        Sound.robotPlayer.setVolume(rLeftVol, rRightVol)
        
        if Build.VERSION.SDK_INT >= 23 then
          local robotPitchFactor = 0.7 + (currentRobotCalculatedSpeed * 0.8)
          local rParams = PlaybackParams()
          rParams.setPitch(robotPitchFactor)
          rParams.setSpeed(robotPitchFactor)
          Sound.robotPlayer.setPlaybackParams(rParams)
        end
      end
    else
      if Sound.robotPlayer and Sound.robotPlayer.isPlaying() then Sound.robotPlayer.pause() end
    end
  end)
end

function Sound.stopAllAudio()
  for key, runnable in pairs(Sound.activeLoopers) do mainHandler.removeCallbacks(runnable) end
  Sound.activeLoopers = {}
  
  Sound.stopThunderstormAudio()
  Sound.stopWindyAudio()

  pcall(function()
    if Sound.racingPlayer then
      pcall(function() Sound.racingPlayer.stop() Sound.racingPlayer.release() end)
      Sound.racingPlayer = nil
    end
    if Sound.robotPlayer then
      pcall(function() Sound.robotPlayer.stop() Sound.robotPlayer.release() end)
      Sound.robotPlayer = nil
    end
    if Sound.bgPlayer then
      pcall(function() Sound.bgPlayer.stop() Sound.bgPlayer.release() end)
      Sound.bgPlayer = nil
    end
    if Sound.menuPlayer then
      pcall(function() Sound.menuPlayer.stop() Sound.menuPlayer.release() end)
      Sound.menuPlayer = nil
    end
  end)
end

return Sound