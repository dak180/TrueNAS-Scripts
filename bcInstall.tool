#!/bin/bash
#
# Builds a static version of GNU bc inside a TrueNAS 26 container
# under the /opt prefix, with built-in environmental safety checks.
#

set -e

CONTAINER="${1}"

if [ -z "${CONTAINER}" ]; then
	echo "Usage: ${0} <container-name>" >&2
	exit 1
fi

echo "Checking container environment: ${CONTAINER}..." >&2

# Feed the build instructions directly to the container's shell via heredoc
# using standard POSIX 'sh' to ensure maximum compatibility.
truenas-nsexec "${CONTAINER}" sh << 'EOF'
set -e

# Guardrail for Assumption 1: Verify the package manager is apt-get (Debian/Ubuntu)
if ! command -v apt-get >/dev/null 2>&1; then
	echo "Error: This script requires a Debian or Ubuntu-based container (apt-get not found)." >&2
	exit 1
fi

# Pre-build check: If bc exists in /opt, verify if it is statically linked
if [ -x "/opt/bin/bc" ]; then
	if ldd /opt/bin/bc 2>&1 | grep -q "not a dynamic executable"; then
		echo "Static 'bc' already exists at /opt/bin/bc. Skipping build." >&2
		exit 0
	fi
fi

# Install build dependencies
apt-get update >&2
apt-get install -y build-essential curl grep sed coreutils >&2

# Scrape the GNU FTP site to dynamically find the newest tarball
LATEST_TAR="$(curl -sL https://ftp.gnu.org/gnu/bc/ | grep -o 'bc-[0-9\.]*\.tar\.gz' | sort -V | tail -n 1)"

if [ -z "${LATEST_TAR}" ]; then
	echo "Failed to determine latest bc version." >&2
	exit 1
fi

echo "Latest version found: ${LATEST_TAR}" >&2

cd /tmp
curl -fLO "https://ftp.gnu.org/gnu/bc/${LATEST_TAR}" >&2
tar -xzf "${LATEST_TAR}" >&2

# Strip the .tar.gz extension to get the extracted directory name
DIR_NAME="$(echo "${LATEST_TAR}" | sed -e 's:\.tar\.gz::')"
cd "${DIR_NAME}"

# Configure using the /opt prefix, omit readline, and force static compilation
./configure --prefix=/opt --without-readline LDFLAGS="-static" >&2
make -j"$(nproc)" >&2
make install >&2
EOF

# Determine the host path by querying ZFS for the container's mountpoint
CONTAINER_MNT="$(zfs list -H -o mountpoint | grep "/\.truenas_containers/containers/${CONTAINER}" | head -n 1)"
HOST_BIN_PATH="${CONTAINER_MNT}/rootfs/opt/bin/bc"

# Guardrail for Assumption 6: Verify the host can actually see the binary across the ZFS mount
if [ -z "${CONTAINER_MNT}" ] || [ ! -x "${HOST_BIN_PATH}" ]; then
	echo "Error: The binary compiled successfully, but the host cannot access it." >&2
	echo "Ensure the container dataset is actively mounted on the host pool." >&2
	exit 1
fi

echo "Success! The static binary is located at:" >&2

# Only the final path is sent to standard output
echo "${HOST_BIN_PATH}"
