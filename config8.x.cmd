#!/bin/bash
# Set VARIABLEs

echo "Confirm version is OneFS 8.x, the script may fail OneFS 7.x."
echo "Please input y or yes, if you continue this script."
echo "========================================================"
read INPUTSTR
if [ "$INPUTSTR" = "y" -o "$INPUTSTR" = "yes" ]
then
	echo ""
	echo "Continue... ------------------ "`date`
	echo ""
else
	echo ""
	echo "Abort!!! --------------------- "`date`
	echo ""
	exit 1
fi

##################
# setting enviroment
zones=`/usr/bin/isi zone zones list | grep -vE '^Name|^-|^Total' | awk -F\  '{print $1}'`
providers=`/usr/bin/isi auth ads list | grep -vE '^Name|^-|^Total' | awk -F\  '{print $1}'`

##################
# Create WORKDIR

WORKDIR="/ifs/data/Isilon_Support/WORK.EMC"
if [ ! -e $WORKDIR ]; then
    echo "Will create $WORKDIR"
	mkdir -p $WORKDIR
fi

cd $WORKDIR
DATETIME=`date +%Y%m%d-%H%M%S`

TMPDIR=$DATETIME
CONFIGDIR=$DATETIME"/config"
mkdir -p $CONFIGDIR

LOGFILE=$CONFIGDIR"/config.log";

CSVDIR=$CONFIGDIR"/csv"
mkdir -p $CSVDIR

##################
# Setting hostname
ISINAME=`hostname | awk -F\- '{print $1}'`

##################
# setting commands
# except smb,nfs,user,zone
### please add new command without zone
CMDS=(\
"/usr/bin/isi_for_array -s isi_hw_status -i | grep SerNo" \
"/usr/bin/isi_for_array -s isi version" \
"/usr/bin/isi_for_array -s cat /etc/ntp.conf" \
"/usr/bin/isi_for_array -s isi auth ads list" \
"/usr/bin/isi_for_array -s ntpq -p" \
"/usr/bin/isi_ntp_config list" \
"/usr/sbin/isi_log_server list" \
"/usr/bin/isi antivirus settings view" \
"/usr/bin/isi antivirus policies list --v" \
"/usr/bin/isi antivirus reports scans list --v" \
"/usr/bin/isi antivirus reports threats list --v" \
"/usr/bin/isi antivirus servers list --v" \
"/usr/bin/isi audit settings global view" \
"/usr/bin/isi audit topics list --v" \
"/usr/bin/isi auth ads list --v" \
"/usr/bin/isi auth roles list --v" \
"/usr/bin/isi auth status --v"
"/usr/bin/isi auth settings global view" \
"/usr/bin/isi auth mapping list" \
"/usr/bin/isi auth settings mapping view" \
"/usr/bin/isi auth nis list" \
"/usr/bin/isi auth ldap list" \
"/usr/bin/isi auth krb5 list" \
"/usr/bin/isi auth krb5 realm list" \
"/usr/bin/isi certificate server list" \
"/usr/bin/isi cluster contact view" \
"/usr/bin/isi dedupe reports list -v" \
"/usr/bin/isi dedupe settings view" \
"/usr/bin/isi dedupe stats" \
"/usr/bin/isi event alerts list --v" \
"/usr/bin/isi event channels list --v" \
"/usr/bin/isi email settings view" \
"/usr/bin/isi filepool default-policy view" \
"/usr/bin/isi filepool policies list --v" \
"/usr/bin/isi license list" \
"/usr/bin/isi nfs settings global view" \
"/usr/bin/isi network groupnets list --v" \
"/usr/bin/isi network subnets list --v" \
"/usr/bin/isi network pools list --v" \
"/usr/bin/isi network rules list --v" \
"/usr/bin/isi network interfaces list --v" \
"/usr/bin/isi network external view" \
"/usr/bin/isi quota quotas list -v" \
"/usr/bin/isi quota settings reports view" \
"/usr/bin/isi quota settings notifications list -v" \
"/usr/bin/isi remotesupport connectemc view" \
"/usr/bin/isi smb settings global view" \
"/usr/bin/isi snapshot settings view" \
"/usr/bin/isi snapshot schedules list -v" \
"/usr/bin/isi snapshot snapshots list -v" \
"/usr/bin/isi sync policies list -v" \
"/usr/bin/isi sync rules list -v" \
"/usr/bin/isi stat -a" \
"/usr/bin/isi stat -p -v" \
"/usr/bin/isi upgrade cluster list" \
"/usr/bin/isi upgrade patches list -v" \
"/usr/bin/isi sync settings view" \
"/usr/bin/isi storagepool list --v" \
"/usr/bin/isi time timezone view" \
"/usr/bin/isi http settings view" \
"/usr/bin/isi ftp settings view" \
"/usr/bin/isi job policies list --v" \
"/usr/bin/isi job reports list" \
"/usr/bin/isi job events list -v --limit=1000" \
"/usr/bin/isi job types list --v" \
"/usr/bin/isi job jobs list" \
"ls -led /ifs/*" \
"/usr/bin/isi_for_array -s cat /etc/crontab" \
)

