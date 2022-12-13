#! /bin/sh -

#/*-
# * Copyright (c) 2000-2020 sol.net Network Services
# * All rights reserved.
# *
# * Redistribution and use in source and binary forms, with or without
# * modification, are permitted provided that the following conditions
# * are met:
# * 1. Redistributions of source code must retain the above copyright
# *    notice, this list of conditions and the following disclaimer.
# * 2. Redistributions in binary form must reproduce the above copyright
# *    notice, this list of conditions and the following disclaimer in the
# *    documentation and/or other materials provided with the distribution.
# * 3. All advertising materials mentioning features or use of this software
# *    must display the following acknowledgement:
# *      This product includes software developed by sol.net Network Services.
# * 4. Neither the name of the author nor the names of any co-contributors
# *    may be used to endorse or promote products derived from this software
# *    without specific prior written permission.
# *
# * THIS SOFTWARE IS PROVIDED BY SOL.NET NETWORK SERVICES AND CONTRIBUTORS
# * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# * PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL SOL.NET NETWORK
# * SERVICES OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# * TO, PROCUREMENT OF SUBSTITUTE GOODS  OR SERVICES; LOSS OF USE, DATA, OR
# * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *
# * $Id$
# *
# */

set -e
notselected=true
disklist=""
wdelay=60
#wdelay=6
climit=
#climit="count=100000"
passnumber=1

samplediskspeed() {
    printf "Please hold, sampling disk speed of ${1}\r" > /dev/tty
    sleep 10
    iostat -c 2 -d -w ${wdelay} "${1}" | tail -1 | awk '{printf "%0.2f", $3}'
    printf "                                            \r" > /dev/tty
}

getdisksize() {
    disksize=`(cat /var/run/dmesg.boot; dmesg) | egrep "^${1}:.* byte sectors.*" | tail -1 | sed -n 's/^[a-z0-9]*: \([0-9]*\)MB .*$/\1/p'`

    if [ -z "${disksize}" ]; then
        disksize=0
    fi
    if [ "${disksize}" -eq 0 ]; then
        echo "Unable to determine disk ${1} size from dmesg file (not fatal but odd!)" > /dev/tty
    fi
    echo ${disksize}
}

approximatepasstime() {
    disksize=`getdisksize "${1}"`
    if [ "${disksize}" -gt 0 ]; then
        echo "The disk ${1} appears to be ${disksize} MB.        "
        speed=`samplediskspeed "${1}"`
        echo "${disksize} ${speed}" | awk '{printf "Disk is reading at about %0.0f MB/sec        \nThis suggests that this pass may take around %0.0f minutes\n", $2, $1 / $2 / 60}'
    else
        echo "Unable to determine disk ${1} size from dmesg file (not fatal but odd!)"
    fi
}


echo "sol.net disk array test v2"

while ${notselected}; do
    echo ""
    echo "1) Use all disks (from camcontrol)"
    echo "2) Use selected disks (from camcontrol|grep)"
    echo "3) Specify disks"
    echo "4) Show camcontrol list"
    echo ""
    echo -n "Option: "

    read opt
    case "${opt}" in
        1)    disklist=`camcontrol devlist | sed 's:.*(::;s:).*::;s:,pass[0-9]*::;s:pass[0-9]*,::' | egrep '^[a]*da[0-9]+$' | tr '\012' ' '`;;
        2)    echo ""
            echo -n "Enter grep match pattern (e.g. ST150176): "
            read pat
            disklist=`camcontrol devlist | grep "${pat}" | sed 's:.*(::;s:).*::;s:,pass[0-9]*::;s:pass[0-9]*,::' | egrep '^[a]*da[0-9]+$' | tr '\012' ' '`;;
        3)    echo ""
            echo -n "Enter disk devices separated by spaces (e.g. da1 da2): "
            read disklist;;
        4)    camcontrol devlist | more -E
            echo -n "Press Return: "
            read ret
            continue;;
    esac
    if [ -z "${disklist}" ]; then
        echo ""
        echo "ERROR: No disks selected!"
    else
        patlist='('`echo ${disklist} | tr ' ' '|'`')'

        echo ""
        (
        echo "Selected disks: ${disklist}"
        camcontrol devlist | egrep '[(,]'"${patlist}"'[,)]'
        ) | more -E
        echo -n "Is this correct? (y/N): "
        read ans
        case "${ans}" in
            y|Y|yes|YES)    notselected=false;;
        esac
    fi
