# Project Guidelines

## Execution Environment

- **Target Host**: All installation scripts (starting from `kubernetes-app-setup`) MUST be executed on the host machine
  named **hierophant**.
- **Current Environment**: The VM where this code is being edited is **NOT** the host machine and is **NOT** responsible
  for running the installation.
- **Commands**: Commands like `sudo virsh`, `kubectl` and `talosctl` are intended to run locally on **hierophant**.
- **Paths**: Absolute paths (e.g., `/mnt/hegemon-share/share/code/kubernetes-app-setup` or
  `/var/lib/libvirt/images/...`) are relative to the file system of **hierophant**.
- **SSH**: SSH commands are intended to be executed from **hierophant** to other machines in the cluster. a user 'junie'
  has been added to 'hierophant' for this access
- **CONTEXT**: This document outlines the guidelines for executing scripts and accessing resources within the project
  environment. This will ensure consistency and security by defining the roles and responsibilities of different
  components.
- **TEMPORAL IMPORTANCE**: DO NOT ASSUME that all scripts or other resources described are current.
- **TEMPORAL IMPORTANCE**: ALWAYS ask before including a new script to make sure it is relevant to the current asks.