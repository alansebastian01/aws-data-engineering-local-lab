# AWS Data Engineering Local Lab - Complete Installation Guide

**Repository name:** `aws-data-engineering-local-lab`  
**Project title:** **AWS Data Engineering Local Lab**  
**Architecture:** MariaDB source -> Apache Hop ETL/ELT -> MinIO data lake -> PostgreSQL warehouse -> Apache Superset BI

This document is the clean-machine installation runbook for the project. It is intentionally separate from the main `README.md` so the repository can keep architecture/lab documentation in the README and reproducible installation instructions here.

> Scope: Windows 10/11 laptop, Docker Desktop with WSL 2, Git, Python, DBeaver, and a browser. Jupyter is optional but recommended for validation exercises.

---

## 1. What this installation creates

The Docker Compose stack creates these services:

| Service | Purpose | Host access |
|---|---|---|
| MariaDB | OLTP/source database (`source_db`) | `localhost:3307` |
| PostgreSQL 17 | Analytical warehouse (`warehouse`) | `localhost:5433` |
| MinIO | S3-compatible local data lake | API `localhost:9000`, Console `http://localhost:9001` |
| Apache Hop Web | Browser ETL/ELT design | `http://localhost:8080/ui` |
| Apache Superset | Dashboards and SQL exploration | `http://localhost:8088` |

Containers communicate through the Docker network by service name, so Hop and Superset use `mariadb:3306`, `postgres:5432`, and `minio:9000` rather than `localhost`.

---

## 2. Recommended laptop resources

Minimum practical lab configuration:

- 64-bit Windows 10/11
- 4 CPU cores
- 16 GB RAM
- 30-40 GB free disk space

Comfortable configuration:

- 6-8 CPU cores
- 32 GB RAM
- 50+ GB free disk space

You do not need to install MariaDB, PostgreSQL, MinIO, Hop, or Superset directly on Windows for this project; Docker runs them as Linux containers.

---

## 3. Verify Windows Subsystem for Linux (WSL 2)

Open **PowerShell** and run:

```powershell
wsl --version
wsl --status
wsl -l -v
```

If WSL is not installed:

```powershell
wsl --install
```

Restart Windows if requested. Then update WSL:

```powershell
wsl --update
```

Make WSL 2 the default for new distributions:

```powershell
wsl --set-default-version 2
```

If Ubuntu is not installed, install it from Microsoft Store or with:

```powershell
wsl --install -d Ubuntu
```

Verify Ubuntu shows version `2`:

```powershell
wsl -l -v
```

---

## 4. Verify Docker Desktop and WSL integration

Install Docker Desktop for Windows if it is not already installed.

In Docker Desktop:

1. Open **Settings -> General**.
2. Ensure **Use the WSL 2 based engine** is enabled when that option is shown.
3. Open **Settings -> Resources -> WSL Integration**.
4. Enable integration for the Ubuntu distribution you will use.
5. Apply/restart Docker Desktop if prompted.

In PowerShell or WSL, verify:

```bash
docker version
docker compose version
docker run --rm hello-world
```

Do not separately install Docker Engine inside Ubuntu when you are using Docker Desktop's WSL integration; running both can create conflicts.

---

## 5. Verify Git and Python

Inside WSL:

```bash
git --version
python3 --version
python3 -m pip --version
```

If Ubuntu is missing Git, Python, pip, curl, or unzip:

```bash
sudo apt update
sudo apt install -y git python3 python3-pip python3-venv curl unzip ca-certificates
```

Verify again:

```bash
git --version
python3 --version
curl --version
```

---

## 6. Put the repository in the WSL Linux filesystem

Docker recommends keeping Linux-container development code inside the Linux distribution for the best WSL development experience.

Create a project directory:

```bash
mkdir -p ~/projects
cd ~/projects
```

### Option A - clone from GitHub

After you publish the repository:

```bash
git clone https://github.com/<YOUR-GITHUB-USER>/aws-data-engineering-local-lab.git
cd aws-data-engineering-local-lab
```

