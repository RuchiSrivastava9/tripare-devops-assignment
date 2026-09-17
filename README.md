# Tripare.ai DevOps Assessment

Terraform + AWS ECS/Fargate/RDS design, plus a local PostgreSQL backup/restore exercise.

## Architecture

Internet -> Application Load Balancer (public subnets) -> ECS Fargate service (private subnets) -> RDS PostgreSQL (private subnets)

The ALB is the only public entry point. ECS accepts application traffic only from the ALB security group. RDS accepts PostgreSQL traffic only from the ECS security group.

## Repository structure

```text
.
├── infra/
│   ├── modules/
│   │   ├── network/
│   │   ├── ecs/
│   │   └── rds/
│   └── envs/
│       ├── dev/
│       └── prod/
├── db/
│   ├── migrations/
│   │   ├── 001_init.sql
│   │   └── 002_indexes.sql
│   └── seed/
│       └── 003_seed.sql
├── scripts/
│   ├── backup.sh
│   └── restore.sh
└── .github/workflows/terraform.yml
```

## Part 1/2 - Terraform

The two environments share the same modules but have different sizing and operational settings.

### Dev

- smaller ECS service and RDS instance
- one NAT gateway to keep the example cheaper
- shorter backup retention
- deletion protection disabled
- single-AZ RDS

### Prod

- larger ECS service and RDS instance
- NAT gateway per AZ for better availability
- longer backup retention
- deletion protection enabled
- Multi-AZ RDS

### State

Each environment has its own S3 backend configuration and state key. The backend configuration is intentionally separate from the application variables. Create the S3 state bucket before using the real backend. For review without AWS state, use `terraform init -backend=false`.

The S3 backend uses native S3 state locking with `use_lockfile = true`. Bucket versioning should also be enabled on the state bucket.

### Local Terraform review

From `infra/envs/dev`:

```bash
terraform init -backend=false
terraform fmt -check -recursive ../../modules
terraform fmt -check
terraform validate
terraform plan -refresh=false -var-file=terraform.tfvars
```

Repeat from `infra/envs/prod`. After the first `terraform init`, commit the generated `.terraform.lock.hcl` file so provider selections are reproducible.

For a real AWS run, configure credentials through the AWS CLI/environment and use the backend configuration after the state bucket exists.

## Part 3 - GitHub Actions

The workflow runs on pull requests and validates both environments. It uses the HashiCorp `setup-terraform` action and uploads a human-readable plan as an artifact. It initializes with `-backend=false` so the assignment can be reviewed without creating a remote state bucket. The environment `terraform.tfvars` files set `plan_only = true`; this supplies mock provider credentials and skips credential/account metadata checks for the assignment plan. A real deployment should set `plan_only = false` and authenticate to AWS.

A real deployment pipeline should use GitHub OIDC to assume an AWS IAM role rather than long-lived AWS access keys.

## Part 4 - Local PostgreSQL

Start the database:

```bash
docker compose up -d db
```

The SQL files are executed only when the PostgreSQL volume is initialized for the first time. To rebuild the sample database from scratch, use `docker compose down -v` and start it again.

The PostgreSQL image automatically runs the files in `db/migrations` and `db/seed` on the first initialization of the database volume.

Verify:

```bash
docker compose exec db psql -U postgres -d hotel_db -c "SELECT COUNT(*) AS booking_count FROM hotel_bookings;"
docker compose exec db psql -U postgres -d hotel_db -c "SELECT city, status, COUNT(*) FROM hotel_bookings GROUP BY city, status ORDER BY city, status;"
```

Expected booking count: at least 100 (this example creates 120).

## Query optimization

The assessment query filters by an exact `city` and a range on `created_at`:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

The main index is:

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at);
```

`city` is first because it is an equality predicate, followed by `created_at` because it is a range predicate. This lets PostgreSQL narrow the candidate rows before the grouping step. I intentionally did not add `status` to the filtering portion of the index because the query does not filter on `status`.

For the booking event table, `booking_id` is indexed because it is the natural lookup/join key.

To compare the plan before/after indexing in a real database, use:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

The important thing to look for is whether the index is used and how many rows/heap blocks are touched. Exact plan output depends on data distribution and PostgreSQL statistics.

## Part 6 - Backup and restore

### Backup

```bash
./scripts/backup.sh
```

This creates a timestamped PostgreSQL custom-format dump under `backups/`.

### Restore into a fresh local database

```bash
./scripts/restore.sh backups/hotel_db_YYYYMMDD_HHMMSS.dump
```

The restore script creates a fresh database named `hotel_db_restore`, restores the dump into it, and then verifies the booking count.

You can also verify manually:

```bash
docker compose exec db psql -U postgres -d hotel_db_restore -c "SELECT COUNT(*) FROM hotel_bookings;"
docker compose exec db psql -U postgres -d hotel_db_restore -c "SELECT COUNT(*) FROM booking_events;"
```

## Notes

- No AWS deployment is required for this assessment.
- No AWS credentials or database secrets are committed to the repository.
- The RDS module uses a Terraform-generated password only for this assessment example. For a real production implementation, I would use RDS-managed credentials/Secrets Manager instead of storing a database password in Terraform state.
- The ECS container uses Nginx as a simple placeholder application because the assessment is evaluating infrastructure rather than application code.
