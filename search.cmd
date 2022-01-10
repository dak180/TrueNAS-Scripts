#!/usr/local/bin/bash
# shellcheck disable=SC2010


# Config
export JAVA_HOME="/usr/local/openjdk15"
fscrawlerPth="/mnt/fscrawler/fscrawler-es7-2.7-SNAPSHOT/"
fscrawlerJobPth="/mnt/fscrawler/settings"

readarray -t "fsJobs" <<< "$(ls "${fscrawlerJobPth}" | grep -v "_default" | sed -e 's:/::')"


cd "${fscrawlerPth}" || exit 1

for fsJob in "${fsJobs[@]}"; do
	if [ ! -e "/var/run/fscrawler-${fsJob}.pid" ]; then
		/usr/sbin/daemon -t "fscrawler-${fsJob}" -P "/var/run/daemon-fscrawler-${fsJob}.pid" -p "/var/run/fscrawler-${fsJob}.pid" -S -u "elasticsearch" bin/fscrawler --config_dir "${fscrawlerJobPth}" "${fsJob}"
	fi
done


exit 0