### Option B - copy/extract the supplied project first

Extract the project so the resulting directory is:

```text
~/projects/aws-data-engineering-local-lab
```

Then:

```bash
cd ~/projects/aws-data-engineering-local-lab
```

Verify required files:

```bash
ls -la
find . -maxdepth 2 -type f | sort
```

At minimum you should see:

```text
.env.example
.gitignore
README.md
docker-compose.yml
docs/INSTALLATION_GUIDE.md
docs/LAB_CHECKLIST.md
scripts/generate_sales_data.py
superset/Dockerfile
```

---

## 7. Install the MariaDB JDBC driver for Apache Hop

This is a required step for the MariaDB source connection. Apache Hop includes many compatible JDBC drivers, but the MariaDB JDBC driver is not bundled. The Compose file mounts the repository `drivers/` directory at `/drivers` and sets:

```text
HOP_SHARED_JDBC_FOLDERS=/drivers
```

Use **MariaDB Connector/J 3.5.8** (Stable GA, released April 1, 2026) or a newer compatible stable version after reviewing the MariaDB release notes.

### Method A - download from Maven Central in WSL

From the repository root:

```bash
mkdir -p drivers
curl -fL \
  -o drivers/mariadb-java-client-3.5.8.jar \
  https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.5.8/mariadb-java-client-3.5.8.jar
```

Verify the file exists:

```bash
ls -lh drivers/*.jar
```

### Method B - browser download

Download the current stable **MariaDB Connector/J** `.jar` from the official MariaDB Connector/J download page and place it in:

```text
drivers/
```

Expected example:

```text
drivers/mariadb-java-client-3.5.8.jar
```

Do not place multiple versions of the same JDBC driver in this folder.

> GitHub note: the repository can either commit this driver if its license/policy is acceptable to you, or keep it out of Git and require this installation step. For a public portfolio repository, documenting the official download is usually cleaner than redistributing third-party binaries.

---

## 8. Create the environment file

From the repository root:

```bash
cp .env.example .env
```

Open `.env` in an editor and replace all example passwords.

Example:

```dotenv
# MariaDB source
MARIADB_ROOT_PASSWORD=replace_me
MARIADB_USER=labuser
MARIADB_PASSWORD=replace_me

# PostgreSQL warehouse
POSTGRES_DB=warehouse
POSTGRES_USER=dw_admin
POSTGRES_PASSWORD=replace_me
POSTGRES_BI_USER=bi_reader
POSTGRES_BI_PASSWORD=replace_me

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=replace_me

# Superset
SUPERSET_ADMIN_USER=admin
SUPERSET_ADMIN_PASSWORD=replace_me
SUPERSET_ADMIN_EMAIL=admin@example.local
SUPERSET_SECRET_KEY=replace_me
```

Generate a long Superset secret:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
```

Paste the generated value into `SUPERSET_SECRET_KEY`.

Verify `.env` is ignored by Git:

```bash
git check-ignore .env
```

Expected output:

```text
.env
```

Never commit `.env`, real passwords, access keys, or production secrets.

---

## 9. Validate Docker Compose before startup

Run:

```bash
docker compose config
```

This should render the complete configuration without YAML or missing-variable errors.

List the services:

```bash
docker compose config --services
```

Expected main services:

```text
mariadb
postgres
minio
minio-init
hop-web
superset
```

`hop-runner` is an optional profile service.

---

## 10. Pull and build the images

Run:

```bash
docker compose pull
```

Then build the custom Superset image:

```bash
docker compose build --pull superset
```

The Superset Dockerfile installs:

```text
psycopg2-binary
pymysql
```

`psycopg2-binary` lets Superset query PostgreSQL. PyMySQL is included for optional source-versus-warehouse exercises.

---

## 11. Start the complete platform

Run:

```bash
docker compose up -d --build
```

Check status:

```bash
docker compose ps
```

Expected containers include:

```text
de-mariadb
de-postgres-dw
de-minio
de-minio-init
de-hop-web
de-superset
```

`de-minio-init` is a one-time initialization container. It can finish and exit successfully after creating the buckets.

Check recent logs:

```bash
docker compose logs --tail=100 mariadb postgres minio hop-web superset
```

Follow startup logs if necessary:

```bash
docker compose logs -f mariadb postgres minio hop-web superset
```

Stop log following with `Ctrl+C`; this does not stop the containers.

---

## 12. Verify each container and port

Run:

```bash
docker compose ps
```

Optional host-port checks in WSL:

```bash
curl -I http://localhost:9001
curl -I http://localhost:8080/ui
curl -I http://localhost:8088
```

Database port checks can be made with DBeaver, or if `nc` is installed:

```bash
nc -vz localhost 3307
nc -vz localhost 5433
```

Install netcat if needed:

```bash
sudo apt install -y netcat-openbsd
```

---

## 13. Verify MariaDB source initialization

### DBeaver connection

Create a MariaDB connection:

```text
Host: localhost
Port: 3307
Database: source_db
User: labuser
Password: MARIADB_PASSWORD from .env
```

Run:

```sql
USE source_db;
SHOW TABLES;

SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
```

Before data import, the tables should exist and row counts can be zero.

### Docker CLI verification

You can also run:

```bash
docker exec -it de-mariadb mariadb \
  -u"$MARIADB_USER" \
  -p"$MARIADB_PASSWORD" \
  source_db
```

If the shell variables are not loaded in your terminal, use DBeaver instead or load `.env` carefully.

---

## 14. Verify PostgreSQL warehouse initialization

### DBeaver connection as warehouse owner

```text
Host: localhost
Port: 5433
Database: warehouse
User: dw_admin
Password: POSTGRES_PASSWORD from .env
```

Run:

```sql
SELECT current_database();
SELECT current_user;
SELECT version();

SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('dw', 'control')
ORDER BY schema_name;
```

Then:

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('dw', 'control')
ORDER BY table_schema, table_name;
```

Expected core warehouse objects:

```text
dw.dim_date
dw.dim_customer
dw.dim_product
dw.fact_sales
control.etl_watermark
control.etl_audit
control.data_quality_rejects
```

Views include:

```text
dw.v_sales_detail
control.v_etl_health
```

You can also execute the supplied validation script:

```text
scripts/postgres_validation.sql
```

---

## 15. Verify the PostgreSQL BI read-only account

Create a second DBeaver PostgreSQL connection:

```text
Host: localhost
Port: 5433
Database: warehouse
User: bi_reader
Password: POSTGRES_BI_PASSWORD from .env
```

This should succeed:

```sql
SELECT * FROM dw.dim_product LIMIT 10;
```

A write should fail, for example:

```sql
DELETE FROM dw.dim_product
WHERE product_id = -99999;
```

The failure is expected and proves the BI account is read-only.

---

## 16. Verify MinIO

Open:

```text
http://localhost:9001
```

Sign in with:

```text
MINIO_ROOT_USER
MINIO_ROOT_PASSWORD
```

Expected buckets:

```text
raw
curated
archive
rejects
```

If the buckets are missing, inspect:

```bash
docker compose logs minio-init
```

Re-run the initializer if needed:

```bash
docker compose run --rm minio-init
```

---

## 17. Verify Apache Hop Web

Open:

```text
http://localhost:8080/ui
```

The repository directory `hop-project/` is mounted into Hop as:

```text
/files
```

The JDBC driver folder is mounted as:

```text
/drivers
```

Confirm the driver can be seen inside the container:

```bash
docker exec de-hop-web sh -lc 'ls -lh /drivers'
```

You should see the MariaDB Connector/J `.jar`.

---

## 18. Configure the MariaDB source connection in Hop

In Hop Web, create a **Relational Database Connection**:

```text
Name: lab_source_mariadb
Database type: MariaDB
Host: mariadb
Port: 3306
Database: source_db
Username: labuser
Password: value of MARIADB_PASSWORD
```

