use strict;
use warnings;
use ZeroMQ qw/:all/;
use Functions::FIFOHandle qw(print_to_fifo);
use Tests::Common qw (set_stdout_stderr get_daemon_output killing_services check_repo setup_environment restart_cvmfs_services check_mount_timeout open_test_socket close_test_socket);
use Getopt::Long;
use FindBin qw($Bin);

# Folders where to extract the repo and document root for httpd
my $tmp_repo = '/tmp/server/repo/';
my $repo_pub = $tmp_repo . 'pub';

# Variables for GetOpt
my $outputfile = '/var/log/cvmfs-test/ipv6_fallback.out';
my $errorfile = '/var/log/cvmfs-test/ipv6_fallback.err';
my $no_clean = undef;

# Test name used for output and socket identity
my $testname = 'IPV6_FALLBACK';

# Repository name
my $repo_name = 'mytestrepo.cern.ch';


# Variables used to record tests result. Set to 0 by default, will be changed
# to 1 for mount_successful if the test succed and to seconds needed for timeout
# for the other two tests.
my ($ipv6_only, $ipv4_fallback) = (0, 0);

# FIFO for output
my $outputfifo = '/tmp/returncode.fifo';

# Array to store PID of services. Every service will be killed after every test.
my @pids;

# Retrieving command line options
my $ret = GetOptions ( "stdout=s" => \$outputfile,
					   "stderr=s" => \$errorfile,
					   "no-clean" => \$no_clean );


# Forking the process so the daemon can come back in listening mode.
my $pid = fork();

# This will be ran only by the forked process. Everything here will be logged in a file and
# will not be sent back to the daemon.
if (defined ($pid) and $pid == 0) {
	# Setting STDOUT and STDERR to file in log folder.
	set_stdout_stderr($outputfile, $errorfile);

	# Opening the socket to communicate with the server and setting is identity.
	my ($socket, $ctxt) = open_test_socket($testname);
	
	# Cleaning the environment if --no-clean is undef.
	# See 'Tests/clean/main.pl' if you want to know what this command does.
	if (!defined($no_clean)) {
		print "\nCleaning the environment:\n";
		$socket->send("clean");
		get_daemon_output($socket);
		sleep 5;
	}
	else {
		print "\nSkipping cleaning.\n";
	}
	
	# Common test setup
	setup_environment($tmp_repo, $repo_name);

	# Creating /etc/resolv.conf backup
	print 'Creating resolv.conf backup... ';
	my $resolv_temp = `mktemp /tmp/resolv_XXXXXX` || die "Couldn't backup /etc/resolv.conf: $!\n.";
	chomp($resolv_temp);
	system("sudo cat /etc/resolv.conf > $resolv_temp");
	print "Done.\n";

	# Overwriting /etc/resolv.conf with an empty file to avoid that the system complains about
	# dns answer arriving from a different host than the one expected.
	print 'Overwriting resolv.conf... ';
	system('sudo bash -c "echo \"\" > /etc/resolv.conf"');
	print "Done.\n";
	
	# Saving iptables rules
	print 'Creating iptables rules backup... ';
	system('sudo /etc/init.d/iptables save > /dev/null 2>&1');
	print "Done.\n";
	
	# Adding iptables rules to redirect any dns request to non-standard port 5300
	print 'Adding iptables rules... ';
	system('sudo /sbin/iptables -t nat -A OUTPUT -p tcp --dport domain -j DNAT --to-destination 127.0.0.1:5300');
	system('sudo /sbin/iptables -t nat -A OUTPUT -p udp --dport domain -j DNAT --to-destination 127.0.0.1:5300');
	print "Done.\n";

	# Configuring cvmfs
	print 'Configuring cvmfs... ';
	system("sudo $Bin/config_cvmfs.sh");
	print "Done.\n";

	print '-'x30 . 'IPV6_ONLY' . '-'x30 . "\n";
	print "Starting services for mount_successfull test...\n";
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080");
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	$socket->send('named --port 5300 --add-ipv6 mytestrepo.cern.ch=::1');
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	print "Done.\n";

	# For this first test, we should be able to mount the repo. So, if possibile, setting its variable
	# to 1.
	if (check_repo("/cvmfs/$repo_name")){
	    $ipv6_only = 1;
	}
	
	if ($ipv6_only == 1) {
	    print_to_fifo($outputfifo, "Able to mount the repo with ipv6... OK.\n", 'SNDMORE');
	}
	else {
	    print_to_fifo($outputfifo, "Unable to mount the repo with ipv6... WRONG.\n", 'SNDMORE');
	}

	@pids = killing_services($socket, @pids);

	restart_cvmfs_services();

	print '-'x30 . 'IPV4_FALLBACK' . '-'x30 . "\n";
	print "Starting services for proxy_timeout test...\n";
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080");
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	$socket->send("named --port 5300 --add-ipv6 $repo_name=::10 --add $repo_name=127.0.0.1 ");
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	print "Done.\n";

	if (check_repo("/cvmfs/$repo_name") {
		$ipv4_fallback = 1;
	}
	
	if ($ipv4_fallback == 1) {
	    print_to_fifo($outputfifo, "Able to mount the repo with wrong ipv6 and good ipv4... OK.\n");
	}
	else {
	    print_to_fifo($outputfifo, "Unable to mount the repo with wrong ipv6 and good ipv4... WRONG.\n");
	}	

	@pids = killing_services($socket, @pids);

	restart_cvmfs_services();
	
	# Restoring resolv.conf
	print 'Restoring resolv.conf backup... ';
	system("sudo cp $resolv_temp /etc/resolv.conf");
	print "Done.\n";
	
	# Restarting iptables, it will load previously saved rules
	print 'Restoring iptables rules... ';
	system('sudo /etc/init.d/iptables restart > /dev/null 2>&1');
	print "Done.\n";
	
	# Closing socket
	close_test_socket($socket, $ctxt);
}

# This will be ran by the main script.
# These lines will be sent back to the daemon and the damon will send them to the shell.
if (defined ($pid) and $pid != 0) {
	print "DNS_TIMEOUT test started.\n";
	print "You can read its output in $outputfile.\n";
	print "Errors are stored in $errorfile.\n";
	print "PROCESSING:DNS_TIMEOUT\n";
	# This is the line that makes the shell waiting for test output.
	# Change whatever you want, but don't change this line or the shell will ignore exit status.
	print "READ_RETURN_CODE\n";
}

exit 0;
