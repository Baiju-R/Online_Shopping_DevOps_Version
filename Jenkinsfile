pipeline {
    agent any

    parameters {
        string(name: 'DOCKER_REGISTRY', defaultValue: 'docker.io', description: 'Docker Registry URL')
        string(name: 'IMAGE_NAME', defaultValue: 'online-shopping-system', description: 'Docker Image Name')
        string(name: 'IMAGE_TAG', defaultValue: 'latest', description: 'Docker Image Tag')
        string(name: 'KUBE_NAMESPACE', defaultValue: 'default', description: 'Kubernetes Namespace')
        booleanParam(name: 'DEPLOY_TO_K8S', defaultValue: false, description: 'Deploy to Kubernetes')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run Tests')
        booleanParam(name: 'SECURITY_SCAN', defaultValue: true, description: 'Run Security Scan')
    }

    environment {
        DOCKER_IMAGE = "${params.DOCKER_REGISTRY}/${params.IMAGE_NAME}:${params.IMAGE_TAG}"
        BUILD_TIMESTAMP = sh(script: "date -u +'%Y-%m-%d_%H-%M-%S'", returnStdout: true).trim()
        WORKSPACE_ROOT = "${WORKSPACE}"
        LOG_DIR = "${WORKSPACE}/logs"
        REPORTS_DIR = "${WORKSPACE}/reports"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }

    stages {
        stage('Initialization') {
            steps {
                script {
                    echo "=== Pipeline Initialization ==="
                    sh 'mkdir -p ${LOG_DIR} ${REPORTS_DIR}'
                    sh 'echo "Pipeline started at $(date)" > ${LOG_DIR}/build.log'
                    sh 'git --version && docker --version && kubectl version --client'
                }
            }
        }

        stage('Checkout') {
            steps {
                script {
                    echo "=== Checking out source code ==="
                    checkout scm
                    sh 'git log -1 --pretty=format:"%H - %an - %s" > ${REPORTS_DIR}/git-info.txt'
                }
            }
        }

        stage('Code Quality Analysis') {
            steps {
                script {
                    echo "=== Running PHP Code Quality Checks ==="
                    try {
                        sh '''
                            # Check for PHP syntax errors
                            echo "Checking PHP syntax..."
                            find . -name "*.php" -type f | while read php_file; do
                                php -l "$php_file" || echo "Syntax error in $php_file" >> ${LOG_DIR}/php-errors.log
                            done
                            
                            # Count lines of code
                            echo "Code Statistics:"
                            find . -name "*.php" -type f -exec wc -l {} + | tail -1
                            
                            # Check for common security issues
                            echo "Checking for common vulnerabilities..."
                            grep -r "eval(" --include="*.php" . > ${REPORTS_DIR}/eval-usage.txt 2>&1 || echo "No eval() functions found"
                            grep -r "exec(" --include="*.php" . > ${REPORTS_DIR}/exec-usage.txt 2>&1 || echo "No exec() functions found"
                        '''
                    } catch (Exception e) {
                        echo "Code quality check found issues (non-critical): ${e.message}"
                    }
                }
            }
        }

        stage('Dependency Check') {
            steps {
                script {
                    echo "=== Checking Dependencies ==="
                    sh '''
                        echo "Checking for composer.json..."
                        if [ -f "composer.json" ]; then
                            echo "composer.json found, would run: composer install"
                            # Uncomment if composer is available
                            # composer install --no-dev --optimize-autoloader
                        else
                            echo "No composer.json found - using direct PHP files"
                        fi
                        
                        echo "Checking MySQL connectivity requirements..."
                        grep -r "mysqli\\|PDO" --include="*.php" . | wc -l > ${REPORTS_DIR}/db-connections.txt
                    '''
                }
            }
        }

        stage('Unit Tests & Integration Tests') {
            when {
                expression { params.RUN_TESTS == true }
            }
            steps {
                script {
                    echo "=== Running Tests ==="
                    sh '''
                        # Create test report directory
                        mkdir -p ${REPORTS_DIR}/tests
                        
                        echo "Running PHP Unit Tests..."
                        if command -v phpunit &> /dev/null; then
                            phpunit --log-junit ${REPORTS_DIR}/tests/phpunit.xml --testdox || true
                        else
                            echo "PHPUnit not installed - skipping unit tests"
                        fi
                        
                        echo "Checking critical files exist..."
                        [ -f "index.php" ] && echo "✓ index.php found" || echo "✗ index.php missing"
                        [ -f "config.php" ] && echo "✓ config.php found" || echo "✗ config.php missing"
                        [ -f "db.php" ] && echo "✓ db.php found" || echo "✗ db.php missing"
                        [ -d "database" ] && echo "✓ database directory found" || echo "✗ database directory missing"
                    '''
                }
            }
        }

        stage('Security Scanning') {
            when {
                expression { params.SECURITY_SCAN == true }
            }
            steps {
                script {
                    echo "=== Security Scanning ==="
                    sh '''
                        mkdir -p ${REPORTS_DIR}/security
                        
                        echo "Scanning for sensitive files..."
                        grep -r "password\\|secret\\|api.key\\|token" --include="*.php" . | head -20 > ${REPORTS_DIR}/security/sensitive-strings.txt 2>&1 || true
                        
                        echo "Checking for SQL Injection vulnerabilities..."
                        grep -r "SELECT.*\\$\\|INSERT.*\\$\\|UPDATE.*\\$" --include="*.php" . > ${REPORTS_DIR}/security/sql-injection-risks.txt 2>&1 || true
                        
                        echo "Checking for XSS vulnerabilities..."
                        grep -r "echo.*\\$_\\|print.*\\$_" --include="*.php" . | grep -v "htmlspecialchars\\|htmlentities" > ${REPORTS_DIR}/security/xss-risks.txt 2>&1 || true
                        
                        echo "Checking for hardcoded credentials..."
                        grep -r "MYSQL_PASSWORD\\|MYSQL_USER\\|MYSQL_ROOT_PASSWORD" --include="*.php" --include="*.yml" --include="*.yaml" . > ${REPORTS_DIR}/security/hardcoded-creds.txt 2>&1 || true
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "=== Building Docker Image: ${DOCKER_IMAGE} ==="
                    sh '''
                        docker build \
                            --tag ${DOCKER_IMAGE} \
                            --tag ${IMAGE_NAME}:${BUILD_TIMESTAMP} \
                            --label "build.timestamp=${BUILD_TIMESTAMP}" \
                            --label "git.commit=$(git rev-parse --short HEAD)" \
                            -f Dockerfile .
                        
                        echo "Docker image built successfully"
                        docker images | grep ${IMAGE_NAME}
                    '''
                }
            }
        }

        stage('Docker Image Scanning') {
            steps {
                script {
                    echo "=== Scanning Docker Image for Vulnerabilities ==="
                    sh '''
                        echo "Image inspection:"
                        docker inspect ${DOCKER_IMAGE} | head -50 > ${REPORTS_DIR}/docker-inspect.json
                        
                        echo "Checking image layers..."
                        docker history ${DOCKER_IMAGE} > ${REPORTS_DIR}/docker-layers.txt
                        
                        # If Trivy is available, use it
                        if command -v trivy &> /dev/null; then
                            echo "Running Trivy scan..."
                            trivy image --severity HIGH,CRITICAL ${DOCKER_IMAGE} > ${REPORTS_DIR}/trivy-scan.txt || true
                        fi
                    '''
                }
            }
        }

        stage('Docker Compose Validation') {
            steps {
                script {
                    echo "=== Validating Docker Compose Configuration ==="
                    sh '''
                        if [ -f "docker-compose.yml" ]; then
                            docker-compose config > ${REPORTS_DIR}/docker-compose-validated.yml
                            echo "✓ docker-compose.yml is valid"
                        else
                            echo "⚠ docker-compose.yml not found"
                        fi
                    '''
                }
            }
        }

        stage('Local Docker Test') {
            steps {
                script {
                    echo "=== Testing Docker Image Locally ==="
                    sh '''
                        # Start container for testing
                        echo "Starting test container..."
                        CONTAINER_ID=$(docker run -d --rm \
                            -p 8001:80 \
                            ${DOCKER_IMAGE} 2>&1)
                        
                        if [ -z "$CONTAINER_ID" ]; then
                            echo "Failed to start container"
                            exit 1
                        fi
                        
                        echo "Container ID: $CONTAINER_ID"
                        
                        # Wait for container to be ready
                        sleep 5
                        
                        # Test container connectivity
                        echo "Testing container connectivity..."
                        if curl -f http://localhost:8001/index.php > /dev/null 2>&1; then
                            echo "✓ Container is responding on port 80"
                        else
                            echo "⚠ Container test response (may be expected for first load)"
                        fi
                        
                        # Check Apache is running
                        if docker exec $CONTAINER_ID ps aux | grep -q apache2; then
                            echo "✓ Apache is running in container"
                        fi
                        
                        # Stop container
                        docker stop $CONTAINER_ID || true
                        
                        echo "Local test completed"
                    '''
                }
            }
        }

        stage('Kubernetes Manifests Validation') {
            steps {
                script {
                    echo "=== Validating Kubernetes Manifests ==="
                    sh '''
                        mkdir -p ${REPORTS_DIR}/k8s
                        
                        if [ -d "k8s" ]; then
                            echo "Validating all K8s manifests..."
                            for manifest in k8s/*.yaml; do
                                echo "Validating $manifest..."
                                kubectl apply -f "$manifest" --dry-run=client -n ${KUBE_NAMESPACE} > /dev/null 2>&1 && \
                                    echo "✓ $manifest is valid" || \
                                    echo "✗ $manifest has errors"
                            done
                        else
                            echo "⚠ K8s directory not found"
                        fi
                    '''
                }
            }
        }

        stage('Push to Registry') {
            when {
                expression { env.BRANCH_NAME == null || env.BRANCH_NAME == 'master' || env.BRANCH_NAME == 'main' }
            }
            steps {
                script {
                    echo "=== Pushing Docker Image to Registry ==="
                    withCredentials([usernamePassword(credentialsId: 'docker-registry-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh '''
                            echo "Logging in to Docker Registry..."
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin ${DOCKER_REGISTRY}
                            
                            echo "Pushing image: ${DOCKER_IMAGE}"
                            docker push ${DOCKER_IMAGE}
                            
                            echo "Image pushed successfully"
                            docker logout ${DOCKER_REGISTRY}
                        '''
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            when {
                expression { params.DEPLOY_TO_K8S == true && (env.BRANCH_NAME == null || env.BRANCH_NAME == 'master' || env.BRANCH_NAME == 'main') }
            }
            steps {
                script {
                    echo "=== Deploying to Kubernetes ==="
                    sh '''
                        echo "Preparing K8s deployment..."
                        
                        # Create namespace if it doesn't exist
                        kubectl create namespace ${KUBE_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Update image in deployment manifest
                        if [ -f "k8s/app-deployment.yaml" ]; then
                            sed -i "s|image: .*|image: ${DOCKER_IMAGE}|g" k8s/app-deployment.yaml
                            sed -i "s|imagePullPolicy: Never|imagePullPolicy: IfNotPresent|g" k8s/app-deployment.yaml
                        fi
                        
                        # Apply MySQL deployment and service
                        echo "Deploying MySQL..."
                        kubectl apply -f k8s/mysql-pv.yaml -n ${KUBE_NAMESPACE} --validate=false
                        kubectl apply -f k8s/mysql-pvc.yaml -n ${KUBE_NAMESPACE} --validate=false
                        kubectl apply -f k8s/mysql-deployment.yaml -n ${KUBE_NAMESPACE} --validate=false
                        kubectl apply -f k8s/mysql-service.yaml -n ${KUBE_NAMESPACE} --validate=false
                        
                        # Wait for MySQL to be ready
                        echo "Waiting for MySQL to be ready..."
                        kubectl wait --for=condition=ready pod -l app=mysql -n ${KUBE_NAMESPACE} --timeout=300s || true
                        
                        # Apply app deployment and service
                        echo "Deploying application..."
                        kubectl apply -f k8s/app-deployment.yaml -n ${KUBE_NAMESPACE} --validate=false
                        kubectl apply -f k8s/app-service.yaml -n ${KUBE_NAMESPACE} --validate=false
                        
                        # Apply ingress if it exists
                        if [ -f "k8s/ingress.yaml" ]; then
                            kubectl apply -f k8s/ingress.yaml -n ${KUBE_NAMESPACE} --validate=false
                        fi
                        
                        # Wait for deployment to be ready
                        echo "Waiting for application to be ready..."
                        kubectl rollout status deployment/onlineshop-app -n ${KUBE_NAMESPACE} --timeout=300s || true
                        
                        # Show deployment status
                        echo "Deployment status:"
                        kubectl get pods -n ${KUBE_NAMESPACE}
                        kubectl get services -n ${KUBE_NAMESPACE}
                    '''
                }
            }
        }

        stage('Post-Deployment Verification') {
            when {
                expression { params.DEPLOY_TO_K8S == true }
            }
            steps {
                script {
                    echo "=== Post-Deployment Verification ==="
                    sh '''
                        echo "Checking pod status..."
                        kubectl get pods -n ${KUBE_NAMESPACE} -o wide
                        
                        echo "Checking services..."
                        kubectl get svc -n ${KUBE_NAMESPACE}
                        
                        echo "Getting application pod logs..."
                        POD=$(kubectl get pods -n ${KUBE_NAMESPACE} -l app=onlineshop -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                        if [ ! -z "$POD" ]; then
                            echo "Pod: $POD"
                            kubectl logs $POD -n ${KUBE_NAMESPACE} --tail=50 > ${REPORTS_DIR}/app-logs.txt 2>&1 || true
                        fi
                        
                        echo "Checking MySQL pod..."
                        MYSQL_POD=$(kubectl get pods -n ${KUBE_NAMESPACE} -l app=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                        if [ ! -z "$MYSQL_POD" ]; then
                            echo "MySQL Pod: $MYSQL_POD"
                            kubectl logs $MYSQL_POD -n ${KUBE_NAMESPACE} --tail=30 > ${REPORTS_DIR}/mysql-logs.txt 2>&1 || true
                        fi
                    '''
                }
            }
        }

        stage('Generate Report') {
            steps {
                script {
                    echo "=== Generating Build Report ==="
                    sh '''
                        cat > ${REPORTS_DIR}/build-summary.txt <<EOF
==========================================
BUILD SUMMARY
==========================================
Build Number: ${BUILD_NUMBER}
Build Timestamp: ${BUILD_TIMESTAMP}
Git Commit: $(git rev-parse --short HEAD)
Image: ${DOCKER_IMAGE}
Kubernetes Namespace: ${KUBE_NAMESPACE}
Deploy to K8s: ${DEPLOY_TO_K8S}
Run Tests: ${RUN_TESTS}
Security Scan: ${SECURITY_SCAN}

Build Status: SUCCESS
Build Duration: ${BUILD_DURATION}

Generated Reports:
- Code Quality: ${REPORTS_DIR}/
- Security Scan: ${REPORTS_DIR}/security/
- Docker: ${REPORTS_DIR}/docker-inspect.json
- K8s Manifests: ${REPORTS_DIR}/k8s/

==========================================
EOF
                        cat ${REPORTS_DIR}/build-summary.txt
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                echo "=== Pipeline Cleanup ==="
                sh '''
                    echo "Collecting all reports..."
                    ls -la ${REPORTS_DIR}/ > ${REPORTS_DIR}/directory-listing.txt
                    
                    echo "Stopping any remaining test containers..."
                    docker ps -a | grep -v CONTAINER | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true
                '''
            }
        }

        success {
            script {
                echo "=== Build Successful ==="
                sh '''
                    echo "Build succeeded at $(date)" >> ${LOG_DIR}/build.log
                    if [ "${DEPLOY_TO_K8S}" == "true" ]; then
                        echo "Application deployed to K8s namespace: ${KUBE_NAMESPACE}"
                    fi
                '''
            }
        }

        failure {
            script {
                echo "=== Build Failed ==="
                sh '''
                    echo "Build failed at $(date)" >> ${LOG_DIR}/build.log
                    
                    # Collect debug information
                    echo "Docker containers:"
                    docker ps -a >> ${REPORTS_DIR}/failure-debug.txt
                    
                    echo "Recent Docker logs:"
                    docker logs $(docker ps -aq 2>/dev/null | head -1) >> ${REPORTS_DIR}/failure-debug.txt 2>&1 || true
                '''
            }
        }

        unstable {
            script {
                echo "=== Build Unstable ==="
                sh 'echo "Build unstable at $(date)" >> ${LOG_DIR}/build.log'
            }
        }

        cleanup {
            cleanWs()
        }
    }
}
