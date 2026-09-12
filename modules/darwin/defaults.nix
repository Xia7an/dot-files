{ ... }:
{
  system.defaults = {
    dock = {
      autohide = true;
      expose-group-apps = false;
      largesize = 102;
      magnification = true;
      minimize-to-application = false;
      mineffect = "genie";
      mru-spaces = false;
      orientation = "bottom";
      show-recents = false;
      showAppExposeGestureEnabled = false;
      showMissionControlGestureEnabled = true;
    };
    finder = {
      AppleShowAllExtensions = false;
      FXPreferredViewStyle = "icnv";
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowRemovableMediaOnDesktop = true;
    };
    magicmouse.MouseButtonMode = "OneButton";
    NSGlobalDomain = {
      AppleEnableSwipeNavigateWithScrolls = true;
      ApplePressAndHoldEnabled = false;
      AppleSpacesSwitchOnActivate = false;
      AppleWindowTabbingMode = "always";
      # 実機の HID 値では 1 単位 ≈ 1/60 秒。
      # 待ち時間を 15 (約250ms) から 25 (約417ms) に延ばして
      # 誤リピートを抑える。二重入力の原因確定を意味するものではない。
      KeyRepeat = 2;
      InitialKeyRepeat = 25;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };
    menuExtraClock = {
      FlashDateSeparators = true;
      IsAnalog = false;
      ShowAMPM = true;
      ShowDate = 0;
      ShowDayOfWeek = true;
      ShowSeconds = true;
    };
    screencapture.target = "clipboard";
    trackpad = {
      ActuateDetents = true;
      Clicking = false;
      DragLock = false;
      Dragging = false;
      FirstClickThreshold = 1;
      ForceSuppressed = false;
      SecondClickThreshold = 1;
      TrackpadCornerSecondaryClick = 0;
      TrackpadFourFingerHorizSwipeGesture = 2;
      TrackpadFourFingerPinchGesture = 2;
      TrackpadFourFingerVertSwipeGesture = 2;
      TrackpadMomentumScroll = true;
      TrackpadPinch = true;
      TrackpadRightClick = true;
      TrackpadRotate = true;
      TrackpadThreeFingerDrag = false;
      TrackpadThreeFingerHorizSwipeGesture = 2;
      TrackpadThreeFingerTapGesture = 0;
      TrackpadThreeFingerVertSwipeGesture = 0;
      TrackpadTwoFingerDoubleTapGesture = true;
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
    };
    CustomUserPreferences = {
      NSGlobalDomain = {
        AppleMenuBarVisibleInFullscreen = true;
        AppleMiniaturizeOnDoubleClick = false;
        NSQuitAlwaysKeepsWindows = true;
        "_HIHideMenuBar" = false;
      };
      "com.apple.HIToolbox" = {
        AppleCurrentKeyboardLayoutInputSourceID = "com.apple.keylayout.ABC";
        AppleDictationAutoEnable = true;
        # 先頭の "Keyboard Layout" エントリは必須。これが無いと有効な入力
        # ソースから物理キーボードのレイアウトが消え、AppleCurrentKeyboard-
        # LayoutInputSourceID が指す ABC と実際の状態が食い違ったまま
        # org.nixos.activate-system が起動毎に上書きしてしまう。
        # KeyboardLayout ID 252 = ABC。
        AppleEnabledInputSources = [
          {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = 252;
            "KeyboardLayout Name" = "ABC";
          }
          # Google 日本語入力は実機の選択中ソースにも存在する。
          # 有効リストから除外して起動時に上書きしないよう、英数も含める。
          {
            "Bundle ID" = "com.google.inputmethod.Japanese";
            "Input Mode" = "com.apple.inputmethod.Roman";
            InputSourceKind = "Input Mode";
          }
          {
            "Bundle ID" = "com.google.inputmethod.Japanese";
            "Input Mode" = "com.apple.inputmethod.Japanese";
            InputSourceKind = "Input Mode";
          }
          {
            "Bundle ID" = "com.google.inputmethod.Japanese";
            InputSourceKind = "Keyboard Input Method";
          }
          {
            "Bundle ID" = "dev.ensan.inputmethod.azooKeyMac";
            "Input Mode" = "com.apple.inputmethod.Japanese";
            InputSourceKind = "Input Mode";
          }
          {
            "Bundle ID" = "dev.ensan.inputmethod.azooKeyMac";
            InputSourceKind = "Keyboard Input Method";
          }
          {
            "Bundle ID" = "com.apple.inputmethod.Kotoeri.RomajiTyping";
            "Input Mode" = "com.apple.inputmethod.Japanese";
            InputSourceKind = "Input Mode";
          }
          {
            "Bundle ID" = "com.apple.inputmethod.Kotoeri.RomajiTyping";
            InputSourceKind = "Keyboard Input Method";
          }
          {
            "Bundle ID" = "com.apple.CharacterPaletteIM";
            InputSourceKind = "Non Keyboard Input Method";
          }
        ];
      };
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "10" = {
            enabled = false;
          }; # 日本語入力ソースを選択
          "11" = {
            enabled = false;
          };
          "50" = {
            enabled = false;
          }; # 入力メニューの Spotlight を無効化
          "64" = {
            enabled = false;
          }; # Spotlight 検索を表示 (cmd+space) — Raycast に譲るため無効化
          "79" = {
            enabled = true;
            value = {
              type = "standard";
              parameters = [
                65535
                123
                262144
              ];
            };
          }; # 左の Space に移動 (Ctrl+←)
          "81" = {
            enabled = true;
            value = {
              type = "standard";
              parameters = [
                65535
                124
                262144
              ];
            };
          }; # 右の Space に移動 (Ctrl+→)
        };
      };
    };
  };
}
