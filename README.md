Patch Management
=========

An intelligent ansible play to manage patching Linux servers (and eventually windows too)

### Instructions

#### Command Line Useage
From the command line you need to specify the value of hosts as an extra_vars entry:

```
ansible-playbook PatchSystems.yaml -e "hosts=<valid hosts input>"
```

The playbook defaults rebooting servers after patching. Override the reboot var to change this.

```
ansible-playbook PatchSystems.yaml -e "hosts=<valid hosts input> reboot=false"
```

You may opt to specify what tags to act on. The two tags allow you to only run parts of the plays.

* Options:
  * pin      - Performs only the kernel package pinning or versionlock part of the role
  * patch    - Performs patching only i.e. skips pinning

This example would perform package pinning:

```
ansible-playbook PatchSystems.yaml -e "hosts=tag_site_example_com" --tags "pin"
```

##### Updating Compatible Kernel Versions
We currently pin Kernel packages so that we don't break support for a host agent that loads a kernel module:

 1) Update the appropriate vars file for with the new most current kernel version for the distribution

i.e  vars/ubuntu_12.yaml

```
---
kernel_version: "3.2.0.70*"
```

### Contribution Instructions
 * Every YAML file must follow this format:

```
---
   
# Location <PATH TO FILE>
# <PURPOSE/DESCRIPTIVE STATEMENT>

<content>
```

Additionally, all contributions must adhere to the same standards found [here](https://github.com/nousdefions/NWP-AnsibleRules)
