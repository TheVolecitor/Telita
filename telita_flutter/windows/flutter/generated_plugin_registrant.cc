//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_acrylic/flutter_acrylic_plugin.h>
#include <flutter_tv_media3/flutter_tv_media3_plugin_c_api.h>
#include <fvp/fvp_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterAcrylicPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterAcrylicPlugin"));
  FlutterTvMedia3PluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterTvMedia3PluginCApi"));
  FvpPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FvpPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
}
