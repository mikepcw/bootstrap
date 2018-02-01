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

# Add docker role from Ansible Galaxy
ansible-galaxy install angstwad.docker_ubuntu --roles-path=/tmp/roles

# Write playbook
f=$(mktemp)
cat <<EOF > $f
- hosts: all
  become: true
  become_method: sudo
  roles:
    - angstwad.docker_ubuntu
  tasks:
    - name: docker | add user to docker group
      user: name=$USER groups=docker append=yes
    - name: cuda | apt key
      apt_key:
        url: http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
        state: present
    - name: cuda | repo
      apt: deb=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64/cuda-repo-ubuntu1404_8.0.61-1_amd64.deb
      when: (ansible_distribution == 'Ubuntu' and ansible_distribution_version == '14.04')
    - name: cuda | repo
      apt: deb=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
      when: (ansible_distribution == 'Ubuntu' and ansible_distribution_version == '16.04')
    - name: cuda | install prereqs
      apt: name={{ item }} state=latest update_cache=yes cache_valid_time=600
      with_items:
        - build-essential
        - linux-source
        - linux-generic
        - dkms
    - name: cuda | install cuda driver
      apt: name={{ item }} state=latest update_cache=yes
      when: (ansible_distribution == 'Ubuntu')
      with_items:
        - cuda-drivers
    - name: nvidia-docker | apt key
      apt_key:
        url: https://nvidia.github.io/nvidia-docker/gpgkey
        state: present
    - name: nvidia-docker | apt repo
      apt_repository:
        repo: "{{ item }}"
        state: present
        filename: 'nvidia-docker'
        update_cache: yes
      with_items:
        - "deb https://nvidia.github.io/libnvidia-container/ubuntu16.04/amd64 /"
        - "deb https://nvidia.github.io/nvidia-container-runtime/ubuntu16.04/amd64 /"
        - "deb https://nvidia.github.io/nvidia-docker/ubuntu16.04/amd64 /"
    - name: nvidia-docker | install
      apt:
        name: nvidia-docker2
        state: latest
    - name: docker | restart service
      service: name=docker state=restarted enabled=yes
EOF

# Execute playbook
ansible-playbook -i "localhost," -c local $f

# cleanup
rm -f $f

exit
