# Jenkins Setup and Configuration Guide

## Quick Start

### 1. Install Jenkins Plugins

In Jenkins UI: **Manage Jenkins** → **Manage Plugins** → **Available Plugins**

Install these plugins:
```
Pipeline
Docker Pipeline
Kubernetes CLI
Git
Timestamps
AnsiColor (for colored logs)
Log Parser Plugin (optional)
Email Extension Plugin (optional)
Slack Notification Plugin (optional)
```

### 2. Create Jenkins Credentials

#### Docker Registry Credentials
1. Go to **Manage Jenkins** → **Manage Credentials** → **Global credentials**
2. Click **Add Credentials**
3. Kind: `Username with password`
4. ID: `docker-registry-credentials`
5. Username: Your Docker Hub username
6. Password: Your Docker Hub access token
7. Click **Create**

#### Kubernetes Config (if needed)
1. Go to **Manage Jenkins** → **Manage Credentials** → **Global credentials**
2. Click **Add Credentials**
3. Kind: `Secret file`
4. ID: `kubeconfig`
5. File: Upload your kubeconfig file
6. Click **Create**

### 3. Create Jenkins Job

1. Click **New Item**
2. Enter name: `online-shopping-system`
3. Select **Pipeline**
4. Click **OK**
5. In **Pipeline** section:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/yourusername/online-shopping-system.git`
   - Credentials: Select appropriate credentials
   - Branch: `*/main` or `*/master`
   - Script Path: `Jenkinsfile`
6. Click **Save**

### 4. Configure Build Triggers (Optional)

To automatically trigger builds on git push:

1. In job configuration, scroll to **Build Triggers**
2. Check **GitHub hook trigger for GITScm polling** (if using GitHub)
3. Or check **Poll SCM** with schedule: `H/5 * * * *` (every 5 minutes)
4. Click **Save**

### 5. Configure Agent (If using agents)

On the Jenkins agent machine:
```bash
# Install Docker
sudo apt-get install docker.io
sudo usermod -aG docker jenkins

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Configure kubeconfig
mkdir ~/.kube
# Copy your kubeconfig file
cp kubeconfig ~/.kube/config
chmod 600 ~/.kube/config

# Restart Docker daemon
sudo systemctl restart docker
```

## Environment Setup

### Linux/Mac Agent Setup

```bash
#!/bin/bash
# setup-jenkins-agent.sh

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker jenkins

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install PHP CLI for syntax checking
sudo apt-get install -y php-cli php-mysql

# Install Trivy for vulnerability scanning (optional)
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

# Install jq for JSON parsing
sudo apt-get install -y jq

echo "Jenkins agent setup completed!"
```

## Jenkins Configuration as Code (JCasC)

If you want to automate Jenkins setup, create a `jenkins-casc.yaml`:

```yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false
  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: "admin"
            permissions:
              - "Overall/Administer"
          - name: "developer"
            permissions:
              - "Job/Build"
              - "Job/Read"

credentials:
  system:
    domainCredentials:
      - credentials:
          - username: "${DOCKER_USER}"
            password: "${DOCKER_PASS}"
            id: "docker-registry-credentials"
            description: "Docker registry credentials"
            scope: GLOBAL

unclassified:
  location:
    url: "http://jenkins.example.com/"
  timestamper:
    allPipelines: true
```

## Docker Setup for Jenkins

### Jenkins with Docker Support

Create a `docker-compose.yml` for Jenkins:

```yaml
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:lts
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - /usr/bin/docker:/usr/bin/docker
    environment:
      - JENKINS_OPTS=--httpPort=8080
    container_name: jenkins

volumes:
  jenkins_home:
```

Start Jenkins:
```bash
docker-compose up -d
```

Access Jenkins at: `http://localhost:8080`

Get initial admin password:
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## Monitoring and Logs

### View Build Logs
```bash
# Jenkins UI: Job → Build # → Console Output
# Or via CLI:
curl -s http://localhost:8080/job/online-shopping-system/1/consoleText
```

### View Agent Logs
```bash
# On agent machine
tail -f /var/log/syslog | grep jenkins
docker logs -f <jenkins-container-name>
```

