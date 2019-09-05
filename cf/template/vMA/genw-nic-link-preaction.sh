#! /bin/sh
#***********************************************
#*	          preaction.sh                 *
#***********************************************

ulimit -s unlimited

echo "START"

if [ "$CLP_ACTION" = "" ]
then
	echo "NO_CLP"
	echo "EXIT"
	exit 0
fi

echo "OS NAME         : $CLP_OSNAME"
echo "INSTALL PATH    : $CLP_PATH"
echo "VERSION         : $CLP_VERSION_FULL"

echo "MONITOR NAME    : $CLP_MONITORNAME"
echo "ACTION          : $CLP_ACTION"

if [ "$CLP_ACTION" = "RECOVERY" ]
then
	echo "RECOVERY COUNT  : $CLP_RECOVERYCOUNT"
elif [ "$CLP_ACTION" = "RESTART" ]
then
	echo "RESTART COUNT   : $CLP_RESTARTCOUNT"
elif [ "$CLP_ACTION" = "FAILOVER" ]
then
	echo "FAILOVER COUNT  : $CLP_FAILOVERCOUNT"
elif [ "$CLP_ACTION" = "FINALACTION" ]
then
	echo "FINAL ACTION"
else
	echo "NO_CLP"
fi

ip address | grep %%VMA1%%
if [ $? -eq 0 ]; then
	echo "Killing iSCSI-1"
	ssh %%ISCSI1%% "clplogcmd -m \"vMA#1 kills iSCSI#1\" --alert --syslog -l ERROR; clpdown -r"
fi
ip address | grep %%VMA2%%
if [ $? -eq 0 ]; then
	echo "Killing iSCSI-2"
	ssh %%ISCSI2%% "clplogcmd -m \"vMA#2 kills iSCSI#2\" --alert --syslog -l ERROR; clpdown -r"
fi

echo "EXIT"
exit 0
