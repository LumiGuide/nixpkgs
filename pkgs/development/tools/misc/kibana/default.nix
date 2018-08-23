{ elk6Version
, enableUnfree ? true
, stdenv
, makeWrapper
, fetchzip
, fetchurl
, nodejs
, coreutils
, which
}:

with stdenv.lib;
let
  inherit (builtins) elemAt;
  info = splitString "-" stdenv.system;
  arch = elemAt info 0;
  plat = elemAt info 1;
  shas =
    if enableUnfree
    then {
      "x86_64-linux"  = "1vlasy960qfd7jxc3vzil0lk99ajl44yvjprmnhhdhh8b885c86z";
      "x86_64-darwin" = "075i6wpwq6ik7mdx14xcz9sxnql1rjflgbrcm2kad3y767y79c5b";
    }
    else {
      "x86_64-linux"  = "1x4n8cxd7x200gv3181fa8c4zjc5n3qkp1rhmc2dm3gfhsmjr0qj";
      "x86_64-darwin" = "1ixci00aqyh2c93k5mm2pdivzyxjhyrf37dv9gx8bffc6ba8fd20";
    };

  # For the correct phantomjs version see:
  # https://github.com/elastic/kibana/blob/master/x-pack/plugins/reporting/server/browsers/phantom/paths.js
  phantomjs = rec {
    name = "phantomjs-${version}-linux-x86_64";
    version = "2.1.1";
    src = fetchzip {
      inherit name;
      url = "https://github.com/Medium/phantomjs/releases/download/v${version}/${name}.tar.bz2";
      sha256 = "0g2dqjzr2daz6rkd6shj6rrlw55z4167vqh7bxadl8jl6jk7zbfv";
    };
  };

in stdenv.mkDerivation rec {
  name = "kibana-${optionalString (!enableUnfree) "oss-"}${version}";
  version = elk6Version;

  src = fetchurl {
    url = "https://artifacts.elastic.co/downloads/kibana/${name}-${plat}-${arch}.tar.gz";
    sha256 = shas."${stdenv.system}" or (throw "Unknown architecture");
  };

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/libexec/kibana $out/bin
    mv * $out/libexec/kibana/
    rm -r $out/libexec/kibana/node
    makeWrapper $out/libexec/kibana/bin/kibana $out/bin/kibana \
      --prefix PATH : "${stdenv.lib.makeBinPath [ nodejs coreutils which ]}"
    sed -i 's@NODE=.*@NODE=${nodejs}/bin/node@' $out/libexec/kibana/bin/kibana
  '' +
  # phantomjs is needed in the unfree version. When phantomjs doesn't exist in
  # $out/libexec/kibana/data kibana will try to download and unpack it during
  # runtime which will fail because the nix store is read-only. So we make sure
  # it already exist in the nix store.
  optionalString enableUnfree ''
    ln -s ${phantomjs.src} $out/libexec/kibana/data/${phantomjs.name}
  '';

  meta = {
    description = "Visualize logs and time-stamped data";
    homepage = http://www.elasticsearch.org/overview/kibana;
    license = if enableUnfree then licenses.elastic else licenses.asl20;
    maintainers = with maintainers; [ offline rickynils basvandijk ];
    platforms = with platforms; unix;
  };
}
