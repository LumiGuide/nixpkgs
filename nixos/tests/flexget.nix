import ./make-test.nix ({ ... }:
{
  name = "flexget";

  machine = {
    services.flexget.enable = true;
  };

  testScript = ''
    $machine->start;
    $machine->waitForUnit("flexget.service");
    $machine->waitForUnit("flexget-runner.service");
  '';
})
