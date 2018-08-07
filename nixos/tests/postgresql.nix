{ system ? builtins.currentSystem
, test_pg_journal ? true
, test_postgis ? true
}:

with import ../lib/testing.nix { inherit system; };
with pkgs.lib;

let

  # An attrset containing every version of PostgreSQL, shipped by Nixpkgs.  The
  # tests are run once for each version.
  postgresql-versions =
    # This is an existing attrset containing every supported version...
    let allPackages = (pkgs.callPackage ../../pkgs/servers/sql/postgresql/packages.nix { }).allPostgresqlPackages;
    # ... now swizzle the names of the attrset in order to be more user-friendly. This is a bit of a hack;
    # ideally we would use postgresql.version, but that normally results in something like 'postgresql-10.4'
    # which is an attribute name that can't be evaluated easily by 'nix-build'
    in mapAttrs' (name: value: { name = "${builtins.substring 0 12 name}"; inherit value; }) allPackages;

  # Sample SQL script to use. Note: this should work on _every_ available, supported
  # version of PostgreSQL shipped by Nixpkgs.
  test-sql = pkgs.writeText "test.sql" (''
    CREATE EXTENSION pgcrypto; -- just to check if lib loading works
    CREATE TABLE sth (
      id int
    );
    INSERT INTO sth (id) VALUES (1);
    INSERT INTO sth (id) VALUES (1);
    INSERT INTO sth (id) VALUES (1);
    INSERT INTO sth (id) VALUES (1);
    INSERT INTO sth (id) VALUES (1);
    CREATE TABLE xmltest ( doc xml );
    INSERT INTO xmltest (doc) VALUES ('<test>ok</test>'); -- check if libxml2 enabled
  '' + optionalString test_postgis ''
    -- Enable the postgis extension and insert some geography data.
    -- Copied from section 4.2.1 from the PostGIS manual.
    CREATE EXTENSION postgis;
    CREATE EXTENSION postgis_topology;
    CREATE TABLE global_points (
      id SERIAL PRIMARY KEY,
      name VARCHAR(64),
      location GEOGRAPHY(POINT,4326)
    );
    INSERT INTO global_points (name, location)
      VALUES ('Town', ST_GeogFromText('SRID=4326; POINT(-110 30)') );
    INSERT INTO global_points (name, location)
      VALUES ('Forest', ST_GeogFromText('SRID=4326; POINT(-109 29)') );
    INSERT INTO global_points (name, location)
      VALUES ('London', ST_GeogFromText('SRID=4326; POINT(0 49)') );
    CREATE INDEX global_points_gix ON global_points USING GIST ( location );
  '');

  # Actual test
  make-test = name: packages: makeTest {
    inherit name;

    meta = with pkgs.stdenv.lib.maintainers; {
      maintainers = [ thoughtpolice zagy ];
    };

    machine = { pkgs, lib, ...}: lib.mkMerge [
      {
        services.postgresql.enable = true;
        services.postgresql.packages = packages;
        services.postgresql.plugins = p: with p;
          optional test_postgis postgis;

        services.postgresqlBackup.enable = true;
        services.postgresqlBackup.databases = [ "postgres" ];
      }

      (lib.mkIf test_pg_journal {
        services.postgresql.plugins = p: with p; [ pg_journal ];
        services.postgresql.extraConfig = ''
          shared_preload_libraries = 'pg_journal'
          log_statement = all
        '';
        environment.systemPackages = [ pkgs.jq ];
      })
    ];

    testScript = ''
      sub check_count {
        my ($select, $nlines) = @_;
        return 'test $(sudo -u postgres psql postgres -tAc "' . $select . '"|wc -l) -eq ' . $nlines;
      }

      $machine->start;

      # postgresql should be available just after unit start
      $machine->waitForUnit("postgresql");
      $machine->succeed("cat ${test-sql} | sudo -u postgres psql");
      $machine->shutdown; # make sure that postgresql survive restart (bug #1735)
      sleep(2);

      # run some basic queries against the schema
      $machine->start;
      $machine->waitForUnit("postgresql");
      $machine->fail(check_count("SELECT * FROM sth;", 3));
      $machine->succeed(check_count("SELECT * FROM sth;", 5));
      $machine->fail(check_count("SELECT * FROM sth;", 4));
      $machine->succeed(check_count("SELECT xpath(\'/test/text()\', doc) FROM xmltest;", 1));

      ${optionalString test_pg_journal ''
      # Check that pg_journal plugin is outputting structured logs to the journal
      $machine->succeed('journalctl -u postgresql -r -o json | \
        \jq \'select(.PGDATABASE == "postgres") | .MESSAGE | test(".*SELECT \\\\* FROM sth")\' | grep true');
      ''}

      ${optionalString test_postgis ''
      # Check some postgis query
      $machine->succeed(' \
        test "$(sudo -u postgres psql postgres -tAc \
                "SELECT name \
                 FROM global_points \
                 WHERE ST_DWithin(location, ST_GeogFromText(\'SRID=4326; POINT(0 0)\'), 10000000);" \
              )" = "London" \
      ');
      ''}

      # Check backup service
      $machine->succeed("systemctl start postgresqlBackup-postgres.service");
      $machine->succeed("zcat /var/backup/postgresql/postgres.sql.gz | grep '<test>ok</test>'");
      $machine->shutdown;
    '';
  };

  results = mapAttrs' (name: pkg: { inherit name; value = make-test name pkg; }) postgresql-versions;
in results
