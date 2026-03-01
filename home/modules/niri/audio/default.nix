{ pkgs, ... }:
{
  home.packages = with pkgs; [
    playerctl
  ];

  services.easyeffects = {
    enable = true;
    preset = "luix-crystal-voice";

    extraPresets = {
      luix-crystal-voice = {
        input = {
          blocklist = [ ];

          "plugins_order" = [
            "rnnoise#0"
            "gate#0"
            "equalizer#0"
            "compressor#0"
            "deesser#0"
            "limiter#0"
          ];

          "rnnoise#0" = {
            bypass = false;
            "enable-vad" = false;
            "input-gain" = 0.0;
            "model-name" = "\"\"";
            "output-gain" = 0.0;
            release = 20.0;
            "use-standard-model" = true;
            "vad-thres" = 30.0;
            wet = 0.65;
          };

          "gate#0" = {
            attack = 5.0;
            bypass = false;
            "curve-threshold" = -55.0;
            "curve-zone" = -2.0;
            dry = -80.01;
            "hpf-frequency" = 10.0;
            "hpf-mode" = "Off";
            hysteresis = true;
            "hysteresis-threshold" = -3.0;
            "hysteresis-zone" = -1.0;
            "input-gain" = 0.0;
            "input-to-link" = 0.0;
            "input-to-sidechain" = 0.0;
            "link-to-input" = 0.0;
            "link-to-sidechain" = 0.0;
            "lpf-frequency" = 20000.0;
            "lpf-mode" = "Off";
            makeup = 1.0;
            "output-gain" = 0.0;
            reduction = -15.0;
            release = 180.0;
            sidechain = {
              lookahead = 0.0;
              mode = "RMS";
              preamp = 0.0;
              reactivity = 10.0;
              source = "Middle";
              "stereo-split-source" = "Left/Right";
              type = "Internal";
            };
            "sidechain-to-input" = 0.0;
            "sidechain-to-link" = 0.0;
            "stereo-split" = false;
            wet = -1.0;
          };

          "equalizer#0" = {
            balance = 0.0;
            bypass = false;
            "input-gain" = 0.0;
            mode = "IIR";
            "num-bands" = 5;
            "output-gain" = 0.0;
            "pitch-left" = 0.0;
            "pitch-right" = 0.0;
            "split-channels" = false;

            left = {
              band0 = {
                frequency = 90.0;
                gain = 0.0;
                mode = "RLC (BT)";
                mute = false;
                q = 0.7;
                slope = "x2";
                solo = false;
                type = "Hi-pass";
                width = 4.0;
              };
              band1 = {
                frequency = 180.0;
                gain = -3.0;
                mode = "RLC (MT)";
                mute = false;
                q = 1.0;
                slope = "x1";
                solo = false;
                type = "Bell";
                width = 4.0;
              };
              band2 = {
                frequency = 320.0;
                gain = -2.5;
                mode = "BWC (MT)";
                mute = false;
                q = 1.0;
                slope = "x2";
                solo = false;
                type = "Bell";
                width = 4.0;
              };
              band3 = {
                frequency = 3500.0;
                gain = 2.0;
                mode = "BWC (BT)";
                mute = false;
                q = 0.9;
                slope = "x2";
                solo = false;
                type = "Bell";
                width = 4.0;
              };
              band4 = {
                frequency = 9000.0;
                gain = 1.8;
                mode = "LRX (MT)";
                mute = false;
                q = 0.7;
                slope = "x1";
                solo = false;
                type = "Hi-shelf";
                width = 4.0;
              };
            };

            right = {
              band0 = {
                frequency = 90.0;
                gain = 0.0;
                mode = "RLC (BT)";
                mute = false;
                q = 0.7;
                slope = "x2";
                solo = false;
                type = "Hi-pass";
                width = 4.0;
              };
              band1 = {
                frequency = 180.0;
                gain = -3.0;
                mode = "RLC (MT)";
                mute = false;
                q = 1.0;
                slope = "x1";
                solo = false;
                type = "Bell";
                width = 4.0;
              };
              band2 = {
                frequency = 320.0;
                gain = -2.5;
                mode = "BWC (MT)";
                mute = false;
                q = 1.0;
                slope = "x2";
                solo = false;
                type = "Bell";
                width = 4.0;
              };
              band3 = {
                frequency = 3500.0;
                gain = 2.0;
                mode = "BWC (BT)";
                mute = false;
                q = 0.9;
                slope = "x2";
                solo = false;
                type = "Bell";
                width = 4.0;
              };
              band4 = {
                frequency = 9000.0;
                gain = 1.8;
                mode = "LRX (MT)";
                mute = false;
                q = 0.7;
                slope = "x1";
                solo = false;
                type = "Hi-shelf";
                width = 4.0;
              };
            };
          };

          "compressor#0" = {
            attack = 10.0;
            "boost-amount" = 0.0;
            "boost-threshold" = -72.0;
            bypass = false;
            dry = -80.01;
            "hpf-frequency" = 10.0;
            "hpf-mode" = "Off";
            "input-gain" = 0.0;
            "input-to-link" = 0.0;
            "input-to-sidechain" = 0.0;
            knee = -6.0;
            "link-to-input" = 0.0;
            "link-to-sidechain" = 0.0;
            "lpf-frequency" = 20000.0;
            "lpf-mode" = "Off";
            makeup = 2.0;
            mode = "Downward";
            "output-gain" = 0.0;
            ratio = 2.5;
            release = 140.0;
            "release-threshold" = -40.0;
            sidechain = {
              lookahead = 0.0;
              mode = "RMS";
              preamp = 0.0;
              reactivity = 10.0;
              source = "Middle";
              "stereo-split-source" = "Left/Right";
              type = "Feed-forward";
            };
            "sidechain-to-input" = 0.0;
            "sidechain-to-link" = 0.0;
            "stereo-split" = false;
            threshold = -20.0;
            wet = 0.0;
          };

          "deesser#0" = {
            bypass = false;
            detection = "RMS";
            "f1-freq" = 4500.0;
            "f1-level" = -6.0;
            "f2-freq" = 8500.0;
            "f2-level" = -6.0;
            "f2-q" = 1.5;
            "input-gain" = 0.0;
            laxity = 15;
            makeup = 0.0;
            mode = "Split";
            "output-gain" = 0.0;
            ratio = 3.0;
            "sc-listen" = false;
            threshold = -24.0;
          };

          "limiter#0" = {
            alr = false;
            "alr-attack" = 5.0;
            "alr-knee" = 0.0;
            "alr-release" = 50.0;
            attack = 2.0;
            bypass = false;
            dithering = "16bit";
            "gain-boost" = false;
            "input-gain" = 0.0;
            "input-to-link" = 0.0;
            "input-to-sidechain" = 0.0;
            "link-to-input" = 0.0;
            "link-to-sidechain" = 0.0;
            lookahead = 2.0;
            mode = "Herm Wide";
            "output-gain" = 0.0;
            oversampling = "None";
            release = 5.0;
            "sidechain-preamp" = 0.0;
            "sidechain-to-input" = 0.0;
            "sidechain-to-link" = 0.0;
            "sidechain-type" = "Internal";
            "stereo-link" = 100.0;
            threshold = -2.0;
          };
        };
      };
    };
  };
}