Test the connection.

If Hop reports that the MariaDB JDBC driver is missing:

1. Confirm the `.jar` exists in local `drivers/`.
2. Confirm `docker exec de-hop-web sh -lc 'ls /drivers'` sees it.
3. Confirm `docker-compose.yml` has `HOP_SHARED_JDBC_FOLDERS: /drivers` for `hop-web`.
4. Recreate the Hop container:

```bash
docker compose up -d --force-recreate hop-web
```

5. Test again.

---

## 19. Configure the PostgreSQL warehouse connection in Hop

Create another Hop relational connection:

```text
Name: lab_dw_postgres
Database type: PostgreSQL
Host: postgres
Port: 5432
Database: warehouse
Username: dw_admin
Password: value of POSTGRES_PASSWORD
```

Test it.

Notice the difference:

```text
DBeaver on host -> localhost:5433
Hop in Docker   -> postgres:5432
```

---

## 20. Configure MinIO in Hop

Create a MinIO connection:

```text
Name: lablake
Access key: MINIO_ROOT_USER
Secret key: MINIO_ROOT_PASSWORD
Endpoint hostname: minio
Endpoint port: 9000
Secure: false
Region: us-east-1
```

Logical paths can then follow this pattern:

```text
lablake:///raw/retail/
lablake:///curated/retail/
lablake:///archive/retail/
lablake:///rejects/retail/
```

---

## 21. Verify Apache Superset

Open:

```text
http://localhost:8088
```

Sign in with:

```text
SUPERSET_ADMIN_USER
SUPERSET_ADMIN_PASSWORD
```

If the page does not load, inspect:

```bash
docker compose logs --tail=200 superset
```

Superset can take longer on the first start because it runs database migrations, creates the admin account, initializes application metadata, and then launches Gunicorn.

---

## 22. Connect Superset to PostgreSQL

In Superset, add a database connection using the read-only BI account.

SQLAlchemy URI:

```text
postgresql+psycopg2://bi_reader:<POSTGRES_BI_PASSWORD>@postgres:5432/warehouse
```

Do **not** use `localhost:5433` from Superset. Superset runs inside Docker, so it reaches the warehouse at `postgres:5432`.

Test the connection and save it.

The intended permission flow is:

```text
Apache Hop -> dw_admin -> PostgreSQL -> bi_reader -> Superset
             writes                    reads only
```

---

## 23. Generate the first synthetic dataset

From the repository root in WSL:

```bash
python3 scripts/generate_sales_data.py --orders 100000
```

Expected files:

```text
datasets/generated/customers.csv
datasets/generated/products.csv
datasets/generated/orders.csv
datasets/generated/order_items.csv
```

Verify:

```bash
ls -lh datasets/generated/
wc -l datasets/generated/*.csv
```

Start with 100,000 orders. Do not begin with the one-million-order exercise until the pipeline is correct and rerunnable.

---

## 24. Load CSV files into MariaDB with DBeaver

For the first lab, use DBeaver's **Import Data** wizard so you can inspect mappings manually.

Import in this order:

```text
customers.csv   -> source_db.customers
products.csv    -> source_db.products
orders.csv      -> source_db.orders
order_items.csv -> source_db.order_items
```

The order matters because orders depend on customers and order items depend on orders/products.

After import:

```sql
SELECT COUNT(*) AS customers FROM source_db.customers;
SELECT COUNT(*) AS products FROM source_db.products;
SELECT COUNT(*) AS orders FROM source_db.orders;
SELECT COUNT(*) AS order_items FROM source_db.order_items;
```

Use `scripts/load_csv_to_mariadb.sql` for additional checks.

---

## 25. Install the optional Jupyter/Python validation environment

You already may have Python/Jupyter on Windows. For a reproducible WSL environment, create a virtual environment in the repository:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install \
  jupyterlab \
  pandas \
  pyarrow \
  sqlalchemy \
  pymysql \
  psycopg2-binary \
  boto3 \
  s3fs \
  duckdb \
  matplotlib
