{
  description = "TNT Core Smart contracts development environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    foundry = {
      url = "github:shazow/foundry.nix/monthly";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, foundry, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ foundry.overlay ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "tnt-core";
          nativeBuildInputs = [ ];
          buildInputs = [
            pkgs.foundry-bin
            # Nodejs
            pkgs.nodePackages.typescript-language-server
            pkgs.nodejs_22
            pkgs.nodePackages.yarn
          ];
          packages = [ ];
        };
      });
}
