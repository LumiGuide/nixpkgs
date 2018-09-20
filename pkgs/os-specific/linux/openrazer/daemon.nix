{ buildPythonApplication
, daemonize
, dbus-python
, fetchFromGitHub
, gobjectIntrospection
, gtk3
, makeWrapper
, pygobject3
, pyudev
, setproctitle
, stdenv
}:

let
  openrazerSrc = import ./src.nix;
in
buildPythonApplication rec {
  inherit (openrazerSrc) version;
  pname = "openrazer_daemon";

  outputs = [ "out" "man" ];

  src = fetchFromGitHub openrazerSrc.github;
  sourceRoot = "source/daemon";
  patches = [
    # https://github.com/openrazer/openrazer/pull/681
    ./openrazer_python_daemon_script.patch
    # https://github.com/openrazer/openrazer/pull/680
    ./fix_install_example_config_file.patch
  ];

  buildInputs = [ makeWrapper ];

  propagatedBuildInputs = [
    daemonize
    dbus-python
    gobjectIntrospection
    gtk3
    pygobject3
    pyudev
    setproctitle
  ];

  postBuild = ''
    DESTDIR="$out" PREFIX="" make manpages
  '';

  postInstall = ''
    mv $out/bin/run_openrazer_daemon.py $out/bin/openrazer-daemon
  '';

  # This fixes problems with gi.require_version('Gdk', '3.0')
  preFixup = ''
    wrapProgram $out/bin/openrazer-daemon \
      --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH" \
      --prefix LD_LIBRARY_PATH ":" "${gtk3.out}/lib"
  '';

  meta = with stdenv.lib; {
    description = "An entirely open source driver and user-space daemon that allows you to manage your Razer peripherals on GNU/Linux";
    homepage = https://openrazer.github.io/;
    license = licenses.gpl2;
    maintainers = with maintainers; [ roelvandijk ];
    platforms = platforms.linux;
  };
}
