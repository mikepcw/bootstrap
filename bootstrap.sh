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

# Install Docker if needed
tags="--skip-tags docker"
type docker >/dev/null 2>&1
if [ $? -eq 1 ] ; then
	# Add docker role from Ansible Galaxy
	ansible-galaxy install angstwad.docker_ubuntu --roles-path=/tmp/roles
	tags=
fi

# Write playbook
f=$(mktemp)
cat <<EOF > $f
- hosts: all
  become: true
  become_method: sudo
  vars:
    daemon_json:
      default-runtime: "nvidia"
      runtimes:
        nvidia:
          path: "/usr/bin/nvidia-container-runtime"
          runtimeArgs: []
  roles:
    - { role: angstwad.docker_ubuntu, tags: docker }
  tasks:
    - name: docker | add user to docker group
      user: name=$USER groups=docker append=yes
    - name: cuda | apt key
      apt_key:
        url: http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
        state: present
    - name: cuda | repo
      apt: deb=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
    - name: cuda | install prereqs
      apt: name={{ item }} state=latest update_cache=yes cache_valid_time=600
      with_items:
        - build-essential
        - linux-source
        - linux-generic
        - dkms
    - name: cuda | install cuda driver
      apt: name={{ item }} state=latest update_cache=yes
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
    - name: set docker default runtime
      copy:
        content: "{{ daemon_json | to_nice_json }}"
        dest: /etc/docker/daemon.json
        owner: root
        group: root
        mode: 0644
    - name: docker | restart service
      service: name=docker state=restarted enabled=yes
EOF

# Execute playbook
ansible-playbook -i "localhost," -c local "${tags}" $f

# cleanup
rm -f $f
rm -rf /tmp/roles

exit
