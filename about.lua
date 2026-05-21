local about = {}

function about.show(activity, bgm1Path, bgm2Path)
  isTransitioning = true
  playBGM(bgm1Path) 
  
  local layoutA = { 
    ScrollView, 
    layout_width="fill", 
    { 
      LinearLayout, 
      orientation="vertical", 
      background="#000000", 
      layout_width="fill", 
      gravity="center", 
      padding="16dp", 
      {TextView, id="aboutText", text="This tool is developed by Muzammil Muneer", layout_marginBottom="20dp"}, 
      {Button, id="ytBtn", text="Subscribe our YouTube channel Tech with Gamers", layout_width="fill", layout_marginBottom="10dp"}, 
      {Button, id="ytBtn2", text="Subscribe our YouTube channel Digital World For Blind", layout_width="fill", layout_marginBottom="10dp"}, 
      {Button, id="ytBtn3", text="Subscribe our other YouTube channel Hussain Urdu Adab", layout_width="fill", layout_marginBottom="10dp"}, 
      {Button, id="waChannelBtn", text="Follow our WhatsApp channel Digital World For Blind", layout_width="fill", layout_marginBottom="10dp"}, 
      {Button, id="waCommunityBtn", text="Join our WhatsApp community Digital World For Blind", layout_width="fill", layout_marginBottom="10dp"}, 
      {Button, id="feedbackBtn", text="Send Feedback", layout_width="fill", layout_marginBottom="10dp"}, 
      {Button, id="closeAboutBtn", text="Close", layout_width="fill"} 
    } 
  }
  
  local v = loadlayout(layoutA)
  whiteText(aboutText)
  styleButton(ytBtn)
  styleButton(ytBtn2)
  styleButton(ytBtn3)
  styleButton(waChannelBtn)
  styleButton(waCommunityBtn)
  styleButton(feedbackBtn)
  styleButton(closeAboutBtn)
  
  local d = AlertDialog.Builder(activity).create()
  d.setTitle("About")
  d.setView(v)
  d.show()
  isTransitioning = false
  
  wrapClick(ytBtn, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://youtube.com/@tecwithgamers"))) end)
  wrapClick(ytBtn2, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://youtube.com/@digitalworldforblind"))) end)
  wrapClick(ytBtn3, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://youtube.com/@hussainurduadab"))) end)
  wrapClick(waChannelBtn, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://whatsapp.com/channel/0029VatVug4IHphAok7ffs2O"))) end)
  wrapClick(waCommunityBtn, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://chat.whatsapp.com/LunAppbWT8UL5Tubw7vfYM"))) end)
  wrapClick(feedbackBtn, function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/923323905725"))) end)
  
  wrapClick(closeAboutBtn, function() 
    d.dismiss()
    playBGM(bgm2Path) 
  end)
  
  d.setOnCancelListener({onCancel=function() playBGM(bgm2Path) end})
  d.setOnDismissListener({onDismiss=function() playBGM(bgm2Path) end})
end

return about
