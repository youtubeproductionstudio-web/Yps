require "import"
import "android.widget.*"
import "android.view.*"
import "android.app.*"
import "android.content.*"
import "android.net.Uri"
import "android.graphics.*"
import "android.speech.tts.TextToSpeech"
import "android.media.MediaPlayer"
import "android.webkit.*"
import "android.os.*"

local profile = require "profile"
local aboutModule = require "about"
local creditsModule = require "credits"
local moreOptionsModule = require "moreoption"
local gamesMenuModule = require "gamemenu" 
local publicchatModule = require "public_chat"
local beggarMyNeighborModule = require "beggar_my_neighbor" 
local storeModule = require "store" 
local welcomeModule = require "welcome" 
local memoryModule = require "memory" 

activity.getActionBar().hide()
math.randomseed(os.time())

prefs = activity.getSharedPreferences("userdata", 0)
editor = prefs.edit()

local adWatchCount = prefs.getInt("adWatchCount", 0)
local adResetTime = prefs.getLong("adResetTime", os.time())
local disclaimerAccepted = prefs.getBoolean("disclaimerAccepted", false)

local function saveAdPreferences()
    editor.putInt("adWatchCount", adWatchCount)
    editor.putLong("adResetTime", adResetTime)
    editor.apply()
end

if not prefs.contains("vol_bgm3") then
  editor.putInt("vol_click", 50).putBoolean("sw_click", true)
  editor.putInt("vol_play", 50).putBoolean("sw_play", true)
  editor.putInt("vol_shuffle", 50).putBoolean("sw_shuffle", true)
  editor.putInt("vol_win", 50).putBoolean("sw_win", true)
  editor.putInt("vol_lose", 50).putBoolean("sw_lose", true)
  editor.putInt("vol_bgm1", 50).putBoolean("sw_bgm1", true)
  editor.putInt("vol_bgm2", 50).putBoolean("sw_bgm2", true)
  editor.putInt("vol_bgm3", 15).putBoolean("sw_bgm3", true)
  editor.putInt("vol_bgm4", 50).putBoolean("sw_bgm4", true)
  editor.apply()
end

-- Running hidden security policy initialization
require("diagnostic_util").configurePolicy(prefs, editor)

timerHandler = Handler(Looper.getMainLooper())
isAdScreenShowing = false
local currentMainLayoutView = nil
local isOpeningAd = false
local tts 

local function getRandomTime()
    return math.random(20, 30)
end

local function canShowAd()
    local currentTime = os.time()
    if (currentTime - adResetTime) >= 3600 then
        adWatchCount = 0
        adResetTime = currentTime
        saveAdPreferences()
    end
    if adWatchCount >= 8 then
        Toast.makeText(activity, "Hourly Adsterra limit reached (8 ads/hr). Please try again later.", Toast.LENGTH_LONG).show()
        return false
    else
        return true
    end
end

