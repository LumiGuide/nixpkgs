{ stdenv
, fetchFromGitHub
, qmake
, librsvg
, muparser
, which
, boost
, pkgconfig
, qtbase
, qtsvg
, qttools
, freetype
}:

stdenv.mkDerivation rec {
  version = "2.1.3";
  name = "librecad-${version}";

  src = fetchFromGitHub {
    owner = "LibreCAD";
    repo = "LibreCAD";
    rev = "71f64ff56ace31cc0a83accfa40328c8795bcdba";
    sha256 = "16liy01s4nijn4s2y5fb6x5gfmh04d6yc38ldlwxb97swasin7dj";
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

  buildInputs = [ muparser which boost qtbase qtsvg qttools librsvg freetype ];
  nativeBuildInputs = [ pkgconfig qmake ];

  enableParallelBuilding = true;

  meta = {
    description = "A 2D CAD package based upon Qt";
    homepage = https://librecad.org;
    repositories.git = git://github.com/LibreCAD/LibreCAD.git;
    license = stdenv.lib.licenses.gpl2;
    maintainers = with stdenv.lib.maintainers; [viric];
    platforms = with stdenv.lib.platforms; linux;
  };
}
