# The roadwarrior carol sets up a connection to gateway moon. The authentication
# is based on pre-shared keys and IPv4 addresses. Upon the successful
# establishment of the IPsec tunnels, the specified updown script automatically
# inserts iptables-based firewall rules that let pass the tunneled traffic. In
# order to test both tunnel and firewall, carol pings the client alice behind
# the gateway moon.
#
#     alice                       moon                        carol
#      eth1------vlan_0------eth1        eth2------vlan_1------eth1
#   192.168.0.1         192.168.0.3  192.168.1.3           192.168.1.2
#
# See the NixOS manual for how to run this test:
# https://nixos.org/nixos/manual/index.html#sec-running-nixos-tests-interactively

import ../make-test.nix ({ pkgs, ...} :

let
  ifAddr = node: iface: (pkgs.lib.head node.config.networking.interfaces.${iface}.ip4).address;

  moon  = "moon";
  carol = "carol";
  hosts = [ moon carol ];

  allowESP = "iptables --insert INPUT --protocol ESP --jump ACCEPT";

  # Shared VPN settings:
  vlan0   = "192.168.0.0/24";
  version = 2;

  ################################################################################
  # PKI keys & certificates
  ################################################################################

  buildInputs = [ pkgs.strongswan ];

  caPrivKey = mkPrivKey "ca";

  mkPrivKey = name : pkgs.runCommand "${name}PrivKey.der"
    {inherit buildInputs;}
    ''pki --gen > $out'';

  caCert = pkgs.runCommand "caCert.der"
    {inherit buildInputs; inherit caPrivKey;}
    ''pki --self --in $caPrivKey --dn "C=CH, O=strongSwan, CN=strongSwan CA" --ca > $out'';

  mkPubKey = name : pkgs.runCommand "${name}PubKey.der"
    {inherit buildInputs; privKey = privKeys."${name}";}
    ''pki --pub --in $privKey > $out'';

  mkCert = name : pkgs.runCommand "${name}Cert.der"
    {inherit buildInputs; inherit caCert; inherit caPrivKey; pubKey = pubKeys."${name}"; cn = name;}
    ''pki --issue --in $pubKey --cacert $caCert --cakey $caPrivKey \
        --dn "C=CH, O=strongSwan, CN=$cn" --san $cn > $out'';

  privKeys = pkgs.lib.genAttrs hosts mkPrivKey;
  pubKeys  = pkgs.lib.genAttrs hosts mkPubKey;
  certs    = pkgs.lib.genAttrs hosts mkCert;

  # This function returns a module that installs the private key, certificate
  # and CA certificate for the given name.
  etcSwanctlPkiFiles = name : {
    environment.etc = {
      "swanctl/rsa/${name}PrivKey.der" = {source = privKeys."${name}"; mode = "400";};
      "swanctl/x509/${name}Cert.der"   = {source = certs."${name}";    mode = "400";};
      "swanctl/x509ca/caCert.der"      = {source = caCert;             mode = "400";};
    };
  };

in {
  name = "strongswan-swanctl";
  meta.maintainers = with pkgs.stdenv.lib.maintainers; [ basvandijk ];
  nodes = {

    alice = { nodes, ... } : {
      virtualisation.vlans = [ 0 ];
      networking = {
        dhcpcd.enable = false;
        defaultGateway = ifAddr nodes.moon "eth1";
      };
    };

    moon = {pkgs, config, nodes, ...} :
      let
        moonIp  = ifAddr nodes.moon  "eth2";
        strongswan = config.services.strongswan-swanctl.package;
      in {
        virtualisation.vlans = [ 0 1 ];
        networking = {
          dhcpcd.enable = false;
          firewall = {
            allowedUDPPorts = [ 4500 500 ];
            extraCommands = allowESP;
          };
          nat = {
            enable             = true;
            internalIPs        = [ vlan0 ];
            internalInterfaces = [ "eth1" ];
            externalIP         = moonIp;
            externalInterface  = "eth2";
          };
        };
        environment.systemPackages = [ strongswan ];
        imports = [ (etcSwanctlPkiFiles moon) ];
        services.strongswan-swanctl = {
          enable = true;
          swanctl = {
            pools."carol".addrs = "10.0.0.1";
            connections = {
              "carol" = {
                inherit version;
                local_addrs = [ moonIp ];
                pools = [ carol ];
                local."main" = {
                  auth = "pubkey";
                  certs = [ "moonCert.der" ];
                  id = moon;
                };
                remote."main" = {
                  auth = "pubkey";
                  id = carol;
                };
                children = {
                  "carol" = {
                    local_ts = [ vlan0 ];
                    updown = "${strongswan}/libexec/ipsec/_updown iptables";
                  };
                };
              };
            };
          };
        };
      };

    carol = {pkgs, config, nodes, ...} :
      let
        moonIp  = ifAddr nodes.moon "eth2";
        strongswan = config.services.strongswan-swanctl.package;
      in {
        virtualisation.vlans = [ 1 ];
        networking = {
          dhcpcd.enable = false;
          firewall.extraCommands = allowESP;
        };
        environment.systemPackages = [ strongswan ];
        imports = [ (etcSwanctlPkiFiles carol) ];
        services.strongswan-swanctl = {
          enable = true;
          swanctl = {
            connections."carol" = {
              inherit version;
              remote_addrs = [ moonIp ];
              vips = [ "0.0.0.0" ];
              local."main" = {
                auth = "pubkey";
                id = carol;
                certs = [ "carolCert.der" ];
              };
              remote."main" = {
                auth = "pubkey";
                id = moon;
              };
              children ."carol" = {
                remote_ts = [ vlan0 ];
                start_action = "trap";
                updown = "${strongswan}/libexec/ipsec/_updown iptables";
              };
            };
          };
        };
      };

  };
  testScript = ''
    startAll();
    $carol->waitUntilSucceeds("ping -c 1 alice");
  '';
})
