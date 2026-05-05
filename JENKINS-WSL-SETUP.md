# Setup Jenkins in WSL - Quick Manual Steps

## Step 1: Open WSL Terminal
```powershell
# In PowerShell, run:
wsl
```

## Step 2: Install Docker in WSL
```bash
# Copy and paste these commands one by one in WSL terminal:

# Install Docker prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker
sudo service docker start

# Add current user to docker group (no sudo needed after this)
sudo usermod -aG docker $USER
```

## Step 3: Run Jenkins Container
```bash
# Create Jenkins data directory
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

# Wait 30 seconds for Jenkins to start
sleep 30

# Get the initial admin password
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## Step 4: Access Jenkins
Open your browser and go to: **http://localhost:8080**

Paste the password from the command above when prompted.

## Step 5: Complete Jenkins Setup
1. **Paste admin password** from Step 3
2. **Click "Install suggested plugins"**
3. **Create first admin user** (use your credentials)
4. **Save and continue**

## Step 6: Create New Pipeline Job
1. **Click "New Item"**
2. **Enter name:** `online-shopping-system`
3. **Select:** Pipeline
4. **Click OK**

### In Pipeline Configuration:
**Definition:** Pipeline script from SCM
**SCM:** Git
**Repository URL:** `file:///mnt/c/xampp/htdocs/online-shopping-system-master` (local path)
**Branch:** `*/main` or `*/master`
**Script Path:** `Jenkinsfile`

**Click Save**

## Step 7: First Build
1. **Click "Build Now"**
2. **Watch the console output**
3. Success! Your pipeline will run through all stages

---

## Useful Commands

### View Jenkins logs:
```bash
sudo docker logs -f jenkins
```

### Restart Jenkins:
```bash
sudo docker restart jenkins
```

### Stop Jenkins:
```bash
sudo docker stop jenkins
```

### Check Docker status:
```bash
sudo docker ps
```

### View Jenkins data:
```bash
ls -la ~/jenkins_data
```

### Access Jenkins shell (for debugging):
```bash
sudo docker exec -it jenkins bash
```

---

## Troubleshooting

### Docker socket permission denied:
```bash
sudo chmod 666 /var/run/docker.sock
```

### Jenkins container won't start:
```bash
# Remove and recreate
sudo docker rm -f jenkins
# Then run the docker run command again
```

### Can't connect to http://localhost:8080:
```bash
# Check if container is running
sudo docker ps | grep jenkins

# Check logs
sudo docker logs jenkins
```

### Permission denied errors:
```bash
# Add docker group permissions
sudo usermod -aG docker $USER
# May need to logout and login again
```

---

## Your Jenkinsfile is Ready!

Your Jenkinsfile is already in the repository with these stages:
✅ Code Quality Analysis
✅ Security Scanning  
✅ Docker Build & Test
✅ Kubernetes Deploy (optional)
✅ Reports Generation

No modifications needed to start using it!

---

## Next: Integrate with Your Running Website

After Jenkins is working, we can:
1. **Add deployment stage** to update your localhost:8000
2. **Set up GitHub webhooks** (if using Git)
3. **Configure automated builds** on code changes
4. **Add email notifications**

Would you like help with any of these?
