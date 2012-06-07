/sbin/service cvmfs start
/sbin/service cvmfs restartclean
/sbin/service autofs stop
killall -9 automount
/sbin/service autofs start
