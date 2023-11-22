#!/bin/bash
# shellcheck disable=SC2236,SC2086,SC2068,SC2317,SC2155

# Config

# Write out a default config file
function jConfig {
	tee > "${configFile}" <<"EOF"
# Set this to 0 to enable
defaultFile="1"

# Jail creation config file
configVers="0" # Do not edit this.

# Resolver lines for different vlans for jails to connect to (vlans must already be defined in the network -> interface section of the gui). Necessary only if the vlan is different than the one used for the web interface.
# If you do not have vlans this can be ignored.
resolver60="search local.dak180.com local;nameserver 192.168.60.1"
resolver04="search local.dak180.com local;nameserver 192.168.4.1"

# The release to base jails on.
ioRelease="13.1-RELEASE" # LATEST

# Common paths to be mounted into jails (relative to the host).
mediaPth="/mnt/data/Media" # path to media; will be mounted to `/media` in jails
jDataPath="/mnt/jails/Data" # prefix path to where persistant jail application data will be ie: `/mnt/jails/Data/znc` these datasets will need to be created prior to making the jail
gitPath="/mnt/data/git" # a location for git repos so a different Record Size can be set
backupPth="/mnt/data/Backups" # prefix path to backup locations ie: `/mnt/data/Backups/plex`
scriptPth="/mnt/jails/scripts" # path to a common set of scripts
thingPath="/mnt/data/Things" # path to a general SMB share
userPth="/mnt/jails/users/dak180" # path to a full user directory on the base system

# Common paths in jails (relative to the jail).
usrpth="/mnt/scripts/user" # where user files are loaded into jails ie: .bashrc .profile .nanorc .config/*

# Common Package list that will be installed into every jail
tee "/tmp/pkg.json" << EOL
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

EOL

##### Jail specific settings
# See https://www.freebsd.org/cgi/man.cgi?iocage#PROPERTIES for some more details on what can be set in <ipset>.

# Plex
{
# Checklist before creating this jail:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `plex` is created on the main system with UID `972`
# Ensure a user named `tautulli` is created on the main system with UID `892`
# ${mediaPth} is set and is r/w by `jailmedia`
# ${scriptPth} is set and is r/w by `jailmedia`
# ${jDataPath}/plex is set and is owned by `plex`
# ${backupPth}/plex is set and is owned by `plex`
# ${jDataPath}/Tautulli is set and is owned by `tautulli`
# See https://www.truenas.com/community/threads/activating-plex-hardware-acceleration.75391/#post-525442 for hardware transcoding setup


# In this example we are disabling ipv6, setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the same as the web interface), and set the use of DHCP and a fixed MAC address pair to go with it.
_plex=(
vnet="1"
allow_raw_sockets="1"
ip6="disable"
interfaces="vnet0:bridge0"
vnet_default_interface="vlan10"
bpf="1"
dhcp="1"
vnet0_mac="B213DD984A80 B213DD984A7F"
)

# Setting a custom devfs rule set; used for setting up hardware transcodes, comment to disable
_plexDevfs="109"

if [ ! -z "${_plex_devfs}" ]; then
_plex+=(
devfs_ruleset="${_plex_devfs}"
)
fi

}

# Transmission
{
torntPath="/mnt/data/torrents" # a temp location for torrents to land so a different Record Size can be set
# Checklist before creating this jail:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `transmission` is created on the main system with UID `921`
# ${mediaPth} is set and is r/w by `jailmedia`
# ${scriptPth} is set and is r/w by `jailmedia`
# ${jDataPath}/transmission is set and is owned by `transmission`
# ${jDataPath}/openvpn is set and is owned by `root`
# ${torntPath} is set and is owned by `transmission` and is r/w by `jailmedia`
# ${thingPath}/Torrents is set and is r/w by `jailmedia`
# pia-port-forward.sh, ipfw.rules, transmission.crontab and transmission.logrotate are in ${scriptPth}/trans


# In this example we are disabling ipv6, allowing tun interfaces, setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the different from the web interface so we set the appropriate resolver), and set the use of DHCP, and a fixed MAC address pair to go with it.
_transmission=(
vnet="1"
allow_raw_sockets="1"
ip6="disable"
allow_tun="1"
interfaces="vnet0:bridge60"
vnet_default_interface="vlan60"
resolver="${resolver60}"
bpf="1"
dhcp="1"
vnet0_mac="4a3a78771683 4a3a78771682"
)

# Name of openvpn config file
_transmission_openvpn_configfile="openvpn.conf"

# Static route to allow cross vlan communication; comment to disable
_transmission_static="192.168.0.0/16 192.168.60.1"

}

# Unifi
{
# Checklist before creating this jail:
# Ensure a user named `unifi` is created on the main system with UID `975`
# ${jDataPath}/unifi is set and is owned by `unifi`
# ${scriptPth} is set and is r/w by `jailmedia`


# In this example we are setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the different from the web interface so we set the appropriate resolver), and set the use of DHCP and a fixed MAC address pair to go with it.
_unifi=(
vnet="1"
allow_raw_sockets="1"
interfaces="igb0:bridge4"
vnet_default_interface="igb0"
resolver="${resolver04}"
bpf="1"
dhcp="1"
vnet0_mac="02ff608700b4 02ff608700b5"
)

}

# Netdata
{
# Checklist before creating this jail:
# Ensure a user named `netdata` is created on the main system with UID `302`
# ${jDataPath}/netdata is set and is owned by `netdata`
# ${jDataPath}/netdata/config is set
# ${jDataPath}/netdata/cache is set
# ${jDataPath}/netdata/db is set
# ${jDataPath}/netdata/smartd is set
# ${scriptPth} is set and is r/w by `jailmedia`
# netdata.crontab and netdata.logrotate are in ${scriptPth}/netdata
# Add a tunable on the main system: type: rc.conf | Variable: `smartd_daemon_flags` | Value: `${smartd_daemon_flags} --attributelog=<jDataPath>/netdata/smartd/`


# In this example we are setting NAT and the port forwards, setting the name of the bridge we are connecting to (or creating), and a fixed MAC address pair to go with it.
_netdata=(
allow_raw_sockets="1"
nat="1"
nat_forwards="tcp(19999:19999)"
interfaces="vnet0:bridge0"
vnet0_mac="02ff602be694 02ff602be695"
)

}

# PVR
{
# Checklist before creating this jail:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `sonarr` is created on the main system with UID `351`
# Ensure a user named `radarr` is created on the main system with UID `352`
# Ensure a user named `jackett` is created on the main system with UID `354`
# Ensure a user named `bazarr` is created on the main system with UID `357`
# ${mediaPth} is set and is r/w by `jailmedia`
# ${scriptPth} is set and is r/w by `jailmedia`
# ${torntPath} is set and is owned by `transmission` and is r/w by `jailmedia`
# ${thingPath}/Torrents is set and is r/w by `jailmedia`
# ${jDataPath}/sonarr is set and is owned by `sonarr`
# ${jDataPath}/radarr is set and is owned by `radarr`
# ${jDataPath}/jackett is set and is owned by `jackett`
# ${jDataPath}/bazarr is set and is owned by `bazarr`
### mono fixes (see: https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=258709)
# mono6.8-6.8.0.123.txz, py37-pillow-7.0.0.txz, py37-olefile-0.46.txz and ca-root-nss.crt are in ${scriptPth}/pvr


# In this example we are disabling ipv6, setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the different from the web interface so we set the appropriate resolver), and set the use of DHCP, a fixed MAC address pair to go with it, and that the plex and transmission jails should start first.
_pvr=(
vnet="1"
allow_raw_sockets="1"
ip6="disable"
interfaces="vnet0:bridge60"
vnet_default_interface="vlan60"
resolver="${resolver60}"
bpf="1"
dhcp="1"
vnet0_mac="02ff60df8049 02ff60df804a"
depends="plex transmission"
)

}

# ZNC
{
# Checklist before creating this jail:
# Ensure a user named `znc` is created on the main system with UID `897`
# ${jDataPath}/unifi is set and is owned by `znc`
# ${scriptPth} is set and is r/w by `jailmedia`


# In this example we are setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the same as the web interface), and set the use of DHCP and a fixed MAC address pair to go with it.
_znc=(
vnet="1"
allow_raw_sockets="1"
interfaces="vnet0:bridge0"
vnet_default_interface="vlan10"
bpf="1"
dhcp="1"
vnet0_mac="02ff609935af 02ff609935b0"
)

}

# Gitea
{
# Checklist before creating this jail:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `git` is created on the main system with UID `211` and home directory set to `${userPth}/../git
# Ensure a user named `git_daemon` is created on the main system with UID `964`
# ${scriptPth} is set and is r/w by `jailmedia`
# ${gitPath} is set and is owned by `git` and is r/w by `jailmedia`
# ${jDataPath}/gitea is set and is owned by `git`
# ${jDataPath}/gitea/etc is set
# ${jDataPath}/gitea/share is set


# In this example we are disabling ipv6, setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the same as the web interface), and set the use of DHCP, and a fixed MAC address pair to go with it.
_gitea=(
vnet="1"
allow_raw_sockets="1"
ip6="disable"
interfaces="vnet0:bridge0"
vnet_default_interface="vlan10"
bpf="1"
dhcp="1"
vnet0_mac="02ff60757089 02ff6075708a"
)

}

# Search
{
# Checklist before creating this jail:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `elasticsearch` is created on the main system with UID `965`
# ${mediaPth} is set and is r/w by `jailmedia`
# ${scriptPth} is set and is r/w by `jailmedia`
# ${thingPath} is set and is r/w by `jailmedia`
# ${jDataPath}/fscrawler is set and is owned by `elasticsearch`
# Download https://github.com/dadoonet/fscrawler/releases/tag/fscrawler-2.7 and unzip in ${jDataPath}/fscrawler
# ${jDataPath}/elasticsearch is set and is owned by `elasticsearch`
# ${jDataPath}/elasticsearch/etc is set
# ${jDataPath}/elasticsearch/db is set
# ${jDataPath}/kibana is set and is owned by `elasticsearch`
# elasticsearch.crontab is in ${scriptPth}/search


# In this example we are disabling ipv6, setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the different from the web interface so we set the appropriate resolver), and set the use of DHCP, and a fixed MAC address pair to go with it.
_search=(
vnet="1"
allow_raw_sockets="1"
ip6="disable"
interfaces="vnet0:bridge60"
vnet_default_interface="vlan60"
resolver="${resolver60}"
bpf="1"
dhcp="1"
vnet0_mac="02ff60ae0444 02ff60ae0445"
)

}

# Test
{
# Checklist before creating this jail:
# ${scriptPth} is set and is r/w by `jailmedia`


# In this example we are setting NAT, and setting the name of the bridge we are connecting to (or creating).
_test=(
vnet="1"
nat="1"
interfaces="vnet0:bridge0"
)

}

# Port
{
# Checklist before creating this jail:
# ${scriptPth} is set and is r/w by `jailmedia`


# In this example we are setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the same as the web interface), and set the use of DHCP.
_port=(
vnet="1"
interfaces="vnet0:bridge0"
vnet_default_interface="vlan10"
bpf="1"
dhcp="1"
)

}

EOF
}



