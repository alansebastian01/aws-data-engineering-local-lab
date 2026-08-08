# Apache Hop project workspace

Save Hop metadata, pipelines (`.hpl`) and workflows (`.hwf`) here so they are
persisted on the host and can be versioned in Git.

Recommended connections:

- `lab_source_mariadb` -> `mariadb:3306/source_db`
- `lab_dw_postgres` -> `postgres:5432/warehouse`
- `lablake` -> `minio:9000`

Recommended structure:

```text
metadata/
pipelines/01_ingestion/
pipelines/02_dimensions/
pipelines/03_facts/
pipelines/04_incremental/
pipelines/05_quality/
workflows/
```
