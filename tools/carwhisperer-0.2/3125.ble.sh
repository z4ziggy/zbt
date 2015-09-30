#!/bin/bash
# used for regulatory testing of the Bluetooth (TI CC2560).
#version 1

echo "Bluetooth Testing (see TI CC256x Testing Guide)."

#hciattach -s 115200 /dev/ttyAMA3 texas
hciconfig noscan

echo "The CC2560 device must be power cycled when switched between different FCC modes."

#==========================================

C_TX () {
	echo "Continuous TX"

	Mod=0x00
	TP=0x01

	Modulation=5
	while [ $Modulation -lt 0 -o $Modulation -gt 4 ]
	do
		echo -e -n "Select Modulation: 0=CW, 1=GFSK(BR), 2=pi/4-DQPSK (2-EDR), 3=8DPSK (3-EDR), 4=BLE\n"
		read Modulation

		case $Modulation in
			0) Mod=0x00 ;;
			1) Mod=0x01 ;;
			2) Mod=0x02 ;;
			3) Mod=0x03 ;;
			4) Mod=0x04 ;;
			*) echo "selection is not valid"
		esac
	done
	echo Modulation=$Mod

	Test=7
	while [ $Test -lt 0 -o $Test -gt 6 ]
	do
		echo -e -n "Select Test Pattern: 0=PN9, 1=PN15, 2=Z0Z0, 3=all 1, 4=all 0, 5=F0F0, 6=FF00\n" 
		read Test

		case $Test in
			0) TP=0x00 ;;
			1) TP=0x01 ;;
			2) TP=0x02 ;;
			3) TP=0x03 ;;
			4) TP=0x04 ;;
			5) TP=0x05 ;;
			6) TP=0x06 ;;
			*) echo "selection is not valid"
		esac
	done
	echo TestPattern=$TP

	Freq=79
	while [ $Freq -lt 0 -o $Freq -gt 78 ]
	do
		echo -e -n "Select Frequency (0-39: f=2402+(2*i)MHz, 40-78: f=2403+2(i-40)Mhz:\n"
		read Freq

	done
	F=$( printf "0x%02x" $Freq )
	echo Frequency=$F

	Pwr=16
	while [ $Pwr -lt 0 -o $Pwr -gt 15 ]
	do
		echo -e -n "Select Power Level (0-15):\n"
		read Pwr

	done
	P=$( printf "0x%01x" $Pwr )
	echo PowerLevel=$P

	echo "Issuing the continuous Tx commands" 
	#HCI_VS_DRPb_Tester_Con_TX
	hcitool cmd 0x3f 0x0184 $Mod $TP $F $P 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00

	#hcitool cmd 0x3f 0x0184 0x01 0x00 0x00 0x0f 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00

	#HCI_VS_Write_Hardware Register
	hcitool cmd 0x3f 0x0301 0x0c 0x18 0x19 0x00 0x01 0x01

	#HCI_VS_DRPb_Enable_RF_Calibration
	hcitool cmd 0x3f 0x0180 0x00 0x01 0x00 0x00 0x00 0x01
}

#=================================================