done

################################
#disklist="${disklist} x"

echo "Performing initial serial array read (baseline speeds)"
date
for disk in ${disklist}; do
    dd if=/dev/${disk} of=/dev/null bs=1048576 2> /tmp/sat.${disk}.err > /tmp/sat.${disk}.out &
    pid=$!
    sleep ${wdelay}
    getdisksize     ${disk} > /tmp/sat.${disk}.size.out
    samplediskspeed ${disk} > /tmp/sat.${disk}.sspeed.out
    kill "${pid}" 2> /dev/null || true
    sleep 5
done
date
echo "Completed: initial serial array read (baseline speeds)"

for disk in ${disklist}; do
    if [ -s /tmp/sat.${disk}.err ]; then
        sed '/ records in$/d;/ records out$/d;/ bytes transferred in /d;s:^:!!ERROR!! :' < /tmp/sat.${disk}.err
    fi
done

(
    for disk in ${disklist}; do
        egrep -v '^(0|0\.00)$' /tmp/sat.${disk}.sspeed.out
    done
) | awk 'BEGIN {sum=0}{sum=sum+$1} END {print sum/NR}' > /tmp/sat.average.sspeed.out
echo ""
avgspeed=`cat /tmp/sat.average.sspeed.out`
echo "Array's average speed is ${avgspeed} MB/sec per disk"

echo ""
echo "Disk    Disk Size  MB/sec %ofAvg"
echo "------- ---------- ------ ------"
for disk in ${disklist}; do
    echo "${disk}" `cat /tmp/sat.${disk}.size.out` `cat /tmp/sat.${disk}.sspeed.out` "${avgspeed}" | awk '{percent=100 * $3 / $4; printf "%-7s %8sMB %6.0f %6.0f", $1, $2, $3, percent; if (percent < 92) printf " --SLOW--"; if (percent > 107) printf " ++FAST++"; printf "\n"}'
done

pass=initial

echo ""
echo "Performing ${pass} parallel array read"
date
for disk in ${disklist}; do
    dd if=/dev/${disk} of=/dev/null bs=1048576 ${climit} 2> /tmp/sat.${disk}.err > /tmp/sat.${disk}.out || true &
done

approximatepasstime ${disklist}

sleep ${wdelay}

for disk in ${disklist}; do
    samplediskspeed ${disk} > /tmp/sat.${disk}.pspeed.out
done

echo ""
echo "                   Serial Parall % of"
echo "Disk    Disk Size  MB/sec MB/sec Serial"
echo "------- ---------- ------ ------ ------"
for disk in ${disklist}; do
    echo "${disk}" `cat /tmp/sat.${disk}.size.out` `cat /tmp/sat.${disk}.sspeed.out` `cat /tmp/sat.${disk}.pspeed.out` | awk '{if ($3 != 0) {percent=100 * $4 / $3} else {percent = 0}; printf "%-7s %8sMB %6.0f %6.0f %6.0f", $1, $2, $3, $4, percent; if (percent < 92) printf " --SLOW--"; if (percent > 107) printf " ++FAST++"; printf "\n"}'
done

echo ""
echo "Awaiting completion: ${pass} parallel array read"

wait

date
echo "Completed: ${pass} parallel array read"

for disk in ${disklist}; do
    if [ -s /tmp/sat.${disk}.err ]; then
        sed '/ records in$/d;/ records out$/d;/ bytes transferred in /d;s:^:!!ERROR!! :' < /tmp/sat.${disk}.err
    fi
