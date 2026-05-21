local gamesMenuModule = {}

function gamesMenuModule.show(params)
    local activity = params.activity
    local mainUI = params.mainUI
    local gameMainUI = params.gameMainUI
    local playBGM = params.playBGM
    local wrapClick = params.wrapClick
    local styleButton = params.styleButton
    local whiteText = params.whiteText
    
    local bgm2Path = params.bgm2Path
    local bgm3Path = params.bgm3Path
    local bgm4Path = params.bgm4Path

    playBGM(bgm4Path)

    local layoutGM = {
        LinearLayout,
        orientation="vertical",
        background="#000000",
        layout_width="fill",
        gravity="center",
        padding="20dp",
        {TextView, id="gmHead", text="Select Your Game", textSize="18sp", layout_marginBottom="20dp"},
        {Button, id="playCardBtn", text="beggar my neighbor", layout_width="fill", layout_marginBottom="15dp"},
        {Button, id="backToHomeBtn", text="Back to Home", layout_width="fill"}
    }

    local vgm = loadlayout(layoutGM)
    whiteText(gmHead)
    styleButton(playCardBtn)
    styleButton(backToHomeBtn)

    local dgm = AlertDialog.Builder(activity).create()
    dgm.setTitle("Games Menu")
    dgm.setView(vgm)
    dgm.show()

    wrapClick(playCardBtn, function()
        dgm.dismiss()
        
        local lobbyLayout = {
            LinearLayout,
            orientation="vertical",
            layout_width="fill",
            layout_height="fill",
            background="#000000",
            gravity="center",
            padding="20dp",
            {TextView, text="Welcome", textSize="30sp", textColor="#FFD700", layout_marginBottom="10dp", gravity="center"},
            {TextView, text="Get Ready for the Challenge", textSize="16sp", textColor="#FFFFFF", layout_marginBottom="40dp", gravity="center"},
            {Button, id="startGameBtn", text="Start Game", layout_width="fill", layout_marginBottom="20dp"},
            {Button, id="backToMenuBtn", text="Back", layout_width="fill"}
        }

        activity.setContentView(loadlayout(lobbyLayout))
        styleButton(startGameBtn)
        styleButton(backToMenuBtn)

        wrapClick(startGameBtn, function()
            playBGM(bgm3Path)
            gameMainUI()
        end)

        wrapClick(backToMenuBtn, function()
            playBGM(bgm4Path)
            mainUI()
        end)
    end)

    wrapClick(backToHomeBtn, function()
        dgm.dismiss()
    end)

    dgm.setOnCancelListener({onCancel=function() playBGM(bgm2Path) end})
    dgm.setOnDismissListener({onDismiss=function() playBGM(bgm2Path) end})
end

return gamesMenuModule
