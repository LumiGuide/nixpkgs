import ./make-test.nix (
{ pkgs
, system ? builtins.currentSystem
, minimal ? false
, config ? {}
, ...
} :

let
  oldPkgs = import (builtins.fetchTarball
    https://github.com/NixOS/nixpkgs/archive/a2845aa0.tar.gz) {
  };

in

with import (oldPkgs.path + "/nixos/lib/build-vms.nix") { inherit system minimal config; };

let
  newNet = buildVirtualNetwork {
    new = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.hello ];
    };
  };

  new = newNet.new.config.system.build.toplevel;
in

{
  name = "nixos-rebuild";
  meta = {
    maintainers = with pkgs.stdenv.lib.maintainers;
      [ basvandijk ];
  };

  nodes = {
    machine =
      { pkgs, config, ... }: {
        environment.systemPackages = [
          (pkgs.writeScriptBin "activate-new" ''
            #!/bin/sh
            ${new}/activate
          '')
        ];
      };
    };

  testScript = ''
    startAll;
    $machine->fail("hello");
    $machine->succeed("activate-new");
    $machine->succeed("hello");
  '';
})
