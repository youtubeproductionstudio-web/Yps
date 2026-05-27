local settings = {}

function settings.show(activity, mainUIFunc, usernameScreenFunc, prefs, editor, playSoundFunc, clickSound)
    
    local function styleButton(btn)
        if btn then
            btn.setTextColor(Color.BLACK)
            btn.setBackgroundColor(Color.WHITE)
        end
    end

    local function wrapClick(btn, func)
        if btn then
            btn.onClick = function()
                playSoundFunc(clickSound)
                if func then func() end
            end
        end
    end

    local function showDedicatedSoundSettingsMenu(parentDialog)
        local sv = ScrollView(activity)
        local layout = LinearLayout(activity)
        layout.setOrientation(1)
        layout.setBackgroundColor(0xFF000000)
        layout.setPadding(30, 30, 30, 30)
        sv.addView(layout)

        local titleText = TextView(activity)
        titleText.setText("Audio & Volume Settings")
        titleText.setTextSize(20)
        titleText.setTextColor(0xFFFFD700)
        titleText.setGravity(Gravity.CENTER)
        titleText.setPadding(0, 0, 0, 20)
        layout.addView(titleText)

        local function createSoundRow(labelName, key)
            local itemContainer = LinearLayout(activity)
            itemContainer.setOrientation(1)
            itemContainer.setPadding(0, 10, 0, 10)

            local topRow = LinearLayout(activity)
            topRow.setOrientation(0)
            topRow.setGravity(Gravity.CENTER_VERTICAL)

            local lbl = TextView(activity)
            lbl.setText(labelName)
            lbl.setTextColor(Color.WHITE)
            lbl.setLayoutParams(LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0))

            local sw = Switch(activity)
            sw.setChecked(prefs.getBoolean("sw_"..key, true))

            topRow.addView(lbl)
            topRow.addView(sw)
            itemContainer.addView(topRow)

            local sb = SeekBar(activity)
            sb.setMax(100)
            sb.setProgress(prefs.getInt("vol_"..key, 50))
            sb.setPadding(0, 10, 0, 10)
            itemContainer.addView(sb)

            layout.addView(itemContainer)

            sb.setOnSeekBarChangeListener(SeekBar.OnSeekBarChangeListener{
                onProgressChanged=function(b, p, f)
                    editor.putInt("vol_"..key, p).apply()
                    if key:find("bgm") and _G.bgmPlayer and _G.currentBgmPath:find(key:sub(-1)) then
                        local v = p / 100
                        pcall(function() _G.bgmPlayer.setVolume(v, v) end)
                    end
                end
            })

            sw.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener{
                onCheckedChanged=function(b, c)
                    editor.putBoolean("sw_"..key, c).apply()
                    if key:find("bgm") then
                        if c then 
                            if _G.currentBgmPath ~= "" then _G.playBGM(_G.currentBgmPath) end
                        else 
                            if _G.bgmPlayer and _G.currentBgmPath:find(key:sub(-1)) then _G.stopBGM() end
                        end
                    end
                end
            })
        end

        createSoundRow("Click Sound", "click")
        createSoundRow("Play Card Sound", "play")
        createSoundRow("Shuffle Sound", "shuffle")
        createSoundRow("Win Sound", "win")
        createSoundRow("Lose Sound", "lose")
        createSoundRow("Background Music 1", "bgm1")
        createSoundRow("Background Music 2", "bgm2")
        createSoundRow("Background Music 3", "bgm3")
        createSoundRow("Background Music 4", "bgm4")

        local backBtn = Button(activity)
        backBtn.setText("Save & Return")
        styleButton(backBtn)
        local btnParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        btnParams.setMargins(0, 20, 0, 10)
        layout.addView(backBtn, btnParams)

        local soundDialog = AlertDialog.Builder(activity, android.R.style.Theme_Black_NoTitleBar_Fullscreen).create()
        soundDialog.setView(sv)
        soundDialog.show()

        wrapClick(backBtn, function()
            soundDialog.dismiss()
            parentDialog.show()
        end)
        soundDialog.setOnCancelListener(DialogInterface.OnCancelListener{
            onCancel=function(dialog) parentDialog.show() end
        })
    end

    local function showFullSettingsDialog()
        local sv = ScrollView(activity)
        local layout = LinearLayout(activity)
        layout.setOrientation(1)
        layout.setBackgroundColor(0xFF000000)
        layout.setPadding(30, 30, 30, 30)
        sv.addView(layout)

        local settingsText = TextView(activity)
        settingsText.setText("Settings Menu")
        settingsText.setTextSize(22)
        settingsText.setTextColor(Color.WHITE)
        settingsText.setGravity(Gravity.CENTER)
        settingsText.setPadding(0, 0, 0, 25)
        layout.addView(settingsText)

        local changeNameBtn = Button(activity)
        changeNameBtn.setText("Change Username")
        styleButton(changeNameBtn)
        local nameParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        nameParams.setMargins(0, 5, 0, 15)
        layout.addView(changeNameBtn, nameParams)

        local resetDataBtn = Button(activity)
        resetDataBtn.setText("Reset Game Data")
        styleButton(resetDataBtn)
        local resetParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        resetParams.setMargins(0, 5, 0, 15)
        layout.addView(resetDataBtn, resetParams)

        local soundConfigBtn = Button(activity)
        soundConfigBtn.setText("Sound Settings")
        styleButton(soundConfigBtn)
        local soundParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        soundParams.setMargins(0, 5, 0, 25)
        layout.addView(soundConfigBtn, soundParams)

        local saveBtn = Button(activity)
        saveBtn.setText("Back & Save")
        styleButton(saveBtn)
        layout.addView(saveBtn)

        local versionText = TextView(activity)
        versionText.setText("Version 1.1")
        versionText.setTextSize(14)
        versionText.setTextColor(0x88FFFFFF)
        versionText.setGravity(Gravity.CENTER)
        versionText.setPadding(0, 40, 0, 10)
        layout.addView(versionText)

        local ds = AlertDialog.Builder(activity, android.R.style.Theme_Black_NoTitleBar_Fullscreen).create()
        ds.setView(sv)
        ds.show()

        wrapClick(changeNameBtn, function()
            ds.dismiss()
            usernameScreenFunc()
        end)

        wrapClick(resetDataBtn, function()
            AlertDialog.Builder(activity)
                .setTitle("Reset Data")
                .setMessage("Are you sure you want to reset all game statistics, coins, and purchased keys?")
                .setPositiveButton("Yes", DialogInterface.OnClickListener{
                    onClick = function(dialog, which)
                        local currentUname = prefs.getString("username", "")
                        if currentUname ~= "" then
                            local firebaseUrl = "https://card-games-muzammil-munir-default-rtdb.firebaseio.com/users/"
                            local oldNodeKey = currentUname:lower():gsub(" ", "%%20")
                            local deleteUrl = firebaseUrl .. oldNodeKey .. ".json?x-http-method-override=DELETE"
                            pcall(function()
                                Http.post(deleteUrl, "", function(delCode, delContent) end)
                            end)
                        end

                        editor.remove("username")
                        editor.remove("userid")
                        editor.putInt("coins", 0)
                        
                        -- BMN Stats Reset
                        editor.putInt("bmn_played", 0)
                        editor.putInt("bmn_wins", 0)
                        editor.putInt("bmn_losses", 0)
                        editor.putInt("bmn_incompleted", 0)
                        editor.putInt("bmn_p_cards", 0)
                        editor.putInt("bmn_c_cards", 0)
                        editor.putInt("bmn_p_piles", 0)
                        editor.putInt("bmn_cPiles", 0)
                        
                        -- Memory Game Stats Reset
                        editor.putInt("memory_matches", 0)
                        editor.putInt("memory_wins", 0)
                        editor.putInt("memory_losses", 0)
                        editor.putInt("memory_incompleted", 0)
                        editor.putInt("mem_correct_guesses", 0)
                        editor.putInt("mem_total_guesses", 0)
                        
                        -- Store Keys Reset
                        editor.putInt("memory_keys", 0)
                        editor.putInt("public_chat_keys", 0)
                        
                        editor.putString("adHourlyHistory", "")
                        editor.putBoolean("first_run", true)
                        editor.apply()
                        
                        ds.dismiss()
                        
                        if startAppUiFlow then
                            startAppUiFlow()
                        else
                            mainUIFunc()
                        end
                    end
                })
                .setNegativeButton("No", nil)
                .show()
        end)

        wrapClick(soundConfigBtn, function()
            ds.dismiss()
            showDedicatedSoundSettingsMenu(ds)
        end)

        wrapClick(saveBtn, function()
            ds.dismiss()
            mainUIFunc()
        end)
        ds.setOnCancelListener(DialogInterface.OnCancelListener{
            onCancel=function(dialog) mainUIFunc() end
        })
    end

    showFullSettingsDialog()
end

return settings
