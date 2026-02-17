```bash
#!/usr/bin/env bash
#════════════════════════════════════════════════════════════════════
#  Jenkins One-Shot Installer — Amazon Linux 2023 (YUM version)
#  Usage:  sudo bash deploy.sh
#════════════════════════════════════════════════════════════════════
set -euo pipefail

ROLE_DIR="/opt/jenkins"

GREEN='\033[0;32m' ; RED='\033[0;31m' ; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && error "Run as root: sudo bash deploy.sh"

info "Starting Jenkins setup on Amazon Linux ..."

# ── Step 1: Install Ansible ──────────────────────────────────────
info "Step 1/3 — Installing Ansible ..."

if command -v ansible-playbook &>/dev/null; then
  info "Ansible already installed ✅"
else
  dnf install -y ansible-core > /dev/null 2>&1 || {
    dnf install -y epel-release > /dev/null 2>&1 || true
    dnf install -y ansible-core > /dev/null
  }
  info "Ansible installed ✅"
fi

info "Installing required Ansible collection ..."
ansible-galaxy collection install community.general > /dev/null 2>&1
info "community.general collection installed ✅"

# ── Step 2: Create Role Files ────────────────────────────────────
info "Step 2/3 — Creating Jenkins role at $ROLE_DIR ..."

rm -rf "$ROLE_DIR"
mkdir -p "$ROLE_DIR"/{defaults,vars,tasks,templates,handlers,meta}

# ─── hosts ───
cat > "$ROLE_DIR/hosts" << 'EOF'
[localhost]
localhost ansible_connection=local
EOF

# ─── playbook.yml ───
cat > "$ROLE_DIR/playbook.yml" << 'EOF'
---
- hosts: localhost
  connection: local
  become: yes
  roles:
    - /opt/jenkins
EOF

# ─── defaults/main.yml ───
cat > "$ROLE_DIR/defaults/main.yml" << 'EOF'
---
jenkins_package_state: present
jenkins_connection_delay: 5
jenkins_connection_retries: 60
jenkins_home: /var/lib/jenkins
jenkins_hostname: localhost
jenkins_http_port: 8080
jenkins_jar_location: /opt/jenkins-cli.jar
jenkins_url_prefix: ""
jenkins_java_options: "-Djenkins.install.runSetupWizard=false"
jenkins_base_url: "http://{{ jenkins_hostname }}:{{ jenkins_http_port }}"
jenkins_url: "{{ jenkins_base_url }}{{ jenkins_url_prefix }}"

jenkins_plugins:
  - git
  - configuration-as-code
  - plain-credentials
  - warnings-ng
  - htmlpublisher
  - antisamy-markup-formatter
  - Office-365-Connector
  - ansicolor
  - sonar
  - pipeline-aws
  - build-user-vars-plugin
  - ws-cleanup
  - blueocean
  - pipeline-groovy-lib
  - workflow-durable-task-step
  - workflow-basic-steps

jenkins_plugins_state: present
jenkins_plugin_updates_expiration: 86400
jenkins_plugin_timeout: 300
jenkins_plugins_install_dependencies: true

jenkins_process_user: jenkins
jenkins_process_group: "{{ jenkins_process_user }}"
EOF

# ─── vars/adminpass.yml ───
cat > "$ROLE_DIR/vars/adminpass.yml" << 'EOF'
---
jenkins_admin_username: pinelabs_admin
jenkins_admin_password: H=f1WB>9Xpki
jenkins_admin_password_file: ""
jenkins_admin_token: ""
jenkins_admin_token_file: ""
EOF

# ─── vars/system.yml ───
cat > "$ROLE_DIR/vars/system.yml" << 'EOF'
---
memory: 1000
core: 1
EOF

# ─── vars/RedHat.yml ───
cat > "$ROLE_DIR/vars/RedHat.yml" << 'EOF'
---
jenkins_init_file: /usr/lib/systemd/system/jenkins.service
jenkins_systemd_override_dir: /etc/systemd/system/jenkins.service.d
jenkins_http_port_param: Environment="JENKINS_PORT"
jenkins_java_options_env_var: Environment="JAVA_OPTS"
EOF

# ─── meta/main.yml ───
cat > "$ROLE_DIR/meta/main.yml" << 'EOF'
---
galaxy_info:
  role_name: jenkins
  description: Install and configure Jenkins
  min_ansible_version: 2.3
  platforms:
    - name: Amazon
      versions:
        - 2023
  galaxy_tags:
    - jenkins
dependencies: []
EOF

# ─── handlers/main.yml ───
cat > "$ROLE_DIR/handlers/main.yml" << 'EOF'
---
- name: configure default users
  template:
    src: basic-security.groovy
    dest: "{{ jenkins_home }}/init.groovy.d/basic-security.groovy"
    owner: "{{ jenkins_process_user }}"
    group: "{{ jenkins_process_group }}"
    mode: 0775

- name: Restart jenkins
  service:
    name: jenkins
    state: restarted
EOF

# ─── templates/basic-security.groovy ───
cat > "$ROLE_DIR/templates/basic-security.groovy" << 'EOF'
#!groovy
import hudson.security.*
import jenkins.model.*

def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)

if (hudson.model.User.get('{{ jenkins_admin_username }}') == null) {
    println "--> creating local admin user"
    hudsonRealm.createAccount('{{ jenkins_admin_username }}', '{{ jenkins_admin_password }}')
    instance.setSecurityRealm(hudsonRealm)

    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.setAllowAnonymousRead(false)

    instance.setAuthorizationStrategy(strategy)
    instance.save()
}
EOF

# ─── tasks/pre_flight_check.yml ───
cat > "$ROLE_DIR/tasks/pre_flight_check.yml" << 'EOF'
---
- include_vars: system.yml

- fail:
    msg: "Minimum 1GB RAM and 1 CPU required"
  when:
    - ansible_memtotal_mb < memory
    - ansible_processor_count < core
EOF

# ─── tasks/setup-RedHat.yml ───
cat > "$ROLE_DIR/tasks/setup-RedHat.yml" << 'EOF'
---
- name: Install Java 17
  package:
    name: java-17-amazon-corretto-devel
    state: present

- name: Install fontconfig
  package:
    name: fontconfig
    state: present

- name: Install Jenkins using yum
  yum:
    name: jenkins
    state: present
  notify: configure default users

- name: Create systemd override directory
  file:
    path: "{{ jenkins_systemd_override_dir }}"
    state: directory
    mode: '0755'

- name: Reload systemd
  systemd:
    daemon_reload: yes
EOF

# ─── tasks/settings.yml ───
cat > "$ROLE_DIR/tasks/settings.yml" << 'EOF'
---
- file:
    path: /etc/systemd/system/jenkins.service.d
    state: directory
    mode: '0755'

- copy:
    dest: /etc/systemd/system/jenkins.service.d/override.conf
    content: |
      [Service]
      Environment="JENKINS_PORT={{ jenkins_http_port }}"
      Environment="JAVA_OPTS={{ jenkins_java_options }}"
      Environment="JENKINS_HOME={{ jenkins_home }}"
  notify: Restart jenkins

- systemd:
    daemon_reload: yes
EOF

# ─── tasks/main.yml ───
cat > "$ROLE_DIR/tasks/main.yml" << 'EOF'
---
- include_tasks: pre_flight_check.yml

- include_vars: "{{ ansible_os_family }}.yml"

- include_vars: adminpass.yml

- include_tasks: setup-RedHat.yml

- include_tasks: settings.yml

- service:
    name: jenkins
    state: started
    enabled: yes

- name: Wait for Jenkins
  uri:
    url: "{{ jenkins_url }}/login"
    status_code: [200,403]
  register: result
  retries: 60
  delay: 5
  until: result.status in [200,403]
EOF

info "Role created ✅"

# ── Step 3: Run playbook ─────────────────────────────────────────
info "Step 3/3 — Installing Jenkins ..."

ansible-playbook "$ROLE_DIR/playbook.yml" -i "$ROLE_DIR/hosts"

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Jenkins installed successfully!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo "URL: http://$(hostname -I | awk '{print $1}'):8080"
echo "User: pinelabs_admin"
echo "Service: systemctl status jenkins"
echo ""
```
