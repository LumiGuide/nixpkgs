{ buildPythonApplication
, daemonize
, dbus-python
, fetchFromGitHub
, fetchpatch
, gobjectIntrospection
, gtk3
, makeWrapper
, pygobject3
, pyudev
, setproctitle
, stdenv
}:

let
  common = import ./common.nix { inherit stdenv fetchFromGitHub; };
in
buildPythonApplication (common // rec {
  pname = "openrazer_daemon";

  sourceRoot = "source/daemon";

  outputs = [ "out" "man" ];

  patches = [
    # https://github.com/openrazer/openrazer/pull/680
    (fetchpatch {
      url = https://github.com/openrazer/openrazer/pull/680/commits/4d7078b6af0cf7de2e4ff0986daff73706ce7eb8.patch;
      sha256 = "0v5bp3zw0csxr5day44gi6b38hm74hipbd7gvvain58b521br5fq";
      stripLen = 1;
    })

    # https://github.com/openrazer/openrazer/pull/681
    (fetchpatch {
      url = https://github.com/openrazer/openrazer/pull/681/commits/feefb86497af6ff7db827e682ae560c12d0aee2f.patch;
      sha256 = "0vfwbdx252lz2v9mswi46jcrzd6pfyyxv1pn21l6a8as9gbakqrm";
      stripLen = 1;
    })
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

  preBuild = ''
    make openrazer-daemon
  '';

  postBuild = ''
    DESTDIR="$out" PREFIX="" make manpages
  '';

  # This fixes problems with gi.require_version('Gdk', '3.0')
  preFixup = ''
    wrapProgram $out/bin/openrazer-daemon \
      --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH" \
      --prefix LD_LIBRARY_PATH ":" "${gtk3.out}/lib"
  '';

  meta.description = "An entirely open source user-space daemon that allows you to manage your Razer peripherals on GNU/Linux";
})
