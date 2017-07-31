{ stdenv, fetchFromGitHub, runCommand, postgresql, openssl } :

stdenv.mkDerivation rec {
  name = "postage-${version}";
  version = "2017-07-31";

  src = fetchFromGitHub {
    owner  = "workflowproducts";
    repo   = "postage";
    rev    = "ff92c5cddaaa50d85a58fe9a54e241371fcaf5ea";
    sha256 = "0m9ddqidf2sxwhidr0dl79jx3cxs2cr79zxrjg820nzhh7qlv4rq";
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
