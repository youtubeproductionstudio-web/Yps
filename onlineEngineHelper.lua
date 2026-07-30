local onlineEngineHelper = {}

function onlineEngineHelper.clearLobbyDataAndViews(ctx)
    if ctx.containerAudienceList then ctx.containerAudienceList.removeAllViews() end
    if ctx.containerWaitingList then ctx.containerWaitingList.removeAllViews() end
    if ctx.txtChatDisplay then ctx.txtChatDisplay.setText("Chat: No messages") end
    if ctx.txtPlayer1Row then ctx.txtPlayer1Row.setText("Player One: EMPTY") end
    if ctx.txtPlayer2Row then ctx.txtPlayer2Row.setText("Player Two: EMPTY") end
end

function onlineEngineHelper.setupTTSEngine(activity, prefs)
    import "android.speech.tts.TextToSpeech"
    import "java.util.Locale"
    import "android.os.Bundle"

    local ttsEngine = nil
    local ttsEngineStr = prefs.getString("tts_engine", "")
    
    local ttsInitListener = TextToSpeech.OnInitListener({
        onInit = function(status)
            pcall(function()
                if status == TextToSpeech.SUCCESS and ttsEngine ~= nil then
                    ttsEngine.setLanguage(Locale.US)
                    local rateInt = prefs.getInt("tts_rate", 100)
                    local pitchInt = prefs.getInt("tts_pitch", 100)
                    ttsEngine.setSpeechRate(rateInt / 100)
                    ttsEngine.setPitch(pitchInt / 100)
                end
            end)
        end
    })

    pcall(function()
        if ttsEngineStr ~= "" then
            ttsEngine = TextToSpeech(activity, ttsInitListener, ttsEngineStr)
        else
            ttsEngine = TextToSpeech(activity, ttsInitListener)
        end
    end)
    return ttsEngine
end

function onlineEngineHelper.openRoomConfigurationSetup(activity, isUpdateMode, config)
    import "android.app.AlertDialog"
    import "android.widget.LinearLayout"
    import "android.widget.TextView"
    import "android.widget.Spinner"
    import "android.widget.ArrayAdapter"
    import "org.json.JSONObject"
    import "org.json.JSONArray"

    local selectedGameName = "Beggarmynaighbor"
    local selectedGameHealth = "5"

    local layout = LinearLayout(activity)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(45, 30, 45, 30)
    
    local lblGame = TextView(activity)
    lblGame.setText("Select Game:")
    lblGame.setTextColor(0xFF000000)
    layout.addView(lblGame)
    
    local gameSpinner = Spinner(activity)
    local gameOptions = {"Beggarmynaighbor", "Memory Game", "Audio Free Fire"}
    local gameAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, gameOptions)
    gameAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    gameSpinner.setAdapter(gameAdapter)
    layout.addView(gameSpinner)
    
    local dynamicSubLayout = LinearLayout(activity)
    dynamicSubLayout.setOrientation(LinearLayout.VERTICAL)
    layout.addView(dynamicSubLayout)
    
    if isUpdateMode then
        for idx, val in ipairs(gameOptions) do
            if val == config.selectedGameName then gameSpinner.setSelection(idx - 1) break end
        end
    else
        gameSpinner.setSelection(0, false)
    end

    gameSpinner.setOnItemSelectedListener(Spinner.OnItemSelectedListener({
        onItemSelected = function(parent, view, position, id)
            dynamicSubLayout.removeAllViews()
            local posNum = tonumber(position) or 0
            selectedGameName = gameOptions[posNum + 1] or "Beggarmynaighbor"
            
            if selectedGameName == "Beggarmynaighbor" then
                selectedGameHealth = "5" 
            elseif selectedGameName == "Memory Game" then
                selectedGameHealth = "Easy"
                local lblDifficulty = TextView(activity)
                lblDifficulty.setText("\nSelect Difficulty:")
                lblDifficulty.setTextColor(0xFF000000)
                dynamicSubLayout.addView(lblDifficulty)
                
                local memDifficultySpinner = Spinner(activity)
                local memOptions = {"Easy", "Medium", "Hard"}
                local memAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, memOptions)
                memAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                memDifficultySpinner.setAdapter(memAdapter)
                dynamicSubLayout.addView(memDifficultySpinner)
                
                memDifficultySpinner.setOnItemSelectedListener(Spinner.OnItemSelectedListener({ 
                    onItemSelected = function(p, v, pos, i) 
                        local innerPos = tonumber(pos) or 0
                        selectedGameHealth = memOptions[innerPos + 1] or "Easy"
                    end,
                    onNothingSelected = function() end
                }))
            elseif selectedGameName == "Audio Free Fire" then
                selectedGameHealth = "100"
                local lblHealth = TextView(activity)
                lblHealth.setText("\nSelect Health:")
                lblHealth.setTextColor(0xFF000000)
                dynamicSubLayout.addView(lblHealth)
                
                local ffHealthSpinner = Spinner(activity)
                local ffOptions = {"100", "150", "200"}
                local ffAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, ffOptions)
                ffAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                ffHealthSpinner.setAdapter(ffAdapter)
                dynamicSubLayout.addView(ffHealthSpinner)
                
                ffHealthSpinner.setOnItemSelectedListener(Spinner.OnItemSelectedListener({ 
                    onItemSelected = function(p, v, pos, i) 
                        local innerPos = tonumber(pos) or 0
                        selectedGameHealth = ffOptions[innerPos + 1] or "100"
                    end,
                    onNothingSelected = function() end
                }))
            end
        end,
        onNothingSelected = function() end
    }))
    
    AlertDialog.Builder(activity)
    .setTitle(isUpdateMode and "Update Game Core" or "Create Custom Room")
    .setView(layout)
    .setPositiveButton(isUpdateMode and "Update" or "Create Room", config.wrapClickCallback(function()
        if isUpdateMode then
            config.onUpdateExecuted(selectedGameName, selectedGameHealth)
        else
            config.onCreateExecuted(selectedGameName, selectedGameHealth)
        end
    end)).show()
end

return onlineEngineHelper
