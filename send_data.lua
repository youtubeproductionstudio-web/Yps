local SendData = {}
import "org.json.JSONObject"
import "java.lang.String"

-- Message ko execute aur format karne ka poora texture yahan hai
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

    -- Safeguarding text texture
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

    -- Agar koi reply payload ho to use attach karo
    if replyTo then
        payloadObj.put("reply_to_sender", tostring(replyTo.sender))
        payloadObj.put("reply_to_text", tostring(replyTo.text))
    end

    Http.post(url, payloadObj.toString(), function(code, content)
        if callback then callback(code, content) end
    end)
    return true
end

-- Chat clear karne ke liye
function SendData.clearChat(url, callback)
    Http.delete(url, function(code, content)
        if callback then callback(code, content) end
    end)
end

-- Message delete karne ke liye
function SendData.deleteMessage(url, callback)
    Http.delete(url, function(code, content)
        if callback then callback(code, content) end
    end)
end

return SendData
