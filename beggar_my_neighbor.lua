local bmn = {}
local env = {}

local deck = {}
local playerHand = {}
local computerHand = {}
local board = {}
local isPlayerTurn = true
local cardsToGive = 0

-- Dynamic English reward messages ki list
local winMessages = {
  "You earned 6 points as a victory bonus!",
  "Great job! 6 points have been added to your coins.",
  "Awesome play! 6 points credited to your account.",
  "Victory reward! You received 6 points.",
  "Brilliant win! 6 bonus points are now yours.",
  "You nailed it! Enjoy your 6 winning points."
}

local function setupDeck()
  deck = {}
  local suits = {{n="Hearts", s="♥", c="#FF0000"}, {n="Diamonds", s="♦", c="#FF0000"}, {n="Clubs", s="♣", c="#000000"}, {n="Spades", s="♠", c="#000000"}}
  for _, suit in ipairs(suits) do
    for i=2, 10 do table.insert(deck, {name=i, suit=suit.s, color=suit.c, fullName=i.." of "..suit.n, value=0, type="normal"}) end
    table.insert(deck, {name="A", suit=suit.s, color=suit.c, fullName="Ace of "..suit.n, value=4, type="special"})
    table.insert(deck, {name="K", suit=suit.s, color=suit.c, fullName="King of "..suit.n, value=3, type="special"})
    table.insert(deck, {name="Q", suit=suit.s, color=suit.c, fullName="Queen of "..suit.n, value=2, type="special"})
    table.insert(deck, {name="J", suit=suit.s, color=suit.c, fullName="Jack of "..suit.n, value=1, type="special"})
  end
  math.randomseed(os.time())
  for i = #deck, 2, -1 do local j = math.random(i); deck[i], deck[j] = deck[j], deck[i] end
  playerHand, computerHand = {}, {}
  for i=1, 52 do if i <= 26 then table.insert(playerHand, deck[i]) else table.insert(computerHand, deck[i]) end end
  isPlayerTurn, cardsToGive, board = true, 0, {}
end

local function showResultDialog(title, message)
  local dialogLayout = {
    LinearLayout, orientation="vertical", layout_width="fill", background="#FFFFFF", padding="20dp", gravity="center",
    {TextView,id="resMsg",text=message,textSize="18sp",textColor="#000000",gravity="center",layout_marginBottom="20dp"},
    {LinearLayout, layout_width="fill", gravity="center",
      {Button,id="retryBtn",text="PLAY AGAIN",layout_width="0dp",layout_weight="1"},
      {Button,id="backBtn",text="BACK",layout_width="0dp",layout_weight="1",layout_marginLeft="10dp"}
    }
  }
  local builder = AlertDialog.Builder(env.activity); local v = loadlayout(dialogLayout)
  env.styleButton(retryBtn); env.styleButton(backBtn); resMsg.setTypeface(Typeface.DEFAULT_BOLD); builder.setView(v); builder.setCancelable(false)
  local resultDlg = builder.create(); resultDlg.show()
  env.wrapClick(retryBtn, function() resultDlg.dismiss(); bmn.start(env) end)
  env.wrapClick(backBtn, function() resultDlg.dismiss(); env.mainUI() end)
end

local function createCardUI(idPrefix)
  return { CardView, id=idPrefix.."Card", layout_width="115dp", layout_height="165dp", cardBackgroundColor="#FFFFFF", cardElevation="15dp", radius="12dp", visibility=View.INVISIBLE,
    { RelativeLayout, layout_width="fill", layout_height="fill", padding="8dp",
      {TextView,id=idPrefix.."TopLabel",textSize="22sp",layout_alignParentTop=true,layout_alignParentLeft=true},
      {TextView,id=idPrefix.."MainSuit",textSize="55sp",layout_centerInParent=true} } }
end

