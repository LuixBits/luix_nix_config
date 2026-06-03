{ ... }:
{
  programs.fish = {
    enable = true;

    functions.fish_greeting = ''
      set -l pine (set_color 5f8d62)
      set -l leaf (set_color 8ccf7e)
      set -l moss (set_color 6f8f5f)
      set -l bark (set_color a58f6f)
      set -l mist (set_color 6b7f6a)
      set -l hello (set_color d6e7b5)
      set -l normal (set_color normal)

      echo
      printf '%s%s%s\n' "$pine" '       /\        /\        /\       ' "$normal"
      printf '%s%s%s\n' "$leaf" '      /  \  /\  /  \  /\  /  \      ' "$normal"
      printf '%s%s%s\n' "$pine" '     /____\/__\/____\/__\/____\     ' "$normal"
      printf '%s      ||    ||   %shello%s   ||    ||%s\n' "$bark" "$hello" "$bark" "$normal"
      printf '%s%s%s\n' "$moss" '   /\ ||        /\        || /\    ' "$normal"
      printf '%s%s%s\n' "$pine" '  /__\||       /__\       ||/__\   ' "$normal"
      printf '%s%s%s\n' "$mist" '       ~~~  ~~~  ~~  ~~~  ~~~       ' "$normal"
      echo
    '';
  };

  # aliases
  # abbreviations
  # functions
  # prompt
}
