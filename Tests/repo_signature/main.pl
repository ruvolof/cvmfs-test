use strict;
use warnings;
use ZeroMQ qw/:all/;
use Functions::FIFOHandle qw(open_wfifo close_fifo);
use Tests::Common qw(get_daemon_output killing_services check_repo setup_environment restart_cvmfs_services);
use File::Copy;
use File::Find;
use Getopt::Long;
use FindBin qw($Bin);

# Folders where to extract the repo and document root for httpd
my $tmp_repo = '/tmp/server/repo/';
my $repo_pub = $tmp_repo . 'pub';

# Variables for GetOpt
my $outputfile = '/var/log/cvmfs-test/repo_signature.out';
my $errorfile = '/var/log/cvmfs-test/repo_signature.err';
my $no_clean = undef;

# Socket path and socket name. Socket name is set to let the server to select
# the socket where to send its response.
my $socket_protocol = 'ipc://';
my $socket_path = '/tmp/server.ipc';
my $testname = 'REPO_SIGNATURE';

# Name for the cvmfs repository
my $repo_name = '127.0.0.1';

# Variables used to record tests result. Set to 0 by default, will be changed
# to 1 if it will be able to mount the repo.
my ($mount_successful, $garbage_cvmfspublished, $broken_signature, $garbage_datachunk, $garbage_zlib) = (0, 0, 0, 0, 0);

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
	# Setting autoflush for STDOUT to read its output in real time
	STDOUT->autoflush;
	
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
	
	# Common test setup
	setup_environment($tmp_repo, $repo_name);
	
	# Configuring cvmfs for the first two tests.
	print 'Configuring cvmfs... ';
	system("sudo $Bin/config_cvmfs.sh");
	print "Done.\n";
	
	# For this testcase I'm not going to kill https for each test as long as I need it
	# with the same configuration for all tests. Restarting cvmfs will be enough.
	print "Starting services for mount_successfull test...\n";
	$socket->send("httpd --root $repo_pub --index-of --all --port 8080");
	@pids = get_daemon_output($socket, @pids);
	sleep 5;
	print "Services started.\n";
	
	print '-'x30 . 'MOUNT_SUCCESSFUL' . '-'x30 . "\n";
	# For this first test, we should be able to mount the repo. So, if possible, setting its variable
	# to 1.
	if (check_repo("/cvmfs/$repo_name")){
	    $mount_successful = 1;
	}

	restart_cvmfs_services();
	
	print '-'x30 . 'GARBAGE_CVMFSPUBLISHED' . '-'x30 . "\n";
	my $published = $repo_pub . '/catalogs/.cvmfspublished';
	print "Creating $published backup... ";
	copy($published, "$published.bak");
	print "Done.\n";
	print "Creating a corrupted $published... ";
	my $deleted = unlink($published);
	unless($deleted) {
		print "Impossibile to delete $published: $!.\n";
	}
	# Creating a .cvmfspublished with random values.
	open(my $cvmfs_pub_fh, '>', $published);
	my $random = rand(100);
	print $cvmfs_pub_fh "$random\n"x100;
	close $cvmfs_pub_fh;
	
	# For this second test, we should not be able to mount the repo. If possible, setting its variable
	# to 1.
	if (check_repo("/cvmfs/$repo_name")){
	    $garbage_cvmfspublished = 1;
	}
	
	print "Restoring $published... ";
	unlink($published);
	copy("$published.bak", $published);

	restart_cvmfs_services();
	
	print '-'x30 . 'GARBAGE_DATACHUNK' . '-'x30 ."\n";
	print 'Retrieving files... ';
	my @file_list;
	my $select_files = sub {
		push @file_list,$File::Find::name if -f $File::Find::name;
	};
	find( { wanted => $select_files }, "$repo_pub/data" );
	foreach (@file_list) {
		my $digit = int(rand(10));
		(my $newname = $_) =~ s/.$/$digit/;
		move($_, $newname);
	}
	
	# For this third test, we should not be able to mount the repo. If possible, setting its variable
	# to 1.
	if (check_repo("/cvmfs/$repo_name")){
	    $garbage_datachunk = 1;
	}
	
	restart_cvmfs_services();
	
	
	# We're sending output to the shell through a FIFO.
	print 'Sending status to the shell... ';
	my $outputfifo = open_wfifo('/tmp/returncode.fifo');
	if ($mount_successful == 1) {
	    print $outputfifo "Able to mount the repo with right configuration... OK.\n";
	}
	else {
	    print $outputfifo "Unable to mount the repo with right configuration... WRONG.\n";
	}
	if ($garbage_cvmfspublished == 1) {
	    print $outputfifo "Able to mount the repo with garbage .cvmfspublished... WRONG.\n";
	}
	else {
	    print $outputfifo "Unable to mount the repo with garbage .cvmfspublished... OK.\n";
	}
	if ($garbage_datachunk == 1) {
	    print $outputfifo "Able to mount the repo with garbage datachunk... WRONG.\n";
	}
	else {
	    print $outputfifo "Unable to mount the repo with garbage datachunk... OK.\n";
	}
	close_fifo($outputfifo);
	print "Done.\n";
}

# This will be ran by the main script.
# These lines will be sent back to the daemon and the damon will send them to the shell.
if (defined ($pid) and $pid != 0) {
	print "REPO_SIGNATURE test started.\n";
	print "You can read its output in $outputfile.\n";
	print "Errors are stored in $errorfile.\n";
	print "PROCESSING:REPO_SIGNATURE\n";
	# This is the line that makes the shell waiting for test output.
	# Change whatever you want, but don't change this line or the shell will ignore exit status.
	print "READ_RETURN_CODE\n";
}

exit 0;