local function updateCardGraphics(card, side)
  local cardView, topText, mainSuitText
  if side == "play" then 
    cardView, topText, mainSuitText = playCard, playTopLabel, playMainSuit 
  else 
    cardView, topText, mainSuitText = compCard, compTopLabel, compMainSuit 
  end
  if card and cardView then
    cardView.setVisibility(View.VISIBLE)
    topText.Text = tostring(card.name).." "..card.suit
    mainSuitText.Text = card.suit
    local c = Color.parseColor(card.color)
    topText.setTextColor(c)
    mainSuitText.setTextColor(c)
    topText.setTypeface(Typeface.DEFAULT_BOLD)
  end
end

local function updateUI(msg)
  if statusLabel then statusLabel.Text = msg end
  if cardCountLabel then cardCountLabel.Text = "Your Cards: "..#playerHand.."\nComputer Cards: "..#computerHand end
  if boardText then boardText.Text = "Pile: "..#board.." cards" end
end

local function awardBoard(winnerHand, isPlayerWinner)
  local cardsWon = #board
  for _, c in ipairs(board) do table.insert(winnerHand, c) end
  board, cardsToGive = {}, 0
  if playCard then playCard.setVisibility(View.INVISIBLE) end
  if compCard then compCard.setVisibility(View.INVISIBLE) end
  
  -- Stats Update Logic
  if isPlayerWinner ~= nil then
    if isPlayerWinner then
      local pCards = env.prefs.getInt("bmn_p_cards", 0) + cardsWon
      local pPiles = env.prefs.getInt("bmn_p_piles", 0) + 1
      env.editor.putInt("bmn_p_cards", pCards)
      env.editor.putInt("bmn_p_piles", pPiles)
      env.editor.apply()
    else
      local cCards = env.prefs.getInt("bmn_c_cards", 0) + cardsWon
      local cPiles = env.prefs.getInt("bmn_c_piles", 0) + 1
      env.editor.putInt("bmn_c_cards", cCards)
      env.editor.putInt("bmn_c_piles", cPiles)
      env.editor.apply()
    end
  end
end

local checkComputerTurn -- Pre-declare function
local playTurn          -- Pre-declare function

