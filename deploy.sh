#!/usr/bin/env bash
#════════════════════════════════════════════════════════════════════
#  Jenkins One-Shot Installer — Amazon Linux 2023
#  Usage:  sudo bash deploy.sh
#════════════════════════════════════════════════════════════════════
set -euo pipefail

ROLE_DIR="/opt/jenkins"

GREEN='\033[0;32m' ; RED='\033[0;31m' ; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && error "Run as root:  sudo bash deploy.sh"

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
jenkins_repo_url: https://pkg.jenkins.io/redhat-stable/jenkins.repo
jenkins_repo_key_url: https://pkg.jenkins.io/redhat-stable/jenkins.io-2026.key
jenkins_pkg_url: https://pkg.jenkins.io/redhat-stable
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
  register: jenkins_users_config

- name: Restart jenkins
  service: name=jenkins state=restarted
EOF

# ─── templates/basic-security.groovy ───
cat > "$ROLE_DIR/templates/basic-security.groovy" << 'EOF'
#!groovy
import hudson.security.*
import jenkins.model.*

def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
def users = hudsonRealm.getAllUsers()
users_s = users.collect { it.toString() }

if ("{{ jenkins_admin_username }}" in users_s) {
    println "Admin user already exists - updating password"
    def user = hudson.model.User.get('{{ jenkins_admin_username }}');
    def password = hudson.security.HudsonPrivateSecurityRealm.Details.fromPlainPassword('{{ jenkins_admin_password }}')
    user.addProperty(password)
    user.save()
}
else {
    println "--> creating local admin user"
    hudsonRealm.createAccount('{{ jenkins_admin_username }}', '{{ jenkins_admin_password }}')
    instance.setSecurityRealm(hudsonRealm)
    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    instance.setAuthorizationStrategy(strategy)
    strategy.setAllowAnonymousRead(false)
    jenkins.model.Jenkins.instance.getDescriptor("jenkins.CLI").get().setEnabled(false)
    instance.save()
}
EOF

# ─── tasks/pre_flight_check.yml ───
cat > "$ROLE_DIR/tasks/pre_flight_check.yml" << 'EOF'
---
- name: Include system variables
  include_vars: system.yml

- name: Setting up of jenkins
  fail:
    msg: "Server does not meet minimum requirements (1 GB RAM, 1 core)"
  when: ( ansible_memtotal_mb < 0.85*memory ) or ( ansible_processor_count < core )
EOF

# ─── tasks/setup-RedHat.yml ───
cat > "$ROLE_DIR/tasks/setup-RedHat.yml" << 'EOF'
---
- name: Install Java 17 (Amazon Corretto)
  package:
    name: java-17-amazon-corretto-devel
    state: present

- name: Verify Java installation
  command: java -version
  register: java_check
  changed_when: false

- name: Ensure dependencies are installed
  package:
    name:
      - fontconfig
    state: present

- name: Ensure Jenkins repo is installed
  get_url:
    url: "{{ jenkins_repo_url }}"
    dest: /etc/yum.repos.d/jenkins.repo
  when: jenkins_repo_url | length > 0

- name: Add Jenkins repo GPG key
  rpm_key:
    state: present
    key: "{{ jenkins_repo_key_url }}"

- name: Ensure Jenkins is installed
  package:
    name: jenkins
    state: "{{ jenkins_package_state }}"
  notify: configure default users

- name: Create systemd override directory
  file:
    path: "{{ jenkins_systemd_override_dir }}"
    state: directory
    owner: root
    group: root
    mode: '0755'

- name: Reload systemd daemon
  systemd:
    daemon_reload: yes
EOF

# ─── tasks/settings.yml ───
cat > "$ROLE_DIR/tasks/settings.yml" << 'EOF'
---
- name: Create systemd override directory for Jenkins
  file:
    path: /etc/systemd/system/jenkins.service.d
    state: directory
    owner: root
    group: root
    mode: '0755'

- name: Deploy Jenkins systemd override
  copy:
    dest: /etc/systemd/system/jenkins.service.d/override.conf
    owner: root
    group: root
    mode: '0644'
    content: |
      [Service]
      Environment="JENKINS_PORT={{ jenkins_http_port }}"
      Environment="JAVA_OPTS={{ jenkins_java_options }}"
      Environment="JENKINS_HOME={{ jenkins_home }}"
      Environment="JENKINS_PREFIX={{ jenkins_url_prefix }}"
  register: jenkins_systemd_override
  notify:
    - Restart jenkins

- name: Reload systemd after override change
  systemd:
    daemon_reload: yes
  when: jenkins_systemd_override.changed