while getopts ":c:t:n:" OPTION; do
	case "${OPTION}" in
		c)
			configFile="${OPTARG}"
		;;
		t)
			jlType="${OPTARG}"
		;;
		n)
			jlNType="${OPTARG}"
		;;
		?)
			# If an unknown flag is used (or -?):
			echo "${0} -c <configFile> -t <jailType> {-n <jailName>}" >&2
			exit 1
		;;
	esac
done

if [ -z "${configFile}" ]; then
	echo "Please specify a config file location; if none exist one will be created." >&2
	exit 1
elif [ ! -f "${configFile}" ]; then
	jConfig
	exit 0
elif [ -z "${jlType}" ]; then
	echo "Please specify a jail type." >&2
	exit 1
fi

# shellcheck source=./jls.cnfg
. "${configFile}"

# Do not run if the config file has not been edited.
if [ ! "${defaultFile}" = "0" ]; then
	echo "Please edit the config file for your setup" >&2
	exit 1
elif [ ! "${configVers}" = "0" ]; then
	mv "${configFile}" "${configFile}.bak"
	jConfig
	echo "The config has been changed please update it for your setup" >&2
	exit 1
fi



function portS {
	sudo iocage pkg "${jlName}" install -y svnup || echo "Failed to install packages." >&2; exit 1
	sudo iocage exec -f "${jlName}" -- 'cat /usr/local/etc/svnup.conf.sample | sed -e "s:#host=svn\.:host=svn\.:" > /usr/local/etc/svnup.conf'
	sudo iocage exec -f "${jlName}" -- "svnup ports -v 0" || echo "Failed to install packages." >&2; exit 1
	sudo iocage exec -f "${jlName}" -- "cd /usr/ports/ports-mgmt/portmaster && make install clean"
}

