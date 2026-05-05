#!/bin/bash
# Complete Jenkins + Docker setup for WSL Ubuntu
# Run with: bash setup-jenkins-wsl.sh

set -e

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${COLOR_BLUE}=====================================${NC}"
echo -e "${COLOR_BLUE}Jenkins + Docker Setup for WSL${NC}"
echo -e "${COLOR_BLUE}=====================================${NC}\n"

# 1. Update system
echo -e "${COLOR_YELLOW}[1/7] Updating Ubuntu packages...${NC}"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# 2. Install prerequisites
echo -e "${COLOR_YELLOW}[2/7] Installing prerequisites...${NC}"
sudo apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    wget \
    git \
    vim \
    net-tools \
    htop

# 3. Add Docker repository and install Docker
echo -e "${COLOR_YELLOW}[3/7] Installing Docker Engine...${NC}"

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update and install Docker
sudo apt-get update -qq
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 4. Add user to docker group
echo -e "${COLOR_YELLOW}[4/7] Configuring Docker permissions...${NC}"
sudo usermod -aG docker $USER
sudo usermod -aG docker root

# 5. Start Docker
echo -e "${COLOR_YELLOW}[5/7] Starting Docker daemon...${NC}"
sudo service docker start || true
sudo update-rc.d docker defaults 2>/dev/null || true

# Wait a moment for Docker to start
sleep 2

# 6. Verify Docker installation
echo -e "${COLOR_YELLOW}[6/7] Verifying Docker installation...${NC}"
docker_version=$(docker --version 2>/dev/null || echo "Docker not running yet")
echo "Docker version: $docker_version"

# 7. Create Jenkins container
echo -e "${COLOR_YELLOW}[7/7] Setting up Jenkins container...${NC}"

# Create Jenkins data directory
mkdir -p ~/jenkins_data
sudo chown 1000:1000 ~/jenkins_data

# Create Jenkins container with Docker
sudo docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v ~/jenkins_data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker \
  jenkins/jenkins:lts

echo -e "\n${COLOR_GREEN}✓ Setup completed!${NC}\n"

# Display connection info
echo -e "${COLOR_BLUE}=====================================${NC}"
echo -e "${COLOR_BLUE}Jenkins Information${NC}"
echo -e "${COLOR_BLUE}=====================================${NC}"
echo -e "URL: ${COLOR_GREEN}http://localhost:8080${NC}"
echo -e "Data directory: ${COLOR_GREEN}~/jenkins_data${NC}"
echo -e "Container name: ${COLOR_GREEN}jenkins${NC}\n"

# Wait for Jenkins to start and get initial password
echo -e "${COLOR_YELLOW}Waiting for Jenkins to initialize (this takes 30-60 seconds)...${NC}"
sleep 15

echo -e "\n${COLOR_YELLOW}Getting Jenkins initial admin password...${NC}"
max_attempts=12
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if sudo docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
        echo ""
        echo -e "${COLOR_GREEN}Initial Admin Password:${NC}"
        echo -e "${COLOR_BLUE}========================================${NC}"
        sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
        echo -e "${COLOR_BLUE}========================================${NC}"
        break
    else
        echo -n "."
        sleep 5
        ((attempt++))
    fi
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "\n${COLOR_YELLOW}Jenkins is still starting. Check again in a moment with:${NC}"
    echo -e "${COLOR_GREEN}sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword${NC}"
fi

echo -e "\n${COLOR_BLUE}=====================================${NC}"
echo -e "${COLOR_BLUE}Docker Status${NC}"
echo -e "${COLOR_BLUE}=====================================${NC}"
sudo docker ps --filter "name=jenkins"

echo -e "\n${COLOR_GREEN}Setup complete! Open http://localhost:8080 in your browser.${NC}\n"

echo -e "${COLOR_YELLOW}Next steps:${NC}"
echo "1. Open http://localhost:8080 in your browser"
echo "2. Paste the admin password from above"
echo "3. Complete Jenkins setup wizard"
echo "4. Install suggested plugins"
echo "5. Create your first admin user"
echo ""
echo -e "${COLOR_YELLOW}Useful commands:${NC}"
echo "  View Jenkins logs:     sudo docker logs -f jenkins"
echo "  Restart Jenkins:       sudo docker restart jenkins"
echo "  Stop Jenkins:          sudo docker stop jenkins"
echo "  Remove Jenkins:        sudo docker rm jenkins"
echo "  Docker status:         sudo docker ps"
echo ""
