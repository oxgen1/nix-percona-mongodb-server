{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.percona-server-mongodb;

  mongod = "${cfg.package}/bin/mongod";
  mongosh = lib.getExe cfg.mongoshPackage;

  mongoCnf = pkgs.writeText "percona-mongodb.conf" ''
    net.bindIp: ${cfg.bind_ip}
    ${lib.optionalString cfg.quiet "systemLog.quiet: true"}
    systemLog.destination: syslog
    storage.dbPath: ${cfg.dbpath}
    ${lib.optionalString cfg.enableAuth "security.authorization: enabled"}
    ${lib.optionalString (cfg.replSetName != "") "replication.replSetName: ${cfg.replSetName}"}
    ${cfg.extraConfig}
  '';

  # Config without auth, used during initial root user setup
  mongoCnfNoAuth = pkgs.writeText "percona-mongodb-setup.conf" ''
    net.bindIp: 127.0.0.1
    systemLog.destination: syslog
    storage.dbPath: ${cfg.dbpath}
  '';
in
{
  options.services.percona-server-mongodb = {
    enable = lib.mkEnableOption "Percona Server for MongoDB";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The percona-server-mongodb package to use.";
    };

    mongoshPackage = lib.mkOption {
      type = lib.types.package;
      description = "The mongosh package to use for initialisation scripts.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "percona-mongodb";
      description = "User account under which mongod runs.";
    };

    bind_ip = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP address(es) mongod binds to (comma-separated).";
    };

    quiet = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Reduce log verbosity.";
    };

    enableAuth = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable client authentication. Requires initialRootPasswordFile.";
    };

    initialRootPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the initial root password (used when enableAuth = true).";
    };

    dbpath = lib.mkOption {
      type = lib.types.str;
      default = "/var/db/percona-mongodb";
      description = "Directory where mongod stores its data files.";
    };

    pidFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/percona-mongodb/mongod.pid";
      description = "Path to the mongod PID file.";
    };

    replSetName = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Replica set name. Leave empty for standalone mode.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = "storage.journal.enabled: false";
      description = "Additional mongod configuration in YAML format, appended to the generated config.";
    };

    initialScript = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a JS file executed via mongosh on the very first startup.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.enableAuth || cfg.initialRootPasswordFile != null;
        message = "services.percona-server-mongodb.enableAuth requires initialRootPasswordFile to be set.";
      }
    ];

    users.users.${cfg.user} = lib.mkIf (cfg.user == "percona-mongodb") {
      isSystemUser = true;
      group = cfg.user;
      description = "Percona Server for MongoDB daemon user";
    };
    users.groups.${cfg.user} = lib.mkIf (cfg.user == "percona-mongodb") { };

    systemd.services.percona-server-mongodb = {
      description = "Percona Server for MongoDB";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${mongod} --config ${mongoCnf} --fork --pidfilepath ${cfg.pidFile}";
        User = cfg.user;
        PIDFile = cfg.pidFile;
        Type = "forking";
        TimeoutStartSec = 120;
        PermissionsStartOnly = true;
        RuntimeDirectory = "percona-mongodb";
        RuntimeDirectoryMode = "0755";
      };

      preStart = ''
        rm -f ${cfg.dbpath}/mongod.lock || true

        if ! test -e ${cfg.dbpath}; then
          install -d -m 0700 -o ${cfg.user} ${cfg.dbpath}
        fi

        if ! test -e ${cfg.dbpath}/storage.bson; then
          touch ${cfg.dbpath}/.first_startup
        fi
      '' + lib.optionalString cfg.enableAuth ''
        if ! test -e ${cfg.dbpath}/.auth_setup_complete; then
          systemd-run --unit=percona-mongodb-setup --uid=${cfg.user} \
            ${mongod} --config ${mongoCnfNoAuth}
          while ! ${mongosh} --eval "db.version()" >/dev/null 2>&1; do sleep 0.1; done

          initialRootPassword=$(<${cfg.initialRootPasswordFile})
          ${mongosh} <<EOF
            use admin;
            db.createUser({
              user: "root",
              pwd: "$initialRootPassword",
              roles: [
                { role: "userAdminAnyDatabase",  db: "admin" },
                { role: "dbAdminAnyDatabase",    db: "admin" },
                { role: "readWriteAnyDatabase",  db: "admin" }
              ]
            });
        EOF
          touch ${cfg.dbpath}/.auth_setup_complete
          systemctl stop percona-mongodb-setup
        fi
      '';

      postStart = ''
        if test -e ${cfg.dbpath}/.first_startup; then
          ${lib.optionalString (cfg.initialScript != null) ''
            ${lib.optionalString cfg.enableAuth "initialRootPassword=$(<${cfg.initialRootPasswordFile})"}
            ${mongosh} ${lib.optionalString cfg.enableAuth "-u root -p \"$initialRootPassword\""} admin "${cfg.initialScript}"
          ''}
          rm -f ${cfg.dbpath}/.first_startup
        fi
      '';
    };
  };
}
