# CIS Deployment - Jenkins + SonarQube + Nexus CI/CD Setup

Complete step-by-step guide to build, scan, quality-gate, and store Docker images for the CIS application.

**Your environment (Docker containers on QA-Testing server):**

| Tool            | URL / Address                    | Container internal |
|-----------------|----------------------------------|--------------------|
| Jenkins         | http://192.168.0.125:8012        | 8080               |
| SonarQube       | http://192.168.0.125:8032        | 9000               |
| Nexus UI        | http://192.168.0.125:8002        | 8081               |
| Nexus Docker    | 192.168.0.125:8003               | 8082               |

> **Important:** Do NOT use ports `9002` or `8082` in browser — those are wrong for this server.
> Your compose files are at `/opt/dependencies/jenkins`, `/opt/dependencies/sonarqube`, `/opt/dependencies/nexus`.

**Pipeline flow:**
```
Git Checkout → Validate JARs → SonarQube Scan → Quality Gate → Build Docker Images → Push to Nexus
```

---

## Part 1: Docker-based setup (Jenkins runs IN Docker)

Jenkins, SonarQube, and Nexus are all **Docker containers**. There is NO `jenkins` Linux user and NO `jenkins.service` on the host.

### 1.1 Configure host Docker for Nexus push

On the **host** (not inside Jenkins), edit `/etc/docker/daemon.json`:

```json
{
  "insecure-registries": ["192.168.0.125:8003"]
}
```

Then restart host Docker:

```bash
sudo systemctl restart docker
```

### 1.2 Rebuild Jenkins container with Docker CLI + SonarQube scanner

Copy the updated Jenkins files and rebuild:

```bash
# Get docker group ID on host
export DOCKER_GID=$(getent group docker | cut -d: -f3)

# Copy new Jenkins Dockerfile + compose into your jenkins folder
sudo cp -r /opt/deployment/CIS-Deployment/ci/jenkins/* /opt/dependencies/jenkins/

# Rebuild and restart Jenkins
cd /opt/dependencies/jenkins
sudo -E docker compose up -d --build
```

Or run the helper script:

```bash
sudo /opt/deployment/CIS-Deployment/ci/setup-host.sh
```

This gives Jenkins:
- Access to host Docker via `/var/run/docker.sock` (build & push images)
- `sonar-scanner` CLI inside the container
- Mount of `/opt/deployment` for local builds

### 1.3 Verify containers are running

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}\t{{.Status}}'
```

Expected:
```
jenkins     0.0.0.0:8012->8080/tcp
sonarqube   0.0.0.0:8032->9000/tcp
nexus       0.0.0.0:8002->8081/tcp, 0.0.0.0:8003->8082/tcp
```

### 1.4 Ensure JAR files exist

This repo is a **deployment** repo. JAR files are required locally but are gitignored.

Copy JARs to the workspace before first build, or place them permanently:

```
CIS-Deployment/cisBackend/DragerCISBackend-0.0.1-SNAPSHOT.jar
CIS-Deployment/connectEngine/device-connect-engine-0.0.1-SNAPSHOT.jar
CIS-Deployment/visualizationEngine/device-visualization-engine-0.0.1-SNAPSHOT.jar
CIS-Deployment/deviceSimulation/device-simulation-0.0.1-SNAPSHOT.jar
```

---

## Part 2: SonarQube Setup

### 2.1 Login and create admin account

1. Open http://192.168.0.125:8032
2. Default login: `admin` / `admin` (change password when prompted)

### 2.2 Create project

1. Click **"Create a local project"** (bottom of project creation page)
2. **Project name:** `CIS Deployment`
3. **Project key:** `cis-deployment` (must match `sonar-project.properties`)
4. **Main branch:** `main` or `master`
5. Click **Set Up**

### 2.3 Generate SonarQube token

1. Choose **"Locally"** as analysis method
2. Generate a token, e.g. `jenkins-cis-token`
3. **Save this token** — you will add it to Jenkins

### 2.4 Configure Quality Gate

1. Go to **Quality Gates** (top menu)
2. Click **Create**
3. Name: `CIS Quality Gate`
4. Add conditions (click **Add Condition**):

| Metric                    | Operator | Value |
|---------------------------|----------|-------|
| Coverage                  | is less than | 0% (or 60% if you add tests later) |
| Bugs on New Code          | is greater than | 0 |
| Vulnerabilities on New Code | is greater than | 0 |
| Code Smells on New Code   | is greater than | 10 |
| Security Hotspots Reviewed | is less than | 100% |

5. Click **Set as Default** (or assign to project in step 2.5)

### 2.5 Assign Quality Gate to project

1. Go to **Projects** → **CIS Deployment**
2. **Project Settings** (gear icon) → **Quality Gate**
3. Select **CIS Quality Gate**

### 2.6 (Optional) Create custom Quality Profile for Java

1. Go to **Quality Profiles** → **Create**
2. Language: Java, Name: `CIS Java Profile`
3. Set as default for Java projects

---

## Part 3: Nexus Setup

### 3.1 Login

1. Open http://192.168.0.125:8002
2. Click **Sign in** (top right)
3. Default: `admin` and password from `/nexus-data/admin.password` on Nexus container

### 3.2 Verify Docker hosted repository

You already have `docker-hosted`. Verify settings:

1. **Settings (gear)** → **Repositories** → **docker-hosted**
2. **HTTP** connector: internal port `8082`, exposed on host as `8003`
5. **Deployment policy**: Allow redeploy (for CI/CD)

`NEXUS_PORT` in `Jenkinsfile` is already set to `8003`.

### 3.3 Create Nexus user for Jenkins

1. **Settings** → **Security** → **Users** → **Create local user**
2. **User ID:** `jenkins`
3. **Password:** (strong password)
4. **Roles:** `nx-admin` (or create custom role with `nx-repository-view-docker-*-*` permissions)

### 3.4 Test Docker login manually

```bash
docker login 192.168.0.125:8003 -u admin
# Enter password
docker logout 192.168.0.125:8003
```

---

## Part 4: Jenkins Setup

### 4.1 Install Jenkins plugins

1. Open http://192.168.0.125:8012
2. **Manage Jenkins** → **Plugins** → **Available plugins**
3. Install and restart:

| Plugin | Purpose |
|--------|---------|
| Pipeline | Jenkinsfile support |
| Git | Source checkout |
| Docker Pipeline | Docker build steps |
| SonarQube Scanner | Code analysis |
| SonarQube Quality Gates | Wait for quality gate |
| Credentials Binding | Secure credentials |

### 4.2 Configure SonarQube server in Jenkins

1. **Manage Jenkins** → **System** → **SonarQube servers**
2. Click **Add SonarQube**
3. **Name:** `SonarQube` (must match Jenkinsfile `withSonarQubeEnv('SonarQube')`)
4. **Server URL:** `http://192.168.0.125:8032`
5. **Server authentication token:** Add credential → Secret text → paste SonarQube token from step 2.3
6. Save

