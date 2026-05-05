#!/bin/bash
# jenkins-helper-scripts.sh
# Collection of helper scripts for Jenkins pipeline operations

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# Docker Functions
# ============================================================================

docker_build() {
    local dockerfile="${1:-.}"
    local image_name="$2"
    local image_tag="${3:-latest}"
    local build_args="${4:-}"

    log_info "Building Docker image: ${image_name}:${image_tag}"
    
    if [ -z "$build_args" ]; then
        docker build -t "${image_name}:${image_tag}" -f "${dockerfile}" .
    else
        docker build -t "${image_name}:${image_tag}" -f "${dockerfile}" ${build_args} .
    fi
    
    log_success "Docker image built: ${image_name}:${image_tag}"
}

docker_push() {
    local image_name="$1"
    local registry="$2"
    local username="${3:-}"
    local password="${4:-}"

    log_info "Pushing Docker image to registry: $registry"
    
    if [ -n "$username" ] && [ -n "$password" ]; then
        echo "$password" | docker login -u "$username" --password-stdin "$registry"
    fi
    
    docker push "${image_name}"
    log_success "Docker image pushed successfully"
}

docker_scan() {
    local image_name="$1"
    local report_file="${2:-trivy-report.json}"

    log_info "Scanning Docker image with Trivy: $image_name"
    
    if command -v trivy &> /dev/null; then
        trivy image --format json --output "$report_file" "$image_name"
        log_success "Trivy scan completed: $report_file"
    else
        log_warn "Trivy not found. Install with: apt-get install trivy"
    fi
}

docker_run_test() {
    local image_name="$1"
    local container_port="${2:-80}"
    local host_port="${3:-8001}"
    local timeout="${4:-30}"

    log_info "Running test container: $image_name"
    
    local container_id=$(docker run -d -p "${host_port}:${container_port}" "$image_name")
    log_info "Container started: $container_id"
    
    # Wait for container to be ready
    sleep 3
    
    # Test connectivity
    local counter=0
    while [ $counter -lt $timeout ]; do
        if curl -f "http://localhost:${host_port}" > /dev/null 2>&1; then
            log_success "Container is responding on port ${host_port}"
            docker stop "$container_id"
            return 0
        fi
        sleep 2
        ((counter+=2))
    done
    
    log_error "Container test failed after ${timeout} seconds"
    docker stop "$container_id" || true
    return 1
}

# ============================================================================
# Kubernetes Functions
# ============================================================================

