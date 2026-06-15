#include "include/flutter_tv_media3/flutter_tv_media3_plugin_c_api.h"
#include <flutter/plugin_registrar_windows.h>
#include "flutter_tv_media3_plugin.h"

void FlutterTvMedia3PluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_tv_media3::FlutterTvMedia3Plugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
