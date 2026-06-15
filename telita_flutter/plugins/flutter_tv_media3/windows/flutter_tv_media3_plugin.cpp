#include "flutter_tv_media3_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <string>
#include <iostream>
#include <commctrl.h>
#include <dwmapi.h>

#pragma comment(lib, "comctl32.lib")

namespace flutter_tv_media3 {

static const UINT_PTR SUBCLASS_ID = 1001;

void FlutterTvMedia3Plugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "app_player_plugin",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterTvMedia3Plugin>(registrar);
  auto plugin_pointer = plugin.get();

  channel->SetMethodCallHandler(
      [plugin_pointer](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto ui_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "ui_player_plugin_activity",
          &flutter::StandardMethodCodec::GetInstance());
          
  ui_channel->SetMethodCallHandler(
      [plugin_pointer](const auto &call, auto result) {
        plugin_pointer->HandleUiMethodCall(call, std::move(result));
      });

  plugin->SetUiChannel(std::move(ui_channel));
  registrar->AddPlugin(std::move(plugin));
}

FlutterTvMedia3Plugin::FlutterTvMedia3Plugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {
  parent_hwnd_ = registrar_->GetView()->GetNativeWindow();
  
  // Create an independent borderless pop-up window for libmpv (underneath Flutter)
  WNDCLASSEX wc = {0};
  wc.cbSize = sizeof(WNDCLASSEX);
  wc.lpfnWndProc = DefWindowProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.lpszClassName = L"FtvMedia3VideoWindow";
  RegisterClassEx(&wc);

  video_hwnd_ = CreateWindowEx(
      0, L"FtvMedia3VideoWindow", L"Video Window",
      WS_POPUP, 0, 0, 100, 100,
      parent_hwnd_, nullptr, wc.hInstance, nullptr);

  SetWindowSubclass(video_hwnd_, VideoWindowProc, SUBCLASS_ID + 1, (DWORD_PTR)this);

  // We no longer need Chroma Key. MPV will just sit on top and receive input.


  // Subclass root window to track movement/resizing
  HWND root_hwnd = GetAncestor(parent_hwnd_, GA_ROOT);
  SetWindowSubclass(root_hwnd, ParentWindowProc, SUBCLASS_ID, (DWORD_PTR)this);
}

FlutterTvMedia3Plugin::~FlutterTvMedia3Plugin() {
  DestroyMpv();
  HWND root_hwnd = GetAncestor(parent_hwnd_, GA_ROOT);
  RemoveWindowSubclass(root_hwnd, ParentWindowProc, SUBCLASS_ID);
  if (video_hwnd_) {
    RemoveWindowSubclass(video_hwnd_, VideoWindowProc, SUBCLASS_ID + 1);
    DestroyWindow(video_hwnd_);
  }
}

LRESULT CALLBACK FlutterTvMedia3Plugin::ParentWindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam, UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
  FlutterTvMedia3Plugin* plugin = (FlutterTvMedia3Plugin*)dwRefData;
  if (msg == WM_WINDOWPOSCHANGING || msg == WM_WINDOWPOSCHANGED || msg == WM_SIZE || msg == WM_MOVE) {
    plugin->UpdateVideoWindowBounds();
  }
  return DefSubclassProc(hwnd, msg, wparam, lparam);
}

#include <windowsx.h>

LRESULT CALLBACK FlutterTvMedia3Plugin::VideoWindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam, UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
  FlutterTvMedia3Plugin* plugin = (FlutterTvMedia3Plugin*)dwRefData;
  
  if (msg == WM_KEYDOWN) {
    if (wparam == VK_ESCAPE || wparam == VK_BACK) {
      plugin->DestroyMpv();
      ShowWindow(plugin->video_hwnd_, SW_HIDE);
      if (plugin->ui_channel_) {
        plugin->ui_channel_->InvokeMethod("onBack", std::make_unique<flutter::EncodableValue>());
      }
      return 0;
    }
  } else if (msg == WM_LBUTTONUP) {
    int x = GET_X_LPARAM(lparam);
    int y = GET_Y_LPARAM(lparam);
    RECT rect;
    GetClientRect(hwnd, &rect);
    if (x < rect.right * 0.1 && y < rect.bottom * 0.1) {
      plugin->DestroyMpv();
      ShowWindow(plugin->video_hwnd_, SW_HIDE);
      if (plugin->ui_channel_) {
        plugin->ui_channel_->InvokeMethod("onBack", std::make_unique<flutter::EncodableValue>());
      }
      return 0;
    }
  } else if (msg == WM_TIMER) {
    if (wparam == 1005 && plugin->mpv_) {
      double pos = 0.0;
      double duration = 0.0;
      plugin->mpv_get_property_(plugin->mpv_, "time-pos", MPV_FORMAT_DOUBLE, &pos);
      plugin->mpv_get_property_(plugin->mpv_, "duration", MPV_FORMAT_DOUBLE, &duration);

      int pos_ms = (int)(pos * 1000);
      int dur_ms = (int)(duration * 1000);

      if (plugin->ui_channel_) {
        // Position changed for slider only
        flutter::EncodableMap posMap;
        posMap[flutter::EncodableValue("position")] = flutter::EncodableValue(pos_ms);
        posMap[flutter::EncodableValue("duration")] = flutter::EncodableValue(dur_ms);
        plugin->ui_channel_->InvokeMethod("onPositionChanged", std::make_unique<flutter::EncodableValue>(posMap));
      }
      return 0;
    }
  }
  return DefSubclassProc(hwnd, msg, wparam, lparam);
}

