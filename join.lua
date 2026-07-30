local JoinModule = {}

function JoinModule.execute(roomKey, ctx)
    ctx.setCurrentRoom(roomKey:lower())
    local nodeTarget = ctx.DB_URL .. "/rooms/" .. ctx.gamePathNode .. "/" .. ctx.getCurrentRoom() .. ".json"
    
    ctx.asyncNetwork(function()
        ctx.Network.get(nodeTarget, function(roomBody, statusOk)
            if not statusOk or roomBody == "null" or roomBody == "" then
                ctx.forceExitToMenu("Room no longer exists!") return
            end
            
            ctx.asyncNetwork(function()
                local success, err = pcall(function()
                    local rObj = ctx.JSONObject(roomBody) 
                    local serverBanExpiry = rObj.optLong("banned_player_" .. ctx.myUsername:lower(), 0)
                    if os.time() < serverBanExpiry then
                        ctx.forceExitToMenu("You are permanently banned from this room by the Host!") return
                    end
                    
                    ctx.setMyRole("waitingList") 
                    
                    -- Bug Fix: Safely fetching JSONArray
                    local waitArray = ctx.JSONArray()
                    if rObj.has("waitingList") and not rObj.isNull("waitingList") then
                        waitArray = rObj.getJSONArray("waitingList")
                    end
                    
                    waitArray.put(ctx.myUsername)
                    rObj.put("waitingList", waitArray)
                    rObj.put("hb_" .. ctx.safeName(ctx.myUsername), os.time())
                    
                    local alertObj = ctx.JSONObject()
                    alertObj.put("sender", "SYSTEM") 
                    alertObj.put("text", ctx.myUsername:upper() .. " joined.")
                    alertObj.put("timestamp", os.time()*1000) 
                    rObj.put("lastChat", alertObj)
                    
                    ctx.Network.put(nodeTarget, rObj.toString(), function(ok)
                        ctx.safeUI(function()
                            if ok then ctx.onJoinSuccess() end
                        end)
                    end)
                end)
                if not success then ctx.forceExitToMenu("Error joining room data execution.") end
            end)
        end)
    end)
end

return JoinModule
