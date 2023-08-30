{
  nixpkgs ? import <nixpkgs> {},
  haskell-tools ? import (builtins.fetchTarball "https://github.com/danwdart/haskell-tools/archive/master.tar.gz") {
    nixpkgs = nixpkgs;
    compiler = compiler;
  },
  compiler ? "ghc94"
}:
let
  gitignore = nixpkgs.nix-gitignore.gitignoreSourcePure [ ./.gitignore ];
  tools = haskell-tools compiler;
  lib = nixpkgs.pkgsCross.gnu64.haskell.lib;
  myHaskellPackages = nixpkgs.pkgsCross.gnu64.haskell.packages.${compiler}.override {
    overrides = self: super: rec {
      hs-openfaas = lib.dontHaddock (self.callCabal2nix "hs-openfaas" (gitignore ./.) {});
      # Tests for aeson don't work because they should be run as host
      # "Couldn't find a target code interpreter. Try with -fexternal-interpreter"
      aeson = lib.dontCheck super.aeson;
    };
   };
  shell = myHaskellPackages.shellFor {
    packages = p: [
      p.hs-openfaas
    ];
    shellHook = ''
      gen-hie > hie.yaml
      for i in $(find -type f | grep -v dist-newstyle); do krank $i; done

      build() {
          nix-build -A hs-openfaas -o build
          for PACKAGE in packages/*/*/
          do
              rm -rf $PACKAGE/hs-openfaas
              cp build/bin/hs-openfaas $PACKAGE/hs-openfaas
              rm -rf $PACKAGE/*.so*
              cp ${nixpkgs.pkgsCross.gnu64.pkgsHostHost.libffi.outPath}/lib64/libffi.so.8.1.2 $PACKAGE/libffi.so.8
              cp ${nixpkgs.pkgsCross.gnu64.pkgsHostHost.gmp.outPath}/lib/libgmp.so.10.5.0 $PACKAGE/libgmp.so.10
              cp ${nixpkgs.pkgsCross.gnu64.glibc.outPath}/lib/{libc.so.6,libm.so.6,librt.so.1,libdl.so.2,ld-linux-x86-64.so.2} $PACKAGE/
              #x86_64-unknown-linux-gnu-strip $PACKAGE/hs-openfaas
              chmod +w $PACKAGE/*
              patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 $PACKAGE/libc.so.6
          done
      }

      [[ -f packages/hs-openfaas/debug/libc.so.6 ]] || build

      # wget -c https://raw.githubusercontent.com/oufm/packelf/master/packelf.sh
      # chmod +x packelf.sh
      # export GHC=${if builtins.currentSystem == "aarch64-linux" then "x86_64-unknown-linux-ghc" else "ghc"}
    '';
    buildInputs = tools.defaultBuildTools ++ (with nixpkgs; [
        nodejs_20
        closurecompiler
        cabal-install
        pkgsCross.gnu64.pkgsBuildHost.gcc
        pkgsCross.gnu64.pkgsHostHost.gmp
        pkgsCross.gnu64.pkgsHostHost.libffi
        pkgsCross.gnu64.pkgsHostHost.glibc
    ]);
    nativeBuildInputs = tools.defaultBuildTools ++ (with nixpkgs; [
        nodejs_20
        closurecompiler
        cabal-install
        pkgsCross.gnu64.pkgsBuildHost.gcc
        pkgsCross.gnu64.pkgsHostHost.gmp
        pkgsCross.gnu64.pkgsHostHost.libffi
        pkgsCross.gnu64.pkgsHostHost.glibc
    ]);
    withHoogle = false;
  };
  exe = lib.justStaticExecutables (myHaskellPackages.hs-openfaas);
in
{
  inherit shell;
  hs-openfaas = lib.justStaticExecutables (myHaskellPackages.hs-openfaas);
}
