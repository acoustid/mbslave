{
  description = "MusicBrainz Database Mirror ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      packages.default = pkgs.callPackage ./default.nix {};

      #devShells.default = pkgs.mkShell {
      #  buildInputs = [ pkgs.python310 ];
      #};

      apps.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/mbslave";
      };
    });
}
