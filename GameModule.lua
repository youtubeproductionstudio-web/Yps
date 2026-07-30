local GameModule = {}

function GameModule.startGameSignal(DB_URL, gamePathNode, currentRoom, Network, JSONObject, onSuccessCallback)
    local nodeTarget = DB_URL .. "/rooms/" .. gamePathNode .. "/" .. currentRoom .. ".json"
    Network.executeTask(function()
        pcall(function()
            local startObj = JSONObject()
            startObj.put("gameState", "STARTED")
            startObj.put("turn", "player1")
            
            Network.patch(nodeTarget, startObj.toString(), function(success)
                if success and onSuccessCallback then
                    onSuccessCallback()
                end
            end)
        end)
    end)
end

function GameModule.syncGameData(DB_URL, gamePathNode, currentRoom, Network, JSONObject, updatedScore, forceNextTurn)
    local nodeTarget = DB_URL .. "/rooms/" .. gamePathNode .. "/" .. currentRoom .. ".json"
    Network.executeTask(function()
        pcall(function()
            local syncPatchObj = JSONObject()
            syncPatchObj.put("syncScoreData", updatedScore)
            syncPatchObj.put("gameState", "STARTED")
            syncPatchObj.put("turn", forceNextTurn)
            
            Network.patch(nodeTarget, syncPatchObj.toString(), nil)
        end)
    end)
end

return GameModule
