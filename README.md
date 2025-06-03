Ansible Role: Jenkins
=====================
An Ansible role to **install** and **configure Jenkins**, including support for **Jenkins Configuration as Code (JCasC)** and **custom plugin management**.

🔧 Salient Features
-------------------
- ✅ Flexible Jenkins Installation
  
  Installs the latest Jenkins version available in system repositories by default, or a user-defined version when specified.

- 🔌 Dynamic Plugin Management

  Supports installation of Jenkins plugins through default variables, external YAML files (plugins_override.yml)—ideal for clean, modular, and environment-specific plugin management.

- 🧩 Jenkins Configuration as Code (JCasC)

  Enables declarative configuration of Jenkins (users, tools, security, etc.) by simply toggling a variable and supplying a YAML config file.

- ⚙️ Cross-Platform Compatibility

  Compatible with both RHEL-based (e.g., RockyLinux) and Debian-based (e.g., Ubuntu) operating systems.

🖥️ Supported OS
------------
  * Rockylinux:9
  * Ubuntu:24
  * Ubuntu:22

📦 Dependencies
------------
* Java {version 21 preferred}

🔧 Requirements
------------
* curl
* libselinux-python
* initscripts
* apt-transport-https

⚙️ Role Variables
--------------

|**Variables**| **Default Values**| **Description**|
|----------|---------|---------------|
| `jenkins_admin_username`            | `admin`                                       | Jenkins admin username                                                         |
| `jenkins_admin_password`            | `admin`                                       | Jenkins admin password                                                         |
| `jenkins_connection_delay`          | `5`                                           | Delay (in seconds) before connecting to Jenkins                                |
| `jenkins_connection_retries`        | `60`                                          | Number of retries while waiting for Jenkins startup                            |
| `jenkins_home`                      | `/var/lib/jenkins`                            | Jenkins home directory                                                          |
| `jenkins_hostname`                  | `localhost`                                   | Jenkins hostname                                                                |
| `jenkins_http_port`                 | `8080`                                        | Jenkins HTTP port                                                               |
| `jenkins_jar_location`              | `/opt/jenkins-cli.jar`                        | Path to Jenkins CLI JAR                                                        |
| `jenkins_url_prefix`                | `""`                                          | Optional Jenkins URL prefix                                                    |
| `jenkins_java_options`             | `-Djenkins.install.runSetupWizard=false`      | Java options for Jenkins                                                       |
| `jenkins_plugins`                   | `[{'name': 'git'}]`                           | List of Jenkins plugins to install                                             |
| `jenkins_plugins_state`             | `present`                                     | State of plugins (`present` or `latest`)                                       |
| `jenkins_plugin_updates_expiration`| `86400`                                       | Time (in seconds) before plugin update cache expires                           |
| `jenkins_plugin_timeout`            | `300`                                         | Plugin installation timeout (in seconds)                                       |
| `jenkins_plugins_install_dependencies` | `true`                                  | Install plugin dependencies automatically                                      |
| `jenkins_process_user`              | `jenkins`                                     | Jenkins process owner user                                                     |
| `jenkins_process_group`             | `{{ jenkins_process_user }}`                 | Jenkins process group                                                           |
| `jenkins_enable_configuration_as_code` | `false`                                   | Set to `"true"` to enable JCasC configuration                                  |
| `jenkins_casc_file_src`             | `files/jenkins.yaml`                          | Default JCasC YAML file location (can be overridden at runtime)                |

📁 Inventory
-------------
An inventory should look like this:-
```ini
[jenkinshost]                 
192.168.1.198    ansible_user=ubuntu   
192.168.3.201    ansible_user=opstree 
```

🚀 Example Playbook
--------------------

* Here is an example playbook:-

```sh
---
- hosts: jenkinshost
  become: yes
  roles:
    - jenkins

```
* ansible-playbook site.yml


🛠️ Usage
--------
### 🔧 Full Jenkins Installation

```shell
ansible-playbook -i hosts site.yml
```

### 📦 Plugin Installation Only

```shell
ansible-playbook -i hosts site.yml --tags "jenkins_plugins"
```
Default plugins (from defaults/main.yml):
```yaml
jenkins_plugins:
  - name: git
    version: 5.7.0
  - name: configuration-as-code
    version: 1947.v7d33fe23569c
```
Override using a YAML file:
```yaml
# plugins_override.yml
jenkins_plugins:
  - name: git
  - name: matrix-auth
    version: 3.2
```
```bash
ansible-playbook site.yml -tags "jenkins_plugins" -e @plugins_override.yml
```
**💡 Why use plugins_override.yml?**

Keeps your plugin configurations clean, version-controlled, and environment-specific—ideal for CI/CD setups and collaboration.

### 🧩 Jenkins Configuration as Code (JCasC)
Enable JCasC:
```yaml
jenkins_enable_configuration_as_code: true
```
Run:

Configure Jenkins with sample config from [files/](./files/): 

- To create Credentials using JCasC:
  ```shell
  ansible-playbook -i hosts site.yml --tags "jenkins_JCasC" -e 'jenkins_casc_file_src=files/credentials.yml
  ```
- To set Global Tool Configurations using JCasC:
  ```shell
  ansible-playbook -i hosts site.yml --tags "jenkins_JCasC" -e 'jenkins_casc_file_src=files/tools.yml
  ```
Use a Custom JCasC YAML:

```shell
ansible-playbook -i hosts site.yml --tags "jenkins_JCasC" -e 'jenkins_casc_file_src=/path/to/custom.yaml'
```
**📄 Need Help Creating Your Own jenkins.yaml?**

You can refer to official examples to build your own configuration:

🔗 [JCasC Demo Repository](https://github.com/jenkinsci/configuration-as-code-plugin/tree/master/demos)

Alternatively, use the provided examples under the files/ directory in this role.

🧪 Molecule Test
----------------
To test this role using Molecule, refer to the [Molecule Test Documentation](./molecule/README.md).

🔮 Future Enhancements
-----------------------
- Reverse proxy setup with NGINX
- Jenkins agent installation and registration

🔗 References
----------
- **[Java Official Website](https://www.java.com/en/)**
- **[Molecule (Ansible Role Testing)](https://ansible.readthedocs.io/projects/molecule/)**

📬 Contact Information
----------------------
For questions, suggestions, or issues related to this role, please contact:

📧 Email: [opensource@opstree.com](mailto:opensource@opstree.com)

🏢 Organization: [OpsTree Solutions](http://opstree.com)
