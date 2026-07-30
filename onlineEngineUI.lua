local View = import "android.view.View"
local UIModule = {}

UIModule.onlineMenuUI = {
    LinearLayout, orientation="vertical", layout_width="fill", layout_height="fill", backgroundColor=0xFF1A1A1A,
    { LinearLayout, orientation="horizontal", layout_width="fill", layout_height="wrap", gravity="center_vertical", backgroundColor=0xFF2D2D2D, padding="10dp",
        { Button, id="btnBackMenu", text="← Back", layout_width="80dp", layout_height="40dp", backgroundColor=0xFF444444, textColor=0xFFFFFFFF },
        { TextView, id="lblHeadingCustom", text="CUSTOM ROOMS", textSize="16sp", textColor=0xFFFFFFFF, gravity="center", layout_weight="1" },
        { Button, id="btnRefreshServerRooms", text="Refresh", layout_width="120dp", layout_height="40dp", backgroundColor=0xFF007ACC, textColor=0xFFFFFFFF }
    },
    { ScrollView, layout_width="match_parent", layout_height="0dp", layout_weight="1", fillViewport="true",
        { LinearLayout, orientation="vertical", layout_width="match_parent", layout_height="wrap", gravity="center_horizontal", padding="15dp",
            { Button, id="btnCreateNewRoom", text="Create New Room", layout_width="match_parent", layout_height="50dp", layout_marginTop="10dp", layout_marginBottom="15dp", backgroundColor=0xFFEE5500, textColor=0xFFFFFFFF },
            { LinearLayout, id="containerAvailableRoomsList", orientation="vertical", layout_width="match_parent", layout_height="wrap" }
        }
    }
}

UIModule.gameUI = {
    LinearLayout, id="layoutGameContainer", orientation="vertical", layout_width="fill", layout_height="fill", backgroundColor=0xFF0D140D, padding="10dp",
    { Button, id="btnExitRoom", text="Exit Room", layout_width="match_parent", layout_height="45dp", backgroundColor=0xFFB32424, textColor=0xFFFFFFFF },
    { TextView, id="txtChatDisplay", text="Chat: No messages yet", textSize="14sp", textColor=0xFFFFA500, layout_marginTop="8dp", layout_marginBottom="4dp", accessibilityLiveRegion=1 },
    { LinearLayout, orientation="horizontal", layout_width="fill", layout_height="wrap", layout_marginBottom="8dp",
        { Button, id="btnInGameSendMsg", text="Send Message", layout_width="0dp", layout_height="42dp", layout_weight="1", layout_marginRight="4dp" },
        { Button, id="btnInGameChatHistory", text="Chat History", layout_width="0dp", layout_height="42dp", layout_weight="1", layout_marginLeft="4dp" }
    },
    { Button, id="btnUpdateGameRoom", text="Update Game Room", layout_width="match_parent", layout_height="42dp", layout_marginBottom="4dp", backgroundColor=0xFF007ACC, textColor=0xFFFFFFFF, visibility=View.GONE },
    { Button, id="btnToggleGlobalChat", text="Disable All Messages", layout_width="match_parent", layout_height="42dp", layout_marginBottom="10dp", backgroundColor=0xFFD97706, textColor=0xFFFFFFFF, visibility=View.GONE },
    { ScrollView, layout_width="match_parent", layout_height="0dp", layout_weight="1",
        { LinearLayout, orientation="vertical", layout_width="match_parent", layout_height="wrap",
            { TextView, id="txtPlayer1Row", text="Player One: Empty - EMPTY", textSize="15sp", textColor=0xFF00FFFF, padding="8dp", focusable=true },
            { TextView, id="txtPlayer2Row", text="Player Two: Empty - EMPTY", textSize="15sp", textColor=0xFF00FFFF, padding="8dp", focusable=true },
            { View, layout_width="match_parent", layout_height="2dp", backgroundColor=0xFF444444, layout_marginTop="5dp", layout_marginBottom="5dp" },
            { TextView, id="txtAudienceHeading", text="Audience (0)", textSize="16sp", textColor=0xFFFFCC00, padding="4dp", focusable=true },
            { LinearLayout, id="containerAudienceList", orientation="vertical", layout_width="match_parent", layout_height="wrap", padding="4dp" },
            { View, layout_width="match_parent", layout_height="1dp", backgroundColor=0xFF333333, layout_marginTop="5dp", layout_marginBottom="5dp" },
            { TextView, id="txtWaitingListHeading", text="Waiting List (0)", textSize="16sp", textColor=0xFFFFCC00, padding="4dp", focusable=true },
            { LinearLayout, id="containerWaitingList", orientation="vertical", layout_width="match_parent", layout_height="wrap", padding="4dp" }
        }
    },
    { Button, id="btnStartMatchSignal", text="START GAME", layout_width="match_parent", layout_height="50dp", backgroundColor=0xFF009900, textColor=0xFFFFFFFF, layout_marginTop="5dp", visibility=View.GONE },
    { LinearLayout, id="layoutInGameControls", orientation="vertical", layout_width="fill", layout_height="wrap", gravity="center", visibility=View.GONE,
        { TextView, id="txtTotal", text="Global Sync Data: 0", textSize="20sp", textColor=0xFFFFFFFF },
        { LinearLayout, id="genericGameViewport", orientation="horizontal", layout_width="fill", layout_height="wrap", gravity="center" }
    }
}

return UIModule
