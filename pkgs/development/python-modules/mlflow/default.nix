{ lib
, alembic
, buildPythonPackage
, click
, cloudpickle
, databricks-cli
, docker
, entrypoints
, fetchpatch
, fetchPypi
, flask
, GitPython
, gorilla
, gunicorn
, importlib-metadata
, markdown
, matplotlib
, nixosTests
, numpy
, packaging
, pandas
, prometheus-flask-exporter
, protobuf
, pyarrow
, python-dateutil
, pythonOlder
, pyyaml
, querystring_parser
, requests
, scikit-learn
, scipy
, shap
, simplejson
, six
, sqlalchemy
, sqlparse
}:

buildPythonPackage rec {
  pname = "mlflow";
  version = "2.1.1";
  format = "setuptools";

  disabled = pythonOlder "3.8";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-oRazzUW7+1CaFyO/1DiL21ZqPlBF483lOQ5mf1kUmKY=";
  };

  propagatedBuildInputs = [
    alembic
    click
    cloudpickle
    databricks-cli
    docker
    entrypoints
    flask
    GitPython
    gorilla
    gunicorn
    importlib-metadata
    markdown
    matplotlib
    numpy
    packaging
    pandas
    prometheus-flask-exporter
    protobuf
    pyarrow
    python-dateutil
    pyyaml
    querystring_parser
    requests
    scikit-learn
    scipy
    shap
    simplejson
    six
    sqlalchemy
    sqlparse
  ];

  pythonImportsCheck = [
    "mlflow"
  ];

  # Some mlflow subcommands like `mlflow server` run the gunicorn binary which
  # in turn attempts to find the mlflow package again. Gunicorn does not have
  # mlflow in its closure and won't find it unless we expose it here.
  makeWrapperArgs = ''--prefix PYTHONPATH ":" "$PYTHONPATH"'';

  # run into https://stackoverflow.com/questions/51203641/attributeerror-module-alembic-context-has-no-attribute-config
  # also, tests use conda so can't run on NixOS without buildFHSUserEnv
  doCheck = false;

  passthru.tests = { inherit (nixosTests) mlflow; };

  meta = with lib; {
    description = "Open source platform for the machine learning lifecycle";
    homepage = "https://github.com/mlflow/mlflow";
    license = licenses.asl20;
    maintainers = with maintainers; [ tbenst ];
    knownVulnerabilities = [
      "CVE-2023-1176"
      "CVE-2023-1177"
    ];
  };
}
