#!/bin/bash
# shellcheck disable=SC1004,SC2236,SC2001

# LLM generated translation of https://gist.github.com/dak180/cd44e9957e1c4180e7eb6eb000716ee2

STORCLI_CMD="$(command -v storcli || command -v storcli64)"

if [ -z "${STORCLI_CMD}" ]; then
	echo '{"error": "storcli utility not found on this system."}' >&2
	exit 1
fi

function collectTelemetry () {
	local currentCtrl
	local ctrlName
	local line
	local tempVal
	local currentEnclosure
	local cleanEnclosure
	local encName
	local inTable
	local cleanLine
	local sensorId
	local tempC
	local unit

	currentCtrl="unknown"
	ctrlName="unknown"
	while IFS= read -r line; do
		if grep -q "Controller =" <<< "${line}"; then
			currentCtrl="$(sed -e 's|.*= ||' <<< "${line}")"
			ctrlName="unknown"
		elif grep -q "Model Name =" <<< "${line}"; then
			ctrlName="$(sed -e 's|.*= ||' <<< "${line}")"
		elif grep -q "ROC temperature" <<< "${line}"; then
			tempVal="$(sed -e 's|.* ||' <<< "${line}")"

			# Stream format: HBA <device_id> <temp> <name_string...>
			echo "HBA c${currentCtrl} ${tempVal} ${ctrlName}"
		fi
	done < <("${STORCLI_CMD}" /call show all nolog 2>/dev/null)

	currentEnclosure="unknown"
	encName="unknown"
	inTable="false"
	while IFS= read -r line; do
		line="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "${line}")"

		if grep -q "Enclosure /" <<< "${line}"; then
			currentEnclosure="$(cut -d' ' -f2 <<< "${line}")"

			# Strip the leading slash and replace inner slashes with underscores (e.g., /c0/e252 -> c0_e252)
			cleanEnclosure="$(sed -e 's|^/||' -e 's|/|_|g' <<< "${currentEnclosure}")"

			encName="unknown"
			inTable="false"
		elif grep -E -q "^(Product Id|Product ID)[[:space:]]*=" <<< "${line}"; then
			encName="$(sed -e 's|.*= ||' <<< "${line}")"
		elif grep -q "Enclosure Temperature Sensors" <<< "${line}"; then
			inTable="true"
		elif [ "${inTable}" = "true" ]; then
			if [ -z "${line}" ]; then
				inTable="false"
			elif grep -E -q "^[0-9]" <<< "${line}"; then
				cleanLine="$(tr -s ' ' <<< "${line}")"
				sensorId="$(cut -d' ' -f1 <<< "${cleanLine}")"
				tempC="$(cut -d' ' -f2 <<< "${cleanLine}")"
				unit="$(cut -d' ' -f3 <<< "${cleanLine}")"

				if [ "${unit}" = "C" ]; then
					# Stream format: EXP <device_id> <temp> <name_string...>
					echo "EXP ${cleanEnclosure}_sensor${sensorId} ${tempC} ${encName}"
				fi
			fi
		fi
	done < <("${STORCLI_CMD}" /call /eall show all nolog 2>/dev/null)
}

collectTelemetry | jq -n -R '
	[inputs | split(" ")] |
	[
		.[] |
		if .[0] == "HBA" then
			{
				device_id: .[1],
				type: "hba",
				model: (.[3:] | join(" ")),
				temperature_c: (.[2] | tonumber)
			}
		elif .[0] == "EXP" then
			{
				device_id: .[1],
				type: "expander",
				model: (.[3:] | join(" ")),
				temperature_c: (.[2] | tonumber)
			}
		else
			empty
		end
	]
'
