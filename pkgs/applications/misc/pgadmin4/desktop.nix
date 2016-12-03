{ stdenv, fetchurl, qtbase, qtwebkit, qmakeHook, which, python }:
let version = "1.1"; in stdenv.mkDerivation {
  name = "pgadmin4-desktop-${version}";
  src = import ./src.nix fetchurl version;
  buildInputs = [
    qtbase
    qtwebkit
    qmakeHook
    which
    python
  ];
  postPatch = "cd runtime";
  postBuild = "make";
  meta = with stdenv.lib; {
    description = "PostgreSQL administration GUI tool";
    homepage = http://www.pgadmin.org;
    license = licenses.bsd2;
    platforms = platforms.unix;
  };
}
