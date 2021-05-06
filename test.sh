#!/bin/bash

# Jail Configuration
allow_raw_sockets="1" 
allow_set_hostname="1"
allow_tun="1"
bpf="0"
defaultrouter="192.168.0.1"
dhcp="0"
interfaces=""
ip4_addr=""
pkglist="/tmp/pkg.json"
priority="99"
release="12.2-RELEASE" # LATEST
type="normal"
vnet="1"
vnet_default_interface="igb0"


# Pool locations for resources
configs='/mnt/pool1/configs/'
iocage='/mnt/pool1/iocage'
media='/mnt/pool1/media/'
p2p='/mnt/pool3/p2p/'
scripts='/mnt/pool1/scripts/'
user=''

# In Host mount points
configH='/mnt/config/'
p2pH='/mnt/p2p/'
mediaH='/mnt/media/'
scriptsH='/mnt/scripts/'


# Transmission stuff
trans_ip4_addr="vnet0|192.168.0.11/24"
trans_resolver=''
trans_conf_dir="$configH/transmission" # originally /var/db/transmission/
trans_download_dir="$p2pH/completed" # originally /mnt/incoming/transmission
trans_mkdirs="mkdir -pv $configH $mediaH $p2pH $scriptsH" # Originally 'mkdir -pv "/mnt/scripts/" "/mnt/users/dak180/" "/mnt/incoming/" "/mnt/torrents/" "/mnt/transmission/" "/var/db/transmission/" "/usr/local/etc/openvpn/"'
trans_watch_dir="$p2pH/torrents/autoload" # originally /mnt/transmission
trans_flags="--incomplete-dir $p2pH/incomplete --logfile /var/log/transmission.log" # originally --incomplete-dir /mnt/torrents --logfile /var/log/transmission.log

# Common Package list
tee "/tmp/pkg.json" << EOF
{
	"pkgs": [
	"bash",
	"bash-completion",
	"tmux",
	"wget",
	"curl",
	"nano",
	"sudo",
	"logrotate",
	"fortune-mod-freebsd-classic",
	"fortune-mod-bofh",
	"pkg-provides"
	]
} 

EOF


# media user file
tee "/tmp/user" << USEREOF
media:816:816::::Media access user:/nonexistant:/usr/local/bin/bash:

USEREOF


addParameter() {
	if [ "${!1}" != "" ]; then
		local newParam="$1='${!1}'"
		parameters="$2$prefix$parameters $newParam"
		return 0
	fi
	return 1
}


jail_initialise() {
	sudo iocage pkg "${jailName}" update && sudo iocage pkg "${jailName}" upgrade -y

#	sudo iocage exec -f "${jailName}" -- "pw groupadd -n jailmedia -g 1001"
#	sudo iocage exec -f "${jailName}" -- "mkdir -pv $configH $mediaH $p2pH $scriptsH"
}


pkg_repo() {
	# Set latest pkg repo
	sudo iocage exec -f "${jailName}" -- "mkdir -pv /usr/local/etc/pkg/repos"
	sudo iocage exec -f "${jailName}" -- 'tee "/usr/local/etc/pkg/repos/FreeBSD.conf" << EOF

FreeBSD: {
  url: "pkg+http://pkg.FreeBSD.org/\${ABI}/latest"
}

EOF'
}


setBaseParameters() {
	parameters=" -b -n ${jailName} -r ${release}"
	addParameter 'allow_raw_sockets'
	addParameter 'allow_set_hostname'
	addParameter 'bpf'
	addParameter 'dhcp'
	addParameter 'pkglist'
}


usrpths() {
	# Link files
	local usrpth="/mnt/scripts/$user"

#	sudo iocage exec -f "${jailName}" -- "cd /root/ && ln -s \"${usrpth}/.profile\" .bashrc"
#	sudo iocage exec -f "${jailName}" -- "cd /root/ && ln -fs .bashrc .profile"
#	sudo iocage exec -f "${jailName}" -- "cd /root/ && ln -s \"${usrpth}/.nanorc\" .nanorc"
#	sudo iocage exec -f "${jailName}" -- "cd /root/ && ln -s \"${usrpth}/.config\" .config"
}


clear


if [ "${1}" = "trans" ] || [ "${1}" = "transmission" ]; then
	jailName="transmission2"

	# Destroy old jail.
	if [ -d "$iocage/jails/${jailName}" ]; then
		if ! sudo iocage destroy -f "${jailName}"; then
			exit 2
		fi
	fi


	ip4_addr="${trans_ip4_addr}"
	resolver=${trans_resolver}
	setBaseParameters
	# Add optional parameters to list.
	addParameter 'allow_tun'
	addParameter 'interfaces'
	addParameter 'ip4_addr'
	addParameter 'priority'
	addParameter 'resolver'
	addParameter 'type'
	addParameter 'vnet'
	addParameter 'vnet_default_interface'

	# Create jail
	if ! sudo iocage create $parameters; then
		exit 1
	fi


	# Set Mounts
	sudo iocage exec -f "${jailName}" -- $trans_mkdirs
	sudo iocage fstab -a "${jailName}" "$configs $configH nullfs rw 0 0"
	sudo iocage fstab -a "${jailName}" "$media $mediaH nullfs rw 0 0"
	sudo iocage fstab -a "${jailName}" "$p2p $p2pH nullfs rw 0 0"
	sudo iocage fstab -a "${jailName}" "$scripts $scriptsH nullfs rw 0 0"


	# Generic Configuration
	pkg_repo
#	usrpths
	jail_initialise
	sudo iocage exec -f "${jailName}" -- 'ln -sf "/usr/local/plexdata/.bash_history" "/root/.bash_history"'


	# Install packages
	sudo iocage pkg "${jailName}" install -y openvpn transmission-daemon transmission-web transmission-cli transmission-utils base64 jq

	# Set permissions
	sudo iocage exec -f "${jailName}" -- 'adduser -f /tmp/user'
	sudo iocage exec -f "${jailName}" -- "pw groupmod $mediaGroup -m transmission"
	sudo iocage exec -f "${jailName}" -- "touch /var/log/transmission.log"
	sudo iocage exec -f "${jailName}" -- "chown transmission /var/log/transmission.log"


	
	# Set jail to start at boot.
	sudo iocage stop "${jailName}"
#	sudo iocage set boot="1" "${jailName}"
else
	echo "usage: $0 <application>"
fi


rm /tmp/pkg.json
rm /tmp/user
