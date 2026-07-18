# openclaude-nix

Nix package and [home-manager](https://github.com/nix-community/home-manager) module for
[openclaude](https://github.com/Gitlawb/openclaude), a terminal-first coding agent that extends
claude-code with support for OpenAI, Gemini, Ollama, DeepSeek, Groq, AWS Bedrock, and 20+ other
LLM providers.

## Package

### Run directly

```bash
nix run github:eureka-cpu/openclaude-nix#openclaude
```

### Install into profile

```bash
nix profile install github:eureka-cpu/openclaude-nix#openclaude
```

### Overlay (make `pkgs.openclaude` available in your own flake)

```nix
inputs.openclaude-nix = {
  url = "github:eureka-cpu/openclaude-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};

# In nixpkgs config or NixOS/nix-darwin module:
nixpkgs.overlays = [ openclaude-nix.overlays.default ];

# pkgs.openclaude is now available anywhere pkgs is in scope
home.packages = [ pkgs.openclaude ];
```

## Home-manager Module

The module manages `~/.openclaude.json` and optionally `~/.claude/CLAUDE.md`. It works on NixOS,
nix-darwin, and any platform running standalone home-manager.

### Wire into your flake

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  openclaude-nix = {
    url = "github:eureka-cpu/openclaude-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

# Inside your home-manager module list:
modules = [
  { nixpkgs.overlays = [ openclaude-nix.overlays.default ]; }
  openclaude-nix.homeManagerModules.openclaude
  ./home.nix
];
```

### Minimal configuration

```nix
programs.openclaude.enable = true;
```

### Full configuration example

```nix
programs.openclaude = {
  enable = true;

  settings = {
    theme = "dark";
    compactModel = "claude-3-5-haiku-20241022";
    verbose = false;
  };

  claudeMd = ''
    You are a concise assistant.
    Prefer functional programming patterns.
    Always write tests.
  '';
};

# API keys go here, NOT in settings (see warning below)
home.sessionVariables.ANTHROPIC_API_KEY = "sk-ant-...";
```

### Module options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | Install openclaude and manage its config |
| `package` | package | `pkgs.openclaude` | Override the package |
| `settings` | attrset | `{}` | Written to `~/.openclaude.json` |
| `claudeMd` | string or null | `null` | Written to `~/.claude/CLAUDE.md` |

`settings` is merged with Nix-managed defaults (`autoUpdates = false`, `installMethod = "nixos"`).
User-supplied keys override those defaults.

### API keys

> **Warning:** Do NOT set `primaryApiKey` or any other secret in `settings`. The Nix store is
> world-readable (mode 0444). Anyone with access to the machine can read it.

Set API keys via `home.sessionVariables`, a shell profile, or a secrets manager:

```nix
# Simple (plain text in Nix store — acceptable only for non-secret config)
home.sessionVariables.ANTHROPIC_API_KEY = "sk-ant-...";

# Recommended for real secrets: sops-nix or agenix
# https://github.com/Mic92/sops-nix
# https://github.com/ryantm/agenix
```

## Releases

Releases are tagged `v{openclaude-version}-{short-commit}` (e.g. `v0.24.0-abc1234`), created
automatically each night when the version in `master` has no existing release.

## Updating

The package derivation includes an update script. To run it manually from the repo root:

```bash
./packages/update.sh
```

The script fetches the latest openclaude version from npm, regenerates `packages/package-lock.json`
from the new tarball, and recomputes both Nix hashes. Nix, Node.js 22, curl, and git must be
available (the script's nix shebang provisions them automatically if run directly).

A nightly GitHub Actions workflow runs the script automatically and opens a PR when a new version
is available.
