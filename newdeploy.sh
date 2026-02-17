#!/usr/bin/env bash
#════════════════════════════════════════════════════════════════════
#  Jenkins One-Shot Installer — Amazon Linux 2023 (DNF Version)
#  Usage: sudo bash deploy.sh
#════════════════════════════════════════════════════════════════════

set -euo pipefail

ROLE_DIR="/opt/jenkins"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && error "Run as root: sudo bash deploy.sh"

info "Starting Jenkins setup on Amazon Linux 2023 ..."

# ─────────────────────────────────────────────────────────────
# Step 1: Install Ansible
# ─────────────────────────────────────────────────────────────

info "Step 1/3 — Installing Ansible ..."

if command -v ansible-playbook &>/dev/null; then
    info "Ansible already installed ✅"
else
    dnf install -y ansible-core > /dev/null
    info "Ansible installed ✅"
fi

info "Installing required collection ..."
ansible-galaxy collection install community.general > /dev/null 2>&1 || true
info "Collection installed ✅"

# ─────────────────────────────────────────────────────────────
# Step 2: Create role structure
# ─────────────────────────────────────────────────────────────

info "Step 2/3 — Creating Jenkins role..."

rm -rf "$ROLE_DIR"

mkdir -p "$ROLE_DIR"/{defaults,vars,tasks,templates,handlers,meta}

# ───────────────── hosts ─────────────────

cat > "$ROLE_DIR/hosts" << 'EOF'
[localhost]
localhost ansible_connection=local
EOF

# ───────────────── playbook ─────────────────

cat > "$ROLE_DIR/playbook.yml" << 'EOF'
---
- hosts: localhost
  connection: local
  become: yes
  roles:
    - /opt/jenkins
EOF

# ───────────────── defaults ─────────────────

cat > "$ROLE_DIR/defaults/main.yml" << 'EOF'
---
jenkins_home: /var/lib/jenkins
jenkins_hostname: localhost
jenkins_http_port: 8080

jenkins_admin_username: pinelabs_admin
jenkins_admin_password: H=f1WB>9Xpki

jenkins_plugins:
  - git
  - configuration-as-code
  - workflow-aggregator
  - blueocean

jenkins_connection_delay: 5
jenkins_connection_retries: 60

jenkins_java_options: "-Djenkins.install.runSetupWizard=false"

jenkins_base_url: "http://{{ jenkins_hostname }}:{{ jenkins_http_port }}"
jenkins_url: "{{ jenkins_base_url }}"
EOF

# ───────────────── handlers ─────────────────

cat > "$ROLE_DIR/handlers/main.yml" << 'EOF'
---
- name: restart jenkins
  systemd:
    name: jenkins
    state: restarted
EOF

# ───────────────── security template ─────────────────

cat > "$ROLE_DIR/templates/security.groovy" << 'EOF'
#!groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.get()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("${JENKINS_USER}", "${JENKINS_PASS}")

instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)

instance.setAuthorizationStrategy(strategy)
instance.save()
EOF

# ───────────────── main tasks ─────────────────

cat > "$ROLE_DIR/tasks/main.yml" << 'EOF'
---

- name: Install Java 17
  dnf:
    name: java-17-amazon-corretto-devel
    state: present

- name: Install fontconfig
  dnf:
    name: fontconfig
    state: present

- name: Install Jenkins using dnf
  dnf:
    name: jenkins
    state: present
  notify: restart jenkins

- name: Create systemd override directory
  file:
    path: /etc/systemd/system/jenkins.service.d
    state: directory

- name: Configure Jenkins port and options
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

- name: Enable Jenkins
  systemd:
    name: jenkins
    enabled: yes
    state: started

- name: Wait for Jenkins startup
  uri:
    url: "{{ jenkins_url }}/login"
    status_code: [200,403]
  register: result
  retries: "{{ jenkins_connection_retries }}"
  delay: "{{ jenkins_connection_delay }}"
  until: result.status in [200,403]

EOF

# ───────────────── meta ─────────────────

cat > "$ROLE_DIR/meta/main.yml" << 'EOF'
---
galaxy_info:
  role_name: jenkins
  author: devops
  description: Install Jenkins via dnf
  min_ansible_version: 2.9
dependencies: []
EOF

info "Role created ✅"

# ─────────────────────────────────────────────────────────────
# Step 3: Execute playbook
# ─────────────────────────────────────────────────────────────

info "Step 3/3 — Installing Jenkins..."

ansible-playbook "$ROLE_DIR/playbook.yml" -i "$ROLE_DIR/hosts"

# ─────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────

IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN} Jenkins Installed Successfully${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "URL      : http://$IP:8080"
echo "User     : pinelabs_admin"
echo "Home     : /var/lib/jenkins"
echo ""
echo "Check    : systemctl status jenkins"
echo ""
