{ pkgs,  stdenv, fetchurl, unzip, elasticsearch-oss, javaPackages, elk6Version }:

with pkgs.lib;

let
  esPlugin = a@{
    pluginName,
    installPhase ? ''
      mkdir -p $out/config
      mkdir -p $out/plugins
      ES_HOME=$out ${elasticsearch-oss}/bin/elasticsearch-plugin install --batch -v file://$src
    '',
    ...
  }:
    stdenv.mkDerivation (a // {
      inherit installPhase;
      unpackPhase = "true";
      buildInputs = [ unzip ];
      meta = a.meta // {
        platforms = elasticsearch-oss.meta.platforms;
        maintainers = (a.meta.maintainers or []) ++ [ maintainers.offline ];
      };
    });
in {

  elasticsearch_analysis_lemmagen = esPlugin rec {
    name = "elasticsearch-analysis-lemmagen-${version}";
    pluginName = "elasticsearch-analysis-lemmagen";
    version = "6.3.2"; # TODO: replace with elk6Version once the versions match up.
    src = fetchurl {
      url = "https://github.com/vhyza/elasticsearch-analysis-lemmagen/releases/download/v${version}/${name}-plugin.zip";
      sha256 = "1m4z05wixjrq4nlbdjyhvprkrwxjym8aba18scmzfn25fhbjgvkz";
    };
    meta = {
      homepage = https://github.com/vhyza/elasticsearch-analysis-lemmagen;
      description = "LemmaGen Analysis plugin provides jLemmaGen lemmatizer as Elasticsearch token filter";
      license = licenses.asl20;
    };
  };

  discovery-ec2 = esPlugin {
    name = "elasticsearch-discovery-ec2-${version}";
    pluginName = "discovery-ec2";
    version = elk6Version;
    src = pkgs.fetchurl {
      url = "https://artifacts.elastic.co/downloads/elasticsearch-plugins/discovery-ec2/discovery-ec2-${elk6Version}.zip";
      sha256 = "1hd1b9w9z405p44i6zxfq5z0mdnxkjsdiikzkcq7b2qgaj3jyz7j";
    };
    meta = {
      homepage = https://github.com/elastic/elasticsearch/tree/master/plugins/discovery-ec2;
      description = "The EC2 discovery plugin uses the AWS API for unicast discovery.";
      license = licenses.asl20;
    };
  };

  search_guard = esPlugin rec {
    name = "elastic-search-guard-${version}";
    pluginName = "search-guard";
    version = "6.3.2-22.3"; # TODO: replace the first version component with "${elk6Version}" once the versions match up.
    src = fetchurl rec {
      url = "mirror://maven/com/floragunn/search-guard-6/${version}/search-guard-6-${version}.zip";
      sha256 = "1r71h4h9bmxak1mq5gpm19xq5ji1gry1kp3sjmm8azy4ykdqdncx";
    };
    meta = {
      homepage = https://github.com/floragunncom/search-guard;
      description = "Plugin to fetch data from JDBC sources for indexing into Elasticsearch";
      license = licenses.asl20;
    };
  };
}
