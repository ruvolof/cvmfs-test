use strict;
use warnings;
use ZeroMQ qw/:all/;
use Functions::File qw(recursive_mkdir);
use Functions::FIFOHandle qw(open_wfifo close_fifo);
use File::Find;
use File::Copy;
use Getopt::Long;
use FindBin qw($Bin);

my $tmp_repo = '/tmp/server/repo/';
my $repo_pub = $tmp_repo . 'pub';
my $outputfile = '/var/log/cvmfs-test/faulty_proxy.out';
my $errorfile = '/var/log/cvmfs-test/faulty_proxy.err';
my $socket_path = 'ipc:///tmp/server.ipc';
my $testname = 'FAULTY_PROXY';
my $no_clean = undef;

# Variables used to record tests result
my ($proxy_crap, $server_timeout, $mount_successful) = (1, 1, 1);

# Array to store PID of services.
my @pids;

# This functions will wait for output from the daemon
sub get_daemon_output {
	my $socket = shift;
	my ($data, $reply) = '';
	while ($data ne "END\n") {
		$reply = $socket->recv();
		$data = $reply->data;
		if ($data =~ m/SAVE_PID/) {
		    my $pid = (split /:/, $data)[-1];
		    push @pids,$pid;
		}
		print $data if $data ne "END\n" and $data !~ m/SAVE_PID/;
	}
}

# This function will kill all services started, so it can start new processes on the same ports
sub killing_services {
	# Retrieving socket handler
	my $socket = shift;
	print 'Killing services... ';
	foreach (@pids) {
		chomp($_);
	}
	my $pid_list = join (' ', @pids);
	undef @pids;
	$socket->send("kill $pid_list");
	get_daemon_output($socket);
	print "Done.\n";
}

# Retrieving command line options
my $ret = GetOptions ( "stdout=s" => \$outputfile,
					   "stderr=s" => \$errorfile,
					   "no-clean" => \$no_clean );

# Forking the process. Only some little line of output will be sent back to the daemon.
my $pid = fork();

if (defined ($pid) and $pid == 0) {
	open (my $errfh, '>', $errorfile) || die "Couldn't open $errorfile: $!\n";
	STDERR->fdopen ( \*$errfh, 'w' ) || die "Couldn't set STDERR to $errorfile: $!\n";
	open (my $outfh, '>', $outputfile) || die "Couldn't open $outputfile: $!\n";
	STDOUT->fdopen( \*$outfh, 'w' ) || die "Couldn't set STDOUT to $outputfile: $!\n";

	print 'Opening the socket to communicate with the server... ';
	my $ctxt = ZeroMQ::Context->new();
	my $socket = $ctxt->socket(ZMQ_DEALER);
	my $setopt = $socket->setsockopt(ZMQ_IDENTITY, $testname);
	$socket->connect( $socket_path );
	print "Done.\n";

	# Cleaning the environment if --no-clean is undef
	if (!defined($no_clean)) {
		print "\nCleaning the environment:\n";
		$socket->send("clean");
		get_daemon_output($socket);
		sleep 5;
	}
	else {
		print "\nSkipping cleaning.\n";
	}
	
	print "Creating directory $tmp_repo... ";
	recursive_mkdir($tmp_repo);
	print "Done.\n";

	print "Extracting the repository... ";
	system("tar -xzf $Bin/repo/pub.tar.gz -C $tmp_repo");
	print "Done.\n";
	
	print 'Creating RSA key... ';
	system("$Bin/creating_rsa.sh");
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
		system("$Bin/cvmfs_sign-linux32.crun -c /tmp/cvmfs_test.crt -k /tmp/cvmfs_test.key -n 127.0.0.1 $_");		
	}
	copy('/tmp/whitelist.test.signed', "$repo_pub/catalogs/.cvmfswhitelist");
	print "Done.\n";
	
	print 'Configurin RSA key for cvmfs... ';
	system("$Bin/configuring_rsa.sh");
	copy('/tmp/whitelist.test.signed', "$repo_pub/catalogs/.cvmfswhitelist");
	print "Done.\n";
	
	print 'Configuring cvmfs... ';
	system("sudo $Bin/config_cvmfs.sh");
	print "Done.\n";
	
	print 'Creating faulty file... ';
	open (my $faultyfh, '>', '/tmp/cvmfs.faulty') or die "Couldn't create /tmp/cvmfs.faulty: $!\n";
	print $faultyfh 'A'x1024x10;
	print "Done.\n";
	
	print '-'x30;
	print "Starting services for mount_successfull test... \n";
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080");
	get_daemon_output($socket);
	sleep 5;
	$socket->send("webproxy --port 3128 --backend http://localhost:8080");
	get_daemon_output($socket);
	sleep 5;	
	print "Services started.\n";

	print "Trying to open and listing the directory...";
	my $opened = opendir (my $dirfh, '/cvmfs/127.0.0.1');
	unless ($opened){
	    $mount_successful = 0;
	}
	my @files = readdir $dirfh;
	unless (@files) {
	    $mount_successful = 0;
	}
	closedir($dirfh);
	print "Done.\n";

	killing_services($socket);

	print '-'x30;
	print 'Starting services for proxy_crap test... ';
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080");
	get_daemon_output($socket);
	sleep 5;
	$socket->send("webproxy --port 3128 --deliver-crap --fail all");
	get_daemon_output($socket);
	sleep 5;
	print "Done.\n";

	print "Trying to open and listing the directory...";
	$opened = opendir ($dirfh, '/cvmfs/127.0.0.1');
	if ($opened){
	    $proxy_crap = 0;
	}
	my @files_crap = readdir $dirfh;
	if (@files_crap) {
	    $proxy_crap = 0;
	}
	closedir($dirfh);
	print "Done.\n";

	killing_services($socket);
	
	print '-'x30;
	print 'Starting services for server_timeout test... ';
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080 --timeout");
	get_daemon_output($socket);
	sleep 5;
	$socket->send("webproxy --port 3128 --backend http://localhost:8080");
	get_daemon_output($socket);
	sleep 5;
	print "All services started.\n";

	print "Trying to open and listing the directory...";
	$opened = opendir ($dirfh, '/cvmfs/127.0.0.1');
	if ($opened){
	    $server_timeout = 0;
	}
	my @files_timeout = readdir $dirfh;
	if (@files_timeout) {
	    $server_timeout = 0;
	}
	closedir($dirfh);
	print "Done.\n";

	killing_services($socket);

	print 'Sending status to the shell... ';
	my $outputfifo = open_wfifo('/tmp/returncode.fifo');
	if ($mount_successful == 1) {
	    print $outputfifo "Able to mount the repo with right configuration... OK.\n";
	}
	else {
	    print $outputfifo "Unable to mount the repo with right configuration... WRONG.\n";
	}
	if ($proxy_crap == 1) {
	    print $outputfifo "Able to mount the repo with faulty proxy configuration... WRONG.\n";
	}
	else {
	    print $outputfifo "Unable to mount the repo with faulty proxy configuration... OK.\n";
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

if (defined ($pid) and $pid != 0) {
	print "FAULTY_PROXY test started.\n";
	print "You can read its output in $outputfile.\n";
	print "Errors are stored in $errorfile.\n";
	print "PROCESSING:FAULTY_PROXY\n";
	print "READ_RETURN_CODE\n";
}

exit 0;
