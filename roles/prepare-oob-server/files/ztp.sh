#!/bin/bash
###################
#   ZTP Script
###################
# This function provides more information should the script die somewhere during execution
function error() {
  echo -e "\e[0;33mERROR: The Zero Touch Provisioning script failed while running the command \$BASH_COMMAND at line \$BASH_LINENO.\e[0m" >&2
}
# Instructs the script to send any errors encountered to the function above
trap error ERR
# Setup SSH key authentication for Ansible
mkdir -p /home/cumulus/.ssh
#wget -O /home/cumulus/.ssh/authorized_keys http://192.168.0.254/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCzH+R+UhjVicUtI0daNUcedYhfvgT1dbZXgY33Ibm4MOo+X84Iwuzirm3QFnYf2O3uyZjNyrA6fj9qFE7Ekul4bD6PCstQupXPwfPMjns2M7tkHsKnLYjNxWNql/rCUxoH2B6nPyztcRCass3lIc2clfXkCY9Jtf7kgC2e/dmchywPV5PrFqtlHgZUnyoPyWBH7OjPLVxYwtCJn96sFkrjaG9QDOeoeiNvcGlk4DJp/g9L4f2AaEq69x8+gBTFUqAFsD8ecO941cM8sa1167rsRPx7SK3270Ji5EUF3lZsgpaiIgMhtIB/7QNTkN9ZjQBazxxlNVN6WthF8okb7OSt" >> /home/cumulus/.ssh/authorized_keys
chmod 700 -R /home/cumulus/.ssh
chown cumulus:cumulus -R /home/cumulus/.ssh
# Setup SUDO access that does not require a password for all users in the "sudo" group
echo "cumulus ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10_cumulus
# Setup NTP
#   Remove the last 3 default NTP Servers
sed -i '/^server [1-3]/d' /etc/ntp.conf
#   Modify the first server to point to the oob-mgmt-server as the authoritative time source
sed -i 's/^server 0.cumulusnetworks.pool.ntp.org iburst/server 192.168.0.254 iburst/g' /etc/ntp.conf
# Check to see if the internet is reachable
ping 8.8.8.8 -c2
if [ "\$?" == "0" ]; then
  # Update the GPG key so we don't encounter errors during install process
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A88BBC95
  # Install the Cumulus External Repository Source
  cat << TOE > /etc/apt/sources.list.d/cumulus-apps.list
deb http://apps3.cumulusnetworks.com/repos/deb CumulusLinux-3 netq-1.1
TOE
  # Install NetQ
  apt-get update -qy
  apt-get install cumulus-netq -qy
  # Setup a Default configuration for NetQ
  cat << TOE > /etc/netq/netq.yml
#/etc/netq/netq.yml
# See /usr/share/doc/netq/examples for full configuration file
backend:
  port: 6379
  server: 192.168.0.254
  vrf: default
user-commands:
- commands:
  - command: /bin/cat /etc/network/interfaces
    key: config-interfaces
    period: '60'
  - command: /bin/cat /etc/ntp.conf
    key: config-ntp
    period: '60'
  service: misc
- commands:
  - command:
    - /usr/bin/vtysh
    - -c
    - show running-config
    key: config-quagga
    period: '60'
  service: zebra
TOE
  # Enable NTP and NetQ
  systemctl restart ntp
  systemctl restart netq-agent
  systemctl restart netqd
fi
#nohup bash -c 'sleep 2; shutdown now -r "Rebooting to Complete ZTP"' &
exit 0
# The line below is required to be a valid ZTP script
#CUMULUS-AUTOPROVISIONING
