{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, openssl
, curl
, zlib
, snappy
, cyrus_sasl
, openldap
, krb5
, lz4
, zstd
, libpcap
, xz  # liblzma
}:

let
  version = "8.0.19-7";
  suffix  = "x86_64.ol9";
in
stdenv.mkDerivation {
  pname   = "percona-server-mongodb";
  inherit version;

  src = fetchurl {
    url    = "https://downloads.percona.com/downloads/percona-server-mongodb-8.0/percona-server-mongodb-${version}/binary/tarball/percona-server-mongodb-${version}-${suffix}.tar.gz";
    hash   = "sha256-pr3jMspkdFJYbM4YWdxRqe/4mkYlbR8x4ODvtKg8WbY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # Runtime libraries autoPatchelfHook will search for
  buildInputs = [
    openssl
    curl
    zlib
    snappy
    cyrus_sasl
    krb5
    lz4
    zstd
    libpcap
    xz
    openldap
    (lib.getLib stdenv.cc.cc)
  ];

  sourceRoot = "percona-server-mongodb-${version}-${suffix}";
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    install -m 0755 bin/mongod $out/bin/mongod
    install -m 0755 bin/mongos $out/bin/mongos
    install -m 0755 bin/perconadecrypt $out/bin/perconadecrypt

    if [ -f bin/install_compass ]; then
      install -m 0755 bin/install_compass $out/bin/install_compass
    fi
    runHook postInstall
  '';

  meta = with lib; {
    description = "Percona Server for MongoDB ${version} — drop-in MongoDB replacement with enterprise features";
    homepage    = "https://www.percona.com/software/mongodb/percona-server-for-mongodb";
    license     = licenses.sspl;
    platforms   = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
