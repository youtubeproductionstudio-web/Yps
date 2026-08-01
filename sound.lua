-- sound fixed auto update
require "import"
import "com.androlua.Http"
import "android.widget.Toast"
import "android.app.AlertDialog"
import "android.view.WindowManager"
import "android.os.Handler"
import "android.os.Looper"
import "java.io.File"
import "android.widget.ScrollView"
import "android.widget.LinearLayout"
import "android.widget.TextView"
import "android.util.Log"
import "android.content.DialogInterface"

if activity and activity.getActionBar() then
    activity.getActionBar().hide()
end

-- Yahan YouTube Production Studio walay VALID Sound links lagaye gaye hain
local baseUrl = "https://raw.githubusercontent.com/youtubeproductionstudio-web/Yps/refs/heads/main/sounds/"
local updateURL = "https://raw.githubusercontent.com/youtubeproductionstudio-web/Yps/refs/heads/main/sounds_virsion.txt"
local notesURL = "https://raw.githubusercontent.com/youtubeproductionstudio-web/Yps/refs/heads/main/SoundNotes.txt"

-- Multi-file list: Yeh saari sound files update hongi
local filesToUpdate = {
    {name = "BGM.ogg", url = baseUrl .. "BGM.ogg"},
    {name = "BGM 2.ogg", url = baseUrl .. "BGM%202.ogg"},
    {name = "BGM 3.ogg", url = baseUrl .. "BGM%203.ogg"},
    {name = "BGM 4.ogg", url = baseUrl .. "BGM%204.ogg"},
    {name = "card_shuffle.mp3", url = baseUrl .. "card_shuffle.mp3"},
    {name = "click.mp3", url = baseUrl .. "click.mp3"},
    {name = "key.mp3", url = baseUrl .. "key.mp3"}, 
    {name = "Coins.mp3", url = baseUrl .. "Coins.mp3"},
    {name = "guess.mp3", url = baseUrl .. "guess.mp3"},
    {name = "laugh4.mp3", url = baseUrl .. "laugh4.mp3"},
    {name = "leave.mp3", url = baseUrl .. "leave.mp3"},
    {name = "join.mp3", url = baseUrl .. "join.mp3"},
    {name = "perchased.mp3", url = baseUrl .. "perchased.mp3"},
    {name = "Play Card.mp3", url = baseUrl .. "Play%20Card.mp3"},
    {name = "receive.mp3", url = baseUrl .. "receive.mp3"},
    {name = "store.mp3", url = baseUrl .. "store.mp3"},
    {name = "send.mp3", url = baseUrl .. "send.mp3"},
    {name = "Vin sound.mp3", url = baseUrl .. "Vin%20sound.mp3"},
    {name = "wrong.mp3", url = baseUrl .. "wrong.mp3"},
    {name = "Open.mp3", url = baseUrl .. "Open.mp3"},
    {name = "greenparrot.mp3", url = baseUrl .. "greenparrot.mp3"},
    {name = "cat.mp3", url = baseUrl .. "cat.mp3"},
    {name = "horse.mp3", url = baseUrl .. "horse.mp3"},
    {name = "cricket.mp3", url = baseUrl .. "cricket.mp3"},
    {name = "rooster.mp3", url = baseUrl .. "rooster.mp3"},
    {name = "goat.mp3", url = baseUrl .. "goat.mp3"},
    {name = "donkey.mp3", url = baseUrl .. "donkey.mp3"},
    {name = "dog.mp3", url = baseUrl .. "dog.mp3"},
    {name = "sheep.mp3", url = baseUrl .. "sheep.mp3"},
    {name = "peacock.mp3", url = baseUrl .. "peacock.mp3"},
    {name = "turkey.mp3", url = baseUrl .. "turkey.mp3"},
    {name = "chicken.mp3", url = baseUrl .. "chicken.mp3"},
    {name = "duck.mp3", url = baseUrl .. "duck.mp3"},
    {name = "flamingo.mp3", url = baseUrl .. "flamingo.mp3"},
    {name = "penguin.mp3", url = baseUrl .. "penguin.mp3"},
    {name = "bear.mp3", url = baseUrl .. "bear.mp3"},
    {name = "cow.mp3", url = baseUrl .. "cow.mp3"},
    {name = "honeybee.mp3", url = baseUrl .. "honeybee.mp3"},
    {name = "eagle.mp3", url = baseUrl .. "eagle.mp3"},
    {name = "asiankoel.mp3", url = baseUrl .. "asiankoel.mp3"},
    {name = "crow.mp3", url = baseUrl .. "crow.mp3"},
    {name = "africangreyparrot.mp3", url = baseUrl .. "africangreyparrot.mp3"},
    {name = "camel.mp3", url = baseUrl .. "camel.mp3"},
    {name = "elephant.mp3", url = baseUrl .. "elephant.mp3"},
    {name = "frog.mp3", url = baseUrl .. "frog.mp3"},
    {name = "hippopotamus.mp3", url = baseUrl .. "hippopotamus.mp3"},
    {name = "lion.mp3", url = baseUrl .. "lion.mp3"},
    {name = "panda.mp3", url = baseUrl .. "panda.mp3"},
    {name = "rat.mp3", url = baseUrl .. "rat.mp3"},
    {name = "wolf.mp3", url = baseUrl .. "wolf.mp3"},
    {name = "zebra.mp3", url = baseUrl .. "zebra.mp3"}
}

