local memoryModule = {}

function memoryModule.start(params)
    local activity = params.activity
    local mainUI = params.mainUI
    local difficulty = params.difficulty
    
    -- SharedPreferences setup for stats integration
    local prefs = activity.getSharedPreferences("userdata", 0)
    local editor = prefs.edit()

    local MediaPlayer = luajava.bindClass("android.media.MediaPlayer")
    local FileClass = luajava.bindClass("java.io.File")
    local ColorClass = luajava.bindClass("android.graphics.Color")
    local HandlerClass = luajava.bindClass("android.os.Handler")
    local LooperClass = luajava.bindClass("android.os.Looper")
    local RunnableClass = luajava.bindClass("java.lang.Runnable")
    local View = luajava.bindClass("android.view.View")
    local AlertDialog = luajava.bindClass("android.app.AlertDialog")

    local totalBoxes = 30
    if difficulty == "Medium" then totalBoxes = 38 end
    if difficulty == "Hard" then totalBoxes = 62 end

    -----------------------------------------------------
    -- SAFE REUSABLE SOUND SYSTEM
    -----------------------------------------------------
    local activePlayers = {}

    local function safeReleasePlayer(mp)
        if mp then
            pcall(function()
                if mp.isPlaying() then mp.stop() end
                mp.release()
            end)
            -- Remove from active players list
            for i, v in ipairs(activePlayers) do
                if v == mp then
                    table.remove(activePlayers, i)
                    break
                end
            end
        end
    end

    local function findSoundPath(soundName)
        local baseDir = activity.getLuaDir()
        local pathsToTry = {
            baseDir .. "/" .. soundName,
            baseDir .. "/./" .. soundName,
            "/storage/emulated/0/" .. soundName
        }
        for _, p in ipairs(pathsToTry) do
            local f = FileClass(p)
            if f.exists() and f.isFile() then
                return p
            end
        end
        return nil
    end

    local function playSound(soundName)
        pcall(function()
            local validPath = findSoundPath(soundName)
            if not validPath then return end -- Gracefully exit if file is missing
            
            local mp = MediaPlayer()
            mp.setDataSource(validPath)
            mp.prepare()
            mp.start()
            
            table.insert(activePlayers, mp)
            
            mp.setOnCompletionListener({
                onCompletion = function(mediaPlayer)
                    safeReleasePlayer(mediaPlayer)
                end
            })
        end)
    end
    -----------------------------------------------------

    local colorPool = {{c="#FF0000", name="Red color"}, {c="#0000FF", name="Blue color"}, {c="#008000", name="Green color"}, {c="#FFFF00", name="Yellow color"}, {c="#800080", name="Purple color"}, {c="#FFC0CB", name="Pink color"}, {c="#00FFFF", name="Cyan color"}, {c="#FF00FF", name="Magenta color"}, {c="#A52A2A", name="Brown color"}, {c="#00FF00", name="Lime color"}, {c="#008080", name="Teal color"}, {c="#000080", name="Navy color"}, {c="#800000", name="Maroon color"}, {c="#808000", name="Olive color"}, {c="#808080", name="Gray color"}}
    local fruitVegPool = {{e="馃崕", name="Apple"}, {e="馃崒", name="Banana"}, {e="馃崌", name="Grapes"}, {e="馃崜", name="Strawberry"}, {e="馃崏", name="Watermelon"}, {e="馃崚", name="Cherry"}, {e="馃崙", name="Peach"}, {e="4", name="Pineapple"}, {e="馃キ", name="Mango"}, {e="馃", name="Kiwi"}, {e="馃ゥ", name="Coconut"}, {e="馃", name="Carrot"}, {e="馃ウ", name="Broccoli"}, {e="馃崊", name="Tomato"}, {e="馃", name="Potato"}, {e="馃", name="Onion"}, {e="馃尳", name="Corn"}, {e="馃", name="Cucumber"}, {e="馃崋", name="Eggplant"}}
    local animalBirdPool = {{e="馃", name="Lion"}, {e="馃惎", name="Tiger"}, {e="馃悩", name="Elephant"}, {e="馃惖", name="Monkey"}, {e="馃惗", name="Dog"}, {e="馃惐", name="Cat"}, {e="馃惌", name="Mouse"}, {e="馃惢", name="Bear"}, {e="馃惏", name="Rabbit"}, {e="馃", name="Fox"}, {e="馃", name="Deer"}, {e="4", name="Zebra"}, {e="馃悇", name="Cow"}, {e="馃", name="Hedgehog"}, {e="馃悜", name="Sheep"}, {e="馃悙", name="Goat"}, {e="馃悢", name="Chicken"}, {e="馃", name="Duck"}, {e="馃", name="Eagle"}, {e="馃", name="Owl"}, {e="馃", name="Parrot"}, {e="馃惂", name="Penguin"}, {e="馃悕", name="Snake"}}

    local isAnimalLookup = {}
    for _, v in ipairs(animalBirdPool) do
        isAnimalLookup[v.name] = true
    end

    local gameDeck = {}
    if difficulty == "Easy" then for i=1, 15 do table.insert(gameDeck, colorPool[i]); table.insert(gameDeck, colorPool[i]) end
    elseif difficulty == "Medium" then for i=1, 19 do table.insert(gameDeck, fruitVegPool[i]); table.insert(gameDeck, fruitVegPool[i]) end
    elseif difficulty == "Hard" then for i=1, 23 do table.insert(gameDeck, animalBirdPool[i]); table.insert(gameDeck, animalBirdPool[i]) end for i=1, 4 do table.insert(gameDeck, fruitVegPool[i]); table.insert(gameDeck, fruitVegPool[i]) end for i=1, 4 do table.insert(gameDeck, colorPool[i]); table.insert(gameDeck, colorPool[i]) end end
    
    math.randomseed(os.time())
    for i = #gameDeck, 2, -1 do local j = math.random(i); gameDeck[i], gameDeck[j] = gameDeck[j], gameDeck[i] end

    local p1Score, p2Score, currentTurn, firstPick, isChecking = 0, 0, 1, nil, false
    local p1Guesses, p2Guesses = 0, 0
    local lastData1, lastData2 = nil, nil
    local isGameActive = true
    
    -- Safe Lua Table debounce lock to prevent runtime errors on Buttons
    local processingBoxes = {}

    local gridLayout = {LinearLayout, orientation="vertical", layout_width="fill", layout_height="wrap", gravity="center"}
    local btnIndex = 1
    for r = 1, math.ceil(totalBoxes / 5.0) do
        local rowLayout = {LinearLayout, orientation="horizontal", layout_width="fill", layout_height="wrap", layout_weight=1}
        for c = 1, 5 do
            if btnIndex <= totalBoxes then
                table.insert(rowLayout, {Button, id="membox_"..btnIndex, text=tostring(btnIndex), contentDescription="Box " .. btnIndex .. " unopened", textSize="24sp", textColor="#FFFFFF", layout_weight=1, layout_margin="2dp", layout_height="60dp", background="#FFA500"})
                btnIndex = btnIndex + 1
            end
        end
        table.insert(gridLayout, rowLayout)
    end

    local mainLayout = {LinearLayout, orientation="vertical", layout_width="fill", layout_height="fill", background="#000000",
        {LinearLayout, orientation="horizontal", layout_width="fill", padding="10dp",
            {TextView, id="p1Text", text="You: 0", textSize="18sp", textColor="#FF5555", layout_weight=1},
            {TextView, id="turnText", text="Turn: You", textSize="18sp", textColor="#FF5555", layout_weight=1, gravity="center"},
            {TextView, id="p2Text", text="Computer: 0", textSize="18sp", textColor="#5555FF", layout_weight=1, gravity="right"}
        },
        {ScrollView, layout_width="fill", layout_weight=1, gridLayout},
        {Button, id="backBtn", text="Exit Game", layout_width="fill"}
    }
    
    local mainLayoutView = loadlayout(mainLayout)
    activity.setContentView(mainLayoutView)
    
    local function openBox(index)
        local btn, data = _G["membox_"..index], gameDeck[index]
        
        if currentTurn == 1 then
            if data.c then 
                btn.setBackgroundColor(ColorClass.parseColor(data.c))
                btn.setText("") 
            else 
                btn.setBackgroundColor(ColorClass.parseColor("#333333"))
                btn.setText(data.e) 
            end
        else
            -- Ensure computer's pick remains visually hidden while sound/TTS still function
            btn.setBackgroundColor(ColorClass.parseColor("#FFA500"))
            btn.setText(tostring(index))
        end
        
        btn.setContentDescription("Box " .. index .. " opened. " .. data.name)
        
        playSound("sounds/open.mp3")
        
        if difficulty == "Hard" and isAnimalLookup[data.name] then
            local animalFileName = "sounds/" .. string.lower(data.name):gsub("%s+", "") .. ".mp3"
            playSound(animalFileName)
        end
    end

    -- End-game Dialog implementation with Rewards and Custom Buttons
    local function processGameOver(result)
        isGameActive = false
        
        -- Base Stats Save: Increment total played matches
        local matches = prefs.getInt("memory_matches", 0) + 1
        editor.putInt("memory_matches", matches)
        
        local titleStr = ""
        local msgStr = ""
        
        local statsSection = "\n\n📊 Current Game Statistics:\n• Your Score: " .. p1Score .. "\n• Computer Score: " .. p2Score
        
        if result == "win" then
            titleStr = "Congratulations"
            msgStr = "Congratulations!\n" ..
                     "You have won the game with an amazing performance!\n" ..
                     "Your memory skills are truly outstanding.\n" ..
                     "You successfully defeated the computer in this match.\n" ..
                     "Keep up the great work and take on harder challenges!" .. statsSection
            
            -- Increment wins count
            local wins = prefs.getInt("memory_wins", 0) + 1
            editor.putInt("memory_wins", wins)
            
            -- Coins logic implementation based on selected difficulty mode
            local currentCoins = prefs.getInt("coins", 0)
            local addedCoins = 6
            if difficulty == "Medium" then addedCoins = 7
            elseif difficulty == "Hard" then addedCoins = 8 end
            
            editor.putInt("coins", currentCoins + addedCoins)
            
            -- Play main.lua global sounds safely
            if _G.playSound then
                pcall(function() _G.playSound("/storage/emulated/0/瑙ｈ/Tools/ All Games Hub/sounds/Vin sound.mp3") end)
                pcall(function() _G.playSound("/storage/emulated/0/瑙ｈ/Tools/ All Games Hub/sounds/Coins.mp3") end)
            end
            
        elseif result == "lose" then
            titleStr = "Computer Wins"
            msgStr = "Better luck next time!\n" ..
                     "The computer managed to outsmart you in this round.\n" ..
                     "Don't give up.\n" ..
                     "Keep practicing to sharpen your memory.\n" ..
                     "Play again to reclaim your well-deserved victory!" .. statsSection
            
            -- Increment losses count
            local losses = prefs.getInt("memory_losses", 0) + 1
            editor.putInt("memory_losses", losses)
            
            -- Play main.lua global lose sound
            if _G.playSound then
                pcall(function() _G.playSound("/storage/emulated/0/瑙ｈ/Tools/ All Games Hub/sounds/laugh4.mp3") end)
            end
            
        elseif result == "draw" then
            titleStr = "Match Draw"
            msgStr = "It's a Match Draw!\n" ..
                     "Both you and the computer played excellently.\n" ..
                     "You both finished with equal strength and sharp memory.\n" ..
                     "Play another round to break the tie and prove who is better!" .. statsSection
        end
        
        editor.apply()
        
        -- Show Game Over Alert Dialog with Play Again, Back To Main Menu & General Share options
        AlertDialog.Builder(activity)
            .setTitle(titleStr)
            .setMessage(msgStr)
            .setCancelable(false)
            .setPositiveButton("Play Again", {onClick=function()
                memoryModule.start(params)
            end})
            .setNegativeButton("Back To Main Menu", {onClick=function()
                mainUI()
            end})
            .setNeutralButton("Share Results", {onClick=function()
                local shareText = "🎮 *Memory Game Match Results* 🎮\n\n" ..
                                  "Hey everyone! I just finished an intense match of the Memory Game and wanted to share my results with you all.\n\n" ..
                                  "🏆 *Match Outcome:* " .. titleStr .. "\n" ..
                                  "⚙️ *Difficulty Level:* " .. difficulty .. "\n\n" ..
                                  "📊 *Current Game Statistics*:\n" ..
                                  "👤 My Final Score: " .. p1Score .. "\n" ..
                                  "🤖 Computer's Final Score: " .. p2Score .. "\n\n" ..
                                  "It was a great test of memory and concentration! Can you beat my score? Download the game and let's find out who has the sharpest mind!\n\n" ..
                                  "👨‍💻 *Proudly Developed By:*\n" ..
                                  "Muzammil Muneer And Muhammad Hussain"
                
                pcall(function()
                    local Intent = luajava.bindClass("android.content.Intent")
                    local intent = Intent(Intent.ACTION_SEND)
                    intent.setType("text/plain")
                    intent.putExtra(Intent.EXTRA_TEXT, shareText)
                    
                    local chooser = Intent.createChooser(intent, "Share Results via...")
                    activity.startActivity(chooser)
                end)
                processGameOver(result)
            end})
            .show()
    end

    local function checkGameCompletion()
        local allCleared = true
        for i=1, totalBoxes do
            if _G["membox_"..i].getVisibility() == View.VISIBLE then
                allCleared = false
                break
            end
        end
        
        if allCleared then
            if p1Score > p2Score then
                processGameOver("win")
            elseif p2Score > p1Score then
                processGameOver("lose")
            else
                processGameOver("draw")
            end
        end
    end

    -- Forward declarations for functions
    local checkMatch
    local computerTurn

    checkMatch = function(pick1, pick2)
        lastData1, lastData2 = pick1.data, pick2.data
        local h = HandlerClass(LooperClass.getMainLooper())
        
        if currentTurn == 1 then
            p1Guesses = p1Guesses + 1
        else
            p2Guesses = p2Guesses + 1
        end
        
        local isMatch = (pick1.data.name == pick2.data.name)
        local matchStatus = isMatch and "Correct guess!" or "Incorrect guess!"
        
        -- Integration: Save player's correct/total guesses to Profile
        if currentTurn == 1 then
            local currentTotal = prefs.getInt("mem_total_guesses", 0) + 1
            editor.putInt("mem_total_guesses", currentTotal)
            
            if isMatch then
                local currentCorrect = prefs.getInt("mem_correct_guesses", 0) + 1
                editor.putInt("mem_correct_guesses", currentCorrect)
            end
            editor.apply()
        end
        
        if isMatch then
            if currentTurn == 1 then 
                p1Score = p1Score + 1
                p1Text.setText("You: " .. p1Score)
                playSound("sounds/guess.mp3") 
            else 
                p2Score = p2Score + 1
                p2Text.setText("Computer: " .. p2Score)
                playSound("sounds/guess.mp3") 
            end
        else
            playSound("sounds/wrong.mp3")
        end

        if _G.ttsAnnounce then _G.ttsAnnounce(matchStatus) end
        
        h.postDelayed(RunnableClass({run = function()
            if isMatch then
                -- Retaining your exact style preferences: blocks hide upon matching
                pick1.btn.setVisibility(View.INVISIBLE)
                pick2.btn.setVisibility(View.INVISIBLE)
                firstPick = nil
                isChecking = false
                
                checkGameCompletion()
                
                if currentTurn == 2 and isGameActive then
                    h.postDelayed(RunnableClass({run = function() computerTurn() end}), 1000)
                end
            else
                pick1.btn.setBackgroundColor(ColorClass.parseColor("#FFA500"))
                pick1.btn.setText(tostring(pick1.index))
                pick1.btn.setContentDescription("Box " .. pick1.index .. " unopened")
                
                pick2.btn.setBackgroundColor(ColorClass.parseColor("#FFA500"))
                pick2.btn.setText(tostring(pick2.index))
                pick2.btn.setContentDescription("Box " .. pick2.index .. " unopened")
                
                firstPick = nil
                isChecking = false
                currentTurn = currentTurn == 1 and 2 or 1
                turnText.setText(currentTurn == 1 and "Turn: You" or "Turn: Computer")
                
                if currentTurn == 1 then
                    if _G.ttsAnnounce then _G.ttsAnnounce("Now it is your turn.") end
                else
                    if _G.ttsAnnounce then _G.ttsAnnounce("Now it is the computer's turn.") end
                    if isGameActive then
                        h.postDelayed(RunnableClass({run = function() computerTurn() end}), 1500) 
                    end
                end
            end
        end}), 2000)
    end

    computerTurn = function()
        if not isGameActive then return end
        local h = HandlerClass(LooperClass.getMainLooper())
        isChecking = true 

        h.postDelayed(RunnableClass({run = function()
            local available = {}
            for i=1, totalBoxes do if _G["membox_"..i].getVisibility() == View.VISIBLE then table.insert(available, i) end end
            if #available < 2 then 
                isChecking = false
                checkGameCompletion()
                return 
            end
            
            local p1_idx, p2_idx
            local calculatedMatch = false
            
            -- Smart Tweak: 35% chance computer will intentionally look for an available matching pair
            if math.random(1, 100) <= 35 then
                for i = 1, #available - 1 do
                    for j = i + 1, #available do
                        local index1 = available[i]
                        local index2 = available[j]
                        if gameDeck[index1].name == gameDeck[index2].name then
                            p1_idx = index1
                            p2_idx = index2
                            calculatedMatch = true
                            break
                        end
                    end
                    if calculatedMatch then break end
                end
            end
            
            -- Fallback if 35% rule misses or no matches are left on board
            if not calculatedMatch then
                p1_idx = available[math.random(1, #available)]
                p2_idx = available[math.random(1, #available)]
                while p2_idx == p1_idx do p2_idx = available[math.random(1, #available)] end
            end
            
            openBox(p1_idx)
            if _G.ttsAnnounce then _G.ttsAnnounce("Box " .. p1_idx .. " contains " .. gameDeck[p1_idx].name) end
            
            h.postDelayed(RunnableClass({run = function()
                openBox(p2_idx)
                if _G.ttsAnnounce then _G.ttsAnnounce("Box " .. p2_idx .. " contains " .. gameDeck[p2_idx].name) end
                
                h.postDelayed(RunnableClass({run = function()
                    checkMatch({btn=_G["membox_"..p1_idx], index=p1_idx, data=gameDeck[p1_idx]}, {btn=_G["membox_"..p2_idx], index=p2_idx, data=gameDeck[p2_idx]})
                end}), 1500)
                
            end}), 1800) 
            
        end}), 1500)
    end

    -- Gestures
    local gestureListener = luajava.createProxy("android.view.GestureDetector$OnGestureListener", {
        onFling = function(e1, e2, vx, vy)
            if e1 == nil or e2 == nil then return false end
            local dx = e2.getX() - e1.getX(); local dy = e2.getY() - e1.getY()
            if math.abs(dy) > math.abs(dx) and dy < -100 then if _G.ttsAnnounce then _G.ttsAnnounce(currentTurn == 1 and "It's your turn." or "It's the computer's turn.") end
            elseif dx < -100 then if _G.ttsAnnounce then _G.ttsAnnounce("Total score. You " .. p1Score .. ", Computer " .. p2Score) end
            elseif dx > 100 then if _G.ttsAnnounce then if lastData1 then _G.ttsAnnounce("Last opened: " .. lastData1.name .. " and " .. lastData2.name) end end end
            return true
        end, 
        onDown = function() return true end,
        onLongPress = function() end,
        onScroll = function() return false end,
        onShowPress = function() end,
        onSingleTapUp = function() return false end
    })
    
    local detector = luajava.bindClass("android.view.GestureDetector")(activity, gestureListener)
    mainLayoutView.setOnTouchListener({onTouch = function(v, event) 
        detector.onTouchEvent(event)
        return false 
    end})

    for i=1, totalBoxes do
        _G["membox_"..i].onClick = function(v)
            if currentTurn ~= 1 or isChecking or v.getVisibility() == View.INVISIBLE or (firstPick and firstPick.index == i) then return end
            
            -- Checked Fix: Clean Table implementation for multi-tap prevention
            if processingBoxes[i] then return end
            processingBoxes[i] = true
            local lockHandler = HandlerClass(LooperClass.getMainLooper())
            lockHandler.postDelayed(RunnableClass({run = function() processingBoxes[i] = nil end}), 600)
            
            openBox(i)
            if _G.ttsAnnounce then _G.ttsAnnounce("Box " .. i .. " contains " .. gameDeck[i].name) end
            
            if not firstPick then 
                firstPick = {btn=v, index=i, data=gameDeck[i]} 
            else 
                isChecking = true 
                local h = HandlerClass(LooperClass.getMainLooper())
                h.postDelayed(RunnableClass({run = function()
                    checkMatch(firstPick, {btn=v, index=i, data=gameDeck[i]})
                end}), 1500)
            end
        end
    end

    -- Incomplete matches tracking when quitting halfway
    local showDialog = function() 
        AlertDialog.Builder(activity)
            .setTitle("Quit Game")
            .setMessage("Are you sure you want to quit the game?")
            .setPositiveButton("Yes", {onClick=function() 
                isGameActive = false
                
                -- Save incomplete stats to profile data registry
                local incompleted = prefs.getInt("memory_incompleted", 0) + 1
                local matches = prefs.getInt("memory_matches", 0) + 1
                editor.putInt("memory_incompleted", incompleted)
                editor.putInt("memory_matches", matches)
                editor.apply()
                
                for _, mp in ipairs(activePlayers) do safeReleasePlayer(mp) end
                mainUI() 
            end})
            .setNegativeButton("No", nil)
            .show() 
    end
    
    backBtn.onClick = showDialog
    
    mainLayoutView.setFocusableInTouchMode(true)
    mainLayoutView.requestFocus()
    mainLayoutView.setOnKeyListener(luajava.createProxy("android.view.View$OnKeyListener", {
        onKey = function(v, keyCode, event)
            if keyCode == 4 then
                if event.getAction() == 1 then
                    showDialog()
                end
                return true
            end
            return false
        end
    }))
end

return memoryModule
