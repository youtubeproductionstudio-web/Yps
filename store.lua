local store = {}

function store.show(params)
  local activity = params.activity
  local prefs = params.prefs
  local editor = params.editor
  local mainUI = params.mainUI
  local wrapClick = params.wrapClick
  local styleButton = params.styleButton
  local whiteText = params.whiteText
  
  _G.isStoreShowing = true

  -- Layout is created once outside to prevent screen reader focus from resetting/fluctuating
  local layout = {
    LinearLayout,
    orientation = "vertical",
    layout_width = "fill",
    layout_height = "fill",
    background = "#000000",
    padding = "16dp",
    {
      LinearLayout,
      orientation = "horizontal",
      layout_width = "fill",
      layout_height = "wrap",
      gravity = "center_vertical",
      layout_marginBottom = "20dp",
      {
        Button,
        id = "backBtn",
        text = "Back",
        layout_width = "wrap",
        layout_height = "wrap",
      },
      {
        TextView,
        id = "storeTitle",
        text = "Store",
        textSize = "24sp",
        layout_marginLeft = "20dp",
      },
    },
    {
      TextView,
      id = "coinsTxt",
      text = "",
      textSize = "18sp",
      layout_marginBottom = "30dp",
    },
    -- Memory Key Item Block
    {
      LinearLayout,
      orientation = "vertical",
      layout_width = "fill",
      layout_height = "wrap",
      layout_marginBottom = "20dp",
      background = "#111111",
      padding = "10dp",
      {
        TextView,
        id = "memTitle",
        text = "Memory Game Keys",
        textSize = "16sp",
      },
      {
        TextView,
        id = "memOwnedTxt",
        text = "",
        textSize = "14sp",
        textColor = "#00FF00",
        layout_marginTop = "5dp",
        layout_marginBottom = "5dp",
      },
      {
        TextView,
        id = "memDesc",
        text = "",
        textSize = "14sp",
        textColor = "#AAAAAA",
        layout_marginBottom = "10dp",
      },
      {
        LinearLayout,
        orientation = "horizontal",
        layout_width = "fill",
        {
          Button,
          id = "buyMemBtn",
          text = "Buy 1 Memory Game Key",
          layout_width = "wrap",
          layout_marginRight = "10dp",
        },
        {
          Button,
          id = "buyMemMultiBtn",
          text = "Buy Multiple Memory Game Keys",
          layout_width = "wrap",
        }
      }
    },
    -- Public Chat Key Item Block
    {
      LinearLayout,
      orientation = "vertical",
      layout_width = "fill",
      layout_height = "wrap",
      background = "#111111",
      padding = "10dp",
      {
        TextView,
        id = "chatTitle",
        text = "Public Chat Keys",
        textSize = "16sp",
      },
      {
        TextView,
        id = "chatOwnedTxt",
        text = "",
        textSize = "14sp",
        textColor = "#00FF00",
        layout_marginTop = "5dp",
        layout_marginBottom = "5dp",
      },
      {
        TextView,
        id = "chatDesc",
        text = "",
        textSize = "14sp",
        textColor = "#AAAAAA",
        layout_marginBottom = "10dp",
      },
      {
        LinearLayout,
        orientation = "horizontal",
        layout_width = "fill",
        {
          Button,
          id = "buyChatBtn",
          text = "Buy 1 Public Chat Key",
          layout_width = "wrap",
          layout_marginRight = "10dp",
        },
        {
          Button,
          id = "buyChatMultiBtn",
          text = "Buy Multiple Public Chat Keys",
          layout_width = "wrap",
        }
      }
    },
  }

  -- Initialize views
  activity.setContentView(loadlayout(layout))
  whiteText(storeTitle)
  whiteText(coinsTxt)
  whiteText(memTitle)
  whiteText(chatTitle)
  styleButton(backBtn)
  styleButton(buyMemBtn)
  styleButton(buyMemMultiBtn)
  styleButton(buyChatBtn)
  styleButton(buyChatMultiBtn)

  -- UI Update function (Modifies text values directly without reloading layout)
  local function refreshStoreUI()
    local coins = prefs.getInt("coins", 0)
    local memBoughtBefore = prefs.getBoolean("memory_key_bought_before", false)
    local chatBoughtBefore = prefs.getBoolean("public_chat_key_bought_before", false)

    local memPrice = memBoughtBefore and 4 or 20
    local chatPrice = chatBoughtBefore and 4 or 15

    local memCount = prefs.getInt("memory_keys", 0)
    local chatCount = prefs.getInt("public_chat_keys", 0)

    coinsTxt.setText("You have: " .. coins .. " Coins.")

    -- Memory Text Setup
    memOwnedTxt.setText("You currently own " .. memCount .. " Memory Game Keys.")
    if memBoughtBefore then
      memDesc.setText("Memory Game Entry Key.\nThis key serves as a single match entry token.\nPrice: " .. memPrice .. " Coins")
    else
      memDesc.setText("Unlock Memory Game (First Purchase).\nThis key will be used to permanently unlock this game feature.\nPrice: " .. memPrice .. " Coins")
    end

    -- Public Chat Text Setup
    chatOwnedTxt.setText("You currently own " .. chatCount .. " Public Chat Keys.")
    if chatBoughtBefore then
      chatDesc.setText("Public Chat Entry Key.\nThis key serves as a single room access entry token.\nPrice: " .. chatPrice .. " Coins")
    else
      chatDesc.setText("Unlock Public Chat (First Purchase).\nThis key will be used to permanently unlock this chat feature.\nPrice: " .. chatPrice .. " Coins")
    end
  end

  -- Initial UI content rendering
  refreshStoreUI()

  -- Bulletproof Dialog Box for Bulk Purchasing
  local function showMultipleKeysDialog(keyTypeStr)
    local isMem = (keyTypeStr == "memory")
    local boughtKeyStr = isMem and "memory_key_bought_before" or "public_chat_key_bought_before"
    local countKeyStr = isMem and "memory_keys" or "public_chat_keys"
    
    local boughtBefore = prefs.getBoolean(boughtKeyStr, false)
    local pricePerKey = boughtBefore and 4 or (isMem and 20 or 15)
    local itemName = isMem and "Memory Game" or "Public Chat"

    import "android.widget.EditText"
    import "android.app.AlertDialog"
    
    local input = EditText(activity)
    input.setInputType(2) -- Number password/numeric keyboard configuration
    input.setHint("Enter amount of keys")

    local dialog = AlertDialog.Builder(activity)
    dialog.setTitle("Purchase Multiple " .. itemName .. " Keys")
    dialog.setMessage("Price per key: " .. pricePerKey .. " Coins.\nHow many keys do you want to purchase?")
    dialog.setView(input)
    dialog.setPositiveButton("Buy Now", {
      onClick = function()
        -- Fresh verification check directly against database state inside click scope
        local currentCoins = prefs.getInt("coins", 0)
        local qtyText = input.getText().toString()
        local qty = tonumber(qtyText)
        
        if qty and qty > 0 then
          local totalCost = qty * pricePerKey
          
          if currentCoins >= totalCost then
            editor.putInt("coins", currentCoins - totalCost)
            editor.putBoolean(boughtKeyStr, true)
            editor.putInt(countKeyStr, prefs.getInt(countKeyStr, 0) + qty)
            editor.apply()
            
            import "android.widget.Toast"
            Toast.makeText(activity, qty .. " " .. itemName .. " keys purchased successfully!", Toast.LENGTH_SHORT).show()
            refreshStoreUI()
          else
            import "android.widget.Toast"
            Toast.makeText(activity, "Transaction failed! Not enough coins. You need " .. totalCost .. " coins.", Toast.LENGTH_SHORT).show()
          end
        else
          import "android.widget.Toast"
          Toast.makeText(activity, "Please enter a valid positive number.", Toast.LENGTH_SHORT).show()
        end
      end
    })
    dialog.setNegativeButton("Cancel", nil)
    dialog.show()
  end

  -- Navigation Actions
  wrapClick(backBtn, function()
    _G.isStoreShowing = false
    mainUI()
  end)

  -- Purchase Action Handlers
  wrapClick(buyMemBtn, function()
    local memBoughtBefore = prefs.getBoolean("memory_key_bought_before", false)
    local memPrice = memBoughtBefore and 4 or 20
    local currentCoins = prefs.getInt("coins", 0) -- Fresh live read validation
    
    if currentCoins >= memPrice then
      editor.putInt("coins", currentCoins - memPrice)
      editor.putBoolean("memory_key_bought_before", true)
      editor.putInt("memory_keys", prefs.getInt("memory_keys", 0) + 1)
      editor.apply()
      import "android.widget.Toast"
      Toast.makeText(activity, "1 Memory Game Key purchased successfully!", Toast.LENGTH_SHORT).show()
      refreshStoreUI()
    else
      import "android.widget.Toast"
      Toast.makeText(activity, "Transaction failed! Not enough coins.", Toast.LENGTH_SHORT).show()
    end
  end)

  wrapClick(buyMemMultiBtn, function()
    showMultipleKeysDialog("memory")
  end)

  wrapClick(buyChatBtn, function()
    local chatBoughtBefore = prefs.getBoolean("public_chat_key_bought_before", false)
    local chatPrice = chatBoughtBefore and 4 or 15
    local currentCoins = prefs.getInt("coins", 0) -- Fresh live read validation
    
    if currentCoins >= chatPrice then
      editor.putInt("coins", currentCoins - chatPrice)
      editor.putBoolean("public_chat_key_bought_before", true)
      editor.putInt("public_chat_keys", prefs.getInt("public_chat_keys", 0) + 1)
      editor.apply()
      import "android.widget.Toast"
      Toast.makeText(activity, "1 Public Chat Key purchased successfully!", Toast.LENGTH_SHORT).show()
      refreshStoreUI()
    else
      import "android.widget.Toast"
      Toast.makeText(activity, "Transaction failed! Not enough coins.", Toast.LENGTH_SHORT).show()
    end
  end)

  wrapClick(buyChatMultiBtn, function()
    showMultipleKeysDialog("chat")
  end)
end

return store
