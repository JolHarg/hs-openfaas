{
  nixpkgs ? import <nixpkgs> {},
  haskell-tools ? import (builtins.fetchTarball "https://github.com/danwdart/haskell-tools/archive/master.tar.gz") {
    nixpkgs = nixpkgs;
    compiler = compiler;
  },
  compiler ? "ghc94"
}:
let
  pkgsToUse = if builtins.currentSystem == "x86_64-linux" then nixpkgs else nixpkgs.pkgsCross.gnu64;
  gitignore = nixpkgs.nix-gitignore.gitignoreSourcePure [ ./.gitignore ];
  tools = haskell-tools compiler;
  lib = pkgsToUse.pkgsBuildHost.haskell.lib;
  myHaskellPackages = pkgsToUse.pkgsBuildHost.haskell.packages.${compiler}.override {
    overrides = self: super: rec {
      openfaas = lib.dontHaddock (self.callCabal2nix "openfaas" (gitignore ./.) {});
      # Tests for aeson don't work because they should be run as host
      # "Couldn't find a target code interpreter. Try with -fexternal-interpreter"
      aeson = lib.dontCheck super.aeson;
    };
   };
  shell = myHaskellPackages.shellFor {
    packages = p: [
      p.openfaas
    ];
    shellHook = ''
      gen-hie > hie.yaml
      for i in $(find -type f | grep -v dist-newstyle); do krank $i; done

      build() {
          nix-build -A openfaas -o build
          for PACKAGE in packages/*/*/
          do
              rm -rf $PACKAGE/openfaas
              cp build/bin/openfaas $PACKAGE/openfaas
              rm -rf $PACKAGE/*.so*
              cp ${pkgsToUse.pkgsHostHost.libffi.outPath}/lib64/libffi.so.8.1.2 $PACKAGE/libffi.so.8
              cp ${pkgsToUse.pkgsHostHost.gmp.outPath}/lib/libgmp.so.10.5.0 $PACKAGE/libgmp.so.10
              cp ${pkgsToUse.pkgsHostHost.glibc.outPath}/lib/{libc.so.6,libm.so.6,librt.so.1,libdl.so.2,ld-linux-x86-64.so.2} $PACKAGE/
              #x86_64-unknown-linux-gnu-strip $PACKAGE/openfaas
              chmod +w $PACKAGE/*
              patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 $PACKAGE/libc.so.6
          done
      }

      [[ -f packages/openfaas/debug/libc.so.6 ]] || build

      # wget -c https://raw.githubusercontent.com/oufm/packelf/master/packelf.sh
      # chmod +x packelf.sh
      # export GHC=${if builtins.currentSystem == "aarch64-linux" then "x86_64-unknown-linux-ghc" else "ghc"}
    '';
    buildInputs = tools.defaultBuildTools ++ (with nixpkgs; [
        nodejs_20
        closurecompiler
        cabal-install
        pkgsToUse.pkgsBuildHost.gcc
        pkgsToUse.pkgsHostHost.gmp
        pkgsToUse.pkgsHostHost.libffi
        pkgsToUse.pkgsHostHost.glibc
    ]);
    nativeBuildInputs = tools.defaultBuildTools ++ (with nixpkgs; [
        nodejs_20
        closurecompiler
        cabal-install
        pkgsToUse.pkgsBuildHost.gcc
        pkgsToUse.pkgsHostHost.gmp
        pkgsToUse.pkgsHostHost.libffi
        pkgsToUse.pkgsHostHost.glibc
    ]);
    withHoogle = false;
  };
  exe = lib.justStaticExecutables (myHaskellPackages.openfaas);
in
{
  inherit shell;
  openfaas = lib.justStaticExecutables (myHaskellPackages.openfaas);
}