```

Start Jupyter Lab:

```bash
jupyter lab --no-browser
```

Use Jupyter for independent source/warehouse reconciliation and MinIO validation rather than as the primary ETL engine.

---

## 26. Recommended initial verification queries

### Source count check

```sql
SELECT COUNT(*) FROM source_db.orders;
```

### PostgreSQL warehouse object check

```sql
SELECT COUNT(*) FROM dw.dim_customer;
SELECT COUNT(*) FROM dw.dim_product;
SELECT COUNT(*) FROM dw.fact_sales;
```

Before ETL, dimensions may contain only initialized unknown members and the fact table may be empty.

### Watermark check

```sql
SELECT *
FROM control.etl_watermark
ORDER BY pipeline_name;
```

### Audit check

```sql
SELECT *
FROM control.etl_audit
ORDER BY run_start_ts DESC
LIMIT 20;
```

---

## 27. First Hop pipeline order

Once installation is verified, build the project in this sequence:

1. `dim_date`
2. `dim_product`
3. `dim_customer` as SCD Type 2
4. `fact_sales`
5. ETL audit logging
6. data-quality reject routing
7. incremental/watermark loading
8. MinIO raw/curated writing
9. Superset business dashboard
10. Superset engineering/ETL-health dashboard

Use `docs/LAB_CHECKLIST.md` as the hands-on project checklist.

---

## 28. Common Windows/WSL problems

### Docker command not found inside WSL

Enable Docker Desktop WSL integration for the Ubuntu distribution and restart the terminal.

### Port 3307 is already in use

Find the process/container using it or change:

```yaml
ports:
  - "3307:3306"
```

to another unused host port such as `3308:3306`. Hop still uses `mariadb:3306` internally.

### Port 5433 is already in use

Change host mapping to another unused host port, for example:

```yaml
ports:
  - "5434:5432"
