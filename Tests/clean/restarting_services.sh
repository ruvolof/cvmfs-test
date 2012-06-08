/etc/init.d/cvmfs start
/etc/init.d/cvmfs restartclean
/etc/init.d/autofs stop
killall -9 automount
/etc/init.d/autofs start
