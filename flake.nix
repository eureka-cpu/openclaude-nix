{
  description = "Nix package and home-manager module for openclaude";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = eachSystem (system: {
        openclaude = nixpkgs.legacyPackages.${system}.callPackage ./packages/openclaude.nix { };
        default = self.packages.${system}.openclaude;
      });

      overlays.default = final: prev: {
        openclaude = prev.callPackage ./packages/openclaude.nix { };
      };

      homeManagerModules = {
        openclaude = ./modules/home-manager/openclaude.nix;
        default = self.homeManagerModules.openclaude;
      };
    };
}
