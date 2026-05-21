local M = {}

function M.show(activity, mainUIFunc, usernameScreenFunc, prefs, editor, saveAdPreferences, canShowAdFunc, getRandomTimeFunc, getAdConfigFunc, configureWebViewFunc, playSoundFunc, clickSound, currentMainLayoutView, timerHandler, tickerRef)
    
    local isOpeningAd = false

    local layoutMO = { 
        LinearLayout, orientation="vertical", background="#000000", layout_width="fill", gravity="center", padding="16dp",
        {TextView, text="More Options", textSize="20sp", textColor="#FFFFFF", layout_marginBottom="20dp"},
        {Button, id="settingsBtn", text="Settings", layout_width="fill", layout_marginBottom="10dp"},
        {Button, id="adWatchBtn", text="Watch Ads & Earn Coins", layout_width="fill", layout_marginBottom="10dp"},
        {Button, id="backToMainBtn", text="Back to main screen", layout_width="fill"}
    }
    
    local view = loadlayout(layoutMO)
    
    local function styleButton(btn)
        if btn then
            btn.setTextColor(Color.BLACK)
            btn.setBackgroundColor(Color.WHITE)
        end
    end
    
    styleButton(settingsBtn)
    styleButton(adWatchBtn)
    styleButton(backToMainBtn)

    local dialog1 = AlertDialog.Builder(activity).create()
    dialog1.setView(view)
    dialog1.show()

    local function wrapClick(btn, func)
        if btn then
            btn.onClick = function()
                playSoundFunc(clickSound)
                if func then func() end
            end
        end
    end

    -- Background Silent Network/DNS Scan
    local function checkAdBlockingDNS()
        local detectedName = nil
        pcall(function()
            local Runtime = luajava.bindClass("java.lang.Runtime")
            local BufferedReader = luajava.bindClass("java.io.BufferedReader")
            local InputStreamReader = luajava.bindClass("java.io.InputStreamReader")
            
            local proc1 = Runtime.getRuntime().exec("getprop net.dns1")
            local reader1 = BufferedReader(InputStreamReader(proc1.getInputStream()))
            local dns1 = tostring(reader1.readLine() or ""):lower()
            
            local proc2 = Runtime.getRuntime().exec("getprop net.dns2")
            local reader2 = BufferedReader(InputStreamReader(proc2.getInputStream()))
            local dns2 = tostring(reader2.readLine() or ""):lower()

            if dns1:find("adguard") or dns2:find("adguard") then
                detectedName = "AdGuard Private DNS"
            elseif dns1:find("dns.adg") or dns2:find("dns.adg") then
                detectedName = "AdGuard Filtering Server"
            elseif dns1:find("adblock") or dns2:find("adblock") then
                detectedName = "Network AdBlocker Rule"
            elseif dns1:find("hosts") or dns2:find("hosts") then
                detectedName = "Modified Local Hosts File"
            end
        end)
        return detectedName
    end

    local function checkHourlyLimit()
        local currentTime = os.time()
        local adHistoryStr = prefs.getString("adHourlyHistory", "")
        local history = {}
        
        for timestamp in string.gmatch(adHistoryStr, "([^,]+)") do
            local t = tonumber(timestamp)
            if t and (currentTime - t) < 3600 then
                table.insert(history, t)
            end
        end
        
        if #history >= 10 then
            local oldestAd = history[1]
            local nextAvailableTime = oldestAd + 3600
            return false, nextAvailableTime
        end
        
        return true, history
    end

    -- Forward Declaration for Recursive Call
    local showRandomAd

    -- Separate Full-Screen Limit Layout with Real-Time Timer & Try Again
    local function showLimitReachedScreen(targetResetTime)
        _G.isAdScreenShowing = true
        local limitTicker = nil

        local layoutLimit = {
            LinearLayout, orientation="vertical", background="#000000", layout_width="fill", layout_height="fill", gravity="center", padding="20dp",
            {TextView, id="limitTitleText", text="Limit Reached!", textSize="26sp", textColor="#FF4444", layout_marginBottom="15dp"},
            {TextView, text="You can only watch 10 ads per hour. Please wait.", textSize="16sp", textColor="#FFFFFF", layout_marginBottom="25dp", gravity="center"},
            {TextView, id="limitTimerText", text="Calculating time...", textSize="20sp", textColor="#FFFFD700", layout_marginBottom="40dp", gravity="center"},
            {Button, id="limitTryAgainBtn", text="Try Again", layout_width="fill", layout_marginBottom="10dp"},
            {Button, id="limitBackHomeBtn", text="Back to Home", layout_width="fill"}
        }

        local limitView = loadlayout(layoutLimit)
        pcall(function()
            import "android.graphics.Typeface"
            limitTitleText.setTypeface(Typeface.DEFAULT_BOLD)
            limitTimerText.setTypeface(Typeface.DEFAULT_BOLD)
        end)

        activity.setContentView(limitView)
        styleButton(limitTryAgainBtn)
        styleButton(limitBackHomeBtn)

        -- Real-time countdown functionality
        limitTicker = Runnable{
            run = function()
                local now = os.time()
                local diff = tonumber(targetResetTime) - now

                if diff > 0 then
                    local minutes = math.floor(diff / 60)
                    local seconds = diff % 60
                    limitTimerText.setText(string.format("Limit resets in:\n%02d:%02d", minutes, seconds))
                    timerHandler.postDelayed(limitTicker, 1000)
                else
                    limitTimerText.setText("Limit has expired!\nYou can watch ads again.")
                end
            end
        }
        timerHandler.post(limitTicker)

        wrapClick(limitTryAgainBtn, function()
            local allowed, dataOrResetTime = checkHourlyLimit()
            if allowed then
                if limitTicker then timerHandler.removeCallbacks(limitTicker) end
                _G.isAdScreenShowing = false
                if canShowAdFunc() == true then
                    showRandomAd(dataOrResetTime)
                else
                    if currentMainLayoutView ~= nil then activity.setContentView(currentMainLayoutView) else mainUIFunc() end
                end
            else
                targetResetTime = dataOrResetTime
                Toast.makeText(activity, "Limit is still active. Please wait for the timer to finish.", Toast.LENGTH_SHORT).show()
            end
        end)

        wrapClick(limitBackHomeBtn, function()
            if limitTicker then timerHandler.removeCallbacks(limitTicker) end
            _G.isAdScreenShowing = false
            if currentMainLayoutView ~= nil then
                activity.setContentView(currentMainLayoutView)
            else
                mainUIFunc()
            end
        end)
    end

    -- Separate Full-Screen Violation Layout with Try Again Button
    local function showAdBlockViolationScreen(detectedBlockerName)
        _G.isAdScreenShowing = true
        
        local title = "Ad Status Alert / Error"
        local description = "An issue has been detected with your ad layout, active connection filtering, or network status. Please restore settings and try again."
        
        -- UPDATED: Condition for 'No Internet Connection' vs 'AdBlock Detected'
        if detectedBlockerName == "No Internet Connection Detected" then
            title = "No Internet Connection"
            description = "This feature is strictly online and requires an active internet connection to load advertisements. Please ensure your mobile data or Wi-Fi is stable, then try again after a few moments."
        elseif detectedBlockerName ~= "Layout Tampering Scheme" then
            title = "AdBlock Detected!"
            description = "An active ad-blocker or secure DNS filter has been detected on your device, which is preventing advertisements from showing up. Please disable any ad-blocking tools or custom network rules to continue earning coins, then try again."
        end

        local layoutViolation = {
            LinearLayout, orientation="vertical", background="#000000", layout_width="fill", layout_height="fill", gravity="center", padding="24dp",
            {TextView, id="violationTitleText", text=title, textSize="26sp", textColor="#FF4444", layout_marginBottom="20dp"},
            {TextView, text=description, textSize="16sp", textColor="#FFFFFF", layout_marginBottom="15dp", gravity="center"},
            {TextView, id="violationSourceText", text="Reason: " .. tostring(detectedBlockerName), textSize="14sp", textColor="#FFA500", layout_marginBottom="40dp", gravity="center"},
            {Button, id="violationTryAgainBtn", text="Try Again", layout_width="fill", layout_marginBottom="10dp"},
            {Button, id="violationBackHomeBtn", text="Back to Home", layout_width="fill"}
        }
        
        local violationView = loadlayout(layoutViolation)
        
        pcall(function()
            import "android.graphics.Typeface"
            violationTitleText.setTypeface(Typeface.DEFAULT_BOLD)
            violationSourceText.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.ITALIC))
        end)

        activity.setContentView(violationView)
        styleButton(violationTryAgainBtn)
        styleButton(violationBackHomeBtn)

        wrapClick(violationTryAgainBtn, function()
            local connectivity = activity.getSystemService(Context.CONNECTIVITY_SERVICE)
            local networkInfo = connectivity.getActiveNetworkInfo()

            if networkInfo == nil or not networkInfo.isConnected() then
                violationSourceText.setText("Reason: No Internet Connection Detected")
                Toast.makeText(activity, "Still Offline! Please connect to the internet.", Toast.LENGTH_SHORT).show()
            else
                local checkAgain = checkAdBlockingDNS()
                if checkAgain ~= nil then
                    violationSourceText.setText("Reason: " .. tostring(checkAgain))
                    Toast.makeText(activity, "Still Detected! Please check your network/DNS settings.", Toast.LENGTH_SHORT).show()
                else
                    _G.isAdScreenShowing = false
                    local allowed, dataOrResetTime = checkHourlyLimit()
                    if allowed and canShowAdFunc() == true then
                        showRandomAd(dataOrResetTime)
                    elseif not allowed then
                        showLimitReachedScreen(dataOrResetTime)
                    else
                        if currentMainLayoutView ~= nil then
                            activity.setContentView(currentMainLayoutView)
                        else
                            mainUIFunc()
                        end
                    end
                end
            end
        end)

        wrapClick(violationBackHomeBtn, function()
            _G.isAdScreenShowing = false
            if currentMainLayoutView ~= nil then
                activity.setContentView(currentMainLayoutView)
            else
                mainUIFunc()
            end
        end)
    end

    local function trackNewAdWatch(historyTable)
        local currentTime = os.time()
        table.insert(historyTable, currentTime)
        local newHistoryStr = table.concat(historyTable, ",")
        editor.putString("adHourlyHistory", newHistoryStr).apply()
    end
    
    local function openInDefaultBrowser(targetUrl)
        if targetUrl == nil or targetUrl == "" or string.find(targetUrl, "about:blank") then return end
        pcall(function()
            local intent = Intent(Intent.ACTION_VIEW, Uri.parse(tostring(targetUrl)))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            local pm = activity.getPackageManager()
            local browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com"))
            local resolveInfo = pm.resolveActivity(browserIntent, 0)
            if resolveInfo ~= nil then
                intent.setPackage(resolveInfo.activityInfo.packageName)
            end
            activity.startActivity(intent)
        end)
    end

    function showRandomAd(currentHistory)
        -- STRICT PRIORITY 1: Internet Connectivity Check
        local connectivity = activity.getSystemService(Context.CONNECTIVITY_SERVICE)
        local networkInfo = connectivity.getActiveNetworkInfo()

        if networkInfo == nil or not networkInfo.isConnected() then
            showAdBlockViolationScreen("No Internet Connection Detected")
            return
        end

        -- STRICT PRIORITY 2: AdBlocker Check
        local dnsBlockerName = checkAdBlockingDNS()
        if dnsBlockerName ~= nil then
            showAdBlockViolationScreen(dnsBlockerName)
            return
        end

        _G.isAdScreenShowing = true

        local selectedAd = getAdConfigFunc()
        local adContainer = FrameLayout(activity)
        adContainer.setBackgroundColor(Color.BLACK)

        local webViewLayout = LinearLayout(activity)
        webViewLayout.setOrientation(1)
        webViewLayout.setBackgroundColor(Color.BLACK)
        
        local webView1 = WebView(activity)
        configureWebViewFunc(webView1)
        local webView2 = nil

        local randomTime = getRandomTimeFunc()
        local timeLeft = randomTime
        local isAdFullyLoaded = false
        local timerRunning = false
        local rewardGranted = false
        local penaltyApplied = false
        local failSafeCancelled = false

        local bottomLayout = LinearLayout(activity)
        bottomLayout.setOrientation(1)
        bottomLayout.setBackgroundColor(0xEE000000)
        bottomLayout.setPadding(30, 30, 30, 30)

        local statusText = TextView(activity)
        statusText.setTextColor(Color.WHITE)
        statusText.setTextSize(16)
        statusText.setGravity(Gravity.CENTER)
        statusText.setText("Loading Ad... Please wait.")

        local successContainer = LinearLayout(activity)
        successContainer.setOrientation(1)
        successContainer.setGravity(Gravity.CENTER)
        successContainer.setVisibility(View.GONE)

        local successLine1 = TextView(activity)
        successLine1.setTextColor(0xFF00FF00)
        successLine1.setTextSize(18)
        successLine1.setGravity(Gravity.CENTER)
        successLine1.setText("Task Completed Successfully!")

        local successLine2 = TextView(activity)
        successLine2.setTextColor(Color.WHITE)
        successLine2.setTextSize(16)
        successLine2.setGravity(Gravity.CENTER)
        successLine2.setText("Reward Granted")

        local successLine3 = TextView(activity)
        successLine3.setTextColor(0xFFFFD700)
        successLine3.setTextSize(14)
        successLine3.setGravity(Gravity.CENTER)

        successContainer.addView(successLine1)
        successContainer.addView(successLine2)
        successContainer.addView(successLine3)

        local closeButton = Button(activity)
        closeButton.setText("Close Ad")
        closeButton.setVisibility(View.GONE)

        bottomLayout.addView(statusText)
        bottomLayout.addView(successContainer)
        bottomLayout.addView(closeButton)

        local function returnToMain()
            _G.isAdScreenShowing = false
            if currentMainLayoutView ~= nil then
                activity.setContentView(currentMainLayoutView)
            else
                mainUIFunc()
            end
        end

        closeButton.setOnClickListener(View.OnClickListener{
            onClick = function(v)
                returnToMain()
            end
        })

        local ticker
        ticker = Runnable{
            run = function()
                if isAdFullyLoaded == true and penaltyApplied == false then
                    local runtimeDnsName = checkAdBlockingDNS()
                    if runtimeDnsName ~= nil then
                        penaltyApplied = true
                        showAdBlockViolationScreen(runtimeDnsName)
                        return
                    end

                    if tonumber(timeLeft) > 0 then
                        statusText.setText("Please watch the ad.\nReward in " .. tostring(timeLeft) .. " seconds")
                        timeLeft = tonumber(timeLeft) - 1
                        timerHandler.postDelayed(ticker, 1000)
                    else
                        rewardGranted = true
                        local rewardCoins = math.random(2, 3)
                        local currentCoins = prefs.getInt("coins", 0) + rewardCoins
                        editor.putInt("coins", currentCoins).apply()
                        
                        trackNewAdWatch(currentHistory)
                        
                        statusText.setVisibility(View.GONE)
                        successLine3.setText(tostring(rewardCoins) .. " coins have been added to your balance.")
                        successContainer.setVisibility(View.VISIBLE)
                        closeButton.setVisibility(View.VISIBLE)
                    end
                end
            end
        }

        local function triggerAdStartSafely()
            activity.runOnUiThread(Runnable{run=function()
                if timerRunning == false and penaltyApplied == false then
                    local finalDnsCheck = checkAdBlockingDNS()
                    if finalDnsCheck ~= nil then
                        showAdBlockViolationScreen(finalDnsCheck)
                        return
                    end
                    
                    failSafeCancelled = true
                    isAdFullyLoaded = true
                    timerRunning = true
                    
                    statusText.setText("Please watch the ad.\nReward in " .. tostring(timeLeft) .. " seconds")
                    local currentWatchCount = prefs.getInt("adWatchCount", 0) + 1
                    editor.putInt("adWatchCount", currentWatchCount)
                    saveAdPreferences()
                    timerHandler.post(ticker)
                end
            end})
        end

        -- JavaScript Dynamic Visual Verification Interface
        pcall(function()
            webView1.getSettings().setJavaScriptEnabled(true)
            webView1.addJavascriptInterface(luajava.override(luajava.bindClass("java.lang.Object"), {
                toString = function() return "AdCheckInterface" end,
                onRenderStatus = function(status)
                    if tostring(status) == "blocked" then
                        activity.runOnUiThread(Runnable{run=function()
                            local adBlockCheck = checkAdBlockingDNS() or "Cosmetic Ad-Blocker Extension"
                            showAdBlockViolationScreen(adBlockCheck)
                        end})
                    elseif tostring(status) == "visible_and_rendered" then
                        triggerAdStartSafely()
                    end
                end
            }), "AdCheckInterface")
        end)

        if selectedAd.type == "COMBO" then
            webView2 = WebView(activity)
            configureWebViewFunc(webView2)
            webViewLayout.addView(webView1, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.0))
            webViewLayout.addView(webView2, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.0))
            webView1.loadDataWithBaseURL("https://www.effectivecpmnetwork.com/", selectedAd.htmlTop, "text/html", "UTF-8", nil)
            webView2.loadDataWithBaseURL("https://www.effectivecpmnetwork.com/", selectedAd.htmlBottom, "text/html", "UTF-8", nil)
        else
            webViewLayout.addView(webView1, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT))
            webView1.loadUrl(selectedAd.url)
        end

        local function attachClientLogic(targetWebView)
            if targetWebView == nil then return end
            
            targetWebView.setWebChromeClient(luajava.override(luajava.bindClass("android.webkit.WebChromeClient"), {
                onProgressChanged = function(view, newProgress)
                    if tonumber(newProgress) == 100 then
                        triggerAdStartSafely()
                    end
                end
            }))

            targetWebView.setWebViewClient(luajava.override(luajava.bindClass("android.webkit.WebViewClient"), {
                shouldOverrideUrlLoading = function(view, url)
                    if url ~= nil then
                        local urlString = tostring(url)
                        if string.find(urlString, "myapp://ad_hidden") then
                            if rewardGranted == false and isAdFullyLoaded == true then
                                penaltyApplied = true
                                isAdFullyLoaded = false
                                showAdBlockViolationScreen("Layout Tampering Scheme")
                            end
                            return true
                        elseif string.find(urlString, "http") then
                            openInDefaultBrowser(urlString)
                            return true
                        else
                            return false
                        end
                    end
                    return false
                end,
                onPageFinished = function(view, url)
                    if url ~= nil and tostring(url) ~= "about:blank" then
                        pcall(function()
                            local enforceSelfTargetJS = [[
                                javascript:(function() {
                                    var links = document.getElementsByTagName('a');
                                    for(var i=0; i<links.length; i++){
                                        links[i].setAttribute('target', '_self');
                                        links[i].onclick = function(e) {
                                            window.location.href = this.href;
                                            return false;
                                        };
                                    }
                                    window.open = function(url) {
                                        if(url) { window.location.href = url; }
                                        return null;
                                    };
                                })();
                            ]]
                            targetWebView.loadUrl(enforceSelfTargetJS)

                            local loopRenderCheckJS = [[
                                javascript:(function() {
                                    var maxAttempts = 40; 
                                    localCheckCounter = 0;
                                    function doCheck() {
                                        localCheckCounter++;
                                        var height = window.innerHeight || document.documentElement.clientHeight;
                                        var width = window.innerWidth || document.documentElement.clientWidth;
                                        var hasContent = document.body && document.body.innerHTML.trim().length > 150;
                                        var elementsCount = document.getElementsByTagName('*').length;

                                        if (hasContent && elementsCount > 6) {
                                            AdCheckInterface.onRenderStatus("visible_and_rendered");
                                        } else {
                                            if (localCheckCounter < maxAttempts) {
                                                setTimeout(doCheck, 500);
                                            } else {
                                                AdCheckInterface.onRenderStatus("blocked");
                                            }
                                        }
                                    }
                                    doCheck();
                                })();
                            ]]
                            targetWebView.loadUrl(loopRenderCheckJS)
                        end)

                        -- Native Height Backup Verification
                        pcall(function()
                            local h = targetWebView.getHeight()
                            if h and tonumber(h) > 50 then
                                triggerAdStartSafely()
                            end
                        end)
                    end
                end,
                onReceivedError = function(view, request, error)
                    if rewardGranted == false and penaltyApplied == false and isAdFullyLoaded == false then
                        local currentConn = activity.getSystemService(Context.CONNECTIVITY_SERVICE)
                        local netInfo = currentConn.getActiveNetworkInfo()
                        
                        activity.runOnUiThread(Runnable{run=function()
                            if netInfo ~= nil and netInfo.isConnected() then
                                local adBlockCheck = checkAdBlockingDNS() or "Ad-Blocker Content Filter Detected"
                                showAdBlockViolationScreen(adBlockCheck)
                            else
                                showAdBlockViolationScreen("No Internet Connection Detected")
                            end
                        end})
                    end
                end
            }))
        end

        attachClientLogic(webView1)
        if webView2 ~= nil then attachClientLogic(webView2) end

        local mainParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        adContainer.addView(webViewLayout, mainParams)

        local bottomParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT)
        bottomParams.gravity = Gravity.BOTTOM
        adContainer.addView(bottomLayout, bottomParams)

        activity.setContentView(adContainer)

        -- Fail-Safe Watchdog
        timerHandler.postDelayed(Runnable{
            run = function()
                if failSafeCancelled == false and isAdFullyLoaded == false and penaltyApplied == false then
                    local connState = activity.getSystemService(Context.CONNECTIVITY_SERVICE).getActiveNetworkInfo()
                    
                    if connState ~= nil and connState.isConnected() then
                        local adBlockCheck = checkAdBlockingDNS() or "Ad Host Request Blocked"
                        showAdBlockViolationScreen(adBlockCheck)
                    else
                        showAdBlockViolationScreen("No Internet Connection Detected")
                    end
                end
            end
        }, 22000)
    end

    local function showDisclaimerDialog()
        local builder = AlertDialog.Builder(activity)
        builder.setTitle("Ad Content Disclaimer")
        builder.setMessage("We do not endorse, guarantee, or take responsibility for any products, services, or claims displayed in the third-party advertisements. Please interact with ad content at your own discretion.")
        builder.setCancelable(false)
        builder.setPositiveButton("I Agree", DialogInterface.OnClickListener{
            onClick = function(dialog, which)
                editor.putBoolean("disclaimerAccepted", true)
                saveAdPreferences()
                
                local allowed, dataOrResetTime = checkHourlyLimit()
                if allowed and canShowAdFunc() == true then 
                    showRandomAd(dataOrResetTime) 
                elseif not allowed then
                    showLimitReachedScreen(dataOrResetTime)
                else
                    mainUIFunc()
                end
            end
        })
        builder.setNegativeButton("Cancel", nil)
        builder.show()
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
        versionText.setText("Version 1.6")
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
                .setMessage("Are you sure you want to reset all game statistics and coins?")
                .setPositiveButton("Yes", DialogInterface.OnClickListener{
                    onClick = function(dialog, which)
                        -- Data clear logics
                        editor.remove("username")
                        editor.remove("userid")
                        editor.putInt("coins", 0)
                        editor.putInt("bmn_played", 0)
                        editor.putInt("bmn_wins", 0)
                        editor.putInt("bmn_losses", 0)
                        editor.putInt("bmn_incompleted", 0)
                        editor.putString("adHourlyHistory", "")
                        
                        -- ENHANCEMENT: Shuruati welcome1 layout ko target karne ke liye first_run true kiya gaya
                        editor.putBoolean("first_run", true)
                        editor.apply()
                        
                        -- Settings layout band karke pure startup sequence par redirect kiya
                        ds.dismiss()
                        
                        -- main.lua ki shuruati conditions ko mock karne ke liye welcome screen chain ko call kiya gaya
                        welcome1()
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

    wrapClick(backToMainBtn, function()
        isOpeningAd = false
        dialog1.dismiss()
        mainUIFunc()
    end)

    dialog1.setOnCancelListener(DialogInterface.OnCancelListener{
        onCancel=function(dialog)
            if not isOpeningAd then mainUIFunc() end
        end
    })
    dialog1.setOnDismissListener(DialogInterface.OnDismissListener{
        onDismiss=function(dialog)
            if not isOpeningAd then mainUIFunc() end
        end
    })

    wrapClick(settingsBtn, function()
        isOpeningAd = false
        dialog1.dismiss()
        showFullSettingsDialog()
    end)

    wrapClick(adWatchBtn, function()
        isOpeningAd = true
        dialog1.dismiss()
        if prefs.getBoolean("disclaimerAccepted", false) == false then
            showDisclaimerDialog()
        else
            local allowed, dataOrResetTime = checkHourlyLimit()
            if allowed and canShowAdFunc() == true then 
                showRandomAd(dataOrResetTime) 
            elseif not allowed then
                showLimitReachedScreen(dataOrResetTime)
            else
                mainUIFunc()
            end
        end
    end)
end

return M
