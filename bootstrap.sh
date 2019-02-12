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
# Add docker role from Ansible Galaxy
ansible-galaxy install angstwad.docker_ubuntu --roles-path=/tmp/roles
tags="--skip-tags docker"
type docker >/dev/null 2>&1
if [ $? -eq 1 ] ; then
	tags=
fi

# Write playbook
UBUNTU_REL=$(lsb_release -sr)
UBUNTU_REL_NODOT=${UBUNTU_REL//./}
DOCKER_VERSION="5:18.09.1*"
CUDA_VERSION="10.0.130-1"
f=$(mktemp)
cat <<EOF > $f
- hosts: all
  become: true
  become_method: sudo
  vars:
    docker_pkg_name: "docker-ce=${DOCKER_VERSION}"
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
        url: http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${UBUNTU_REL_NODOT}/x86_64/7fa2af80.pub
        state: present
    - name: cuda | repo
      apt: deb=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${UBUNTU_REL_NODOT}/x86_64/cuda-repo-ubuntu${UBUNTU_REL_NODOT}_${CUDA_VERSION}_amd64.deb
    - name: cuda | install prereqs
      apt:
        name: "{{ packages }}"
        state: latest 
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
        state: latest 
        update_cache: yes
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
        - "deb https://nvidia.github.io/libnvidia-container/ubuntu${UBUNTU_REL}/amd64 /"
        - "deb https://nvidia.github.io/nvidia-container-runtime/ubuntu${UBUNTU_REL}/amd64 /"
        - "deb https://nvidia.github.io/nvidia-docker/ubuntu${UBUNTU_REL}/amd64 /"
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
ansible-playbook -i "localhost," -c local ${tags} $f

# cleanup
rm -f $f
rm -rf /tmp/roles

exit
