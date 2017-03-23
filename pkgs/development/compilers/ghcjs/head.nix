{ fetchgit, fetchFromGitHub, bootPkgs }:

bootPkgs.callPackage ./base.nix {
  version = "0.2.020170323";

  # deprecated on HEAD, directly included in the distribution
  ghcjs-prim = null;
  inherit bootPkgs;

  ghcjsSrc = fetchFromGitHub {
    owner = "ghcjs";
    repo = "ghcjs";
    rev = "2dc14802e78d7d9dfa35395d5dbfc9c708fb83e6";
    sha256 = "0cvmapbrwg0h1pbz648isc2l84z694ylnfm8ncd1g4as28lmj0pz";
  };
  ghcjsBootSrc = fetchgit {
    # TODO: switch back to git://github.com/ghcjs/ghcjs-boot.git
    # when https://github.com/ghcjs/ghcjs-boot/pull/41 is merged.
    url = git://github.com/basvandijk/ghcjs-boot.git;
    rev = "0159c4d866e095cf7474e2d3587f5debf66aa1f8";
    sha256 = "0lccjd88x32g6gsbivjg4jrsk7xm5g6wsn2m97x67p1xj93fda14";
    fetchSubmodules = true;
  };

  shims = import ./head_shims.nix { inherit fetchFromGitHub; };
  stage1Packages = [
    "array"
    "base"
    "binary"
    "bytestring"
    "containers"
    "deepseq"
    "directory"
    "filepath"
    "ghc-boot"
    "ghc-boot-th"
    "ghc-prim"
    "ghci"
    "ghcjs-prim"
    "ghcjs-th"
    "integer-gmp"
    "pretty"
    "primitive"
    "process"
    "rts"
    "template-haskell"
    "time"
    "transformers"
    "unix"
  ];
  stage2 = import ./head_stage2.nix;
}
