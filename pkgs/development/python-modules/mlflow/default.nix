{
  lib,
  buildPythonPackage,
  fetchPypi,

  # dependencies
  aiohttp,
  alembic,
  cachetools,
  click,
  cloudpickle,
  cryptography,
  databricks-sdk,
  docker,
  fastapi,
  flask,
  flask-cors,
  gitpython,
  graphene,
  gunicorn,
  huey,
  importlib-metadata,
  matplotlib,
  nixosTests,
  numpy,
  opentelemetry-api,
  opentelemetry-proto,
  opentelemetry-sdk,
  packaging,
  pandas,
  protobuf,
  pyarrow,
  pydantic,
  python-dotenv,
  pyyaml,
  requests,
  scikit-learn,
  scipy,
  skops,
  sqlalchemy,
  sqlparse,
  starlette,
  typing-extensions,
  uvicorn,
}:

buildPythonPackage (finalAttrs: {
  pname = "mlflow";
  version = "3.14.0";
  format = "wheel";
  __structuredAttrs = true;

  # We build from the PyPI wheel rather than fetchFromGitHub, because the mlflow-server
  # JS UI is absent from GitHub but provided in the wheel.
  src = fetchPypi {
    pname = "mlflow";
    inherit (finalAttrs) version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-2/d/fNtbXA7Fm0ZxxhcwsbkUtN/3ookuJnpUfLVFT1Y=";
  };

  # Nix-wrapped python populates sys.path via NIX_PYTHONPATH/site hooks,
  # but PYTHONPATH stays unset in os.environ. mlflow spawns the server
  # in a subprocess with a curated env, so without this patch the child
  # interpreter cannot import uvicorn / mlflow itself.
  postInstall = ''
    patch -p1 -d "$out/lib/python"*/site-packages < ${./subprocess-pythonpath.patch}
  '';

  pythonRelaxDeps = [
    "cryptography"
  ];

  pythonRemoveDeps = [
    "mlflow-skinny"
    "mlflow-tracing"
  ];

  dependencies = [
    aiohttp
    alembic
    cachetools
    click
    cloudpickle
    cryptography
    databricks-sdk
    docker
    fastapi
    flask
    flask-cors
    gitpython
    graphene
    gunicorn
    huey
    importlib-metadata
    matplotlib
    numpy
    opentelemetry-api
    opentelemetry-proto
    opentelemetry-sdk
    packaging
    pandas
    protobuf
    pyarrow
    pydantic
    python-dotenv
    pyyaml
    requests
    scikit-learn
    scipy
    skops
    sqlalchemy
    sqlparse
    starlette
    typing-extensions
    uvicorn
  ];

  pythonImportsCheck = [ "mlflow" ];

  # I (@GaetanLepage) gave up at enabling tests:
  # - They require a lot of dependencies (some unpackaged);
  # - Many errors occur at collection time;
  # - Most (all ?) tests require internet access anyway.
  doCheck = false;

  passthru.tests = { inherit (nixosTests) mlflow; };

  meta = {
    description = "Open source platform for the machine learning lifecycle";
    mainProgram = "mlflow";
    homepage = "https://github.com/mlflow/mlflow";
    changelog = "https://github.com/mlflow/mlflow/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    # Build from wheel which contains pure Python and pre-built JS bundle.
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
    ];
    maintainers = with lib.maintainers; [
      GaetanLepage
    ];
  };
})
