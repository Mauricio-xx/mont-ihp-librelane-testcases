{
  description = "LibreLane IHP SG13G2 CI Test Suite (Reproducible)";

  inputs = {
    # LibreLane 3.0.0.dev43 - Required for IHP SG13G2 support
    # Uses nix-eda 5.5.0 internally
    librelane.url = "github:librelane/librelane/3.0.0.dev43";

    # Use same nixpkgs as nix-eda for Python version compatibility
    nixpkgs.follows = "librelane/nix-eda/nixpkgs";

    # IHP PDK pinned to production baseline
    ihp-pdk = {
      url = "github:IHP-GmbH/IHP-Open-PDK/cb716cc8291193fb63ef16c94c9e12526f9221be";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, librelane, ihp-pdk }:
    let
      nix-eda = librelane.inputs.nix-eda;
      devshell = librelane.inputs.devshell;
      lib = nixpkgs.lib;
    in {
      # Expose overlays from LibreLane
      overlays = librelane.overlays;

      # Package system with EDA tools
      legacyPackages = nix-eda.forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [
            nix-eda.overlays.default
            devshell.overlays.default
            librelane.overlays.default
          ];
        }
      );

      # Build packages
      packages = nix-eda.forAllSystems (system: let
        pkgs = self.legacyPackages.${system};
        basePackages = librelane.packages.${system};

        # LibreLane with tests disabled for CI speed
        librelanePkg = basePackages.default.overridePythonAttrs (_: {
          doCheck = false;
          checkInputs = [];
        });

        # Test suite runner
        runSuite = pkgs.writeShellApplication {
          name = "librelane-suite";
          runtimeInputs = [
            librelanePkg
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
          ];
          text = ''
            exec ${./scripts/run_suite.sh} "$@"
          '';
        };
      in basePackages // {
        default = librelanePkg;
        librelane = librelanePkg;
        suite = runSuite;
      });

      # Apps for direct execution
      apps = nix-eda.forAllSystems (system: let
        librelaneApp = {
          type = "app";
          program = "${self.packages.${system}.librelane}/bin/librelane";
        };
        suiteApp = {
          type = "app";
          program = "${self.packages.${system}.suite}/bin/librelane-suite";
        };
      in {
        default = suiteApp;
        librelane = librelaneApp;
        run-suite = suiteApp;
      });

      # Development shell (uses system PDK_ROOT from environment)
      devShells = nix-eda.forAllSystems (system: let
        pkgs = self.legacyPackages.${system};
      in {
        default = lib.callPackageWith pkgs (librelane.createOpenLaneShell {
          extra-packages = with pkgs; [];
          extra-python-packages = with pkgs.python3.pkgs; [];
          # Use PDK_ROOT from system environment (bashrc)
          # LibreLane/Ciel requires writable PDK location
          extra-env = [];
        }) {};
      });
    };
}
