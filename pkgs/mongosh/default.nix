{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, openssl
, zlib
, stdenv  # for libstdc++
}:

let
  version = "2.6.0";
in
stdenv.mkDerivation {
  pname   = "percona-mongosh";
  inherit version;

  src = fetchurl {
    url  = "https://downloads.percona.com/downloads/percona-server-mongodb-8.0/percona-server-mongodb-8.0.19-7/binary/tarball/percona-mongodb-mongosh-${version}-x86_64.tar.gz";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # replace after first build
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    openssl
    zlib
    stdenv.cc.cc.lib  # libstdc++, libgcc_s
  ];

  # Adjust once we know the actual top-level dir name in the tarball
  # Run: tar -tf <tarball> | head -5  to verify
  # sourceRoot = "mongosh-${version}";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Walk the unpacked tree and install whatever ends up under bin/
    find . -maxdepth 3 -name "mongosh" -type f -exec install -m 0755 {} $out/bin/mongosh \;

    runHook postInstall
  '';

  meta = with lib; {
    description = "Percona-distributed MongoDB Shell (mongosh) ${version}";
    homepage    = "https://www.percona.com/software/mongodb/percona-server-for-mongodb";
    license     = licenses.asl20;
    platforms   = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
