{ stdenv, fetchFromGitHub, runCommand, postgresql, openssl } :

stdenv.mkDerivation rec {
  name = "postage-${version}";
  version = "HEAD";

  src = fetchFromGitHub {
    owner  = "workflowproducts";
    repo   = "postage";
    rev    = "6459cc783976c32207685819b38b4c1b00fd87fb";
    sha256 = "1gw66a05kc24jr1q7zcazzh21n2gq1zfcykydj70nc38377xic6q";
  };

  buildInputs = [ postgresql openssl ];
}
