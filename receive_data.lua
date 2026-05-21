local ReceiveData = {}
import "org.json.JSONObject"
import "org.json.JSONArray"

-- Server se data lene aur parse karne ka poora nizam
function ReceiveData.fetchChatMessages(url, callback)
    Http.get(url, function(code, content)
        if code ~= 200 or not content then 
            if callback then callback(code, nil, 0) end
            return 
        end

        local raw = tostring(content):match("^%s*(.-)%s*$") or ""
        if raw == "" or raw == "null" or raw == "{}" then
            if callback then callback(200, {}, 0) end
            return
        end

        local normalizedData = {}
        local serverMsgCount = 0

        local cjson_status = pcall(function()
            local cjson = require("cjson")
            local data = cjson.decode(raw)
            if type(data) == "table" then
                for k, v in pairs(data) do
                    serverMsgCount = serverMsgCount + 1
                    normalizedData["idx_" .. tostring(k)] = {
                        sender = v.sender,
                        text = v.text,
                        time = v.time,
                        reply_to_sender = v.reply_to_sender,
                        reply_to_text = v.reply_to_text,
                        deleted = v.deleted
                    }
                end
            end
        end)

        if not cjson_status then
            pcall(function()
                local firstChar = raw:sub(1,1)
                if firstChar == "[" then
                    local arr = JSONArray(raw)
                    for i = 0, arr:length() - 1 do
                        if not arr:isNull(i) then
                            serverMsgCount = serverMsgCount + 1
                            local obj = arr:getJSONObject(i)
                            normalizedData["idx_" .. tostring(i)] = {
                                sender = obj:optString("sender", "Unknown"),
                                text = obj:optString("text", ""),
                                time = obj:optString("time", ""),
                                reply_to_sender = obj:has("reply_to_sender") and obj:getString("reply_to_sender") or nil,
                                reply_to_text = obj:has("reply_to_text") and obj:getString("reply_to_text") or nil,
                                deleted = obj:optBoolean("deleted", false)
                            }
                        end
                    end
                elseif firstChar == "{" then
                    local root = JSONObject(raw)
                    local iter = root:keys()
                    while iter:hasNext() do
                        serverMsgCount = serverMsgCount + 1
                        local k = tostring(iter:next())
                        local obj = root:getJSONObject(k)
                        normalizedData["idx_" .. tostring(k)] = {
                            sender = obj:optString("sender", "Unknown"),
                            text = obj:optString("text", ""),
                            time = obj:optString("time", ""),
                            reply_to_sender = obj:has("reply_to_sender") and obj:getString("reply_to_sender") or nil,
                            reply_to_text = obj:has("reply_to_text") and obj:getString("reply_to_text") or nil,
                            deleted = obj:optBoolean("deleted", false)
                        }
                    end
                end
            end)
        end

        if callback then
            callback(200, normalizedData, serverMsgCount)
        end
    end)
end

-- External check for unread layout counts
function ReceiveData.checkUnread(act, chatUsername, callback)
    local chatUrl = "https://card-games-muzammil-munir-default-rtdb.firebaseio.com/chats/PK-Games-01/messages.json"
    Http.get(chatUrl, function(code, content)
        if code ~= 200 or not content then 
            if callback then callback(0) end
            return 
        end
        local raw = tostring(content):match("^%s*(.-)%s*$") or ""
        if raw == "" or raw == "null" or raw == "{}" then
            if callback then callback(0) end
            return
        end
        
        local metaPrefs = act.getSharedPreferences("UnreadMetadata", android.content.Context.MODE_PRIVATE)
        local lastSeenTime = tonumber(metaPrefs.getString("last_seen_timestamp", "0")) or 0
        local unreadCount = 0
        
        pcall(function()
            local cjson = require("cjson")
            local data = cjson.decode(raw)
            if type(data) == "table" then
                for _, v in pairs(data) do
                    if type(v) == "table" and v.time and v.sender then
                        local msgTime = tonumber(v.time) or 0
                        if msgTime > lastSeenTime and v.sender ~= tostring(chatUsername) and v.text ~= "馃毇 This message was deleted" then
                            unreadCount = unreadCount + 1
                        end
                    end
                end
            end
        end)
        if callback then callback(unreadCount) end
    end)
end

return ReceiveData
