#include "include/flutter_libepiccash/flutter_libepiccash_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_libepiccash_plugin.h"

void FlutterLibepiccashPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_libepiccash::FlutterLibepiccashPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
