# Pub Insights

This project is used to analyze the pub ecosystem. This discovers all
pub packages, downloads them all, and then generates reports on their contents.

This project is inspired by .NET's wonderful [NuGet Insights](https://github.com/NuGet/Insights) project.

## Running

> **Note**
> This tool downloads all pub packages. Make sure you have a decent internet
> connection!

> **Note**
> Consider running this in a [sandbox](https://learn.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview) to minimize risk of malware.

Run using:

```
dart run ./bin/pub_insights.dart "/my/output/path"
```

## Examples

Use [DuckDB](https://duckdb.org/) to analyze the tables using SQL.

### Plugins' platform breakdown

```sql
WITH
  plugins AS (
    SELECT
      json(pubspec)->>'$.flutter.plugin.implements' AS plugin,
      id,
      UNNEST(json_keys(pubspec, '$.flutter.plugin.platforms')) AS platform
    FROM "package_versions.json"
    WHERE
      is_latest = true AND
      plugin IS NOT NULL
  ),
  plugin_by_platforms AS (
    SELECT
      plugin,
      platform,
      list(id) AS ids
    FROM plugins
    GROUP BY plugin, platform
  )
SELECT
  plugin,
  map(list(platform), list(ids)) AS platform_to_packages
FROM plugin_by_platforms
GROUP BY plugin
```

<details>
<summary>Result...</summary>


|             plugin              |                                                                                                                                            platform_to_packages                                                                                                                                             |
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| agschat                         | {android=[agschat], ios=[agschat]}                                                                                                                                                                                                                                                                          |
| alipay_kit                      | {android=[alipay_kit_android], ios=[alipay_kit_ios]}                                                                                                                                                                                                                                                        |
| aliyun_emas                     | {android=[aliyun_emas_android], ios=[aliyun_emas_ios]}                                                                                                                                                                                                                                                      |
| aliyun_oss_plugin               | {android=[aliyun_oss_android], ios=[aliyun_oss_ios], macos=[aliyun_oss_macos], web=[aliyun_oss_web]}                                                                                                                                                                                                        |
| ali_auth_person                 | {android=[ali_auth_person_android], ios=[ali_auth_person_ios]}                                                                                                                                                                                                                                              |
| apivideo_player                 | {android=[apivideo_player], ios=[apivideo_player], web=[apivideo_player]}                                                                                                                                                                                                                                   |
| app_widget                      | {android=[app_widget_android]}                                                                                                                                                                                                                                                                              |
| audioplayers                    | {android=[audioplayers_android], ios=[audioplayers_darwin], macos=[audioplayers_darwin], linux=[audioplayers_linux], windows=[audioplayers_windows]}                                                                                                                                                        |
| aws_s3_plugin                   | {android=[aws_s3_android], ios=[aws_s3_ios]}                                                                                                                                                                                                                                                                |
| battery_plus                    | {linux=[battery_plus_linux]}                                                                                                                                                                                                                                                                                |
| bdaya_oidc_client               | {web=[bdaya_oidc_client_android, bdaya_oidc_client_web]}                                                                                                                                                                                                                                                    |
| bdaya_openidconnect             | {web=[bdaya_openidconnect_web], windows=[bdaya_openidconnect_windows]}                                                                                                                                                                                                                                      |
| bonsoir                         | {android=[bonsoir_android], ios=[bonsoir_darwin], macos=[bonsoir_darwin], linux=[bonsoir_linux_dbus]}                                                                                                                                                                                                       |
| bootpay_webview_flutter         | {android=[bootpay_webview_flutter_android], web=[bootpay_webview_flutter_web], ios=[bootpay_webview_flutter_wkwebview, bootpay_webview_ios]}                                                                                                                                                                |
| butterfly                       | {android=[butterfly_flutter], ios=[butterfly_flutter], macos=[butterfly_flutter], windows=[butterfly_flutter], linux=[butterfly_flutter]}                                                                                                                                                                   |
| camera                          | {android=[camera_android], ios=[camera_avfoundation], web=[camera_web], windows=[camera_windows]}                                                                                                                                                                                                           |
| cbl_flutter                     | {android=[cbl_flutter_ce, cbl_flutter_ee], ios=[cbl_flutter_ce, cbl_flutter_ee], linux=[cbl_flutter_ce, cbl_flutter_ee], macos=[cbl_flutter_ce, cbl_flutter_ee], windows=[cbl_flutter_ce, cbl_flutter_ee]}                                                                                                  |
| video_player                    | {android=[chewie_video_player_android, video_player_android, video_player_web_hls_swarm_cloud], ios=[video_player_avfoundation, video_player_web_hls_swarm_cloud], macos=[video_player_macos], windows=[video_player_win], web=[dora_video_player_web, video_player_web, video_player_web_hls_swarm_cloud]} |
| cobi_flutter_service            | {android=[cobi_flutter_service_android]}                                                                                                                                                                                                                                                                    |
| cobi_flutter_share              | {android=[cobi_flutter_share_android]}                                                                                                                                                                                                                                                                      |
| connectivity                    | {web=[connectivity_for_web], macos=[connectivity_macos]}                                                                                                                                                                                                                                                    |
| connectivity_plus               | {linux=[connectivity_plus_linux]}                                                                                                                                                                                                                                                                           |
| dargon2_flutter                 | {linux=[dargon2_flutter_desktop], macos=[dargon2_flutter_desktop], windows=[dargon2_flutter_desktop], android=[dargon2_flutter_mobile], ios=[dargon2_flutter_mobile], web=[dargon2_flutter_web]}                                                                                                            |
| desktop_context_menu            | {macos=[desktop_context_menu_macos], windows=[desktop_context_menu_windows]}                                                                                                                                                                                                                                |
| device_info_plus                | {linux=[device_info_plus_linux], windows=[device_info_plus_windows]}                                                                                                                                                                                                                                        |
| drag_and_drop_flutter           | {web=[drag_and_drop_flutter_web]}                                                                                                                                                                                                                                                                           |
| dyte_core                       | {android=[dyte_core_android], ios=[dyte_core_ios]}                                                                                                                                                                                                                                                          |
| embrace                         | {android=[embrace_android], ios=[embrace_ios]}                                                                                                                                                                                                                                                              |
| enhanced_url_launcher           | {android=[enhanced_url_launcher_android], ios=[enhanced_url_launcher_ios], linux=[enhanced_url_launcher_linux], macos=[enhanced_url_launcher_macos], web=[enhanced_url_launcher_web], windows=[enhanced_url_launcher_windows]}                                                                              |
| flutter_facebook_auth           | {macos=[facebook_auth_desktop]}                                                                                                                                                                                                                                                                             |
| file_selector                   | {ios=[file_selector_ios], linux=[file_selector_linux], macos=[file_selector_macos], web=[file_selector_web], windows=[file_selector_windows]}                                                                                                                                                               |
| firebase_auth                   | {linux=[firebase_auth_desktop], windows=[firebase_auth_desktop, firebase_auth_window]}                                                                                                                                                                                                                      |
| firebase_core                   | {linux=[firebase_core_desktop], windows=[firebase_core_desktop]}                                                                                                                                                                                                                                            |
| cloud_functions                 | {linux=[firebase_functions_desktop], windows=[firebase_functions_desktop]}                                                                                                                                                                                                                                  |
| firebase_game_services          | {ios=[firebase_game_services_apple], macos=[firebase_game_services_apple], android=[firebase_game_services_google]}                                                                                                                                                                                         |
| flutter_auto_gui                | {windows=[flutter_auto_gui_windows]}                                                                                                                                                                                                                                                                        |
| flutter_avif                    | {android=[flutter_avif_android], ios=[flutter_avif_ios], linux=[flutter_avif_linux], macos=[flutter_avif_macos], windows=[flutter_avif_windows]}                                                                                                                                                            |
| flutter_background_service      | {android=[flutter_background_service_android, flutter_background_service_android_enhanced], ios=[flutter_background_service_ios, flutter_background_service_ios_enhanced]}                                                                                                                                  |
| flutter_charset_detector        | {android=[flutter_charset_detector_android], ios=[flutter_charset_detector_ios]}                                                                                                                                                                                                                            |
| flutter_exprtk                  | {android=[flutter_exprtk_native], ios=[flutter_exprtk_native], macos=[flutter_exprtk_native], windows=[flutter_exprtk_native], web=[flutter_exprtk_web]}                                                                                                                                                    |
| flutter_gl                      | {macos=[flutter_gl_macos], windows=[flutter_gl_windows]}                                                                                                                                                                                                                                                    |
| flutter_google_places_sdk       | {linux=[flutter_google_places_sdk_linux], macos=[flutter_google_places_sdk_macos], windows=[flutter_google_places_sdk_windows]}                                                                                                                                                                             |
| webview_flutter                 | {web=[flutter_iframe_webview, webview_flutter_web], android=[talkjs_webview_flutter_android, webview_flutter_android, webview_pro_android], ios=[talkjs_webview_flutter_wkwebview, webview_flutter_wkwebview, webview_flutter_wkwebview_pagecall_poc, webview_pro_wkwebview]}                               |
| flutter_keyboard_visibility     | {linux=[flutter_keyboard_visibility_linux], macos=[flutter_keyboard_visibility_macos], windows=[flutter_keyboard_visibility_windows]}                                                                                                                                                                       |
| flutter_libphonenumber          | {ios=[flutter_libphonenumber_ios], web=[flutter_libphonenumber_web], android=[flutter_libphonenumber_android]}                                                                                                                                                                                              |
| flutter_line_liff               | {web=[flutter_line_liff_web]}                                                                                                                                                                                                                                                                               |
| flutter_lyra                    | {android=[flutter_lyra_android], ios=[flutter_lyra_ios]}                                                                                                                                                                                                                                                    |
| flutter_midi_command            | {linux=[flutter_midi_command_linux]}                                                                                                                                                                                                                                                                        |
| flutter_native_badge            | {ios=[flutter_native_badge_foundation], macos=[flutter_native_badge_foundation]}                                                                                                                                                                                                                            |
| flutter_opencc_ffi              | {android=[flutter_opencc_ffi_android], ios=[flutter_opencc_ffi_ios], macos=[flutter_opencc_ffi_macos], web=[flutter_opencc_ffi_web], windows=[flutter_opencc_ffi_windows]}                                                                                                                                  |
| flutter_pcsc                    | {linux=[flutter_pcsc_linux], macos=[flutter_pcsc_macos], windows=[flutter_pcsc_windows]}                                                                                                                                                                                                                    |
| flutter_player                  | {windows=[flutter_player]}                                                                                                                                                                                                                                                                                  |
| flutter_qjs                     | {windows=[flutter_qjs], linux=[flutter_qjs], android=[flutter_qjs], macos=[flutter_qjs], ios=[flutter_qjs]}                                                                                                                                                                                                 |
| flutter_reach_five              | {android=[flutter_reach_five_android], ios=[flutter_reach_five_ios]}                                                                                                                                                                                                                                        |
| flutter_safe_js                 | {web=[flutter_safe_js_web]}                                                                                                                                                                                                                                                                                 |
| flutter_secure_storage          | {linux=[flutter_secure_storage_linux], macos=[flutter_secure_storage_macos], windows=[flutter_secure_storage_windows]}                                                                                                                                                                                      |
| flutter_smart_watch             | {android=[flutter_smart_watch_android], ios=[flutter_smart_watch_ios]}                                                                                                                                                                                                                                      |
| flutter_tex_js                  | {android=[flutter_tex_js_android], ios=[flutter_tex_js_ios]}                                                                                                                                                                                                                                                |
| flutter_web_auth_2              | {windows=[flutter_web_auth_2_windows]}                                                                                                                                                                                                                                                                      |
| gamepads                        | {macos=[gamepads_darwin], linux=[gamepads_linux], windows=[gamepads_windows]}                                                                                                                                                                                                                               |
| geocoding                       | {android=[geocoding_android], ios=[geocoding_ios]}                                                                                                                                                                                                                                                          |
| geolocator                      | {android=[geolocator_android], ios=[geolocator_apple], macos=[geolocator_apple], linux=[geolocator_linux]}                                                                                                                                                                                                  |
| gify                            | {android=[gify], ios=[gify], web=[gify]}                                                                                                                                                                                                                                                                    |
| google_api_availability         | {android=[google_api_availability_android]}                                                                                                                                                                                                                                                                 |
| google_maps_flutter             | {android=[google_maps_flutter_android], ios=[google_maps_flutter_ios], web=[google_maps_flutter_web]}                                                                                                                                                                                                       |
| google_sign_in                  | {android=[google_sign_in_android], ios=[google_sign_in_ios], web=[google_sign_in_web]}                                                                                                                                                                                                                      |
| gtm                             | {android=[gtm_android], ios=[gtm_ios]}                                                                                                                                                                                                                                                                      |
| hackle                          | {android=[hackle_android], ios=[hackle_ios]}                                                                                                                                                                                                                                                                |
| hid                             | {linux=[hid_linux], macos=[hid_macos], windows=[hid_windows]}                                                                                                                                                                                                                                               |
| hi_share                        | {android=[hi_share_android], ios=[hi_share_ios]}                                                                                                                                                                                                                                                            |
| iabtcf_consent_info             | {web=[iabtcf_consent_info_web]}                                                                                                                                                                                                                                                                             |
| image_cropper                   | {web=[image_cropper_for_web, image_cropper_for_web2]}                                                                                                                                                                                                                                                       |
| image_editor                    | {android=[image_editor_common], ios=[image_editor_common], macos=[image_editor_common]}                                                                                                                                                                                                                     |
| image_picker                    | {android=[image_picker_android], web=[image_picker_for_web], ios=[image_picker_ios], windows=[image_picker_windows]}                                                                                                                                                                                        |
| in_app_purchase                 | {android=[in_app_purchase_android], ios=[in_app_purchase_ios, in_app_purchase_storekit], macos=[in_app_purchase_storekit]}                                                                                                                                                                                  |
| jpush_flutter_plugin            | {android=[jpush_flutter_plugin_android], ios=[jpush_flutter_plugin_ios]}                                                                                                                                                                                                                                    |
| just_audio                      | {windows=[just_audio_libwinmedia], linux=[just_audio_libwinmedia]}                                                                                                                                                                                                                                          |
| just_audio_platform_interface   | {linux=[just_audio_mpv]}                                                                                                                                                                                                                                                                                    |
| keri                            | {android=[keri_android], macos=[keri_macos], windows=[keri_windows]}                                                                                                                                                                                                                                        |
| kevin_flutter_accounts          | {android=[kevin_flutter_accounts_android], ios=[kevin_flutter_accounts_ios]}                                                                                                                                                                                                                                |
| kevin_flutter_core              | {android=[kevin_flutter_core_android], ios=[kevin_flutter_core_ios]}                                                                                                                                                                                                                                        |
| kevin_flutter_in_app_payments   | {android=[kevin_flutter_in_app_payments_android], ios=[kevin_flutter_in_app_payments_ios]}                                                                                                                                                                                                                  |
| linktsp_api                     | {android=[linktsp_api], ios=[linktsp_api], windows=[linktsp_api], web=[linktsp_api], macos=[linktsp_api]}                                                                                                                                                                                                   |
| local_auth                      | {android=[local_auth_android], ios=[local_auth_ios], windows=[local_auth_windows]}                                                                                                                                                                                                                          |
| local_auth_credentials          | {android=[local_auth_android_credentials], ios=[local_auth_ios_credentials]}                                                                                                                                                                                                                                |
| location                        | {android=[location_android], ios=[location_ios], macos=[location_macos]}                                                                                                                                                                                                                                    |
| mapsindoors                     | {android=[mapsindoors_android], ios=[mapsindoors_ios]}                                                                                                                                                                                                                                                      |
| mg_webview_flutter              | {android=[mg_webview_flutter_android]}                                                                                                                                                                                                                                                                      |
| mindbox                         | {android=[mindbox_android], ios=[mindbox_ios]}                                                                                                                                                                                                                                                              |
| mono_flutter                    | {web=[mono_flutter], ios=[mono_flutter], android=[mono_flutter]}                                                                                                                                                                                                                                            |
| native_image_cropper            | {android=[native_image_cropper_android], ios=[native_image_cropper_ios], macos=[native_image_cropper_macos]}                                                                                                                                                                                                |
| network_info_plus               | {linux=[network_info_plus_linux]}                                                                                                                                                                                                                                                                           |
| nevis_mobile_authentication_sdk | {android=[nevis_mobile_authentication_sdk_android], ios=[nevis_mobile_authentication_sdk_ios]}                                                                                                                                                                                                              |
| nim_core                        | {macos=[nim_core_macos], web=[nim_core_web], windows=[nim_core_windows]}                                                                                                                                                                                                                                    |
| on_audio_query                  | {android=[on_audio_query_android], ios=[on_audio_query_ios]}                                                                                                                                                                                                                                                |
| openidconnect                   | {web=[openidconnect_web], windows=[openidconnect_windows]}                                                                                                                                                                                                                                                  |
| open_dir                        | {linux=[open_dir_linux], macos=[open_dir_macos], windows=[open_dir_windows]}                                                                                                                                                                                                                                |
| opus_flutter                    | {android=[opus_flutter_android], ios=[opus_flutter_ios], web=[opus_flutter_web], windows=[opus_flutter_windows]}                                                                                                                                                                                            |
| package_info_plus               | {linux=[package_info_plus_linux], windows=[package_info_plus_windows]}                                                                                                                                                                                                                                      |
| parsec                          | {android=[parsec_android], linux=[parsec_linux]}                                                                                                                                                                                                                                                            |
| path_provider                   | {ios=[path_provider_foundation, path_provider_ios], linux=[path_provider_linux], windows=[path_provider_windows], android=[path_provider_android], macos=[path_provider_foundation, path_provider_macos]}                                                                                                   |
| permission_handler              | {android=[permission_handler_android], ios=[permission_handler_apple], windows=[permission_handler_windows]}                                                                                                                                                                                                |
| pivo                            | {android=[pivo_android], ios=[pivo_ios]}                                                                                                                                                                                                                                                                    |
| platform_device_id              | {linux=[platform_device_id_linux], macos=[platform_device_id_macos], web=[platform_device_id_web]}                                                                                                                                                                                                          |
| platform_support_pub_test       | {macos=[platform_support_pub_test_desktop], windows=[platform_support_pub_test_desktop], linux=[platform_support_pub_test_desktop]}                                                                                                                                                                         |
| proximity_screen_lock           | {ios=[proximity_screen_lock_ios]}                                                                                                                                                                                                                                                                           |
| detect_proxy_setting            | {android=[proxy_setting_android], ios=[proxy_setting_ios], macos=[proxy_setting_macos], windows=[proxy_setting_windows]}                                                                                                                                                                                    |
| pusher_beams                    | {android=[pusher_beams_android, pusher_push_notifications_android], web=[pusher_beams_web, pusher_push_notifications_web]}                                                                                                                                                                                  |
| push                            | {android=[push_android], ios=[push_ios]}                                                                                                                                                                                                                                                                    |
| python_ffi                      | {macos=[python_ffi_cpython, python_ffi_macos], windows=[python_ffi_cpython], linux=[python_ffi_cpython]}                                                                                                                                                                                                    |
| qr_code_utils                   | {android=[qr_code_utils_android], ios=[qr_code_utils_ios]}                                                                                                                                                                                                                                                  |
| quick_actions                   | {android=[quick_actions_android], ios=[quick_actions_ios]}                                                                                                                                                                                                                                                  |
| record                          | {linux=[record_linux], windows=[record_windows]}                                                                                                                                                                                                                                                            |
| rich_clipboard                  | {android=[rich_clipboard_android], ios=[rich_clipboard_ios], linux=[rich_clipboard_linux], macos=[rich_clipboard_macos], web=[rich_clipboard_web], windows=[rich_clipboard_windows]}                                                                                                                        |
| rudder_sdk_flutter              | {android=[rudder_plugin_android], ios=[rudder_plugin_ios], web=[rudder_plugin_web]}                                                                                                                                                                                                                         |
| screen_plus                     | {android=[screen_plus_android], ios=[screen_plus_ios]}                                                                                                                                                                                                                                                      |
| scrolls_flutter                 | {ios=[scrolls_ios], android=[scrolls_android]}                                                                                                                                                                                                                                                              |
| shared_preferences              | {android=[shared_preferences_android], ios=[shared_preferences_foundation, shared_preferences_ios, shared_preferences_ios_sn], macos=[shared_preferences_foundation, shared_preferences_macos], linux=[shared_preferences_linux], web=[shared_preferences_web], windows=[shared_preferences_windows]}       |
| share_plus                      | {linux=[share_plus_linux], windows=[share_plus_windows]}                                                                                                                                                                                                                                                    |
| solana_wallet_adapter           | {android=[solana_wallet_adapter_android]}                                                                                                                                                                                                                                                                   |
| speech_to_text                  | {macos=[speech_to_text_macos]}                                                                                                                                                                                                                                                                              |
| splitio                         | {android=[splitio_android], ios=[splitio_ios]}                                                                                                                                                                                                                                                              |
| system_proxy_resolver_federated | {ios=[system_proxy_resolver_foundation], macos=[system_proxy_resolver_foundation], windows=[system_proxy_resolver_windows]}                                                                                                                                                                                 |
| system_tray_platform_interface  | {macos=[system_tray_macos]}                                                                                                                                                                                                                                                                                 |
| tencent_im_sdk_plugin           | {macos=[tencent_im_sdk_plugin_desktop], windows=[tencent_im_sdk_plugin_desktop], web=[tencent_im_sdk_plugin_web]}                                                                                                                                                                                           |
| text_to_speech                  | {macos=[text_to_speech_macos]}                                                                                                                                                                                                                                                                              |
| tflite_style_transfer           | {android=[tflite_style_transfer_android], ios=[tflite_style_transfer_ios]}                                                                                                                                                                                                                                  |
| thumblr                         | {macos=[thumblr_macos], windows=[thumblr_windows]}                                                                                                                                                                                                                                                          |
| touch_bar                       | {macos=[touch_bar_macos]}                                                                                                                                                                                                                                                                                   |
| unifiedpush                     | {android=[unifiedpush_android]}                                                                                                                                                                                                                                                                             |
| uni_links                       | {macos=[uni_links_desktop], windows=[uni_links_desktop]}                                                                                                                                                                                                                                                    |
| update_available                | {android=[update_available_android], ios=[update_available_ios]}                                                                                                                                                                                                                                            |
| url_launcher                    | {android=[url_launcher_android], ios=[url_launcher_ios], linux=[url_launcher_linux], macos=[url_launcher_macos], web=[url_launcher_web], windows=[url_launcher_windows]}                                                                                                                                    |
| vital_devices                   | {android=[vital_devices_android], ios=[vital_devices_ios]}                                                                                                                                                                                                                                                  |
| vital_health                    | {android=[vital_health_android], ios=[vital_health_ios]}                                                                                                                                                                                                                                                    |
| webview_flutter_pagecall        | {ios=[webview_flutter_wkwebview_pagecall]}                                                                                                                                                                                                                                                                  |
| yaru_window                     | {linux=[yaru_window_linux, yaru_window_manager], macos=[yaru_window_manager], windows=[yaru_window_manager], web=[yaru_window_web]}                                                                                                                                                                         |
| youtube_player_iframe           | {web=[youtube_player_iframe_web]}                                                                                                                                                                                                                                                                           |
| motion                          | {web=[motion_web]}                                                                                                                                                                                                                                                                                          |
| sparrow_image_picker            | {web=[sparrow_image_picker_for_web]}                                                                                                                                                                                                                                                                        |

</details>

### Packages that contain pre-built libraries

We're adding support for Windows ARM64 to Flutter. Packages that contain
pre-built DLLs need to be updated to also target ARM64.

```SQL
SELECT
  DISTINCT(lower_id)
FROM "package_archive_entries.json"
WHERE
  name LIKE '%.dll';
```

<details>
<summary>Results...</summary>

```
agent_dart
argox
argox_printer
atmos_database
auto_updater
biii_in_serial
clavie_test
cronet_flutter
dargon2
dark_matter
dart_discord_rpc
dart_randomx
dart_sunvox
dart_synthizer
dart_tinydtls_libs
dart_tolk
dartzmq
decentralized_internet
derry
desktop_webview_window
discord_rpc
driver_extensions
es_compression
etebase_flutter
fast_rsa
flutter_avif_windows
flutter_barcode_sdk
flutter_document_scan_sdk
flutter_js
flutter_media_info
flutter_media_metadata
flutter_ocr_sdk
flutter_olm
flutter_opencc_ffi_windows
flutter_plugin_stkouyu
flutter_sparkle
flutter_twain_scanner
flutter_webrtc
flutter_webrtc_haoxin
flutter_zwap_webrtc
foodb_objectbox_adapter
fts5_simple
geiger_localstorage
git2dart_binaries
glew
grpc_cronet
imgui_dart
isar_flutter_libs
kdbx
keri_windows
lexactivator
libusb_new
libusb
lychee_player
medea_jason
medea_flutter_webrtc
mg_msix
msix
n_triples_db
nacl_win
nftgen
nvda_controller_client
ogg_opus_player
openpgp
pdf_text_extraction
pdfium_bindings
profept_server
python_ffi_cpython
quds_db
quick_usb
record_windows
rps
smart_usb
smart_usb_android
sodium_libs
sqflite_common_ffi
sqlcipher_library_windows
sqlite_wrapper
squirrel
starflut
syncfusion_pdfviewer_windows
telegram_client_flutter
tencent_im_sdk_plugin_desktop
tencent_trtc_cloud
tencent_trtc_cloud_professional
test_gavinwjwang
universal_mqtt_client
upload_testing_flutter
vclibs
webview_universal
windows_ocr
windows_printing
winmd
x_media_info
yumeeting_webrtc
znn_sdk_dart
```

</details>

## Tables

### package_versions.json

This table contains the information for each package version.


Column name | Data type | Description
-- | -- | --
lower_id | String | Lowercase package ID. Good for joins
identity | String | Lowercase package ID and version. Good for joins
id | String | Original package ID
version | String | Original package version
archive_url | String | URL to download the package archive
archive_sha256 | String | SHA-256 hash of the package archive
published | String | Timestamp package was published
is_latest | Bool | Whether this package version is the latest
pubspec | String | The package's pubspec JSON

### package_archive_entries.json

This table contains low-level information about .tar.gz file entries.

Column name | Data type | Description
-- | -- | --
lower_id | String | Lowercase package ID. Good for joins
identity | String | Lowercase package ID and version. Good for joins
id | String | Original package ID
version | String | Original package version
sequence_number | int | The index of this entry in the .tar.gz package archive
last_modified | int | Seconds since epoch
uncompressed_size | int | Size of the uncompressed file entry in bytes