void FlutterTvMedia3Plugin::UpdateVideoWindowBounds() {
  if (!video_hwnd_ || !IsWindowVisible(video_hwnd_)) return;
  HWND root_hwnd = GetAncestor(parent_hwnd_, GA_ROOT);
  RECT rect;
  if (GetWindowRect(root_hwnd, &rect)) {
    SetWindowPos(video_hwnd_, HWND_TOP,
                 rect.left, rect.top,
                 rect.right - rect.left, rect.bottom - rect.top,
                 SWP_NOACTIVATE | SWP_SHOWWINDOW);
  }
}

void FlutterTvMedia3Plugin::InitializeMpv() {
  if (mpv_) return;

  if (!mpv_dll_) {
    // Attempt to load mpv-2.dll from the executable directory
    mpv_dll_ = LoadLibraryA("mpv-2.dll");
    if (!mpv_dll_) {
      std::cerr << "Failed to load mpv-2.dll" << std::endl;
      return;
    }

    mpv_create_ = (mpv_create_fn)GetProcAddress(mpv_dll_, "mpv_create");
    mpv_initialize_ = (mpv_initialize_fn)GetProcAddress(mpv_dll_, "mpv_initialize");
    mpv_set_option_ = (mpv_set_option_fn)GetProcAddress(mpv_dll_, "mpv_set_option");
    mpv_set_option_string_ = (mpv_set_option_string_fn)GetProcAddress(mpv_dll_, "mpv_set_option_string");
    mpv_command_ = (mpv_command_fn)GetProcAddress(mpv_dll_, "mpv_command");
    mpv_set_property_ = (mpv_set_property_fn)GetProcAddress(mpv_dll_, "mpv_set_property");
    mpv_set_property_string_ = (mpv_set_property_string_fn)GetProcAddress(mpv_dll_, "mpv_set_property_string");
    mpv_get_property_ = (mpv_get_property_fn)GetProcAddress(mpv_dll_, "mpv_get_property");
    mpv_terminate_destroy_ = (mpv_terminate_destroy_fn)GetProcAddress(mpv_dll_, "mpv_terminate_destroy");
    mpv_error_string_ = (mpv_error_string_fn)GetProcAddress(mpv_dll_, "mpv_error_string");
    
    if (!mpv_create_ || !mpv_initialize_) {
      std::cerr << "Failed to find mpv functions in dll" << std::endl;
      return;
    }
  }

  mpv_ = mpv_create_();
  if (!mpv_) {
    std::cerr << "failed creating context" << std::endl;
    return;
  }

  int64_t wid = (int64_t)video_hwnd_;
  mpv_set_option_(mpv_, "wid", MPV_FORMAT_INT64, &wid);
  
  mpv_set_option_string_(mpv_, "vo", "gpu-next");
  mpv_set_option_string_(mpv_, "hwdec", "auto");
  mpv_set_option_string_(mpv_, "gpu-api", "d3d11");
  mpv_set_option_string_(mpv_, "d3d11-output-csp", "pq");
  mpv_set_option_string_(mpv_, "target-colorspace-hint", "yes");
  mpv_set_option_string_(mpv_, "keep-open", "yes");
  mpv_set_option_string_(mpv_, "idle", "yes");
  mpv_set_option_string_(mpv_, "osc", "no");

  // Build absolute path to Lua script based on the executable location
  char exe_path[MAX_PATH];
  GetModuleFileNameA(nullptr, exe_path, MAX_PATH);
  std::string exe_dir(exe_path);
  exe_dir = exe_dir.substr(0, exe_dir.find_last_of("\\/"));
  std::string script_path = exe_dir + "\\data\\flutter_assets\\assets\\telita_osd.lua";
  if (GetFileAttributesA(script_path.c_str()) != INVALID_FILE_ATTRIBUTES) {
    mpv_set_option_string_(mpv_, "script", script_path.c_str());
  } else {
    std::cerr << "Lua OSD script not found at: " << script_path << std::endl;
  }

  int res = mpv_initialize_(mpv_);
  if (res < 0) {
    std::cerr << "mpv init failed" << std::endl;
    DestroyMpv();
  } else {
    progress_timer_id_ = SetTimer(video_hwnd_, 1005, 1000, nullptr);
  }
}

