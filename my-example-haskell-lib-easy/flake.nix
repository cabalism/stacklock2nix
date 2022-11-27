{
  description = "Easy example of using stacklock2nix to build a Haskell project";

  # This is a flake reference to the stacklock2nix repo.
  #
  # CHANGEME: Note that in a real repo, this will need to be changed to
  # something like the following:
  #
  # inputs.stacklock2nix.url = "github:cdepillabout/stacklock2nix/main";
  inputs.stacklock2nix.url = "path:../.";

  # This is a flake reference to Nixpkgs.
  #
  # CHANGEME: Note that in a real repo, this will need to be changed to
  # something like the following:
  #
  # inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.nixpkgs.follows = "stacklock2nix/nixpkgs";

  outputs = { self, nixpkgs, stacklock2nix }:
    let
      # System types to support.
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor =
        forAllSystems (system: import nixpkgs { inherit system; overlays = [ stacklock2nix.overlay self.overlay ]; });
    in
    {
      # A Nixpkgs overlay.
      overlay = final: prev: {
        # This is a top-level attribute that contains the result from calling
        # stacklock2nix.
        my-example-haskell-stacklock = final.stacklock2nix {
          stackYaml = ./stack.yaml;

          # The Haskell package set to use as a base.  You should change this
          # based on the compiler version from the resolver in your stack.yaml.
          baseHaskellPkgSet = final.haskell.packages.ghc924;

          # Any additional Haskell package overrides you may want to add.
          additionalHaskellPkgSetOverrides = hfinal: hprev: {
            # TODO: Explain why this is necessary and link to servant-cassava PR.
            servant-cassava =
              final.haskell.lib.compose.overrideCabal
                { editedCabalFile = null; revision = null; }
                hprev.servant-cassava;
          };

          # Additional packages that should be available for development.
          additionalDevShellNativeBuildInputs = stacklockHaskellPkgSet: [
            # Some Haskell tools (like cabal-install and ghcid) can be taken from the
            # top-level of Nixpkgs.
            final.cabal-install
            final.ghcid
            final.stack
            # Some Haskell tools need to have been compiled with the same compiler
            # you used to define your stacklock2nix Haskell package set.  Be
            # careful not to pull these packages from your stacklock2nix Haskell
            # package set, since transitive dependency versions may have been
            # carefully setup in Nixpkgs so that the tool will compile, and your
            # stacklock2nix Haskell package set will likely contain different
            # versions.
            final.haskell.packages.ghc924.haskell-language-server
            # Other Haskell tools may need to be taken from the stacklock2nix
            # Haskell package set, and compiled with the example same dependency
            # versions your project depends on.
            #stacklockHaskellPkgSet.some-haskell-lib
          ];

          # When creating your own Haskell package set from the stacklock2nix
          # output, you may need to specify a newer all-cabal-hashes.
          #
          # This is necessary when you are using a Stackage snapshot/resolver or
          # `extraDeps` in your `stack.yaml` file that is _newer_ than the
          # `all-cabal-hashes` derivation from the Nixpkgs you are using.
          #
          # If you are using the latest nixpkgs-unstable and an old Stackage
          # resolver, then it is usually not necessary to override
          # `all-cabal-hashes`.
          #
          # If you are using a very recent Stackage resolver and an old Nixpkgs,
          # it is almost always necessary to override `all-cabal-hashes`.
          all-cabal-hashes = final.fetchurl {
            name = "all-cabal-hashes";
            url = "https://github.com/commercialhaskell/all-cabal-hashes/archive/9ab160f48cb535719783bc43c0fbf33e6d52fa99.tar.gz";
            sha256 = "sha256-QC07T3MEm9LIMRpxIq3Pnqul60r7FpAdope6S62sEX8=";
          };
        };

        # One of our local packages.
        my-example-haskell-app = final.my-example-haskell-stacklock.pkgSet.my-example-haskell-app;

        # You can also easily create a development shell for hacking on your local
        # packages with `cabal`.
        my-example-haskell-dev-shell = final.my-example-haskell-stacklock.devShell;
      };

      packages = forAllSystems (system: {
        my-example-haskell-app = nixpkgsFor.${system}.my-example-haskell-app;
      });

      defaultPackage = forAllSystems (system: self.packages.${system}.my-example-haskell-app);

      devShells = forAllSystems (system: {
        my-example-haskell-dev-shell = nixpkgsFor.${system}.my-example-haskell-dev-shell;
      });

      devShell = forAllSystems (system: self.devShells.${system}.my-example-haskell-dev-shell);
    };
}
