# Jenkins Pipeline - Practical Examples and Scenarios

## Scenario 1: Development Build (Local Testing)

**Goal**: Build and test locally without deploying to production

**Pipeline Parameters**:
```
DOCKER_REGISTRY: docker.io (or local)
IMAGE_NAME: online-shopping-system
IMAGE_TAG: dev-$(date +%s)
KUBE_NAMESPACE: dev
DEPLOY_TO_K8S: false
RUN_TESTS: true
SECURITY_SCAN: true
```

**Expected Outcomes**:
- ✅ Code quality checks pass
- ✅ Docker image builds successfully
- ✅ Security scan completes
- ✅ Unit tests pass
- ✅ Local container test succeeds
- ✅ No deployment to Kubernetes
- ❌ Image is not pushed to registry

**Typical Build Time**: 10-15 minutes

**Command to Trigger** (if using Jenkins CLI):
```bash
java -jar jenkins-cli.jar -s http://jenkins.example.com/ \
  build online-shopping-system \
  -p DOCKER_TAG=dev-test \
  -p DEPLOY_TO_K8S=false
```

---

## Scenario 2: Staging Deployment

**Goal**: Deploy to staging environment for QA testing

**Pipeline Parameters**:
```
DOCKER_REGISTRY: docker.io
IMAGE_NAME: online-shopping-system
IMAGE_TAG: staging-$(date +%Y%m%d-%H%M%S)
KUBE_NAMESPACE: staging
DEPLOY_TO_K8S: true
RUN_TESTS: true
SECURITY_SCAN: true
```

**Pre-requisites**:
- Docker Hub credentials configured in Jenkins
- Kubernetes cluster accessible with `staging` namespace
- MySQL persistent volume configured

**Expected Outcomes**:
- ✅ All code quality and security checks pass
- ✅ Docker image is built and tested locally
- ✅ Image is pushed to Docker Hub
- ✅ MySQL database is deployed in staging
- ✅ Application pods are running
- ✅ Service endpoints are accessible
- ✅ Health checks pass

**Verification**:
```bash
# Check deployment status
kubectl get deployments -n staging
kubectl get pods -n staging
kubectl get services -n staging

# Access the application
kubectl get svc onlineshop-service -n staging
# Use the EXTERNAL-IP to access http://<ip>

# Check logs
kubectl logs deployment/onlineshop-app -n staging
```

**Typical Build Time**: 20-25 minutes

---

## Scenario 3: Production Release

**Goal**: Full CI/CD pipeline with all checks and production deployment

**Pipeline Parameters**:
```
DOCKER_REGISTRY: docker.io
IMAGE_NAME: online-shopping-system
IMAGE_TAG: v1.0.0 (or release-2024-05-05)
KUBE_NAMESPACE: production
DEPLOY_TO_K8S: true
RUN_TESTS: true
SECURITY_SCAN: true
```

**Pre-requisites**:
- Code on `main` or `master` branch
- Release tag created (v1.0.0)
- All previous staging tests passed
- Security approvals obtained

**Expected Outcomes**:
- ✅ Complete code quality analysis
- ✅ Comprehensive security scanning
- ✅ All tests pass
- ✅ Docker image pushed with version tag
- ✅ MySQL backup taken before deployment
- ✅ Blue-green deployment (new pods) start
- ✅ Traffic gradually shifted to new version
- ✅ Old pods remain for quick rollback

**Deployment Process**:
```bash
# Create release tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# This triggers the Jenkins pipeline
# Monitor in Jenkins UI
```

**Post-Deployment Verification**:
```bash
# Verify deployment
kubectl get deployments -n production
kubectl rollout status deployment/onlineshop-app -n production

# Get application URL
kubectl get ingress -n production

# Monitor health
kubectl top nodes
kubectl top pods -n production
```

**Rollback (if needed)**:
```bash
# Quick rollback to previous version
kubectl rollout undo deployment/onlineshop-app -n production

# Or specific revision
kubectl rollout history deployment/onlineshop-app -n production
kubectl rollout undo deployment/onlineshop-app -n production --to-revision=2
```

**Typical Build Time**: 25-30 minutes

---

## Scenario 4: Hotfix Deployment (Emergency)

**Goal**: Rapidly deploy a critical bug fix to production

**Pipeline Parameters**:
```
DOCKER_REGISTRY: docker.io
IMAGE_NAME: online-shopping-system
IMAGE_TAG: v1.0.1-hotfix
KUBE_NAMESPACE: production
DEPLOY_TO_K8S: true
RUN_TESTS: true (full tests)
SECURITY_SCAN: true
```

