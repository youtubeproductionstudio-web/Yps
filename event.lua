local eventModule = {}

function eventModule.show(activity, mainUI, wrapClick, styleButton, prefs, editor, timerHandler, getAdConfigFunc, configureWebViewFunc)
    _G.isEventShowing = true
    
    -- Unique ticket to ensure background polling strictly stops when screen is closed
    _G.eventPollTicket = (_G.eventPollTicket or 0) + 1
    local currentPollTicket = _G.eventPollTicket
    
    local eventsBaseUrl = "https://all-games-76b5d-default-rtdb.firebaseio.com/events/"
    
    -- Tracking variables for fail-safe ad termination
    local currentTickerRunnable = nil
    local currentWatchdogRunnable = nil
    local activeWebView1 = nil
    local activeWebView2 = nil
    
    -- Hashing for exact database change detection
    local lastEventsHash = ""
    
    local eventLayout = {
        LinearLayout,
        orientation="vertical",
        layout_width="fill",
        layout_height="fill",
        background="#000000",
        {
            LinearLayout,
            orientation="horizontal",
            layout_width="fill",
            layout_height="wrap",
            padding="15dp",
            gravity="center_vertical",
            background="#111111",
            {
                Button,
                id="backEventBtn",
                text="Back",
                textSize="14sp",
                layout_width="wrap",
            },
            {
                TextView,
                id="eventTitleTxt",
                text="Events and Festivals",
                textSize="22sp",
                textColor="#FFFFFF",
                layout_marginLeft="15dp"
            }
        },
        {
            TextView,
            id="emptyEventTxt",
            text="Loading data...",
            textSize="18sp",
            textColor="#AAAAAA",
            gravity="center",
            layout_width="fill",
            layout_height="fill",
            visibility=0 -- VISIBLE
        },
        {
            ListView,
            id="eventListView",
            layout_width="fill",
            layout_height="fill",
            dividerHeight="1dp",
            visibility=8 -- GONE
        }
    }
    
    local eventView = loadlayout(eventLayout)
    activity.setContentView(eventView)
    
    pcall(function()
        eventTitleTxt.setTypeface(android.graphics.Typeface.DEFAULT_BOLD)
        local ColorDrawable = luajava.bindClass("android.graphics.drawable.ColorDrawable")
        eventListView.setDivider(ColorDrawable(android.graphics.Color.parseColor("#333333")))
    end)

    styleButton(backEventBtn)
    
    wrapClick(backEventBtn, function()
        _G.isEventShowing = false
        mainUI()
    end)

    -- --- HELPER UTILS FOR REALTIME FIREBASE UPDATES --- --
    local function updateFirebaseField(eventId, fieldName, jsonValue, callback)
        local System = luajava.bindClass("java.lang.System")
        local timestamp = tostring(System.currentTimeMillis())
        local targetUrl = eventsBaseUrl .. eventId .. "/" .. fieldName .. ".json?x-http-method-override=PUT&t=" .. timestamp
        Http.post(targetUrl, tostring(jsonValue), function(code, content)
            if callback then callback(code >= 200 and code < 300) end
        end)
    end

    -- --- DATE & TIME VALIDATOR --- --
    local function checkEventTimingStatus(openStr, closeStr)
        local status = "ACTIVE" -- ACTIVE, NOT_STARTED, EXPIRED
        pcall(function()
            local SimpleDateFormat = luajava.bindClass("java.text.SimpleDateFormat")
            local Locale = luajava.bindClass("java.util.Locale")
            local System = luajava.bindClass("java.lang.System")
            local sdf = SimpleDateFormat("dd MMM yyyy, HH:mm", Locale.US)
            local now = System.currentTimeMillis()
            
            if openStr and openStr ~= "" then
                local openDateObj = sdf.parse(openStr)
                if openDateObj and now < openDateObj.getTime() then
                    status = "NOT_STARTED"
                end
            end
            
            if status == "ACTIVE" and closeStr and closeStr ~= "" then
                local closeDateObj = sdf.parse(closeStr)
                if closeDateObj and now > closeDateObj.getTime() then
                    status = "EXPIRED"
                end
            end
        end)
        return status
    end

    -- --- ADVERTISEMENT LOGIC UTILS --- --
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

            if dns1:find("adguard") or dns2:find("dns1") then
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

    local function showAdBlockViolationScreen(detectedBlockerName, eventObj, onAdSuccess, onCancel)
        if currentTickerRunnable then
            pcall(function() timerHandler.removeCallbacks(currentTickerRunnable) end)
            currentTickerRunnable = nil
        end
        if currentWatchdogRunnable then
            pcall(function() timerHandler.removeCallbacks(currentWatchdogRunnable) end)
            currentWatchdogRunnable = nil
        end
        if activeWebView1 then
            pcall(function() 
                activeWebView1.stopLoading()
                activeWebView1.setWebViewClient(nil)
                activeWebView1.setWebChromeClient(nil)
            end)
            activeWebView1 = nil
        end
        if activeWebView2 then
            pcall(function() 
                activeWebView2.stopLoading()
                activeWebView2.setWebViewClient(nil)
                activeWebView2.setWebChromeClient(nil)
            end)
            activeWebView2 = nil
        end

        local title = "Ad Status Alert / Error"
        local description = "An issue has been detected with your ad layout, active connection filtering, or network status."
        
        if detectedBlockerName == "No Internet Connection Detected" then
            title = "No Internet Connection"
            description = "This feature is strictly online and requires an active internet connection to load advertisements."
        elseif detectedBlockerName ~= "Layout Tampering Scheme" then
            title = "AdBlock Detected!"
            description = "An active ad-blocker or secure DNS filter has been detected on your device. Please disable it to continue."
        end

        local layoutViolation = {
            LinearLayout, orientation="vertical", background="#000000", layout_width="fill", layout_height="fill", gravity="center", padding="24dp",
            {TextView, id="violationTitleText", text=title, textSize="26sp", textColor="#FF4444", layout_marginBottom="20dp"},
            {TextView, text=description, textSize="16sp", textColor="#FFFFFF", layout_marginBottom="15dp", gravity="center"},
            {TextView, id="violationSourceText", text="Reason: " .. tostring(detectedBlockerName), textSize="14sp", textColor="#FFA500", layout_marginBottom="40dp", gravity="center"},
            {Button, id="violationTryAgainBtn", text="Try Again", layout_width="fill", layout_marginBottom="10dp"},
            {Button, id="violationBackHomeBtn", text="Cancel", layout_width="fill"}
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
            local Toast = luajava.bindClass("android.widget.Toast")

            if networkInfo == nil or not networkInfo.isConnected() then
                violationSourceText.setText("Reason: No Internet Connection Detected")
                Toast.makeText(activity, "Still Offline! Please connect to the internet.", Toast.LENGTH_SHORT).show()
            else
                local checkAgain = checkAdBlockingDNS()
                if checkAgain ~= nil then
                    violationSourceText.setText("Reason: " .. tostring(checkAgain))
                    Toast.makeText(activity, "Still Detected! Please check your network/DNS settings.", Toast.LENGTH_SHORT).show()
                else
                    if onAdSuccess and onCancel then
                        eventModule.playUnlockAd(activity, timerHandler, getAdConfigFunc, configureWebViewFunc, eventObj, onAdSuccess, onCancel, showAdBlockViolationScreen)
                    end
                end
            end
        end)

        wrapClick(violationBackHomeBtn, function()
            if onCancel then onCancel() end
        end)
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

    function eventModule.playUnlockAd(activity, timerHandler, getAdConfigFunc, configureWebViewFunc, eventObj, onAdSuccess, onCancel, violationFunc)
        local connectivity = activity.getSystemService(Context.CONNECTIVITY_SERVICE)
        local networkInfo = connectivity.getActiveNetworkInfo()

        if networkInfo == nil or not networkInfo.isConnected() then
            violationFunc("No Internet Connection Detected", eventObj, onAdSuccess, onCancel)
            return
        end

        local dnsBlockerName = checkAdBlockingDNS()
        if dnsBlockerName ~= nil then
            violationFunc(dnsBlockerName, eventObj, onAdSuccess, onCancel)
            return
        end

        local selectedAd = getAdConfigFunc()
        if selectedAd == nil then 
            if onCancel then onCancel() end
            return 
        end

        local adContainer = FrameLayout(activity)
        adContainer.setBackgroundColor(Color.BLACK)

        local webViewLayout = LinearLayout(activity)
        webViewLayout.setOrientation(1)
        webViewLayout.setBackgroundColor(Color.BLACK)
        
        local webView1 = WebView(activity)
        configureWebViewFunc(webView1)
        local webView2 = nil
        
        activeWebView1 = webView1

        math.randomseed(os.time())
        local timeLeft = math.random(20, 30)
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
        successContainer.setVisibility(8)

        local successLine1 = TextView(activity)
        successLine1.setTextColor(0xFF00FF00)
        successLine1.setTextSize(18)
        successLine1.setGravity(Gravity.CENTER)
        successLine1.setText("Task Completed Successfully!")

        local successLine2 = TextView(activity)
        successLine2.setTextColor(Color.WHITE)
        successLine2.setTextSize(16)
        successLine2.setGravity(Gravity.CENTER)
        successLine2.setText("Event Progress Updated")

        successContainer.addView(successLine1)
        successContainer.addView(successLine2)

        local closeButton = Button(activity)
        closeButton.setText("Close & Continue")
        closeButton.setVisibility(8)

        bottomLayout.addView(statusText)
        bottomLayout.addView(successContainer)
        bottomLayout.addView(closeButton)

        closeButton.setOnClickListener(View.OnClickListener{
            onClick = function(v)
                if onAdSuccess then onAdSuccess() end
            end
        })

        local ticker
        ticker = Runnable{
            run = function()
                if isAdFullyLoaded == true and penaltyApplied == false then
                    local runtimeDnsName = checkAdBlockingDNS()
                    if runtimeDnsName ~= nil then
                        penaltyApplied = true
                        violationFunc(runtimeDnsName, eventObj, onAdSuccess, onCancel)
                        return
                    end

                    if tonumber(timeLeft) > 0 then
                        statusText.setText("Please watch the ad to unlock.\nDone in " .. tostring(timeLeft) .. " seconds")
                        timeLeft = tonumber(timeLeft) - 1
                        timerHandler.postDelayed(ticker, 1000)
                    else
                        rewardGranted = true
                        statusText.setVisibility(8)
                        successContainer.setVisibility(0)
                        closeButton.setVisibility(0)
                    end
                end
            end
        }

        local function triggerAdStartSafely()
            activity.runOnUiThread(Runnable{run=function()
                if timerRunning == false and penaltyApplied == false then
                    local finalDnsCheck = checkAdBlockingDNS()
                    if finalDnsCheck ~= nil then
                        violationFunc(finalDnsCheck, eventObj, onAdSuccess, onCancel)
                        return
                    end
                    
                    failSafeCancelled = true
                    isAdFullyLoaded = true
                    timerRunning = true
                    
                    statusText.setText("Please watch the ad to unlock.\nDone in " .. tostring(timeLeft) .. " seconds")
                    
                    currentTickerRunnable = ticker
                    timerHandler.post(ticker)
                end
            end})
        end

        pcall(function()
            webView1.getSettings().setJavaScriptEnabled(true)
            webView1.addJavascriptInterface(luajava.override(luajava.bindClass("java.lang.Object"), {
                toString = function() return "AdCheckInterface" end,
                onRenderStatus = function(status)
                    if tostring(status) == "blocked" then
                        activity.runOnUiThread(Runnable{run=function()
                            local adBlockCheck = checkAdBlockingDNS() or "Cosmetic Ad-Blocker Extension"
                            violationFunc(adBlockCheck, eventObj, onAdSuccess, onCancel)
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
            activeWebView2 = webView2
            webViewLayout.addView(webView1, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.0))
            webViewLayout.addView(webView2, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.0))
            webView1.loadDataWithBaseURL("https://www.effectivecpmnetwork.com/", selectedAd.htmlTop, "text/html", "UTF-8", nil)
            webView2.loadDataWithBaseURL("https://www.effectivecpmnetwork.com/", selectedAd.htmlBottom, "text/html", "UTF-8", nil)
        else
            webViewLayout.addView(webView1, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT))
            if selectedAd.url then
                webView1.loadUrl(selectedAd.url)
            else
                webView1.loadUrl("https://www.google.com")
            end
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
                                violationFunc("Layout Tampering Scheme", eventObj, onAdSuccess, onCancel)
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
                        pcall(function()
                            local h = targetWebView.getHeight()
                            if h and tonumber(h) > 50 then triggerAdStartSafely() end
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
                                violationFunc(adBlockCheck, eventObj, onAdSuccess, onCancel)
                            else
                                violationFunc("No Internet Connection Detected", eventObj, onAdSuccess, onCancel)
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

        local watchdog = Runnable{
            run = function()
                if failSafeCancelled == false and isAdFullyLoaded == false and penaltyApplied == false then
                    local connState = activity.getSystemService(Context.CONNECTIVITY_SERVICE).getActiveNetworkInfo()
                    
                    if connState ~= nil and connState.isConnected() then
                        local adBlockCheck = checkAdBlockingDNS() or "Ad Host Request Blocked"
                        violationFunc(adBlockCheck, eventObj, onAdSuccess, onCancel)
                    else
                        violationFunc("No Internet Connection Detected", eventObj, onAdSuccess, onCancel)
                    end
                end
            end
        }
        currentWatchdogRunnable = watchdog
        timerHandler.postDelayed(watchdog, 22000)
    end
    -- --- ADVERTISEMENT LOGIC END --- --

    local function getNumericValue(jsonObj, key)
        if jsonObj.has(key) then
            local val = jsonObj.optString(key, "0")
            if val == "" then return 0 end
            return tonumber(val) or 0
        end
        return 0
    end

    -- LOAD EVENTS FROM SERVER (WITH CACHE BUSTING FIX)
    local function loadEventsList(forceReload)
        local System = luajava.bindClass("java.lang.System")
        -- Fix #1: Appending explicit timestamp completely bypasses HTTP caching
        local eventsUrl = eventsBaseUrl:sub(1, -2) .. ".json?t=" .. tostring(System.currentTimeMillis())
        
        Http.get(eventsUrl, function(code, content)
            if code == 200 and content and content ~= "null" and content ~= "{}" then
                local success, err = pcall(function()
                    local JSONObject = luajava.bindClass("org.json.JSONObject")
                    local jsonObj = JSONObject(content)
                    local keys = jsonObj.keys()
                    local eventList = {}
                    local count = 0
                    local newHashBuilder = ""
                    
                    while keys.hasNext() do
                        local k = tostring(keys.next())
                        local item = jsonObj.optJSONObject(k)
                        if item then
                            count = count + 1
                            
                            local evType = item.optString("type", "Event")
                            local title = item.optString("title", "Untitled Event")
                            local description = item.optString("description", "No description available.")
                            local openingDate = item.optString("opening_date", "")
                            local closingDate = item.optString("closing_date", "")
                            
                            local isAdsPerUser = item.optBoolean("is_ads_per_user", true)
                            
                            local currentParticipants = getNumericValue(item, "current_participants")
                            local currentAdsWatched = getNumericValue(item, "current_ads_watched")
                            local maxParticipants = getNumericValue(item, "max_participants")
                            local joiningCoins = getNumericValue(item, "joining_coins")
                            local requiredAds = getNumericValue(item, "ads_watch")
                            
                            newHashBuilder = newHashBuilder .. k .. "_" .. currentAdsWatched .. "_" .. currentParticipants .. "|"
                            
                            local formattedTitle = "[" .. evType .. "] " .. title
                            
                            local timeInfo = ""
                            if openingDate ~= "" or closingDate ~= "" then
                                timeInfo = "Opens: " .. (openingDate ~= "" and openingDate or "N/A") .. " | Closes: " .. (closingDate ~= "" and closingDate or "N/A")
                            else
                                timeInfo = "Timing: Always Open / Permanent"
                            end
                            
                            -- FIX: Yahan par hum check lagayenge fees aur ads ke requirements ka
                            local requirements = {}
                            if joiningCoins > 0 then
                                table.insert(requirements, "Cost: " .. joiningCoins .. " Coins")
                            end
                            
                            if requiredAds > 0 then
                                local targetType = isAdsPerUser and "(Per User Target)" or "(Global Community Target)"
                                table.insert(requirements, "Ads Target: " .. requiredAds .. " " .. targetType)
                            end
                            
                            local reqTextFinal = table.concat(requirements, " | ")
                            local hasRequirements = (reqTextFinal ~= "")
                            
                            local partInfo = "Max Participants: " .. (maxParticipants > 0 and maxParticipants or "Unlimited")
                            
                            local userFriendlyHint = ""
                            if hasRequirements then
                                if not isAdsPerUser then
                                    userFriendlyHint = "Note: This is a global event. All users work together to complete this advertisement target, not just 1 user."
                                else
                                    userFriendlyHint = "Note: Complete the requirements below to unlock and join this exclusive event instantly."
                                end
                            end

                            table.insert(eventList, {
                                id = k,
                                type = evType,
                                title = formattedTitle,
                                desc = description,
                                timeInfo = timeInfo,
                                partInfo = partInfo,
                                reqText = reqTextFinal,
                                hasReq = hasRequirements,
                                hintText = userFriendlyHint,
                                openingDate = openingDate,
                                closingDate = closingDate,
                                requiredAds = requiredAds,
                                isAdsPerUser = isAdsPerUser,
                                currentAdsWatched = currentAdsWatched,
                                joiningCoins = joiningCoins,
                                maxParticipants = maxParticipants,
                                currentParticipants = currentParticipants
                            })
                        end
                    end
                    
                    if count == 0 then
                        emptyEventTxt.setText("No data found")
                        emptyEventTxt.setVisibility(0)
                        eventListView.setVisibility(8)
                        return
                    end
                    
                    -- Safe Hash Checking for seamless updates
                    if not forceReload and newHashBuilder == lastEventsHash then
                        return 
                    end
                    lastEventsHash = newHashBuilder
                    
                    local itemLayout = {
                        LinearLayout,
                        orientation="vertical",
                        layout_width="fill",
                        padding="15dp",
                        background="#000000",
                        { TextView, id="eTitleHeading", text="EVENT DETAILS:", textSize="12sp", textColor="#888888" },
                        { TextView, id="eTitleTxt", textSize="18sp", textColor="#E91E63", layout_marginTop="2dp" },
                        { TextView, id="eDescHeading", text="DESCRIPTION:", textSize="12sp", textColor="#888888", layout_marginTop="8dp" },
                        { TextView, id="eDescTxt", textSize="14sp", textColor="#FFFFFF", layout_marginTop="2dp" },
                        { TextView, id="eDateHeading", text="SCHEDULE & TIMING:", textSize="12sp", textColor="#888888", layout_marginTop="8dp" },
                        { TextView, id="eDateTxt", textSize="13sp", textColor="#CCCCCC", layout_marginTop="2dp" },
                        { TextView, id="eReqHeading", text="REQUIREMENTS & TARGET:", textSize="12sp", textColor="#888888", layout_marginTop="8dp" },
                        { TextView, id="eReqTxt", textSize="13sp", textColor="#FFEB3B", layout_marginTop="2dp" },
                        { TextView, id="eHintTxt", textSize="12sp", textColor="#00BCD4", layout_marginTop="6dp" },
                        { TextView, id="ePartTxt", textSize="12sp", textColor="#AAAAAA", layout_marginTop="4dp" },
                        {
                            Button,
                            id="eActionBtn",
                            text="Unlock / Join",
                            textColor="#000000",
                            backgroundColor="#FFFFFF",
                            layout_marginTop="12dp",
                            layout_width="fill"
                        }
                    }
                    
                    local adapterData = {}
                    for _, ev in ipairs(eventList) do
                        local timingStatus = checkEventTimingStatus(ev.openingDate, ev.closingDate)
                        local isJoined = prefs.getBoolean("joined_event_" .. ev.id, false)
                        local isUnlockedLocally = prefs.getBoolean("unlocked_event_" .. ev.id, false)
                        local userWatchedAds = prefs.getInt("watched_ads_" .. ev.id, 0)
                        
                        local buttonText = "Join Event"
                        local isButtonEnabled = true
                        
                        -- Fix #2: Festival vs Event Conflict (Dynamically modify headers to distinguish)
                        local dynamicHeading = (string.upper(ev.type) == "FESTIVAL") and "FESTIVAL DETAILS:" or "EVENT DETAILS:"
                        
                        if timingStatus == "NOT_STARTED" then
                            buttonText = "Opens: " .. ev.openingDate
                            isButtonEnabled = false
                        elseif timingStatus == "EXPIRED" then
                            buttonText = "Expired"
                            isButtonEnabled = false
                        elseif isJoined then
                            buttonText = "Already Joined ✓"
                            isButtonEnabled = false
                        elseif ev.maxParticipants > 0 and ev.currentParticipants >= ev.maxParticipants then
                            buttonText = "Slots Full"
                            isButtonEnabled = false
                        else
                            if ev.requiredAds > 0 and not isUnlockedLocally then
                                if ev.isAdsPerUser then
                                    if userWatchedAds >= ev.requiredAds then
                                        editor.putBoolean("unlocked_event_" .. ev.id, true).apply()
                                        buttonText = "Join Event"
                                    else
                                        buttonText = "Watch Ad (" .. userWatchedAds .. "/" .. ev.requiredAds .. ")"
                                    end
                                else
                                    if ev.currentAdsWatched >= ev.requiredAds then
                                        buttonText = "Join (Global Unlocked)"
                                    else
                                        buttonText = "Watch Ad (Global: " .. ev.currentAdsWatched .. "/" .. ev.requiredAds .. ")"
                                    end
                                end
                            else
                                buttonText = "Join " .. ((string.upper(ev.type) == "FESTIVAL") and "Festival" or "Event") .. (ev.joiningCoins > 0 and (" (" .. ev.joiningCoins .. " Coins)") or "")
                            end
                        end
                        
                        -- Visibility logic agar koi requirement na ho (Free entry ho)
                        local reqVis = ev.hasReq and 0 or 8
                        local hintVis = (ev.hintText ~= "") and 0 or 8

                        table.insert(adapterData, {
                            eTitleHeading = dynamicHeading,
                            eTitleTxt = ev.title,
                            eDescTxt = ev.desc,
                            eDateTxt = ev.timeInfo,
                            ePartTxt = ev.partInfo,
                            eReqHeading = { text = "REQUIREMENTS & TARGET:", visibility = reqVis },
                            eReqTxt = { text = ev.reqText, visibility = reqVis },
                            eHintTxt = { text = ev.hintText, visibility = hintVis },
                            eActionBtn = {
                                text = buttonText,
                                enabled = isButtonEnabled,
                                onClick = function(v)
                                    if not isButtonEnabled then return end
                                    
                                    -- Fix #3: Fetching single exact record for Button Press also needs anti-caching
                                    local singleCheckUrl = eventsBaseUrl .. ev.id .. ".json?t=" .. tostring(System.currentTimeMillis())
                                    Http.get(singleCheckUrl, function(code, freshContent)
                                        local latestAdsWatched = ev.currentAdsWatched
                                        local latestParticipants = ev.currentParticipants
                                        if code == 200 and freshContent and freshContent ~= "null" then
                                            pcall(function()
                                                local JSONObject = luajava.bindClass("org.json.JSONObject")
                                                local freshObj = JSONObject(freshContent)
                                                latestAdsWatched = getNumericValue(freshObj, "current_ads_watched")
                                                latestParticipants = getNumericValue(freshObj, "current_participants")
                                            end)
                                        end

                                        local isCurrentlyUnlocked = prefs.getBoolean("unlocked_event_" .. ev.id, false)
                                        local currentWatched = prefs.getInt("watched_ads_" .. ev.id, 0)
                                        
                                        local needsMoreAds = false
                                        if ev.requiredAds > 0 and not isCurrentlyUnlocked then
                                            if ev.isAdsPerUser and currentWatched < ev.requiredAds then
                                                needsMoreAds = true
                                            elseif not ev.isAdsPerUser and latestAdsWatched < ev.requiredAds then
                                                needsMoreAds = true
                                            end
                                        end

                                        if needsMoreAds then
                                            local function startAdProcess()
                                                eventModule.playUnlockAd(activity, timerHandler, getAdConfigFunc, configureWebViewFunc, ev, 
                                                function() 
                                                    local Toast = luajava.bindClass("android.widget.Toast")
                                                    
                                                    if ev.isAdsPerUser then
                                                        local newCount = currentWatched + 1
                                                        editor.putInt("watched_ads_" .. ev.id, newCount)
                                                        if newCount >= ev.requiredAds then
                                                            editor.putBoolean("unlocked_event_" .. ev.id, true)
                                                        end
                                                        editor.apply()
                                                        
                                                        updateFirebaseField(ev.id, "current_ads_watched", '"' .. (latestAdsWatched + 1) .. '"')
                                                        
                                                        if newCount >= ev.requiredAds then
                                                            Toast.makeText(activity, "Unlocked! You can now join.", Toast.LENGTH_SHORT).show()
                                                        else
                                                            Toast.makeText(activity, "Ad watched! (" .. newCount .. "/" .. ev.requiredAds .. ") completed.", Toast.LENGTH_SHORT).show()
                                                        end
                                                    else
                                                        local newGlobalAds = latestAdsWatched + 1
                                                        updateFirebaseField(ev.id, "current_ads_watched", '"' .. newGlobalAds .. '"', function(success)
                                                            if newGlobalAds >= ev.requiredAds then
                                                                Toast.makeText(activity, "Global target reached! Unlocked for everyone!", Toast.LENGTH_LONG).show()
                                                            else
                                                                Toast.makeText(activity, "Global ad contributed! (" .. newGlobalAds .. "/" .. ev.requiredAds .. ")", Toast.LENGTH_SHORT).show()
                                                            end
                                                            activity.setContentView(eventView)
                                                            loadEventsList(true)
                                                        end)
                                                        return
                                                    end
                                                    
                                                    activity.setContentView(eventView)
                                                    loadEventsList(true) 
                                                end,
                                                function() 
                                                    activity.setContentView(eventView)
                                                end,
                                                showAdBlockViolationScreen)
                                            end

                                            if ev.isAdsPerUser and currentWatched == 0 then
                                                local AlertDialog = luajava.bindClass("android.app.AlertDialog")
                                                AlertDialog.Builder(activity)
                                                    .setTitle("Unlock Required")
                                                    .setMessage("You need to watch " .. (ev.requiredAds - currentWatched) .. " ad(s) to unlock this. Proceed?")
                                                    .setPositiveButton("Watch Ad", {onClick=function() startAdProcess() end})
                                                    .setNegativeButton("Cancel", nil)
                                                    .show()
                                            else
                                                startAdProcess()
                                            end
                                        else
                                            -- Slot protection with live download integration
                                            if ev.maxParticipants > 0 and latestParticipants >= ev.maxParticipants then
                                                local Toast = luajava.bindClass("android.widget.Toast")
                                                Toast.makeText(activity, "Sorry! The slots just got full.", Toast.LENGTH_SHORT).show()
                                                activity.setContentView(eventView)
                                                loadEventsList(true)
                                                return
                                            end

                                            local userCoins = prefs.getInt("user_coins", 0)
                                            if ev.joiningCoins > 0 and userCoins < ev.joiningCoins then
                                                local Toast = luajava.bindClass("android.widget.Toast")
                                                Toast.makeText(activity, "Insufficient Coins! Need " .. ev.joiningCoins .. " Coins.", Toast.LENGTH_SHORT).show()
                                                return
                                            end

                                            local AlertDialog = luajava.bindClass("android.app.AlertDialog")
                                            AlertDialog.Builder(activity)
                                                .setTitle("Join " .. ev.type)
                                                .setMessage("Do you want to join this?\n\n" .. ev.title .. (ev.joiningCoins > 0 and ("\nCost: " .. ev.joiningCoins .. " Coins") or ""))
                                                .setPositiveButton("Yes", {onClick=function()
                                                    if ev.joiningCoins > 0 then
                                                        editor.putInt("user_coins", userCoins - ev.joiningCoins).apply()
                                                    end
                                                    
                                                    editor.putBoolean("joined_event_" .. ev.id, true).apply()
                                                    
                                                    local newParticipants = latestParticipants + 1
                                                    updateFirebaseField(ev.id, "current_participants", '"' .. newParticipants .. '"', function()
                                                        local Toast = luajava.bindClass("android.widget.Toast")
                                                        Toast.makeText(adapterData and activity or activity, "Joined Successfully!", Toast.LENGTH_SHORT).show()
                                                        activity.setContentView(eventView)
                                                        loadEventsList(true)
                                                    end)
                                                end})
                                                .setNegativeButton("No", nil)
                                                .show()
                                        end
                                    end)
                                end
                            }
                        })
                    end
                    
                    local firstVis = 0
                    local topOffset = 0
                    pcall(function()
                        firstVis = eventListView.getFirstVisiblePosition()
                        local child = eventListView.getChildAt(0)
                        if child then topOffset = child.getTop() end
                    end)

                    local LuaAdapter = luajava.bindClass("com.androlua.LuaAdapter")
                    local adapter = LuaAdapter(activity, adapterData, itemLayout)
                    eventListView.setAdapter(adapter)

                    pcall(function()
                        eventListView.setSelectionFromTop(firstVis, topOffset)
                    end)
                    
                    emptyEventTxt.setVisibility(8)
                    eventListView.setVisibility(0)
                end)
                
                if not success then
                    emptyEventTxt.setText("Error parsing data")
                    emptyEventTxt.setVisibility(0)
                    eventListView.setVisibility(8)
                end
            else
                emptyEventTxt.setText("No data found")
                emptyEventTxt.setVisibility(0)
                eventListView.setVisibility(8)
            end
        end)
    end

    loadEventsList(true)

    -- Fix #4: Background protection ensures only 1 isolated ticker runs strictly on the active screen
    local pollingRunnable
    pollingRunnable = Runnable{
        run = function()
            -- Ticket Validation logic ensures overlapping runnables are impossible
            if _G.isEventShowing and _G.eventPollTicket == currentPollTicket then
                loadEventsList(false)
                timerHandler.postDelayed(pollingRunnable, 1500)
            end
        end
    }
    timerHandler.postDelayed(pollingRunnable, 1500)

end

return eventModule
