use strict;
use warnings;
use Functions::FIFOHandle qw(make_fifo unlink_fifo print_to_fifo open_rfifo close_fifo);
use Tests::Common qw(set_stdout_stderr open_test_socket close_test_socket open_shellout_socket);
use ZeroMQ qw/:all/;
use File::Find;
use Getopt::Long;

# Variables for command line options
my $outputfile = '/var/log/cvmfs-test/do_all.out';
my $errorfile = '/var/log/cvmfs-test/do_all.err';
my $outputfifo = '/tmp/returncode.fifo';
my $no_clean = undef;

# Retrieving command line options
my $ret = GetOptions ( "stdout=s" => \$outputfile,
					   "stderr=s" => \$errorfile,
					   "fifo=s" => \$outputfifo,
					   "no-clean" => \$no_clean );
					   
# Test name used for socket identity
my $testname = 'DO_ALL';

# This function will wait on a FIFO for output test and will redirect this output
# on the FIFO where the shell is waiting for it.
sub send_test_output {
	# Retrieving FIFO path
	my $fifo = shift;
	# Retrieving socket path
	my $shell_socket = shift;
	
	# Will be set to 1 if more output lines are coming
	my $continue = 0;
	
	# Creating a FIFO. The shell will wait for some output there.
	make_fifo($fifo);
	my $return_fh = open_rfifo($fifo);

	while (my $return_line = $return_fh->getline) {
		if ($return_line eq "SNDMORE\n") {
			$continue = 1;
		}
		# Printing output in $outputfile for this test
		print $return_line unless $return_line eq "SNDMORE\n";
		# Sending output to the shell. I'm always sending it back with SNDMORE option.
		# I'll close the fifo definitely at the end of this test.
		$shell_socket->send($return_line) unless $return_line eq "SNDMORE\n" or $return_line eq "END\n";
	}
	close_fifo($return_fh);
	unlink_fifo($fifo);
	
	if ($continue) {
		send_test_output($fifo, $shell_socket);
	}
}

# Function to get daemon output and call the function to send test output to the shell.
# I'm not going to use the get_daemon_output from Tests::Common because
# this behaviour is specific to this test.
sub get_daemon_output {
	# Retrieving socket to use
	my $socket = shift;
	my $shell_socket = shift;
	
	my ($data, $reply) = ('', '');
	
	while ($data ne "END\n") {
		$reply = $socket->recv();
		$data = $reply->data;
		
		if ($data =~ m/PROCESSING/) {
			$shell_socket->send($data);
		}
		
		if ($data =~ m/READ_RETURN_CODE/) {
			my $fifo = (split /:/, $data)[-1];
			chomp($fifo);
			send_test_output($fifo, $shell_socket);
		}
		
		print $data if $data ne "END\n" and $data !~ m/READ_RETURN_CODE/;
	}
}

# Forking the process
my $pid = fork();

if (defined ($pid) and $pid == 0) {
	# Setting STDOUT and STDERR to file in log folder.
	set_stdout_stderr($outputfile, $errorfile);
	
	# Opening the socket to communicate with the daemon
	my ($socket, $ctxt) = open_test_socket($testname);
	
	# Opening the socket to send the output to the shell
	my ($shell_socket, $shell_ctxt) = open_shellout_socket();
	
	# Array to store every main.pl files
	my @main_pl;
	
	# This functions will select tests main.pl file
	my $select = sub {
		if ($File::Find::name =~ m/.*\/main.pl$/ and $File::Find::name !~ m/Auxiliary/) {
		print "Found: $File::Find::name\n";
		push @main_pl, $File::Find::name;
		}
	};
	find( { wanted => $select }, 'Tests/' );
	
	# Sending a command to the daemon for each main.pl file found to start different test
	foreach (@main_pl) {
		# Generating a random file name to pass it as --fifo options for all tests
		my $test_fifo = `mktemp /tmp/test_fifo.XXXXXX`;
		chomp($test_fifo);
		
		my $command = (split /\//, $_)[-2];
		$socket->send("$command --fifo $test_fifo");
		get_daemon_output($socket, $shell_socket);
	}
	
	$shell_socket->send("All tests processed.\n");
	$shell_socket->send("END\n");
	
	close_test_socket($socket, $ctxt);
	close_test_socket($shell_socket, $shell_ctxt);
}

# This will be ran by the main script.
# These lines will be sent back to the daemon and the damon will send them to the shell.
if (defined ($pid) and $pid != 0) {
	print "$testname will run all tests. It will take a long time\n";
	print "You can read its output in $outputfile.\n";
	print "Errors are stored in $errorfile.\n";
	print "PROCESSING:$testname\n";
	# This is the line that makes the shell waiting for test output.
	# Change whatever you want, but don't change this line or the shell will ignore exit status.
	print "READ_RETURN_CODE:$outputfifo\n";
}

exit 0;
