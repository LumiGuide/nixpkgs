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
, pythonRelaxDepsHook
, pytz
, pyyaml
, querystring_parser
, requests
, scikit-learn
, scipy
, shap
, simplejson
, sqlalchemy
, sqlparse
}:

buildPythonPackage rec {
  pname = "mlflow";
  version = "2.2.2";
  format = "setuptools";

  disabled = pythonOlder "3.8";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-PvLC7iDJp63t/zTnVsbtrGLPTZBXZa0OgHS8naoMWAw";
  };

  # Remove currently broken dependency `shap`, a model explainability package.
  # This seems quite unprincipled especially with tests not being enabled,
  # but not mlflow has a 'skinny' install option which does not require `shap`.
  nativeBuildInputs = [ pythonRelaxDepsHook ];
  pythonRemoveDeps = [ "shap" ];
  pythonRelaxDeps = [ "pytz" ];

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
    pytz
    pyyaml
    querystring_parser
    requests
    scikit-learn
    scipy
    shap
    simplejson
    sqlalchemy
    sqlparse
  ];

  pythonImportsCheck = [
    "mlflow"
  ];

  # no tests in PyPI dist
  # run into https://stackoverflow.com/questions/51203641/attributeerror-module-alembic-context-has-no-attribute-config
  # also, tests use conda so can't run on NixOS without buildFHSUserEnv
  doCheck = false;

  passthru.tests = { inherit (nixosTests) mlflow; };

  meta = with lib; {
    description = "Open source platform for the machine learning lifecycle";
    homepage = "https://github.com/mlflow/mlflow";
    license = licenses.asl20;
    maintainers = with maintainers; [ tbenst ];
  };
}