**Process**:
1. **Create hotfix branch**:
   ```bash
   git checkout -b hotfix/critical-payment-bug main
   # Make fixes
   git commit -m "Fix: Critical payment processing bug"
   ```

2. **Trigger Pipeline**:
   ```bash
   # Push hotfix branch
   git push origin hotfix/critical-payment-bug
   
   # Jenkins detects hotfix branch and runs pipeline
   ```

3. **Fast-track Testing**:
   - Focus on affected areas only
   - Run critical path tests
   - Skip non-critical checks if needed

4. **Deploy**:
   ```bash
   # Merge to main after approval
   git checkout main
   git merge hotfix/critical-payment-bug
   git tag v1.0.1
   git push origin main --tags
   ```

**Typical Build Time**: 15-20 minutes (prioritized)

---

## Scenario 5: Database Migration with Deployment

**Goal**: Deploy new code with database schema changes

**Preparation Script** (to run before deployment):
```bash
#!/bin/bash

# Backup current database
kubectl exec -it <mysql-pod> -n production -- \
  mysqldump -u root -pROOT_PASSWORD onlineshop > backup_pre_migration.sql

# Run migration scripts
kubectl exec -it <mysql-pod> -n production -- \
  mysql -u root -pROOT_PASSWORD onlineshop < database/migrations/add_product_ratings.sql

# Verify migration
kubectl exec -it <mysql-pod> -n production -- \
  mysql -u root -pROOT_PASSWORD -e "SHOW TABLES IN onlineshop;"
```

**Pipeline Execution**:
- Same as production release (Scenario 3)
- Database migration happens in `database/` initialization scripts

**Post-Migration Verification**:
```bash
# Check new tables exist
kubectl exec -it mysql-0 -n production -- \
  mysql -u root -pROOT_PASSWORD -e "DESCRIBE onlineshop.product_ratings;"

# Verify data integrity
kubectl exec -it mysql-0 -n production -- \
  mysql -u root -pROOT_PASSWORD -e "SELECT COUNT(*) FROM onlineshop.products;"
```

---

## Scenario 6: Multi-Environment Testing

**Goal**: Test across multiple PHP and MySQL versions

**Jenkinsfile Modification** (Matrix Build):
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

stages {
    stage('Build') {
        steps {
            sh '''
                docker build \
                    --build-arg PHP_VERSION=${PHP_VERSION} \
                    --build-arg MYSQL_VERSION=${MYSQL_VERSION} \
                    -t online-shopping:${PHP_VERSION}-mysql${MYSQL_VERSION} .
            '''
        }
    }
}
```

**Result**:
- Tests all combinations (4 PHP × 2 MySQL = 8 builds)
- Identifies version compatibility issues
- Ensures broad platform support

---

## Scenario 7: Performance Testing

**Goal**: Run load tests on staging before production

**Add to Jenkinsfile**:
```groovy
stage('Performance Test') {
    when {
        expression { params.RUN_PERF_TESTS == true }
    }
    steps {
        script {
            sh '''
                # Install Apache Bench
                apt-get install -y apache2-utils
                
                # Run load test
                ab -n 1000 -c 10 http://staging-app-service:80/index.php > reports/load-test.txt
                
                # Parse results
                grep "Requests per second" reports/load-test.txt
            '''
        }
    }
}
```

**Monitor Results**:
```bash
# View performance metrics
kubectl top pods -n staging
kubectl top nodes

# Check response times in logs
kubectl logs deployment/onlineshop-app -n staging | grep "response_time"
```

---

## Scenario 8: Scheduled Nightly Builds

**Jenkins Job Configuration** (Build Trigger):
```
Poll SCM: H 2 * * * (2 AM every day)
```

**Purpose**:
- Detect integration issues early
- Run comprehensive security scans
- Test against latest dependencies
- Generate nightly reports

**Pipeline Modification**:
```groovy
when {
    // Only full scan on scheduled builds
    expression { 
        env.BUILD_CAUSE_UPSTREAM_CAUSE == null
    }
}