### Health Check
```bash
# Jenkins is running
curl -s http://localhost:8080/api/json | jq '.nodeName'

# Check connected agents
curl -s http://localhost:8080/api/json | jq '.computer[] | {name: .displayName, offline: .offline}'
```

## Performance Optimization

### Jenkins Configuration

1. **Increase Java Heap**:
   Edit Jenkins startup script:
   ```bash
   export JAVA_OPTS="-Xmx4g -Xms2g"
   ```

2. **Configure Pipeline Timeout**:
   ```groovy
   options {
       timeout(time: 1, unit: 'HOURS')
   }
   ```

3. **Enable Concurrent Builds**:
   ```groovy
   options {
       disableConcurrentBuilds(false)
   }
   ```

4. **Clean Workspace Before Build**:
   ```groovy
   options {
       skipDefaultCheckout()
   }
   ```

## Backup and Disaster Recovery

### Backup Jenkins Configuration

```bash
#!/bin/bash
# backup-jenkins.sh

BACKUP_DIR="/backups/jenkins"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup Jenkins home
tar -czf $BACKUP_DIR/jenkins_home_$DATE.tar.gz /var/jenkins_home

# Keep only last 7 backups
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/jenkins_home_$DATE.tar.gz"
```

### Restore Jenkins Configuration

```bash
#!/bin/bash
# restore-jenkins.sh

BACKUP_FILE=$1
JENKINS_HOME=/var/jenkins_home

# Stop Jenkins
systemctl stop jenkins

# Restore backup
tar -xzf $BACKUP_FILE -C /

# Restore permissions
chown -R jenkins:jenkins $JENKINS_HOME

# Start Jenkins
systemctl start jenkins

echo "Jenkins restored from $BACKUP_FILE"
```

## CI/CD Metrics

Monitor these metrics for pipeline health:

1. **Build Duration**: Should be consistent
2. **Success Rate**: Aim for >95%
3. **Deployment Frequency**: How often you deploy
4. **Lead Time**: From code commit to deployment
5. **Mean Time to Recovery**: When failures occur

View in Jenkins:
- **Manage Jenkins** → **Jenkins Metrics**
- Or use Prometheus + Grafana

## Troubleshooting Common Issues

### Issue: "permission denied while trying to connect to the Docker daemon"

Solution:
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
sudo systemctl restart docker
```

### Issue: "kubectl command not found"

Solution:
```bash
export PATH=$PATH:/usr/local/bin
# Or add to agent startup script
```

### Issue: "Cannot pull from Docker registry"

Solution:
```bash
# Test credentials
docker login -u username -p password docker.io

# Verify in Jenkins
docker login docker.io
```

### Issue: "Pod is not becoming ready"

Solution:
```bash
kubectl describe pod -n <namespace> <pod-name>
kubectl logs -n <namespace> <pod-name>
```

## Advanced Configuration

### Parallel Execution

Modify Jenkinsfile to run stages in parallel:

```groovy
stage('Parallel Tests') {
    parallel {
        stage('Unit Tests') {
            steps {
                sh 'phpunit'
            }
        }
        stage('Security Scan') {
            steps {
                sh 'trivy scan .'
            }
        }
        stage('Code Quality') {
            steps {
                sh 'phpcs .'
            }
        }
    }
}
```

### Matrix Builds

Test across multiple configurations:

```groovy
matrix {
    axes {
        axis {
            name 'PHP_VERSION'
            values '7.4', '8.0', '8.1', '8.2'
        }
        axis {
            name 'MYSQL_VERSION'
            values '5.7', '8.0'
        }
    }
}
```

### Conditional Stages

```groovy
stage('Deploy') {
    when {
        branch 'main'
        environment name: 'DEPLOY_ENABLED', value: 'true'
    }
    steps {
        sh 'kubectl apply -f k8s/'
    }
}
```

## Support Resources

- [Jenkins Official Documentation](https://www.jenkins.io/doc/)
- [Jenkins Configuration as Code](https://plugins.jenkins.io/configuration-as-code/)
- [Jenkins Plugins Directory](https://plugins.jenkins.io/)
- [Pipeline Syntax Reference](https://www.jenkins.io/doc/book/pipeline/syntax/)
