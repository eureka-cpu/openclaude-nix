{ config, lib, pkgs, osConfig ? { }, ... }:
let
  cfg = config.programs.openclaude;
  ollamaCfg = cfg.ollama;
  jsonFormat = pkgs.formats.json { };

  # NixOS system services.ollama (the only ollama module with loadModels / syncModels)
  nixosOllama = osConfig.services.ollama or { };
  nixosPort = nixosOllama.port or 11434;
  nixosModels = nixosOllama.loadModels or [ ];
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

    ollama = {
      enable = lib.mkEnableOption "ollama integration for openclaude";

      host = lib.mkOption {
        type = lib.types.str;
        # The NixOS listen host may be 0.0.0.0; always default to loopback
        # for client connections.
        default = "127.0.0.1";
        description = "Ollama server host for client connections.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = nixosPort;
        defaultText = lib.literalExpression ''
          osConfig.services.ollama.port or 11434
        '';
        description = "Ollama server port.";
      };

      extraModels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "gemma3" "llama3.2:8b" ];
        description = ''
          Ollama models to register in openclaude's {option}`agentModels`.

          These are merged with any models declared in
          {option}`osConfig.services.ollama.loadModels` (the NixOS system
          module, which is the only ollama module with a declarative model
          list). Use this option when running home-manager standalone (no
          NixOS), or to include models that are already pulled locally but
          not listed in `loadModels`.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
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
    })

    (lib.mkIf (cfg.enable && ollamaCfg.enable) {
      programs.openclaude.settings.agentModels =
        let
          allModels = lib.unique (nixosModels ++ ollamaCfg.extraModels);
          url = "http://${ollamaCfg.host}:${toString ollamaCfg.port}/v1";
        in
        lib.listToAttrs (map
          (m: lib.nameValuePair m {
            base_url = url;
            api_key = "ollama";
          })
          allModels);
    })
  ];
}