local function checkGameOver()
  if #playerHand == 0 or #computerHand == 0 then
    if #playerHand == 0 and cardsToGive > 0 then 
      awardBoard(computerHand, false) 
    elseif #computerHand == 0 and cardsToGive > 0 then 
      awardBoard(playerHand, true) 
    end
    if #playerHand == 0 then
      local bmnLosses = env.prefs.getInt("bmn_losses", 0) + 1
      env.editor.putInt("bmn_losses", bmnLosses).apply()
      updateUI("Match Over"); env.playSound(env.loseSound); showResultDialog("Match Over", "Computer Win, Better Luck Next Time")
      return true
    elseif #computerHand == 0 then
      local bmnWins = env.prefs.getInt("bmn_wins", 0) + 1
      env.editor.putInt("bmn_wins", bmnWins).apply()
      
      -- Coins data update logic (6 points plus)
      local currentCoins = env.prefs.getInt("coins", 0) + 6
      env.editor.putInt("coins", currentCoins).apply()
      
      -- winMessages list se random index select karna
      local randomIndex = math.random(1, #winMessages)
      local selectedRewardMsg = winMessages[randomIndex]
      
      updateUI("Match Over"); env.playSound(env.winSound); 
      
      -- Sukoon se ek hi success dialogue mein text append kar diya gaya hai
      showResultDialog("Match Over", "Congratulations! You Win.\n\n" .. selectedRewardMsg)
      return true
    end
  end
  return false
end

playTurn = function()
  if checkGameOver() then return end
  local currentHand = isPlayerTurn and playerHand or computerHand
  local opponentHand = isPlayerTurn and computerHand or playerHand
  local playedCard = table.remove(currentHand, 1)
  if not playedCard then return end
  env.playSound(env.cardPlaySound)
  table.insert(board, playedCard); updateCardGraphics(playedCard, isPlayerTurn and "play" or "comp")
  local name = isPlayerTurn and "You" or "Computer"; local msg = name.." played "..playedCard.fullName; env.ttsAnnounce(msg)
  
  local runHandler = Handler()
  if playedCard.type == "special" then
    cardsToGive = playedCard.value; isPlayerTurn = not isPlayerTurn; updateUI(msg..". Give "..cardsToGive.." cards")
  elseif cardsToGive > 0 then
    cardsToGive = cardsToGive - 1
    if cardsToGive == 0 then
      local winnerMsg = "Pile collected by "..(isPlayerTurn and "Computer" or "You"); updateUI(winnerMsg)
      runHandler.postDelayed(Runnable{run=function() env.ttsAnnounce(winnerMsg) end}, 800)
      if playBtn then playBtn.Enabled = false end
      runHandler.postDelayed(Runnable{run=function() 
         awardBoard(opponentHand, not isPlayerTurn)
         updateUI("Pile collected")
         isPlayerTurn = not isPlayerTurn
         if not checkGameOver() then checkComputerTurn() end 
      end}, 1800)
      return
    else updateUI(msg..". "..cardsToGive.." more") end
  else isPlayerTurn = not isPlayerTurn; updateUI(msg) end
  checkComputerTurn()
end

checkComputerTurn = function()
  if not isPlayerTurn then 
    if playBtn then playBtn.Enabled = false end
    Handler().postDelayed(Runnable{run=function() if not checkGameOver() then playTurn() end end}, 1500) 
  else 
    if playBtn then playBtn.Enabled = true end 
  end
end

function bmn.start(dependencies)
  env = dependencies
  _G.isGameActive = true
  _G.isTransitioning = false
  
  local bmnPlayed = env.prefs.getInt("bmn_played", 0) + 1
  env.editor.putInt("bmn_played", bmnPlayed).apply()

  local game_layout = {
    RelativeLayout, layout_width="fill", layout_height="fill", id="gameView",
    {TextView,id="statusLabel",text="Card Game",textSize="20sp",textColor="#FFD700",layout_centerHorizontal=true,layout_marginTop="40dp"},
    {LinearLayout, layout_width="fill", gravity="center", layout_centerInParent=true,
      {LinearLayout, orientation="vertical", gravity="center", layout_marginRight="10dp", {TextView, text="Computer", textColor="#FFFFFF", layout_marginBottom="10dp", textSize="14sp"}, createCardUI("comp")},
      {LinearLayout, orientation="vertical", gravity="center", layout_marginLeft="10dp", {TextView, text="You", textColor="#FFFFFF", layout_marginBottom="10dp", textSize="14sp"}, createCardUI("play")} },
    {LinearLayout, id="bottomBar", layout_width="fill", layout_height="100dp", layout_alignParentBottom=true, padding="15dp", gravity="center",
      {CardView, layout_width="0dp", layout_weight="1", layout_height="60dp", radius="8dp", cardBackgroundColor="#FFFFFF", layout_marginRight="8dp", {Button,id="playBtn",text="PLAY CARD",background="#00000000",textColor="#000000"}},
      {CardView, layout_width="0dp", layout_weight="1", layout_height="60dp", radius="8dp", cardBackgroundColor="#FFFFFF", layout_marginLeft="8dp", {LinearLayout, layout_width="fill", layout_height="fill", gravity="center", orientation="vertical", {TextView,id="cardCountLabel",text="",textColor="#000000",textSize="11sp",gravity="center"}}} },
    {TextView,id="boardText",text="",layout_above="bottomBar",layout_centerHorizontal=true,textColor="#FFFFFF",layout_marginBottom="10dp",textSize="16sp"}
  }
  
  env.activity.setContentView(loadlayout(game_layout))
  gameView.setBackground(env.bg); statusLabel.setTypeface(Typeface.DEFAULT_BOLD); cardCountLabel.setTypeface(Typeface.DEFAULT_BOLD)
  
  local handler = Handler()
  handler.postDelayed(Runnable{run=function() env.playSound(env.shuffleSound) end}, 300)
  
  env.wrapClick(playBtn, function() playTurn() end)
  setupDeck(); updateUI("Game Ready! Your Turn")
end

return bmn
