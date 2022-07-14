import ./make-test-python.nix ({ lib, ... }: {
  name = "mlflow";

  nodes.machine = { ... }: {
    services.mlflow.enable = true;
    virtualisation.memorySize = 2048;
  };

  testScript = ''
    with subtest("Web interface gets ready"):
        machine.wait_for_unit("mlflow.service")
        # Wait until server accepts connections
        machine.wait_until_succeeds("curl -fs localhost:5000")
  '';
})
