{
  wivrn,
  lib,
  fetchFromGitHub,
  fetchFromGitLab,
  applyPatches,
  libpng,
}:
# The Quest store ships 26.9, while both pinned nixpkgs inputs still have 26.6.2.
# Keep the server, dashboard and OpenXR library on the same release as the Quest.
# Remove this override once the repository's nixpkgs provides that release.
wivrn.overrideAttrs (
  finalAttrs: previous: {
    version = "26.9";

    src = fetchFromGitHub {
      owner = "WiVRn";
      repo = "WiVRn";
      rev = "v${finalAttrs.version}";
      hash = "sha256-/kXgbku/4EeYY5YTwtY71csgxOP8bRACLqOvKXolg5g=";
    };

    monado = applyPatches {
      src = fetchFromGitLab {
        domain = "gitlab.freedesktop.org";
        owner = "monado";
        repo = "monado";
        rev = "f037264d23e2472a444a157370647fcd601ed81b";
        hash = "sha256-exHbecudAy57szL7kut7/fBYCoekEs3riZzhMtFWS/c=";
      };
      postPatch = ''
        ${finalAttrs.src}/patches/apply.sh ${finalAttrs.src}/patches/monado/*
      '';
    };

    buildInputs = previous.buildInputs ++ [ libpng ];

    # 26.9 distinguishes official tags from development builds. Supplying only
    # GIT_DESC/GIT_COMMIT would label this release as a development build.
    cmakeFlags =
      lib.filter (
        flag:
        !(lib.hasPrefix "-DGIT_DESC" flag)
        && !(lib.hasPrefix "-DGIT_COMMIT" flag)
        && !(lib.hasPrefix "-DWIVRN_USE_PULSEAUDIO" flag)
      ) previous.cmakeFlags
      ++ [ (lib.cmakeFeature "GIT_TAG" "v${finalAttrs.version}") ];
  }
)
