#!/usr/bin/env bash
#════════════════════════════════════════════════════════════════════
# Jenkins Installer — Amazon Linux 2023 (YUM Version)
# Usage: sudo bash deploy.sh
#════════════════════════════════════════════════════════════════════

set -euo pipefail

ROLE_DIR="/opt/jenkins"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && error "Run as root"

info "Starting Jenkins installation..."

############################################################
# Step 1: Install Ansible
############################################################

info "Installing Ansible..."

if ! command -v ansible-playbook &>/dev/null; then
    yum install -y ansible-core > /dev/null
fi

ansible-galaxy collection install community.general > /dev/null 2>&1 || true

############################################################
# Step 2: Create Role
############################################################

rm -rf "$ROLE_DIR"

mkdir -p "$ROLE_DIR"/{defaults,tasks,handlers,meta}

cat > "$ROLE_DIR/hosts" << 'EOF'
localhost ansible_connection=local
EOF

cat > "$ROLE_DIR/playbook.yml" << 'EOF'
---
- hosts: localhost
  become: yes
  roles:
    - /opt/jenkins
EOF

cat > "$ROLE_DIR/defaults/main.yml" << 'EOF'
---
jenkins_http_port: 8080
jenkins_home: /var/lib/jenkins
jenkins_java_options: "-Djenkins.install.runSetupWizard=false"
jenkins_connection_retries: 60
jenkins_connection_delay: 5
jenkins_url: "http://localhost:8080"
EOF

cat > "$ROLE_DIR/handlers/main.yml" << 'EOF'
---
- name: restart jenkins
  service:
    name: jenkins
    state: restarted
EOF

############################################################
# Main Tasks
############################################################

cat > "$ROLE_DIR/tasks/main.yml" << 'EOF'
---

- name: Install Java 17
  yum:
    name: java-17-amazon-corretto-devel
    state: present

- name: Install fontconfig
  yum:
    name: fontconfig
    state: present

- name: Install Jenkins using yum
  yum:
    name: jenkins
    state: present
  notify: restart jenkins

- name: Create override directory
  file:
    path: /etc/systemd/system/jenkins.service.d
    state: directory

- name: Configure Jenkins port
  copy:
    dest: /etc/systemd/system/jenkins.service.d/override.conf
    content: |
      [Service]
      Environment="JENKINS_PORT={{ jenkins_http_port }}"
      Environment="JAVA_OPTS={{ jenkins_java_options }}"
  notify: restart jenkins

- name: Reload systemd
  systemd:
    daemon_reload: yes

- name: Enable and start Jenkins
  service:
    name: jenkins
    enabled: yes
    state: started

- name: Wait for Jenkins
  uri:
    url: "{{ jenkins_url }}/login"
    status_code: [200,403]
  register: result
  retries: "{{ jenkins_connection_retries }}"
  delay: "{{ jenkins_connection_delay }}"
  until: result.status in [200,403]

EOF

cat > "$ROLE_DIR/meta/main.yml" << 'EOF'
---
galaxy_info:
  role_name: jenkins
  description: Jenkins install via yum
EOF

############################################################
# Step 3: Run Playbook
############################################################

info "Running Ansible..."

ansible-playbook "$ROLE_DIR/playbook.yml" -i "$ROLE_DIR/hosts"

############################################################
# Done
############################################################

IP=$(hostname -I | awk '{print $1}')

echo ""
echo "======================================"
echo "Jenkins Installed Successfully"
echo "======================================"
echo ""
echo "URL: http://$IP:8080"
echo ""
echo "Check status:"
echo "systemctl status jenkins"
echo ""
