local NetworkEngine = {}

-- Import Java/Android Classes for Networking
import "android.os.Handler"
import "android.os.Looper"
import "java.lang.Thread"
import "java.lang.Runnable"
import "java.lang.String"
import "java.lang.StringBuilder"
import "java.io.BufferedReader"
import "java.io.InputStreamReader"
import "java.net.URL"
import "org.json.JSONObject"
import "org.json.JSONArray"
import "java.util.concurrent.Executors" 

local uiHandler = Handler(Looper.getMainLooper())
-- Thread pool increased to 8 to handle parallel operations gracefully on slow connections
local threadPool = Executors.newFixedThreadPool(8) 
local syncThread = nil
local syncRunning = false

-- Centralized HTTP Manager to prevent Connection Leaks & Crashes
local function executeHttp(method, targetUrl, payload)
    local success = false
    local response = "null"
    
    pcall(function()
        local url = URL(targetUrl)
        local conn = url.openConnection()
        conn.setConnectTimeout(8000) -- Increased for Silo/slow networks
        conn.setReadTimeout(8000)
        conn.setRequestMethod(method)
        conn.setRequestProperty("Connection", "keep-alive")
        conn.setRequestProperty("Accept-Charset", "UTF-8")

        if payload then
            conn.setDoOutput(true)
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            local data = String(payload).getBytes("UTF-8")
            local os = conn.getOutputStream()
            os.write(data)
            os.flush()
            os.close()
        end

        local code = conn.getResponseCode()
        local stream
        
        -- Success vs Error stream handling (CRITICAL for fixing crashes/hangs)
        if code >= 200 and code < 300 then
            stream = conn.getInputStream()
            success = true
        else
            stream = conn.getErrorStream()
        end

        if stream then
            local reader = BufferedReader(InputStreamReader(stream, "UTF-8"))
            local sb = StringBuilder()
            local line = reader.readLine()
            while line ~= nil do
                sb.append(line)
                line = reader.readLine()
            end
            reader.close()
            stream.close() -- Connection freed for internal pool reuse!
            if success then
                response = sb.toString()
            end
        end
    end)
    
    return success, response
end

function NetworkEngine.executeTask(logicAction)
    threadPool.execute(Runnable({run = logicAction}))
end

function NetworkEngine.put(targetUrl, jsonString, callback)
    threadPool.execute(Runnable({
        run = function()
            local success, _ = executeHttp("PUT", targetUrl, jsonString)
            if callback then uiHandler.post(Runnable({ run = function() callback(success) end })) end
        end
    }))
end

function NetworkEngine.patch(targetUrl, jsonString, callback)
    threadPool.execute(Runnable({
        run = function()
            local url = targetUrl .. "?x-http-method-override=PATCH"
            local success, _ = executeHttp("POST", url, jsonString)
            if callback then uiHandler.post(Runnable({ run = function() callback(success) end })) end
        end
    }))
end

function NetworkEngine.get(targetUrl, callback)
    threadPool.execute(Runnable({
        run = function()
            local success, res = executeHttp("GET", targetUrl, nil)
            if callback then uiHandler.post(Runnable({ run = function() callback(res, success) end })) end
        end
    }))
end

function NetworkEngine.delete(targetUrl, callback)
    threadPool.execute(Runnable({
        run = function()
            local success, _ = executeHttp("DELETE", targetUrl, nil)
            if callback then uiHandler.post(Runnable({ run = function() callback(success) end })) end
        end
    }))
end

function NetworkEngine.fastAction(nodeTarget, actionLogic, onCompleteCallback)
    threadPool.execute(Runnable({
        run = function()
            local success, body = executeHttp("GET", nodeTarget, nil)
            if success and body ~= "null" then
                pcall(function()
                    local rObj = JSONObject(body)
                    actionLogic(rObj)
                    
                    executeHttp("PUT", nodeTarget, rObj.toString())
                    
                    if onCompleteCallback then
                        uiHandler.post(Runnable({ run = onCompleteCallback }))
                    end
                end)
            end
        end
    }))
end

