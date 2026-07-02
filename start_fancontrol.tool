#!/bin/bash

fanControlService="/etc/systemd/system/fancontrol.service"

function writeService() {
	tee > "${fanControlService}" <<EOF
[Unit]
Description=FanControl Daemon
After=multi-user.target

[Service]
Type=simple
ExecStart="${scriptFile}" -dc "${configFile}"

# Equivalent to -R "60"
Restart=always
RestartSec=60

# Equivalent to -Ss "info" -T "FanControl"
SyslogIdentifier=FanControl
SyslogFacility=daemon
SyslogLevel=info

[Install]
WantedBy=multi-user.target

EOF
}



while getopts ":c:f:" OPTION; do
	case "${OPTION}" in
		c)
			configFile="${OPTARG}"
		;;
		f)
			scriptFile="${OPTARG}"
		;;
		?)
			# If an unknown flag is used (or -?):
			echo "${0} {-c configFile} {-f scriptFile}" >&2
			exit 1
		;;
	esac
done

if [ -z "${configFile}" ]; then
	echo "Please specify the config file." >&2
	exit 1
elif [ -z "${scriptFile}" ]; then
	echo "Please specify the script file." >&2
	exit 1
fi

# Must be run as root
if [ ! "$(whoami)" = "root" ]; then
	echo "Must be run as root." >&2
	exit 1
fi

if [ ! -f "${fanControlService}" ]; then
	writeService
fi

if ! systemctl is-active --quiet fancontrol; then
	systemctl daemon-reload
	systemctl enable fancontrol
	systemctl start fancontrol
	systemctl status fancontrol
fi
