#!/bin/bash

#
# Config
#
# shellcheck disable=SC2236
#
# ipmitool raw 0x3a 0x01  ${CPU_FAN1} ${Reserved} ${REAR_FAN1} ${REAR_FAN2} ${FRNT_FAN1} ${FRNT_FAN2} ${FRNT_FAN3} ${Reserved}

# Write out a default config file
function fcConfig {
	tee > "${configFile}" <<"EOF"
# FanControl config file

# Set this to 0 to enable
defaultFile="1"

# Fan settings
autoFanDuty="0" # Value that sets fan to auto based on CPU temp.
minFanDuty="30" # Minimum effective value to set duty level to.
maxFanDuty="100" # Maxim value to set duty level to.
difFanDuty="10" # The difference maintained between intake and exhaust fans


# Temperatures in Celsius
targetHDriveTemp="31" # The temperature that we try to maintain for HDs.
targetSSDriveTemp="36" # The temperature that we try to maintain for SSDs.
maxDriveTemp="39" # Do not let drives get hotter than this.
ambTempVariance="1" # How many degrees the ambient temperature may effect the target

# CPU settings
# Currently unused
# targetCPUTemp="35" # The temperature that we try to maintain.
# maxCPUTemp="55" # Do not let the CPU get hotter than this.
# cpuCheckTempInterval="2" # In seconds.

# HBA Settings
targetHBATemp="41" # The temperature that we try to maintain.
# maxHBATemp="55" # Do not let the HBA get hotter than this.	Currently unused


# PID Controls
Kp="4"	#  Proportional tunable constant
Ki="0.040"	#  Integral tunable constant
Kd="16"	#  Derivative tunable constant

# Time interval to check disk temps in mins
diskCheckTempInterval="2"


# List of HDs
hdName=(
da0
da1
da2
da3
da4
da5
da6
da7
)

# List of SSDs
ssdName=(
ada0
ada1
ada2
ada3
ada4
ada5
)


# Everything below this line is MB specific.
# These examples are for an ASRockRack E3C236D4U.

#
# Currently unused
#
# Fan sensor name prefixes; numbers will be added
# senNamePrefixCPU_FAN="CPU_FAN"
# senNamePrefixFRNT_FAN="FRNT_FAN"
# senNamePrefixREAR_FAN="REAR_FAN"


# Temp sensors
# The names used by ipmi.
# cpuTempSens[0]="CPU1 Temp"		# CPU temp	Currently unused
hbaTempSens[0]="TR1 Temp"		# HBA temp
ambTempSens[0]="MB Temp"		# Ambient temp
ambTempSens[1]="Card Side Temp"	# Ambient temp

# IPMI Fan Commands
#
# The script curently tracks five different types of fan values:
# CPU_FAN is used for fans that directly cools the cpu.
# HBA_FAN is used for fans that directly cools a HBA card.
# FRNT_FAN is used for intake fans.
# REAR_FAN is used for exhaust fans.
# NIL_FAN is used for space holder values that are not fans.
#
# Make sure that you set values here corectly for your board.

# The command to set the desired fan duty levels.
function ipmiWrite {
	if ! ipmitool raw 0x3a 0x01 "${CPU_FAN[0]}" "${NIL_FAN[0]}" "${REAR_FAN[0]}" "${NIL_FAN[1]}" "${FRNT_FAN[0]}" "${FRNT_FAN[1]}" "${HBA_FAN[0]}" "${NIL_FAN[2]}"; then
		return ${?}
	fi
}

# A function to read the current fan duty levels.
# It conversts hex values to decimal and seperates them by type.
function ipmiRead {
	local rawFan
	local rawFanArray

	# Command to get current fan duty levels as a space separated list.
	rawFan="$(ipmitool raw 0x3a 0x02 | sed -e 's:^ *::')"

	read -ra rawFanArray <<< "${rawFan}"

	# Assign named values from the raw array.
	CPU_FAN[0]="$(hexConv "${rawFanArray[0]}")"
	NIL_FAN[0]="$(hexConv "${rawFanArray[1]}")"
	REAR_FAN[0]="$(hexConv "${rawFanArray[2]}")"
	NIL_FAN[1]="$(hexConv "${rawFanArray[3]}")"
	FRNT_FAN[0]="$(hexConv "${rawFanArray[4]}")"
	FRNT_FAN[1]="$(hexConv "${rawFanArray[5]}")"
	FRNT_FAN[2]="$(hexConv "${rawFanArray[6]}")"
	NIL_FAN[2]="$(hexConv "${rawFanArray[7]}")"

	# Remap from MB supplied names.
	HBA_FAN[0]="${FRNT_FAN[2]}"
}

EOF
	exit 0
}

