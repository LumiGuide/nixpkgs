{ lib
, buildPythonPackage
, pythonOlder
, fetchPypi
, fetchzip
, alembic
, async_generator
, certipy
, python-dateutil
, entrypoints
, jinja2
, jupyter-telemetry
, oauthlib
, packaging
, pamela
, prometheus-client
, requests
, sqlalchemy
, tornado
, traitlets
, nodePackages
}:

let
  # js/css assets that setup.py tries to fetch via `npm install` when building
  # from source. https://github.com/jupyterhub/jupyterhub/blob/master/package.json
  bootstrap =
    fetchzip {
      url = "https://registry.npmjs.org/bootstrap/-/bootstrap-3.4.1.tgz";
      sha256 = "1ywmxqdccg0mgx0xknrn1hlrfnhcwphc12y9l91zizx26fqfmzgc";
    };
  font-awesome =
    fetchzip {
      url = "https://registry.npmjs.org/font-awesome/-/font-awesome-4.7.0.tgz";
      sha256 = "1xnxbdlfdd60z5ix152m8r2kk9dkwlqwpypky1mm3dv64ajnzdbk";
    };
  jquery =
    fetchzip {
      url = "https://registry.npmjs.org/jquery/-/jquery-3.5.1.tgz";
      sha256 = "0yi9ql493din1qa1s923nd5zvd0klk1sx00xj1wx2yambmq86vm9";
    };
  moment =
    fetchzip {
      url = "https://registry.npmjs.org/moment/-/moment-2.29.4.tgz";
      sha256 = "sha256-axzBYoaA8f53hLQ3Zq6vd+bZuNUu2Uund0APKBVD/1U=";
    };
  requirejs =
    fetchzip {
      url = "https://registry.npmjs.org/requirejs/-/requirejs-2.3.6.tgz";
      sha256 = "165hkli3qcd59cjqvli9r5f92i0h7czkmhcg1cgwamw2d0b7xibz";
    };

in

buildPythonPackage rec {
  pname = "jupyterhub";
  version = "4.0.0";
  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-LKspluSafStwwLtYCpkuRCBZSD4K8YrwYaKayCsUqGc=";
  };

  # Most of this only applies when building from source (e.g. js/css assets are
  # pre-built and bundled in the official release tarball on pypi).
  #
  # Stuff that's always needed:
  #   * At runtime, we need configurable-http-proxy, so we substitute the store
  #     path.
  #
  # Other stuff that's only needed when building from source:
  #   * js/css assets are fetched from npm.
  #   * substitute store path for `lessc` commmand.
  #   * set up NODE_PATH so `lessc` can find `less-plugin-clean-css`.
  #   * don't run `npm install`.
  preBuild = ''
    export NODE_PATH=${nodePackages.less-plugin-clean-css}/lib/node_modules

    substituteInPlace jupyterhub/proxy.py --replace \
      "'configurable-http-proxy'" \
      "'${nodePackages.configurable-http-proxy}/bin/configurable-http-proxy'"

    substituteInPlace jupyterhub/tests/test_proxy.py --replace \
      "'configurable-http-proxy'" \
      "'${nodePackages.configurable-http-proxy}/bin/configurable-http-proxy'"

    substituteInPlace setup.py --replace \
      "'npm'" "'true'"

    declare -A deps
    deps[bootstrap]=${bootstrap}
    deps[font-awesome]=${font-awesome}
    deps[jquery]=${jquery}
    deps[moment]=${moment}
    deps[requirejs]=${requirejs}

    mkdir -p share/jupyter/hub/static/components
    for dep in "''${!deps[@]}"; do
      if [ ! -e share/jupyter/hub/static/components/$dep ]; then
        cp -r ''${deps[$dep]} share/jupyter/hub/static/components/$dep
      fi
    done
  '';

  propagatedBuildInputs = [
    # https://github.com/jupyterhub/jupyterhub/blob/master/requirements.txt
    alembic
    async_generator
    certipy
    python-dateutil
    entrypoints
    jinja2
    jupyter-telemetry
    oauthlib
    packaging
    pamela
    prometheus-client
    requests
    sqlalchemy
    tornado
    traitlets
  ];

  doCheck = false;

  meta = with lib; {
    description = "Serves multiple Jupyter notebook instances";
    homepage = "https://jupyter.org/";
    changelog = "https://github.com/jupyterhub/jupyterhub/blob/${version}/docs/source/changelog.md";
    license = licenses.bsd3;
    maintainers = with maintainers; [ ixxie cstrahan ];
  };
}