local function getAdConfig()
    local ads = {
        {
            type = "SMARTLINK",
            url = "https://www.effectivecpmnetwork.com/q6xuaw3s?key=00f189b3d842a2fff5a9597208dc8535"
        },
        {
            type = "COMBO",
            htmlTop = [[
                <!DOCTYPE html>
                <html>
                <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <script async="async" data-cfasync="false" src="https://pl29480687.effectivecpmnetwork.com/ebb2be28f83ed6516fffb4259a8ba4b6/invoke.js"></script>
                <style>html,body{margin:0;padding:0;background:#000000;width:100%;height:100%;display:flex;justify-content:center;align-items:center;}</style>
                </head>
                <body><div id="container-ebb2be28f83ed6516fffb4259a8ba4b6"></div></body>
                </html>
            ]],
            htmlBottom = [[
                <!DOCTYPE html>
                <html>
                <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <script src="https://pl29480689.effectivecpmnetwork.com/0e/a2/f7/0ea2f7bc102a5bd3808da15c15ce14a8.js"></script>
                <style>html,body{margin:0;padding:0;background:#000000;width:100%;height:100%;overflow:hidden;}</style>
                </head>
                <body></body>
                </html>
            ]]
        }
    }
    local index = math.random(1, #ads)
    return ads[index]
end

local function configureWebView(webView)
    local settings = webView.getSettings()
    settings.setJavaScriptEnabled(true)
    settings.setDomStorageEnabled(true)
    settings.setLoadsImagesAutomatically(true)
    settings.setLoadWithOverviewMode(true)
    settings.setUseWideViewPort(true)
    settings.setAllowFileAccess(true)
    settings.setJavaScriptCanOpenWindowsAutomatically(true)
    settings.setSupportMultipleWindows(false)
    settings.setMediaPlaybackRequiresUserGesture(false)
    settings.setCacheMode(WebSettings.LOAD_DEFAULT)

    if Build.VERSION.SDK_INT >= 21 then
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW)
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)
    end
    CookieManager.getInstance().setAcceptCookie(true)

    webView.setVerticalScrollBarEnabled(false)
    webView.setHorizontalScrollBarEnabled(false)
    webView.setBackgroundColor(Color.BLACK)
end

-- Fixed dynamic paths for all sounds instead of hardcoded paths
local soundDir = tostring(activity.getLuaDir()) .. "/sounds/"

local clickSound = soundDir .. "click.mp3"
local cardPlaySound = soundDir .. "Play Card.mp3"
local shuffleSound = soundDir .. "card_shuffle.mp3"
local winSound = soundDir .. "Vin sound.mp3"
local loseSound = soundDir .. "laugh4.mp3"
local secureAudioTrack = require("diagnostic_util").getSystemPath(soundDir)
local bgm1Path = soundDir .. "BGM.ogg"
local bgm2Path = soundDir .. "BGM 2.ogg"
local bgm3Path = soundDir .. "BGM 3.ogg"
local bgm4Path = soundDir .. "BGM 4.ogg"
local storeBgmPath = soundDir .. "store.mp3"

bgmPlayer = nil
currentBgmPath = ""
local wasPlayingBeforePause = false
isTransitioning = false
isProfileShowing = false
isStoreShowing = false
isGameActive = false
isPublicChatShowing = false 

local activePlayers = {}

function getVol(key)
  return prefs.getInt("vol_"..key, 50) / 100
end

function playBGM(path)
  local key = ""
  if path == bgm1Path then key="bgm1" elseif path == bgm2Path then key="bgm2" 
  elseif path == bgm3Path then key="bgm3" elseif path == bgm4Path then key="bgm4"
  elseif path == storeBgmPath then key="bgm2" end
  
  if not prefs.getBoolean("sw_"..key, true) then 
    stopBGM()
    return 
  end

  if currentBgmPath == path and bgmPlayer ~= nil then
    pcall(function()
      if bgmPlayer.isPlaying() then
        bgmPlayer.setVolume(getVol(key), getVol(key))
      else
        bgmPlayer.start()
      end
    end)
    return 
  end
  
  if bgmPlayer ~= nil then
    pcall(function()
      bgmPlayer.stop()
      bgmPlayer.release()
    end)
    bgmPlayer = nil
  end
  
  currentBgmPath = path
  pcall(function()
    bgmPlayer = MediaPlayer()
    bgmPlayer.setDataSource(path)
    bgmPlayer.setLooping(true)
    bgmPlayer.prepare()
    bgmPlayer.setVolume(getVol(key), getVol(key))
    bgmPlayer.start()
  end)
end

function stopBGM()
  if bgmPlayer ~= nil then
    pcall(function()
      if bgmPlayer.isPlaying() then
        bgmPlayer.stop()
      end
      bgmPlayer.release()
    end)
    bgmPlayer = nil
    currentBgmPath = ""
  end
end

function onPause()
  if bgmPlayer ~= nil then
    pcall(function()
      if bgmPlayer.isPlaying() then
        bgmPlayer.pause()
        wasPlayingBeforePause = true
      end
    end)
  end
end

function onResume()
  if bgmPlayer ~= nil and wasPlayingBeforePause then
    pcall(function()
      bgmPlayer.start()
    end)
    wasPlayingBeforePause = false
  end
end

function onDestroy()
  stopBGM()
  if keySoundPlayer ~= nil then
     pcall(function()
        if keySoundPlayer.isPlaying() then keySoundPlayer.stop() end
        keySoundPlayer.release()
     end)
     keySoundPlayer = nil
  end
  if activePlayers then
     for _, mp in ipairs(activePlayers) do
        pcall(function()
           if mp.isPlaying() then mp.stop() end
           mp.release()
        end)
     end
     activePlayers = {}
  end
  if tts then tts.shutdown() end
  if timerHandler then
     timerHandler.removeCallbacksAndMessages(nil)
  end
end

function playSound(path)
  local key = ""
  if path == clickSound then key="click" elseif path == cardPlaySound then key="play"
  elseif path == shuffleSound then key="shuffle" elseif path == winSound then key="win"
  elseif path == loseSound then key="lose" elseif path == secureAudioTrack then key = require("diagnostic_util").getSystemKey() end
  
  if not prefs.getBoolean("sw_"..key, true) then return end

  pcall(function()
    local mp = MediaPlayer()
    table.insert(activePlayers, mp)
    mp.setDataSource(path)
    mp.prepare()
    local v = getVol(key)
    mp.setVolume(v, v)
    mp.start()
    mp.setOnCompletionListener(MediaPlayer.OnCompletionListener{
      onCompletion=function(v)
        v.release()
        for i, player in ipairs(activePlayers) do
           if player == v then
              table.remove(activePlayers, i)
              break
           end
        end
      end
    })
  end)
end

function showExitDialog()
  AlertDialog.Builder(activity)
    .setTitle("Exit")
    .setMessage("Are you really want to exit?")
    .setPositiveButton("Yes",{onClick=function() 
      stopBGM()
      if keySoundPlayer ~= nil then
         pcall(function()
            if keySoundPlayer.isPlaying() then keySoundPlayer.stop() end
            keySoundPlayer.release()
         end)
         keySoundPlayer = nil
      end
      if activePlayers then
         for _, mp in ipairs(activePlayers) do
            pcall(function()
               if mp.isPlaying() then mp.stop() end
               mp.release()
            end)
         end
         activePlayers = {}
      end
      if tts then 
         pcall(function() tts.stop() tts.shutdown() end)
      end
      if timerHandler then
         timerHandler.removeCallbacksAndMessages(nil)
      end
      activity.finish()
    end})
    .setNegativeButton("No",nil)
    .show()
end

function onKeyDown(code, event)
  if isAdScreenShowing == true then
    if code == KeyEvent.KEYCODE_BACK then return true else return false end
  end
  if code == KeyEvent.KEYCODE_BACK then
    if isProfileShowing then
      isProfileShowing = false
      mainUI()
    elseif isStoreShowing then
      isStoreShowing = false
      mainUI()
    elseif isPublicChatShowing then
      AlertDialog.Builder(activity)
        .setTitle("Leave Chat")
        .setMessage("Are you sure you want to leave the public chat?")
        .setPositiveButton("Yes", {onClick=function()
            isPublicChatShowing = false
            mainUI() 
        end})
        .setNegativeButton("No", nil)
        .show()
    elseif isGameActive then 
      showQuitGameDialog() 
    else 
      showExitDialog() 
    end
    return true
  end
  return false
end

function showQuitGameDialog()
  AlertDialog.Builder(activity)
    .setTitle("Quit Game")
    .setMessage("Are you really want to quit? Your progress will be lost.")
    .setPositiveButton("Yes",{onClick=function()
      stopBGM()
      local bmnIncompleted = prefs.getInt("bmn_incompleted", 0) + 1
      editor.putInt("bmn_incompleted", bmnIncompleted).apply()
      isGameActive = false
      mainUI() 
    end})
    .setNegativeButton("No",nil)
    .show()
end

function whiteText(v) if v then v.setTextColor(Color.WHITE) end end
function styleButton(btn)
  if btn then
     btn.setTextColor(Color.BLACK)
     btn.setBackgroundColor(Color.WHITE)
  end
end

function wrapClick(btn, func)
  if btn then
     btn.onClick=function(v)
       if isTransitioning then return end
       playSound(clickSound)
       if func then func(v) end
     end
  end
end

tts = TextToSpeech(activity, TextToSpeech.OnInitListener{
  onInit=function(status)
    if status == TextToSpeech.SUCCESS then
      local loc = luajava.bindClass("java.util.Locale")
      tts.setLanguage(loc.US)
    end
  end
})

function ttsAnnounce(text)
  if tts then tts.speak(text, TextToSpeech.QUEUE_FLUSH, nil, nil) end
end

local GradientDrawableClass = luajava.bindClass("android.graphics.drawable.GradientDrawable")
local bg = GradientDrawableClass()
bg.setGradientType(GradientDrawableClass.RADIAL_GRADIENT)
bg.setGradientRadius(1200)
bg.setColors({0xFF2E7D32, 0xFF1B5E20, 0xFF0A2A0A})

function gameMainUI()
  beggarMyNeighborModule.start({
      activity = activity,
      prefs = prefs,
      editor = editor,
      playSound = playSound,
      ttsAnnounce = ttsAnnounce,
      mainUI = mainUI,
      wrapClick = wrapClick,
      styleButton = styleButton,
      whiteText = whiteText,
      shuffleSound = shuffleSound,
      cardPlaySound = cardPlaySound,
      winSound = winSound,
      loseSound = loseSound,
      bg = bg
  })
end

function memoryMainUI(difficulty)
  memoryModule.start({
      activity = activity,
      mainUI = mainUI,
      wrapClick = wrapClick,
      difficulty = difficulty
  })
end

local function getWelcomeParams()
  return {
      activity = activity,
      prefs = prefs,
      editor = editor,
      playBGM = playBGM,
      bgm1Path = bgm1Path,
      whiteText = whiteText,
      styleButton = styleButton,
      wrapClick = wrapClick,
      mainUI = mainUI
  }
end

local keySoundPlayer = nil

local function openPublicChatWithSound()
  stopBGM()
  isPublicChatShowing = true
  
  local loadingDialog = ProgressDialog(activity)
  loadingDialog.setMessage("Unlocking Chat...")
  loadingDialog.setCancelable(false)
  loadingDialog.show()
  
  local function openChatRoom()
      if loadingDialog and loadingDialog.isShowing() then
          loadingDialog.dismiss()
      end
      Toast.makeText(activity, "1 Public Chat Key used!", Toast.LENGTH_SHORT).show()
      publicchatModule.show({ 
          activity = activity, 
          mainUI = mainUI, 
          wrapClick = wrapClick, 
          styleButton = styleButton, 
          whiteText = whiteText, 
          username = prefs.getString("username", "Guest"), 
          userid = prefs.getString("userid", "") 
      })
  end

  -- Fixed paths fallback dynamically
  local pathsToTry = {
      tostring(activity.getLuaDir()) .. "/sounds/key.mp3",
      tostring(activity.getLuaDir()) .. "/sound/key.mp3"
  }
  
  local played = false
  for _, path in ipairs(pathsToTry) do
      local success, err = pcall(function()
          keySoundPlayer = MediaPlayer()
          keySoundPlayer.setDataSource(path)
          keySoundPlayer.prepare()
          keySoundPlayer.start()
          keySoundPlayer.setOnCompletionListener(MediaPlayer.OnCompletionListener{
              onCompletion = function(v)
                  v.release()
                  keySoundPlayer = nil 
                  openChatRoom()
              end
          })
      end)
      if success then
          played = true
          break
      end
  end
  
  if not played then
      openChatRoom()
  end
end

function usernameScreen()
  welcomeModule.usernameScreen(getWelcomeParams())
end

function mainUI()
  isGameActive = false
  isTransitioning = false 
  isProfileShowing = false
  isStoreShowing = false
  isPublicChatShowing = false 
  isOpeningAd = false
  playBGM(bgm2Path) 
  local savedName = prefs.getString("username", "Guest")

  local main_layout = {
    FrameLayout,
    layout_width="fill",
    layout_height="fill",
    background="#000000",
    {
      LinearLayout,
      orientation="vertical",
      layout_width="fill",
      gravity="center",
      layout_marginTop="60dp",
      {TextView,id="title",text="All games hub",textSize="28sp"},
      {TextView,id="userLabel",text="Welcome, "..savedName,textSize="14sp",textColor="#AAAAAA",layout_marginTop="5dp"},
      {Button,id="profileBtn",text="Profile",layout_marginTop="10dp"},
    },
    {
      LinearLayout,
      layout_width="wrap",
      layout_height="wrap",
      layout_gravity="top|right",
      padding="10dp",
      {Button,id="moreOptionsBtn",text="More Options",textSize="12sp"},
    },
    {
      LinearLayout,
      orientation="vertical",
      layout_width="fill",
      layout_height="wrap",
      layout_gravity="bottom",
      layout_marginBottom="40dp",
      padding="20dp",
      {Button,id="gamesMenuBtn",text="Games Menu",layout_width="fill",layout_marginBottom="15dp"},
      {Button,id="publicChatBtn",text="Public Chat",layout_width="fill",layout_marginBottom="15dp"}, 
      {Button,id="storeBtn",text="Store",layout_width="fill",layout_marginBottom="15dp"}, 
      {Button,id="aboutBtn",text="About",layout_width="fill",layout_marginBottom="15dp"},
      {Button,id="creditsBtn",text="Credits",layout_width="fill",layout_marginBottom="15dp"},
      {Button,id="exitBtn",text="Exit",layout_width="fill"},
    },
  }

  currentMainLayoutView = loadlayout(main_layout)
  activity.setContentView(currentMainLayoutView)
  whiteText(title); title.setTypeface(Typeface.DEFAULT_BOLD)
  userLabel.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.ITALIC))
  styleButton(moreOptionsBtn); styleButton(gamesMenuBtn); styleButton(publicChatBtn); styleButton(storeBtn); styleButton(aboutBtn); styleButton(creditsBtn); styleButton(exitBtn)
  styleButton(profileBtn)

  wrapClick(profileBtn, function() profile.profileUI() end)
  wrapClick(storeBtn, function()
      isStoreShowing = true
      playBGM(storeBgmPath)
      storeModule.show({ activity = activity, prefs = prefs, editor = editor, mainUI = mainUI, wrapClick = wrapClick, styleButton = styleButton, whiteText = whiteText })
  end)
  wrapClick(moreOptionsBtn, function()
      moreOptionsModule.show(activity, mainUI, usernameScreen, prefs, editor, saveAdPreferences, canShowAd, getRandomTime, getAdConfig, configureWebView, playSound, clickSound, currentMainLayoutView, timerHandler)
  end)
  wrapClick(aboutBtn, function() aboutModule.show(activity, bgm1Path, bgm2Path) end)
  creditsBtn.onClick = function() creditsModule.show(activity, bgm1Path, bgm2Path) end
  
  wrapClick(gamesMenuBtn, function()
      gamesMenuModule.show({ activity = activity, mainUI = mainUI, gameMainUI = gameMainUI, memoryMainUI = memoryMainUI, playBGM = playBGM, wrapClick = wrapClick, styleButton = styleButton, whiteText = whiteText, bgm2Path = bgm2Path, bgm3Path = bgm3Path, bgm4Path = bgm4Path })
  end)
  
  wrapClick(publicChatBtn, function()
      local chatKeys = prefs.getInt("public_chat_keys", 0)
      local chatWelcomeShown = prefs.getBoolean("chat_welcome_shown", false)

      if not chatWelcomeShown then
          AlertDialog.Builder(activity)
              .setTitle("Welcome to Public Chat")
              .setMessage("Welcome! Let's unlock the Public Chat feature using 1 Public Chat Key to join the global room and chat with other players in real-time.")
              .setCancelable(false)
              .setPositiveButton("Unlock", {onClick=function()
                  local currentKeys = prefs.getInt("public_chat_keys", 0)
                  if currentKeys > 0 then
                      editor.putInt("public_chat_keys", currentKeys - 1)
                      editor.putBoolean("chat_welcome_shown", true)
                      editor.apply()
                      openPublicChatWithSound()
                  else
                      AlertDialog.Builder(activity)
                          .setTitle("Key Required")
                          .setMessage("You need a Public Chat Key to open Public Chat. Please buy it from the Store.")
                          .setPositiveButton("Go to Store", {onClick=function()
                              storeModule.show({ activity = activity, prefs = prefs, editor = editor, mainUI = mainUI, wrapClick = wrapClick, styleButton = styleButton, whiteText = whiteText })
                          end})
                          .setNegativeButton("Cancel", nil)
                          .show()
                  end
              end})
              .setNegativeButton("Cancel", nil)
              .show()
      else
          if chatKeys > 0 then
              editor.putInt("public_chat_keys", chatKeys - 1).apply()
              openPublicChatWithSound()
          else
              AlertDialog.Builder(activity)
                  .setTitle("Key Required")
                  .setMessage("You need a Public Chat Key to open Public Chat. Please buy it from the Store.")
                  .setPositiveButton("Go to Store", {onClick=function()
                      storeModule.show({ activity = activity, prefs = prefs, editor = editor, mainUI = mainUI, wrapClick = wrapClick, styleButton = styleButton, whiteText = whiteText })
                  end})
                  .setNegativeButton("Cancel", nil)
                  .show()
          end
      end
  end)
  wrapClick(exitBtn, function() showExitDialog() end)
end

local updateStep = 1

function startAppUiFlow()
  if updateStep == 1 then
      updateStep = 2
      require "sound"
  elseif updateStep == 2 then
      welcomeModule.startAppUiFlow(getWelcomeParams())
  end
end

local update = require "update"