-- Ultra-Stable Background Lobby Sync Engine
function NetworkEngine.startRoomSync(config, uiCallbacks)
    NetworkEngine.stopRoomSync()
    syncRunning = true
    
    local lastHbTime = 0
    local lastRawBodyCache = ""
    local nodeTarget = config.dbUrl .. "/rooms/" .. config.gamePathNode .. "/" .. config.currentRoom .. ".json"
    
    syncThread = Thread(Runnable({
        run = function()
            while syncRunning do
                local now = os.time()
                
                -- Heartbeat dispatched to threadPool (Parallel execution = faster sync loop)
                if now - lastHbTime >= 3 then
                    lastHbTime = now
                    threadPool.execute(Runnable({
                        run = function()
                            local patchObj = JSONObject()
                            patchObj.put("hb_" .. config.safeName, now)
                            executeHttp("POST", nodeTarget .. "?x-http-method-override=PATCH", patchObj.toString())
                        end
                    }))
                end
                
                -- Realtime fetch
                local statusOk, body = executeHttp("GET", nodeTarget, nil)
                
                if not syncRunning then break end
                
                if statusOk then
                    if body == "null" or body == "" then
                        uiHandler.post(Runnable({ run = function() uiCallbacks.onRoomClosed("Room deleted or closed by host.") end }))
                        break
                    elseif body ~= lastRawBodyCache then
                        lastRawBodyCache = body
                        
                        pcall(function()
                            local jobj = JSONObject(body)
                            local liveTime = os.time()
                            
                            -- Status logic interpreter
                            local function getPlayerState(pName)
                                if pName == "Empty" or pName == "" then return "EMPTY" end
                                local lastSeen = jobj.optLong("hb_" .. pName:gsub("[%.$#%[%]/%s]", "_"):lower(), liveTime)
                                local diff = liveTime - lastSeen
                                if diff < 0 then diff = 0 end
                                if lastSeen > 0 and diff > 15 then return "REMOVE" end
                                if lastSeen > 0 and diff > 5 then return "OFFLINE" end
                                return "ONLINE"
                            end
                            
                            -- Ban checking enforcement
                            local localKickBanStamp = jobj.optLong("banned_player_" .. config.myUsername:lower(), 0)
                            if localKickBanStamp > 0 and liveTime < localKickBanStamp then
                                uiHandler.post(Runnable({ run = function() uiCallbacks.onKicked() end }))
                                syncRunning = false
                                return
                            end
                            
                            -- Cleanup calculations
                            local activeRoomHostName = jobj.optString("hostName", "Admin")
                            local p1NameServer = jobj.optString("player1_name", "Empty")
                            local p2NameServer = jobj.optString("player2_name", "Empty")
                            
                            local currentActivePlayersList = {}
                            if p1NameServer ~= "Empty" and p1NameServer ~= "" then currentActivePlayersList[p1NameServer] = "player1" end
                            if p2NameServer ~= "Empty" and p2NameServer ~= "" then currentActivePlayersList[p2NameServer] = "player2" end
                            
                            local audCheck = jobj.optJSONArray("audience")
                            if audCheck ~= nil then
                                for i=0, audCheck.length()-1 do currentActivePlayersList[audCheck.getString(i)] = "audience" end
                            end
                            local waitCheck = jobj.optJSONArray("waitingList")
                            if waitCheck ~= nil then
                                for i=0, waitCheck.length()-1 do currentActivePlayersList[waitCheck.getString(i)] = "waitingList" end
                            end
                            
                            local needToKick = {}
                            for pName, _ in pairs(currentActivePlayersList) do
                                if getPlayerState(pName) == "REMOVE" then table.insert(needToKick, pName) end
                            end
                            
                            local amIResponsible = false
                            if activeRoomHostName == config.myUsername then
                                amIResponsible = true
                            else
                                if getPlayerState(activeRoomHostName) == "REMOVE" then
                                    local candidateHost = "Empty"
                                    if p1NameServer ~= "Empty" and getPlayerState(p1NameServer) ~= "REMOVE" then candidateHost = p1NameServer
                                    elseif p2NameServer ~= "Empty" and getPlayerState(p2NameServer) ~= "REMOVE" then candidateHost = p2NameServer
                                    end
                                    if candidateHost == config.myUsername then amIResponsible = true end
                                end
                            end
                            
                            if amIResponsible and #needToKick > 0 then
                                NetworkEngine.fastAction(nodeTarget, function(rObj)
                                    local systematicallyKicked = {}
                                    for _, kickTarget in ipairs(needToKick) do
                                        if rObj.optString("player1_name") == kickTarget then rObj.put("player1_name", "Empty") rObj.put("player1_status", "empty") end
                                        if rObj.optString("player2_name") == kickTarget then rObj.put("player2_name", "Empty") rObj.put("player2_status", "empty") end
                                        
                                        local aArr = rObj.optJSONArray("audience")
                                        if aArr then
                                            local nA = JSONArray()
                                            for i=0, aArr.length()-1 do
                                                if aArr.getString(i) ~= kickTarget then nA.put(aArr.getString(i)) end
                                            end
                                            rObj.put("audience", nA)
                                        end
                                        local wArr = rObj.optJSONArray("waitingList")
                                        if wArr then
                                            local nW = JSONArray()
                                            for i=0, wArr.length()-1 do
                                                if wArr.getString(i) ~= kickTarget then nW.put(wArr.getString(i)) end
                                            end
                                            rObj.put("waitingList", nW)
                                        end
                                        rObj.remove("hb_" .. kickTarget:gsub("[%.$#%[%]/%s]", "_"):lower())
                                        table.insert(systematicallyKicked, kickTarget:upper())
                                    end
                                    
                                    local currentHost = rObj.optString("hostName")
                                    local hostKicked = false
                                    for _, kTarget in ipairs(needToKick) do if currentHost == kTarget then hostKicked = true break end end
                                    if hostKicked then
                                        rObj.put("hostName", config.myUsername)
                                    end
                                    
                                    if #systematicallyKicked > 0 then
                                        local sysObj = JSONObject()
                                        sysObj.put("sender", "SYSTEM")
                                        sysObj.put("text", table.concat(systematicallyKicked, ", ") .. " removed due to inactivity.")
                                        sysObj.put("timestamp", os.time() * 1000)
                                        rObj.put("lastChat", sysObj)
                                    end
                                end)
                            end
                            
                            uiHandler.post(Runnable({
                                run = function()
                                    if syncRunning then
                                        uiCallbacks.onDataReceived(body, jobj, currentActivePlayersList, getPlayerState)
                                    end
                                end
                            }))
                        end)
                    end
                end
                
                Thread.sleep(650)
            end
        end
    }))
    syncThread.start()
end

function NetworkEngine.stopRoomSync()
    syncRunning = false
    if syncThread then
        -- Enforces complete background halt upon exit
        pcall(function() syncThread.interrupt() end)
        syncThread = nil
    end
end

return NetworkEngine
