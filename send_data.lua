local SendData = {}
import "org.json.JSONObject"
import "java.lang.String"

function SendData.postMessage(url, username, text, replyTo, callback)
    local trimmed = text:gsub("^%s*(.-)%s*$", "%1")
    if trimmed == "" then 
        if callback then callback(-1, "Empty message") end
        return false
    end
    
    local javaStr = String(text)
    if javaStr.length() > 1500 then
        if callback then callback(-2, "Length exceeded") end
        return false
    end

    text = text:gsub('\\', '\\\\')
    text = text:gsub('"', '\\"')
    text = text:gsub('\n', '\\n')
    text = text:gsub('\r', '')

    local timeStr = tostring(os.time()) 

    local payloadObj = JSONObject()
    payloadObj.put("sender", tostring(username))
    payloadObj.put("text", tostring(text))
    payloadObj.put("time", timeStr)
    payloadObj.put("deleted", false)

    if replyTo then
        payloadObj.put("reply_to_sender", tostring(replyTo.sender))
        payloadObj.put("reply_to_text", tostring(replyTo.text))
    end

    Http.post(url, payloadObj.toString(), function(code, content)
        if callback then callback(code, content) end
    end)
    return true
end

function SendData.clearChat(url, callback)
    Http.delete(url, function(code, content)
        if callback then callback(code, content) end
    end)
end

function SendData.deleteMessage(url, sender, timeStr, callback)
    local payloadObj = JSONObject()
    payloadObj.put("sender", tostring(sender))
    payloadObj.put("text", "🚫 This message was deleted")
    payloadObj.put("time", tostring(timeStr))
    payloadObj.put("deleted", true)
    
    Http.put(url, payloadObj.toString(), function(code, content)
        if callback then callback(code, content) end
    end)
end

return SendData