```

Hop and Superset still use `postgres:5432` internally.

### Port 8080 or 8088 is already in use

Change only the host side of the relevant mapping. For example:

```yaml
- "8081:8080"
```

or:

```yaml
- "8089:8088"
```

### Hop cannot connect to MariaDB

Most likely causes:

- MariaDB JDBC driver missing from `drivers/`;
- `HOP_SHARED_JDBC_FOLDERS` not set;
- wrong host (`localhost` instead of `mariadb`);
- wrong port (`3307` instead of container port `3306`);
- wrong password.

### Hop cannot connect to PostgreSQL

Check:

```text
Host: postgres
Port: 5432
Database: warehouse
User: dw_admin
```

Do not use `localhost:5433` from inside Hop.

### Superset cannot connect to PostgreSQL

Use:

```text
postgresql+psycopg2://bi_reader:<password>@postgres:5432/warehouse
```

Do not use the host-side port.

### Schema changes do not appear after editing initialization SQL

The official MariaDB/PostgreSQL Docker entrypoint scripts run initialization files only when creating a new database volume.

For a full lab reset:

```bash
docker compose down -v
docker compose up -d --build
```

**Warning:** `down -v` permanently deletes this lab's database and MinIO volumes.

### Normal stop without deleting data

```bash
docker compose down
```

### Restart existing services

```bash
docker compose up -d
```

---

## 29. Useful operations cheat sheet

Status:

```bash
docker compose ps
```

Logs:

```bash
docker compose logs --tail=100
```

Follow one service:

```bash
docker compose logs -f postgres
```

Restart one service:

```bash
docker compose restart hop-web
```

Recreate one service:

```bash
docker compose up -d --force-recreate hop-web
```

Stop while retaining data:

```bash
docker compose down
```

Full destructive reset:

```bash
docker compose down -v
```

Pull new images:

```bash
docker compose pull
```

Rebuild Superset:

```bash
docker compose build --pull superset
```

Start optional Hop runner profile:

```bash
docker compose --profile runner up -d hop-runner
```

---

## 30. GitHub publishing checklist

Before the first push:

```bash
git status
git check-ignore .env
git check-ignore datasets/generated/orders.csv 2>/dev/null || true
```

Recommended repository name:

```text
aws-data-engineering-local-lab
```

Initialize if necessary:

```bash
git init
git add .
git status
git commit -m "Initial local data engineering lab"
git branch -M main
```

Create an empty GitHub repository named `aws-data-engineering-local-lab`, then add the remote shown by GitHub, for example:

```bash
git remote add origin https://github.com/<YOUR-GITHUB-USER>/aws-data-engineering-local-lab.git
git push -u origin main
```

Before every push, inspect:

```bash
git diff --cached
git status
```

Never publish `.env`, passwords, access keys, private data, or generated multi-gigabyte datasets.

---

## 31. Suggested GitHub repository description

```text
Hands-on local data engineering platform using MariaDB, Apache Hop, MinIO, PostgreSQL, Superset, Docker, Python and Jupyter. Covers ETL/ELT, SCD2, incremental loading, data quality, dimensional modeling, observability, BI and AWS migration patterns.
```

Suggested topics:

```text
data-engineering
apache-hop
postgresql
mariadb
minio
apache-superset
docker
etl
elt
data-warehouse
data-lake
aws
python
jupyter
scd2
dimensional-modeling
```

---

## 32. Installation acceptance checklist

Installation is complete when all of the following are true:

- [ ] WSL 2 is enabled.
- [ ] Docker Desktop WSL integration works.
- [ ] `docker compose config` succeeds.
- [ ] MariaDB Connector/J exists in `drivers/`.
- [ ] `docker compose up -d --build` succeeds.
- [ ] MariaDB is reachable at `localhost:3307`.
- [ ] PostgreSQL is reachable at `localhost:5433`.
- [ ] `dw` and `control` PostgreSQL schemas exist.
- [ ] `bi_reader` can SELECT and cannot DELETE.
- [ ] MinIO console opens and four buckets exist.
- [ ] Hop Web opens at `/ui`.
- [ ] Hop can connect to MariaDB using `mariadb:3306`.
- [ ] Hop can connect to PostgreSQL using `postgres:5432`.
- [ ] Hop can connect to MinIO using `minio:9000`.
- [ ] Superset opens at `localhost:8088`.
- [ ] Superset can connect to PostgreSQL as `bi_reader`.
- [ ] Synthetic datasets can be generated.
- [ ] Source CSV files can be imported into MariaDB.
- [ ] `.env` is ignored by Git.

After these checks pass, proceed to `docs/LAB_CHECKLIST.md`.

---

## 33. Official references

These are the primary references used for the installation design. Prefer official documentation over third-party tutorials when versions or behavior differ.

- Docker Desktop on Windows: https://docs.docker.com/desktop/setup/install/windows-install/
- Docker Desktop WSL 2 backend: https://docs.docker.com/desktop/features/wsl/
- Docker development with WSL 2: https://docs.docker.com/desktop/features/wsl/use-wsl/
- Apache Hop Docker container: https://hop.apache.org/tech-manual/latest/docker-container.html
- Apache Hop Web: https://hop.apache.org/manual/latest/hop-gui/hop-web.html
- Apache Hop database plugins/JDBC drivers: https://hop.apache.org/manual/latest/database/databases.html
- Apache Hop MariaDB database support: https://hop.apache.org/manual/latest/database/databases/mariadb.html
- MariaDB Connector/J release notes: https://mariadb.com/docs/release-notes/connectors/java/3.5/3.5.8
- PostgreSQL official container image: https://hub.docker.com/_/postgres
- MinIO documentation: https://min.io/docs/
- Apache Superset Docker Compose: https://superset.apache.org/admin-docs/installation/docker-compose/

---

## 34. Next document

After installation, continue with:

```text
docs/LAB_CHECKLIST.md
```

The main `README.md` explains the architecture, data model, ETL exercises, incremental loading, SCD Type 2, MinIO zones, Superset dashboards, PostgreSQL performance work, and AWS migration roadmap.
