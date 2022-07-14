{ options, config, lib, pkgs, ... }:

let
  cfg = config.services.mlflow;

  keyToFlag = k: (if lib.stringLength k == 1 then "-" else "--") + k;

  toFlags = k: v:
    if v == false || v == null then
      ""
    else if v == true then
      keyToFlag k
    else if lib.isList v then
      lib.concatMapStringsSep " " (x: toFlags k x) v
    else
      "${keyToFlag k} ${toString v}";

  flags = lib.concatStringsSep " " (lib.mapAttrsToList toFlags cfg.settings);

  valueType = with lib.types;
    nullOr (oneOf [ bool float int package path port str ]);

  settingsType = with lib.types;
    submodule {
      freeformType = attrsOf (oneOf [ valueType (listOf valueType) ]);
      options = {
        host = lib.mkOption {
          type = str;
          default = "127.0.0.1";
          description = ''
            The IP address the mlflow server should listen on.
          '';
        };

        port = lib.mkOption {
          type = port;
          default = 5000;
          description = ''
            The TCP port the mlflow server should listen on.
          '';
        };

        default-artifact-root = lib.mkOption {
          type = str;
          default = if cfg.settings.serve-artifacts or false then
            "mlflow-artifacts:/"
          else
            "/var/lib/mlflow/mlruns";

          defaultText = lib.literalExpression ''
            if cfg.settings.serve-artifacts or false then
              "mlflow-artifacts:/"
            else
              "/var/lib/mlflow/mlruns"
          '';

          description = ''
            Directory in which to store artifacts for any new experiments
            created. For tracking server backends that rely on SQL, this option
            is required in order to store artifacts.
          '';
        };

        backend-store-uri = lib.mkOption {
          type = str;
          default = "sqlite:////var/lib/mlflow/mlruns.db";
          description = ''
            URI to which to persist experiment and run data.

            Acceptable URIs are SQLAlchemy-compatible database connection
            strings (e.g. 'sqlite:///path/to/file.db') or local filesystem URIs
            (e.g. 'file:///absolute/path/to/directory'). Using a SQL-backed
            store is required for a number of features.
          '';
        };
      };
    };

in {
  options.services.mlflow = with lib; {
    enable = mkEnableOption "the MLflow tracking server";

    settings = mkOption {
      type = settingsType;
      default = { };
      description = ''
        Settings for mlflow server, passed to it as flags.
      '';

      example = literalExpression ''
        {
          serve-artifacts = true;
        }
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.python3.pkgs.mlflow;
      defaultText = "pkgs.python3.pkgs.mlflow";
      description = ''
        The mlflow derivation to use.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.mlflow = {
      wantedBy = [ "multi-user.target" ];
      path = [ cfg.package ];
      serviceConfig = {
        StateDirectory = "mlflow";
        DynamicUser = true;
        WorkingDirectory = "/var/lib/mlflow";
      };

      script = ''
        mlflow server ${flags}
      '';
    };
  };
}
