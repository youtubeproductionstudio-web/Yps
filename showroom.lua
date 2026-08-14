require "import"
import "android.widget.*"
import "android.view.*"
import "android.graphics.Color"
import "android.graphics.Typeface" -- Yeh import add kiya gaya hai bold text ke liye
import "android.widget.Toast"
import "android.app.AlertDialog"

local MediaPlayerClass = luajava.bindClass("android.media.MediaPlayer")

local showroom = {}

function showroom.openWindow(params)
  params = params or {}
  
  local activity = params.activity
  local prefs = params.prefs
  local editor = params.editor
  
  local onClose = params.onClose or function() end
  local stopSubMusic = params.stopSubMusic -- Music stop param received here
  
  local getSecureCoins = params.getSecureCoins or _G.getSecureCoins or function() return 0 end
  local setSecureCoins = params.setSecureCoins or _G.setSecureCoins or function(v) end
  
  -- Function passed from Store logic ensuring true transaction deduction sync before giving the item.
  local processServerPurchase = params.processServerPurchase
  
  local attachBackListener = params.attachBackListener or function(dlg, cb)
    pcall(function()
      dlg.setOnKeyListener(luajava.createProxy("android.content.DialogInterface$OnKeyListener", {
        onKey = function(dialog, keyCode, event)
          if keyCode == 4 and event.getAction() == KeyEvent.ACTION_UP then
            cb()
            return true
          end
          return false
        end
      }))
    end)
  end

  -- Load live ownership state natively directly from the primary user preferences 
  local unlockedBoats = {
    pedal = prefs.getBoolean("boat_pedal", false),
    small = prefs.getBoolean("boat_small", true),
    advance = prefs.getBoolean("boat_advance", false),
    big = prefs.getBoolean("boat_big", false),
    hyper = prefs.getBoolean("boat_hyper", false)
  }

  -- UPDATED LAYOUT: Top left back button, right side heading, aur items neeche
  local showroomLayout = {
    LinearLayout, orientation = "vertical", layout_width = "fill", layout_height = "fill", backgroundColor = "#1A1A1A",
    
    -- Header Section 
    { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_height = "wrap", gravity = "center_vertical", padding = "16dp",
      { Button, id = "backShowroomBtn", text = "Back to Market", layout_width = "wrap", layout_height = "wrap", layout_marginRight = "16dp" },
      -- Yahan textStyle="bold" ko fix karke Typeface = Typeface.DEFAULT_BOLD kar diya gaya hai
      { TextView, text = "Showroom", textSize = "24sp", textColor = Color.CYAN, Typeface = Typeface.DEFAULT_BOLD }
    },

    -- Items Section (Items heading kay neechay)
    { ScrollView, layout_width = "fill", layout_height = "fill", fillViewport = "true",
      { LinearLayout, orientation = "vertical", layout_width = "fill", layout_height = "wrap", gravity = "center", padding = "24dp", paddingTop = "8dp",
        { TextView, text = "Aqua Glider Pedal Boat (Speed: 5 m/s)", textSize = "16sp", textColor = Color.WHITE },
        { Button, id = "buyPedalBtn", text = unlockedBoats.pedal and "Owned" or "Buy Aqua Glider (10 Coins)", layout_width = "fill", layout_marginBottom = "20dp", backgroundColor = unlockedBoats.pedal and "#455A64" or "#00897B", textColor = Color.WHITE, enabled = not unlockedBoats.pedal },
        
        { TextView, text = "Wave Runner Mini (Speed: 10 m/s)", textSize = "16sp", textColor = Color.WHITE },
        { Button, id = "buySmallBtn", text = "Owned", layout_width = "fill", layout_marginBottom = "20dp", backgroundColor = "#455A64", textColor = Color.WHITE, enabled = false },
        
        { TextView, text = "Sea Viper Cruiser (Speed: 20 m/s)", textSize = "16sp", textColor = Color.WHITE },
        { Button, id = "buyAdvanceBtn", text = unlockedBoats.advance and "Owned" or "Buy Sea Viper (30 Coins)", layout_width = "fill", layout_marginBottom = "20dp", backgroundColor = unlockedBoats.advance and "#455A64" or "#D84315", textColor = Color.WHITE, enabled = not unlockedBoats.advance },
        
        { TextView, text = "Titan (Speed: 30 m/s)", textSize = "16sp", textColor = Color.WHITE },
        { Button, id = "buyBigBtn", text = unlockedBoats.big and "Owned" or "Buy Titan (50 Coins)", layout_width = "fill", layout_marginBottom = "20dp", backgroundColor = unlockedBoats.big and "#455A64" or "#C62828", textColor = Color.WHITE, enabled = not unlockedBoats.big },
        
        { TextView, text = "Leviathan Hypercraft (Speed: 50 m/s)", textSize = "16sp", textColor = Color.WHITE },
        { Button, id = "buyHyperBtn", text = unlockedBoats.hyper and "Owned" or "Buy Leviathan (100 Coins)", layout_width = "fill", layout_marginBottom = "30dp", backgroundColor = unlockedBoats.hyper and "#455A64" or "#4A148C", textColor = Color.WHITE, enabled = not unlockedBoats.hyper }
      }
    }
  }

  local dlgShowroom = LuaDialog(activity) 
  dlgShowroom.View = loadlayout(showroomLayout) 
  dlgShowroom.setCancelable(false)
  
  -- Unified variables for safe exit
  local isExiting = false
  local lifecycleCallbacks
  
  -- Unified Exit Function: Stops music, cleans up callbacks and closes dialog
  local function exitShowroom()
    if isExiting then return end
    isExiting = true
    if stopSubMusic then stopSubMusic() end
    if lifecycleCallbacks then
      pcall(function() activity.getApplication().unregisterActivityLifecycleCallbacks(lifecycleCallbacks) end)
    end
    pcall(function() dlgShowroom.dismiss() end)
    onClose()
  end

  -- BACKGROUND MUSIC FIX: Register Lifecycle observer.
  -- This reliably triggers exitShowroom() and stops music when Home/Overview button is pressed or screen is closed.
  lifecycleCallbacks = luajava.createProxy("android.app.Application$ActivityLifecycleCallbacks", {
    onActivityCreated = function(act, bundle) end,
    onActivityStarted = function(act) end,
    onActivityResumed = function(act) end,
    onActivityPaused = function(act)
      if act == activity and not isExiting then
        exitShowroom()
      end
    end,
    onActivityStopped = function(act) end,
    onActivitySaveInstanceState = function(act, bundle) end,
    onActivityDestroyed = function(act) end
  })
  pcall(function() activity.getApplication().registerActivityLifecycleCallbacks(lifecycleCallbacks) end)

  -- Guaranteed trigger to stop music if user exits through touching outside dialog unexpectedly
  pcall(function()
    dlgShowroom.setOnDismissListener(luajava.createProxy("android.content.DialogInterface$OnDismissListener", {
      onDismiss = function(dialog)
        if not isExiting then
          exitShowroom()
        end
      end
    }))
  end)

  -- Apply to Hardware Back Button
  attachBackListener(dlgShowroom, exitShowroom)
  
  local function purchaseBoat(boatKey, btn, price, name)
    -- Prevent multi-purchases visually
    if unlockedBoats[boatKey] then return end
    
    local proceedPurchase = function()
        -- Mark as bought globally in memory map
        unlockedBoats[boatKey] = true
        
        -- Secure purchase persist state bridging to Boat Game runtime logic (LOCAL SAVE)
        editor.putBoolean("boat_" .. boatKey, true)
        editor.apply()
        
        -- SERVER SAVE (Boss Ka Data Data Page Par Save Ho Raha Hai)
        pcall(function()
            local username = prefs.getString("username", "")
            if username and username ~= "" then
                local nodeKey = username:lower():gsub(" ", "%%20")
                local firebaseUrl = "https://all-games-76b5d-default-rtdb.firebaseio.com/users/"
                local userUrl = firebaseUrl .. nodeKey .. ".json?x-http-method-override=PATCH"
                local patchData = '{"boat_' .. boatKey .. '": true}'
                
                -- Perform background save to Firebase user node
                Http.post(userUrl, patchData, function(code, content)
                    -- Successfully synced ownership to the server
                end)
            end
        end)
        
        -- Play purchase sound "perchased.mp3"
        pcall(function()
            local pathsToTry = {
                tostring(activity.getLuaDir()) .. "/perchased.mp3",
                tostring(activity.getLuaDir()) .. "/sounds/perchased.mp3",
                tostring(activity.getLuaDir()) .. "/sound/perchased.mp3"
            }
            for _, path in ipairs(pathsToTry) do
                local player = nil
                local success = pcall(function()
                    player = MediaPlayerClass()
                    player.setDataSource(path)
                    player.prepare()
                    player.start()
                    player.setOnCompletionListener(MediaPlayerClass.OnCompletionListener{
                        onCompletion = function(v)
                            pcall(function() v.release() end)
                        end
                    })
                end)
                if success then
                    break
                else
                    if player then pcall(function() player.release() end) end
                end
            end
        end)

        -- Provide Visual UI Feedback locking button
        btn.setText("Owned")
        btn.setEnabled(false)
        btn.setBackgroundColor(Color.parseColor("#455A64"))
        Toast.makeText(activity, name .. " purchased successfully! Available in Boat Game Menu.", 0).show()
    end

    -- Evaluate whether hooked through network-enabled Store
    if processServerPurchase then
       -- Utilize strict online deduction handler preventing free purchases
       processServerPurchase(price, nil, nil, proceedPurchase)
    else
       -- Fallback if opened locally (handles typical local variables & deducts safely)
       local currentCoins = getSecureCoins()
       if currentCoins >= price then
           setSecureCoins(currentCoins - price)
           proceedPurchase()
       else
           Toast.makeText(activity, "Insufficient coins! Required: " .. price, 0).show()
       end
    end
  end
  
  buyPedalBtn.onClick = function() purchaseBoat("pedal", buyPedalBtn, 10, "Aqua Glider") end
  buyAdvanceBtn.onClick = function() purchaseBoat("advance", buyAdvanceBtn, 30, "Sea Viper") end
  buyBigBtn.onClick = function() purchaseBoat("big", buyBigBtn, 50, "Titan") end
  buyHyperBtn.onClick = function() purchaseBoat("hyper", buyHyperBtn, 100, "Leviathan") end
  
  -- Apply to UI Back Button
  backShowroomBtn.onClick = exitShowroom
  
  dlgShowroom.show()
end

return showroom
