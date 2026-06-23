{ config, pkgs, ... }:
let
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "35" ];
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis_playstore" ];
    abiVersions = [ "x86_64" ];
  };

  androidSdk = androidComposition.androidsdk;
  androidSdkRoot = "${androidSdk}/libexec/android-sdk";
  sigaAvdName = "siga-pixel-api-35";
  sigaSystemImage = "system-images;android-35;google_apis_playstore;x86_64";
  sigaHostDnsServer = "127.0.0.1";
  caddyRootCert = "/etc/android-siga/caddy-local-root.crt";

  createAvd = pkgs.writeShellApplication {
    name = "android-siga-create-avd";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = ''
      export ANDROID_HOME="${androidSdkRoot}"
      export ANDROID_SDK_ROOT="${androidSdkRoot}"
      export ANDROID_AVD_HOME="${config.home.homeDirectory}/.android/avd"

      avd_name="''${ANDROID_SIGA_AVD:-${sigaAvdName}}"
      avdmanager=""
      for candidate in \
        "${androidSdkRoot}"/cmdline-tools/*/bin/avdmanager \
        "${androidSdkRoot}"/tools/bin/avdmanager
      do
        if [ -x "$candidate" ]; then
          avdmanager="$candidate"
          break
        fi
      done

      if [ -z "$avdmanager" ]; then
        echo "Could not find avdmanager in ${androidSdkRoot}" >&2
        exit 1
      fi

      if [ -d "$ANDROID_AVD_HOME/$avd_name.avd" ]; then
        echo "AVD already exists: $avd_name"
        exit 0
      fi

      mkdir -p "$ANDROID_AVD_HOME"

      create_with_device() {
        device="$1"
        printf 'no\n' | "$avdmanager" create avd \
          --force \
          --name "$avd_name" \
          --package "${sigaSystemImage}" \
          --device "$device"
      }

      create_with_device pixel_8 \
        || create_with_device pixel_7 \
        || create_with_device pixel_6 \
        || create_with_device pixel_5

      cat > "$ANDROID_AVD_HOME/$avd_name.avd/config.ini.tmp" <<'EOF'
hw.keyboard=yes
showDeviceFrame=yes
skin.dynamic=yes
EOF
      cat "$ANDROID_AVD_HOME/$avd_name.avd/config.ini.tmp" >> "$ANDROID_AVD_HOME/$avd_name.avd/config.ini"
      rm "$ANDROID_AVD_HOME/$avd_name.avd/config.ini.tmp"

      echo "Created AVD: $avd_name"
    '';
  };

  startEmulator = pkgs.writeShellApplication {
    name = "android-siga-emulator";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = ''
      export ANDROID_HOME="${androidSdkRoot}"
      export ANDROID_SDK_ROOT="${androidSdkRoot}"
      export ANDROID_AVD_HOME="${config.home.homeDirectory}/.android/avd"

      avd_name="''${ANDROID_SIGA_AVD:-${sigaAvdName}}"

      if [ ! -d "$ANDROID_AVD_HOME/$avd_name.avd" ]; then
        ${createAvd}/bin/android-siga-create-avd
      fi

      exec "${androidSdkRoot}/emulator/emulator" \
        -avd "$avd_name" \
        -dns-server "${sigaHostDnsServer}" \
        -netdelay none \
        -netspeed full \
        -no-metrics \
        -no-audio \
        -gpu swiftshader_indirect \
        "$@"
    '';
  };

  openCheckout = pkgs.writeShellApplication {
    name = "android-siga-open";
    text = ''
      export ANDROID_HOME="${androidSdkRoot}"
      export ANDROID_SDK_ROOT="${androidSdkRoot}"

      url="''${1:-https://roi.local/}"
      adb="${androidSdkRoot}/platform-tools/adb"

      "$adb" wait-for-device
      exec "$adb" shell am start \
        -a android.intent.action.VIEW \
        -d "$url"
    '';
  };

  installCaddyCert = pkgs.writeShellApplication {
    name = "android-siga-install-caddy-cert";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = ''
      export ANDROID_HOME="${androidSdkRoot}"
      export ANDROID_SDK_ROOT="${androidSdkRoot}"

      cert="''${1:-${caddyRootCert}}"
      adb="${androidSdkRoot}/platform-tools/adb"
      target="/sdcard/Download/caddy-local-root.crt"

      if [ ! -r "$cert" ]; then
        legacy_cert="/etc/android-checkout/caddy-local-root.crt"
        if [ "$cert" = "${caddyRootCert}" ] && [ -r "$legacy_cert" ]; then
          cert="$legacy_cert"
        fi
      fi

      if [ ! -r "$cert" ]; then
        cat >&2 <<EOF
Cannot read Caddy root certificate: $cert

Start Caddy once, then run:
  sudo systemctl start android-siga-caddy-ca.service
EOF
        exit 1
      fi

      "$adb" wait-for-device
      "$adb" push "$cert" "$target"

      if ! "$adb" shell am start \
        -a android.intent.action.VIEW \
        -t application/x-x509-ca-cert \
        -d "file://$target"; then
        cat >&2 <<EOF
The certificate was copied to the emulator:
  $target

Open Android Settings and install it from storage as a CA certificate.
EOF
      fi
    '';
  };
in
{
  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };

  home.packages = [
    androidSdk
    pkgs.android-studio
    pkgs.android-tools
    pkgs.scrcpy
    createAvd
    startEmulator
    openCheckout
    installCaddyCert
  ];

  home.sessionVariables = {
    ANDROID_HOME = androidSdkRoot;
    ANDROID_SDK_ROOT = androidSdkRoot;
    ANDROID_AVD_HOME = "${config.home.homeDirectory}/.android/avd";
    ANDROID_SIGA_AVD = sigaAvdName;
  };

  programs.fish.shellAliases = {
    siga-emulator = "android-siga-emulator";
    siga-roi = "android-siga-open https://roi.local/";
    siga-webshop = "android-siga-open https://siga-webshop.local/";
    siga-install-cert = "android-siga-install-caddy-cert";
  };
}