k8s_validate_manifests() {
    local manifest_dir="${1:-.}"
    local namespace="${2:-default}"

    log_info "Validating Kubernetes manifests in: $manifest_dir"
    
    local invalid_count=0
    for manifest in "${manifest_dir}"/*.yaml; do
        if [ -f "$manifest" ]; then
            if kubectl apply -f "$manifest" --dry-run=client -n "$namespace" > /dev/null 2>&1; then
                log_success "Valid: $(basename $manifest)"
            else
                log_error "Invalid: $(basename $manifest)"
                ((invalid_count++))
            fi
        fi
    done
    
    if [ $invalid_count -eq 0 ]; then
        log_success "All manifests are valid"
        return 0
    else
        log_error "$invalid_count manifest(s) failed validation"
        return 1
    fi
}

k8s_deploy() {
    local manifest_dir="$1"
    local namespace="${2:-default}"
    local wait_timeout="${3:-300}"

    log_info "Deploying to Kubernetes namespace: $namespace"
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply manifests
    for manifest in "${manifest_dir}"/*.yaml; do
        if [ -f "$manifest" ]; then
            log_info "Applying: $(basename $manifest)"
            kubectl apply -f "$manifest" -n "$namespace"
        fi
    done
    
    log_success "Deployment completed"
}

k8s_wait_rollout() {
    local deployment="$1"
    local namespace="${2:-default}"
    local timeout="${3:-300}"

    log_info "Waiting for deployment rollout: $deployment"
    
    kubectl rollout status deployment/"$deployment" \
        -n "$namespace" \
        --timeout="${timeout}s" || {
        log_error "Deployment rollout failed"
        return 1
    }
    
    log_success "Deployment rollout completed"
}

k8s_get_logs() {
    local pod_label="$1"
    local namespace="${2:-default}"
    local lines="${3:-50}"

    log_info "Getting logs for pods with label: $pod_label"
    
    local pod=$(kubectl get pods -n "$namespace" -l "$pod_label" -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$pod" ]; then
        log_error "No pods found with label: $pod_label"
        return 1
    fi
    
    log_info "Pod: $pod"
    kubectl logs -n "$namespace" "$pod" --tail="$lines"
}

k8s_describe_pod() {
    local pod_label="$1"
    local namespace="${2:-default}"

    local pod=$(kubectl get pods -n "$namespace" -l "$pod_label" -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$pod" ]; then
        log_error "No pods found with label: $pod_label"
        return 1
    fi
    
    kubectl describe pod -n "$namespace" "$pod"
}

# ============================================================================
# PHP Functions
# ============================================================================

php_lint() {
    local directory="${1:-.}"
    local log_file="${2:-php-lint.log}"

    log_info "PHP linting directory: $directory"
    
    local error_count=0
    find "$directory" -name "*.php" -type f | while read php_file; do
        if ! php -l "$php_file" > /dev/null 2>&1; then
            echo "ERROR: $php_file" >> "$log_file"
            ((error_count++))
        fi
    done
    
    if [ $error_count -eq 0 ]; then
        log_success "PHP lint check passed"
        return 0
    else
        log_error "Found $error_count PHP files with syntax errors"
        cat "$log_file"
        return 1
    fi
}

php_security_check() {
    local directory="${1:-.}"
    local report_file="${2:-php-security.txt}"

    log_info "Running PHP security checks"
    
    > "$report_file"
    
    # Check for eval
    if grep -r "eval(" --include="*.php" "$directory" >> "$report_file" 2>&1; then
        log_warn "Found eval() usage - security risk"
    fi
    
    # Check for exec
    if grep -r "exec(" --include="*.php" "$directory" >> "$report_file" 2>&1; then
        log_warn "Found exec() usage - security risk"
    fi
    
    # Check for system
    if grep -r "system(" --include="*.php" "$directory" >> "$report_file" 2>&1; then
        log_warn "Found system() usage - security risk"
    fi
    
    # Check for unescaped output
    if grep -r "echo.*\$_" --include="*.php" "$directory" | grep -v "htmlspecialchars" >> "$report_file" 2>&1; then
        log_warn "Found potentially unescaped output"
    fi
    
    log_success "Security check report generated: $report_file"
}

# ============================================================================
# Database Functions
# ============================================================================

db_backup() {
    local db_host="$1"
    local db_user="$2"
    local db_password="$3"
    local db_name="$4"
    local backup_dir="${5:-.}"
    local backup_file="${backup_dir}/backup_${db_name}_$(date +%Y%m%d_%H%M%S).sql"

    log_info "Backing up database: $db_name"
    
    mysqldump -h "$db_host" -u "$db_user" -p"$db_password" "$db_name" > "$backup_file"
    
    log_success "Database backup completed: $backup_file"
}

db_restore() {
    local db_host="$1"
    local db_user="$2"
    local db_password="$3"
    local db_name="$4"
    local backup_file="$5"

    log_info "Restoring database: $db_name"
    
    mysql -h "$db_host" -u "$db_user" -p"$db_password" "$db_name" < "$backup_file"
    
    log_success "Database restore completed"
}

# ============================================================================
# Git Functions
# ============================================================================

git_get_commit_info() {
    log_info "Git commit information:"
    echo "Commit: $(git rev-parse --short HEAD)"
    echo "Author: $(git log -1 --pretty=format:'%an <%ae>')"
    echo "Date: $(git log -1 --pretty=format:'%ad' --date=short)"
    echo "Message: $(git log -1 --pretty=format:'%s')"
}

git_get_changed_files() {
    log_info "Changed files since last commit:"
    git diff --name-only HEAD~1..HEAD
}

# ============================================================================
# Health Check Functions
# ============================================================================

health_check_web() {
    local url="$1"
    local timeout="${2:-10}"

    log_info "Health check: $url"
    
    local response=$(curl -s -w "\n%{http_code}" --max-time "$timeout" "$url" 2>/dev/null | tail -n1)
    
    if [ "$response" = "200" ]; then
        log_success "Health check passed (HTTP 200)"
        return 0
    else
        log_error "Health check failed (HTTP $response)"
        return 1
    fi
}

health_check_pod() {
    local pod_name="$1"
    local namespace="${2:-default}"

    log_info "Checking pod health: $pod_name"
    
    local status=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}')
    
    if [ "$status" = "Running" ]; then
        log_success "Pod is running"
        return 0
    else
        log_error "Pod status: $status"
        return 1
    fi
}

# ============================================================================
# Report Generation Functions
# ============================================================================

generate_build_report() {
    local report_file="${1:-build-report.txt}"
    local build_number="${2:-unknown}"
    local git_commit="${3:-unknown}"
    local build_status="${4:-UNKNOWN}"

    log_info "Generating build report: $report_file"
    
    cat > "$report_file" <<EOF
================================================================================
BUILD REPORT
================================================================================
Timestamp: $(date)
Build Number: $build_number
Git Commit: $git_commit
Build Status: $build_status
Hostname: $(hostname)
Kernel: $(uname -r)
================================================================================

ENVIRONMENT
================================================================================
$(env | grep -E "DOCKER|KUBERNETES|JAVA|MAVEN")

DOCKER STATUS
================================================================================
$(docker --version)
Images: $(docker images | wc -l)
Containers: $(docker ps -a | wc -l)

KUBERNETES STATUS
================================================================================
$(kubectl version --client 2>/dev/null || echo "kubectl not configured")
Namespaces: $(kubectl get namespaces --no-headers 2>/dev/null | wc -l || echo "N/A")

DISK USAGE
================================================================================
$(df -h)

MEMORY USAGE
================================================================================
$(free -h)

================================================================================
EOF
    
    log_success "Build report generated: $report_file"
}

# ============================================================================
# System Check Functions
# ============================================================================

system_health_check() {
    log_info "Performing system health check..."
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 80 ]; then
        log_warn "Disk usage is high: ${disk_usage}%"
    else
        log_success "Disk usage: ${disk_usage}%"
    fi
    
    # Check memory
    local mem_usage=$(free | awk 'NR==2 {printf("%.0f\n", $3/$2 * 100)}')
    if [ "$mem_usage" -gt 80 ]; then
        log_warn "Memory usage is high: ${mem_usage}%"
    else
        log_success "Memory usage: ${mem_usage}%"
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        if docker ps > /dev/null 2>&1; then
            log_success "Docker daemon is running"
        else
            log_error "Docker daemon is not responding"
        fi
    else
        log_warn "Docker is not installed"
    fi
    
    # Check kubectl
    if command -v kubectl &> /dev/null; then
        if kubectl cluster-info > /dev/null 2>&1; then
            log_success "Kubernetes cluster is accessible"
        else
            log_warn "Kubernetes cluster is not accessible"
        fi
    else
        log_warn "kubectl is not installed"
    fi
}

# ============================================================================
# Cleanup Functions
# ============================================================================

cleanup_docker_images() {
    local keep_count="${1:-5}"

    log_info "Cleaning up Docker images (keeping $keep_count most recent)"
    
    docker images --format "{{.Repository}}:{{.Tag}}" | sort | uniq | while read image; do
        local count=$(docker images "$image" | tail -n +2 | wc -l)
        if [ "$count" -gt "$keep_count" ]; then
            docker images "$image" | tail -n +2 | head -n $((count - keep_count)) | awk '{print $3}' | xargs docker rmi -f
        fi
    done
    
    log_success "Docker image cleanup completed"
}

cleanup_docker_containers() {
    log_info "Cleaning up stopped Docker containers"
    docker container prune -f
    log_success "Docker container cleanup completed"
}

cleanup_k8s_completed_pods() {
    local namespace="${1:-default}"

    log_info "Cleaning up completed pods in namespace: $namespace"
    
    kubectl delete pods --field-selector status.phase=Succeeded -n "$namespace"
    kubectl delete pods --field-selector status.phase=Failed -n "$namespace"
    
    log_success "Kubernetes pod cleanup completed"
}

# ============================================================================
# Main - Display Usage
# ============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    cat <<EOF
Jenkins Helper Scripts
======================

Usage: source jenkins-helper-scripts.sh

Available Functions:

DOCKER:
  - docker_build <dockerfile> <image_name> <tag> [build_args]
  - docker_push <image_name> <registry> [username] [password]
  - docker_scan <image_name> [report_file]
  - docker_run_test <image_name> [container_port] [host_port] [timeout]

KUBERNETES:
  - k8s_validate_manifests [manifest_dir] [namespace]
  - k8s_deploy <manifest_dir> [namespace] [timeout]
  - k8s_wait_rollout <deployment> [namespace] [timeout]
  - k8s_get_logs <pod_label> [namespace] [lines]
  - k8s_describe_pod <pod_label> [namespace]

PHP:
  - php_lint [directory] [log_file]
  - php_security_check [directory] [report_file]

DATABASE:
  - db_backup <host> <user> <password> <db_name> [backup_dir]
  - db_restore <host> <user> <password> <db_name> <backup_file>

GIT:
  - git_get_commit_info
  - git_get_changed_files

HEALTH CHECKS:
  - health_check_web <url> [timeout]
  - health_check_pod <pod_name> [namespace]

REPORTS:
  - generate_build_report [report_file] [build_number] [git_commit] [status]

SYSTEM:
  - system_health_check
  - cleanup_docker_images [keep_count]
  - cleanup_docker_containers
  - cleanup_k8s_completed_pods [namespace]

UTILITIES:
  - log_info <message>
  - log_success <message>
  - log_warn <message>
  - log_error <message>

Examples:
  source jenkins-helper-scripts.sh
  docker_build Dockerfile online-shopping latest
  k8s_validate_manifests ./k8s
  php_lint . php-errors.log
  health_check_web http://localhost:8000
EOF
fi
