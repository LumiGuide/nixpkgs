# The roadwarriors alice and carol set up a connection each to the gateway
# moon. They request a virtual IP. The gateway moon assigns virtual IP addresses
# from a simple pool per roadwarrior containing a single IP address. The
# authentication is based on X.509 certificates. In order to test the tunnel
# alice and carol ping each other.

import ../make-test.nix ({ pkgs, ...} :
let

  # Copied from: https://wiki.strongswan.org/projects/strongswan/wiki/CorrectTrafficDump#Examples
  firewallLoggingCommands = ''
    # ingress IPsec and IKE Traffic rule
    iptables -t filter -I INPUT -p esp -j NFLOG --nflog-group 5
    iptables -t filter -I INPUT -p ah -j NFLOG --nflog-group 5
    iptables -t filter -I INPUT -p udp -m multiport --dports 500,4500 -j NFLOG --nflog-group 5

    # egress IPsec and IKE traffic
    iptables -t filter -I OUTPUT -p esp -j NFLOG --nflog-group 5
    iptables -t filter -I OUTPUT -p ah -j NFLOG --nflog-group 5
    iptables -t filter -I OUTPUT -p udp -m multiport --dports 500,4500 -j NFLOG --nflog-group 5

    # decapsulated IPsec traffic
    iptables -t mangle -I PREROUTING -m policy --pol ipsec --dir in -j NFLOG --nflog-group 5
    iptables -t mangle -I POSTROUTING -m policy --pol ipsec --dir out -j NFLOG --nflog-group 5

    # IPsec traffic that is destinated for the local host (iptables INPUT chain)
    iptables -t filter -I INPUT -m addrtype --dst-type LOCAL -m policy --pol ipsec --dir in -j NFLOG --nflog-group 5

    # IPsec traffic that is destinated for a remote host (iptables FORWARD chain)
    iptables -t filter -I INPUT -m addrtype ! --dst-type LOCAL -m policy --pol ipsec --dir in -j NFLOG --nflog-group 5

    # IPsec traffic that is outgoing (iptables OUTPUT chain)
    iptables -t filter -I OUTPUT -m policy --pol ipsec --dir out -j NFLOG --nflog-group 5
  '';

  ################################################################################
  # Hostnames & IP addresses
  ################################################################################

  moon  = "moon";
  alice = "alice";
  carol = "carol";

  roadwarriors = [ alice carol ];
  hosts = roadwarriors ++ [ moon ];

  vpnIps = {
    alice = "10.0.0.1";
    carol = "10.0.0.2";
  };
  vpnSubnet = "10.0.0.0/24";

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

  ################################################################################
  # Roadwarriors
  ################################################################################

  # This function returns a module for a roadwarrior with the given name.
  roadwarrior = name : {pkgs, config, ...} :
    let strongswan = config.services.strongswan-swanctl.package;
    in {
      imports = [ (etcSwanctlPkiFiles name) ];
      networking = {
        dhcpcd.enable = false;
        #firewall.extraCommands = firewallLoggingCommands;
      };
      environment.systemPackages = [
        strongswan
        pkgs.iptables
        pkgs.tcpdump
        pkgs.tmux
      ];
      services.strongswan-swanctl = {
        enable = true;
        swanctl.connections."${name}" = {
          version = 2;
          remote_addrs = [ moon ];
          vips = [ "0.0.0.0" ];
          local."main" = {
            auth = "pubkey";
            id = name;
            certs = [ "${name}Cert.der" ];
          };
          remote."main" = {
            auth = "pubkey";
            id = moon;
          };
          children."${name}" = {
            start_action = "trap";
            remote_ts = [ vpnSubnet ];
            updown = "${strongswan}/libexec/ipsec/_updown iptables";
          };
        };
      };
    };

  ################################################################################
  # Gateway
  ################################################################################

  # This is the module for the moon gateway.
  gateway = {pkgs, lib, config, ...} :
    let strongswan = config.services.strongswan-swanctl.package;

        # This functions returns the gateway configuration for a roadwarrior
        # with the given name.
        rwConnection = rwName : {
          pools."${rwName}".addrs = vpnIps."${rwName}";
          connections."${rwName}" = {
            version = 2;
            pools = [ rwName ];
            local."main" = {
              auth = "pubkey";
              certs = [ "moonCert.der" ];
              id = moon;
            };
            remote."main" = {
              auth = "pubkey";
              id = rwName;
            };
            children."${rwName}" = {
              local_ts = [ vpnSubnet ];
              updown = "${strongswan}/libexec/ipsec/_updown iptables";
            };
          };
        };
    in {
      imports = [ (etcSwanctlPkiFiles moon) ];
      boot.kernel.sysctl = {
        "net.ipv4.conf.all.forwarding"     = true;
        "net.ipv4.conf.default.forwarding" = true;
      };
      networking = {
        dhcpcd.enable = false;
        firewall = {
          allowedUDPPorts = [ 4500 500 ];
          #extraCommands = firewallLoggingCommands;
        };
      };
      environment.systemPackages = [
        strongswan
        pkgs.iptables
        pkgs.tcpdump
        pkgs.tmux
      ];
      services.strongswan-swanctl = {
        enable = true;
        swanctl = lib.mkMerge (map rwConnection roadwarriors);
      };
    };

################################################################################
# Test
################################################################################
in {
  name = "strongswan-swanctl-pubkey";
  nodes = {
    alice = roadwarrior alice;
    carol = roadwarrior carol;
    moon  = gateway;
  };
  testScript = ''
    startAll();
    $carol->waitUntilSucceeds("ping -c 1 ${vpnIps.alice}");
    $alice->waitUntilSucceeds("ping -c 1 ${vpnIps.carol}");
  '';
})
