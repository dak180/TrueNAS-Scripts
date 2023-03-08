# A Collection of Scripts For TrueNAS #

## FanControl.tool ##

`FanControl.tool {-c configFile} {-t|-f|-d}`

This tool is meant to control case fans via ipmi to maintain target disk and HBA temperatures using a PID control loop on TrueNAS Core. It also allows you to get a readout of current temps and fan speeds.

The first run of the script will write out a default config file to the specified location; this file will need to be edited to conform to your system.

Most of the first sections of the config file should be fairly self explanatory, so starting with `lsi_temp` in the **List of HBAs** section: this is the path to a compiled binary of the [lsi_temp](https://gist.github.com/dak180/cd44e9957e1c4180e7eb6eb000716ee2) helper program which gets the temp of LSI HBA cards that support it (SAS 3+ generally)

`hbaName` is a list of both HBAs and expanders that support temp sensors.

**Temp sensors**: This section allows you to specify what the motherboard temp sensors will be used for.

The `hbaTempSens` array is useful if your motherboard supports thermal probes and you have a HBA card that does not support temperature reporting.

The `ambTempSens` array is to specify which sensors mesure the internal ambient temperature of the case.

**IPMI Fan Commands**: This section allows you to customise the commands to both read and write fan speeds. All of these commands _will_ need to be customised for both the motherboard you are using and how fans are attached to it.

The `ipmiWrite` function is used to write the PWM levels for each fan as a value from 0 - 100; this command is specific to a particular model of board, consult your board manufacture to get the correct command.

The `ipmiRead` function is used to read the PWM levels for each fan as a value from 0 - 100 in hexadecimal; this command is specific to a particular model of board, consult your board manufacture to get the correct command.

It is suggested that following invocation be used to run this script from a Post Init task:
```bash
/usr/sbin/daemon -t "FanControl" -P "/var/run/daemon-FanControl.pid" -p "/var/run/FanControl.pid" -Ss "info" -T "FanControl" -R "60" <path>/FanControl.tool -dc "<path>/FanConfig"
```

## ipfw.rules ##

A script to setup `ipfw` to force all non lan trafic from the `transmission` user through the first listed `tun` device.

## jls.tool ##

This a script to automate the creation of jails; modification would likely be required for your setup.

## pia-port-forward.sh ##

This is a script to maintain a pia vpn connection with an open port for transmission.  It is intended to be run via cron at intervals of less than 15 mins from within the jail running transmission and openvpn.

This script generally expects to be run form a jail created via `jls.tool transmission`.

The `vpnDir` will need to be set to the location of the openvpn config directory.

The `firewallScript` needs to be set to the location of the `ipfw.rules` file.

## search.cmd ##

A command to initiate crawls from within the **search** jail as setup by `jls.tool search`.

## suite-definition.xml ##

A configuration file for the phoronix-test package.

## tlerActiveation.tool ##

A script to activate Time Limited Error Recovery on drives that do not remember this setting between reboots.  This is intended to be run as a Post Init task.
