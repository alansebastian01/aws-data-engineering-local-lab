# MariaDB JDBC driver for Apache Hop

Apache Hop's standard distribution does not bundle MariaDB Connector/J. The lab mounts this directory into the Hop containers as `/drivers` and sets:

```text
HOP_SHARED_JDBC_FOLDERS=/drivers
```

Before testing the Hop MariaDB connection, place one compatible MariaDB Connector/J jar here.

Recommended reproducible lab version at the time this guide was prepared:

```text
mariadb-java-client-3.5.8.jar
```

From the repository root in WSL:

```bash
curl -fL \
  -o drivers/mariadb-java-client-3.5.8.jar \
  https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.5.8/mariadb-java-client-3.5.8.jar
```

Do not keep multiple versions of the MariaDB JDBC driver in this directory.

See `docs/INSTALLATION_GUIDE.md` for the complete installation and verification procedure.