### 4.3 Configure SonarQube Scanner tool

1. **Manage Jenkins** → **Tools**
2. **SonarQube Scanner installations** → **Add SonarQube Scanner**
3. Name: `SonarQubeScanner`
4. Either install automatically or set path: `/opt/sonar-scanner-5.0.1.3006-linux`
5. Save

### 4.4 Add Nexus Docker credentials

1. **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. **Add Credentials**
3. Kind: **Username with password**
4. **ID:** `nexus-docker-credentials` (must match Jenkinsfile)
5. Username: `jenkins`
6. Password: Nexus password from step 3.3
7. Save

### 4.5 Create Pipeline Job

1. Jenkins Dashboard → **New Item**
2. Name: `cis-deployment-pipeline`
3. Type: **Pipeline**
4. Click **OK**
5. Under **Pipeline**:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `git@github.com:Inv-Monish-reddy/cis-deployment.git` (or your repo URL)
   - Credentials: add SSH key if private repo
   - Branch: `*/main` or `*/master`
   - Script Path: `Jenkinsfile`
6. Save

### 4.6 Run the pipeline

1. Open job `cis-deployment-pipeline`
2. Click **Build Now**
3. Watch **Console Output**

---

## Part 5: Files Created in This Repo

| File | Purpose |
|------|---------|
| `Jenkinsfile` | Full CI/CD pipeline definition |
| `sonar-project.properties` | SonarQube scan configuration |
| `CIS-Deployment/nginx/Dockerfile.ci` | Nginx image with baked frontend for Nexus |
| `CICD-SETUP.md` | This setup guide |

---

## Part 6: What Gets Stored in Nexus

After a successful build, these images appear in `docker-hosted`:

```
192.168.0.125:8003/cis-backend:<build>-<commit>
192.168.0.125:8003/cis-connect-engine:<build>-<commit>
192.168.0.125:8003/cis-visualization-engine:<build>-<commit>
192.168.0.125:8003/cis-device-simulation:<build>-<commit>
192.168.0.125:8003/cis-nginx:<build>-<commit>
```

Each also has a `:latest` tag.

Browse in Nexus: **Browse** → **docker-hosted**

---

## Part 7: Deploy from Nexus (pull images)

On any deployment server:

```bash
docker login 192.168.0.125:8003 -u admin

docker pull 192.168.0.125:8003/cis-backend:latest
docker pull 192.168.0.125:8003/cis-connect-engine:latest
docker pull 192.168.0.125:8003/cis-visualization-engine:latest
docker pull 192.168.0.125:8003/cis-device-simulation:latest
docker pull 192.168.0.125:8003/cis-nginx:latest
```

Update `docker-compose.yml` to use Nexus images instead of `build:`:

```yaml
critixperticubackendengine:
  image: 192.168.0.125:8003/cis-backend:latest
  # remove build: line
```

---

## Part 8: Troubleshooting

### Quality Gate fails
- Open SonarQube → **Projects** → **CIS Deployment** → check issues
- Relax gate conditions temporarily while setting up
- Ensure `sonar-project.properties` exclusions are correct

### Docker push denied
- Verify `insecure-registries` in Docker daemon
- Check Nexus user has push permissions
- Confirm Docker connector port in Nexus matches `NEXUS_PORT` in Jenkinsfile

### JAR not found
- JARs are gitignored; copy them to Jenkins workspace manually or from build server
- Consider adding a Maven/raw repository in Nexus for JAR storage

### SonarQube scanner not found
- Install sonar-scanner on Jenkins agent (Part 1.1)
- Or configure in Jenkins Tools (Part 4.3)

### Jenkins cannot connect to SonarQube
- Check firewall: port 8032 open between Jenkins container and SonarQube
- Verify SonarQube token is valid

---

## Quick Checklist

- [ ] Host `/etc/docker/daemon.json` has `192.168.0.125:8003` in insecure-registries
- [ ] Jenkins container rebuilt with `ci/jenkins/Dockerfile` (docker CLI + sonar-scanner)
- [ ] All 3 containers running: jenkins (8012), sonarqube (8032), nexus (8002/8003)
- [ ] SonarQube project `cis-deployment` created
- [ ] Quality Gate created and assigned
- [ ] SonarQube token added to Jenkins
- [ ] Nexus `docker-hosted` repository ready
- [ ] Nexus credentials `nexus-docker-credentials` in Jenkins
- [ ] Jenkins plugins installed
- [ ] Pipeline job created pointing to `Jenkinsfile`
- [ ] JAR files present in workspace
- [ ] First build run successfully
