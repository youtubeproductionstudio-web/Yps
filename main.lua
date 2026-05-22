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
local beggarMyNeighborModule = require "beggar_my_neighbor" -- Game logic yahan include ki gayi hai
local storeModule = require "store" -- Store module acquire kiya gaya hai

activity.getActionBar().hide()
math.randomseed(os.time())

prefs = activity.getSharedPreferences("userdata", 0)
editor = prefs.edit()

local adWatchCount = prefs.getInt("adWatchCount", 0)
local adResetTime = prefs.getLong("adResetTime", os.time())
-- FIXED: Changed putBoolean to getBoolean for reading data
local disclaimerAccepted = prefs.getBoolean("disclaimerAccepted", false)

local function saveAdPreferences()
    editor.putInt("adWatchCount", adWatchCount)
    editor.putLong("adResetTime", adResetTime)
    editor.putBoolean("disclaimerAccepted", prefs.getBoolean("disclaimerAccepted", false))
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

timerHandler = Handler(Looper.getMainLooper())
isAdScreenShowing = false
local currentMainLayoutView = nil
local isOpeningAd = false

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

local clickSound = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/click.mp3"
local cardPlaySound = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/Play Card.mp3"
local shuffleSound = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/card_shuffle.mp3"
local winSound = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/Vin sound.mp3"
local loseSound = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/laugh4.mp3"
local bgm1Path = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/BGM.ogg"
local bgm2Path = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/BGM 2.ogg"
local bgm3Path = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/BGM 3.ogg"
local bgm4Path = "/storage/emulated/0/解说/Tools/Card games version 1.1. /sounds/BGM 4.ogg"

bgmPlayer = nil
currentBgmPath = ""
local wasPlayingBeforePause = false
isTransitioning = false
isProfileShowing = false
isStoreShowing = false
isGameActive = false

function getVol(key)
  return prefs.getInt("vol_"..key, 50) / 100
end

function playBGM(path)
  local key = ""
  if path == bgm1Path then key="bgm1" elseif path == bgm2Path then key="bgm2" 
  elseif path == bgm3Path then key="bgm3" elseif path == bgm4Path then key="bgm4" end
  
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
  if tts then tts.shutdown() end
end

function playSound(path)
  local key = ""
  if path == clickSound then key="click" elseif path == cardPlaySound then key="play"
  elseif path == shuffleSound then key="shuffle" elseif path == winSound then key="win"
  elseif path == loseSound then key="lose" end
  
  if not prefs.getBoolean("sw_"..key, true) then return end

  pcall(function()
    local mp = MediaPlayer()
    mp.setDataSource(path)
    mp.prepare()
    local v = getVol(key)
    mp.setVolume(v, v)
    mp.start()
    mp.setOnCompletionListener(MediaPlayer.OnCompletionListener{
      onCompletion=function(v) v.release() end
    })
  end)
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
    elseif isGameActive then 
      showQuitGameDialog() 
    else 
      showExitDialog() 
    end
    return true
  end
  return false
end

function showExitDialog()
  AlertDialog.Builder(activity)
    .setTitle("Exit")
    .setMessage("Are you really want to exit?")
    .setPositiveButton("Yes",{onClick=function() 
      stopBGM()
      activity.finish() 
    end})
    .setNegativeButton("No",nil)
    .show()
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

local tts
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

-- Yahan Beggar My Neighbor ka wrapper lagaya gaya hai jo required dependencies naye module mein bhejta hai
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