-- Screen par message show karega (sighted + TalkBack dono ke liye)
if activity then
    Toast.makeText(activity, "Checking for sound updates, please wait...", Toast.LENGTH_LONG).show()
end

local TAG = "SoundUpdater"
local currentVersion = "1.5"

local currentPath = ...
local currentDir = nil

if currentPath and type(currentPath) == "string" then
    currentDir = currentPath:match("(.*/)")
end

if not currentDir then
    if activity then
        currentDir = tostring(activity.getLuaDir()) .. "/"
    else
        currentDir = "/storage/emulated/0/解说/Tools/Card games version 1.1./"
    end
end

if currentDir and not currentDir:find("/$") then
    currentDir = currentDir .. "/"
end

-- Sounds ko download karne ke liye specific folder
local soundsDir = currentDir .. "sounds/"

-- mainPath for updating version text
local mainPath = currentDir .. "sound.lua" 

Log.i(TAG, "Environment Path Auditing Logs")

local oldMainDialog = nil
local currentUpdateDialog = nil
local currentSuccessDialog = nil

local function isContextValid(ctx)
    if not ctx then return false end
    if activity then
        if activity.isFinishing() or activity.isDestroyed() then
            return false
        end
    end
    return true
end

local function closeToolCompletely(ctx)
    Log.w(TAG, "Terminating host environment completely.")
    pcall(function()
        if currentUpdateDialog and currentUpdateDialog.isShowing() then currentUpdateDialog.dismiss() end
        if currentSuccessDialog and currentSuccessDialog.isShowing() then currentSuccessDialog.dismiss() end
        if oldMainDialog and oldMainDialog.isShowing() then oldMainDialog.dismiss() end
    end)

    if activity then
        pcall(function() activity.finish() end)
    end
end

local function showErrorDialog(ctx, message)
    Handler(Looper.getMainLooper()).post(Runnable{run=function()
        if not isContextValid(ctx) then return end
        local errorDlg = AlertDialog.Builder(ctx)
        errorDlg.setTitle("Update Error")
        errorDlg.setMessage(message .. "\n\nThe tool will now close.")
        errorDlg.setPositiveButton("OK", function(d, w)
            closeToolCompletely(ctx)
        end)
        local d = errorDlg.create()
        d.setCancelable(false)
        pcall(function() d.show() end)
    end})
end

-- Yeh main.lua ka flow start karega sirf tab jab update ki zaroorat nahi hogi
local function runOriginalCode()
    if startAppUiFlow then
        startAppUiFlow()
    end
end

