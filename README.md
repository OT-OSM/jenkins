Ansible Role: osm_jenkins
=========
An ansible role to install and configure jenkins server.

Version History
---------------

|**Date**| **Version**| **Description**| **Changed By** |
|----------|---------|---------------|-----------------|
|**June '15, 19** | v.1.0 | Initial Draft | Sudipt Sharma |
|**June '6, 20** | v.1.1 | Added support for managing global credential | Shivam Tomar |

Salient Features
----------------
* This role will check the system requirement(like memory and cpu cores) of remote host and if system requirements are satisfied then it will install latest jenkins version available in repository but if you want to install a specific veriosn you may pass it in variables.
* This role is configuring jenkins global credentials as a code. To use this feature you just need to set variable as **configuration_as_code="enabled"**

Supported OS
------------
  * CentOS:7
  * CentOS:6
  * Ubuntu:bionic
  * Ubuntu:xenial

Dependencies
------------
* Java {version 8 preferred}

Requirements
------------
* curl
* libselinux-python
* initscripts
* apt-transport-https

Role Variables
--------------

|**Variables**| **Default Values**| **Description**|
|----------|---------|---------------|
| memory | 1000 | total memory(in mb) that should be present at remote host|
| core | 1 | total number of cores that should be present at remote host|
| jenkins_admin_username | admin | Username of Admin |
| jenkins_admin_password | admin | Password for Admin user|
| jenkins_connection_delay | 5 | Wait for Jenkins to start up before proceeding |
| jenkins_connection_retries | 60| Retry to execute task if it fails to start Jenkins |
| jenkins_home | /var/lib/jenkins | Home Directory of jenkins|
| jenkins_hostname | localhost| Hostname for Jenkins |
| jenkins_http_port | 8080 | Port on which Jenkins runs|
| jenkins_jar_location | /opt/jenkins-cli.jar | Location where jar file for jenkins stores|
| jenkins_url_prefix | ""| URL prefix used in jenkins url|
| jenkins_java_options | "-Djenkins.install.runSetupWizard=false" | |
| jenkins_plugins| ['git']| Plugins add in Jenkins|
| jenkins_plugins_state | present | Jenkins plugin state|
| jenkins_plugin_updates_expiration | 86400 | Number of seconds after which a new copy of the update-center.json file is downloaded|
| jenkins_plugin_timeout | 300 | Jenkins Server connection timeout in secs|
| jenkins_plugins_install_dependencies | yes | Defines whether to install plugin dependencies. |
| jenkins_process_user | jenkins | Jenkins process username|
| jenkins_process_group | "{{ jenkins_process_user }}" | Jenkins process groupname|
| configuration_as_code | "disabled"  | Update its value to "enabled" for managing global credential as a code | 

Inventory
----------
An inventory should look like this:-
```ini
[jenkinshost]                 
192.168.1.198    ansible_user=ubuntu   
192.168.3.201    ansible_user=opstree 
```

Example Playbook
----------------

* Here is an example playbook:-

```sh
---
- hosts: jenkinshost
  become: yes
  roles:
    - jenkins

```
* ansible-playbook site.yml

**After the successful installation of jenkins, browse through the jenkins url and you would get your login page**
![login](./media/login.png)

Future Proposed Changes
-----------------------

References
----------
- **[software](https://jenkins.io/)**

Author Information
------------------

- **[Yashvinder Hooda](mailto:yashvinder.hooda@opstree.com)*
- **[Jeff Geerling](mailto:)*
