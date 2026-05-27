local ReplyManager = {}

import "android.view.View"
import "android.widget.LinearLayout"
import "android.widget.TextView"
import "android.graphics.Color"
import "android.graphics.drawable.GradientDrawable"
import "android.text.Html"

local containerView = nil
local previewTextView = nil

-- Reply UI views ko initialize karne ke liye
function ReplyManager.init(replyContainer, replyTextPreview)
    containerView = replyContainer
    previewTextView = replyTextPreview
end

-- Reply active karne ke liye (Long Press par)
function ReplyManager.setReply(sender, text)
    _G.AppState.replyTo = {sender = sender, text = text}
    if containerView and previewTextView then
        containerView.setVisibility(View.VISIBLE)
        previewTextView.setText("Replying to " .. sender .. ":\n" .. text)
    end
end

-- Reply cancel karne ke liye
function ReplyManager.cancelReply()
    _G.AppState.replyTo = nil
    if containerView and previewTextView then
        containerView.setVisibility(View.GONE)
        previewTextView.setText("")
    end
end

-- Bubble ke andar reply text format karne ke liye
function ReplyManager.formatReplyHtml(replySender, replyText)
    local safeReply = replyText:gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\\n", "<br>"):gsub("\n", "<br>")
    return Html.fromHtml(string.format("<font color='#00a884'><b>Replying to %s:</b></font><br>%s", replySender, safeReply))
end

-- Outgoing payload mein reply data attach karne ke liye
function ReplyManager.handleOutgoing(payloadObj)
    if _G.AppState.replyTo then
        payloadObj.put("reply_to_sender", tostring(_G.AppState.replyTo.sender))
        payloadObj.put("reply_to_text", tostring(_G.AppState.replyTo.text))
        ReplyManager.cancelReply()
    end
end

-- Bubble ka UI structure dynamically yahan banaya gaya hai
function ReplyManager.buildBubbleUI(act, bubbleView)
    local bubbleEnv = {}

    -- CONTAINER 1 (TOP): Main message jo hum bhej rahe hain (Accessibility reads this first)
    local mainContainer = LinearLayout(act)
    mainContainer.setOrientation(LinearLayout.VERTICAL)
    mainContainer.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT))

    local msgTv = TextView(act)
    msgTv.setTextColor(Color.parseColor("#e9edef"))
    msgTv.setTextSize(15)
    msgTv.setFocusable(true) -- Accessibility focus enabled
    msgTv.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT))
    
    mainContainer.addView(msgTv)
    bubbleView.addView(mainContainer)
    bubbleEnv.msgTv = msgTv

    -- CONTAINER 2 (BOTTOM): Original message jisko humne reply kiya hai (Accessibility reads this second)
    local replyContainer = LinearLayout(act)
    replyContainer.setOrientation(LinearLayout.VERTICAL)
    local bottomLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    bottomLp.setMargins(0, 12, 0, 0) -- Top margin to separate from main message
    replyContainer.setLayoutParams(bottomLp)
    
    local replyBg = GradientDrawable()
    replyBg.setShape(GradientDrawable.RECTANGLE)
    replyBg.setColor(Color.parseColor("#182229"))
    replyBg.setCornerRadius(8)
    replyContainer.setBackground(replyBg)
    replyContainer.setPadding(24, 16, 24, 16)
    replyContainer.setVisibility(View.GONE)

    local replyTv = TextView(act)
    replyTv.setTextColor(Color.parseColor("#8696a0"))
    replyTv.setTextSize(13)
    replyTv.setFocusable(true) -- Accessibility focus enabled
    replyTv.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
    
    replyContainer.addView(replyTv)
    bubbleView.addView(replyContainer)
    
    bubbleEnv.replyTv = replyTv
    bubbleEnv.replyContainerView = replyContainer

    return bubbleEnv
end

return ReplyManager
