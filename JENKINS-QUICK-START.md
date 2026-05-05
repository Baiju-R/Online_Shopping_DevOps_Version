# Jenkins Integration - Quick Start for Your Running Website

Your website is running at: **http://localhost:8000/**

Jenkins will help you automate testing, security scanning, and deployments.

---

## ⚡ 5-Minute Setup

### 1. Open WSL Terminal
```powershell
# In PowerShell:
wsl
```

### 2. Start Docker (one-time setup)
```bash
# Install Docker (first time only)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo service docker start

# Add your user to docker group (one-time)
sudo usermod -aG docker $USER
```

### 3. Start Jenkins Container
```bash
# Create data directory
mkdir -p ~/jenkins_data

# Run Jenkins
sudo docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v ~/jenkins_data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Wait 30 seconds then get admin password
sleep 30
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 4. Access Jenkins UI
**URL:** http://localhost:8080
**Paste:** Admin password from step 3

### 5. Complete Setup Wizard
- ✓ Install suggested plugins
- ✓ Create admin user
- ✓ Save and finish

---

## 📋 Create Your First Pipeline Job

### In Jenkins UI:

1. **Click:** "New Item"
2. **Name:** `online-shopping-system`
3. **Type:** Pipeline
4. **Click:** OK

### Configure Pipeline:

**Definition:** Pipeline script from SCM

**SCM:** Git

**Repository URL:**
```
file:///mnt/c/xampp/htdocs/online-shopping-system-master
```

**Branch:** `*/main` (or `*/master` if that's your branch)

**Script Path:** `Jenkinsfile-local` (for local testing) or `Jenkinsfile` (for Docker/K8s)

**Click:** Save

---

## 🚀 Run Your First Build

1. **Click:** "Build Now"
2. **Watch:** Console output in real-time
3. **Review:** Reports at the end

### What It Will Do:

✅ Check PHP syntax  
✅ Scan for security issues  
✅ Run tests (if PHPUnit installed)  
✅ Health check your website at http://localhost:8000  
✅ Generate detailed reports  

---

## 📊 View Build Reports

After build completes:

1. **Click:** Build number (e.g., "#1")
2. **Click:** "Console Output" (full logs)
3. **Reports location:** `${WORKSPACE}/reports/`

### Available Reports:
- `build-summary.txt` - Overall summary
- `code-stats.txt` - Lines of code analysis
- `security/` - Security findings
- `tests/` - Test results (if applicable)
- `git-info.txt` - Git commit info

---

## 💡 Jenkinsfile Options

You have **two Jenkinsfile versions**:

### `Jenkinsfile-local` (Recommended for Now)
- ✓ Optimized for local development
- ✓ Tests your running website at localhost:8000
- ✓ Faster builds
- ✓ Uses local file system
- **Use this for:** Quick testing, development, CI pipeline

### `Jenkinsfile` (Full Featured)
- ✓ Docker image building
- ✓ Kubernetes deployment
- ✓ Registry push
- ✓ Production-ready
- **Use this for:** Production, Docker, cloud deployment

---

## 🔧 Common Tasks

### Trigger Build on Git Commit (GitHub/GitLab)

1. In Jenkins job, go to **Build Triggers**
2. Enable: **GitHub hook trigger** OR **Poll SCM**
3. In your repository, add webhook pointing to: `http://your-jenkins-server:8080/github-webhook/`

### View Jenkins Logs
```bash
sudo docker logs -f jenkins
```

### Stop Jenkins
```bash
sudo docker stop jenkins
```

### Restart Jenkins
```bash
sudo docker restart jenkins
```

### Delete Jenkins (fresh start)
```bash
sudo docker rm -f jenkins
rm -rf ~/jenkins_data
# Then run the docker run command again
```

### Run Jenkins Commands Without Docker
If you prefer native Jenkins without Docker, install it directly in WSL.

---

## 📝 Your Jenkinsfile-local Configuration

