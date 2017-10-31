  # Upgrading? We have a test! nix-build ./nixos/tests/wordpress.nix
{ fetchFromGitHub, lib } : fetchFromGitHub {
  owner = "WordPress";
  repo = "WordPress";
  rev = "4.8.2";
  sha256 = "1bgj5zj50vcph0m8h6gzc7gphnp6qkfz5fgcrinji08dbbmqhfr3";
  meta = {
    homepage = https://wordpress.org;
    description = "WordPress is open source software you can use to create a beautiful website, blog, or app.";
    license = lib.licenses.gpl2;
    maintainers = [ lib.maintainers.basvandijk ];
  };
}
