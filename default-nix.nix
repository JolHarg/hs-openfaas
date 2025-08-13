{
  nixpkgs ? import <nixpkgs> {},
  haskell-tools ? import (builtins.fetchTarball "https://github.com/danwdart/haskell-tools/archive/master.tar.gz") {
    inherit nixpkgs;
    inherit compiler;
  },
  compiler ? "ghc912"
}:
let
  pkgsForX86 = if builtins.currentSystem == "x86_64-linux" then nixpkgs else nixpkgs.pkgsCross.gnu64.pkgsBuildHost;
  pkgsX86 = if builtins.currentSystem == "x86_64-linux" then nixpkgs else nixpkgs.pkgsCross.gnu64.pkgsHostHost;
  gitignore = nixpkgs.nix-gitignore.gitignoreSourcePure [ ./.gitignore ];
  tools = haskell-tools compiler;
  inherit (pkgsX86.haskell) lib;
  myHaskellPackages = pkgsX86.haskell.packages.${compiler}.override {
    overrides = self: super: rec {
      openfaas = lib.dontHaddock (self.callCabal2nix "openfaas" (gitignore ./.) {});
      # Tests for aeson don't work because they should be run as host
      # "Couldn't find a target code interpreter. Try with -fexternal-interpreter"
      aeson = if builtins.currentSystem == "x86_64-linux" then super.aeson else lib.dontCheck super.aeson;
    };
   };
  shell = myHaskellPackages.shellFor {
    packages = p: [
      p.openfaas
    ];
    shellHook = ''
      gen-hie > hie.yaml
      for i in $(find . -type f | grep -v "dist-*"); do krank $i; done
      cabal update
    '';
    buildInputs = tools.defaultBuildTools ++ (with nixpkgs; [
        nodejs_20
        closurecompiler
        pkgsForX86.cabal-install
        pkgsForX86.gcc
        pkgsX86.gmp
        pkgsX86.libffi
        pkgsX86.glibc
    ]);
    nativeBuildInputs = tools.defaultBuildTools ++ (with nixpkgs; [
        nodejs_20
        closurecompiler
        pkgsForX86.cabal-install
        pkgsForX86.gcc
        pkgsX86.gmp
        pkgsX86.libffi
        pkgsX86.glibc
    ]);
    withHoogle = false;
  };
in
{
  inherit shell;
}
