#ifndef FLUTTER_PLUGIN_FLUTTER_TV_MEDIA3_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_TV_MEDIA3_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <windows.h>
#include "mpv_client.h"

namespace flutter_tv_media3 {

class FlutterTvMedia3Plugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterTvMedia3Plugin(flutter::PluginRegistrarWindows *registrar);
  virtual ~FlutterTvMedia3Plugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleUiMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SetUiChannel(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel) {
    ui_channel_ = std::move(channel);
  }

  void InitializeMpv();
  void DestroyMpv();
  void UpdateVideoWindowBounds();

  static LRESULT CALLBACK VideoWindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam, UINT_PTR uIdSubclass, DWORD_PTR dwRefData);
  static LRESULT CALLBACK ParentWindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam, UINT_PTR uIdSubclass, DWORD_PTR dwRefData);

  flutter::PluginRegistrarWindows *registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> ui_channel_;
  HWND parent_hwnd_ = nullptr;
  HWND video_hwnd_ = nullptr;
  HMODULE mpv_dll_ = nullptr;
  
  mpv_handle *mpv_ = nullptr;
  int playlist_index_ = 0;
  UINT_PTR progress_timer_id_ = 0;
  
  // Dynamic mpv functions
  mpv_create_fn mpv_create_ = nullptr;
  mpv_initialize_fn mpv_initialize_ = nullptr;
  mpv_set_option_fn mpv_set_option_ = nullptr;
  mpv_set_option_string_fn mpv_set_option_string_ = nullptr;
  mpv_command_fn mpv_command_ = nullptr;
  mpv_set_property_fn mpv_set_property_ = nullptr;
  mpv_set_property_string_fn mpv_set_property_string_ = nullptr;
  mpv_get_property_fn mpv_get_property_ = nullptr;
  mpv_terminate_destroy_fn mpv_terminate_destroy_ = nullptr;
  mpv_error_string_fn mpv_error_string_ = nullptr;
};

}  // namespace flutter_tv_media3

#endif  // FLUTTER_PLUGIN_FLUTTER_TV_MEDIA3_PLUGIN_H_
