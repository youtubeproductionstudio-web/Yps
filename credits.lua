local credits = {}

function credits.show(activity, bgm1Path, bgm2Path)
  isTransitioning = true 
  playBGM(bgm1Path) 
  
  local layoutC = {
    LinearLayout,
    orientation="vertical",
    layout_width="fill",
    layout_height="fill",
    background="#111111",
    {
      LinearLayout,
      orientation="horizontal",
      layout_width="fill",
      padding="10dp",
      gravity="center_vertical",
      {Button, id="closeCreditsBtn", text="Back", layout_width="wrap"},
      {TextView, text="CREDITS", textSize="25sp", textColor="#FFD700", layout_marginLeft="20dp"}
    },
    {
      ScrollView,
      layout_width="fill",
      layout_height="fill",
      {
        LinearLayout,
        orientation="vertical",
        layout_width="fill",
        gravity="center",
        padding="25dp",
        {TextView, text="This project is created by YouTube Production Studio,", textSize="16sp", textColor="#00E5FF", gravity="center"},
        {TextView, text="where passion meets the world.", textSize="14sp", textColor="#00E5FF", gravity="center", layout_marginBottom="15dp"},
        {TextView, text="Here you can see the names of those who helped create this project and made the project better and better.", textSize="13sp", textColor="#AAAAAA", gravity="center", layout_marginBottom="25dp"},
        
        {TextView, text="Developed by:", textSize="12sp", textColor="#FFFFFF", gravity="center"},
        {TextView, text="Muzammil Muneer and Muhammad Hussain", textSize="18sp", textColor="#00FF00", gravity="center", layout_marginBottom="15dp"},
        
        {TextView, text="Helped in development:", textSize="12sp", textColor="#FFFFFF", gravity="center"},
        {TextView, text="Bilawal Pirzada and Muhammad Shuraim", textSize="18sp", textColor="#00E5FF", gravity="center", layout_marginBottom="15dp"},
        
        {TextView, text="Sound designed by:", textSize="12sp", textColor="#FFFFFF", gravity="center"},
        {TextView, text="Irtiza Hassan, Muhammad Musa, and Muhammad Shuraim", textSize="18sp", textColor="#FF69B4", gravity="center", layout_marginBottom="15dp"},
        
        {TextView, text="Tested by:", textSize="12sp", textColor="#FFFFFF", gravity="center", layout_marginBottom="5dp"},
        {TextView, text="Muhammad Shuraim, Muhammad Hussain, Irtiza Hassan, and Bilawal Pirzada", textSize="17sp", textColor="#FFD700", gravity="center", layout_marginBottom="30dp"},
        
        {TextView, text="Supported by:", textSize="12sp", textColor="#FFFFFF", gravity="center", layout_marginBottom="5dp"},
        {TextView, text="Tahir HT", textSize="18sp", textColor="#FFD700", gravity="center", layout_marginBottom="30dp"},
        
        {TextView, text="Thanks for playing", textSize="15sp", textColor="#FFFFFF", gravity="center", layout_marginBottom="20dp"},
      }
    }
  }
  
  local vc = loadlayout(layoutC)
  styleButton(closeCreditsBtn)
  
  local dc = AlertDialog.Builder(activity, android.R.style.Theme_Black_NoTitleBar_Fullscreen).create()
  dc.setView(vc)
  dc.show()
  isTransitioning = false 
  
  local function exitCredits()
    dc.dismiss()
    playBGM(bgm2Path)
  end
  
  wrapClick(closeCreditsBtn, function() exitCredits() end)
  dc.setOnCancelListener({onCancel=function() playBGM(bgm2Path) end})
  dc.setOnDismissListener({onDismiss=function() playBGM(bgm2Path) end})
end

return credits
