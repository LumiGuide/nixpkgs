{ stdenv, buildPythonPackage, fetchPypi
, funcsigs, six, pytz, tzlocal, futures
}:

buildPythonPackage rec {
  pname = "APScheduler";
  version = "3.3.1";
  name = "${pname}-${version}";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0yvn69bvfc6za49q6gryk9h2q5jd3q689dxdwdncrzxxy7gp927n";
  };

  propagatedBuildInputs =  [ funcsigs six pytz tzlocal futures ];

  meta = with stdenv.lib; {
    description = "In-process task scheduler with Cron-like capabilities";
    homepage = https://apscheduler.readthedocs.io;
    license = licenses.mit;
  };
}
