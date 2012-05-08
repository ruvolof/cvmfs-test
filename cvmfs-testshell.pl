use strict;
use warnings;
use POSIX qw(mkfifo);
use Proc::Spawn;
use Functions::Shell qw(check_daemon);

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

# These are the FIFOs used to communicate with the daemon
my $INPUT = '/tmp/cvmfs-testd-input.fifo';
my $OUTPUT = '/tmp/cvmfs-testd-output.fifo';

# A simple welcome.
print '#'x80 . "\n";
print "Welcome in the interactive shell of the CernVM-FS testing system.\n";
print "Type 'help' for a list of available commands.\n";
print '#'x80 . "\n";

# Variables to store daemon information
my ($daempid, $daemin, $daemout, $daemerr);

# If the daemon is not running, the shell will ask the use if run it
unless (check_daemon()) {
	print 'The daemon is not running. Would you like to run it now? [Y/n]';
	my $answer = <STDIN>;
	if($answer eq "\n" or $answer eq "Y\n"){
		print 'Starting daemon...';
		($daempid, $daemin, $daemout, $daemerr) = spawn('perl ' . $Bin . '/cvmfs-testd.pl');
		print "Done.\n";
	}
}

# Infinite loop for the shell. It will switch between two shells: the first one
# is the one used when the shell is connected to the daemon. The second one is used
# when the daemon is not running and will have less options available.
# Both shell terminates on exit.
while(1){
	# This is the first shell, the one used to communicate with the daemon
	while(check_daemon()){
		print '-> ';
		# Reading an input line.
		my $line = <STDIN>;
		chomp($line);
		
		# Checking if the command refer to the shell and not to the daemon
		if($line eq 'exit' or $line eq 'quit' or $line eq 'q') { exit 0 }
		
		# Opening the $INPUT FIFO to send commands to the daemon
		open(my $myinput, '>', $INPUT) || die "Couldn't open $INPUT";	
		# Sending the command
		print $myinput $line;
		# Closing the file
		close $myinput;
		
		# Opening the $OUTPUT FIFO to get the answer from the daemon
		open(my $myoutput, '<', $OUTPUT) || die "Couldn't open $OUTPUT";
		
		# Waiting for the answer and printing it
		while( defined(my $outputline = <$myoutput>)){
			print $outputline;
		}
		
		close $myoutput;
	}
	
	# This is the second shell, use when the daemon is closed
	while(!check_daemon()){
		exit 0;
	}
}
