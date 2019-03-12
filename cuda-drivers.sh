#!/usr/bin/env bash

# Ensure running as regular user
if [ $(id -u) -eq 0 ] ; then
    echo "Please run as a regular user"
    exit 1
fi

# Install newer version of Ansible
sudo apt-get -y install software-properties-common
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt-get update
sudo apt-get -y install ansible


# Write playbook
UBUNTU_REL=$(lsb_release -sr)
UBUNTU_REL_NODOT=${UBUNTU_REL//./}
CUDA_VERSION="10.1.105-1"
f=$(mktemp)
cat <<EOF > $f
- hosts: all
  become: true
  become_method: sudo
  vars:
    username: "{{ ansible_env.SUDO_USER }}"
  tasks:
    - name: cuda | apt key
      apt_key:
        url: http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${UBUNTU_REL_NODOT}/x86_64/7fa2af80.pub
        state: present
    - name: cuda | repo
      apt: deb=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${UBUNTU_REL_NODOT}/x86_64/cuda-repo-ubuntu${UBUNTU_REL_NODOT}_${CUDA_VERSION}_amd64.deb
    - name: cuda | install prereqs
      apt:
        name: "{{ packages }}"
        state: present
        update_cache: yes 
        cache_valid_time: 600
      vars:
        packages:
          - build-essential
          - linux-source
          - linux-generic
          - dkms
    - name: cuda | install cuda driver
      apt: 
        name: "cuda-drivers"
        state: present
        update_cache: yes
EOF

# Execute playbook
ansible-playbook -i "localhost," -c local $f

# cleanup
rm -f $f

exit


