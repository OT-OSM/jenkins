Role Name
=========

This ROLE will install jenkins server 
- Supported Distributions
  * Redhat7
  * AmazonAMI 2
  * Ubuntu16

```I am working on to make this role work on ubuntu14 and redhat/centos verison 6, will update you guys once this is done ```

Jenkins Versions
=========

- This role will fetch and install latest jenkins version available in repository but if you want to install a specific veriosn you may pass it in variables. I have tested it with last 5 versions on RHEL7 and it is working fine.


Requirements
------------

* curl
* libselinux-python
* initscripts
* apt-transport-https


Role Variables
--------------

**jenkins username and password {change them for your installation}**
* jenkins_admin_username: admin
* jenkins_admin_password: admin

* jenkins_connection_delay: 5
* jenkins_connection_retries: 60
* jenkins_home: /var/lib/jenkins
* jenkins_hostname: localhost
* jenkins_http_port: 8080
* jenkins_jar_location: /opt/jenkins-cli.jar
* jenkins_url_prefix: ""
* jenkins_java_options: "-Djenkins.install.runSetupWizard=false"

* jenkins_plugins: ['git']
* jenkins_plugins_state: present
* jenkins_plugin_updates_expiration: 86400
* jenkins_plugin_timeout: 300
* jenkins_plugins_install_dependencies: yes

* jenkins_process_user: jenkins
* jenkins_process_group: "{{ jenkins_process_user }}"

Dependencies
------------

- Java {version 8 preferred}

Example Playbook
----------------

```how to```


```sh
hosts: Tag_Name_jenkins
become: yes
roles:
  - jenkins

```
* ansible-playbook site.yml --vault-password-file vault_secret.sh
> vault_secret.sh is a simple script with single echo statement as: echo $password, where $password will be used to decrypt variables file: vars/adminpass.yml containing jenkins admin user login credentials.

* Password for decrypting vars/adminpass.yml for this role is: OcCeybCiWist3

Plugins
-------
* By default it will install 'git' but you may pass more plugins in the list in defualts/main.yml playbook 

Author Information
------------------

- Yashvinder Hooda
- yashvinder.hooda@opstree.com

