local profile = {}

function profile.profileUI()
  isGameActive = false
  isTransitioning = false
  isProfileShowing = true
  
  local savedName = prefs.getString("username", "Guest")
  local coins = prefs.getInt("coins", 0)
  
  -- BMN Stats
  local bmnPlayed = prefs.getInt("bmn_played", 0)
  local bmnWins = prefs.getInt("bmn_wins", 0)
  local bmnLosses = prefs.getInt("bmn_losses", 0)
  local bmnIncompleted = prefs.getInt("bmn_incompleted", 0)
  
  local pCards = prefs.getInt("bmn_p_cards", 0)
  local cCards = prefs.getInt("bmn_c_cards", 0)
  local pPiles = prefs.getInt("bmn_p_piles", 0)
  local cPiles = prefs.getInt("bmn_cPiles", 0)

  -- Memory Game Stats (Updated keys to sync with memory.lua)
  local memPlayed = prefs.getInt("memory_matches", 0)
  local memWins = prefs.getInt("memory_wins", 0)
  local memLosses = prefs.getInt("memory_losses", 0)
  local memIncompleted = prefs.getInt("memory_incompleted", 0)
  local memCorrectGuesses = prefs.getInt("mem_correct_guesses", 0)
  local memTotalGuesses = prefs.getInt("mem_total_guesses", 0)
  
  -- Store Items Status
  local memCount = prefs.getInt("memory_keys", 0)
  local chatCount = prefs.getInt("public_chat_keys", 0)
  
  local userLevel = 1 + math.floor(bmnPlayed / 10)
  
  -- BMN Percentages
  local bmnWinPercent = 0
  local bmnLossPercent = 0
  if bmnPlayed > 0 then
    bmnWinPercent = (bmnWins / bmnPlayed) * 100
    bmnLossPercent = (bmnLosses / bmnPlayed) * 100
  end
  local bmnWinPercentStr = string.format("%.1f%%", bmnWinPercent)
  local bmnLossPercentStr = string.format("%.1f%%", bmnLossPercent)

  local compWins = bmnLosses
  local compLosses = bmnWins
  local compWinPercentStr = bmnLossPercentStr
  local compLossPercentStr = bmnWinPercentStr

  local totalCards = pCards + cCards
  local totalPiles = pPiles + cPiles
  
  local pCardPercent, cCardPercent, pPilePercent, cPilePercent = 0, 0, 0, 0
  if totalCards > 0 then
    pCardPercent = (pCards / totalCards) * 100
    cCardPercent = (cCards / totalCards) * 100
  end
  if totalPiles > 0 then
    pPilePercent = (pPiles / totalPiles) * 100
    cPilePercent = (cPiles / totalPiles) * 100
  end

  local pCardPercentStr = string.format("%.1f%%", pCardPercent)
  local cCardPercentStr = string.format("%.1f%%", cCardPercent)
  local pPilePercentStr = string.format("%.1f%%", pPilePercent)
  local cPilePercentStr = string.format("%.1f%%", cPilePercent)

  -- Memory Game Percentages
  local memWinPercent = 0
  local memLossPercent = 0
  if memPlayed > 0 then
    memWinPercent = (memWins / memPlayed) * 100
    memLossPercent = (memLosses / memPlayed) * 100
  end
  local memWinPercentStr = string.format("%.1f%%", memWinPercent)
  local memLossPercentStr = string.format("%.1f%%", memLossPercent)

  local memCorrectPercent = 0
  if memTotalGuesses > 0 then
    memCorrectPercent = (memCorrectGuesses / memTotalGuesses) * 100
  end
  local memCorrectPercentStr = string.format("%.1f%%", memCorrectPercent)

  local compMemWins = memLosses
  local compMemLosses = memWins
  local compMemWinPercentStr = memLossPercentStr
  local compMemLossPercentStr = memWinPercentStr

  local profile_layout = {
    RelativeLayout,
    layout_width="fill",
    layout_height="fill",
    background="#000000",
    {
      RelativeLayout,
      id="headerBar",
      layout_width="fill",
      layout_height="60dp",
      background="#111111",
      layout_alignParentTop=true,
      padding="10dp",
      {Button, id="profBackBtn", text="Back", layout_alignParentLeft=true, layout_centerVertical=true},
      {TextView, id="profTitle", text="Profile", textSize="22sp", textColor="#FFFFFF", layout_centerInParent=true},
      {Button, id="profShareBtn", text="Share Profile", layout_alignParentRight=true, layout_centerVertical=true}
    },
    {
      ScrollView,
      layout_width="fill",
      layout_height="fill",
      layout_below="headerBar",
      padding="20dp",
      {
        LinearLayout,
        orientation="vertical",
        layout_width="fill",
        {TextView, id="profUserLabel", text="Username: " .. savedName, textSize="18sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
        {TextView, id="profLevelLabel", text="Level: " .. userLevel, textSize="16sp", textColor="#00FF00", layout_marginBottom="5dp"},
        {TextView, id="profCoinsLabel", text="Coins: " .. coins, textSize="16sp", textColor="#FFFFD700", layout_marginBottom="25dp"},
        
        {TextView, text="STORE ITEMS OWNED", textSize="16sp", textColor="#00E5FF", layout_marginBottom="15dp"},
        {
          LinearLayout,
          orientation="vertical",
          layout_width="fill",
          background="#111111",
          padding="15dp",
          layout_marginBottom="15dp",
          {TextView, text="You have " .. memCount .. " Memory Game keys.", textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="You have " .. chatCount .. " Public Chat keys.", textSize="14sp", textColor="#FFFFFF"}
        },
        
        {TextView, text="GAME STATISTICS", textSize="16sp", textColor="#00E5FF", layout_marginBottom="15dp"},
        
        {
          LinearLayout,
          orientation="vertical",
          layout_width="fill",
          background="#111111",
          padding="15dp",
          layout_marginBottom="15dp",
          
          -- BMN Stats UI
          {TextView, text="Beggar My Neighbor", textSize="16sp", textColor="#FFD700", layout_marginBottom="10dp"},
          {TextView, text="Total Played Matches: " .. bmnPlayed, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Win Matches: " .. bmnWins, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Win Matches Percentage: " .. bmnWinPercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Loss Matches: " .. bmnLosses, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Loss Matches Percentage: " .. bmnLossPercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Total Cards Captured: " .. pCards, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Cards Captured Percentage: " .. pCardPercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Total Piles Collected: " .. pPiles, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Piles Collected Percentage: " .. pPilePercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Incompleted Matches: " .. bmnIncompleted, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="12dp"},
          
          {TextView, text="Computer Statistics:", textSize="14sp", textColor="#FF69B4", layout_marginBottom="5dp"},
          {TextView, text="Computer Win Matches: " .. compWins, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Computer Win Matches Percentage: " .. compWinPercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Computer Loss Matches: " .. compLosses, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Computer Loss Matches Percentage: " .. compLossPercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Computer Total Cards Captured: " .. cCards, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Computer Cards Captured Percentage: " .. cCardPercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Computer Total Piles Collected: " .. cPiles, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Computer Piles Collected Percentage: " .. cPilePercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="25dp"},

          -- Memory Game Stats UI
          {TextView, text="Memory Game", textSize="16sp", textColor="#FFD700", layout_marginBottom="10dp"},
          {TextView, text="Total Played Matches: " .. memPlayed, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Win Matches: " .. memWins, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Win Matches Percentage: " .. memWinPercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Loss Matches: " .. memLosses, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Loss Matches Percentage: " .. memLossPercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Total Correct Guesses: " .. memCorrectGuesses, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Your Correct Guesses Percentage: " .. memCorrectPercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Incompleted Matches: " .. memIncompleted, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="12dp"},
          
          {TextView, text="Computer Statistics:", textSize="14sp", textColor="#FF69B4", layout_marginBottom="5dp"},
          {TextView, text="Computer Win Matches: " .. compMemWins, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Computer Win Matches Percentage: " .. compMemWinPercentStr, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Computer Loss Matches: " .. compMemLosses, textSize="14sp", textColor="#FFFFFF", layout_marginBottom="5dp"},
          {TextView, text="Computer Loss Matches Percentage: " .. compMemLossPercentStr, textSize="14sp", textColor="#FFFFFF"}
        }
      }
    }
  }
  
  activity.setContentView(loadlayout(profile_layout))
  styleButton(profBackBtn)
  styleButton(profShareBtn)
  profTitle.setTypeface(Typeface.DEFAULT_BOLD)
  
  wrapClick(profBackBtn, function()
    isProfileShowing = false
    mainUI()
  end)
  
  wrapClick(profShareBtn, function()
    local shareOptions = {"Share All Stats", "Share Beggar My Neighbor Stats", "Share Memory Game Stats"}
    
    AlertDialog.Builder(activity)
      .setTitle("Select Stats to Share")
      .setItems(String(shareOptions), {onClick=function(dialog, which)
        
        local introOptions = {
          "Greetings! Check out my latest milestone as " .. savedName .. ", reaching Level " .. userLevel .. " with " .. coins .. " coins!",
          "Hello world! I am dominating the board as " .. savedName .. ". Currently at Level " .. userLevel .. " with " .. coins .. " coins.",
          "Think you can match this? " .. savedName .. " here, rocking Level " .. userLevel .. " and holding " .. coins .. " gold coins.",
          "Level " .. userLevel .. " achieved! This is " .. savedName .. " showing off a solid stash of " .. coins .. " coins.",
          "My card gaming journey is hitting new heights. Player: " .. savedName .. " | Level: " .. userLevel .. " | Coins: " .. coins .. ".",
          "Hey everyone! Just updating my gaming profile. " .. savedName .. " is now at Level " .. userLevel .. " with " .. coins .. " coins.",
          "The grind never stops. " .. savedName .. " has advanced to Level " .. userLevel .. ", securing " .. coins .. " coins so far.",
          "Current status: Unstoppable. " .. savedName .. " is sitting on Level " .. userLevel .. " with " .. coins .. " coins in the bag.",
          "Shoutout to all gaming strategy fans! " .. savedName .. " here, proud owner of Level " .. userLevel .. " and " .. coins .. " coins.",
          "A new record is in the making. Follow " .. savedName .. "'s progress: Level " .. userLevel .. " with " .. coins .. " coins!",
          "Gaming strategy at its finest! This is " .. savedName .. " presenting Level " .. userLevel .. " alongside " .. coins .. " coins.",
          "Victory belongs to the persistent. " .. savedName .. " has conquered Level " .. userLevel .. " and amassed " .. coins .. " coins.",
          "Step into my arena! " .. savedName .. " is currently executing masterclasses at Level " .. userLevel .. " with " .. coins .. " coins.",
          "Leveling up feels amazing. " .. savedName .. " just hit Level " .. userLevel .. " and holds a fortune of " .. coins .. " coins.",
          "Behold my latest progression card. Username: " .. savedName .. " | Rank Level: " .. userLevel .. " | Wealth: " .. coins .. " coins.",
          "Mastering the games one match at a time. This is " .. savedName .. ", currently Level " .. userLevel .. " with " .. coins .. " coins.",
          "Tactical gameplay is paying off. " .. savedName .. " has claimed Level " .. userLevel .. " and gathered " .. coins .. " coins.",
          "Track my elite status! " .. savedName .. " is officially Level " .. userLevel .. ", boasting an impressive " .. coins .. " coins.",
          "No luck, pure skill. " .. savedName .. " is scaling the ranks at Level " .. userLevel .. " with " .. coins .. " coins.",
          "Quick update from the leaderboard. " .. savedName .. " is holding strong at Level " .. userLevel .. " with " .. coins .. " coins."
        }

        local outroOptions = {
          "All Games Hub is beautifully crafted and developed by Muzammil Muneer and Muhammad Hussain. Join the challenge now!",
          "Experience the thrill of strategy and skill. All Games Hub is developed by Muzammil Muneer and Muhammad Hussain. See you in the arena!",
          "Step up your game and challenge these stats! Developed by Muzammil Muneer and Muhammad Hussain, All Games Hub is waiting for you.",
          "Think you have what it takes to break my streak? Download All Games Hub by Muzammil Muneer and Muhammad Hussain today!",
          "Brought to you by the creative minds of Muzammil Muneer and Muhammad Hussain. Get ready and join the action!",
          "Every match is a lesson in strategy. Play All Games Hub, an exceptional title developed by Muzammil Muneer and Muhammad Hussain.",
          "Join millions of players in this epic gaming tracker. Masterfully developed by Muzammil Muneer and Muhammad Hussain.",
          "Are you ready to test your tactical limits? Install All Games Hub by Muzammil Muneer and Muhammad Hussain and show your skills!",
          "Proudly developed by Muzammil Muneer and Muhammad Hussain. Jump into the ultimate gaming experience right now.",
          "Can you handle the heat of a true duel? Find out in All Games Hub, engineered by Muzammil Muneer and Muhammad Hussain.",
          "Sharpen your mind and perfect your tactics. All Games Hub by Muzammil Muneer and Muhammad Hussain is the ultimate proving ground.",
          "From beginner to grandmaster, your journey starts here. All Games Hub is proudly developed by Muzammil Muneer and Muhammad Hussain.",
          "Don't just watch, come and claim your own victories! Download All Games Hub, designed by Muzammil Muneer and Muhammad Hussain.",
          "Epic turn-based battles await you. Dive into All Games Hub, an amazing creation by Muzammil Muneer and Muhammad Hussain.",
          "Claim your daily rewards and build your gaming empire. Developed with passion by Muzammil Muneer and Muhammad Hussain.",
          "Prove your intellectual superiority on the digital board. Get All Games Hub by Muzammil Muneer and Muhammad Hussain today!",
          "The ultimate blend of classic rules and modern smooth UI. All Games Hub is developed by Muzammil Muneer and Muhammad Hussain.",
          "Take the challenge, beat the computer, and rule the lobby! All Games Hub by Muzammil Muneer and Muhammad Hussain is live.",
          "Brilliant strategy requires a brilliant game. Play All Games Hub, masterfully coded by Muzammil Muneer and Muhammad Hussain.",
          "Are you the next champion? Start your ultimate legacy in All Games Hub by Muzammil Muneer and Muhammad Hussain!"
        }

        math.randomseed(os.time())
        local selectedIntro = introOptions[math.random(1, #introOptions)]
        local selectedOutro = outroOptions[math.random(1, #outroOptions)]

        local bmnStatsStr = "Game Mode: Beggar My Neighbor\n" ..
                            "- Total Matches Played: " .. bmnPlayed .. "\n" ..
                            "- My win matches: " .. bmnWins .. "\n" ..
                            "- My win matches percentage: " .. bmnWinPercentStr .. "\n" ..
                            "- My loss matches: " .. bmnLosses .. "\n" ..
                            "- My loss matches percentage: " .. bmnLossPercentStr .. "\n" ..
                            "- My total cards captured: " .. pCards .. "\n" ..
                            "- My cards captured percentage: " .. pCardPercentStr .. "\n" ..
                            "- My total piles collected: " .. pPiles .. "\n" ..
                            "- My piles collected percentage: " .. pPilePercentStr .. "\n" ..
                            "- Incompleted Matches: " .. bmnIncompleted .. "\n" ..
                            "- Computer win matches: " .. compWins .. "\n" ..
                            "- Computer win matches percentage: " .. compWinPercentStr .. "\n" ..
                            "- Computer loss matches: " .. compLosses .. "\n" ..
                            "- Computer loss matches percentage: " .. compLossPercentStr .. "\n" ..
                            "- Computer total cards captured: " .. cCards .. "\n" ..
                            "- Computer cards captured percentage: " .. cCardPercentStr .. "\n" ..
                            "- Computer total piles collected: " .. cPiles .. "\n" ..
                            "- Computer piles collected percentage: " .. cPilePercentStr .. "\n\n"

        local memStatsStr = "Game Mode: Memory Game\n" ..
                            "- Total Matches Played: " .. memPlayed .. "\n" ..
                            "- My win matches: " .. memWins .. "\n" ..
                            "- My win matches percentage: " .. memWinPercentStr .. "\n" ..
                            "- My loss matches: " .. memLosses .. "\n" ..
                            "- My loss matches percentage: " .. memLossPercentStr .. "\n" ..
                            "- My total correct guesses: " .. memCorrectGuesses .. "\n" ..
                            "- My correct guesses percentage: " .. memCorrectPercentStr .. "\n" ..
                            "- Incompleted Matches: " .. memIncompleted .. "\n" ..
                            "- Computer win matches: " .. compMemWins .. "\n" ..
                            "- Computer win matches percentage: " .. compMemWinPercentStr .. "\n" ..
                            "- Computer loss matches: " .. compMemLosses .. "\n" ..
                            "- Computer loss matches percentage: " .. compMemLossPercentStr .. "\n\n"

        local selectedStats = ""
        
        if which == 0 then
            selectedStats = "LIVE PERFORMANCE STATISTICS:\n\n" .. bmnStatsStr .. memStatsStr
        elseif which == 1 then
            selectedStats = "LIVE PERFORMANCE STATISTICS:\n\n" .. bmnStatsStr
        elseif which == 2 then
            selectedStats = "LIVE PERFORMANCE STATISTICS:\n\n" .. memStatsStr
        end

        local shareText = selectedIntro .. "\n\n" ..
                          "MY STORE INVENTORY STATUS:\n" ..
                          "- I have " .. memCount .. " Memory Game Keys.\n" ..
                          "- I have " .. chatCount .. " Public Chat Keys.\n\n" ..
                          selectedStats ..
                          selectedOutro
                          
        pcall(function()
          local intent = Intent(Intent.ACTION_SEND)
          intent.setType("text/plain")
          intent.putExtra(Intent.EXTRA_TEXT, shareText)
          activity.startActivity(Intent.createChooser(intent, "Share Profile via"))
        end)
      end})
      .show()
  end)
end

return profile