**Build Parameters:**
```
RUN_TESTS: true/false          # Run PHP unit tests
SECURITY_SCAN: true/false      # Run security checks
BUILD_DOCKER: true/false       # Build Docker image
DEPLOY_PATH: [path]            # Where to deploy
```

**Stages:**
1. Initialization - Setup
2. Checkout - Get source code
3. Code Quality - PHP syntax check
4. Dependency Check - Critical files
5. PHP Unit Tests - If available
6. Security Scanning - Look for vulnerabilities
7. Build Docker Image - Optional
8. Health Check - Test localhost:8000
9. Generate Reports - Create summaries

**Reports Generated:**
```
reports/
├── build-summary.txt
├── code-stats.txt
├── git-info.txt
├── security/
│   ├── possible-credentials.txt
│   ├── sql-risks.txt
│   ├── xss-risks.txt
│   └── dangerous-functions.txt
├── tests/
│   └── phpunit.xml
└── files-listing.txt
```

---

## 🐛 Troubleshooting

### "Cannot connect to http://localhost:8080"
```bash
# Check if Jenkins container is running
sudo docker ps | grep jenkins

# View logs
sudo docker logs jenkins

# Restart if needed
sudo docker restart jenkins
```

### "Cannot reach http://localhost:8000"
```bash
# Make sure XAMPP is running
xampp start

# Or start Apache manually
sudo service apache2 start
```

### "Permission denied" errors
```bash
# Fix Docker permissions
sudo usermod -aG docker $USER
# Might need to logout/login or restart WSL
```

### "kubectl command not found"
If you try to deploy to Kubernetes later:
```bash
sudo apt-get install -y kubectl
# Or use Jenkinsfile-local instead
```

### "docker: command not found"
```bash
# Make sure Docker is installed
docker --version

# Start Docker service
sudo service docker start

# Or reinstall
curl -fsSL https://get.docker.com | sh
```

---

## 🎯 Next Steps

After Jenkins is working with `Jenkinsfile-local`:

1. **Add Automated Triggers:**
   - Push to git → Build runs automatically
   - Set up webhook in GitHub/GitLab

2. **Enhance Security:**
   - Review security scan reports
   - Fix any XSS or SQL injection issues
   - Use prepared statements for DB queries

3. **Setup Notifications:**
   - Email alerts on build failures
   - Slack integration
   - Build status badges

4. **Production Deployment:**
   - Use full `Jenkinsfile` with Docker
   - Deploy to Kubernetes
   - Use staging environment first

5. **Monitoring:**
   - Track build metrics
   - Monitor application health
   - Setup dashboards

---

## 📖 Documentation Files

In your repository:
- `Jenkinsfile` - Full CI/CD pipeline (Docker/K8s)
- `Jenkinsfile-local` - Local development pipeline
- `JENKINS-WSL-SETUP.md` - Detailed WSL setup
- `JENKINS-PIPELINE.md` - Pipeline documentation
- `JENKINS-SETUP.md` - Complete setup guide
- `JENKINS-EXAMPLES.md` - Real-world scenarios
- `jenkins-helper-scripts.sh` - Utility functions

---

## ✅ Verification Checklist

- [ ] WSL Ubuntu is running
- [ ] Docker is installed and running
- [ ] Jenkins container is running (port 8080)
- [ ] Jenkins UI is accessible
- [ ] Admin user created
- [ ] Pipeline job created
- [ ] Job configured with correct Jenkinsfile-local
- [ ] First build successful
- [ ] Reports generated
- [ ] Website health check passed

---

## 💬 Need Help?

Common issues are documented in the troubleshooting section above.

For specific errors:
1. Check Jenkins logs: `sudo docker logs jenkins`
2. Review build console output in Jenkins UI
3. Check application logs at: `${WORKSPACE}/logs/build.log`
4. Review security findings: `${WORKSPACE}/reports/security/`

---

**Ready to start? Go to Step 1: Open WSL Terminal** ⬆️