PacketTxRx () {
	FreqMode=4
	while [ $FreqMode -ne 1 -a $FreqMode -ne 3 ]
	do
		echo -e -n "Select Test Pattern: 1=Hopping, 3=Single Frequency\n" 
		read FreqMode

		case $FreqMode in
			1) FM=0x01 ;;
			3) FM=0x03 ;;
			*) echo "selection is not valid"
		esac
	done
	echo FreqMode=$FM

	TxFreq=79
	while [ $TxFreq -lt 0 -o $TxFreq -gt 78 ]
	do
		echo -e -n "Select Tx Frequency (0-39: f=2402+(2*i)MHz, 40-78: f=2403+2(i-40)Mhz:\n"
		read TxFreq

	done
	TxF=$( printf "0x%02x" $TxFreq )
	echo Tx Frequency=$TxF

	RxFreq=79
	while [ $RxFreq -lt 0 -o $RxFreq -gt 78 ]
	do
		echo -e -n "Select Rx Frequency (0-39: f=2402+(2*i)MHz, 40-78: f=2403+2(i-40)Mhz:\n"
		read RxFreq

	done
	RxF=$( printf "0x%02x" $RxFreq )
	echo Rx Frequency=$RxF

	ACLTx="c"
	while [ "$ACLTx" != "0" -a "$ACLTx" != "1" -a "$ACLTx" != "2" -a "$ACLTx" != "3" -a "$ACLTx" != "4" -a "$ACLTx" != "5" -a "$ACLTx" != "6" -a "$ACLTx" != "7" -a "$ACLTx" != "8" -a "$ACLTx" != "9" -a "$ACLTx" != "a" -a "$ACLTx" != "A" -a "$ACLTx" != "b" -a "$ACLTx" != "B" ]
	do
		echo -e -n "Select ACL Tx Packet Type: 0=DM1, 1=DH1, 2=DM3, 3=DH3, 4=DM5, 5=DH5, 6=2-DH1, 7=2-DH3, 8=2-DH5, 9=3-DH1, A=3-DH3, B=3-DH5\n" 
		read ACLTx

		case $ACLTx in
			0) ACLTX=0x00 ;;
			1) ACLTX=0x01 ;;
			2) ACLTX=0x02 ;;
			3) ACLTX=0x03 ;;
			4) ACLTX=0x04 ;;
			5) ACLTX=0x05 ;;
			6) ACLTX=0x06 ;;
			7) ACLTX=0x07 ;;
			8) ACLTX=0x08 ;;
			9) ACLTX=0x09 ;;
			a) ACLTX=0x0a ;;
			A) ACLTX=0x0a ;;
			b) ACLTX=0x0b ;;
			B) ACLTX=0x0b ;;
			*) echo "selection is not valid"
		esac
	done
	echo ACL Tx=$ACLTX

	ACLTxPat=6
	while [ $ACLTxPat -lt 0 -o $ACLTxPat -gt 5 ]
	do
		echo -e -n "Select ACL Tx Packet Data Pattern: 0=all 0, 1=all 1, 2=Z0Z0, 3=F0F0, 4=ordered, 5=PRBS9 Random\n" 
		read ACLTxPat

		case $ACLTxPat in
			0) ACLTXPAT=0x00 ;;
			1) ACLTXPAT=0x01 ;;
			2) ACLTXPAT=0x02 ;;
			3) ACLTXPAT=0x03 ;;
			4) ACLTXPAT=0x04 ;;
			5) ACLTXPAT=0x05 ;;
			*) echo "selection is not valid"
		esac
	done
	echo ACL Tx Packet Data Pattern=$ACLTXPAT

	ACLTxLen=400
	while [ $ACLTxLen -lt 0 -o $ACLTxLen -gt 367 ]
	do
		echo -e -n "Select ACL Packet Data Length: 0-17(DM1), 0-27(DH1), 0-121(DM3), 0-183(DH3), 0-224(DM5), 0-339(DH5), 0-54(2-DH1), 0-367(2-DH3), 0-83(3-DH1)\n" 
		read ACLTxLen

	done
	AclTxL=$( printf "0x%03x" $ACLTxLen )
	echo ACL Tx Packet Data Length=$AclTxL

	Pwr1=16
	while [ $Pwr1 -lt 0 -o $Pwr1 -gt 15 ]
	do
		echo -e -n "Select Power Level (0-15):\n"
		read Pwr1

	done
	P1=$( printf "0x%01x" $Pwr1 )
	echo PowerLevel=$P1

	Whitening=4
	while [ $Whitening -ne 0 -a $Whitening -ne 1 ]
	do
		echo -e -n "Select Disable Whitening: 0=Enable, 1=Disable\n" 
		read Whitening

		case $Whitening in
			0) WH=0x00 ;;
			1) WH=0x01 ;;
			*) echo "selection is not valid"
		esac
	done
	echo Disable Whitening=$WH

	PRBS9=512
	while [ $PRBS9 -gt 511 ]
	do
		echo -e -n "Select PRBS9 Init Value (0-511):\n"
		read PRBS9

	done
	prbs9=$( printf "0x%04x" $PRBS9 )
	echo PRBS9=$prbs9

	echo "Issuing the Packet Tx/Rx command"
	#HCI_VS_DRPb_Tester_Packet_TX_RX
	hcitool cmd 0x3f 0x0185 $FM $TxF $RxF $ACLTX $ACLTXPAT $AclTxL $P1 $WH $prbs9
}

