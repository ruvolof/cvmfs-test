use strict;
use warnings;
use ZeroMQ qw/:all/;
use Functions::File qw(recursive_mkdir);
use Functions::FIFOHandle qw(open_wfifo close_fifo);
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
my $socket_path = 'ipc:///tmp/server.ipc';
my $testname = 'FAULTY_PROXY';


# Variables used to record tests result. Set to 1 by default, will be changed
# to 0 if the test will fail.
my ($proxy_crap, $server_timeout, $mount_successful) = (0, 0, 0);

# Array to store PID of services. Every service will be killed after every test.
my @pids;

# Retrieving command line options
my $ret = GetOptions ( "stdout=s" => \$outputfile,
					   "stderr=s" => \$errorfile,
					   "no-clean" => \$no_clean );
#############
# FUNCTIONS #
#############
# Here you'll find function used in this test. Skip to MAIN if you want to follow
# execution flow.
#############

# This functions will wait for output from the daemon
sub get_daemon_output {
	# It needs to know the socket object to use
	my $socket = shift;
	my ($data, $reply) = '';
	# It will stop waiting for output when it receives the string "END\n"
	while ($data ne "END\n") {
		$reply = $socket->recv();
		$data = $reply->data;
		# Daemon will send data about PIDs od service started for this test.
		# This message will be formatted like 'SAVE_PID:PID', where PID is the part
		# that we have to save.
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
	print "Killing services...\n";
	
	# This chomp is necessary since the server would send the message with a carriage
	# return at the end. But we have to erase it if we want the daemon to correctly
	# recognize the command.
	foreach (@pids) {
		chomp($_);
	}
	
	# Joining PIDs in an unique string
	my $pid_list = join (' ', @pids);
	
	# Removing all elements fro @pids. This command will be called more than once during
	# the test. So we have to empty the arrays if don't want that sequent calling will try
	# to kill already killed services.
	undef @pids;
	
	# Sending the command.
	$socket->send("kill $pid_list");
	get_daemon_output($socket);
	print "Done.\n";
}

# This function will check if the repository is accessible, it will return 1 on success and 0 on failure.
# Remember that for two of our tests, success is failure and failure is success.
sub check_repo {
	my ($opened, $readdir, $readfile) = (undef, undef, undef);
	print "Trying to open and listing the directory...\n";
	
	# Opening the directory.
	$opened = opendir (my $dirfh, '/cvmfs/127.0.0.1');
	
	# Returning false if the directory was not open correctly
	unless ($opened){
	    print "Failed to open directory: $!.\n";
	    return 0;
	}
	
	# Reading the list of files.
	my @files = readdir $dirfh;
	
	# Returning false if the directory can't be read correctly.
	unless (@files) {
	    print "Failed to list directories: $!.\n";
	    return 0;
	}
	else {
		$readdir = 1;
	}
	
	# Printing all files in the directory.
	#print "Directory Listing:\n");
	foreach (@files) {
		print $_ . "\n";
	}
	
	# Opening a file.
	$readfile = open(my $filefh, "/cvmfs/127.0.0.1/$files[2]");
	
	# Returning false if the file can't be correctly read.
	unless ($readfile) {
		print "Failed to open file $files[2]: $!.\n";
		return 0;
	}
	
	print "File $files[2] content:\n";
	while (defined(my $line = $filefh->getline)) {
		print $line;
	}
	closedir($dirfh);
	
	# Returning true if all operation were done correctly.
	if ($readfile and $readdir and $opened) {
		print "Done.\n";
		return 1;
	}
	else {
		print "Done.\n";
		return 0;
	}
}

########
# MAIN #
########

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
	$socket->connect( $socket_path );
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
	
	print '-'x30 . "\n";
	print "Starting services for mount_successfull test...\n";
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080");
	get_daemon_output($socket);
	sleep 5;
	$socket->send("webproxy --port 3128 --backend http://localhost:8080");
	get_daemon_output($socket);
	sleep 5;	
	print "Services started.\n";

	# For this first test, we should be able to mount the repo. So, if not, setting its variable
	# to 0.
	if (check_repo()){
	    $mount_successful = 1;
	}

	killing_services($socket);

	print 'Restarting services... ';
	system("sudo $Bin/restarting_services.sh >> /dev/null 2>&1");
	print "Done.\n";

	print '-'x30 . "\n";
	print "Starting services for proxy_crap test...\n";
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080");
	get_daemon_output($socket);
	sleep 5;
	$socket->send("webproxy --port 3128 --deliver-crap --fail all");
	get_daemon_output($socket);
	sleep 5;
	print "Done.\n";

	# For this test, we shouldn't be able to mount the repo. If possibile, setting its variable
	# to 1.
	if (check_repo()){
	    $proxy_crap = 1;
	}

	killing_services($socket);

	print 'Restarting services... ';
	system("sudo $Bin/restarting_services.sh >> /dev/null 2>&1");
	print "Done.\n";
	
	print '-'x30 . "\n";
	print "Starting services for server_timeout test...\n";
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080 --timeout");
	get_daemon_output($socket);
	sleep 5;
	$socket->send("webproxy --port 3128 --backend http://localhost:8080");
	get_daemon_output($socket);
	sleep 5;
	print "All services started.\n";

	# For this test, we shouldn't be able to mount the repo. If possibile, setting its variable
	# to 1.
	if (check_repo()){
	    $server_timeout = 1;
	}

	killing_services($socket);

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

# This will be ran by the main script.
# These lines will be sent back to the daemon and the damon will send them to the shell.
if (defined ($pid) and $pid != 0) {
	print "FAULTY_PROXY test started.\n";
	print "You can read its output in $outputfile.\n";
	print "Errors are stored in $errorfile.\n";
	print "PROCESSING:FAULTY_PROXY\n";
	# This is the line that makes the shell waiting for test output.
	# Change whatever you want, but don't change this line or the shell will ignore exit status.
	print "READ_RETURN_CODE\n";
}

exit 0;
