{ lib, config, ... }:

with lib;

{
  options = {
    selector = mkOption {
      default = _pkgs : [];
      type = types.selectorFunction;
      description = ''
        Some descriptive text
      '';
    };

    result = mkOption {
      type = types.str;
      default = toString (config.selector {
        a = "a";
        b = "b";
        c = "c";
      });
    };
  };

  config = lib.mkMerge [
    { selector = pkgs: [ pkgs.a ]; }
    { selector = pkgs: [ pkgs.b ]; }
  ];
}
