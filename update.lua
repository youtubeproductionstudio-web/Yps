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

-- ActionBar check fix
if activity and activity.getActionBar() then
    activity.getActionBar().hide()
end

-- YouTube Production Studio links
local baseUrl = "https://raw.githubusercontent.com/youtubeproductionstudio-web/Yps/refs/heads/main/"
local updateURL = baseUrl .. "Version.txt"
local notesURL = baseUrl .. "Notes.txt"

-- Default Fallback Multi-file List
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
    {name = "onlineEngineUI.lua", url = baseUrl .. "onlineEngineUI.lua"},
    {name = "onlineEngineHelper.lua", url = baseUrl .. "onlineEngineHelper.lua"},
    {name = "onlineengine.lua", url = baseUrl .. "onlineengine.lua"},
    {name = "NetworkEngine.lua", url = baseUrl .. "NetworkEngine.lua"},
    {name = "join.lua", url = baseUrl .. "join.lua"},
    {name = "GameModule.lua", url = baseUrl .. "GameModule.lua"},
    {name = "event.lua", url = baseUrl .. "event.lua"},
    {name = "GameLogicManager.lua", url = baseUrl .. "GameLogicManager.lua"}
}

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
        pcall(function() currentDir = tostring(activity.getLuaDir()) .. "/" end)
    end
end

if not currentDir or currentDir == "" then
    currentDir = "/storage/emulated/0/解说/Tools/Card games version 1.1./"
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
                        local ctx = activity
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
                            v.setText("Downloading...")
                            v.setEnabled(false)
                            btnLater.setEnabled(false)
                            
                            local dirFile = File(currentDir)
                            if not dirFile.exists() then dirFile.mkdirs() end
                            
                            -- Multi-file download loop function
                            local function downloadNextFile(index)
                                if index > #filesToUpdate then
                                    -- Saari files (nayi + purani) download hone ke baad version update karo
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

                                            -- RESTART RULE: User Click par App Finish hogi taake updated code next launch par chale
                                            local btnRestart = currentSuccessDialog.getButton(AlertDialog.BUTTON_POSITIVE)
                                            btnRestart.onClick = function(vx)
                                                closeToolCompletely(ctx)
                                            end
                                        end})
                                    else
                                        showErrorDialog(ctx, "Update apply karte waqt error aaya. Update file ko likhne mein masla hai.")
                                    end
                                    return
                                end
                                
                                local currentFile = filesToUpdate[index]
                                Http.get(currentFile.url, function(c, content)
                                    if c ~= 200 or not content or tostring(content):gsub("^%s*(.-)%s*$", "%1") == "" then
                                        showErrorDialog(ctx, "Download failed for " .. currentFile.name .. ". Please check internet connection.")
                                        return
                                    end
                                    
                                    local filePath = currentDir .. currentFile.name
                                    
                                    -- Auto-create missing subdirectories if any
                                    local targetFile = File(filePath)
                                    local parentDir = targetFile.getParentFile()
                                    if parentDir and not parentDir.exists() then
                                        parentDir.mkdirs()
                                    end
                                    
                                    local f, fErr = io.open(filePath, "w")
                                    if f then 
                                        f:write(tostring(content)) 
                                        f:flush()
                                        f:close() 
                                        downloadNextFile(index + 1)
                                    else
                                        showErrorDialog(ctx, "Failed to write data to " .. currentFile.name)
                                        return
                                    end
                                end)
                            end
                            
                            -- FIX: 100% Guaranteed Dynamic Server Manifest Extractor
                            Http.get(baseUrl .. "update.lua", function(lCode, lContent)
                                if lCode == 200 and lContent then
                                    local remoteCode = tostring(lContent)
                                    
                                    -- Remote BaseURL extract
                                    local serverBaseUrl = remoteCode:match('local%s+baseUrl%s*=%s*["\'](.-)["\']')
                                    if not serverBaseUrl or serverBaseUrl == "" then
                                        serverBaseUrl = baseUrl
                                    end
                                    
                                    -- Remote code se tamaam filenames pull karna (Zero Loadstring Dependency)
                                    local dynamicFilesList = {}
                                    local seenFiles = {}
                                    
                                    for fileName in remoteCode:gmatch('name%s*=%s*["\']([^"\']+)["\']') do
                                        if fileName and fileName ~= "" and not seenFiles[fileName] then
                                            seenFiles[fileName] = true
                                            table.insert(dynamicFilesList, {
                                                name = fileName,
                                                url = serverBaseUrl .. fileName
                                            })
                                        end
                                    end
                                    
                                    if #dynamicFilesList > 0 then
                                        filesToUpdate = dynamicFilesList
                                        Log.i(TAG, "Successfully extracted " .. tostring(#filesToUpdate) .. " files from remote update.lua")
                                    end
                                end
                                
                                -- Downloads start kar do (Saari nayi aur purani files fully sync ho jayengi)
                                downloadNextFile(1)
                            end)
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