local function generateRandomUserID(length)
  local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local t = {}
  for i = 1, length do
    local r = math.random(1, #chars)
    table.insert(t, chars:sub(r, r))
  end
  return table.concat(t)
end

local function sendDataToServer(username, userId)
  local serverSaved = true
  return serverSaved
end

local function showUserIdDialog(generatedId, username)
  local dlgLayout = {
    LinearLayout,
    orientation = "vertical",
    background = "#000000",
    padding = "24dp",
    gravity = "center",
    layout_width = "fill",
    {
      TextView,
      id = "titleTxt",
      text = "User ID Generated",
      textSize = "20sp",
      textColor = "#FFD700",
      gravity = "center",
      layout_marginBottom = "14dp"
    },
    {
      TextView,
      id = "idTxt",
      text = "Your ID: " .. generatedId,
      textSize = "16sp",
      textColor = "#FFFFFF",
      gravity = "center",
      layout_marginBottom = "24dp"
    },
    {
      Button,
      id = "collectBtn",
      text = "Collect",
      layout_width = "180dp",
      layout_height = "wrap"
    }
  }

  local builder = AlertDialog.Builder(activity)
  local view = loadlayout(dlgLayout)
  titleTxt.setTypeface(Typeface.DEFAULT_BOLD)
  styleButton(collectBtn)
  builder.setView(view)
  builder.setCancelable(false)
  local idDialog = builder.create()
  idDialog.show()

  wrapClick(collectBtn, function()
    local synchronized = sendDataToServer(username, generatedId)
    if synchronized then
      editor.putString("userid", generatedId)
      editor.putString("username", username)
      editor.putBoolean("first_run", false)
      editor.apply()
      idDialog.dismiss()
      Toast.makeText(activity, "Saved successfully", Toast.LENGTH_SHORT).show()
      mainUI()
    else
      Toast.makeText(activity, "Server sync failed. Please try again.", Toast.LENGTH_SHORT).show()
    end
  end)
end

function usernameScreen()
  isGameActive = false
  isTransitioning = false
  local layout={ LinearLayout, orientation="vertical", background="#000000", gravity="center", padding="16dp", {TextView,id="txt",text="Enter your username",gravity="center",textSize="18sp",layout_marginBottom="10dp"}, {EditText,id="nameInput",hint="Enter your username",textColor="#FFFFFF",hintTextColor="#AAAAAA",layout_width="fill",singleLine=true}, {LinearLayout, orientation="horizontal", layout_marginTop="20dp", {Button,id="cancelBtn",text="Cancel",layout_width="0dp",layout_weight="1"}, {Button,id="saveBtn",text="Save",layout_width="0dp",layout_weight="1"} } }
  activity.setContentView(loadlayout(layout))
  whiteText(txt); styleButton(cancelBtn); styleButton(saveBtn)
  nameInput.setText(prefs.getString("username", ""))
  
  wrapClick(cancelBtn, function()
    if prefs.getBoolean("first_run", true) then
      welcome2()
    else
      mainUI()
    end
  end)
  
  wrapClick(saveBtn, function()
    local raw_uname = tostring(nameInput.getText())
    local uname = raw_uname:gsub("^%s*(.-)%s*$", "%1")
    if uname == "" then Toast.makeText(activity, "You have not entered any username yet", Toast.LENGTH_SHORT).show(); return end
    if not uname:match("^[a-zA-Z0-9_]+$") then AlertDialog.Builder(activity).setTitle("Invalid Username").setMessage("Sirf letters, numbers aur underscore (_) allowed hain.").setPositiveButton("OK", nil).show(); return end
    
    if prefs.getBoolean("first_run", true) or not prefs.contains("username") then
      local newId = generateRandomUserID(10)
      showUserIdDialog(newId, uname)
    else
      editor.putString("username", uname)
      editor.putBoolean("first_run", false)
      editor.apply()
      Toast.makeText(activity, "Saved successfully", Toast.LENGTH_SHORT).show()
      mainUI()
    end
  end)
end

function welcome2()
  isGameActive = false
  isTransitioning = false
  local layout={ LinearLayout, orientation="vertical", background="#000000", gravity="center", layout_width="fill", layout_height="fill", {TextView,id="t2",text="This tool is developed by Muzammil Muneer",gravity="center",textSize="18sp"}, {Space, layout_height="20dp"}, {Button,id="n2",text="Next",layout_width="200dp"} }
  activity.setContentView(loadlayout(layout))
  whiteText(t2); styleButton(n2)
  wrapClick(n2, function() usernameScreen() end)
end

function welcome1()
  isGameActive = false
  isTransitioning = false
  playBGM(bgm1Path) 
  local layout={ LinearLayout, orientation="vertical", background="#000000", gravity="center", layout_width="fill", layout_height="fill", {TextView,id="t1",text="Welcome to Card Games",gravity="center",textSize="22sp"}, {Space, layout_height="10dp"}, {TextView,id="t1sub",text="This tool is specially designed for visually impaired persons. Here you will find various types of card games to play and enjoy...",gravity="center",textSize="16sp",layout_marginLeft="20dp",layout_marginRight="20dp"}, {Space, layout_height="20dp"}, {Button,id="n1",text="Next",layout_width="200dp"} }
  activity.setContentView(loadlayout(layout))
  whiteText(t1); whiteText(t1sub); styleButton(n1)
  wrapClick(n1, function() welcome2() end)
end

function mainUI()
  isGameActive = false
  isTransitioning = false 
  isProfileShowing = false
  isStoreShowing = false
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
      {TextView,id="title",text="Card Games",textSize="28sp"},
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
      {Button,id="storeBtn",text="Store",layout_width="fill",layout_marginBottom="15dp"}, -- Store button add kiya gaya
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

  wrapClick(profileBtn, function()
    -- FIXED: changed from profileUI() to profile.profileUI() to properly call the module
    profile.profileUI()
  end)

  wrapClick(storeBtn, function()
      storeModule.show({
          activity = activity,
          prefs = prefs,
          editor = editor,
          mainUI = mainUI,
          wrapClick = wrapClick,
          styleButton = styleButton,
          whiteText = whiteText
      })
  end)

  wrapClick(moreOptionsBtn, function()
      moreOptionsModule.show(
          activity, 
          mainUI, 
          usernameScreen, 
          prefs, 
          editor, 
          saveAdPreferences, 
          canShowAd, 
          getRandomTime, 
          getAdConfig, 
          configureWebView, 
          playSound, 
          clickSound, 
          currentMainLayoutView, 
          timerHandler
      )
  end)

  wrapClick(aboutBtn, function()
    aboutModule.show(activity, bgm1Path, bgm2Path)
  end)

  wrapClick(creditsBtn, function()
    creditsModule.show(activity, bgm1Path, bgm2Path)
  end)

  wrapClick(gamesMenuBtn, function()
      gamesMenuModule.show({
          activity = activity,
          mainUI = mainUI,
          gameMainUI = gameMainUI,
          playBGM = playBGM,
          wrapClick = wrapClick,
          styleButton = styleButton,
          whiteText = whiteText,
          bgm2Path = bgm2Path,
          bgm3Path = bgm3Path,
          bgm4Path = bgm4Path
      })
  end)

  wrapClick(publicChatBtn, function()
      local chatKeys = prefs.getInt("public_chat_keys", 0)
      if chatKeys > 0 then
          -- Key ko consume karke profile update ki ja rahi hai
          editor.putInt("public_chat_keys", chatKeys - 1).apply()
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
      else
          AlertDialog.Builder(activity)
              .setTitle("Key Required")
              .setMessage("You need a Public Chat Key to open Public Chat. Please buy it from the Store.")
              .setPositiveButton("Go to Store", {onClick=function()
                  storeModule.show({
                      activity = activity,
                      prefs = prefs,
                      editor = editor,
                      mainUI = mainUI,
                      wrapClick = wrapClick,
                      styleButton = styleButton,
                      whiteText = whiteText
                  })
              end})
              .setNegativeButton("Cancel", nil)
              .show()
      end
  end)

  wrapClick(exitBtn, function() showExitDialog() end)
end

-- NEW FUNCTION: Sif update system isko direct call karega jab update check complete ho jayegi
function startAppUiFlow()
  if prefs.getBoolean("first_run", true) or not prefs.contains("username") then
    editor.putBoolean("first_run", true).apply()
    welcome1()
  else
    mainUI()
  end
end

local update = require "update"
