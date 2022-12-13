#!/bin/bash

# Config
resolver60="search local.dak180.com local;nameserver 192.168.60.1"
resolver04="search local.dak180.com local;nameserver 192.168.4.1"
ioRelease="13.1-RELEASE" # LATEST

function portS {
	sudo iocage pkg "${jlName}" install -y svnup
	sudo iocage exec -f "${jlName}" -- 'cat /usr/local/etc/svnup.conf.sample | sed -e "s:#host=svn\.:host=svn\.:" > /usr/local/etc/svnup.conf'
	sudo iocage exec -f "${jlName}" -- "svnup ports -v 0"
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
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/mnt/scripts/" "/mnt/users/dak180/"'
	sudo iocage fstab -a "${jlName}" "/mnt/jails/scripts /mnt/scripts/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/users/dak180 /mnt/users/dak180 nullfs rw 0 0"
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


# Jail Creation
if [ "${1}" = "plex" ]; then
	jlName="plex"


	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" vnet="1" bpf="1" dhcp="1" allow_mount="1" allow_mount_devfs="1" allow_raw_sockets="1" allow_set_hostname="1" devfs_ruleset="109" enforce_statfs="1" interfaces="vnet0:bridge0" priority="1" vnet0_mac="B213DD984A80 B213DD984A7F" vnet_default_interface="vlan10"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/usr/local/plexdata/" "/mnt/dbBackup/" "/var/db/tautulli/"'

	sudo iocage fstab -a "${jlName}" "/mnt/data/Media /media/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/plex /usr/local/plexdata/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/data/Backups/plex /mnt/dbBackup/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/Tautulli /var/db/tautulli/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/plexdata/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y multimedia/plexmediaserver-plexpass tautulli ffmpeg youtube_dl AtomicParsley multimedia/libva-intel-driver multimedia/libva-intel-media-driver

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
	sudo iocage set devfs_ruleset="109" "${jlName}"

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
elif [ "${1}" = "trans" ] || [ "${1}" = "transmission" ]; then
	jlName="transmission"


	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" vnet="1" bpf="1" dhcp="1" allow_raw_sockets="1" allow_set_hostname="1" allow_tun="1" interfaces="vnet0:bridge60" priority="3" resolver="${resolver60}" vnet0_mac="4a3a78771683 4a3a78771682" vnet_default_interface="vlan60"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/mnt/incoming/" "/mnt/torrents/" "/mnt/transmission/" "/var/db/transmission/" "/usr/local/etc/openvpn/"'

	sudo iocage fstab -a "${jlName}" "/mnt/data/Media /mnt/incoming/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/data/torrents /mnt/torrents/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/data/Things/Torrents /mnt/transmission/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/transmission /var/db/transmission/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/openvpn /usr/local/etc/openvpn/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/var/db/transmission/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y openvpn transmission-daemon transmission-web transmission-cli transmission-utils base64 jq

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
	sudo iocage exec -f "${jlName}" -- 'sysrc openvpn_configfile="/usr/local/etc/openvpn/openvpn.conf"'

	## Network config
	sudo iocage exec -f "${jlName}" -- 'sysrc firewall_enable="YES"'
	sudo iocage exec -f "${jlName}" -- 'sysrc firewall_script="/mnt/scripts/trans/ipfw.rules"'
	## Static route for local inter-vlan connections
	sudo iocage exec -f "${jlName}" -- 'sysrc static_routes="net1"'
	sudo iocage exec -f "${jlName}" -- 'sysrc net1="-net 192.168.0.0/16 192.168.60.1"'

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
elif [ "${1}" = "unifi" ]; then
	jlName="unifi"


	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" vnet="1" bpf="1" dhcp="1" allow_raw_sockets="1" allow_set_hostname="1" interfaces="igb0:bridge4" priority="1" resolver="${resolver04}" vnet0_mac="02ff608700b4 02ff608700b5" vnet_default_interface="igb0"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/usr/local/share/java/unifi/"'

	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/unifi /usr/local/share/java/unifi/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/share/java/unifi/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y unifi7

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
elif [ "${1}" = "netdata" ]; then
	jlName="netdata"


	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" nat="1" nat_forwards="tcp(19999:19999)" allow_raw_sockets="1" allow_set_hostname="1" mount_devfs="1" mount_fdescfs="1" mount_procfs="1" securelevel="-1" allow_sysvipc="1" sysvmsg="new" sysvsem="new" sysvshm="new" allow_mount_devfs="1" allow_mount_procfs="1" interfaces="vnet0:bridge0" priority="99" vnet0_mac="02ff602be694 02ff602be695"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/usr/local/etc/netdata/" "/var/cache/netdata/" "/var/db/netdata/" "/mnt/smartd/"'

	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/netdata/config /usr/local/etc/netdata/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/netdata/cache /var/cache/netdata/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/netdata/db /var/db/netdata/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/netdata/smartd /mnt/smartd/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/etc/netdata/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y netdata

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
elif [ "${1}" = "pvr" ]; then
	jlName="pvr"


	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" vnet="1" bpf="1" dhcp="1" allow_raw_sockets="1" allow_mlock="1" allow_set_hostname="1" depends="plex transmission" interfaces="vnet0:bridge60" resolver="${resolver60}" vnet0_mac="02ff60df8049 02ff60df804a" vnet_default_interface="vlan60"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/mnt/torrents/" "/mnt/transmission/" "/usr/local/sonarr/" "/usr/local/radarr/" "/usr/local/jackett/" "/usr/local/bazarr/"'

	sudo iocage fstab -a "${jlName}" "/mnt/data/Media /media/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/data/torrents /mnt/torrents/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/data/Things/Torrents /mnt/transmission/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/sonarr /usr/local/sonarr/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/radarr /usr/local/radarr/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/jackett /usr/local/jackett/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/bazarr /usr/local/bazarr/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/sonarr/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y sonarr jackett radarr bazarr mediainfo ca_root_nss
	sudo iocage pkg "${jlName}" lock -y jackett

### mono fixes (see: https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=258709)
	sudo iocage pkg "${jlName}" install -y /mnt/scripts/pvr/mono6.8-6.8.0.123.txz
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
elif [ "${1}" = "znc" ]; then
	jlName="znc"


	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" vnet="1" bpf="1" dhcp="1" allow_raw_sockets="1" allow_set_hostname="1" interfaces="vnet0:bridge0" priority="2" vnet0_mac="02ff609935af 02ff609935b0" vnet_default_interface="vlan10"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/usr/local/etc/znc/"'

	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/znc/ /usr/local/etc/znc/ nullfs rw 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
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
elif [ "${1}" = "search" ]; then
	jlName="search"


	# Create jail
	if ! sudo iocage create -b -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" vnet="1" bpf="1" dhcp="1" allow_raw_sockets="1" allow_mount="1" allow_mount_procfs="1" enforce_statfs="1" allow_set_hostname="1" host_hostname="elasticsearch" priority="1" interfaces="vnet0:bridge60" resolver="${resolver60}" vnet0_mac="02ff60ae0444 02ff60ae0445" vnet_default_interface="vlan60"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts
	sudo iocage exec -f "${jlName}" -- 'mkdir -pv "/mnt/fscrawler/" "/usr/local/etc/elasticsearch/" "/var/db/elasticsearch" "/usr/local/etc/kibana" "/mnt/Media/" "/mnt/Things/"'

	sudo iocage fstab -a "${jlName}" "proc   /proc    procfs   rw  0  0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/fscrawler /mnt/fscrawler/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/elasticsearch/etc /usr/local/etc/elasticsearch/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/elasticsearch/db /var/db/elasticsearch/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/jails/Data/kibana /usr/local/etc/kibana/ nullfs rw 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/data/Media /mnt/Media/ nullfs ro 0 0"
	sudo iocage fstab -a "${jlName}" "/mnt/data/Things /mnt/Things/ nullfs ro 0 0"

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init
	sudo iocage exec -f "${jlName}" -- 'ln -sf "/usr/local/etc/elasticsearch/.bash_history" "/root/.bash_history"'

	# Install packages
	sudo iocage pkg "${jlName}" install -y elasticsearch7 kibana7 tesseract-data tesseract
	sudo iocage pkg "${jlName}" install -y openjdk15

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
	sudo iocage exec -f "${jlName}" -- "crontab -u elasticsearch /mnt/scripts/search/elasticsearch.crontab"

	# Set jail to start at boot.
	sudo iocage stop "${jlName}"
	sudo iocage set boot="1" "${jlName}"

	# Check IP Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
	sudo iocage exec -f "${jlName}" -- "/mnt/scripts/search/search.cmd"
elif [ "${1}" = "test" ]; then
	jlName="test"


	# Create jail
	if ! sudo iocage create -T -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" vnet="1" nat="1" allow_set_hostname="1" interfaces="vnet0:bridge0"; then
		exit 1
	fi

	# Set Mounts
	comn_mnt_pnts

	# Generic Configuration
	pkg_repo
	usrpths
	jl_init

	# Install packages
	sudo iocage pkg "${jlName}" install -y phoronix-test-suite-php74 autoconf automake cmake gmake openjdk8 perl5 pkgconf python python3

	# Check MAC Address
	sudo iocage get vnet0_mac "${jlName}"

	# Create initial snapshot
	sudo iocage stop "${jlName}"
	sudo iocage snapshot "${jlName}" -n InitialConfiguration
	sudo iocage start "${jlName}"
elif [ "${1}" = "port" ]; then
	jlName="${2}"
	if [ -z "${jlName}" ]; then
		exit 1
	fi


	# Create jail
	if ! sudo iocage create -T -n "${jlName}" -p "/tmp/pkg.json" -r "${ioRelease}" vnet="1" bpf="1" dhcp="1" allow_set_hostname="1" interfaces="vnet0:bridge0" vnet_default_interface="vlan10"; then
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
fi


ifconfig -a | grep ether

exit 0