#======================================================================

C_RX () {
	RXF=79
	while [ $RXF -lt 0 ] #-o $TXF -gt 78 ]
	do
		echo -e -n "Select Rx Frequency (0-39: f=2402+(2*i)MHz, 40-78: f=2403+2(i-40)Mhz):\n"
		read RxFreq

	done
	RXF1=$( printf "0x%02x" $RXF )
	echo Rx Frequency=$RXF1
	echo "Issuing the Continuous Rx command"
	hcitool cmd 0x3f 0x0117 0x00 0x00	#HCI_VS_DRPb_Tester_Con_Rx
}

RF_Sig () {
	hcitool cmd 0x3 0x0005 0x02 0x00 0x02	#HCI_Set_Event_Filter
	hciconfig hci0 piscan 	#HCI_Write_Scan_Enable
	hcitool cmd 0x6 0x0003	#HCI_Enable_Device_Under_Test_Mode
}

#======================================================================

PLT () {
	echo The frequency channel, BD address, packet type and #bytes/packet must match that of the transmitter.
	FR=79
	while [ $FR -lt 0 -o $FR -gt 78 ]
	do
		echo -e -n "Select Frequency Channel (0-39: f=2402+(2*i)MHz, 40-78: f=2403+2(i-40)Mhz):\n"
		read FR

	done
	Fr=$( printf "0x%02x" $FR )
	echo Frequency Channel=$Fr

	echo "Enter MAC Address of Transmitter (0xXX 0xXX 0xXX 0xXX 0xXX 0xXX)"
	read mac1 mac2 mac3 mac4 mac5 mac6
	mac=$( printf "0x%02x%02x%02x%02x%02x%02x" 0x$mac6 0x$mac5 0x$mac4 0x$mac3 0x$mac2 0x$mac1 )
	echo $mac

	ACLTx2="c"
	while [ "$ACLTx2" != "0" -a "$ACLTx2" != "1" -a "$ACLTx2" != "2" -a "$ACLTx2" != "3" -a "$ACLTx2" != "4" -a "$ACLTx2" != "5" -a "$ACLTx2" != "6" -a "$ACLTx2" != "7" -a "$ACLTx2" != "8" -a "$ACLTx2" != "9" -a "$ACLTx2" != "a" -a "$ACLTx2" != "A" -a "$ACLTx2" != "b" -a "$ACLTx2" != "B" ]
	do
		echo -e -n "Select ACL Tx Packet Type: 0=DM1, 1=DH1, 2=DM3, 3=DH3, 4=DM5, 5=DH5, 6=2-DH1, 7=2-DH3, 8=2-DH5, 9=3-DH1, A=3-DH3, B=3-DH5\n" 
		read ACLTx2

		case $ACLTx2 in
			0) ACLTX2=0x00 ;;
			1) ACLTX2=0x01 ;;
			2) ACLTX2=0x02 ;;
			3) ACLTX2=0x03 ;;
			4) ACLTX2=0x04 ;;
			5) ACLTX2=0x05 ;;
			6) ACLTX2=0x06 ;;
			7) ACLTX2=0x07 ;;
			8) ACLTX2=0x08 ;;
			9) ACLTX2=0x09 ;;
			a) ACLTX2=0x0a ;;
			A) ACLTX2=0x0a ;;
			b) ACLTX2=0x0b ;;
			B) ACLTX2=0x0b ;;
			*) echo "selection is not valid"
		esac
	done
	echo ACL Tx=$ACLTX2

	ACLTxLen2=400
	while [ $ACLTxLen2 -lt 0 -o $ACLTxLen2 -gt 367 ]
	do
		echo -e -n "Select ACL Packet Data Length: 0-17(DM1), 0-27(DH1), 0-121(DM3), 0-183(DH3), 0-224(DM5), 0-339(DH5), 0-54(2-DH1), 0-367(2-DH3), 0-83(3-DH1)\n" 
		read ACLTxLen2

	done
	AclTxL2=$( printf "0x%03x" $ACLTxLen2 )
	echo ACL Tx Packet Data Length=$AclTxL2

	Packets=65536
	while [ $Packets -lt 0 -o $Packets -gt 65535 ]
	do
		echo -e -n "How many packets to be used for BER test (0-65535)?\n" 
		read Packets

	done
	PACK=$( printf "0x%04x" $Packets )
	echo Number of Packets for BER test=$PACK

	Prbs9=512
	while [ $Prbs9 -gt 511 ]
	do
		echo -e -n "Select PRBS9 Init Value (0-511):\n"
		read Prbs9

	done
	PRbs9=$( printf "0x%04x" $Prbs9 )
	echo PRBS9=$PRbs9

	Poll=256
	while [ $Poll -lt 0 -o $Poll -gt 255 ]
	do
		echo -e -n "Poll Period (0-255, packet number to use for BER calculation)?\n" 
		read Poll

	done
	PP=$( printf "0x%02x" $Poll )
	echo Packet Number used for BER cal=$PP

	echo "Issuing the PLT commands"
	#HCI_VS_DRPb_BER_Meter_Start
	hcitool cmd 0x3f 0x018b $Fr 0x00 $mac 0x01 $ACLTX2 $AclTxL2 $PACK $PRbs9 $PP
	sleep 5
	#HCI_VS_DRP_Read_BER_Meter_Result
}