void FlutterTvMedia3Plugin::DestroyMpv() {
  if (progress_timer_id_) {
    KillTimer(video_hwnd_, progress_timer_id_);
    progress_timer_id_ = 0;
  }
  if (mpv_) {
    // Sync watch history on exit
    double pos = 0.0;
    double duration = 0.0;
    mpv_get_property_(mpv_, "time-pos", MPV_FORMAT_DOUBLE, &pos);
    mpv_get_property_(mpv_, "duration", MPV_FORMAT_DOUBLE, &duration);
    
    if (ui_channel_ && pos > 0.0) {
      flutter::EncodableMap historyMap;
      historyMap[flutter::EncodableValue("playlist_index")] = flutter::EncodableValue(playlist_index_);
      historyMap[flutter::EncodableValue("position_ms")] = flutter::EncodableValue((int)(pos * 1000));
      historyMap[flutter::EncodableValue("duration_ms")] = flutter::EncodableValue((int)(duration * 1000));
      ui_channel_->InvokeMethod("onWatchTimeMarked", std::make_unique<flutter::EncodableValue>(historyMap));
    }

    const char *cmd[] = {"stop", nullptr};
    mpv_command_(mpv_, cmd);
    mpv_terminate_destroy_(mpv_);
    mpv_ = nullptr;
  }
}

void FlutterTvMedia3Plugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name() == "getHWND") {
    HWND root_hwnd = GetAncestor(parent_hwnd_, GA_ROOT);
    result->Success(flutter::EncodableValue((int64_t)root_hwnd));
    return;
  }
  
  if (method_call.method_name() == "openPlayer") {
    HWND root_hwnd = GetAncestor(parent_hwnd_, GA_ROOT);
    RECT root_rect;
    GetWindowRect(root_hwnd, &root_rect);

    // Position and show BEFORE initializing MPV so the wid is ready
    SetWindowPos(video_hwnd_, HWND_TOP,
                 root_rect.left, root_rect.top,
                 root_rect.right - root_rect.left,
                 root_rect.bottom - root_rect.top,
                 SWP_NOACTIVATE);
    ShowWindow(video_hwnd_, SW_SHOW);
    BringWindowToTop(video_hwnd_);
    SetForegroundWindow(video_hwnd_);
    UpdateWindow(video_hwnd_);

    InitializeMpv();
    
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args) {
      auto idx_it = args->find(flutter::EncodableValue("playlist_index"));
      if (idx_it != args->end()) {
        playlist_index_ = std::get<int>(idx_it->second);
      }
      auto url_it = args->find(flutter::EncodableValue("url"));
      if (url_it != args->end()) {
        std::string url = std::get<std::string>(url_it->second);
        const char *cmd[] = {"loadfile", url.c_str(), nullptr};
        mpv_command_(mpv_, cmd);
      }
    }
    result->Success();
  } else if (method_call.method_name() == "playPause") {
    if (mpv_) {
      const char *cmd[] = {"cycle", "pause", nullptr};
      mpv_command_(mpv_, cmd);
    }
    result->Success();
  } else if (method_call.method_name() == "closePlayer") {
    DestroyMpv();
    ShowWindow(video_hwnd_, SW_HIDE);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void FlutterTvMedia3Plugin::HandleUiMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (!mpv_) {
    result->Success();
    return;
  }

  if (method_call.method_name() == "playPause") {
    const char *cmd[] = {"cycle", "pause", nullptr};
    mpv_command_(mpv_, cmd);
    result->Success();
  } else if (method_call.method_name() == "play") {
    int pause = 0;
    mpv_set_property_(mpv_, "pause", MPV_FORMAT_FLAG, &pause);
    result->Success();
  } else if (method_call.method_name() == "pause") {
    int pause = 1;
    mpv_set_property_(mpv_, "pause", MPV_FORMAT_FLAG, &pause);
    result->Success();
  } else if (method_call.method_name() == "seekTo") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args) {
      auto pos_it = args->find(flutter::EncodableValue("position"));
      if (pos_it != args->end()) {
        double pos = std::get<double>(pos_it->second) / 1000.0;
        std::string pos_str = std::to_string(pos);
        const char *cmd[] = {"seek", pos_str.c_str(), "absolute", nullptr};
        mpv_command_(mpv_, cmd);
      }
    }
    result->Success();
  } else if (method_call.method_name() == "onOverlayEntryPointCalled") {
    result->Success();
  } else if (method_call.method_name() == "stop" || method_call.method_name() == "onBack") {
    DestroyMpv();
    ShowWindow(video_hwnd_, SW_HIDE);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace flutter_tv_media3