function usrpths {
	# Sets up command prompt and nano defaults in the jails.
	local usrpth="/mnt/scripts/user"

	# Link files
	sudo iocage exec -f "${jlName}" -- "cd /root/ && ln -s \"${usrpth}/.profile\" .bashrc"
	sudo iocage exec -f "${jlName}" -- "cd /root/ && ln -fs .bashrc .profile"
	sudo iocage exec -f "${jlName}" -- "cd /root/ && ln -s \"${usrpth}/.nanorc\" .nanorc"
	sudo iocage exec -f "${jlName}" -- "cd /root/ && ln -s \"${usrpth}/.config\" .config"
}

function comn_mnt_pnts {
	# Sets script and user mount points
	local userName="$(basename "${userPth}")"
	sudo iocage exec -f "${jlName}" -- "mkdir -pv '/mnt/scripts/' \"/mnt/users/${userName}/\""
	sudo iocage fstab -a "${jlName}" "${scriptPth} /mnt/scripts/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${userPth} /mnt/users/${userName} nullfs rw 0 0"
}

function jl_init {
	sudo iocage pkg "${jlName}" update && sudo iocage pkg "${jlName}" upgrade -y

	# Common group to coordinate permissions across multiple jails.
	sudo iocage exec -f "${jlName}" -- "pw groupadd -n jailmedia -g 1001"
}

