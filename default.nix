{
  lib,
  pkgs,
  python3,
}:
python3.pkgs.buildPythonPackage rec {
  pname = "mbslave";
  version = "29.1.0";
  pyproject = true;

  src = pkgs.fetchFromGitHub {
    owner = "acoustid";
    repo = "mbslave";
    rev = "refs/tags/v${version}";
    sha256 = "sha256-XCj8Jt6uH3/cZDTxQYgkpiV4bc1Y+i/UccfNZVMZbAI=";
  };
  propagatedBuildInputs = with python3.pkgs; [
    attrs
    colorama
    exceptiongroup
    iniconfig
    pluggy
    prometheus-client
    psycopg2
    pyparsing
    six
    sqlparse
    tomli
    typing-extensions
    poetry-core
  ];

  prePatch = ''
    substituteInPlace pyproject.toml --replace 'prometheus-client = "^0.20.0"' 'prometheus-client = ">=0.20.0"'
  '';

  meta = with lib; {
    description = "MusicBrainz Database Mirror";
    homepage = "https://github.com/acoustid/mbslave";
    changelog = "https://github.com/acoustid/mbslave/releases/tag/v${src.rev}";
    license = licenses.mit;
    mainProgram = "mbslave";
  };
}
