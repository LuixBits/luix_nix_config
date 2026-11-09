{
  fetchurl,
  runCommand,
  strata,
}:
let
  normalRepo = "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF";
  normalRevision = "ed59f92082b1e93c0e96d60a8b11aab089b52f09";
  abliteratedRepo = "SC117/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-GGUF";
  abliteratedRevision = "90a3350cd800ec1fe0d1660a38414ad9e985782f";
  normalStem = "Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS";
  abliteratedStem = "Qwen3.8-Flash-Next-GSQ-RCO-abliterated-IQ3_XXS";
  fetchModel =
    repo: revision: name: sha256:
    fetchurl {
      inherit name sha256;
      url = "https://huggingface.co/${repo}/resolve/${revision}/IQ3_XXS/${name}";
    };
  # Identical SHA256 in both publishers' manifests: store these 28.8 GB once.
  lookup =
    fetchModel normalRepo normalRevision "${normalStem}-00002-of-00002.gguf"
      "316b46f3a2dbd68c900f43136ab9449f9dcc3725dfd8c794847c204bc161e113";
  mkModel =
    {
      name,
      repo,
      revision,
      stem,
      hash,
    }:
    let
      weights = fetchModel repo revision "${stem}-00001-of-00002.gguf" hash;
    in
    runCommand "strata-qwen38-${name}-iq3-xxs"
      {
        nativeBuildInputs = [ strata ];
        passthru = {
          inherit
            repo
            revision
            stem
            weights
            lookup
            ;
        };
      }
      ''
        mkdir -p "$out/model"
        ln -s ${weights} "$out/model/${stem}-00001-of-00002.gguf"
        ln -s ${lookup} "$out/model/${stem}-00002-of-00002.gguf"
        # Each variant needs its OWN dense weights, offsets and tokenizer.
        # Without --experts-bin the large expert matrices stay in the GGUF.
        strata-pack --gguf "$out/model/${stem}-00001-of-00002.gguf" --out "$out/pack"
      '';
in
{
  normal = mkModel {
    name = "normal";
    repo = normalRepo;
    revision = normalRevision;
    stem = normalStem;
    hash = "219ea929900dfa9ef091f3aa473fdba6874b65fcb36526d7d851ac9e95856d15";
  };
  abliterated = mkModel {
    name = "abliterated";
    repo = abliteratedRepo;
    revision = abliteratedRevision;
    stem = abliteratedStem;
    hash = "03b11926b41a3d7f7a008882b1bc7a6330a3c9c43d3cad4598d31dc73042fdc5";
  };
}
