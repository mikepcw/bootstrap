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
    - name: teamviewer | download installer
      get_url:
        url: https://dl.tvcdn.de/download/linux/version_14x/teamviewer_14.1.18533_amd64.deb
        dest: /tmp/teamviewer.deb
    - name: teamviewer | install package
      apt:
        deb: /tmp/teamviewer.deb
    - name: teamviewer | clean up
      file:
        state: absent
        path: /tmp/teamviewer.deb
EOF

# Execute playbook
ansible-playbook -i "localhost," -c local $f

# cleanup
rm -f $f

exit