stages {
    stage('Comprehensive Scanning') {
        steps {
            sh '''
                # Run all security tools
                trivy fs --format json --output trivy-fs-scan.json .
                grype . --output json > grype-scan.json
                
                # Run all tests
                phpunit --coverage-html coverage-report
            '''
        }
    }
}
```

---

## Scenario 9: Automated Rollback on Failure

**Add to Jenkinsfile**:
```groovy
post {
    failure {
        script {
            if (params.DEPLOY_TO_K8S == true) {
                sh '''
                    echo "Deployment failed, rolling back..."
                    kubectl rollout undo deployment/onlineshop-app -n ${KUBE_NAMESPACE}
                    kubectl rollout status deployment/onlineshop-app -n ${KUBE_NAMESPACE}
                    
                    # Notify team
                    echo "Rollback completed" > rollback-report.txt
                '''
            }
        }
    }
}
```

---

## Scenario 10: Custom Alerts and Notifications

**Slack Notification Integration**:

1. **Create Slack Webhook**: In Slack App settings, create Incoming Webhook
2. **Add to Jenkins Credentials**: Save webhook URL
3. **Modify Jenkinsfile**:

```groovy
post {
    always {
        script {
            def status = currentBuild.result
            def color = status == 'SUCCESS' ? 'good' : 'danger'
            def message = "Build #${BUILD_NUMBER}: ${status}\n${BUILD_URL}"
            
            sh '''
                curl -X POST <SLACK_WEBHOOK_URL> \
                    -H 'Content-Type: application/json' \
                    -d '{
                        "color": "'" + color + "'",
                        "text": "'" + message + '",
                        "fields": [
                            {"title": "Build", "value": "'" + BUILD_NUMBER + '"},
                            {"title": "Status", "value": "'" + status + '"}
                        ]
                    }'
            '''
        }
    }
}
```

---

## Scenario 11: Canary Deployment

**Goal**: Deploy to small percentage of users first

**Implementation**:
```groovy
stage('Canary Deployment') {
    steps {
        script {
            sh '''
                # Deploy new version to 10% of replicas
                kubectl set image deployment/onlineshop-app \
                    onlineshop=online-shopping:${IMAGE_TAG} \
                    -n ${KUBE_NAMESPACE} \
                    --record
                
                # Wait 5 minutes
                sleep 300
                
                # Check metrics
                ERROR_RATE=$(kubectl logs deployment/onlineshop-app \
                    -n ${KUBE_NAMESPACE} --tail=1000 \
                    | grep ERROR | wc -l)
                
                if [ $ERROR_RATE -gt 50 ]; then
                    echo "High error rate detected, rolling back..."
                    kubectl rollout undo deployment/onlineshop-app -n ${KUBE_NAMESPACE}
                fi
            '''
        }
    }
}
```

---

## Scenario 12: Zero-Downtime Deployment

**Jenkinsfile Configuration**:
```groovy
stage('Zero-Downtime Deploy') {
    steps {
        script {
            sh '''
                # Ensure multiple replicas
                kubectl scale deployment onlineshop-app \
                    --replicas=3 -n ${KUBE_NAMESPACE}
                
                # Update image with rolling update strategy
                kubectl set image deployment/onlineshop-app \
                    onlineshop=online-shopping:${IMAGE_TAG} \
                    -n ${KUBE_NAMESPACE} \
                    --record
                
                # Wait for rolling update to complete
                kubectl rollout status deployment/onlineshop-app \
                    -n ${KUBE_NAMESPACE} \
                    --timeout=600s
                
                # Verify all pods are ready
                kubectl wait --for=condition=ready pod \
                    -l app=onlineshop \
                    -n ${KUBE_NAMESPACE} \
                    --timeout=600s
            '''
        }
    }
}
```

---

## Quick Reference: Common Jenkins Commands

```bash
# Trigger build from CLI
java -jar jenkins-cli.jar -s http://jenkins.local build online-shopping-system

# Get build logs
java -jar jenkins-cli.jar -s http://jenkins.local console online-shopping-system 1

# List jobs
java -jar jenkins-cli.jar -s http://jenkins.local list-jobs

# Get build info
curl http://jenkins.local/job/online-shopping-system/lastBuild/api/json | jq '.'

# Check pipeline syntax
curl -X POST -F "jenkinsfile=<Jenkinsfile" http://jenkins.local/pipeline-model-converter/validate
```

---

## Success Criteria

A successful CI/CD pipeline should achieve:

- ✅ **Build Success Rate**: > 95%
- ✅ **Test Coverage**: > 70%
- ✅ **Security Issues Fixed**: 100% critical, 90% high
- ✅ **Deployment Time**: < 30 minutes
- ✅ **Mean Time to Recovery**: < 10 minutes
- ✅ **Release Frequency**: Multiple times per week
- ✅ **Zero Downtime Deployments**: 100%