- name: Ensure jenkins_home {{ jenkins_home }} exists
  file:
    path: "{{ jenkins_home }}"
    state: directory
    owner: jenkins
    group: jenkins
    mode: u+rwx
    follow: true

- name: Create custom init scripts directory
  file:
    path: "{{ jenkins_home }}/init.groovy.d"
    state: directory
    owner: "{{ jenkins_process_user }}"
    group: "{{ jenkins_process_group }}"
    mode: 0775

- name: Trigger handlers immediately in case Jenkins was installed
  meta: flush_handlers
EOF

# ─── tasks/plugins.yml ───
cat > "$ROLE_DIR/tasks/plugins.yml" << 'EOF'
---
- name: Get Jenkins admin password from file
  slurp:
    src: "{{ jenkins_admin_password_file }}"
  register: adminpasswordfile
  no_log: true
  when: jenkins_admin_password_file | length > 0

- name: Set Jenkins admin password fact
  set_fact:
    jenkins_admin_password:
      "{{ adminpasswordfile['stdout'] | default(jenkins_admin_password) }}"
  no_log: true

- name: Install Jenkins plugins
  jenkins_plugin:
    name: "{{ item }}"
    jenkins_home: "{{ jenkins_home }}"
    url_username: "{{ jenkins_admin_username }}"
    url_password: "{{ jenkins_admin_password }}"
    state: "{{ jenkins_plugins_state }}"
    timeout: "{{ jenkins_plugin_timeout }}"
    updates_expiration: "{{ jenkins_plugin_updates_expiration }}"
    url: "{{ jenkins_url }}"
    with_dependencies: "{{ jenkins_plugins_install_dependencies }}"
  with_items: "{{ jenkins_plugins }}"
  when: jenkins_admin_password | length > 0
  notify: Restart jenkins
EOF

# ─── tasks/main.yml ───
cat > "$ROLE_DIR/tasks/main.yml" << 'EOF'
---
- name: Include file for remote system configuration
  include_tasks: pre_flight_check.yml

- name: Include OS-Specific variables
  include_vars: "{{ ansible_os_family }}.yml"

- name: Include admin variables
  include_vars:
    file: adminpass.yml

- name: Define jenkins_repo_url
  set_fact:
    jenkins_repo_url: "{{ jenkins_repo_url }}"
  when: jenkins_repo_url is not defined

- name: Define jenkins_repo_key_url
  set_fact:
    jenkins_repo_key_url: "{{ jenkins_repo_key_url }}"
  when: jenkins_repo_key_url is not defined

- name: Define jenkins_pkg_url
  set_fact:
    jenkins_pkg_url: "{{ jenkins_pkg_url }}"
  when: jenkins_pkg_url is not defined

- include_tasks: setup-RedHat.yml

- include_tasks: settings.yml

- name: Ensure Jenkins is started and runs on startup
  service:
    name: jenkins
    state: started
    enabled: yes

- name: Wait for Jenkins to be ready
  uri:
    url: "{{ jenkins_url }}/login"
    method: GET
    status_code: [200, 403]
    return_content: no
  register: result
  retries: "{{ jenkins_connection_retries }}"
  delay: "{{ jenkins_connection_delay }}"
  until: result.status in [200, 403]
  changed_when: false

- name: Check if jenkins-cli jar file exists
  stat:
    path: "{{ jenkins_jar_location }}"
  register: Jenkins_jar_path

- name: Get the jenkins-cli jarfile from the Jenkins server
  get_url:
    url: "{{ jenkins_url }}/jnlpJars/jenkins-cli.jar"
    dest: "{{ jenkins_jar_location }}"
  register: jarfile_get
  until: "'OK' in jarfile_get.msg or 'file already exists' in jarfile_get.msg"
  retries: 5
  delay: 10
  check_mode: false
  when: not Jenkins_jar_path.stat.exists

- name: Remove Jenkins security init scripts after first startup
  file:
    path: "{{ jenkins_home }}/init.groovy.d/basic-security.groovy"
    state: absent

- include_tasks: plugins.yml
EOF

info "Role created ✅"

# ── Step 3: Run Ansible Playbook ─────────────────────────────────
info "Step 3/3 — Installing Jenkins ..."
ansible-playbook "$ROLE_DIR/playbook.yml" -i "$ROLE_DIR/hosts"

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅  Jenkins installed successfully!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  🌐  URL:      http://$(hostname -I | awk '{print $1}'):8080"
echo -e "  👤  User:     pinelabs_admin"
echo -e "  📁  Home:     /var/lib/jenkins"
echo -e "  📋  Service:  sudo systemctl status jenkins"
echo ""
