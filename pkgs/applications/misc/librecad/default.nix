{ stdenv
, fetchFromGitHub
, makeWrapper
, qmake
, qtbase
, qtsvg
, muparser
, which
, boost
, pkgconfig
}:

stdenv.mkDerivation rec {
  version = "2.2.0-rc1";
  name = "librecad-${version}";

  src = fetchFromGitHub {
    owner = "LibreCAD";
    repo = "LibreCAD";
    rev = version;
    sha256 = "0kwj838hqzbw95gl4x6scli9gj3gs72hdmrrkzwq5rjxam18k3f3";
  };

  patchPhase = ''
    sed -i -e s,/bin/bash,`type -P bash`, scripts/postprocess-unix.sh
    sed -i -e s,/usr/share,$out/share, librecad/src/lib/engine/rs_system.cpp
  '';

  qmakeFlags = [ "MUPARSER_DIR=${muparser}" "BOOST_DIR=${boost.dev}" ];

  installPhase = ''
    mkdir -p $out/bin $out/share
    cp -R unix/librecad $out/bin
    cp -R unix/resources $out/share/librecad
  '';

  buildInputs = [ qtbase qtsvg muparser which boost ];
  nativeBuildInputs = [ makeWrapper pkgconfig qmake ];
  enableParallelBuilding = true;

  meta = {
    description = "A 2D CAD package based upon Qt";
    homepage = http://librecad.org;
    repositories.git = git://github.com/LibreCAD/LibreCAD.git;
    license = stdenv.lib.licenses.gpl2;
    maintainers = with stdenv.lib.maintainers; [viric];
    platforms = with stdenv.lib.platforms; linux;
  };
}
