{ stdenv
, fetchurl
, gcc-unwrapped
, dpkg
, polkit
, utillinux
, bash
, makeWrapper
, electron_9
}:

let
  sha256 = {
    "x86_64-linux" = "1mibqr6zldbbsnzslyhigwgi2pd81jhx74xw8z3bpr86xvbszp64";
    "i686-linux" = "0jb7brka55day4m6m0srpbg6l4hl5dzn7210cyw4a17xwg6kg8jk";
  }."${stdenv.system}";

  arch = {
    "x86_64-linux" = "amd64";
    "i686-linux" = "i386";
  }."${stdenv.system}";

  electron = electron_9;

in

stdenv.mkDerivation rec {
  pname = "etcher";
  version = "1.5.116";

  src = fetchurl {
    url = "https://github.com/balena-io/etcher/releases/download/v${version}/balena-etcher-electron_${version}_${arch}.deb";
    inherit sha256;
  };

  dontBuild = true;
  dontConfigure = true;

  nativeBuildInputs = [ makeWrapper ];

  unpackPhase = ''
    ${dpkg}/bin/dpkg-deb -x $src .
  '';

  # sudo-prompt has hardcoded binary paths on Linux and we patch them here
  # along with some other paths
  patchPhase = ''
    pushd opt/balenaEtcher/resources/app
    # use Nix(OS) paths
    sed -i 's|/usr/bin/pkexec|/usr/bin/pkexec", "/run/wrappers/bin/pkexec|' generated/gui.js
    sed -i 's|/bin/bash|${bash}/bin/bash|' generated/gui.js
    sed -i 's|"lsblk"|"${utillinux}/bin/lsblk"|' generated/gui.js
    sed -i "s|process.resourcesPath|'$out/share/${pname}/resources/'|" generated/gui.js
    popd
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/${pname}

    cp -a usr/share/* $out/share
    cp -a opt/balenaEtcher/{locales,resources} $out/share/${pname}

    substituteInPlace $out/share/applications/balena-etcher-electron.desktop \
      --replace 'Exec=/opt/balenaEtcher/balena-etcher-electron' 'Exec=${pname}'

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper ${electron}/bin/electron $out/bin/${pname} \
      --add-flags $out/share/${pname}/resources/app \
      --prefix LD_LIBRARY_PATH : "${stdenv.lib.makeLibraryPath [ gcc-unwrapped.lib ]}"
  '';

  meta = with stdenv.lib; {
    description = "Flash OS images to SD cards and USB drives, safely and easily";
    homepage = "https://etcher.io/";
    license = licenses.asl20;
    maintainers = [ maintainers.shou ];
    platforms = [ "i686-linux" "x86_64-linux" ];
  };
}
