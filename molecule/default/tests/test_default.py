import os
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_java(host):
    java_direc = host.file('/usr/lib/jvm')

    assert java_direc.is_directory


def test_jenkins_install(host):
    jenkins_direc = host.file('/var/lib/jenkins')

    assert jenkins_direc.is_directory


def test_init_file_present(host):
    os = host.system_info.distribution

    if os == 'debian':
        init_file = host.file('/etc/default/jenkins').content

        assert b'JENKINS_ARGS=--prefix=' in init_file.contains
        assert b'JENKINS_HOME=/var/lib/jenkins' in init_file.contains

    elif os == 'redhat':
        init_file = host.file('/etc/sysconfig/jenkins').content

        assert b'JENKINS_ARGS=--prefix=' in init_file.contains
        assert b'JENKINS_HOME=/var/lib/jenkins' in init_file.contains


def test_status(host):
    service = host.service("jenkins")

    assert service.is_running


def test_jenkins_port_change(host):
    os = host.system_info.distribution

    if os == 'debian':
        init_file = host.file('/etc/default/jenkins').content

        assert b'JENKINS_PORT=8080' in init_file.contains

    elif os == 'redhat':
        init_file = host.file('/etc/sysconfig/jenkins').content

        assert b'JENKINS_PORT=8080' in init_file.contains


def test_jenkins_init(host):
    init_groovy = host.file('/var/lib/jenkins/init.groovy.d')

    assert init_groovy.is_directory


def test_jenkins_url(host):
    url = host.run('curl http://localhost:8080')

    assert url.succeeded


def test_jenkins_cli(host):
    cli = host.file('/opt/jenkins-cli.jar')

    assert cli.is_file


def test_plugins(host):
    plugin_name = host.file('/var/lib/jenkins/plugins/*')

    assert plugin_name.exists
