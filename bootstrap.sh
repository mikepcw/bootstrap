#!/usr/bin/env bash

# Install newer version of Ansible
sudo apt-get -y install software-properties-common
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt-get update
sudo apt-get -y install ansible

# Add nvidia-docker role from Ansible Galaxy
sudo ansible-galaxy install ryanolson.nvidia-docker

# Write playbook
f=$(mktemp)
cat <<EOF > $f
- hosts: all
  sudo: true
  roles:
    - role: 'ryanolson.nvidia-docker'
      sudo: true
  tasks:
    - name: cuda | repo
      apt: deb=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64/cuda-repo-ubuntu1404_7.5-18_amd64.deb
    - name: cuda | install prereqs
      apt: name={{ item }} state=latest update_cache=yes cache_valid_time=600
      with_items:
        - build-essential
        - linux-source
        - linux-generic
        - dkms
    - name: cuda | install cuda driver and toolkit
      apt: name={{ item }} state=latest update_cache=yes
      with_items:
        - cuda
EOF

# Execute playbook
ansible-playbook -i "localhost," -c local $f

# cleanup
rm -f $f

exit
