local M = {} 

import "android.widget.*"
import "android.view.*"
import "android.view.Gravity"
import "android.view.ViewTreeObserver"
import "android.graphics.Color"
import "android.graphics.drawable.GradientDrawable"
import "android.os.Handler"
import "android.os.Looper"
import "java.lang.Runnable"
import "android.text.Html"
import "android.content.Context"
import "android.app.AlertDialog"
import "android.content.DialogInterface"
import "android.media.MediaPlayer"

-- Sound Play karne ka function
local function playSound(path)
    pcall(function()
        local mp = MediaPlayer()
        mp.setDataSource(path)
        mp.prepare()
        mp.start()
        mp.setOnCompletionListener(MediaPlayer.OnCompletionListener{
            onCompletion = function(m)
                m.release()
            end
        })
    end)
end

-- REQUIRED MODULES
local ReceiveData = require("receive_data")
local SendData = require("send_data")
local ReplyManager = require("reply_manager")

_G.AppState = {
    isInChat = true,
    loadedIds = {},
    loadedViews = {},
    seenSignatures = {},     
    replyTo = nil,        
    isFirstLoad = true    
}

function M.checkUnread(act, chatUsername, callback)
    ReceiveData.checkUnread(act, chatUsername, callback)
end

function M.show(params)

    local act = params.activity or activity
    local chatUsername = params.username or "Guest"

    -- Dynamically real-time role loader logic
    local role = "user"
    if params.prefs then
        role = params.prefs.getString("role", "user")
    elseif params.role then
        role = params.role
    end
    local isAdmin = (role == "admin")

    local chatUrl = "https://card-games-muzammil-munir-default-rtdb.firebaseio.com/chats/PK-Games-01/messages.json"

    _G.AppState.isInChat = true
    _G.AppState.loadedIds = {}
    _G.AppState.loadedViews = {}
    _G.AppState.seenSignatures = {}
    _G.AppState.replyTo = nil
    _G.AppState.isFirstLoad = true

    local mainHandler = Handler(Looper.getMainLooper())

    -- Real-time role check from server to ensure Admin status is always accurate
    if chatUsername ~= "Guest" then
        local nodeKey = chatUsername:lower():gsub(" ", "%%20")
        local roleCheckUrl = "https://card-games-muzammil-munir-default-rtdb.firebaseio.com/users/" .. nodeKey .. ".json"
        
        Http.get(roleCheckUrl, function(code, content)
            if code == 200 and content and content ~= "null" then
                local serverRole = content:match('"role"%s*:%s*"([^"]+)"')
                if serverRole then
                    role = serverRole
                    isAdmin = (role == "admin")
                    if params.prefs then
                        params.prefs.edit().putString("role", role).apply()
                    end
                    mainHandler.post(Runnable{
                        run = function()
                            if clearChatBtn then
                                clearChatBtn.setVisibility(isAdmin and View.VISIBLE or View.GONE)
                            end
                        end
                    })
                end
            end
        end)
    end

    -- DIALOG BOX FOR LEAVING CHAT ROOM
    local function showExitDialog()
        local confirm = AlertDialog.Builder(act)
        confirm.setTitle("Leave Chat")
        confirm.setMessage("Are you sure you want to leave the public chat room?")
        confirm.setPositiveButton("Yes", DialogInterface.OnClickListener{
            onClick = function(dialog, which)
                _G.AppState.isInChat = false
                mainHandler.removeCallbacksAndMessages(nil) 
                if params.mainUI then
                    params.mainUI() 
                end
            end
        })
        confirm.setNegativeButton("No", nil)
        confirm.show()
    end

    local layout = {
        LinearLayout,
        orientation = "vertical",
        layout_width = "match_parent",
        layout_height = "match_parent",
        background = "#0b141a",

        {
            LinearLayout,
            orientation = "horizontal",
            layout_width = "match_parent",
            layout_height = "wrap_content",
            background = "#1f2c34",
            gravity = "center_vertical",
            padding = "4dp",
            {
                Button,
                id = "backToMainBtn",
                text = "Back",
                layout_width = "wrap_content",
                layout_height = "wrap_content",
                background = "#ea0038",
                textColor = "#FFFFFF",
                layout_margin = "6dp"
            },
            {
                TextView,
                id = "titleTv",
                text = "Public Chat Room (0)",
                textSize = "18sp",
                textColor = "#00a884",
                padding = "10dp",
                layout_width = "0dp",
                layout_weight = 1,
                gravity = "left|center_vertical"
            },
            {
                Button,
                id = "clearChatBtn",
                text = "Clear",
                layout_width = "wrap_content",
                layout_height = "wrap_content",
                background = "#ea0038",
                textColor = "#FFFFFF",
                layout_margin = "6dp",
                visibility = isAdmin and View.VISIBLE or View.GONE
            }
        },

        {
            ScrollView,
            id = "chatScroll",
            layout_width = "match_parent",
            layout_height = "0dp",
            layout_weight = 1,
            fillViewport = true,

            {
                LinearLayout,
                id = "chatContainer",
                orientation = "vertical",
                padding = "12dp",
                layout_width = "match_parent",
                layout_height = "wrap_content"
            }
        },

        {
            Button,
            id = "recentMsgBtn",
            text = "Go to most recent message",
            layout_width = "match_parent",
            layout_height = "wrap_content",
            background = "#1f2c34",
            textColor = "#00a884",
            padding = "8dp",
            textSize = "14sp",
            visibility = View.GONE, -- Hidden by default
        },

        {
            LinearLayout,
            id = "replyContainer",
            orientation = "horizontal",
            layout_width = "match_parent",
            layout_height = "wrap_content",
            background = "#1f2c34",
            padding = "8dp",
            visibility = View.GONE,
            gravity = "center_vertical",
            {
                TextView,
                id = "replyTextPreview",
                layout_width = "0dp",
                layout_weight = 1,
                textColor = "#00a884",
                textSize = "13sp",
                maxLines = 2,
            },
            {
                Button,
                id = "cancelReplyBtn",
                text = "Cancel Reply",
                layout_width = "wrap_content",
                layout_height = "wrap_content",
                background = "#ea0038",
                textColor = "#ffffff",
                padding = "8dp",
                textSize = "12sp"
            }
        },

        {
            LinearLayout,
            orientation = "horizontal",
            padding = "8dp",
            layout_width = "match_parent",
            layout_height = "wrap_content",
            background = "#1f2c34",
            gravity = "center_vertical",

            {
                EditText,
                id = "messageInput",
                layout_width = "0dp",
                layout_weight = 1,
                hint = "Type message...",
                textColor = "#FFFFFF",
                hintTextColor = "#8696a0",
                background = "#2a3942",
                padding = "12dp",
                textSize = "16sp"
            },

            {
                Button,
                id = "sendBtn",
                text = "Send Message",
                background = "#00a884",
                textColor = "#111b21",
                layout_marginLeft = "8dp"
            }
        }
    }

    local layoutView = loadlayout(layout)
    
    local backKeyListener = View.OnKeyListener{
        onKey = function(v, keyCode, event)
            if event.getAction() == KeyEvent.ACTION_DOWN and keyCode == KeyEvent.KEYCODE_BACK then
                showExitDialog() 
                return true 
            end
            return false
        end
    }
    
    layoutView.setFocusableInTouchMode(true)
    layoutView.requestFocus()
    layoutView.setOnKeyListener(backKeyListener)
    messageInput.setOnKeyListener(backKeyListener)

    act.setContentView(layoutView)
    titleTv.getPaint().setFakeBoldText(true)

    ReplyManager.init(replyContainer, replyTextPreview)

    cancelReplyBtn.setOnClickListener(View.OnClickListener{
        onClick = function()
            ReplyManager.cancelReply()
        end
    })

    -- Add scroll listener to show/hide "Go to most recent message" button
    chatScroll.getViewTreeObserver().addOnScrollChangedListener(ViewTreeObserver.OnScrollChangedListener{
        onScrollChanged = function()
            local childCount = chatContainer.getChildCount()
            if childCount <= 3 then
                recentMsgBtn.setVisibility(View.GONE)
                return
            end
            
            local totalHeight = chatContainer.getHeight()
            local scrollY = chatScroll.getScrollY()
            local viewHeight = chatScroll.getHeight()
            
            -- Calculate height of last 3 messages
            local last3Height = 0
            for i = childCount - 3, childCount - 1 do
                local child = chatContainer.getChildAt(i)
                if child then
                    last3Height = last3Height + child.getHeight() + 12 -- Added approx margin
                end
            end
            
            -- Check if user has scrolled up past the last 3 messages
            if (totalHeight - (scrollY + viewHeight)) > last3Height then
                if recentMsgBtn.getVisibility() ~= View.VISIBLE then
                    recentMsgBtn.setVisibility(View.VISIBLE)
                end
            else
                if recentMsgBtn.getVisibility() ~= View.GONE then
                    recentMsgBtn.setVisibility(View.GONE)
                end
            end
        end
    })

    recentMsgBtn.setOnClickListener(View.OnClickListener{
        onClick = function()
            local childCount = chatContainer.getChildCount()
            if childCount > 0 then
                local lastView = chatContainer.getChildAt(childCount - 1)
                chatScroll.fullScroll(ScrollView.FOCUS_DOWN)
                lastView.requestFocus()
                -- 32768 is AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED
                lastView.sendAccessibilityEvent(32768)
                recentMsgBtn.setVisibility(View.GONE)
            end
        end
    })

    if params.wrapClick then
        params.wrapClick(clearChatBtn, function()
            if not isAdmin then return end -- Extra safety check
            local confirm = AlertDialog.Builder(act)
            confirm.setTitle("Clear Public Chat")
            confirm.setMessage("Are you sure you want to clear the entire chat room?")
            confirm.setPositiveButton("Yes", DialogInterface.OnClickListener{
                onClick = function(d, w)
                    local overrideUrl = chatUrl .. "?method=DELETE"
                    SendData.clearChat(overrideUrl, function(delCode, delRes)
                        Toast.makeText(act, "Chat Cleared by Admin", Toast.LENGTH_SHORT).show()
                        chatContainer.removeAllViews()
                        _G.AppState.loadedIds = {}
                        _G.AppState.loadedViews = {}
                        _G.AppState.seenSignatures = {}
                        layoutView.requestFocus()
                    end)
                end
            })
            confirm.setNegativeButton("No", nil)
            confirm.show()
        end)
    end

    local fetchMessages

    local function displayMessage(sender, text, timeStr, msgKey, replySender, replyText)
        if not _G.AppState.isInChat then return end

        sender = tostring(sender or "Unknown")
        text = tostring(text or "")
        timeStr = tostring(timeStr or "")
        msgKey = tostring(msgKey or "sys_msg")
        
        -- Clean string to strictly match 'This message was deleted' (Emoji Removed)
        if string.find(text, "This message was deleted") then
            text = "This message was deleted"
        end

        local displayTime = ""
        local epochTime = tonumber(timeStr)
        if epochTime and epochTime > 1000000000 then 
            displayTime = os.date("%d %b %Y • %I:%M %p", epochTime)
        else
            displayTime = timeStr 
        end
        displayTime = displayTime:gsub("^0(%d:)", "%1"):gsub("• 0(%d:)", "• %1")

        local isMe = (sender == tostring(chatUsername))
        local isDeleted = (text == "This message was deleted")

        local safeText = text:gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\\n", "<br>"):gsub("\n", "<br>")
        local senderColor = isMe and "#00a884" or "#ea0038"
        
        local htmlString = string.format("<font color='%s'><b>%s</b></font><br>%s", senderColor, sender, safeText)
        if displayTime ~= "" then
            htmlString = htmlString .. string.format("<br><font color='#8696a0'><small>%s</small></font>", displayTime)
        end

        if _G.AppState.loadedViews[msgKey] then
            local env = _G.AppState.loadedViews[msgKey]
            if env and env.msgTv then
                env.msgTv.setText(Html.fromHtml(htmlString))
                if replySender and replyText and env.replyTv then
                    env.replyTv.setText(ReplyManager.formatReplyHtml(replySender, replyText))
                    env.replyContainerView.setVisibility(View.VISIBLE)
                elseif env.replyContainerView then
                    env.replyContainerView.setVisibility(View.GONE)
                end
            end
            return 
        end

        local bubbleLayout = {
            LinearLayout,
            orientation = "vertical",
            layout_width = "wrap_content",
            layout_height = "wrap_content",
            padding = "12dp",
        }

        local tempEnv = {}
        local bubbleView = loadlayout(bubbleLayout, tempEnv)
        local bubbleEnv = ReplyManager.buildBubbleUI(act, bubbleView)
        
        _G.AppState.loadedViews[msgKey] = bubbleEnv
        bubbleEnv.msgTv.setText(Html.fromHtml(htmlString))

        if replySender and replyText then
            bubbleEnv.replyTv.setText(ReplyManager.formatReplyHtml(replySender, replyText))
            bubbleEnv.replyContainerView.setVisibility(View.VISIBLE)
        end

        local bgShape = GradientDrawable()
        bgShape.setShape(GradientDrawable.RECTANGLE)
        bgShape.setColor(Color.parseColor(isMe and "#005c4b" or "#202c33"))
        bgShape.setCornerRadius(24) 
        bubbleView.setBackground(bgShape)

        local lp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        lp.gravity = isMe and Gravity.RIGHT or Gravity.LEFT
        lp.setMargins(0, 6, 0, 6)
        bubbleView.setLayoutParams(lp)

        local starPrefs = act.getSharedPreferences("StarredDatabase", Context.MODE_PRIVATE)
        
        -- Yahan sirf tab long click listener set hoga jab message deleted NAHI hoga
        if not isDeleted then
            bubbleView.setOnLongClickListener(View.OnLongClickListener{
                onLongClick = function(v)
                    local isCurrentlyStarred = starPrefs.contains(msgKey)
                    local opts = {"Copy"}
                    table.insert(opts, "Reply")
                    table.insert(opts, isCurrentlyStarred and "Unstar" or "Star")
                    if (isMe or isAdmin) then table.insert(opts, "Delete") end
                    
                    local builder = AlertDialog.Builder(act)
                    builder.setItems(opts, DialogInterface.OnClickListener{
                        onClick = function(dialog, which)
                            local sel = opts[which+1]
                            if sel == "Copy" then
                                local clipboard = act.getSystemService(Context.CLIPBOARD_SERVICE)
                                clipboard.setText(sender .. ":\n" .. text)
                                Toast.makeText(act, "Copied", Toast.LENGTH_SHORT).show()
                            elseif sel == "Reply" then
                                ReplyManager.setReply(sender, text)
                            elseif sel == "Star" then
                                local dataObj = JSONObject()
                                dataObj.put("sender", sender)
                                dataObj.put("text", text)
                                dataObj.put("time", timeStr)
                                if replySender then dataObj.put("reply_to_sender", replySender) end
                                if replyText then dataObj.put("reply_to_text", replyText) end
                                starPrefs.edit().putString(msgKey, dataObj.toString()).apply()
                                Toast.makeText(act, "Starred", Toast.LENGTH_SHORT).show()
                            elseif sel == "Unstar" then
                                starPrefs.edit().remove(msgKey).apply()
                                Toast.makeText(act, "Unstarred", Toast.LENGTH_SHORT).show()
                            elseif sel == "Delete" then
                                local confirmDelete = AlertDialog.Builder(act)
                                confirmDelete.setTitle("Delete Message")
                                confirmDelete.setMessage("Are you sure you want to delete this message?")
                                confirmDelete.setPositiveButton("Yes", DialogInterface.OnClickListener{
                                    onClick = function(d, w)
                                        local firebaseKey = msgKey:gsub("^idx_", "")
                                        local updateUrl = chatUrl:gsub("messages.json", "messages/" .. firebaseKey .. ".json")
                                        SendData.deleteMessage(updateUrl, sender, timeStr, function(code, content)
                                            if code == 200 or code == 201 then
                                                mainHandler.post(Runnable{run = function() if fetchMessages then fetchMessages() end end})
                                            end
                                        end)
                                    end
                                })
                                confirmDelete.setNegativeButton("No", nil)
                                confirmDelete.show()
                            end
                        end
                    })
                    builder.show()
                    return true
                end
            })
        end

        chatContainer.addView(bubbleView)
        chatScroll.post(Runnable{run = function() 
            if _G.AppState.isInChat and chatScroll then 
                chatScroll.fullScroll(ScrollView.FOCUS_DOWN) 
            end 
        end})
    end

    local function processIncomingData(dataMap, totalMsgCount)
        if not _G.AppState.isInChat then return end -- Extra safety check
        
        local starPrefs = act.getSharedPreferences("StarredDatabase", Context.MODE_PRIVATE)
        local metaPrefs = act.getSharedPreferences("UnreadMetadata", Context.MODE_PRIVATE)
        
        local lastSeenTime = tonumber(metaPrefs.getString("last_seen_timestamp", "0")) or 0
        local highestTimestamp = lastSeenTime

        for k, v in pairs(dataMap) do
            if type(v) == "table" then
                -- Emoji removal check for incoming data processing
                if v.text and string.find(v.text, "This message was deleted") then
                    v.text = "This message was deleted"
                end
                
                if v.text == "This message was deleted" or v.deleted == true then
                    if starPrefs.contains(k) then starPrefs.edit().remove(k).apply() end
                end
            end
        end

        local sortedKeys = {}
        for k in pairs(dataMap) do table.insert(sortedKeys, k) end
        table.sort(sortedKeys)

        local activeLiveCount = 0
        for i = 1, #sortedKeys do
            local v = dataMap[sortedKeys[i]]
            if type(v) == "table" and v.text ~= "This message was deleted" then activeLiveCount = activeLiveCount + 1 end
        end
        titleTv.setText("Public Chat Room (" .. tostring(activeLiveCount) .. ")")

        local hasNewReceive = false

        for i = 1, #sortedKeys do
            local k = sortedKeys[i]
            local v = dataMap[k]
            if type(v) == "table" and v.sender and v.text then
                local currentMsgTime = tonumber(v.time) or 0
                if currentMsgTime > highestTimestamp then highestTimestamp = currentMsgTime end

                local msgSignature = tostring(v.sender) .. "_" .. tostring(v.time)
                
                if not _G.AppState.seenSignatures[msgSignature] then
                    _G.AppState.seenSignatures[msgSignature] = true
                    
                    if not _G.AppState.isFirstLoad then
                        local msgSender = tostring(v.sender):match("^%s*(.-)%s*$") or tostring(v.sender)
                        local myUser = tostring(chatUsername):match("^%s*(.-)%s*$") or tostring(chatUsername)
                        
                        if string.lower(msgSender) ~= string.lower(myUser) and v.text ~= "This message was deleted" and v.deleted ~= true then
                            hasNewReceive = true
                        end
                    end
                end

                local lookupString = tostring(v.text) .. "||" .. tostring(v.reply_to_sender or "") .. "||" .. tostring(v.reply_to_text or "")
                if _G.AppState.loadedIds[k] ~= lookupString then
                    _G.AppState.loadedIds[k] = lookupString
                    displayMessage(v.sender, v.text, v.time, k, v.reply_to_sender, v.reply_to_text)
                end
            end
        end

        if hasNewReceive then
            if _G.AppState.isInChat and act.hasWindowFocus() then
                playSound(tostring(act.getLuaDir()) .. "/sounds/receive.mp3")
            end
        end

        _G.AppState.isFirstLoad = false

        if highestTimestamp > lastSeenTime then
            metaPrefs.edit().putString("last_seen_timestamp", tostring(highestTimestamp)).apply()
        end
    end

    fetchMessages = function()
        if not _G.AppState.isInChat then return end
        ReceiveData.fetchChatMessages(chatUrl, function(code, normalizedData, serverMsgCount)
            if not _G.AppState.isInChat then return end
            
            if serverMsgCount >= 100 then
                local overrideUrl = chatUrl .. "?method=DELETE"
                SendData.clearChat(overrideUrl, function() end)
                chatContainer.removeAllViews()
                _G.AppState.loadedIds = {}
                _G.AppState.loadedViews = {}
                _G.AppState.seenSignatures = {}
                return
            end

            mainHandler.post(Runnable{
                run = function()
                    if not _G.AppState.isInChat then return end
                    if normalizedData and next(normalizedData) ~= nil then 
                        processIncomingData(normalizedData, serverMsgCount) 
                    else
                        titleTv.setText("Public Chat Room (0)")
                        chatContainer.removeAllViews()
                        _G.AppState.loadedIds = {}
                        _G.AppState.loadedViews = {}
                        _G.AppState.seenSignatures = {}
                    end
                end
            })
        end)
    end

    local loopRunnable
    loopRunnable = Runnable{
        run = function()
            if _G.AppState.isInChat then
                if act.hasWindowFocus() then
                    if fetchMessages then fetchMessages() end
                end
                mainHandler.postDelayed(loopRunnable, 1500)
            end
        end
    }

    params.wrapClick(sendBtn, function()
        sendBtn.setEnabled(false)
        
        local text = tostring(messageInput.getText().toString())
        local currentReply = _G.AppState.replyTo

        SendData.postMessage(chatUrl, chatUsername, text, currentReply, function(code, content)
            if not _G.AppState.isInChat then return end
            
            if code == 200 or code == 201 then
                -- Disable for 5 seconds AFTER successful upload
                mainHandler.postDelayed(Runnable{
                    run = function()
                        if sendBtn then sendBtn.setEnabled(true) end
                    end
                }, 5000)
                
                if _G.AppState.isInChat and act.hasWindowFocus() then
                    playSound(tostring(act.getLuaDir()) .. "/sounds/send.mp3")
                end
                
                mainHandler.post(Runnable{
                    run = function()
                        messageInput.setText("")
                        ReplyManager.cancelReply()
                        if fetchMessages then fetchMessages() end
                    end
                })
            elseif code == -1 then
                -- Re-enable instantly on empty text error
                mainHandler.post(Runnable{run = function() if sendBtn then sendBtn.setEnabled(true) end end})
                Toast.makeText(act, "Cannot send empty message", Toast.LENGTH_SHORT).show()
            elseif code == -2 then
                -- Re-enable instantly on char limit error
                mainHandler.post(Runnable{run = function() if sendBtn then sendBtn.setEnabled(true) end end})
                messageInput.setText("")
                Toast.makeText(act, "Max 1500 characters allowed.", Toast.LENGTH_SHORT).show()
            else
                -- Re-enable instantly on network error
                mainHandler.post(Runnable{run = function() if sendBtn then sendBtn.setEnabled(true) end end})
                Toast.makeText(act, "Network issue, check connection.", Toast.LENGTH_SHORT).show()
            end
        end)
    end)

    params.wrapClick(backToMainBtn, function()
        showExitDialog()
    end)

    -- Start loop fetching only if active
    if fetchMessages and act.hasWindowFocus() then fetchMessages() end
    mainHandler.postDelayed(loopRunnable, 1500)

end

return M