function pkg_repo {
	# Set latest pkg repo
	sudo iocage exec -f "${jlName}" -- "mkdir -p /usr/local/etc/pkg/repos"
	sudo iocage exec -f "${jlName}" -- 'tee "/usr/local/etc/pkg/repos/FreeBSD.conf" << EOF

FreeBSD: {
  url: "pkg+http://pkg.FreeBSD.org/\${ABI}/latest"
}

EOF'
}


# Jail Creation
if [ "${jlType}" = "plex" ]; then
	jlName="plex"
	{

	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" allow_mount="1" allow_mount_devfs="1" allow_set_hostname="1" enforce_statfs="1" "${_plex[@]}"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/usr/local/plexdata/" "/mnt/dbBackup/" "/var/db/tautulli/"'

	sudo iocage fstab -a "${jlName}" "${mediaPth} /media/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/plex /usr/local/plexdata/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${backupPth}/plex /mnt/dbBackup/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/Tautulli /var/db/tautulli/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	if [ ! -f "${jDataPath}/plex/.bash_history" ]; then
		sudo touch "${jDataPath}/plex/.bash_history"
	fi
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/plexdata/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y multimedia/plexmediaserver-plexpass tautulli ffmpeg yt-dlp py39-pycryptodomex AtomicParsley multimedia/libva-intel-driver multimedia/libva-intel-media-driver || echo "Failed to install packages." >&2; exit 1

	# Set permissions
	sudo iocage exec -f "${jlName}" -- "pw groupmod jailmedia -m plex"
	sudo iocage exec -f "${jlName}" -- "pw groupmod -n video -m plex"

	# Enable Services
	sudo iocage exec -f "${jlName}" -- 'sysrc plexmediaserver_plexpass_enable="YES"'
	sudo iocage exec -f "${jlName}" -- 'sysrc plexmediaserver_plexpass_support_path="/usr/local/plexdata"'

	sudo iocage exec -f "${jlName}" -- 'sysrc tautulli_enable="YES"'

	sudo iocage exec -f "${jlName}" -- "service tautulli start"
	sudo iocage exec -f "${jlName}" -- "service plexmediaserver_plexpass start"

	# Set jail to start at boot.
	sudo iocage stop "${jlName}"
	sudo iocage set boot="1" "${jlName}"
	if [ ! -z "${_plex_devfs}" ]; then
		sudo iocage set devfs_ruleset="109" "${jlName}"
	fi

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	}
elif [ "${jlType}" = "trans" ] || [ "${jlType}" = "transmission" ]; then
	jlName="transmission"
	{

	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" allow_set_hostname="1" priority="3" "${_transmission[@]}"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/mnt/incoming/" "/mnt/torrents/" "/mnt/transmission/" "/var/db/transmission/" "/usr/local/etc/openvpn/"'

	sudo iocage fstab -a "${jlName}" "${mediaPth} /mnt/incoming/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${torntPath} /mnt/torrents/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${thingPath}/Torrents /mnt/transmission/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/transmission /var/db/transmission/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/openvpn /usr/local/etc/openvpn/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	if [ ! -f "${jDataPath}/transmission/.bash_history" ]; then
		sudo touch "${jDataPath}/transmission/.bash_history"
	fi
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/var/db/transmission/.bash_history" "/root/.bash_history"'

	# Install packages
	if ! sudo iocage pkg "${jlName}" install -y openvpn base64 jq; then
		echo "Failed to install packages." >&2
		exit 1
	fi
	if ! sudo iocage pkg "${jlName}" install -y transmission-cli transmission-daemon transmission-utils; then
		echo "Failed to install packages." >&2
		exit 1
	fi

	# Set permissions
	sudo iocage exec -f "${jlName}" -- "pw groupmod jailmedia -m transmission"
	sudo iocage exec -f "${jlName}" -- "touch /var/log/transmission.log"
	sudo iocage exec -f "${jlName}" -- "chown transmission /var/log/transmission.log"

	# Enable Services
	## Transmission config
	sudo iocage exec -f "${jlName}" -- 'sysrc transmission_enable="YES"'
	sudo iocage exec -f "${jlName}" -- 'sysrc transmission_conf_dir="/var/db/transmission"'
	sudo iocage exec -f "${jlName}" -- 'sysrc transmission_download_dir="/mnt/incoming/transmission"'
	sudo iocage exec -f "${jlName}" -- 'sysrc transmission_flags="--incomplete-dir /mnt/torrents --logfile /var/log/transmission.log"'
	sudo iocage exec -f "${jlName}" -- 'sysrc transmission_watch_dir="/mnt/transmission"'

	## OpenVPN config
	sudo iocage exec -f "${jlName}" -- 'sysrc openvpn_enable="YES"'
	sudo iocage exec -f "${jlName}" -- "sysrc openvpn_configfile=\"/usr/local/etc/openvpn/${_transmission_openvpn_configfile}\""

	## Network config
	sudo iocage exec -f "${jlName}" -- 'sysrc firewall_enable="YES"'
	sudo iocage exec -f "${jlName}" -- 'sysrc firewall_script="/mnt/scripts/trans/ipfw.rules"'
	## Static route for local inter-vlan connections
	if [ ! -z "${_transmission_static}" ]; then
		sudo iocage exec -f "${jlName}" -- 'sysrc static_routes="net1"'
		sudo iocage exec -f "${jlName}" -- "sysrc net1=\"-net ${_transmission_static}\""
	fi

	# Start services
	sudo iocage exec -f "${jlName}" -- "wget http://ipinfo.io/ip -qO -"
	sudo iocage exec -f "${jlName}" -- "service openvpn start"
	sudo iocage exec -f "${jlName}" -- "service ipfw start"
	sudo iocage exec -f "${jlName}" -- "wget http://ipinfo.io/ip -qO -"
	sudo iocage exec -f "${jlName}" -- "service transmission start"

	# Final configuration
	sudo iocage exec -f "${jlName}" -- 'transmission-remote --torrent-done-script "/mnt/scripts/trans/torrentPost.sh"'
	sudo iocage exec -f "${jlName}" -- '/mnt/scripts/trans/pia-port-forward.sh >> /var/log/pia.log 2>&1'
	sudo iocage exec -f "${jlName}" -- "cp -sf /mnt/scripts/trans/transmission.logrotate /usr/local/etc/logrotate.d/transmission"
	sudo iocage exec -f "${jlName}" -- "crontab /mnt/scripts/trans/transmission.crontab"

	# Set jail to start at boot.
	sudo iocage stop "${jlName}"
	sudo iocage set boot="1" "${jlName}"

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	}
elif [ "${jlType}" = "unifi" ]; then
	jlName="unifi"
	{

	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" allow_set_hostname="1" priority="1" "${_unifi[@]}"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/usr/local/share/java/unifi/"'

	sudo iocage fstab -a "${jlName}" "${jDataPath}/unifi /usr/local/share/java/unifi/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	if [ ! -f "${jDataPath}/unifi/.bash_history" ]; then
		sudo touch "${jDataPath}/unifi/.bash_history"
	fi
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/share/java/unifi/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y unifi7 || echo "Failed to install packages." >&2; exit 1

	# Enable Services
	sudo iocage exec -f "${jlName}" -- 'sysrc unifi_enable="YES"'
	sudo iocage exec -f "${jlName}" -- "service unifi start"

	# Set jail to start at boot.
	sudo iocage stop "${jlName}"
	sudo iocage set boot="1" "${jlName}"

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	}
elif [ "${jlType}" = "netdata" ]; then
	jlName="netdata"
	{

	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" allow_set_hostname="1" mount_devfs="1" mount_fdescfs="1" mount_procfs="1" securelevel="-1" allow_sysvipc="1" sysvmsg="inherit" sysvsem="inherit" sysvshm="inherit" allow_mount_devfs="1" allow_mount_procfs="1" priority="1" "${_netdata[@]}"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/usr/local/etc/netdata/" "/var/cache/netdata/" "/var/db/netdata/" "/mnt/smartd/"'

	sudo iocage fstab -a "${jlName}" "${jDataPath}/netdata/config /usr/local/etc/netdata/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/netdata/cache /var/cache/netdata/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/netdata/db /var/db/netdata/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/netdata/smartd /mnt/smartd/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	if [ ! -f "${jDataPath}/netdata/config/.bash_history" ]; then
		sudo touch "${jDataPath}/netdata/config/.bash_history"
	fi
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/etc/netdata/.bash_history" "/root/.bash_history"'
	sudo iocage exec -f "${jlName}" -- "cp -sf /mnt/scripts/netdata/netdata.logrotate /usr/local/etc/logrotate.d/netdata"
	sudo iocage exec -f "${jlName}" -- "crontab /mnt/scripts/netdata/netdata.crontab"

	# Install packages
	sudo iocage pkg "${jlName}" install -y netdata netdata-go smartmontools || echo "Failed to install packages." >&2; exit 1

	# Enable Services
	sudo iocage exec -f "${jlName}" -- 'sysrc netdata_enable="YES"'
	sudo iocage exec -f "${jlName}" -- "service netdata start"

	# Set jail to start at boot.
	sudo iocage stop "${jlName}"
	sudo iocage set boot="1" "${jlName}"

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	}
elif [ "${jlType}" = "pvr" ]; then
	jlName="pvr"
	{

	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" allow_mlock="1" allow_set_hostname="1" "${_pvr[@]}"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/mnt/torrents/" "/mnt/transmission/" "/usr/local/sonarr/" "/usr/local/radarr/" "/usr/local/jackett/" "/usr/local/bazarr/"'

	sudo iocage fstab -a "${jlName}" "${mediaPth} /media/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${torntPath} /mnt/torrents/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${thingPath}/Torrents /mnt/transmission/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/sonarr /usr/local/sonarr/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/radarr /usr/local/radarr/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/jackett /usr/local/jackett/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/bazarr /usr/local/bazarr/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	if [ ! -f "${jDataPath}/sonarr/.bash_history" ]; then
		sudo touch "${jDataPath}/sonarr/.bash_history"
	fi
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/sonarr/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y sonarr jackett radarr bazarr mediainfo ca_root_nss || echo "Failed to install packages." >&2; exit 1
	sudo iocage pkg "${jlName}" lock -y jackett

### mono fixes (see: https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=258709)
	sudo iocage pkg "${jlName}" install -y /mnt/scripts/pvr/mono6.8-6.8.0.123.txz /mnt/scripts/pvr/py37-pillow-7.0.0.txz /mnt/scripts/pvr/py37-olefile-0.46.txz || echo "Failed to install packages." >&2; exit 1
	sudo iocage pkg "${jlName}" lock -y mono6.8
	sudo iocage exec -f "${jlName}" -- 'cert-sync "/mnt/scripts/pvr/ca-root-nss.crt"'
###

	# Set permissions
	sudo iocage exec -f "${jlName}" -- "chown -R jackett:jackett /usr/local/share/jackett/"
	sudo iocage exec -f "${jlName}" -- "pw groupmod jailmedia -m sonarr"
	sudo iocage exec -f "${jlName}" -- "pw groupmod jailmedia -m radarr"
	sudo iocage exec -f "${jlName}" -- "pw groupmod jailmedia -m jackett"
	sudo iocage exec -f "${jlName}" -- "pw groupmod jailmedia -m bazarr"


	# Enable Services
	sudo iocage exec -f "${jlName}" -- 'sysrc sonarr_enable="YES"'
	sudo iocage exec -f "${jlName}" -- 'sysrc radarr_enable="YES"'
	sudo iocage exec -f "${jlName}" -- 'sysrc jackett_enable="YES"'
	sudo iocage exec -f "${jlName}" -- 'sysrc bazarr_enable="YES"'

	sudo iocage exec -f "${jlName}" -- "service jackett start"
	sudo iocage exec -f "${jlName}" -- "service sonarr start"
	sudo iocage exec -f "${jlName}" -- "service radarr start"
	sudo iocage exec -f "${jlName}" -- "service bazarr start"

	# Set jail to start at boot.
	sudo iocage stop "${jlName}"
	sudo iocage set boot="1" "${jlName}"

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	}
elif [ "${jlType}" = "znc" ]; then
	jlName="znc"
	{

	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" allow_set_hostname="1" priority="2" "${_znc[@]}"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/usr/local/etc/znc/"'

	sudo iocage fstab -a "${jlName}" "${jDataPath}/znc/ /usr/local/etc/znc/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	if [ ! -f "${jDataPath}/znc/.bash_history" ]; then
		sudo touch "${jDataPath}/znc/.bash_history"
	fi
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/etc/znc/.bash_history" "/root/.bash_history"'

	# Install packagespy38-pip
	portS
	sudo iocage exec -f "${jlName}" -- "portmaster --packages-build --force-config --delete-build-only -db irc/znc"

	# Enable Services
	sudo iocage exec -f "${jlName}" -- 'sysrc znc_enable="YES"'
	sudo iocage exec -f "${jlName}" -- "service znc start"

	# Set jail to start at boot.
	sudo iocage stop "${jlName}"
	sudo iocage set boot="1" "${jlName}"

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	}
elif [ "${jlType}" = "gitea" ]; then
	jlName="gitea"
	{

	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" allow_set_hostname="1" priority="99" "${_gitea[@]}"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/usr/local/etc/gitea" "/usr/local/share/gitea" "/mnt/repositories" "/usr/local/git"'

	sudo iocage fstab -a "${jlName}" "${jDataPath}/gitea/etc/ /usr/local/etc/gitea/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/gitea/share/ /usr/local/share/gitea/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${gitPath}/ /mnt/repositories/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "$(dirname "${userPth}")/git/ /usr/local/git/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	if [ ! -f "${jDataPath}/gitea/etc/.bash_history" ]; then
		sudo touch "${jDataPath}/gitea/etc/.bash_history"
	fi
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/etc/gitea/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y gitea git ca_root_nss openssl gnupg || echo "Failed to install packages." >&2; exit 1
	sudo iocage pkg "${jlName}" lock -y gitea

### Setup gitea
	sudo iocage exec -f "${jlName}" -- "openssl rand -base64 64 | tee '/usr/local/etc/gitea/INTERNAL_TOKEN'"
	sudo iocage exec -f "${jlName}" -- "openssl rand -base64 32 | tee '/usr/local/etc/gitea/JWT_SECRET'"
###

	# Set permissions
	sudo iocage exec -f "${jlName}" -- "pw groupmod jailmedia -m git"

	# Enable Services
	sudo iocage exec -f "${jlName}" -- 'sysrc gitea_enable="YES"'
	sudo iocage exec -f "${jlName}" -- "service gitea start"

	# Set jail to start at boot.
	sudo iocage stop "${jlName}"
	sudo iocage set boot="1" "${jlName}"

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	}
elif [ "${jlType}" = "search" ]; then
	jlName="search"
	{

	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" allow_mount="1" mount_procfs="1" allow_mount_procfs="1" enforce_statfs="1" allow_set_hostname="1" host_hostname="elasticsearch" priority="1" "${_search[@]}"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/mnt/fscrawler/" "/usr/local/etc/elasticsearch/" "/var/db/elasticsearch" "/usr/local/etc/kibana" "/mnt/Media/" "/mnt/Things/"'

	sudo iocage fstab -a "${jlName}" "${jDataPath}/fscrawler /mnt/fscrawler/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/elasticsearch/etc /usr/local/etc/elasticsearch/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/elasticsearch/db /var/db/elasticsearch/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${jDataPath}/kibana /usr/local/etc/kibana/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "${mediaPth} /mnt/Media/ nullfs ro 0 0"
	sudo iocage fstab -a "${jlName}" "${thingPath} /mnt/Things/ nullfs ro 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	if [ ! -f "${jDataPath}/elasticsearch/etc/.bash_history" ]; then
		sudo touch "${jDataPath}/elasticsearch/etc/.bash_history"
	fi
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/etc/elasticsearch/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y elasticsearch7 kibana7 tesseract-data tesseract || echo "Failed to install packages." >&2; exit 1
	sudo iocage pkg "${jlName}" install -y openjdk17 || echo "Failed to install packages." >&2; exit 1

### Setup fscrawler

###

### Setup elasticsearch
	sudo iocage exec -f "${jlName}" -- '/usr/local/lib/elasticsearch/bin/elasticsearch-plugin install --batch ingest-attachment'
###

	# Set permissions
	sudo iocage exec -f "${jlName}" -- "pw groupmod jailmedia -m elasticsearch"

	# Enable Services
	sudo iocage exec -f "${jlName}" -- 'sysrc elasticsearch_enable="YES"'
	sudo iocage exec -f "${jlName}" -- 'sysrc kibana_enable="YES"'

	sudo iocage exec -f "${jlName}" -- "service elasticsearch start"
	sudo iocage exec -f "${jlName}" -- "service kibana start"

	# Final configuration
	sudo iocage exec -f "${jlName}" -- "crontab /mnt/scripts/search/elasticsearch.crontab"

	# Set jail to start at boot.
	sudo iocage stop "${jlName}"
	sudo iocage set boot="1" "${jlName}"

	# Check IP Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	sudo iocage exec -f "${jlName}" -- "/mnt/scripts/search/search.cmd"
	}
elif [ "${jlType}" = "test" ]; then
	jlName="test"
	{

	# Create jail
	if ! sudo iocage create -T -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" allow_set_hostname="1" "${_test[@]}"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init

	# Install packages
	sudo iocage pkg "${jlName}" install -y phoronix-test-suite-php74 autoconf automake cmake gmake openjdk8 perl5 pkgconf python python3 || echo "Failed to install packages." >&2; exit 1

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage stop "${jlName}"
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	}
elif [ "${jlType}" = "port" ]; then
	jlName="${jlNType}"
	if [ -z "${jlName}" ]; then
		echo "Please specify a jail name." >&2
		exit 1
	fi
	{

	# Create jail
	if ! sudo iocage create -T -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" allow_set_hostname="1" "${_port[@]}"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init

	# Install packages
	portS

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage stop "${jlName}"
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	}
fi


ifconfig -a | grep ether

exit 0
