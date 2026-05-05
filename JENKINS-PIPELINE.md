# Jenkins Pipeline Guide for Online Shopping System

## Overview
This Jenkinsfile provides a complete CI/CD pipeline for the Online Shopping System application, covering:
- Code quality analysis
- Security scanning
- Docker image building and testing
- Kubernetes deployment
- Post-deployment verification

## Prerequisites

### Jenkins Setup
- Jenkins server (v2.361+)
- Jenkins plugins:
  - Pipeline
  - Docker Pipeline
  - Kubernetes CLI
  - Git
  - Timestamps
  - Log Parser (optional)

### System Requirements
- Docker installed on Jenkins agent
- kubectl installed and configured
- Git installed
- PHP CLI (for syntax checking)
- curl (for health checks)

### Credentials Configuration
Add the following credentials to Jenkins:
1. **docker-registry-credentials**: Docker Hub credentials for image push
   - Type: Username with password
   - ID: `docker-registry-credentials`
   - Username: Your Docker Hub username
   - Password: Your Docker Hub password/token

2. **kubeconfig**: Kubernetes configuration (if not using agent's default)
   - Type: Secret file
   - File: Your kubeconfig file

## Pipeline Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| DOCKER_REGISTRY | docker.io | Docker registry URL |
| IMAGE_NAME | online-shopping-system | Docker image name |
| IMAGE_TAG | latest | Docker image tag |
| KUBE_NAMESPACE | default | Kubernetes namespace for deployment |
| DEPLOY_TO_K8S | false | Enable Kubernetes deployment |
| RUN_TESTS | true | Run PHP tests |
| SECURITY_SCAN | true | Run security scans |

## Pipeline Stages

### 1. **Initialization**
- Creates log and report directories
- Verifies tool availability (git, docker, kubectl)

### 2. **Checkout**
- Clones the repository
- Captures git commit information

### 3. **Code Quality Analysis**
- PHP syntax validation
- Code statistics collection
- Security issue detection (eval, exec functions)

### 4. **Dependency Check**
- Checks for composer.json
- Identifies database connection patterns

### 5. **Unit Tests & Integration Tests**
- Runs PHPUnit tests (if available)
- Validates critical files exist
- Generates test reports

### 6. **Security Scanning**
- Detects sensitive strings
- Checks for SQL injection vulnerabilities
- Identifies XSS risks
- Scans for hardcoded credentials

### 7. **Build Docker Image**
- Builds Docker image with tags
- Adds build metadata labels

### 8. **Docker Image Scanning**
- Inspects image layers
- Runs Trivy vulnerability scan (if available)

### 9. **Docker Compose Validation**
- Validates docker-compose.yml syntax
- Ensures configuration is correct

### 10. **Local Docker Test**
- Starts test container
- Verifies container connectivity
- Tests Apache functionality
- Checks container health

### 11. **Kubernetes Manifests Validation**
- Validates all K8s YAML files
- Performs dry-run deployment checks

### 12. **Push to Registry**
- Authenticates with Docker registry
- Pushes image with tags
- Only runs on master/main branch

### 13. **Deploy to Kubernetes**
- Creates namespace if needed
- Updates image references in manifests
- Deploys MySQL database
- Deploys application
- Applies ingress configuration
- Waits for rollout completion

### 14. **Post-Deployment Verification**
- Checks pod status
- Verifies service creation
- Collects pod and MySQL logs

### 15. **Generate Report**
- Creates build summary
- Collects all generated reports

## Environment Variables

```groovy
DOCKER_IMAGE          // Full Docker image path with tag
BUILD_TIMESTAMP       // Build timestamp in format YYYY-MM-DD_HH-MM-SS
WORKSPACE_ROOT        // Jenkins workspace root
LOG_DIR              // Directory for logs
REPORTS_DIR          // Directory for generated reports
```

## Configuration Files

### Expected Project Structure
```
├── Dockerfile              # Docker image definition
├── docker-compose.yml      # Docker Compose configuration
├── config.php              # Application config
├── db.php                  # Database configuration
├── index.php               # Application entry point
├── k8s/                    # Kubernetes manifests
│   ├── app-deployment.yaml
│   ├── app-service.yaml
│   ├── mysql-deployment.yaml
│   ├── mysql-service.yaml
│   ├── mysql-pv.yaml
│   ├── mysql-pvc.yaml
│   └── ingress.yaml
└── database/
    └── onlineshop.sql     # Database schema
```

## Usage Examples

### Build Only (Development)
```
Build Parameters:
- DEPLOY_TO_K8S: false
- RUN_TESTS: true
- SECURITY_SCAN: true
```

### Build and Deploy to Staging
```
Build Parameters:
- DOCKER_REGISTRY: staging-registry.example.com
- IMAGE_TAG: staging
- KUBE_NAMESPACE: staging
- DEPLOY_TO_K8S: true
```

### Production Release
```
Build Parameters:
- DOCKER_REGISTRY: docker.io
- IMAGE_TAG: v1.0.0 (or release-YYYY-MM-DD)
- KUBE_NAMESPACE: production
- DEPLOY_TO_K8S: true
```

## Generated Reports

The pipeline generates various reports in the `reports/` directory:

```
reports/
├── build-summary.txt           # Overall build summary
├── git-info.txt                # Git commit information
├── docker-inspect.json         # Docker image inspection
├── docker-layers.txt           # Docker layer information
├── docker-compose-validated.yml # Validated docker-compose config
├── trivy-scan.txt              # Trivy vulnerability scan results
├── php-errors.log              # PHP syntax errors
├── db-connections.txt          # Database connection count
├── eval-usage.txt              # eval() function usage
├── exec-usage.txt              # exec() function usage
├── security/
│   ├── sensitive-strings.txt   # Potential sensitive data
│   ├── sql-injection-risks.txt # SQL injection vulnerabilities
│   ├── xss-risks.txt           # XSS vulnerability risks
│   └── hardcoded-creds.txt     # Hardcoded credentials
├── tests/
│   └── phpunit.xml             # PHPUnit test results
├── app-logs.txt                # Application pod logs (K8s)
├── mysql-logs.txt              # MySQL pod logs (K8s)
└── failure-debug.txt           # Debug info on failure
```

## Security Best Practices

1. **Secrets Management**:
   - Never commit credentials to the repository
   - Use Jenkins Credentials Store for sensitive data
   - Use environment variables for configuration

2. **Image Security**:
   - Regularly scan Docker images with Trivy
   - Use non-root users in Dockerfile
   - Keep base images updated

3. **Code Security**:
   - Enable SECURITY_SCAN for all builds
   - Review security reports before deployment
   - Use prepared statements for SQL queries
   - Validate and sanitize user inputs

4. **Kubernetes Security**:
   - Use resource limits and requests
   - Enable RBAC
   - Use network policies
   - Regularly update Kubernetes

## Troubleshooting

### Docker Connection Issues
```bash
# Check Docker daemon
docker ps

# Verify Docker socket permissions
ls -la /var/run/docker.sock
```

### Kubernetes Connection Issues
```bash
# Verify kubeconfig
kubectl cluster-info

# Check namespace
kubectl get namespaces

# View pod logs
kubectl logs -n <namespace> <pod-name>
```

### Build Failures
1. Check build logs: `Jenkins UI -> Build -> Console Output`
2. Review generated reports in `reports/` directory
3. Check system resources (disk space, memory)
4. Verify credentials are correctly configured

## Maintenance

### Regular Tasks
- Review security scan reports weekly
- Update Docker base image monthly
- Audit access logs and deployment history
- Clean up old Docker images: `docker image prune -a`

### Scaling
For multiple environments:
1. Create separate Jenkins jobs per environment
2. Use different IMAGE_TAG values
3. Use environment-specific kubeconfig files
4. Configure branch-specific triggers

## Advanced Customization

### Adding Email Notifications
```groovy
post {
    failure {
        emailext (
            to: 'team@example.com',
            subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            body: "Check console output at: ${env.BUILD_URL}"
        )
    }
}
```

### Adding Slack Notifications
```groovy
post {
    always {
        slackSend(
            channel: '#deployments',
            message: "Build ${BUILD_NUMBER}: ${currentBuild.result}"
        )
    }
}
```

### Custom Docker Registry
Update the Dockerfile build stage:
```groovy
sh '''
    docker build \
        --registry custom-registry.com \
        -t custom-registry.com/online-shopping:${BUILD_NUMBER} .
'''
```

## Support and Debugging

For detailed debugging:
1. Enable verbose logging: Add `set -x` to shell blocks
2. Check Jenkins agent system logs
3. Review Docker daemon logs on the agent
4. Verify network connectivity between services

## Additional Resources

- [Jenkins Documentation](https://jenkins.io/doc/)
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [PHP Security Best Practices](https://www.php.net/manual/en/security.php)
