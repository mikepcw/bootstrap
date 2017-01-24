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

# Add nvidia-docker role from Ansible Galaxy
ansible-galaxy install ryanolson.nvidia-docker --roles-path=/tmp/roles

# Write playbook
f=$(mktemp)
cat <<EOF > $f
- hosts: all
  become: true
  become_method: sudo
  roles:
    - role: 'ryanolson.nvidia-docker'
  tasks:
    - name: docker | add user to docker group
      user: name=$USER groups=docker append=yes
    - name: docker | modify default subnet
      lineinfile: dest=/etc/default/docker regexp="^DOCKER_OPTS" insertafter="^#DOCKER_OPTS" \
          line='DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4 --bip=192.168.99.1/24 --fixed-cidr=192.168.99.0/24"'
    - name: cuda | repo
      apt: deb=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64/cuda-repo-ubuntu1404_7.5-18_amd64.deb
      when: (ansible_distribution == 'Ubuntu' and ansible_distribution_version == '14.04')
    - name: cuda | repo
      apt: deb=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_8.0.44-1_amd64.deb
      when: (ansible_distribution == 'Ubuntu' and ansible_distribution_version == '16.04')
    - name: cuda | install prereqs
      apt: name={{ item }} state=latest update_cache=yes cache_valid_time=600
      with_items:
        - build-essential
        - linux-source
        - linux-generic
        - dkms
    - name: cuda | install cuda driver and toolkit
      apt: name={{ item }} state=latest update_cache=yes
      when: (ansible_distribution == 'Ubuntu')
      with_items:
        - cuda
EOF

# Execute playbook
ansible-playbook -i "localhost," -c local $f

# cleanup
rm -f $f

exit
