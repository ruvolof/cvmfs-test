#!/bin/bash
#
# This script will contextualize a Cern Virtual Machine.

SHELLPATH="TO_EDIT"
CPS="/root/current_shell_path.txt"
CONTEXTSH="/root/context.sh"
RCLOCAL=`grep context.sh /etc/rc.local`

if [ ! -f $CONTEXTSH ] ; then
	wget -O $CONTEXTSH https://github.com/ruvolof/cvmfs-test/blob/master/Distributed/context.sh
fi

if [ $RCLOCAL == "" ] ; then
	echo "/root/context.sh" >> /etc/rc.local
fi

echo $SHELLPATH > /root/current_shell_path
