{ callPackage, lib, path, fetchFromGitHub }:

let
  rev = "af5d021ddbb8817922f572127a67907261ff362b";

  src = fetchFromGitHub {
    owner = "LumiGuide";
    repo  = "nixops";
    inherit rev;
    sha256 = "0bzmb13czw4hm5k16085jl6ch3fhlxnnqv8z0c0n5p9gn5bf6gg4";
  };

  nixopsSrc = {
    outPath = src;
    revCount = 0;
    shortRev = lib.substring 0 6 rev;
    inherit rev;
  };

  officialRelease = false;

  release = import (src + "/release.nix") {
    inherit nixopsSrc;
    inherit officialRelease;
    nixpkgs = path;
  };

  version = "1.6" + (
    if officialRelease
    then ""
    else "pre${toString nixopsSrc.revCount}_${nixopsSrc.shortRev}"
  );

  releaseName = "nixops-${version}";

in callPackage ./generic.nix {
  inherit version;
  src = release.tarball + "/tarballs/${releaseName}.tar.bz2";
}