### please add new command with csv
CSV_CMDS=(\
"/usr/bin/isi zone zones list --v --format=csv" \
"/usr/bin/isi network groupnets list --v --format=csv" \
"/usr/bin/isi network subnets list --v --format=csv" \
"/usr/bin/isi network pools list --v --format=csv" \
"/usr/bin/isi network rules list --v --format=csv" \
"/usr/bin/isi network interfaces list --v --format=csv" \
"/usr/bin/isi quota quotas list -v --format=csv" \
"/usr/bin/isi quota settings notifications list -v --format=csv" \
"/usr/bin/isi snapshot schedules list -v --format=csv" \
"/usr/bin/isi snapshot snapshots list -v --format=csv" \
"/usr/bin/isi sync policies list -v --format=csv" \
"/usr/bin/isi sync rules list -v --format=csv" \
"/usr/bin/isi upgrade patches list -v --format=csv" \
"/usr/bin/isi antivirus policies list --v --format=csv" \
"/usr/bin/isi antivirus reports scans list --v --format=csv" \
"/usr/bin/isi antivirus reports threats list --v --format=csv" \
"/usr/bin/isi antivirus servers list --v --format=csv" \
"/usr/bin/isi auth roles list --v --format=csv" \
"/usr/bin/isi auth status --v --format=csv" \
"/usr/bin/isi auth local list --v --format=csv" \
"/usr/bin/isi batterystatus list --v --format=csv" \
"/usr/bin/isi audit topics list --v --format=csv" \
"/usr/bin/isi job policies list --v --format=csv" \
"/usr/bin/isi job reports list --format=csv" \
"/usr/bin/isi filepool policies list --v --format=csv" \
)

##################
# main function
ZONE_VIEW(){
	for zone in `echo $zones`;
	do
		echo ">Output Zone Detail..."$zone;
		CMD="/usr/bin/isi zone zones view --zone=$zone"
		echo "=========="$CMD"==========" >> $LOGFILE;
		echo "`$CMD`" >> $LOGFILE;
	done
	echo "=============END_Zone_detail===========" >> $LOGFILE;
}

SMB_LIST(){
	echo "" >> $LOGFILE;
	echo "====================SMB======================" >> $LOGFILE;
	for zone in `echo $zones`;
	do
		echo ">Output SMB..."$zone;
		shares=`/usr/bin/isi smb shares list --zone=$zone | grep -vE '^Share Name  Path|^---|^Total:\ ' | awk -F\  '{print $1}'`
		
		## for csv
		CSVFILE=$CSVDIR"/csv_smb_list.txt"
		CMD="/usr/bin/isi smb shares list --v --zone=$zone --format=csv"
		echo "Zone,"$zone",Share" >> $CSVFILE;
		echo "`$CMD`" >> $CSVFILE;
		echo "" >> $CSVFILE;
		
		## for txt
		for share in `echo $shares`;
		do
			CMD="/usr/bin/isi smb shares view $share --zone=$zone"
			echo "========================"$CMD"================================">> $LOGFILE;
			echo "`$CMD`" >> $LOGFILE;
		done
	done
	echo "====================END_SMB==================" >> $LOGFILE;
}


