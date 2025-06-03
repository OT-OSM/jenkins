Molecule Test: Jenkins Role
--------------------------

This directory contains the [Molecule](https://molecule.readthedocs.io/) test scenarios for the `Jenkins` Ansible role. It helps ensure that the role installs and configures Jenkins correctly on supported platforms.

---

📁 Directory Structure
----------------------

```bash
molecule/
└── default/
    ├── converge.yml        # Playbook to apply the role on the test instance
    ├── Dockerfile.j2       # Jinja2 template to define the base Docker image
    ├── molecule.yml        # Core Molecule scenario configuration
    ├── prepare.yml         # Pre-tasks to run before applying the role (e.g., install dependencies)
    ├── requirements.yml    # Defines any role dependencies for the scenario
    ├── verify.yml          # Validates role outcomes
```
⚙️ Prerequisites
---------------
You must have the following tools installed:
- Python 3.x
- Docker installed and running
- `pip` (Python package manager)

🚀 Installing Molecule
----------------------
### 1. Create a Python virtual environment (recommended)
```bash
python3 -m venv .venv
source .venv/bin/activate
```

### 2. Install Molecule with Docker support
```bash
pip install molecule molecule-docker ansible-core docker
```

### 3. To verify Molecule is installed
```bash
molecule --version
```

🧪 Running Tests
----------------------

### 1. Clone the Repository

```bash
git clone https://github.com/ot-osm/jenkins.git
cd java/
```

### 2. Run Molecule Tests
**Run Full Test Lifecycle**

Execute the complete Molecule sequence (create → converge → verify → destroy) for all scenarios:

```shell
molecule test --all
```
**Run specific scenario**

- Runs the default scenario defined in `molecule/default/`:

    ```shell
    molecule test
    ```
- Custom Configuration Testing
    - Useful for testing:
        - Custom Jenkins version installation
        - Non-default port configuration
        - Plugin installation via overrides

    ```shell
    molecule test -s custom_config
    ```
**Run individual Molecule stages one by one**
```shell
molecule create      # Launch the test instance
molecule converge    # Apply the role
molecule verify      # Run test assertions
molecule destroy     # Clean up
```

🖥️ Platforms Tested
-------------------
- Ubuntu 24.04
- RockyLinux:9

You can customize platforms: in molecule.yml to add/remove distributions.


🧩 Custom Docker Image (Optional)
---------------------------------
If using a custom base image (e.g., Ubuntu 24.04 with systemd support), set pre_build_image: false in molecule.yml and define a Dockerfile.j2 under molecule/default.

📝 Notes
--------
- Ensure Docker daemon is running before executing Molecule commands.
- Use virtual environment to avoid dependency issues.
- After modifying molecule.yml, use molecule destroy before re-running to reset the environment.