done

(
    for disk in ${disklist}; do
        grep ' bytes transferred in ' /tmp/sat.${disk}.out /tmp/sat.${disk}.err
    done
) | awk 'BEGIN {sum=0}{sum=sum+$5} END {printf "%0.0f", sum/NR}' > /tmp/sat.average.time

avgtime=`cat /tmp/sat.average.time`
echo ""
echo "Disk's average time is ${avgtime} seconds per disk"
echo ""
echo "Disk    Bytes Transferred Seconds %ofAvg"
echo "------- ----------------- ------- ------"
for disk in ${disklist}; do
    echo "${disk}" "${avgtime}" `grep -h " bytes transferred in" /tmp/sat.${disk}.out /tmp/sat.${disk}.err` "${avgtime}" | awk '{ if ($2 != 0) {percent=100 * $7 / $2} else {percent = 0}; printf "%-7s %17s %7.0f %6.0f", $1, $3, $7, percent; if (percent < 92) printf " ++FAST++"; if (percent > 107) printf " --SLOW--"; printf "\n"}'
done

echo ""
echo "Performing ${pass} parallel seek-stress array read"
date
for disk in ${disklist}; do
    dd if=/dev/${disk} of=/dev/null bs=1048576 ${climit} 2> /tmp/sat.${disk}.err > /tmp/sat.${disk}.out || true &
done
for i in 1 2 3 4 5; do
    sleep ${wdelay}
    for disk in ${disklist}; do
        dd if=/dev/${disk} of=/dev/null bs=1048576 ${climit} 2> /dev/null > /dev/null || true &
    done
done

approximatepasstime ${disklist}

sleep ${wdelay}

for disk in ${disklist}; do
    samplediskspeed ${disk} > /tmp/sat.${disk}.pspeed.out
done

echo ""
echo "                   Serial Parall % of"
echo "Disk    Disk Size  MB/sec MB/sec Serial"
echo "------- ---------- ------ ------ ------"
for disk in ${disklist}; do
    echo "${disk}" `cat /tmp/sat.${disk}.size.out` `cat /tmp/sat.${disk}.sspeed.out` `cat /tmp/sat.${disk}.pspeed.out` | awk '{if ($3 != 0) {percent=100 * $4 / $3} else {percent = 0}; printf "%-7s %8sMB %6.0f %6.0f %6.0f\n", $1, $2, $3, $4, percent}'
done

echo ""
echo "Awaiting completion: ${pass} parallel seek-stress array read"

wait

date
echo "Completed: ${pass} parallel seek-stress array read"

for disk in ${disklist}; do
    if [ -s /tmp/sat.${disk}.err ]; then
        sed '/ records in$/d;/ records out$/d;/ bytes transferred in /d;s:^:!!ERROR!! :' < /tmp/sat.${disk}.err
    fi
done

(
    for disk in ${disklist}; do
        grep ' bytes transferred in ' /tmp/sat.${disk}.out /tmp/sat.${disk}.err
    done
) | awk 'BEGIN {sum=0}{sum=sum+$5} END {printf "%0.0f", sum/NR}' > /tmp/sat.average.time

avgtime=`cat /tmp/sat.average.time`
echo ""
echo "Disk's average time is ${avgtime} seconds per disk"
echo ""
echo "Disk    Bytes Transferred Seconds %ofAvg"
echo "------- ----------------- ------- ------"
for disk in ${disklist}; do
    echo "${disk}" "${avgtime}" `grep -h " bytes transferred in" /tmp/sat.${disk}.out /tmp/sat.${disk}.err` "${avgtime}" | awk '{ if ($2 != 0) {percent=100 * $7 / $2} else {percent = 0}; printf "%-7s %17s %7.0f %6.0f", $1, $3, $7, percent; if (percent < 92) printf " ++FAST++"; if (percent > 107) printf " --SLOW--"; printf "\n"}'
done
