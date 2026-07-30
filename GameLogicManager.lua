local GameLogicManager = {}

-- Load Game Modules (Cached by Lua)
local bmnModule = require("beggar_my_neighbor")
local memoryModule = require("memory")
local affModule = require("mode_1vs5")

-- Localize global functions for faster access
local type = type
local pcall = pcall
local string_lower = string.lower
local string_find = string.find
local tonumber = tonumber

local function safeGetActivity(viewport, context)
    if context and context.activity then return context.activity end
    if _G.activity then return _G.activity end
    if type(viewport) == "userdata" and viewport.getContext then
        return viewport.getContext()
    end
    return nil
end

-- OPTIMIZED: Native Lua tables are checked first, expensive pcalls (Java bounds) are checked last
local function resolveDependency(key, context, act)
    if context then
        if context[key] ~= nil then return context[key] end
        if context.audio and context.audio[key] ~= nil then return context.audio[key] end
        if context.sound and context.sound[key] ~= nil then return context.sound[key] end
        if context.gameConfig and context.gameConfig[key] ~= nil then return context.gameConfig[key] end
        if context.parent and context.parent[key] ~= nil then return context.parent[key] end
        if context.env and context.env[key] ~= nil then return context.env[key] end
    end
    
    if _G[key] ~= nil then return _G[key] end
    if _G.audio and _G.audio[key] ~= nil then return _G.audio[key] end
    if _G.sound and _G.sound[key] ~= nil then return _G.sound[key] end
    if _G.env and _G.env[key] ~= nil then return _G.env[key] end
    if _G.shared and _G.shared[key] ~= nil then return _G.shared[key] end

    if act then
        local ok, val = pcall(function() return act[key] end)
        if ok and val ~= nil then return val end
        ok, val = pcall(function() return act.get(key) end)
        if ok and val ~= nil then return val end
    end
    
    return nil
end

local function showLoading(act, title, message)
    if act then
        import "android.app.ProgressDialog"
        local pd = ProgressDialog(act)
        pd.setTitle(title or "Loading")
        pd.setMessage(message or "Please wait...")
        pd.setCancelable(false)
        pd.show()
        return pd
    end
    return nil
end

-- Helper function to avoid repetition
local function triggerOnGameReady(context, viewport)
    local gc = context.gameConfig
    if gc and gc.onGameReady then
        gc.onGameReady({
            viewport = viewport,
            role = context.role,
            username = context.username,
            syncAction = context.syncAction
        })
    end
end

local function runBeggarmynaighbor(context, pd, act)
    triggerOnGameReady(context, context.viewport)
    
    local prefs = act and act.getSharedPreferences("userdata", 0) or nil
    
    local dependencies = {
        activity = act,
        prefs = prefs,
        editor = prefs and prefs.edit() or nil,
        mainUI = resolveDependency("mainUI", context, act),
        playSound = resolveDependency("playSound", context, act),
        playBGM = resolveDependency("playBGM", context, act),
        winSound = resolveDependency("winSound", context, act),
        loseSound = resolveDependency("loseSound", context, act),
        shuffleSound = resolveDependency("shuffleSound", context, act),
        cardPlaySound = resolveDependency("cardPlaySound", context, act),
        bg = resolveDependency("bg", context, act),
        wrapClick = resolveDependency("wrapClick", context, act),
        styleButton = resolveDependency("styleButton", context, act)
    }
    
    context.opponentName = context.opponentName or "Opponent"
    bmnModule.startOnline(dependencies, context)
    
    if pd then pd.dismiss() end
end

local function runGameTwoLogic(context, pd, act)
    triggerOnGameReady(context, context.viewport)
    
    local params = {
        activity = act,
        mainUI = resolveDependency("mainUI", context, act),
        difficulty = context.difficulty or "Medium",
        playSound = resolveDependency("playSound", context, act),
        playBGM = resolveDependency("playBGM", context, act),
        winSound = resolveDependency("winSound", context, act),
        loseSound = resolveDependency("loseSound", context, act),
        shuffleSound = resolveDependency("shuffleSound", context, act),
        cardPlaySound = resolveDependency("cardPlaySound", context, act),
        bg = resolveDependency("bg", context, act),
        wrapClick = resolveDependency("wrapClick", context, act),
        styleButton = resolveDependency("styleButton", context, act)
    }
    
    context.opponentName = context.opponentName or "Opponent"
    memoryModule.startOnline(params, context)
    
    if pd then pd.dismiss() end
end

local function runGameThreeLogic(context, pd, act)
    if pd then pd.dismiss() end
end

local function runAudioFreeFireLogic(context, pd, act)
    triggerOnGameReady(context, context.viewport)

    -- [100% HEALTH FIX]
    local rawHealth = context.gameHealth or context.health or context.playerHealth or context.myHealth
    
    if not rawHealth and context.roomSnapshot then
        local ok, snapHealth = pcall(function() return context.roomSnapshot.optString("gameHealthConfig") end)
        if ok and snapHealth ~= "" then
            rawHealth = snapHealth
        end
    end

    local passedHealth = tonumber(rawHealth) or 100
    context.health = passedHealth
    context.gameHealth = passedHealth

    local params = {
        activity = act,
        health = passedHealth,
        mainUI = resolveDependency("mainUI", context, act),
        playSound = resolveDependency("playSound", context, act),
        playBGM = resolveDependency("playBGM", context, act),
        winSound = resolveDependency("winSound", context, act),
        loseSound = resolveDependency("loseSound", context, act),
        wrapClick = resolveDependency("wrapClick", context, act),
        styleButton = resolveDependency("styleButton", context, act)
    }

    context.opponentName = context.opponentName or "Opponent"
    affModule.startOnline(params, context)

    if pd then pd.dismiss() end
end

function GameLogicManager.routeGameExecution(context)
    local targetGame = context.gameName and string_lower(context.gameName) or "beggarmynaighbor"
    local act = safeGetActivity(context.viewport, context)
    
    local pd = showLoading(act, "Starting Game", "Game load ho rahi hai, please wait...")
    
    -- OPTIMIZED: Pre-calculate routing conditions
    local isMemory = string_find(targetGame, "memory") or targetGame == "game two"
    local isGameThree = string_find(targetGame, "game three") or targetGame == "gamethreename"
    local isFreeFire = string_find(targetGame, "free fire") or string_find(targetGame, "aff") or targetGame == "audio free fire"
    
    local function executeGame()
        if isMemory then
            runGameTwoLogic(context, pd, act)
        elseif isGameThree then
            runGameThreeLogic(context, pd, act)
        elseif isFreeFire then
            runAudioFreeFireLogic(context, pd, act)
        else
            runBeggarmynaighbor(context, pd, act)
        end
    end

    if act then
        import "android.os.Handler"
        import "android.os.Looper"
        import "java.lang.Runnable"
        
        -- OPTIMIZED: Reduced delay from 250ms to 20ms to prevent hanging feel
        -- Looper.getMainLooper() ensures thread safety
        Handler(Looper.getMainLooper()).postDelayed(Runnable({
            run = executeGame
        }), 20)
    else
        executeGame()
    end
end

return GameLogicManager
