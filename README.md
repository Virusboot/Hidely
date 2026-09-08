# Hidely

Hidely is a privacy-focused mobile application with real-time features, secure authentication, media uploads, and location-based capabilities built with Flutter (mobile client) and Node.js/Express (backend server) connected to a PostgreSQL database hosted on Neon.

---

## Getting Started & Local Development

### Flutter Mobile App Setup
1. Ensure Flutter SDK is installed and configured (`flutter doctor`).
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Configure Google Maps API Key in `android/local.properties`:
   ```properties
   MAPS_API_KEY=YOUR_DEVELOPMENT_MAPS_KEY
   ```
4. Run the app:
   ```bash
   flutter run
   ```

### Backend Setup
1. Navigate to the `backend/` directory:
   ```bash
   cd backend
   ```
2. Install Node.js dependencies:
   ```bash
   npm install
   ```
3. Provision environment variables in `backend/.env` (see Provisioning Matrix below for required variables).
4. Execute database migrations:
   ```bash
   npm run migrate
   ```
5. Start the backend server in development mode:
   ```bash
   npm run dev
   ```

---

## Production Operations Runbook

### 1. Environment Variable Provisioning

Secrets must be stored in the hosting provider's secure environment/secret configuration and must never be committed to Git.

| Variable Name | Purpose | Target Environment / Location | Required? | Commit to Git? |
|---|---|---|---|---|
| `NODE_ENV` | Application environment mode (`production` or `development`). Enables TLS enforcement and strict error masking. | Hosting Provider Env Config | Required | Never |
| `JWT_SECRET` | Secret key used to sign and verify JSON Web Tokens for API authentication. | Hosting Provider Secret Manager | Required | Never |
| `DATABASE_URL` | PostgreSQL connection string including host, user, password, database, and port. | Hosting Provider Secret Manager | Required | Never |
| `PORT` | Server listening port for Express / Socket.IO HTTP server (defaults to 5000 if omitted). | Hosting Provider Env Config | Optional | Never |
| `ALLOWED_ORIGINS` | Comma-separated list of allowed CORS origins for production HTTP and Socket.IO requests. | Hosting Provider Env Config | Optional | Never |
| `CLOUDINARY_CLOUD_NAME` | Cloudinary storage cloud identifier for media upload operations. | Hosting Provider Secret Manager | Required | Never |
| `CLOUDINARY_API_KEY` | Public API identifier key for Cloudinary SDK authentication. | Hosting Provider Secret Manager | Required | Never |
| `CLOUDINARY_API_SECRET` | Private API secret key for signing Cloudinary media requests. | Hosting Provider Secret Manager | Required | Never |
| `GOOGLE_MAPS_API_KEY` | Google Maps Platform API key for geocoding, location lookup, and Android/iOS native maps rendering. | Hosting Provider Secret Manager / `local.properties` | Required | Never |
| `DB_SSL_CA` | Custom CA certificate string or path for custom PostgreSQL TLS validation, if required by the cloud database proxy. | Hosting Provider Secret Manager | Optional | Never |

---

### 2. Database Backup & Recovery Strategy

- **Hosting Architecture**: Production PostgreSQL is hosted on Neon (cloud PostgreSQL platform).
- **Neon-Managed Backup & PITR**: Point-In-Time Restore (PITR) and continuous transaction logging are fully managed by the Neon cloud platform console. Verify current Neon plan and retention settings for exact PITR history window limits.
- **Application-Level Backups**: No custom or automated application-level database dump scripts exist inside the application repository. Disaster recovery relies on Neon-managed database backups.
- **Restore Responsibility**: Operational team members are responsible for initiating database restores via the Neon management console during disaster recovery.
- **Post-Restore Verification**: Following any database restore, the operations team must verify schema structure, migration state in `schema_migrations`, and data integrity before pointing application traffic to the restored database.

---

### 3. Database Restore Procedure

Follow this high-level procedure when recovering from database corruption or data loss:

1. **Identify Incident & Time Window**: Determine the exact timestamp before the data corruption or incident occurred.
2. **Prevent Further Write Traffic**: Temporarily stop or divert application backend traffic if necessary to prevent further destructive writes to the database.
3. **Initiate Neon Console Restore**: Log into the Neon management console and navigate to the production project and database instance.
4. **Target Restoration / Branching**: Use Neon's PITR capability to restore to a new target branch/database at the designated safe recovery timestamp according to Neon platform capabilities.
5. **Verify Schema & Application Data**: Inspect tables, relations, and recent valid records on the restored target database.
6. **Verify Migration State**: Query `SELECT * FROM schema_migrations;` on the restored database to confirm all expected migrations are present and applied.
7. **Update Connection String**: Update `DATABASE_URL` in the hosting provider's secure secret configuration to point to the restored database instance, if required.
8. **Restart / Redeploy Backend**: Restart backend processes to establish connection pool connections to the updated database endpoint.
9. **Run Health Checks & Smoke Tests**: Verify backend database queries, user login, and critical API routes.
10. **Resume Traffic**: Re-enable incoming application traffic once full verification succeeds.

---

### 4. Migration Procedure

- **Version Control**: All database schema changes are versioned as sequential SQL files located in `backend/src/migrations/`.
- **Migration Tracking**: The `schema_migrations` table records all applied migration filenames and execution timestamps.
- **Execution Runner**: Migrations must always be executed using the project's migration runner script:
  ```bash
  npm run migrate
  ```
- **Pre-Production Review**: Schema migration scripts must be peer-reviewed and tested against a staging database prior to production execution.
- **Pre-Migration Recovery Point**: Before running migrations against production, ensure a Neon database recovery point (branch snapshot or PITR window) exists.
- **Manual Schema Modifications**: Never manually execute arbitrary `ALTER` or `DROP` statements directly against the production database unless explicitly authorized, documented, and peer-reviewed.