#=======================================================================

PLT_TX () {
	echo "This selection is used with PLT.  This assumes another Apollo is used to generate traffic. Both Tx Parmaters should be the same."
	echo "Enter MAC Address of Transmitter (0xXX 0xXX 0xXX 0xXX 0xXX 0xXX)"
	read mac1 mac2 mac3 mac4 mac5 mac6
	Mac=$( printf "0x%02x%02x%02x%02x%02x%02x" 0x$mac6 0x$mac5 0x$mac4 0x$mac3 0x$mac2 0x$mac1 )
	echo $Mac

	FreqMode3=4

	while [ $FreqMode3 -ne 1 -a $FreqMode3 -ne 3 ]
	do
		echo -e -n "Select Test Pattern: 1=Hopping, 2=Single Frequency\n" 
		read FreqMode3

		case $FreqMode3 in
			1) FM3=0x01 ;;
			3) FM3=0x03 ;;
			*) echo "selection is not valid"
		esac
	done
	echo FreqMode=$FM3

	TxFreq3=79
	while [ $TxFreq3 -lt 0 -o $TxFreq3 -gt 78 ]
	do
		echo -e -n "Select Tx Frequency (0-39: f=2402+(2*i)MHz, 40-78: f=2403+2(i-40)Mhz):\n"
		read TxFreq3

	done
	TxF3=$( printf "0x%02x" $TxFreq3 )
	echo Tx Frequency=$TxF3

	ACLTx3="c"
	while [ "$ACLTx3" != "0" -a "$ACLTx3" != "1" -a "$ACLTx3" != "2" -a "$ACLTx3" != "3" -a "$ACLTx3" != "4" -a "$ACLTx3" != "5" -a "$ACLTx3" != "6" -a "$ACLTx3" != "7" -a "$ACLTx3" != "8" -a "$ACLTx3" != "9" -a "$ACLTx3" != "a" -a "$ACLTx3" != "A" -a "$ACLTx3" != "b" -a "$ACLTx3" != "B" ]
	do
		echo -e -n "Select ACL Tx Packet Type: 0=DM1, 1=DH1, 2=DM3, 3=DH3, 4=DM5, 5=DH5, 6=2-DH1, 7=2-DH3, 8=2-DH5, 9=3-DH1, A=3-DH3, B=3-DH5\n" 
		read ACLTx3

		case $ACLTx3 in
			0) ACLTX3=0x00 ;;
			1) ACLTX3=0x01 ;;
			2) ACLTX3=0x02 ;;
			3) ACLTX3=0x03 ;;
			4) ACLTX3=0x04 ;;
			5) ACLTX3=0x05 ;;
			6) ACLTX3=0x06 ;;
			7) ACLTX3=0x07 ;;
			8) ACLTX3=0x08 ;;
			9) ACLTX3=0x09 ;;
			a) ACLTX3=0x0a ;;
			A) ACLTX3=0x0a ;;
			b) ACLTX3=0x0b ;;
			B) ACLTX3=0x0b ;;
			*) echo "selection is not valid"
		esac
	done
	echo ACL Tx=$ACLTX3

	ACLTxPat3=6
	while [ $ACLTxPat3 -lt 0 -o $ACLTxPat3 -gt 5 ]
	do
		echo -e -n "Select ACL Tx Packet Data Pattern: 0=all 0, 1=all 1, 2=Z0Z0, 3=F0F0, 4=ordered, 5=PRBS9 Random\n" 
		read ACLTxPat3

		case $ACLTxPat3 in
			0) ACLTXPAT3=0x00 ;;
			1) ACLTXPAT3=0x01 ;;
			2) ACLTXPAT3=0x02 ;;
			3) ACLTXPAT3=0x03 ;;
			4) ACLTXPAT3=0x04 ;;
			5) ACLTXPAT3=0x05 ;;
			*) echo "selection is not valid"
		esac
	done
	echo ACL Tx Packet Data Pattern=$ACLTXPAT3

	ACLTxLen3=400
	while [ $ACLTxLen3 -lt 0 -o $ACLTxLen3 -gt 367 ]
	do
		echo -e -n "Select ACL Packet Data Length: 0-17(DM1), 0-27(DH1), 0-121(DM3), 0-183(DH3), 0-224(DM5), 0-339(DH5), 0-54(2-DH1), 0-367(2-DH3), 0-83(3-DH1)\n" 
		read ACLTxLen3

	done
	AclTxL3=$( printf "0x%03x" $ACLTxLen3 )
	echo ACL Tx Packet Data Length=$AclTxL3

	Pwr3=16
	while [ $Pwr3 -lt 0 -o $Pwr3 -gt 15 ]
	do
		echo -e -n "Select Power Level (0-15):\n"
		read Pwr3

	done
	P3=$( printf "0x%01x" $Pwr3 )
	echo PowerLevel=$P3

	Whitening3=4
	while [ $Whitening3 -ne 0 -a $Whitening3 -ne 1 ]
	do
		echo -e -n "Select Disable Whitening: 0=Enable, 1=Disable\n" 
		read Whitening3

		case $Whitening3 in
			0) WH3=0x00 ;;
			1) WH3=0x01 ;;
			*) echo "selection is not valid"
		esac
	done
	echo Disable Whitening=$WH3

	PRBS9_3=512
	while [ $PRBS9_3 -gt 511 ]
	do
		echo -e -n "Select PRBS9 Init Value (0-511):\n"
		read PRBS9_3

	done
	prbs9_3=$( printf "0x%04x" $PRBS9_3 )
	echo PRBS9=$prbs9_3

	echo "Issuing the Write BD Addr & Packet Tx/Rx command"
	#HCI_VS_Write_BD_ADDR
	hcitool cmd 0x3f 0x0006 $Mac
	#HCI_VS_DRPb_Tester_Packet_TX_RX
	hcitool cmd 0x3f 0x0185 $FM3 $TxF3 0xff $ACLTX3 $ACLTXPAT3 $AclTxL3 $P3 $WH3 $prbs9_3
}

#===============================================

Reset () {
	#HCI_VS_DRPb_Reset
	hcitool cmd 0x3f 0x0188
}

#===================================================

Scan () {
	bluetoothd
	sleep 1
	hciconfig hci0 up
	sleep 1
	hciconfig hci0 piscan
	sleep 1
	hciconfig hci0 class 420100
	sleep 1
	sdptool add --channel=1 SP
	sleep 1
	hciconfig -a
	sleep 1
	hcitool scan
}

#===================================================

while [ 1 ]
do
	echo -e -n "Select: 1=Continuous TX, 2=Packet Tx/Rx, 3=Continuous Rx, 4=RF_SIG, 5=PLT, 6=PLT_TX, 7=Reset, 8=Scan, 9=exit\n"
	read OP

	case $OP in
		1) C_TX ;;
		2) PacketTxRx ;;
		3) C_RX ;;
		4) RF_Sig ;;
		5) PLT ;;
		6) PLT_TX ;;
		7) Reset ;;
		8) Scan ;;
		9) exit 0 ;;
		*) echo "selection is not valid" ;;
	esac
done



