use strict;
use warnings;
use POSIX qw(mkfifo);

# These are the FIFOs used to communicate with the daemon
my $INPUT = '/tmp/cvmfs-testd-input';
my $OUTPUT = '/tmp/cvmfs-testd-output';

# A simple welcome.
print '#'x80 . "\n";
print "Welcome in the interactive shell of the CernVM-FS testing system.\n";
print "Type 'help' for a list of available commands.\n";
print '#'x80 . "\n";

# Infinite loop for the shell. It will exit on "exit" command.
while(1){
	print '-> ';
	# Reading an input line.
	my $line = <STDIN>;
	
	# Opening the $INPUT FIFO to send commands to the daemon
	open(my $myinput, '>', $INPUT) || die "Couldn't open $INPUT";
	
	# Sending the command
	print $myinput $line;
	
	# Closing the file
	close $myinput;
	
	# Opening the $OUTPUT FIFO to get the answer from the daemon
	open(my $myoutput, '<', $OUTPUT) || die "Couldn't open $OUTPUT";
	
	# Waiting for the answer and printing it
	while( defined(my $line = <$myoutput>)){
		print $line;
	}
	
	close $myoutput;
}
