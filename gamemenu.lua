local gamesMenuModule = {}

function gamesMenuModule.show(params)
    local activity = params.activity
    local mainUI = params.mainUI
    local gameMainUI = params.gameMainUI
    local memoryMainUI = params.memoryMainUI 
    local playBGM = params.playBGM
    local wrapClick = params.wrapClick
    local styleButton = params.styleButton
    local whiteText = params.whiteText
    
    local bgm2Path = params.bgm2Path
    local bgm3Path = params.bgm3Path
    local bgm4Path = params.bgm4Path

    playBGM(bgm4Path)

    -- SharedPreferences for read/write key data
    local prefs = activity.getSharedPreferences("userdata", 0)
    local editor = prefs.edit()

    local layoutGM = {
        LinearLayout,
        orientation="vertical",
        background="#000000",
        layout_width="fill",
        gravity="center",
        padding="20dp",
        {TextView, id="gmHead", text="Select Your Game", textSize="18sp", layout_marginBottom="20dp"},
        {Button, id="playCardBtn", text="beggar my neighbor", layout_width="fill", layout_marginBottom="15dp"},
        {Button, id="memoryBtn", text="Memory Game", layout_width="fill", layout_marginBottom="15dp"}, 
        {Button, id="backToHomeBtn", text="Back to Home", layout_width="fill"}
    }

    local vgm = loadlayout(layoutGM)
    whiteText(gmHead)
    styleButton(playCardBtn)
    styleButton(memoryBtn)
    styleButton(backToHomeBtn)

    local dgm = AlertDialog.Builder(activity).create()
    dgm.setTitle("Games Menu")
    dgm.setView(vgm)
    dgm.show()

    wrapClick(playCardBtn, function()
        dgm.dismiss()
        
        local lobbyLayout = {
            LinearLayout,
            orientation="vertical",
            layout_width="fill",
            layout_height="fill",
            background="#000000",
            gravity="center",
            padding="20dp",
            {TextView, text="Welcome", textSize="30sp", textColor="#FFD700", layout_marginBottom="10dp", gravity="center"},
            {TextView, text="Get Ready for the Challenge", textSize="16sp", textColor="#FFFFFF", layout_marginBottom="40dp", gravity="center"},
            {Button, id="startGameBtn", text="Start Game", layout_width="fill", layout_marginBottom="20dp"},
            {Button, id="backToMenuBtn", text="Back", layout_width="fill"}
        }

        activity.setContentView(loadlayout(lobbyLayout))
        styleButton(startGameBtn)
        styleButton(backToMenuBtn)

        wrapClick(startGameBtn, function()
            playBGM(bgm3Path)
            gameMainUI()
        end)

        wrapClick(backToMenuBtn, function()
            playBGM(bgm4Path)
            mainUI()
        end)
    end)

    -- Memory Game Sound and Unlock Logic
    local keySoundPlayer = nil

    local function openMemoryGameWithSound()
        local loadingDialog = ProgressDialog(activity)
        loadingDialog.setMessage("Unlocking Memory Game...")
        loadingDialog.setCancelable(false)
        loadingDialog.show()
        
        local function openMemLobby()
            if loadingDialog and loadingDialog.isShowing() then
                loadingDialog.dismiss()
            end
            Toast.makeText(activity, "1 Memory Key used!", Toast.LENGTH_SHORT).show()
            
            dgm.dismiss()
            
            local memLobbyLayout = {
                LinearLayout,
                orientation="vertical",
                layout_width="fill",
                layout_height="fill",
                background="#000000",
                gravity="center",
                padding="20dp",
                {TextView, text="Welcome to memory game", textSize="28sp", textColor="#FFD700", layout_marginBottom="15dp", gravity="center"},
                {TextView, text="Choose difficulty", textSize="18sp", textColor="#FFFFFF", layout_marginBottom="10dp", gravity="center"},
                {Spinner, id="difficultySpinner", layout_width="fill", layout_marginBottom="20dp", background="#FFFFFF"},
                {Button, id="startMemBtn", text="Start Game", layout_width="fill", layout_marginBottom="20dp"},
                {Button, id="backToMenuBtn", text="Back", layout_width="fill"}
            }
            
            activity.setContentView(loadlayout(memLobbyLayout))
            
            -- Combo box choices
            local diffAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, String{"Easy", "Medium", "Hard"})
            diffAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            difficultySpinner.setAdapter(diffAdapter)

            styleButton(startMemBtn)
            styleButton(backToMenuBtn)

            wrapClick(startMemBtn, function()
                local selectedDiff = difficultySpinner.getSelectedItem()
                playBGM(bgm3Path)
                memoryMainUI(tostring(selectedDiff)) 
            end)

            wrapClick(backToMenuBtn, function()
                playBGM(bgm4Path)
                mainUI()
            end)
        end

        -- Corrected and streamlined dynamic app directories
        local pathsToTry = {
            tostring(activity.getLuaDir()) .. "/sounds/key.mp3",
            tostring(activity.getLuaDir()) .. "/sound/key.mp3"
        }
        
        local played = false
        for _, path in ipairs(pathsToTry) do
            local success, err = pcall(function()
                keySoundPlayer = MediaPlayer()
                keySoundPlayer.setDataSource(path)
                keySoundPlayer.prepare()
                keySoundPlayer.start()
                keySoundPlayer.setOnCompletionListener(MediaPlayer.OnCompletionListener{
                    onCompletion = function(v)
                        v.release()
                        keySoundPlayer = nil 
                        openMemLobby()
                    end
                })
            end)
            if success then
                played = true
                break
            end
        end
        
        if not played then
            openMemLobby()
        end
    end

    -- Memory Game Menu Logic
    wrapClick(memoryBtn, function()
        local memKeys = prefs.getInt("memory_keys", 0)
        local memWelcomeShown = prefs.getBoolean("memory_welcome_shown", false)

        if not memWelcomeShown then
            AlertDialog.Builder(activity)
                .setTitle("Welcome to Memory Game")
                .setMessage("Welcome! Let's unlock the Memory Game using 1 Memory Key to play.")
                .setCancelable(false)
                .setPositiveButton("Unlock", {onClick=function()
                    local currentKeys = prefs.getInt("memory_keys", 0)
                    if currentKeys > 0 then
                        editor.putInt("memory_keys", currentKeys - 1)
                        editor.putBoolean("memory_welcome_shown", true)
                        editor.apply()
                        openMemoryGameWithSound()
                    else
                        AlertDialog.Builder(activity)
                            .setTitle("Key Required")
                            .setMessage("You need a Memory Key to open the Memory Game. Please buy it from the Store.")
                            .setPositiveButton("Go to Store", {onClick=function()
                                dgm.dismiss()
                                local storeModule = require "store"
                                storeModule.show({ activity = activity, prefs = prefs, editor = editor, mainUI = mainUI, wrapClick = wrapClick, styleButton = styleButton, whiteText = whiteText })
                            end})
                            .setNegativeButton("Cancel", nil)
                            .show()
                    end
                end})
                .setNegativeButton("Cancel", nil)
                .show()
        else
            if memKeys > 0 then
                editor.putInt("memory_keys", memKeys - 1).apply()
                openMemoryGameWithSound()
            else
                AlertDialog.Builder(activity)
                    .setTitle("Key Required")
                    .setMessage("You need a Memory Key to open the Memory Game. Please buy it from the Store.")
                    .setPositiveButton("Go to Store", {onClick=function()
                        dgm.dismiss()
                        local storeModule = require "store"
                        storeModule.show({ activity = activity, prefs = prefs, editor = editor, mainUI = mainUI, wrapClick = wrapClick, styleButton = styleButton, whiteText = whiteText })
                    end})
                    .setNegativeButton("Cancel", nil)
                    .show()
            end
        end
    end)

    wrapClick(backToHomeBtn, function()
        dgm.dismiss()
    end)

    dgm.setOnCancelListener({onCancel=function() playBGM(bgm2Path) end})
    dgm.setOnDismissListener({onDismiss=function() playBGM(bgm2Path) end})
end

return gamesMenuModule