local function checkUpdate()
    Log.i(TAG, "Update checking started. Current local version: [" .. tostring(currentVersion) .. "]")
    Http.get(updateURL, function(code, response)
        if code == 200 and response then
            local rawOnlineVersion = tostring(response)
            local onlineVersion = rawOnlineVersion:gsub("[^%w%.%-]", "")
            
            if onlineVersion == "" then
                Log.e(TAG, "Sanitization error: onlineVersion payload reduced to empty string.")
                runOriginalCode()
                return
            end
            
            if onlineVersion ~= currentVersion then
                Http.get(notesURL, function(nCode, nResponse)
                    local notesText = ""
                    if nCode == 200 and nResponse then
                        notesText = tostring(nResponse)
                    end
                    
                    Handler(Looper.getMainLooper()).post(Runnable{run=function()
                        local ctx = activity -- APK ke liye sirf activity context
                        if not isContextValid(ctx) then return end
                        
                        local updateAlertDlg = AlertDialog.Builder(ctx)
                        updateAlertDlg.setTitle("Sound Update Available!")
                        
                        local scrollView = ScrollView(ctx)
                        local linearLayout = LinearLayout(ctx)
                        linearLayout.setOrientation(LinearLayout.VERTICAL)
                        linearLayout.setPadding(40, 40, 40, 40)
                        scrollView.addView(linearLayout)
                        
                        local tvServer = TextView(ctx)
                        tvServer.setText("Server Version: " .. onlineVersion)
                        tvServer.setTextSize(16)
                        linearLayout.addView(tvServer)
                        
                        local tvCurrent = TextView(ctx)
                        tvCurrent.setText("Your Version: " .. currentVersion .. "\n")
                        tvCurrent.setTextSize(16)
                        linearLayout.addView(tvCurrent)
                        
                        if notesText ~= "" then
                            for line in notesText:gmatch("[^\r\n]+") do
                                local tvLine = TextView(ctx)
                                tvLine.setText(line)
                                tvLine.setTextSize(15)
                                tvLine.setPadding(0, 0, 0, 10)
                                linearLayout.addView(tvLine)
                            end
                        end
                        
                        updateAlertDlg.setView(scrollView)
                        updateAlertDlg.setPositiveButton("Update", nil)
                        updateAlertDlg.setNegativeButton("Later", nil)
                        
                        updateAlertDlg.setOnCancelListener(DialogInterface.OnCancelListener{
                            onCancel = function(dialog)
                                closeToolCompletely(ctx)
                            end
                        })
                        
                        currentUpdateDialog = updateAlertDlg.create()
                        currentUpdateDialog.setCanceledOnTouchOutside(false)
                        
                        local successShow, errShow = pcall(function() currentUpdateDialog.show() end)
                        if not successShow then return end
                        
                        local btnUpdate = currentUpdateDialog.getButton(AlertDialog.BUTTON_POSITIVE)
                        local btnLater = currentUpdateDialog.getButton(AlertDialog.BUTTON_NEGATIVE)
                        
                        btnLater.onClick = function(v)
                            closeToolCompletely(ctx)
                        end

                        btnUpdate.onClick = function(v)
                            v.setText("Downloading... 0%")
                            v.setEnabled(false)
                            btnLater.setEnabled(false)
                            
                            local dirFile = File(soundsDir)
                            if not dirFile.exists() then dirFile.mkdirs() end
                            
                            local function downloadNextFile(index)
                                if index > #filesToUpdate then
                                    -- Saari files download ho gayi hain, ab version sound.lua may replace karo
                                    local writeSuccess = true
                                    local mf, mfErr = io.open(mainPath, "r")
                                    if mf then
                                        local mainContent = mf:read("*a")
                                        mf:close()
                                        
                                        local pattern = 'local%s+currentVersion%s*=%s*["\'](.-)["\']'
                                        local escapedOnlineVersion = onlineVersion:gsub("%%", "%%%%")
                                        local replacementString = 'local currentVersion = "' .. escapedOnlineVersion .. '"'
                                        
                                        local newMainContent, matchCount = mainContent:gsub(pattern, function() return replacementString end, 1)
                                        
                                        if matchCount > 0 and newMainContent and newMainContent ~= "" then
                                            local testFunc, compileErr = loadstring(newMainContent, "main_syntax_test")
                                            if testFunc then
                                                local mf2, mf2Err = io.open(mainPath, "w")
                                                if mf2 then 
                                                    mf2:write(newMainContent)
                                                    mf2:flush()
                                                    mf2:close() 
                                                    currentVersion = onlineVersion
                                                else
                                                    writeSuccess = false
                                                end
                                            else
                                                writeSuccess = false
                                            end
                                        else
                                            writeSuccess = false
                                        end
                                    else
                                        writeSuccess = false
                                    end
                                    
                                    if writeSuccess then
                                        Handler(Looper.getMainLooper()).post(Runnable{run=function()
                                            if currentUpdateDialog then
                                                pcall(function() currentUpdateDialog.dismiss() end)
                                                currentUpdateDialog = nil
                                            end
                                            
                                            if not isContextValid(ctx) then return end

                                            local successDialog = AlertDialog.Builder(ctx)
                                            successDialog.setTitle("Sound Update Successful")
                                            
                                            math.randomseed(os.time())
                                            local messages = {
                                                [[Congratulations! You have successfully downloaded the latest premium sound assets. Enjoy an incredible and immersive audio experience.
This feature is developed by Muhammad Hussain.]],
                                                [[Welcome to the future of pure premium entertainment! Your high-quality sound files have been successfully updated.
This feature is developed by Muhammad Hussain.]]
                                            }

                                            local msgIndex = math.random(1, #messages)
                                            local selectedMessage = messages[msgIndex]

                                            local successScrollView = ScrollView(ctx)
                                            local successLayout = LinearLayout(ctx)
                                            successLayout.setOrientation(LinearLayout.VERTICAL)
                                            successLayout.setPadding(40, 40, 40, 40)
                                            successScrollView.addView(successLayout)

                                            for line in selectedMessage:gmatch("[^\r\n]+") do
                                                local tvLine = TextView(ctx)
                                                tvLine.setText(line)
                                                tvLine.setTextSize(15)
                                                tvLine.setPadding(0, 0, 0, 12)
                                                successLayout.addView(tvLine)
                                            end

                                            successDialog.setView(successScrollView)
                                            successDialog.setCancelable(false)
                                            successDialog.setPositiveButton("Restart Now", nil)
                                            
                                            currentSuccessDialog = successDialog.create()
                                            
                                            local successDlgShow, errDlgShow = pcall(function() currentSuccessDialog.show() end)
                                            if not successDlgShow then return end

                                            local btnRestart = currentSuccessDialog.getButton(AlertDialog.BUTTON_POSITIVE)
                                            btnRestart.onClick = function(vx)
                                                pcall(function() 
                                                    if currentSuccessDialog and currentSuccessDialog.isShowing() then currentSuccessDialog.dismiss() end
                                                end)
                                                if activity then
                                                    pcall(function() activity.finish() end)
                                                end
                                            end
                                        end})
                                    else
                                        showErrorDialog(ctx, "Update apply karte waqt error aaya. Update file ko likhne mein masla hai.")
                                    end
                                    return
                                end
                                
                                local currentFile = filesToUpdate[index]
                                
                                -- Yahan percentage calculate ho rahi hai
                                local percentage = math.floor((index / #filesToUpdate) * 100)
                                
                                -- Percentage UI par update karein
                                Handler(Looper.getMainLooper()).post(Runnable{run=function()
                                    if btnUpdate then
                                        btnUpdate.setText("Downloading... " .. percentage .. "%")
                                    end
                                end})
                                
                                Http.get(currentFile.url, function(c, content)
                                    if c ~= 200 or not content or tostring(content):gsub("^%s*(.-)%s*$", "%1") == "" then
                                        showErrorDialog(ctx, "Download failed for " .. currentFile.name .. ". Please check internet connection.")
                                        return
                                    end
                                    
                                    local filePath = soundsDir .. currentFile.name
                                    local f, fErr = io.open(filePath, "w")
                                    if f then 
                                        f:write(tostring(content)) 
                                        f:close() 
                                        downloadNextFile(index + 1)
                                    else
                                        showErrorDialog(ctx, "Failed to write data to sounds folder for " .. currentFile.name)
                                        return
                                    end
                                end)
                            end
                            
                            downloadNextFile(1)
                        end
                    end})
                end)
            else
                runOriginalCode()
            end
        else
            runOriginalCode()
        end
    end)
end

checkUpdate()