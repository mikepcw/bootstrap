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
  vars:
    username: "{{ ansible_env.SUDO_USER }}"
  tasks:
    - name: nx | get download page
      get_url:
        url: https://www.nomachine.com/download/download&id=6
        dest: /tmp/nomachine.html
    - name: nx | extract nomachine url
      shell: "grep -o https://download.nomachine.com/download/.*/Linux/nomachine.*.deb /tmp/nomachine.html"
      register: deb_url
    - name: nx | print download url
      debug: msg="{{ deb_url.stdout }}"
    - name: nx | download installer
      get_url:
        url: "{{ deb_url.stdout }}"
        dest: /tmp/nomachine.deb
    - name: nx | install nomachine
      apt:
        deb: /tmp/nomachine.deb
    - name: nx | create config dir
      file:
        path: "/home/{{ username }}/.nx/config/"
        state: directory
        owner: "{{ username }}"
        recurse: yes
    - name: nx | copy authorised users
      copy:
        src: "/home/{{ username }}/.ssh/authorized_keys"
        remote_src: yes
        dest: "/home/{{ username }}/.nx/config/authorized.crt"
        owner: "{{ username }}"
        group: "{{ username }}"
        mode: 0600
    - name: nx | restart service
      service:
        name: nxserver
        state: restarted
    - name: nx | clean up
      file:
        state: absent
        path: /tmp/nomachine.deb
EOF

# Execute playbook
ansible-playbook -i "localhost," -c local $f

# cleanup
rm -f $f

exit