NFS_LIST(){
	echo "" >> $LOGFILE;
	echo "====================NFS=====================" >> $LOGFILE;
	for zone in `echo $zones`;
	do
		## for csv
		CSVFILE=$CSVDIR"/csv_nfs_list.txt"
		CMD="/usr/bin/isi nfs exports list --v --zone=$zone --format=csv"
		echo "Zone,"$zone",Export" >> $CSVFILE;
		echo "`$CMD`" >> $CSVFILE;
		echo "" >> $CSVFILE;
		CSVFILE=$CSVDIR"/csv_nfs_alias.txt"
		CMD="/usr/bin/isi nfs aliases list --zone=$zone --format=csv"
		echo "Zone,"$zone",Alias" >> $CSVFILE;
		echo "`$CMD`" >> $CSVFILE;
		echo "" >> $CSVFILE;
		
		## for txt
		echo ">Output NFS..."$zone;
		CMD="/usr/bin/isi nfs exports list --v --zone=$zone"
		echo "================"$CMD"================" >> $LOGFILE;
		echo "`$CMD`" >> $LOGFILE;
		CMD="/usr/bin/isi nfs aliases list --zone=$zone"
		echo "================"$CMD"================" >> $LOGFILE;
		echo "`$CMD`" >> $LOGFILE;
		CMD="/usr/bin/isi nfs settings export view --zone=$zone"
		echo "================"$CMD"================" >> $LOGFILE;
		echo "`$CMD`" >> $LOGFILE;
	done
	echo "====================END_NFS=================" >> $LOGFILE;
}

 
USER_LIST(){
	echo "" >> $LOGFILE;
	echo "====================USER=====================" >> $LOGFILE;
	for zone in `echo $zones`;
	do
		## for csv
		CSVFILE=$CSVDIR"/csv_user_list.txt"
		CMD="/usr/bin/isi auth users list --zone=$zone --provider=local -v --format=csv"
		echo "Zone,"$zone",User" >> $CSVFILE;
		echo "`$CMD`" >> $CSVFILE;
		echo "" >> $CSVFILE;
		CSVFILE=$CSVDIR"/csv_group_list.txt"
		CMD="/usr/bin/isi auth groups list --zone=$zone --provider=local -v --format=csv"
		echo "Zone,"$zone",Group" >> $CSVFILE;
		echo "`$CMD`" >> $CSVFILE;
		echo "" >> $CSVFILE;
		
		## for txt
		echo ">Output Users..."$zone;
		CMD="/usr/bin/isi auth users list --zone=$zone --provider=local -v"
		echo "================"$CMD"================" >> $LOGFILE;
		echo "`$CMD`" >> $LOGFILE;
		CMD="/usr/bin/isi auth groups list --zone=$zone --provider=local -v"
		echo "================"$CMD"================" >> $LOGFILE;
		echo "`$CMD`" >> $LOGFILE;
	done
	echo "====================END_USER=================" >> $LOGFILE;
}

AUDIT_LIST(){
	echo "" >> $LOGFILE;
	echo "====================Audit=====================" >> $LOGFILE;
	for zone in `echo $zones`;
	do
		## for txt
		echo ">Output Audit..."$zone;
		CMD="/usr/bin/isi audit settings view --zone=$zone"
		echo "================"$CMD"================" >> $LOGFILE;
		echo "`$CMD`" >> $LOGFILE;
	done
	echo "====================END_Audit=================" >> $LOGFILE;
}

SPN_LIST(){
	echo "" >> $LOGFILE;
	echo "====================SPN=====================" >> $LOGFILE;
	for provider in `echo $providers`;
	do
		## for csv
		CSVFILE=$CSVDIR"/csv_spn_list.txt"
		CMD="/usr/bin/isi auth ads spn list $provider --v --format=csv"
		echo "`$CMD`" >> $CSVFILE;
		echo "" >> $CSVFILE;
		
		## for txt
		echo ">Output SPN..."$provider;
		CMD="/usr/bin/isi auth ads spn list $provider"
		echo "================"$CMD"================" >> $LOGFILE;
		echo "`$CMD`" >> $LOGFILE;
		CMD="/usr/bin/isi auth ads spn check $provider"
		echo "================"$CMD"================" >> $LOGFILE;
		echo "`$CMD`" >> $LOGFILE;
	done
	echo "====================END_SPN=================" >> $LOGFILE;
}

OTHER_INFO() {
	LOGFILE_INFO=$CONFIGDIR"/info.log";
	echo "" >> $LOGFILE;
	echo "========================OTHER_INFO========================" >> $LOGFILE;
	for CMD in "${CMDS[@]}";
		do
			echo ">Output Commands..."$CMD
			echo "========================"$CMD"========================" >> $LOGFILE;
			echo "`$CMD`" >> $LOGFILE;
	done
	echo "====================END_OTHER_INFO=============" >> $LOGFILE;
}

OTHER_INFO_CSV() {
	for CMD in "${CSV_CMDS[@]}";
		do
		## for csv
		CSVFILE=$CSVDIR"/csv_"`echo $CMD | awk -F\  '{print $2}'`".csv";
		echo "" >> $CSVFILE;
		echo ">Output Commands..."$CMD;
		echo "=======$CMD=======" >> $CSVFILE;
		echo "`$CMD`" >> $CSVFILE;
		echo "" >> $CSVFILE;
	done
}

ISI_CONFIG() {
isi config <<EOS >> $LOGFILE
status advanced
iprange
netmask
timezone
encoding
interface
joinmode
mtu
version
date
name
quit
EOS
}

##################
# main function output
ZONE_VIEW
SMB_LIST
NFS_LIST
USER_LIST
AUDIT_LIST
SPN_LIST
OTHER_INFO
OTHER_INFO_CSV
ISI_CONFIG

##################
# tar the files
TAR_FILENAME="Isilon_tar_"$ISINAME"_"$DATETIME".tar.gz"
tar zcvf $TAR_FILENAME $CONFIGDIR/* && rm -rf $TMPDIR


##################
# end messages
echo "========================================================"
echo ""
echo "Complete ... ------------------ "`date`
echo ""
echo "output was /ifs/data/Isilon_Support/WORK.EMC/"$TAR_FILENAME
echo "========================================================"