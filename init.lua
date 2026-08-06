appname="All games hub"
appver="3.09"
appcode="1"
packagename="com.mm.agh"
developer="Muzammil Muneer and Muhammad Hussain"
target_sdk="36" -- Set to Android 16 (No downgrade)
min_sdk="24"
user_orientation="portrait"
user_theme="Theme.DeviceDefault.Light.NoActionBar"
hardwareAccelerated="true"
debug="true"
user_permission={
  "INTERNET",
  "ACCESS_NETWORK_STATE",
  "ACCESS_WIFI_STATE",
  "android.permission.VIBRATE", -- Fixed: Using full path to force the compiler to include it
  "POST_NOTIFICATIONS",
  "WRITE_EXTERNAL_STORAGE",
  "READ_EXTERNAL_STORAGE",
  "MANAGE_EXTERNAL_STORAGE",
  "READ_MEDIA_IMAGES",
  "READ_MEDIA_VIDEO",
  "READ_MEDIA_AUDIO",
}
