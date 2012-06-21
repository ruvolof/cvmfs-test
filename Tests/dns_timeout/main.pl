use strict;
use warnings;
use ZeroMQ qw/:all/;
use Functions::File qw(recursive_mkdir);
use Functions::FIFOHandle qw(open_wfifo close_fifo);
use Tests::Common qw (get_daemon_output killing_services check_repo);
use File::Find;
use File::Copy;
use Getopt::Long;
use FindBin qw($Bin);

# Folders where to extract the repo and document root for httpd
my $tmp_repo = '/tmp/server/repo/';
my $repo_pub = $tmp_repo . 'pub';

# Variables for GetOpt
my $outputfile = '/var/log/cvmfs-test/faulty_proxy.out';
my $errorfile = '/var/log/cvmfs-test/faulty_proxy.err';
my $no_clean = undef;

# Socket path and socket name. Socket name is set to let the server to select
# the socket where to send its response.
my $socket_protocol = 'ipc://';
my $socket_path = '/tmp/server.ipc';
my $testname = 'DNS_TIMEOUT';


# Variables used to record tests result. Set to 1 by default, will be changed
# to 0 if the test will fail.
my ($mount_successful, $server_timeout, $proxy_timeout) = (0, 0, 0);

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
	open (my $errfh, '>', $errorfile) || die "Couldn't open $errorfile: $!\n";
	STDERR->fdopen ( \*$errfh, 'w' ) || die "Couldn't set STDERR to $errorfile: $!\n";
	open (my $outfh, '>', $outputfile) || die "Couldn't open $outputfile: $!\n";
	STDOUT->fdopen( \*$outfh, 'w' ) || die "Couldn't set STDOUT to $outputfile: $!\n";

	# Opening the socket to communicate with the server and setting is identity.
	print 'Opening the socket to communicate with the server... ';
	my $ctxt = ZeroMQ::Context->new();
	my $socket = $ctxt->socket(ZMQ_DEALER);
	my $setopt = $socket->setsockopt(ZMQ_IDENTITY, $testname);
	$socket->connect( "${socket_protocol}${socket_path}" );
	print "Done.\n";

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
	
	# Stop to comment from here since print statement are self explanatory.
	
	print "Creating directory $tmp_repo... ";
	recursive_mkdir($tmp_repo);
	print "Done.\n";

	print "Extracting the repository... ";
	system("tar -xzf Tests/Common/repo/pub.tar.gz -C $tmp_repo");
	print "Done.\n";
	
	print 'Creating RSA key... ';
	system("Tests/Common/creating_rsa.sh");
	print "Done.\n";
	
	print 'Signing files... ';
	my @files_to_sign;
	my $select = sub {
	if ($File::Find::name =~ m/\.cvmfspublished/){
			push @files_to_sign,$File::Find::name;
		}
	};
	find( { wanted => $select }, $repo_pub );
	foreach (@files_to_sign) {
		copy($_,"$_.unsigned");
		system("Tests/Common/cvmfs_sign-linux32.crun -c /tmp/cvmfs_test.crt -k /tmp/cvmfs_test.key -n mytestrepo.cern.ch $_");		
	}
	copy('/tmp/whitelist.test.signed', "$repo_pub/catalogs/.cvmfswhitelist");
	print "Done.\n";
	
	print 'Configurin RSA key for cvmfs... ';
	system("Tests/Common/configuring_rsa.sh");
	copy('/tmp/whitelist.test.signed', "$repo_pub/catalogs/.cvmfswhitelist");
	print "Done.\n";

	print 'Creating resolv.conf backup... ';
	my $resolv_temp = `mktemp /tmp/resolv_XXXXXX` || die "Couldn't backup /etc/resolv.conf: $!\n.";
	system("sudo cat /etc/resolv.conf > $resolv_temp");
	print "Done.\n";

	print 'Overwriting resolv.conf... ';
	system('sudo bash -c "echo \"[127.0.0.1]:5300\" > /etc/resolv.conf"');
	print "Done.\n";

	print 'Configuring cvmfs... ';
	system("sudo $Bin/config_cvmfs.sh");
	print "Done.\n";
	
	print '-'x30 . "\n";
	print "Starting services for mount_successfull test...\n";
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080");
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	$socket->send('webproxy --port 3128');
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	$socket->send('named --port 5300 --add mytestrepo.cern.ch=127.0.0.1');
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	print "Done.\n";

	# For this first test, we should be able to mount the repo. So, if possibile, setting its variable
	# to 1.
	if (check_repo('/cvmfs/mytestrepo.cern.ch')){
	    $mount_successful = 1;
	}

	@pids = killing_services($socket, @pids);

	print 'Restarting services... ';
	system("sudo $Bin/restarting_services.sh >> /dev/null 2>&1");
	print "Done.\n";

	print '-'x30 . "\n";
	print "Starting services for proxy_timeout test...\n";
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080");
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	$socket->send('webproxy --port 3128');
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	$socket->send('named --port 5300 --add mytestrepo.cern.ch=127.0.0.1 --timeout');
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	print "Done.\n";

	# For this test, we shouldn't be able to mount the repo. If possibile, setting its variable
	# to 1.
	if (check_repo('/cvmfs/mytestrepo.cern.ch')){
	    $proxy_timeout = 1;
	}

	@pids = killing_services($socket, @pids);

	print 'Restarting services... ';
	system("sudo $Bin/restarting_services.sh >> /dev/null 2>&1");
	print "Done.\n";
	
	print '-'x30 . 'SERVER_TIMEOUT' . '-'x30 . "\n";
	print 'Configuring cvmfs without proxy... ';
	system("sudo $Bin/config_cvmfs_noproxy.sh");
	print "Done.\n";

	print "Starting services for server_timeout test...\n";
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080");
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	$socket->send('webproxy --port 3128');
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	$socket->send('named --port 5300 --add mytestrepo.cern.ch=127.0.0.1 --timeout');
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	print "All services started.\n";

	# For this test, we shouldn't be able to mount the repo. If possibile, setting its variable
	# to 1.
	if (check_repo('/cvmfs/mytestrepo.cern.ch')){
	    $server_timeout = 1;
	}

	@pids = killing_services($socket, @pids);

	print 'Restarting services... ';
	system("sudo $Bin/restarting_services.sh >> /dev/null 2>&1");
	print "Done.\n";

	# We're sending output to the shell through a FIFO.
	print 'Sending status to the shell... ';
	my $outputfifo = open_wfifo('/tmp/returncode.fifo');
	if ($mount_successful == 1) {
	    print $outputfifo "Able to mount the repo with right configuration... OK.\n";
	}
	else {
	    print $outputfifo "Unable to mount the repo with right configuration... WRONG.\n";
	}
	if ($proxy_timeout == 1) {
	    print $outputfifo "Able to mount the repo with proxy timeout configuration... WRONG.\n";
	}
	else {
	    print $outputfifo "Unable to mount the repo with proxy timeout configuration... OK.\n";
	}
	if ($server_timeout == 1) {
	    print $outputfifo "Able to mount repo with server timeout configuration... WRONG.\n";
	}
	else {
	    print $outputfifo "Unable to mount the repo with server timeout configuration... OK!\n";
	}
	close_fifo($outputfifo);
	print "Done.\n";		
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
