#!/bin/bash
# shellcheck disable=SC1004,SC2236




function tler_activation() {
	local tlerStatus

	tlerStatus="$(smartctl -jl scterc "/dev/${drive}" | jq -Mre '.ata_sct_erc | values')"


	if [ ! -z "${tlerStatus}" ]; then
		if [ ! "$(echo "${tlerStatus}" | jq -Mre '.read.enabled | values')" = "true" ] || [ ! "$(echo "${tlerStatus}" | jq -Mre '.write.enabled | values')" = "true" ]; then
			smartctl -l scterc,70,70 "/dev/${drive}"
		fi
	fi

	echo "${drive}:"
	smartctl -l scterc "/dev/${drive}" | tail -n +4
	echo "+---------------+"
}

function drive_list() {
	# Reorders the drives in ascending order
	# FixMe: smart support flag is not yet implemented in smartctl json output.
	readarray -t "drives" <<< "$(for drive in $(sysctl -n kern.disks | sed -e 's:nvd:nvme:g'); do
		if smartctl --json=u -i "/dev/${drive}" | grep "SMART support is:" | grep -q "Enabled"; then
			printf "%s " "${drive}"
		elif echo "${drive}" | grep -q "nvme"; then
			printf "%s " "${drive}"
		fi
	done | tr ' ' '\n' | sort -V | sed '/^nvme/!H;//p;$!d;g;s:\n::')"
}




# Check if needed software is installed.
PATH="${PATH}:/usr/local/sbin:/usr/local/bin"
commands=(
sysctl
sed
grep
tr
smartctl
jq
sort
tail
)
for command in "${commands[@]}"; do
	if ! type "${command}" &> /dev/null; then
		echo "${command} is missing, please install" >&2
		exit 100
	fi
done




drive_list

for drive in "${drives[@]}"; do
	tler_activation
done