---

### 5. Secret Rotation Runbook

#### `JWT_SECRET`
- **Effect**: Rotating `JWT_SECRET` immediately invalidates all existing user access tokens signed with the previous secret. Users will be required to re-authenticate (login again).
- **Procedure**: Update `JWT_SECRET` in the hosting provider's environment settings and trigger a backend restart. Note that zero-downtime dual-secret token validation is not currently implemented; all legacy tokens expire upon secret update.

#### `DATABASE_URL` / Database Credentials
- **Procedure**: Update the user password or target database endpoint in the Neon management console, update `DATABASE_URL` in the hosting provider's secret manager, and perform a backend restart so database connection pools reconnect with the new credentials.

#### Cloudinary Credentials (`CLOUDINARY_API_SECRET`, `CLOUDINARY_API_KEY`)
- **Procedure**: Generate new API credentials in the Cloudinary admin dashboard. Update `CLOUDINARY_API_KEY` and `CLOUDINARY_API_SECRET` in the hosting provider environment config. Revoke old credentials in Cloudinary after backend restart and upload verification.

#### Google Maps API Key (`GOOGLE_MAPS_API_KEY` / `MAPS_API_KEY`)
- **Procedure**: Generate a new API key in the Google Cloud Console. Apply API and HTTP/Android package restriction rules. Update `local.properties` (for local builds) or build environment secrets. Rebuild mobile binaries or server environments, then disable the old key in Google Cloud Console.

#### Email Provider Credentials (SMTP / Nodemailer)
- **Procedure**: Generate new app passwords or API credentials in the mail service provider console. Update corresponding environment variables in host secret manager and restart backend services.

---

### 6. Deployment Rollback Strategy

In the event of a critical deployment regression:

1. **Identify Bad Deployment**: Monitor APM, health check failures, or error logs to detect application failures post-deploy.
2. **Stop Rollout**: Cancel any ongoing continuous deployment pipelines or incremental traffic shifts.
3. **Roll Back Application**: Revert application deployment to the last known-good Git release commit or container tag in the hosting provider dashboard.
4. **Evaluate Database Rollback**: Assess database compatibility. Do NOT assume database migrations are automatically reversible unless explicit down-migrations have been validated. Revert or restore database state only if required and safe.
5. **Redeploy Backend**: Deploy the verified previous stable backend build.
6. **Verify API Health**: Execute HTTP checks against the backend root/health endpoint to confirm server startup and DB pool connectivity.
7. **Verify Client Compatibility**: Confirm Flutter mobile app and web clients successfully communicate with the rolled-back API endpoints.
8. **Post-Rollback Monitoring**: Continuously monitor system logs and error rates for at least 30 minutes post-rollback.

---

### 7. Emergency Shutdown & Graceful Recovery

The backend process incorporates native production graceful shutdown handlers (`SIGTERM` and `SIGINT` listeners in `backend/src/server.js`):

- **Signal Interception**: Upon receiving `SIGTERM` (e.g. platform stop request) or `SIGINT` (e.g. Ctrl+C), the process initiates orderly shutdown.
- **Connection Draining**: The Express HTTP and Socket.IO server stops accepting new connections via `server.close()`, allowing active HTTP requests to complete.
- **Database Pool Draining**: The PostgreSQL connection pool is cleanly closed via `db.pool.end()`, terminating active database queries cleanly.
- **Bounded Timeout**: A 10-second safety fallback timeout guarantees process termination if connections fail to drain within the bounded window.
- **Manual Emergency Stop**: To force immediate process termination in emergencies, host managers can issue `SIGKILL` (`kill -9 <PID>`).

---

### 8. Post-Deployment Verification Checklist

Execute this checklist immediately following every production release:

- [ ] Application deployment pipeline completed successfully without build errors.
- [ ] Required production environment variables are provisioned in host secret settings.
- [ ] Backend process starts cleanly and outputs normal initialization logs.
- [ ] Database connection pool connects successfully to production PostgreSQL on Neon.
- [ ] Migration runner (`npm run migrate`) verifies all database migrations are current (`schema_migrations`).
- [ ] Backend HTTP response verified via root API endpoint check.
- [ ] User authentication flow tested successfully (login and token issuance).
- [ ] Media upload endpoint tested successfully against Cloudinary service.
- [ ] Socket.IO real-time connection verified for active clients.
- [ ] Flutter mobile client verified for production API connectivity.
- [ ] Production application logs checked for runtime exceptions or warnings.
- [ ] Application logs inspected to ensure zero exposed secrets or sensitive data.
- [ ] Release tag and rollback point identified in source control.

---

### 9. Operational Security Rules

1. **No Secret Commits**: NEVER commit `.env`, `local.properties`, `.pem`, `.keystore`, `key.properties`, or private key files to source control.
2. **No Hardcoded Secrets**: NEVER hardcode API keys, JWT secrets, passwords, tokens, or DATABASE_URL strings in application source code.
3. **No Secret Exposure in Logs or Issue Trackers**: NEVER paste production credentials into GitHub issues, pull requests, README files, or public chat channels.
4. **No Unsanitized Secret Logging**: NEVER write `JWT_SECRET`, `DATABASE_URL`, or user auth tokens into server logs or error traces.
5. **Secure Configuration Management**: ALWAYS manage production secrets using host-level environment configuration or cloud secret managers.
6. **Key Restriction**: ALWAYS apply IP, HTTP referer, or Android package restrictions to Google Maps API keys in Google Cloud Console.
7. **Immediate Rotation on Exposure**: If any credential or secret is accidentally exposed, immediately rotate the credential across all affected services and update production secret stores.
