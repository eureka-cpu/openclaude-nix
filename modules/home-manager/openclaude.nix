{ config, lib, pkgs, ... }:
let
  cfg = config.programs.openclaude;
  jsonFormat = pkgs.formats.json { };
in
{
  options.programs.openclaude = {
    enable = lib.mkEnableOption "openclaude CLI";

    package = lib.mkPackageOption pkgs "openclaude" { };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          theme = "dark";
          verbose = false;
          compactModel = "claude-3-5-haiku-20241022";
        }
      '';
      description = ''
        Settings written to {file}`~/.openclaude.json`.

        Merged with Nix-managed defaults `autoUpdates = false` and
        `installMethod = "nixos"`. User-supplied keys override defaults.

        WARNING: Do NOT set `primaryApiKey` here — the Nix store is
        world-readable (0444). Set API keys via
        `home.sessionVariables.ANTHROPIC_API_KEY` or a secrets manager
        (sops-nix, agenix, etc.).
      '';
    };

    claudeMd = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      example = ''
        You are a concise assistant.
        Prefer functional programming patterns.
      '';
      description = ''
        Content written to {file}`~/.claude/CLAUDE.md`. Injected as
        system instructions into every openclaude session. Set to `null`
        (default) to leave the file unmanaged.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".openclaude.json".source =
      let
        # Nix-managed defaults; user settings merge on top (right side wins).
        nixDefaults = {
          autoUpdates = false;
          installMethod = "nixos";
        };
      in
      jsonFormat.generate "openclaude-settings" (nixDefaults // cfg.settings);

    home.file.".claude/CLAUDE.md" = lib.mkIf (cfg.claudeMd != null) {
      text = cfg.claudeMd;
    };
  };
}
