{ stdenv, fetchurl, fetchpatch, unzip, libjpeg, libtiff, zlib
, mysql, libgeotiff, pythonPackages, proj, geos, openssl
, libpng, sqlite, libspatialite, poppler, hdf4
, libiconv
, netcdfSupport ? true, netcdf, hdf5, curl
, postgresql
}:

with stdenv.lib;

stdenv.mkDerivation rec {
  version = "2.3.1";
  name = "gdal-${version}";

  src = fetchurl {
    url = "https://download.osgeo.org/gdal/${version}/${name}.tar.xz";
    sha256 = "0nkjnznrp7dr41zsh8j923c9zpc3i5vj3wjfc2df9rrybb22ailw";
  };

  buildInputs = [ unzip libjpeg libtiff libpng proj openssl sqlite
    libspatialite poppler hdf4 ]
  ++ (with pythonPackages; [ python numpy wrapPython ])
  ++ stdenv.lib.optional stdenv.isDarwin libiconv
  ++ stdenv.lib.optionals netcdfSupport [ netcdf hdf5 curl ];

  configureFlags = [
    "--with-jpeg=${libjpeg.dev}"
    "--with-libtiff=${libtiff.dev}" # optional (without largetiff support)
    "--with-png=${libpng.dev}"      # optional
    "--with-poppler=${poppler.dev}" # optional
    "--with-libz=${zlib.dev}"       # optional
    "--with-pg=${postgresql}/bin/pg_config"
    "--with-mysql=${mysql.connector-c or mysql}/bin/mysql_config"
    "--with-geotiff=${libgeotiff}"
    "--with-sqlite3=${sqlite.dev}"
    "--with-spatialite=${libspatialite}"
    "--with-python"               # optional
    "--with-static-proj4=${proj}" # optional
    "--with-geos=${geos}/bin/geos-config"# optional
    "--with-hdf4=${hdf4.dev}" # optional
    (optionalString netcdfSupport "--with-netcdf=${netcdf}")
  ];

  hardeningDisable = [ "format" ];

  CXXFLAGS = "-fpermissive";

  postPatch = ''
    sed -i '/ifdef bool/i\
      #ifdef swap\
      #undef swap\
      #endif' ogr/ogrsf_frmts/mysql/ogr_mysql.h
  '';

  # - Unset CC and CXX as they confuse libtool.
  # - teach gdal that libdf is the legacy name for libhdf
  preConfigure = ''
      unset CC CXX
      substituteInPlace configure \
      --replace "-lmfhdf -ldf" "-lmfhdf -lhdf"
    '';

  preBuild = ''
    substituteInPlace swig/python/GNUmakefile \
      --replace "ifeq (\$(STD_UNIX_LAYOUT),\"TRUE\")" "ifeq (1,1)"
  '';

  postInstall = ''
    wrapPythonPrograms
  '';

  enableParallelBuilding = true;

  meta = {
    description = "Translator library for raster geospatial data formats";
    homepage = http://www.gdal.org/;
    license = stdenv.lib.licenses.mit;
    maintainers = [ stdenv.lib.maintainers.marcweber ];
    platforms = with stdenv.lib.platforms; linux ++ darwin;
  };
}
