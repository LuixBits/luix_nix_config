{
  inputs,
  lib,
  machine ? null,
  pkgs,
  ...
}:
let
  isFrameworkMachine = machine == "framework";
  unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  frameworkInternalDisplay = [
    "v=China Star Optoelectronics Technology Co., Ltd"
    "m=MND508ZB1-1"
  ];
  philipsLeft = [
    "v=Philips Consumer Electronics Company"
    "m=PHL 288E2"
    "s=UK52128001861"
  ];
  philipsRight = [
    "v=Philips Consumer Electronics Company"
    "m=PHL 288E2"
    "s=UK52128001862"
  ];
  dellLeft = [
    "v=Dell Inc."
    "m=DELL P2419H"
    "s=3SDNP33"
  ];
  dellRight = [
    "v=Dell Inc."
    "m=DELL P2419H"
    "s=5TNN343"
  ];
  benqMain = [
    "v=PNP(BNQ)"
    "m=BenQ EX3415R"
    "s=R7M0014701Q"
  ];
  lgPortrait = [
    "v=LG Electronics"
    "m=LG HDR 4K"
    "s=405NTQDBG628"
  ];

  mkOutput =
    search: position: scale: extra:
    {
      inherit search position scale;
      enable = true;
      mode = "preferred";
      transform = "normal";
    }
    // extra;

  frameworkProfiles = [
    {
      name = "undocked";
      output = [
        (mkOutput frameworkInternalDisplay "0,0" 2.0 { })
      ];
    }
    {
      name = "philips-office";
      output = [
        (mkOutput frameworkInternalDisplay "0,0" 2.0 { })
        (mkOutput philipsLeft "1440,0" 1.5 { })
        (mkOutput philipsRight "4000,0" 1.5 { })
      ];
    }
    {
      name = "dell-office-dock";
      output = [
        (mkOutput dellLeft "0,0" 1.0 { })
        (mkOutput dellRight "1920,0" 1.0 { })
        (mkOutput frameworkInternalDisplay "0,1080" 2.0 { })
      ];
    }
    {
      name = "benq-lg-desk";
      output = [
        (mkOutput frameworkInternalDisplay "0,0" 2.0 { })
        (mkOutput benqMain "1440,0" 1.0 { })
        (mkOutput lgPortrait "4880,0" 1.25 {
          transform = "270";
        })
      ];
    }
  ];
in
lib.mkIf isFrameworkMachine {
  services.shikane = {
    enable = true;
    # 1.1.x uses deterministic, full-cardinality output searches. This avoids
    # the ambiguous connector matching of the older release in stable nixpkgs.
    package = unstablePkgs.shikane;
    settings = {
      # A dock exposes its monitors one after another. Wait until the set has
      # settled so only the final profile is submitted to Niri.
      timeout = 1500;

      profile = frameworkProfiles;
    };
  };
}
