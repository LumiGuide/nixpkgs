{ stdenv, fetchFromGitHub, runCommand, postgresql, openssl } :

stdenv.mkDerivation rec {
  name = "postage-${version}";
  version = "2017-07-31";

  src = fetchFromGitHub {
    owner  = "workflowproducts";
    repo   = "postage";
    rev    = "f34afefc6154efc21cea6a7904e7fd66bc2ed91e";
    sha256 = "10s495198flxi4dslgl9gmbginhpbsihnx953yffnh9m9l8f2m3j";
  };

  buildInputs = [ postgresql openssl ];

  meta = with stdenv.lib; {
    description = "A fast replacement for PGAdmin";
    longDescription = ''
      At the heart of Postage is a modern, fast, event-based C-binary, built in
      the style of NGINX and Node.js. This heart makes Postage as fast as any
      PostgreSQL interface can hope to be.
    '';
    homepage = http://www.workflowproducts.com/postage.html;
    license = licenses.asl20;
    maintainers = [ maintainers.basvandijk ];
  };
}
