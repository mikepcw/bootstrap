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
f=$(mktemp)
cat <<EOF > $f
- hosts: all
  become: true
  become_method: sudo
  tasks:
    - name: desktop | install xubuntu-core
      apt:
        name: xubuntu-core
        state: present
        update_cache: yes
    - name: desktop | enable auto-login
      lineinfile:
        path: /usr/share/lightdm/lightdm.conf.d/60-xubuntu.conf
        line: "autologin-user={{ ansible_env.SUDO_USER }}"
    - name: desktop | auto-login user
      service:
        name: lightdm
        state: restarted
EOF

# Execute playbook
ansible-playbook -i "localhost," -c local $f

# cleanup
rm -f $f

exit


