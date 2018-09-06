{ stdenv, buildGoPackage, fetchFromGitHub }:

buildGoPackage rec {
  name = "rclone-${version}";
  version = "1.43";

  goPackagePath = "github.com/ncw/rclone";

  src = fetchFromGitHub {
    owner = "ncw";
    repo = "rclone";
    rev = "v${version}";
    sha256 = "1khg5jsrjmnblv8zg0zqs1n0hmjv05pjj94m9d7jbp9d936lxsxx";
  };

  outputs = [ "bin" "out" "man" ];

  postInstall = ''
    install -D -m644 $src/rclone.1 $man/share/man/man1/rclone.1
  '';

  meta = with stdenv.lib; {
    description = "Command line program to sync files and directories to and from major cloud storage";
    homepage = https://rclone.org;
    license = licenses.mit;
    maintainers = with maintainers; [ danielfullmer ];
    platforms = platforms.all;
  };
}
