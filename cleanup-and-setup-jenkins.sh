#!/bin/bash
# Cleanup and setup script for Jenkins in WSL

echo "================================"
echo "Jenkins WSL Cleanup & Setup"
echo "================================"
echo ""

# Remove password prompt requirement
echo "[1/5] Configuring sudo access..."
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/jenkins-sudo > /dev/null

echo "[2/5] Stopping and removing old Jenkins container..."
sudo docker stop jenkins 2>/dev/null || true
sudo docker rm jenkins 2>/dev/null || true
sudo docker container prune -f 2>/dev/null || true

echo "[3/5] Starting Docker daemon..."
sudo service docker start 2>/dev/null || true
sudo update-rc.d docker defaults 2>/dev/null || true

# Wait for Docker to start
sleep 3

echo "[4/5] Testing Docker..."
if sudo docker ps > /dev/null 2>&1; then
    echo "✓ Docker is running"
else
    echo "⚠ Docker not responding, trying to restart..."
    sudo service docker restart
    sleep 5
fi

echo "[5/5] Starting fresh Jenkins container..."
mkdir -p ~/jenkins_data

sudo docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v ~/jenkins_data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

echo ""
echo "Waiting for Jenkins to initialize..."
sleep 20

echo ""
echo "================================"
echo "Getting Jenkins Admin Password"
echo "================================"
echo ""

# Try to get password, with retries
for i in {1..5}; do
    if sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
        break
    else
        echo "Attempt $i: Jenkins still starting..."
        sleep 10
    fi
done

echo ""
echo "================================"
echo "Jenkins Ready!"
echo "================================"
echo ""
echo "✓ Open: http://localhost:8080"
echo ""
echo "Container Status:"
sudo docker ps --filter "name=jenkins"

echo ""
echo "View logs:"
echo "  sudo docker logs -f jenkins"
echo ""
echo "Stop Jenkins:"
echo "  sudo docker stop jenkins"
echo ""
