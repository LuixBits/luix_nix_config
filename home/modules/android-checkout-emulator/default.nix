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
  checkoutAvdName = "checkout-pixel-api-35";
  checkoutSystemImage = "system-images;android-35;google_apis_playstore;x86_64";
  checkoutDnsServer = "10.0.2.2";
  caddyRootCert = "/etc/android-checkout/caddy-local-root.crt";

  createAvd = pkgs.writeShellApplication {
    name = "android-checkout-create-avd";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = ''
      export ANDROID_HOME="${androidSdkRoot}"
      export ANDROID_SDK_ROOT="${androidSdkRoot}"
      export ANDROID_AVD_HOME="${config.home.homeDirectory}/.android/avd"

      avd_name="''${ANDROID_CHECKOUT_AVD:-${checkoutAvdName}}"
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
          --package "${checkoutSystemImage}" \
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
    name = "android-checkout-emulator";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = ''
      export ANDROID_HOME="${androidSdkRoot}"
      export ANDROID_SDK_ROOT="${androidSdkRoot}"
      export ANDROID_AVD_HOME="${config.home.homeDirectory}/.android/avd"

      avd_name="''${ANDROID_CHECKOUT_AVD:-${checkoutAvdName}}"

      if [ ! -d "$ANDROID_AVD_HOME/$avd_name.avd" ]; then
        ${createAvd}/bin/android-checkout-create-avd
      fi

      exec "${androidSdkRoot}/emulator/emulator" \
        -avd "$avd_name" \
        -dns-server "${checkoutDnsServer}" \
        -netdelay none \
        -netspeed full \
        -no-metrics \
        -no-audio \
        "$@"
    '';
  };

  openCheckout = pkgs.writeShellApplication {
    name = "android-checkout-open";
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
    name = "android-checkout-install-caddy-cert";
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
        cat >&2 <<EOF
Cannot read Caddy root certificate: $cert

Start Caddy once, then run:
  sudo systemctl start android-checkout-caddy-ca.service
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
    ANDROID_CHECKOUT_AVD = checkoutAvdName;
  };

  programs.fish.shellAliases = {
    checkout-emulator = "android-checkout-emulator";
    checkout-roi = "android-checkout-open https://roi.local/";
    checkout-webshop = "android-checkout-open https://siga-webshop.local/";
    checkout-install-cert = "android-checkout-install-caddy-cert";
  };
}