#
# Functions Start Here
#

# ipmi sensor command
function ipmiSens {
	local sensName="${1}"
	ipmitool -c sdr get "${sensName}" | cut -d ',' -f 2
}

# Convert Hex to decimal
function hexConv {
	local hexIn="${1}"
	echo "$((0x${hexIn}))"
}

# Round to nearest whole number
function roundR {
	bc <<< "scale=0;(${1} + 0.5) / 1"
}


# Get average or high CPU temperature.
function cpuTemp {
	local numberCPU="${1}"
	local numberCPUArray
	local coreCPU
	local cpuTempCur
	local cpuTempAv="0"
	local cpuTempMx="0"
	read -ra numberCPUArray <<< "$(seq "0 ${numberCPU}")"

	for coreCPU in "${numberCPUArray[@]}"; do
		cpuTempCur="$(sysctl -n "dev.cpu.${coreCPU}.temperature" | sed -e 's:C::')"

# 		Start adding temps for an average.
		cpuTempAv="$(bc <<< "scale=3;${cpuTempCur} + ${cpuTempAv}")"

# 		Keep track of the highest current temp
		if [ "$(roundR "${cpuTempMx}")" -gt "$(roundR "${cpuTempCur}")" ]; then
			cpuTempMx="${cpuTempMx}"
		else
			cpuTempMx="${cpuTempCur}"
		fi
	done
# 	Divide by number of CPUs for average.
	hdTempAv="$(bc <<< "scale=3;${cpuTempAv} / ${#numberCPUArray[@]}")"

# 	If the hottest CPU matches/exceeds the max temp use that
# 	instead of the average.
	if [ "${cpuTempMx}" -gt "${cpuTempCur}" ]; then
		cpuTempMx="${cpuTempMx}"
	else
		cpuTempMx="${cpuTempCur}"
	fi
}


# Get set point temp
function targetTemp {
	local ambTemIn
	local ambTemOut="0"
	local ambTemCur
	local targetDiskTemp="${1}"

	for ambTemIn in "${ambTempSens[@]}"; do
# 		Get the current ambent temp readings.
		ambTemCur="$(ipmiSens "${ambTemIn}")"
# 		Start adding temps for an average.
		ambTemOut="$(bc <<< "scale=0;${ambTemOut} + ${ambTemCur}")"
	done
# 	Divide by number of sensors for average.
	ambTemOut="$(bc <<< "scale=3;${ambTemOut} / ${#ambTempSens[@]}")"
	ambTemRoun="$(roundR "${ambTemOut}")"
	ambTemComp="$(bc <<< "scale=0;${ambTemOut} / 1")"

# 	Alow the target temp to vary by $ambTempVariance degrees based on
# 	a difference between ambent internal temp and $targetDiskTemp.
	if [ "${ambTemComp}" = "${targetDiskTemp}" ]; then
		echo "${ambTemOut}"
	else
		if [ "${ambTemRoun}" -gt "${targetDiskTemp}" ]; then
			if [ "${ambTemRoun}" -gt "$(bc <<< "scale=0;${targetDiskTemp} + ${ambTempVariance}")" ]; then
				bc <<< "scale=3;${targetDiskTemp} + ${ambTempVariance}"
				return 0
			fi
		elif [ "${targetDiskTemp}" -gt "${ambTemComp}" ]; then
			if [ "$(bc <<< "scale=0;${targetDiskTemp} - ${ambTempVariance}")" -gt "${ambTemComp}" ]; then
				bc <<< "scale=3;${targetDiskTemp} - ${ambTempVariance}"
				return 0
			fi
		fi
		echo "${ambTemOut}"
	fi
}


# Get average or high HD temperature.
function hdTemp {
	local hdNum
	local hdTempCur
	local hdTempAv="0"
	local hdTempMx="0"

	for hdNum in "${hdName[@]}"; do
# 		Get the temp for the current drive.
# 		194 is the standard SMART id for temp so we look for it at the
# 		begining of the line.
		hdTempCur="$(smartctl -a "/dev/${hdNum}" | grep "^194" | sed -E 's:[[:space:]]+: :g' | cut -d ' ' -f 10)"
# 		Start adding temps for an average.
		hdTempAv="$(( hdTempAv + hdTempCur ))"

# 		Keep track of the highest current temp
		if [ "${hdTempMx}" -gt "${hdTempCur}" ]; then
			hdTempMx="${hdTempMx}"
		else
			hdTempMx="${hdTempCur}"
		fi
	done
# 	Divide by number of drives for average.
	hdTempAv="$(bc <<< "scale=3;${hdTempAv} / ${#hdName[@]}")"

# 	If the hottest drive matches/exceeds the max temp use that instead
# 	of the average.
	if [ "${hdTempMx}" -ge "${maxDriveTemp}" ]; then
		echo "${hdTempMx}"
	else
		echo "${hdTempAv}"
	fi
}


# Get average or high ssd temperature.
function ssdTemp {
	local ssdNum
	local ssdTempCur
	local ssdTempAv="0"
	local ssdTempMx="0"

	for ssdNum in "${ssdName[@]}"; do
# 		Get the temp for the current drive.
# 		194 is the standard SMART id for temp so we look for it at the
# 		begining of the line.
		ssdTempCur="$(smartctl -a "/dev/${ssdNum}" | grep "^194" | sed -E 's:[[:space:]]+: :g' | cut -d ' ' -f 10)"
# 		Start adding temps for an average.
		ssdTempAv="$(( ssdTempAv + ssdTempCur ))"

# 		Keep track of the highest current temp
		if [ "${ssdTempMx}" -gt "${ssdTempCur}" ]; then
			ssdTempMx="${ssdTempMx}"
		else
			ssdTempMx="${ssdTempCur}"
		fi
	done
# 	Divide by number of drives for average.
	ssdTempAv="$(bc <<< "scale=3;${ssdTempAv} / ${#ssdName[@]}")"

# 	If the hottest drive matches/exceeds the max temp use that instead
# 	of the average.
	if [ "${ssdTempMx}" -ge "${maxDriveTemp}" ]; then
		echo "${ssdTempMx}"
	else
		echo "${ssdTempAv}"
	fi
}


# Print temp info
function infoTemps {
	local hdNum
	local hdTempCur
	local hdTempAv="0"
	local ssdNum
	local ssdTempCur
	local ssdTempAv="0"

	if [ ! "${#ssdName[@]}" = "0" ]; then
		echo -e "Current SSD setpoint temp:\t$(targetTemp "${targetSSDriveTemp}")°C"
	fi
	echo -e "Current HD setpoint temp:\t$(targetTemp "${targetHDriveTemp}")°C\n"
	if [ ! -z "${hbaTempSens[0]}" ]; then
		echo -e "HBA Temp:\t$(ipmiSens "${hbaTempSens[0]}")°C"
	fi

	for hdNum in "${hdName[@]}"; do
# 		Get the temp for the current drive.
# 		194 is the standard SMART id for temp so we look for it at the
# 		begining of the line.
		hdTempCur="$(smartctl -a "/dev/${hdNum}" | grep "^194" | sed -E 's:[[:space:]]+: :g' | cut -d ' ' -f 10)"
# 		Start adding temps for an average.
		hdTempAv="$(( hdTempAv + hdTempCur ))"

# 		Echo HD's current temp
		echo -e "${hdNum} Temp:\t${hdTempCur}°C"
	done
# 	Divide by number of drives for average.
	hdTempAv="$(bc <<< "scale=3;${hdTempAv} / ${#hdName[@]}")"


	if [ ! "${#ssdName[@]}" = "0" ]; then
		for ssdNum in "${ssdName[@]}"; do
# 			Get the temp for the current drive.
# 			194 is the standard SMART id for temp so we look for it at
# 			the begining of the line.
			ssdTempCur="$(smartctl -a "/dev/${ssdNum}" | grep "^194" | sed -E 's:[[:space:]]+: :g' | cut -d ' ' -f 10)"
# 			Start adding temps for an average.
			ssdTempAv="$(( ssdTempAv + ssdTempCur ))"

# 			Echo HD's current temp
			echo -e "${ssdNum} Temp:\t${ssdTempCur}°C"
		done
# 		Divide by number of drives for average.
		ssdTempAv="$(bc <<< "scale=3;${ssdTempAv} / ${#ssdName[@]}")"
	fi


	echo -e "\nAverage HD Temp: ${hdTempAv}°C"
	if [ ! "${#ssdName[@]}" = "0" ]; then
		echo -e "Average SSD Temp: ${ssdTempAv}°C"
	fi
}


# Print fan info
# shellcheck disable=SC2086
function infoFans {
	ipmiRead
	local cpuFan
	local intakeFan
	local outputFan
	local countd

	for cpuFan in "${!CPU_FAN[@]}"; do
		countd=$((cpuFan+1))
		if [ "${CPU_FAN[${cpuFan}]}" = "0" ]; then
			CPU_FAN[${cpuFan}]="auto"
		else
			CPU_FAN[${cpuFan}]="${CPU_FAN[${cpuFan}]}%"
		fi
		echo -e "CPU_FAN${countd}\t${CPU_FAN[${cpuFan}]}\t$(ipmiSens "CPU_FAN${countd}") rpm"
	done

	for intakeFan in "${!FRNT_FAN[@]}"; do
		countd=$((intakeFan+1))
		if [ "${FRNT_FAN[${intakeFan}]}" = "0" ]; then
			FRNT_FAN[${intakeFan}]="auto"
		else
			FRNT_FAN[${intakeFan}]="${FRNT_FAN[${intakeFan}]}%"
		fi
		echo -e "FRNT_FAN${countd}\t${FRNT_FAN[${intakeFan}]}\t$(ipmiSens "FRNT_FAN${countd}") rpm"
	done

	for outputFan in "${!REAR_FAN[@]}"; do
		countd=$((outputFan+1))
		if [ "${REAR_FAN[${outputFan}]}" = "0" ]; then
			REAR_FAN[${outputFan}]="auto"
		else
			REAR_FAN[${outputFan}]="${REAR_FAN[${outputFan}]}%"
		fi
		echo -e "REAR_FAN${countd}\t${REAR_FAN[${outputFan}]}\t$(ipmiSens "REAR_FAN${countd}") rpm"
	done
}


# Set fan duty levels
function setFanDuty {
	local cpuFan
	local hbaFan
	local intakeFan
	local outputFan
	local cpuFanSet
	local hbaFanSet
	local intakeFanSet
	local outputFanSet
	cpuFanSet="$(roundR "${1}")"
	hbaFanSet="$(roundR "${2}")"
	intakeFanSet="$(roundR "${3}")"
	outputFanSet="$(bc <<< "scale=0;${intakeFanSet} - ${difFanDuty}")"

	for cpuFan in "${!CPU_FAN[@]}"; do
		CPU_FAN[${cpuFan}]="${cpuFanSet}"
	done

	for intakeFan in "${!FRNT_FAN[@]}"; do
		FRNT_FAN[${intakeFan}]="${intakeFanSet}"
	done

	for outputFan in "${!REAR_FAN[@]}"; do
		REAR_FAN[${outputFan}]="${outputFanSet}"
	done

	for hbaFan in "${!HBA_FAN[@]}"; do
		HBA_FAN[${hbaFan}]="${hbaFanSet}"
	done
}


# The proportional calculation
function proportionalK {
	local errorK="${1}"
	local controlOuput

	controlOuput="$(bc <<< "scale=3;${errorK} * ${Kp}")"
	echo "${controlOuput}"
}

# The integral calculation
function integralK {
	local errorK="${1}"
	local prevIntegralVal="${2}"
	local controlStep
	local controlOuput

	controlStep="$(bc <<< "scale=3;(${errorK} * ${diskCheckTempInterval}) + ${prevIntegralVal}")"
	controlOuput="$(bc <<< "scale=3;(${Ki} * ${controlStep}) / 1")"
	echo "${controlOuput}"
}

# The derivative calculation
function derivativeK {
	local errorK="${1}"
	local prevErrorK="${2}"
	local controlOuput

	controlOuput="$(bc <<< "scale=3;${Kd} * ((${errorK} - ${prevErrorK}) / ${diskCheckTempInterval})")"
	echo "${controlOuput}"
}


#
# Main Script Starts Here
#

while getopts ":c:tfd" OPTION; do
	case "${OPTION}" in
		c)
			configFile="${OPTARG}"
		;;
		t)
			scAction="temps"
		;;
		f)
			scAction="fans"
		;;
		d)
			scAction="daemon"
		;;
		?)
			# If an unknown flag is used (or -?):
			echo "${0} {-c configFile} {-t|-f|-d}" >&2
			exit 1
		;;
	esac
done

if [ -z "${configFile}" ]; then
	echo "Please specify a config file location." >&2
	exit 1
elif [ ! -f "${configFile}" ]; then
	fcConfig
fi

# Source external config file
# shellcheck source=/dev/null
. "${configFile}"

# Check if needed software is installed.
PATH="${PATH}:/usr/local/sbin:/usr/local/bin"
commands=(
grep
sed
cut
sleep
bc
smartctl
ipmitool
sysctl
)
for command in "${commands[@]}"; do
	if ! type "${command}" &> /dev/null; then
		echo "${command} is missing, please install" >&2
		exit 100
	fi
done


# Do not run if the config file has not been edited.
if [ ! "${defaultFile}" = "0" ]; then
	echo "Please edit the config file for your setup" >&2
	exit 1
fi


#
# Alternate modes
#

if [ -z "${scAction}" ]; then
	echo "Please specify an action." >&2
	exit 1
elif [ "${scAction}" = "temps" ]; then
	infoTemps
	exit 0
elif [ "${scAction}" = "fans" ]; then
	infoFans
	exit 0
elif [ "${scAction}" = "daemon" ]; then
	: # nothing currently needed here
fi


# Must be run as root
if [ ! "$(whoami)" = "root" ]; then
	echo "Must be run as root." >&2
	exit 1
fi


# Set fans to auto on exit
function scExit {
	setFanDuty "${autoFanDuty}" "${autoFanDuty}" "${autoFanDuty}"
	ipmiWrite
	exit 0
}

trap 'scExit' EXIT


#
# Setup for main loop.
#

# Get current duty levels.
ipmiRead

# Start fans at max
setFanDuty "100" "100" "100"

if ! ipmiWrite; then
	exit 1
fi


# Get number of CPUs
numberCPU="$(bc <<< "$(sysctl -n hw.ncpu) - 1")"

# Initialize previous run vars.
: "${prevHDErrorK:="0"}"
: "${prevHDProportionalVal:="0"}"
: "${prevHDIntegralVal:="0"}"
: "${prevHDDerivativeVal:="0"}"
: "${prevHDControlOutput:="100"}"

: "${prevSSDErrorK:="0"}"
: "${prevSSDProportionalVal:="0"}"
: "${prevSSDIntegralVal:="0"}"
: "${prevSSDDerivativeVal:="0"}"
: "${prevSSDControlOutput:="100"}"

: "${prevHBAErrorK:="0"}"
: "${prevHBAProportionalVal:="0"}"
: "${prevHBAIntegralVal:="0"}"
: "${prevHBADerivativeVal:="0"}"
: "${prevHBAControlOutput:="100"}"


#
# Main Loop.
#


while true; do
# 	Calculate HD fan settings
#
	HDsetPoint="$(targetTemp "${targetHDriveTemp}")"
	HDprocessVar="$(hdTemp)"

# 	Get the error.
	HDerrorK="$(bc <<< "scale=3;${HDprocessVar} - ${HDsetPoint}")"

# 	Compute an unqualified control output (P+I+D).
	HDproportionalVal="$(proportionalK "${HDerrorK}")"
	HDintegralVal="$(integralK "${HDerrorK}" "${prevHDIntegralVal}")"
	HDderivativeVal="$(derivativeK "${HDerrorK}" "${prevHDErrorK}")"

	unQualHDControlOutput="$(bc <<< "scale=3;${prevHDControlOutput} + ${HDproportionalVal} + ${HDintegralVal} + ${HDderivativeVal}")"

# 	Qualify the output to ensure we are inside the constraints.
	qualHDMinFanDuty="$(bc <<< "${minFanDuty} + ${difFanDuty}")"
	qualHDMinFanDuty="$(roundR "${qualHDMinFanDuty}")"
	qualHDControlOutput="$(roundR "${unQualHDControlOutput}")"

	if [ "${qualHDControlOutput}" -lt "${qualHDMinFanDuty}" ]; then
		qualHDControlOutput="${qualHDMinFanDuty}"
	elif [ "${qualHDControlOutput}" -gt "${maxFanDuty}" ]; then
		qualHDControlOutput="${maxFanDuty}"
	fi


	if [ ! "${#ssdName[@]}" = "0" ]; then
# 		Calculate SSD fan settings
#
		SSDsetPoint="$(targetTemp "${targetSSDriveTemp}")"
		SSDprocessVar="$(ssdTemp)"

# 		Get the error.
		SSDerrorK="$(bc <<< "scale=3;${SSDprocessVar} - ${SSDsetPoint}")"

# 		Compute an unqualified control output (P+I+D).
		SSDproportionalVal="$(proportionalK "${SSDerrorK}")"
		SSDintegralVal="$(integralK "${SSDerrorK}" "${prevSSDIntegralVal}")"
		SSDderivativeVal="$(derivativeK "${SSDerrorK}" "${prevSSDErrorK}")"

		unQualSSDControlOutput="$(bc <<< "scale=3;${prevSSDControlOutput} + ${SSDproportionalVal} + ${SSDintegralVal} + ${SSDderivativeVal}")"

# 		Qualify the output to ensure we are inside the constraints.
		qualSSDMinFanDuty="$(bc <<< "${minFanDuty} + ${difFanDuty}")"
		qualSSDMinFanDuty="$(roundR "${qualSSDMinFanDuty}")"
		qualSSDControlOutput="$(roundR "${unQualSSDControlOutput}")"

		if [ "${qualSSDControlOutput}" -lt "${qualSSDMinFanDuty}" ]; then
			qualSSDControlOutput="${qualSSDMinFanDuty}"
		elif [ "${qualSSDControlOutput}" -gt "${maxFanDuty}" ]; then
			qualSSDControlOutput="${maxFanDuty}"
		fi
	fi


# 	Calculate HBA fan settings
#
	HBAsetPoint="${targetHBATemp}"
	HBAprocessVar="$(ipmiSens "${hbaTempSens[0]}")"

# 	Get the error.
	HBAerrorK="$(bc <<< "scale=3;${HBAprocessVar} - ${HBAsetPoint}")"

# 	Compute an unqualified control output (P+I+D).
	HBAproportionalVal="$(proportionalK "${HBAerrorK}")"
	HBAintegralVal="$(integralK "${HBAerrorK}" "${prevHBAIntegralVal}")"
	HBAderivativeVal="$(derivativeK "${HBAerrorK}" "${prevHBAErrorK}")"

	unQualHBAControlOutput="$(bc <<< "scale=3;${prevHBAControlOutput} + ${HBAproportionalVal} + ${HBAintegralVal} + ${HBAderivativeVal}")"

# 	Qualify the output to ensure we are inside the constraints.
	qualHBAMinFanDuty="$(roundR "${minFanDuty}")"
	qualHBAControlOutput="$(roundR "${unQualHBAControlOutput}")"

	if [ "${qualHBAControlOutput}" -lt "${qualHBAMinFanDuty}" ]; then
		qualHBAControlOutput="${qualHBAMinFanDuty}"
	elif [ "${qualHBAControlOutput}" -gt "${maxFanDuty}" ]; then
		qualHBAControlOutput="${maxFanDuty}"
	fi


# 	We only need to set the fans if something changes.
	if [ ! "${prevHDControlOutput}" = "${qualHDControlOutput}" ] || [ ! "${prevHBAControlOutput}" = "${qualHBAControlOutput}" ] || [ ! "${prevSSDControlOutput}" = "${qualSSDControlOutput}" ]; then

		if [ "${qualSSDControlOutput}" -gt "${qualHDControlOutput}" ]; then
			qualDiskControlOutput="${qualSSDControlOutput}"
		else
			qualDiskControlOutput="${qualHDControlOutput}"
		fi

# 		Set the duty levels for each fan type.
		setFanDuty "${autoFanDuty}" "${qualHBAControlOutput}" "${qualDiskControlOutput}"


# 		Write out the new duty levels to ipmi.
# 		shellcheck disable=SC2086
		if ! ipmiWrite; then
			exit 1
		fi
	fi

# 	Set vars for next run
	prevHDErrorK="${HDerrorK}"
	prevHDProportionalVal="${HDproportionalVal}"
	prevHDIntegralVal="${HDintegralVal}"
	prevHDDerivativeVal="${HDderivativeVal}"
	prevHDControlOutput="${qualHDControlOutput}"

	prevSSDErrorK="${SSDerrorK}"
	prevSSDProportionalVal="${SSDproportionalVal}"
	prevSSDIntegralVal="${SSDintegralVal}"
	prevSSDDerivativeVal="${SSDderivativeVal}"
	prevSSDControlOutput="${qualSSDControlOutput}"

	prevHBAErrorK="${HBAerrorK}"
	prevHBAProportionalVal="${HBAproportionalVal}"
	prevHBAIntegralVal="${HBAintegralVal}"
	prevHBADerivativeVal="${HBAderivativeVal}"
	prevHBAControlOutput="${qualHBAControlOutput}"


	sleep "$(( 60 * diskCheckTempInterval ))"
done
