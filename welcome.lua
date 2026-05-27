require "import"
import "android.widget.*"
import "android.content.*"
import "android.app.*"
import "android.graphics.*"

local welcomeModule = {}

-- ==========================================
-- Firebase Realtime Database Configuration
-- ==========================================
local firebaseUrl = "https://card-games-muzammil-munir-default-rtdb.firebaseio.com/users/"

-- Generates a secure, random alphanumeric user ID
local function generateRandomUserID(length)
  local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local t = {}
  for i = 1, length do
    local r = math.random(1, #chars)
    table.insert(t, chars:sub(r, r))
  end
  return table.concat(t)
end

-- Generates a new User ID and saves initial registration data to Firebase
function welcomeModule.showUserIdDialog(params, generatedId, username)
  local dlgLayout = {
    LinearLayout,
    orientation = "vertical",
    background = "#000000",
    padding = "24dp",
    gravity = "center",
    layout_width = "fill",
    {
      TextView,
      id = "titleTxt",
      text = "User ID Generated",
      textSize = "20sp",
      textColor = "#FFD700",
      gravity = "center",
      layout_marginBottom = "14dp"
    },
    {
      TextView,
      id = "idTxt",
      text = "Your ID: " .. generatedId,
      textSize = "16sp",
      textColor = "#FFFFFF",
      gravity = "center",
      layout_marginBottom = "24dp"
    },
    {
      Button,
      id = "collectBtn",
      text = "Collect",
      layout_width = "180dp",
      layout_height = "wrap"
    }
  }

  local builder = AlertDialog.Builder(params.activity)
  local view = loadlayout(dlgLayout)
  titleTxt.setTypeface(Typeface.DEFAULT_BOLD)
  params.styleButton(collectBtn)
  builder.setView(view)
  builder.setCancelable(false)
  local idDialog = builder.create()
  idDialog.show()

  params.wrapClick(collectBtn, function()
    local pd = ProgressDialog.show(params.activity, "Saving", "Please wait, syncing with server...")
    
    local nodeKey = username:lower():gsub(" ", "%%20")
    local saveUrl = firebaseUrl .. nodeKey .. ".json?_method=PUT"
    
    local jsonData = '{"userid": "' .. generatedId .. '", "username": "' .. username .. '", "role": "user"}'
    
    Http.post(saveUrl, jsonData, function(code, content)
      pd.dismiss()
      if code >= 200 and code < 300 then
        params.editor.putString("userid", generatedId)
        params.editor.putString("username", username)
        params.editor.putBoolean("first_run", false)
        params.editor.apply()
        idDialog.dismiss()
        Toast.makeText(params.activity, "Registered successfully.", Toast.LENGTH_SHORT).show()
        params.mainUI()
      else
        Toast.makeText(params.activity, "Server sync failed (Error: "..tostring(code).."). Please try again.", Toast.LENGTH_SHORT).show()
      end
    end)
  end)
end

function welcomeModule.usernameScreen(params)
  isGameActive = false
  isTransitioning = false
  
  local currentUname = params.prefs.getString("username", "")
  local currentRole = params.prefs.getString("role", "user")
  
  local layout={ 
    LinearLayout, orientation="vertical", background="#000000", gravity="center", padding="16dp", 
    {TextView,id="txt",text="Enter your username (Max 17 characters allowed.)",gravity="center",textSize="18sp",layout_marginBottom="10dp"}, 
    {EditText,id="nameInput",hint="Enter your username",textColor="#FFFFFF",hintTextColor="#AAAAAA",layout_width="fill",singleLine=true}, 
    {LinearLayout, orientation="horizontal", layout_marginTop="20dp", 
      {Button,id="cancelBtn",text="Cancel",layout_width="0dp",layout_weight="1"}, 
      {Button,id="saveBtn",text="Save",layout_width="0dp",layout_weight="1"} 
    } 
  }
  
  params.activity.setContentView(loadlayout(layout))
  params.whiteText(txt); params.styleButton(cancelBtn); params.styleButton(saveBtn)
  nameInput.setText(currentUname)
  
  params.wrapClick(cancelBtn, function()
    if params.prefs.getBoolean("first_run", true) then
      welcomeModule.welcome3(params)
    else
      params.mainUI()
    end
  end)
  
  params.wrapClick(saveBtn, function()
    local raw_uname = tostring(nameInput.getText())
    local uname = raw_uname:gsub("^%s*(.-)%s*$", "%1"):gsub("%s+", " ")
    
    if uname == "" then 
      Toast.makeText(params.activity, "Username cannot be empty.", Toast.LENGTH_SHORT).show() 
      return 
    end
    
    if #uname > 17 then
      AlertDialog.Builder(params.activity).setTitle("Invalid Length").setMessage("Your username cannot exceed 17 characters.").setPositiveButton("OK", nil).show() 
      return 
    end
    
    if not uname:match("^[a-zA-Z0-9_ ]+$") then 
      AlertDialog.Builder(params.activity).setTitle("Invalid Format").setMessage("Only letters, numbers, spaces, and underscores (_) are allowed.").setPositiveButton("OK", nil).show() 
      return 
    end
    
    -- Restricted "verified" word check
    if uname:lower():find("verified") then
      AlertDialog.Builder(params.activity).setTitle("Not Allowed").setMessage("The word 'verified' is restricted and cannot be used in your username.").setPositiveButton("OK", nil).show()
      return
    end
    
    if currentUname ~= "" and uname == currentUname then
      params.mainUI()
      return
    end

    local isChange = (currentUname ~= "")
    local isCaseOnlyChange = (isChange and currentUname:lower() == uname:lower())
    
    local currentCoins = params.prefs.getInt("coins", 0)
    local lastChangeStr = params.prefs.getString("last_name_change", "0")
    local lastChangeTime = tonumber(lastChangeStr) or 0
    local currentTime = os.time()
    local tenDays = 10 * 24 * 60 * 60
    
    local cost = 0
    local msg = ""

    if isChange then
      if lastChangeTime > 0 and (currentTime - lastChangeTime) < tenDays then
        cost = 30
        local timeRemaining = tenDays - (currentTime - lastChangeTime)
        local daysRemaining = math.ceil(timeRemaining / (24 * 60 * 60))
        msg = "You are attempting to change your username before the 10-day limit. This will cost 30 Coins!\n\nYou can wait and try again after " .. daysRemaining .. " days to change it for the regular cost of 10 Coins.\n\nAre you sure you want to change your username to '" .. uname .. "'?\n\nCost: 30 Coins."
      else
        cost = 10
        msg = "Are you sure you want to change your username to '" .. uname .. "'?\n\nCost: 10 Coins."
      end
      
      if currentCoins < cost then
         Toast.makeText(params.activity, "Not enough coins! You need " .. cost .. " coins to change your username.", Toast.LENGTH_SHORT).show()
         return
      end
    else
      msg = "Are you sure you want to set your username to '" .. uname .. "'?"
    end

    local proceedWithUpdate = function()
      local pd = ProgressDialog.show(params.activity, "Verifying", "Triple checking username availability...")
      
      local newNodeKey = uname:lower():gsub(" ", "%%20")
      local checkUrl = firebaseUrl .. newNodeKey .. ".json"
      
      if isCaseOnlyChange then
        local currentId = params.prefs.getString("userid", "")
        local updateData = '{"userid": "' .. currentId .. '", "username": "' .. uname .. '", "role": "' .. currentRole .. '"}'
        local updateUrl = firebaseUrl .. newNodeKey .. ".json?_method=PUT"
        
        Http.post(updateUrl, updateData, function(updCode, updContent)
          pd.dismiss()
          if updCode >= 200 and updCode < 300 then
            if isChange then
              params.editor.putInt("coins", currentCoins - cost)
              params.editor.putString("last_name_change", tostring(currentTime))
            end
            params.editor.putString("username", uname).apply()
            Toast.makeText(params.activity, "Display name updated.", Toast.LENGTH_SHORT).show()
            params.mainUI()
          else
            Toast.makeText(params.activity, "Failed to update display name.", Toast.LENGTH_SHORT).show()
          end
        end)
        return
      end

      Http.get(checkUrl, function(code, content)
        if code == 200 then
          if content and content ~= "null" then
            pd.dismiss()
            AlertDialog.Builder(params.activity).setTitle("Username Taken").setMessage("This username is already registered. Please choose a different one.").setPositiveButton("Try Again", nil).show()
          else
            if params.prefs.getBoolean("first_run", true) or currentUname == "" then
              pd.dismiss()
              local newId = generateRandomUserID(10)
              welcomeModule.showUserIdDialog(params, newId, uname)
            else
              pd.setMessage("Securing new username and removing old data...")
              local currentId = params.prefs.getString("userid", "")
              local updateData = '{"userid": "' .. currentId .. '", "username": "' .. uname .. '", "role": "' .. currentRole .. '"}'
              local updateUrl = firebaseUrl .. newNodeKey .. ".json?_method=PUT"
              
              Http.post(updateUrl, updateData, function(updCode, updContent)
                if updCode >= 200 and updCode < 300 then
                  local oldNodeKey = currentUname:lower():gsub(" ", "%%20")
                  local deleteUrl = firebaseUrl .. oldNodeKey .. ".json?x-http-method-override=DELETE"
                  
                  -- Delete old node ONLY after successful creation of new node
                  Http.post(deleteUrl, "", function(delCode, delContent)
                    pd.dismiss()
                    if isChange then
                      params.editor.putInt("coins", currentCoins - cost)
                      params.editor.putString("last_name_change", tostring(currentTime))
                    end
                    params.editor.putString("username", uname).apply()
                    Toast.makeText(params.activity, "Username updated successfully.", Toast.LENGTH_SHORT).show()
                    params.mainUI()
                  end)
                else
                  pd.dismiss()
                  Toast.makeText(params.activity, "Failed to update profile. Please try again.", Toast.LENGTH_SHORT).show()
                end
              end)
            end
          end
        else
          pd.dismiss()
          Toast.makeText(params.activity, "Network error. Please check your connection.", Toast.LENGTH_SHORT).show()
        end
      end)
    end

    local confirmDialog = AlertDialog.Builder(params.activity)
    confirmDialog.setTitle("Confirm Username")
    confirmDialog.setMessage(msg)
    confirmDialog.setPositiveButton("Confirm", DialogInterface.OnClickListener{
      onClick = function(dialog, which)
        proceedWithUpdate()
      end
    })
    confirmDialog.setNegativeButton("Cancel", nil)
    confirmDialog.show()
  end)
end

function welcomeModule.welcome3(params)
  isGameActive = false
  isTransitioning = false
  local layout={ 
    LinearLayout, orientation="vertical", background="#000000", gravity="center", layout_width="fill", layout_height="fill", padding="20dp",
    {TextView,id="t3_1",text="This application is developed by Muzammil Muneer and Muhammad Hussain.",gravity="center",textSize="18sp",layout_marginBottom="12dp"}, 
    {TextView,id="t3_2",text="Our mission is to break all boundaries of digital entertainment and create an inclusive environment for every single gamer.",gravity="center",textSize="15sp",textColor="#BBBBBB",layout_marginBottom="10dp"},
    {TextView,id="t3_3",text="We continuously work hard behind the scenes to optimize layout parameters, auditory response speeds, and server structures.",gravity="center",textSize="15sp",textColor="#BBBBBB",layout_marginBottom="15dp"},
    {TextView,id="t3_4",text="Thank you for choosing our application. We hope you will have a great time exploring everything we built for you.",gravity="center",textSize="15sp",textColor="#AAAAAA"},
    {Space, layout_height="25dp"}, 
    {Button,id="n3",text="Next",layout_width="200dp"} 
  }
  params.activity.setContentView(loadlayout(layout))
  params.whiteText(t3_1); params.whiteText(t3_2); params.whiteText(t3_3); params.whiteText(t3_4); params.styleButton(n3)
  t3_1.setTypeface(Typeface.DEFAULT_BOLD)
  params.wrapClick(n3, function() welcomeModule.usernameScreen(params) end)
end

function welcomeModule.welcome1(params)
  isGameActive = false
  isTransitioning = false
  params.playBGM(params.bgm1Path) 
  
  local layout={ 
    LinearLayout, orientation="vertical", background="#000000", gravity="center", layout_width="fill", layout_height="fill", padding="16dp",
    {TextView,id="t1",text="Welcome to All Games Hub",gravity="center",textSize="24sp",layout_marginBottom="20dp"}, 
    {TextView,id="line1",text="This application is a comprehensive platform designed exclusively to provide accessible gaming experiences.",gravity="center",textSize="15sp",layout_marginBottom="8dp"},
    {TextView,id="line2",text="Here you can play all kinds of games, whether it is a card game, a fighting game, or anything else.",gravity="center",textSize="15sp",layout_marginBottom="8dp"},
    {TextView,id="line3",text="Our game also features a Public Chat where players can communicate with each other in real-time.",gravity="center",textSize="15sp",layout_marginBottom="8dp",textColor="#FFD700"},
    {TextView,id="line4",text="Every single audio cue, touch dynamic, and system interface has been engineered to ensure zero barriers.",gravity="center",textSize="15sp",layout_marginBottom="8dp"},
    {TextView,id="line5",text="Prepare yourself to dive deep into an amazing world where accessibility matches competitive entertainment flawlessly.",gravity="center",textSize="15sp"},
    {Space, layout_height="25dp"}, 
    {Button,id="n1",text="Next",layout_width="200dp"} 
  }
  
  params.activity.setContentView(loadlayout(layout))
  params.whiteText(t1)
  params.whiteText(line1); params.whiteText(line2); params.whiteText(line3); params.whiteText(line4); params.whiteText(line5)
  params.styleButton(n1)
  t1.setTypeface(Typeface.DEFAULT_BOLD)
  line3.setTypeface(Typeface.DEFAULT_BOLD) 
  
  params.wrapClick(n1, function() welcomeModule.welcome3(params) end)
end

-- Full Reset Function (Matches Settings Reset Logic completely)
local function performFullReset(params)
  params.editor.remove("username")
  params.editor.remove("userid")
  params.editor.remove("role")
  params.editor.putInt("coins", 0)
  
  -- BMN Stats Reset
  params.editor.putInt("bmn_played", 0)
  params.editor.putInt("bmn_wins", 0)
  params.editor.putInt("bmn_losses", 0)
  params.editor.putInt("bmn_incompleted", 0)
  params.editor.putInt("bmn_p_cards", 0)
  params.editor.putInt("bmn_c_cards", 0)
  params.editor.putInt("bmn_p_piles", 0)
  params.editor.putInt("bmn_cPiles", 0)
  
  -- Memory Game Stats Reset
  params.editor.putInt("memory_matches", 0)
  params.editor.putInt("memory_wins", 0)
  params.editor.putInt("memory_losses", 0)
  params.editor.putInt("memory_incompleted", 0)
  params.editor.putInt("mem_correct_guesses", 0)
  params.editor.putInt("mem_total_guesses", 0)
  
  -- Store Keys Reset
  params.editor.putInt("memory_keys", 0)
  params.editor.putInt("public_chat_keys", 0)
  
  params.editor.putString("adHourlyHistory", "")
  params.editor.putBoolean("first_run", true)
  params.editor.apply()
end

-- Entry point to manage the welcome flow and transitions
function welcomeModule.startAppUiFlow(params)
  local currentUname = params.prefs.getString("username", "")
  local currentId = params.prefs.getString("userid", "")
  local currentRole = params.prefs.getString("role", "user")
  
  -- Step 1: Check conditions for fresh registration flow
  if (params.prefs.getBoolean("first_run", true) or currentUname == "") and currentId == "" then
    params.editor.putBoolean("first_run", true).apply()
    welcomeModule.welcome1(params)
  else
    local pd = ProgressDialog.show(params.activity, "Verifying Account", "Checking server for your profile...")
    
    -- STEP 2: Normal login search via Username Node
    if currentUname ~= "" then
      local nodeKey = currentUname:lower():gsub(" ", "%%20")
      local checkUrl = firebaseUrl .. nodeKey .. ".json"
      
      Http.get(checkUrl, function(code, content)
        if code == 200 then
          if content and content ~= "null" then
            -- Username records match on the database structure
            
            -- Dynamic Role Synchronization
            local serverRole = content:match('"role"%s*:%s*"([^"]+)"')
            if serverRole and serverRole ~= currentRole then
              params.editor.putString("role", serverRole)
            end
            
            -- Verify and handle mismatched User ID mappings
            local serverUserId = content:match('"userid"%s*:%s*"([^"]+)"')
            if serverUserId and serverUserId ~= currentId then
              params.editor.putString("userid", serverUserId)
            end
            
            params.editor.apply()
            pd.dismiss()
            params.mainUI()
          else
            -- STEP 3: Fallback Verification: If username node does not exist, search dynamically by User ID
            if currentId ~= "" then
              local allUsersUrl = firebaseUrl .. ".json"
              
              Http.get(allUsersUrl, function(idCode, idContent)
                pd.dismiss()
                if idCode == 200 and idContent and idContent ~= "{}" and idContent ~= "null" then
                  local matchedUsername, matchedRole = nil, nil
                  
                  -- Scans deep nested object payloads matching the current dynamic User ID sequence perfectly
                  for block in idContent:gmatch("{([^{}]+)}") do
                    local id = block:match('"userid"%s*:%s*"([^"]+)"')
                    if id == currentId then
                      matchedUsername = block:match('"username"%s*:%s*"([^"]+)"')
                      matchedRole = block:match('"role"%s*:%s*"([^"]+)"')
                      break
                    end
                  end
                  
                  if matchedUsername then
                    -- Synchronize and restore target metadata details locally
                    params.editor.putString("username", matchedUsername)
                    if matchedRole and matchedRole ~= currentRole then
                      params.editor.putString("role", matchedRole)
                    end
                    params.editor.apply()
                    Toast.makeText(params.activity, "Your profile has been updated successfully by the admin.", Toast.LENGTH_SHORT).show()
                    params.mainUI()
                  else
                    -- Complete data loss on database -> Execute safe UI dialog reset flow
                    AlertDialog.Builder(params.activity)
                      .setTitle("Account Not Found")
                      .setMessage("Your account no longer exists on the server. Please create a new account.")
                      .setCancelable(false)
                      .setPositiveButton("OK", DialogInterface.OnClickListener{
                        onClick = function(dialog, which)
                          performFullReset(params)
                          welcomeModule.welcome1(params)
                        end
                      })
                      .show()
                  end
                else
                  AlertDialog.Builder(params.activity)
                    .setTitle("Account Not Found")
                    .setMessage("Your account no longer exists on the server. Please create a new account.")
                    .setCancelable(false)
                    .setPositiveButton("OK", DialogInterface.OnClickListener{
                      onClick = function(dialog, which)
                        performFullReset(params)
                        welcomeModule.welcome1(params)
                      end
                    })
                    .show()
                end
              end)
            else
              pd.dismiss()
              performFullReset(params)
              welcomeModule.welcome1(params)
            end
          end
        else
          pd.dismiss()
          Toast.makeText(params.activity, "Network error. Proceeding with saved data.", Toast.LENGTH_SHORT).show()
          params.mainUI()
        end
      end)
    else
      -- STEP 4: Direct query parsing flow if username is locally empty but User ID is active
      if currentId ~= "" then
        local allUsersUrl = firebaseUrl .. ".json"
        
        Http.get(allUsersUrl, function(idCode, idContent)
          pd.dismiss()
          if idCode == 200 and idContent and idContent ~= "{}" and idContent ~= "null" then
            local matchedUsername, matchedRole = nil, nil
            
            for block in idContent:gmatch("{([^{}]+)}") do
              local id = block:match('"userid"%s*:%s*"([^"]+)"')
              if id == currentId then
                matchedUsername = block:match('"username"%s*:%s*"([^"]+)"')
                matchedRole = block:match('"role"%s*:%s*"([^"]+)"')
                break
              end
            end
            
            if matchedUsername then
              params.editor.putString("username", matchedUsername)
              if matchedRole and matchedRole ~= currentRole then
                params.editor.putString("role", matchedRole)
              end
              params.editor.apply()
              Toast.makeText(params.activity, "Profile synced with server.", Toast.LENGTH_SHORT).show()
              params.mainUI()
            else
              AlertDialog.Builder(params.activity)
                .setTitle("Account Not Found")
                .setMessage("Your account no longer exists on the server. Please create a new account.")
                .setCancelable(false)
                .setPositiveButton("OK", DialogInterface.OnClickListener{
                  onClick = function(dialog, which)
                    performFullReset(params)
                    welcomeModule.welcome1(params)
                  end
                })
                .show()
            end
          else
            AlertDialog.Builder(params.activity)
              .setTitle("Account Not Found")
              .setMessage("Your account no longer exists on the server. Please create a new account.")
              .setCancelable(false)
              .setPositiveButton("OK", DialogInterface.OnClickListener{
                onClick = function(dialog, which)
                  performFullReset(params)
                  welcomeModule.welcome1(params)
                end
              })
              .show()
          end
        end)
      else
        pd.dismiss()
        welcomeModule.welcome1(params)
      end
    end
  end
end

return welcomeModule
