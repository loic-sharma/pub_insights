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
dart run ./bin/pub_insights.dart --fetch-mode popular
```

## Examples

Use [DuckDB](https://duckdb.org/) to analyze the tables using SQL.

### Plugins' platform breakdown

```sql
WITH
  -- Find all packages that are plugins or implement a plugin.
  -- Packages point to which plugin they implement using 'flutter.plugin.implements'.
  -- This contains duplicate rows if a plugin points to an implementation package
  -- in its pubspec using 'default_package'.
  plugins_ AS (
    SELECT
      json_type(pubspec, '$.flutter.plugin') IS NOT NULL AS is_plugin,
      COALESCE(
        json(pubspec)->>'$.flutter.plugin.implements',
        id
      ) AS plugin,
      id,
      UNNEST(json_keys(pubspec, '$.flutter.plugin.platforms')) AS platform
    FROM "package_versions.json"
    WHERE
      is_plugin = true AND
      is_latest = true
  ),
  -- Plugins can point to the package that contains the implementation using
  -- 'flutter.plugin.[platform].default_package'. This causes two rows per
  -- platform: one for the plugin, one for the implementation. Remove this
  -- duplication by filtering out the row that points to the default implementation.
  plugins AS (
    SELECT
      p.id,       -- The package ID that contains a plugin implementation.
      p.plugin,   -- The flutter plugin the package implements.
      p.platform  -- The platform supported by this package ID.
    FROM plugins_ p
    WHERE NOT EXISTS (
      SELECT 1
      FROM "package_versions.json"
      WHERE
        id = p.id AND
        is_latest = true AND
        json_type(
          pubspec,
          concat(
            '$.flutter.plugin.platforms.',
            p.platform,
            '.default_package'
          )
        ) IS NOT NULL
    )
  ),
  plugin_by_platforms_ AS (
    SELECT
      plugin,
      platform,
      list(id) AS ids
    FROM plugins
    GROUP BY plugin, platform
  ),
  plugin_by_platforms AS (
    SELECT
      -- A flutter plugin.
      plugin,
      -- A map of supported platforms to a list of packages that implement the
      -- plugin for that platform.
      map(list(platform), list(ids)) AS platform_to_packages
    FROM plugin_by_platforms_
    GROUP BY plugin
  )
SELECT * FROM plugin_by_platforms;
```

<details>
<summary>Result...</summary>

|                        plugin                         |                                                                                                                                         platform_to_packages                                                                                                                                          |
|-------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| addresspicker_packages                                | {android=[addresspicker_packages], ios=[addresspicker_packages]}                                                                                                                                                                                                                                      |
| adgydesdk                                             | {ios=[adgydesdk], android=[adgydesdk]}                                                                                                                                                                                                                                                                |
| adjust_custom_test_alone                              | {ios=[adjust_custom_test_alone], android=[adjust_custom_test_alone]}                                                                                                                                                                                                                                  |
| admob_flutter                                         | {android=[admob_flutter], ios=[admob_flutter]}                                                                                                                                                                                                                                                        |
| advance_pdf_viewer2                                   | {ios=[advance_pdf_viewer2], android=[advance_pdf_viewer2]}                                                                                                                                                                                                                                            |
| agora_rtc_ng                                          | {web=[agora_rtc_ng], android=[agora_rtc_ng], macos=[agora_rtc_ng], ios=[agora_rtc_ng], windows=[agora_rtc_ng]}                                                                                                                                                                                        |
| ai_umeng_push                                         | {android=[ai_umeng_push], ios=[ai_umeng_push]}                                                                                                                                                                                                                                                        |
| ali_auth_wbq                                          | {ios=[ali_auth_wbq], android=[ali_auth_wbq]}                                                                                                                                                                                                                                                          |

(7231 results)

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