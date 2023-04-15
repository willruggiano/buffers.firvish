{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    devenv.url = "github:cachix/devenv";
  };

  outputs = {flake-parts, ...} @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devenv.flakeModule
      ];

      systems = ["x86_64-linux" "aarch64-darwin"];
      perSystem = {pkgs, ...}: {
        apps.generate-vimdoc.program = pkgs.writeShellApplication {
          name = "generate-vimdoc";
          runtimeInputs = with pkgs; [lemmy-help];
          text = ''
            lemmy-help -c lua/buffers-firvish.lua > doc/buffers-firvish.txt
          '';
        };

        devenv.shells.default = {
          name = "buffers.firvish";
          packages = with pkgs; [lemmy-help luajit zk];
          pre-commit.hooks = {
            alejandra.enable = true;
            stylua.enable = true;
          };
        };

        packages.default = pkgs.vimUtils.buildVimPluginFrom2Nix {
          name = "buffers.firvish";
          src = ./.;
        };
      };
    };
}
