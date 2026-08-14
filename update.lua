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

-- FIX: Pehle check karein ke ActionBar exist karta hai ya nahi (Line 15 error fix)
if activity and activity.getActionBar() then
    activity.getActionBar().hide()
end

-- Yahan YouTube Production Studio walay VALID links lagaye gaye hain
local baseUrl = "https://raw.githubusercontent.com/youtubeproductionstudio-web/Yps/refs/heads/main/"
local updateURL = baseUrl .. "Version.txt" -- Version check ke liye file
local notesURL = baseUrl .. "Notes.txt"    -- Update notes ke liye file

-- Multi-file list: Yeh saari files update hongi
local filesToUpdate = {
    {name = "about.lua", url = baseUrl .. "about.lua"},
    {name = "beggar_my_neighbor.lua", url = baseUrl .. "beggar_my_neighbor.lua"},
    {name = "credits.lua", url = baseUrl .. "credits.lua"},
    {name = "welcome.lua", url = baseUrl .. "welcome.lua"},
    {name = "sound.lua", url = baseUrl .. "sound.lua"},
    {name = "AndroidManifest.xml", url = baseUrl .. "AndroidManifest.xml"},
    {name = "gamemenu.lua", url = baseUrl .. "gamemenu.lua"},
    {name = "main.lua", url = baseUrl .. "main.lua"},
    {name = "moreoption.lua", url = baseUrl .. "moreoption.lua"},
    {name = "profile.lua", url = baseUrl .. "profile.lua"},
    {name = "public_chat.lua", url = baseUrl .. "public_chat.lua"},
    {name = "receive_data.lua", url = baseUrl .. "receive_data.lua"},
    {name = "reply_manager.lua", url = baseUrl .. "reply_manager.lua"},
    {name = "send_data.lua", url = baseUrl .. "send_data.lua"},
    {name = "store.lua", url = baseUrl .. "store.lua"},
    {name = "settings.lua", url = baseUrl .. "settings.lua"},
    {name = "init.lua", url = baseUrl .. "init.lua"},    
    {name = "memory.lua", url = baseUrl .. "memory.lua"},
    {name = "update.lua", url = baseUrl .. "update.lua"},
    {name = "diagnostic_util.lua", url = baseUrl .. "diagnostic_util.lua"},
    {name = "main.lua", url = baseUrl .. "main.lua"},
    {name = "onlineEngineUI.lua", url = baseUrl .. "onlineEngineUI.lua"},
    {name = "onlineEngineHelper.lua", url = baseUrl .. "onlineEngineHelper.lua"},
    {name = "onlineengine.lua", url = baseUrl .. "onlineengine.lua"},
    {name = "NetworkEngine.lua", url = baseUrl .. "NetworkEngine.lua"},
    {name = "join.lua", url = baseUrl .. "join.lua"},
    {name = "GameModule.lua", url = baseUrl .. "GameModule.lua"},
    {name = "event.lua", url = baseUrl .. "event.lua"},
    {name = "GameLogicManager.lua", url = baseUrl .. "GameLogicManager.lua"}
}

-- Screen par message show karega
if activity then
    Toast.makeText(activity, "Checking for updates, please wait...", Toast.LENGTH_LONG).show()
end

local TAG = "LuaUpdater"
local currentVersion = "3.14"

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

local mainPath = currentDir .. "update.lua"

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

-- FIX: Ab yeh main.lua ka main UI flow call karega bina music loop double kiye
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
                        local ctx = activity -- APK ke liye context
                        if not isContextValid(ctx) then return end
                        
                        local updateAlertDlg = AlertDialog.Builder(ctx)
                        updateAlertDlg.setTitle("Update Available!")
                        
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
                            v.setText("Downloading... 0% (0.00 MB)")
                            v.setEnabled(false)
                            btnLater.setEnabled(false)
                            
                            local dirFile = File(currentDir)
                            if not dirFile.exists() then dirFile.mkdirs() end
                            
                            local totalBytesDownloaded = 0

                            -- Multi-file download loop function (New Logic with Progress & Retry)
                            local function downloadNextFile(index)
                                if index > #filesToUpdate then
                                    -- Saari files download ho gayi hain, ab version update.lua may replace karo
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
                                            successDialog.setTitle("Update Successful")
                                            
                                            math.randomseed(os.time())
                                            local messages = {
                                                [[Congratulations! You have successfully unlocked an incredible premium experience designed exclusively to elevate your journey to absolute perfection.
This feature is developed by Muhammad Hussain.]],
                                                [[Welcome to the future of pure premium entertainment where your satisfaction and engagement remain our absolute topmost priority.
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

                                -- Percentage aur MBs ki calculation
                                local percentage = math.floor(((index - 1) / #filesToUpdate) * 100)
                                local mbDownloaded = string.format("%.2f", totalBytesDownloaded / (1024 * 1024))
                                
                                -- Button Text pe status show karna
                                Handler(Looper.getMainLooper()).post(Runnable{run=function()
                                    if btnUpdate then
                                        btnUpdate.setText("Downloading... " .. percentage .. "% (" .. mbDownloaded .. " MB)")
                                    end
                                end})
                                
                                -- File download execute
                                Http.get(currentFile.url, function(c, content)
                                    local contentStr = tostring(content or "")
                                    
                                    -- Network Retry Logic (Agar download theek se nahi hua tou 2 seconds baad automatically retry karega)
                                    if c ~= 200 or content == nil or contentStr:gsub("^%s*(.-)%s*$", "%1") == "" then
                                        Handler(Looper.getMainLooper()).postDelayed(Runnable{run=function()
                                            if not isContextValid(ctx) then return end
                                            downloadNextFile(index) 
                                        end}, 2000)
                                        return
                                    end
                                    
                                    totalBytesDownloaded = totalBytesDownloaded + #contentStr
                                    
                                    local filePath = currentDir .. currentFile.name
                                    local f, fErr = io.open(filePath, "w")
                                    if f then 
                                        f:write(contentStr) 
                                        f:close() 
                                        downloadNextFile(index + 1)
                                    else
                                        -- Storage Error Alert (Kyunke memory full hone par humein user ko alert karna zaruri hai)
                                        Handler(Looper.getMainLooper()).post(Runnable{run=function()
                                            if not isContextValid(ctx) then return end
                                            local retryDlg = AlertDialog.Builder(ctx)
                                            retryDlg.setTitle("Storage Error")
                                            retryDlg.setMessage("Failed to save " .. currentFile.name .. ".\nDo you want to retry?")
                                            retryDlg.setPositiveButton("Retry", function()
                                                downloadNextFile(index)
                                            end)
                                            retryDlg.setNegativeButton("Cancel", function()
                                                closeToolCompletely(ctx)
                                            end)
                                            retryDlg.setCancelable(false)
                                            retryDlg.show()
                                        end})
                                        return
                                    end
                                end)
                            end
                            
                            -- Pehli file se download process shuru karein
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
