{ config, lib, pkgs, serverInfo, php, ... }:
# http://codex.wordpress.org/Hardening_WordPress

with lib;

let

  version = "4.4.2";
  fullversion = "${version}";

  # Our bare-bones wp-config.php file using the above settings
  wordpressConfig = pkgs.writeText "wp-config.php" ''
    <?php
    define('DB_NAME',     '${config.dbName}');
    define('DB_USER',     '${config.dbUser}');
    define('DB_PASSWORD', '${config.dbPassword}');
    define('DB_HOST',     '${config.dbHost}');
    define('DB_CHARSET',  'utf8');
    $table_prefix  = '${config.tablePrefix}';
    ${config.extraConfig}
    if ( !defined('ABSPATH') )
    	define('ABSPATH', dirname(__FILE__) . '/');
    require_once(ABSPATH . 'wp-settings.php');
  '';

  # .htaccess to support pretty URLs
  htaccess = pkgs.writeText "htaccess" ''
    <IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /
    RewriteRule ^index\.php$ - [L]

    # add a trailing slash to /wp-admin
    RewriteRule ^wp-admin$ wp-admin/ [R=301,L]

    RewriteCond %{REQUEST_FILENAME} -f [OR]
    RewriteCond %{REQUEST_FILENAME} -d
    RewriteRule ^ - [L]
    RewriteRule ^(wp-(content|admin|includes).*) $1 [L]
    RewriteRule ^(.*\.php)$ $1 [L]
    RewriteRule . index.php [L]
    </IfModule>

    ${config.extraHtaccess}
  '';

  # WP translation can be found here:
  #   https://github.com/nixcloud/wordpress-translations
  supportedLanguages = {
    en_GB = { revision="7de394e1341ab74c6f6626af5cebe7c30e653c79"; sha256="014qk8zcnkw7v3cs96pyxq41sb5ragbq2hhazrfd7jry5j9v56vp"; };
    de_DE = { revision="4f880c8f608c2d2123a2b8d70979dd8832d3f776"; sha256="0di5q0pa9w4qkgzf9d8j4gm4mdkal7gd7cb91jcyjkcc3mqbi813"; };
    zh_CN = { revision="86880820d2b9ec13ec3140e8494bd62be2bb6edb"; sha256="00rh4igjqrrhwn94lg5h38n1j278byzg9scb451kn6ixm3l7vg6h"; };
    fr_FR = { revision="22667a45cf44864f2c877d71e6db0cbc52d384d9"; sha256="1ynnflajia2pg2gd7p7ssqjyz3wcj5dnf3sr94p0d9jx18nh806p"; };
    nl_NL = { revision="ca146592f687a27493202292cfe735c839dcf4a2"; sha256="0xvysgxd8a3bpbq07l4wcx24lry0lg5rx0rd6r0my2clhm0fjxcl"; };
  };

  downloadLanguagePack = language: revision: sha256s:
    pkgs.stdenv.mkDerivation rec {
      name = "wp_${language}";
      src = pkgs.fetchFromGitHub {
        owner = "nixcloud";
        repo = "wordpress-translations";
        rev = revision;
        sha256 = sha256s;
      };
      installPhase = "mkdir -p $out; cp -R * $out/";
    };

  selectedLanguages = map (lang: downloadLanguagePack lang supportedLanguages.${lang}.revision supportedLanguages.${lang}.sha256) (config.languages);

  # The wordpress package itself
  wordpressRoot = pkgs.stdenv.mkDerivation rec {
    name = "wordpress";
    src = pkgs.fetchFromGitHub {
      owner = "WordPress";
      repo = "WordPress";
      rev = "${fullversion}";
      sha256 = "05m4cncnf4xzzb3fl540b66s7nxnjhfgnzn6pppvq3r32rw214nc";
    };
    installPhase = ''
      mkdir -p $out
      # copy all the wordpress files we downloaded
      cp -R * $out/

      # symlink the wordpress config
      ln -s ${wordpressConfig} $out/wp-config.php
      # symlink custom .htaccess
      ln -s ${htaccess} $out/.htaccess
      # symlink uploads directory
      ln -s ${config.wordpressUploads} $out/wp-content/uploads

      # remove bundled plugins(s) coming with wordpress
      rm -Rf $out/wp-content/plugins/*
      # remove bundled themes(s) coming with wordpress
      rm -Rf $out/wp-content/themes/*

      # symlink additional theme(s)
      ${concatMapStrings (theme: "ln -s ${theme} $out/wp-content/themes/${theme.name}\n") config.themes}
      # symlink additional plugin(s)
      ${concatMapStrings (plugin: "ln -s ${plugin} $out/wp-content/plugins/${plugin.name}\n") (config.plugins) }

      # symlink additional translation(s) 
      mkdir -p $out/wp-content/languages
      ${concatMapStrings (language: "ln -s ${language}/*.mo ${language}/*.po $out/wp-content/languages/\n") (selectedLanguages) }
    '';
  };

in

{

  # And some httpd extraConfig to make things work nicely
  extraConfig = ''
    <Directory ${wordpressRoot}>
      DirectoryIndex index.php
      Allow from *
      Options FollowSymLinks
      AllowOverride All
    </Directory>
  '';

  enablePHP = true;

  options = {
    dbHost = mkOption {
      default = "localhost";
      description = "The location of the database server.";  
      example = "localhost";
    };
    dbName = mkOption {
      default = "wordpress";
      description = "Name of the database that holds the Wordpress data.";
      example = "localhost";
    };
    dbUser = mkOption {
      default = "wordpress";
      description = "The dbUser, read: the username, for the database.";
      example = "wordpress";
    };
    dbPassword = mkOption {
      default = "wordpress";
      description = "The mysql password to the respective dbUser.";
      example = "wordpress";
    };
    tablePrefix = mkOption {
      default = "wp_";
      description = ''
        The $table_prefix is the value placed in the front of your database tables. Change the value if you want to use something other than wp_ for your database prefix. Typically this is changed if you are installing multiple WordPress blogs in the same database. See <link xlink:href='http://codex.wordpress.org/Editing_wp-config.php#table_prefix'/>.
      '';
    };
    wordpressUploads = mkOption {
    default = "/data/uploads";
      description = ''
        This directory is used for uploads of pictures and must be accessible (read: owned) by the httpd running user. The directory passed here is automatically created and permissions are given to the httpd running user.
      '';
    };
    plugins = mkOption {
      default = [];
      type = types.listOf types.path;
      description =
        ''
          List of path(s) to respective plugin(s) which are symlinked from the 'plugins' directory. Note: These plugins need to be packaged before use, see example.
        '';
      example = ''
        # Wordpress plugin 'akismet' installation example
        akismetPlugin = pkgs.stdenv.mkDerivation {
          name = "akismet-plugin";
          # Download the theme from the wordpress site
          src = pkgs.fetchurl {
            url = https://downloads.wordpress.org/plugin/akismet.3.1.zip;
            sha256 = "1i4k7qyzna08822ncaz5l00wwxkwcdg4j9h3z2g0ay23q640pclg";
          };
          # We need unzip to build this package
          buildInputs = [ pkgs.unzip ];
          # Installing simply means copying all files to the output directory
          installPhase = "mkdir -p $out; cp -R * $out/";
        };

        And then pass this theme to the themes list like this:
          plugins = [ akismetPlugin ];
      '';
    };
    themes = mkOption {
      default = [];
      type = types.listOf types.path;
      description =
        ''
          List of path(s) to respective theme(s) which are symlinked from the 'theme' directory. Note: These themes need to be packaged before use, see example.
        '';
      example = ''
        # For shits and giggles, let's package the responsive theme
        responsiveTheme = pkgs.stdenv.mkDerivation {
          name = "responsive-theme";
          # Download the theme from the wordpress site
          src = pkgs.fetchurl {
            url = http://wordpress.org/themes/download/responsive.1.9.7.6.zip;
            sha256 = "06i26xlc5kdnx903b1gfvnysx49fb4kh4pixn89qii3a30fgd8r8";
          };
          # We need unzip to build this package
          buildInputs = [ pkgs.unzip ];
          # Installing simply means copying all files to the output directory
          installPhase = "mkdir -p $out; cp -R * $out/";
        };

        And then pass this theme to the themes list like this:
          themes = [ responsiveTheme ];
      '';
    };
    languages = mkOption {
          default = [];
          description = "Installs wordpress language packs based on the list, see wordpress.nix for possible translations.";
          example = "[ \"en_GB\" \"de_DE\" ];";
    };
    extraConfig = mkOption {
      default = "";
      example =
        ''
          define( 'AUTOSAVE_INTERVAL', 60 ); // Seconds
        '';
      description = ''
        Any additional text to be appended to Wordpress's wp-config.php
        configuration file.  This is a PHP script.  For configuration
        settings, see <link xlink:href='http://codex.wordpress.org/Editing_wp-config.php'/>.
      '';
    };
    extraHtaccess = mkOption {
      default = "";
      example =
        ''
          php_value upload_max_filesize 20M
          php_value post_max_size 20M
        '';
      description = ''
        Any additional text to be appended to Wordpress's .htaccess file.
      '';
    };
  };

  documentRoot = wordpressRoot;

  # FIXME adding the user has to be done manually for the time being
  startupScript = pkgs.writeScript "init-wordpress.sh" ''
    #!/bin/sh
    mkdir -p ${config.wordpressUploads}
    chown ${serverInfo.serverConfig.user} ${config.wordpressUploads}

    # we should use systemd dependencies here
    #waitForUnit("network-interfaces.target");
    if [ ! -d ${serverInfo.fullConfig.services.mysql.dataDir}/${config.dbName} ]; then
      echo "Need to create the database '${config.dbName}' and grant permissions to user named '${config.dbUser}'."
      # Wait until MySQL is up
      while [ ! -e ${serverInfo.fullConfig.services.mysql.pidDir}/mysqld.pid ]; do
        sleep 1
      done
      ${pkgs.mysql}/bin/mysql -e 'CREATE DATABASE ${config.dbName};'
      ${pkgs.mysql}/bin/mysql -e 'GRANT ALL ON ${config.dbName}.* TO ${config.dbUser}@localhost IDENTIFIED BY "${config.dbPassword}";'
    else 
      echo "Good, no need to do anything database related."
    fi
  '';
}
