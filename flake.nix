{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShell = pkgs.mkShell {
        packages = with pkgs; [
          mpi
          # mpich
          cmake
          gnumake
          gcc
          liberation_ttf
          nerd-fonts.jetbrains-mono 
          typst
          tinymist
          times-newer-roman
          neovim
          python312
          python312Packages.numpy
          python312Packages.matplotlib
          uv
        ];
        CMAKE_EXPORT_COMPILE_COMMANDS = 1;
        shellHook = ''
          fc-cache -f -v >> /dev/null
        '';
      };
    });
}
