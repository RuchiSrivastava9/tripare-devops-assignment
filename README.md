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
└── .github/
    └── workflows/
        └── terraform.yml
```

## Part 1/2 - Terraform

The two environments share the same Terraform modules but use different resource sizing and operational settings.

### Dev

- smaller ECS service and RDS instance
- one NAT gateway to keep the environment simpler and lower cost
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

Each environment has its own Terraform state configuration.

For this assessment, the active `backend.tf` uses a local backend so the Terraform configuration can be initialized and reviewed without requiring an AWS account or remote state bucket.

Example S3 backend configurations are provided as:

- `infra/envs/dev/backend.s3.tf.example`
- `infra/envs/prod/backend.s3.tf.example`

The S3 examples use separate state keys for dev and prod and enable native S3 state locking with `use_lockfile = true`. For a real deployment, the S3 state bucket should have versioning enabled and appropriate access controls.

For the local assessment setup:

```bash
terraform init -reconfigure
terraform validate
terraform plan -refresh=false -var-file=terraform.tfvars
```

### Local Terraform review

Run the following commands from `infra/envs/dev`:

```bash
cd infra/envs/dev
terraform init -reconfigure
terraform fmt -check -recursive ../../modules
terraform fmt -check
terraform validate
terraform plan -refresh=false -var-file=terraform.tfvars
```

Then repeat from `infra/envs/prod`:

```bash
cd ../prod
terraform init -reconfigure
terraform fmt -check -recursive ../../modules
terraform fmt -check
terraform validate
terraform plan -refresh=false -var-file=terraform.tfvars
```

The generated `.terraform.lock.hcl` files are committed so provider selections are reproducible.

For a real AWS deployment, configure AWS credentials and use the S3 backend configuration after the state bucket exists.

## Part 3 - GitHub Actions

The workflow validates both the `dev` and `prod` Terraform environments.

It performs:

- `terraform fmt -check`
- `terraform init`
- `terraform validate`
- `terraform plan`

The workflow uses the local Terraform backend for the assessment environment and initializes it with `terraform init -reconfigure -input=false`, so it can run without requiring a remote S3 state bucket.

The Terraform plan is uploaded as a workflow artifact for review.

For a real AWS deployment, I would use a remote S3 backend and GitHub OIDC to assume an AWS IAM role instead of storing long-lived AWS access keys.

## Part 4 - Local PostgreSQL

Start the database:

```bash
docker compose up -d db
```

The PostgreSQL image initializes the database using the SQL files under `db/migrations` and `db/seed` when the database volume is created for the first time.

To rebuild the sample database from scratch:

```bash
docker compose down -v
docker compose up -d db
```

Verify the booking data:

```bash
docker compose exec db psql -U postgres -d hotel_db -c "SELECT COUNT(*) AS booking_count FROM hotel_bookings;"
```

Check cities and statuses:

```bash
docker compose exec db psql -U postgres -d hotel_db -c "SELECT city, status, COUNT(*) FROM hotel_bookings GROUP BY city, status ORDER BY city, status;"
```

Expected booking count: 120.

The seed data includes multiple cities, organizations, statuses, and booking events.

## Part 5 - Query Optimization

The assessment query is:

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

`city` is first because it is an equality predicate, followed by `created_at` because it is a range predicate. This allows PostgreSQL to narrow the candidate rows before the grouping step.

I did not add `status` to this index because the query does not filter on `status`.

For the booking event table, `booking_id` is indexed because it is the natural lookup and join key.

To inspect the execution plan, use:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

The important things to review are whether PostgreSQL uses the index and how many rows and buffers are accessed. The exact execution plan depends on data distribution and PostgreSQL statistics.

## Part 6 - Backup and Restore

### Backup

```bash
./scripts/backup.sh
```

This creates a timestamped PostgreSQL custom-format dump under `backups/`.

### Restore into a fresh local database

```bash
./scripts/restore.sh backups/hotel_db_YYYYMMDD_HHMMSS.dump
```

The restore script creates a fresh database named `hotel_db_restore`, restores the dump into it, and verifies the restored data.

Manual verification:

```bash
docker compose exec db psql -U postgres -d hotel_db_restore -c "SELECT COUNT(*) FROM hotel_bookings;"
```

```bash
docker compose exec db psql -U postgres -d hotel_db_restore -c "SELECT COUNT(*) FROM booking_events;"
```

The tested restore contained:

- 120 hotel bookings
- 60 booking events

## Notes

- No AWS deployment is required for this assessment.
- No AWS credentials or database secrets are committed to the repository.
- The RDS module generates a random password for this assessment example. For a real production implementation, I would use AWS Secrets Manager or RDS-managed master credentials and avoid managing database passwords directly in Terraform configuration.
- The ECS container uses Nginx as a simple placeholder application because the assessment is evaluating infrastructure rather than application code.
