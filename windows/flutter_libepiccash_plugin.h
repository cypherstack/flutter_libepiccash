#ifndef FLUTTER_PLUGIN_FLUTTER_LIBEPICCASH_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_LIBEPICCASH_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_libepiccash {

class FlutterLibepiccashPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterLibepiccashPlugin();

  virtual ~FlutterLibepiccashPlugin();

  // Disallow copy and assign.
  FlutterLibepiccashPlugin(const FlutterLibepiccashPlugin&) = delete;
  FlutterLibepiccashPlugin& operator=(const FlutterLibepiccashPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_libepiccash

#endif  // FLUTTER_PLUGIN_FLUTTER_LIBEPICCASH_PLUGIN_H_
