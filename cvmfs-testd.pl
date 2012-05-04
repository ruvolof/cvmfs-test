use strict;
use warnings;
use POSIX qw(mkfifo);
use IO::Handle;
use Functions::Help;

# This two path will be used to store the FIFO for INPUT and OUTPUT
my $INPUT = '/tmp/cvmfs-testd-input';
my $OUTPUT = '/tmp/cvmfs-testd-output';

while(1) {
	# Here are created the two FIFO that will be used for INPUT and OUTPUT
	# I'm putting it inside a while so it will recreate them if something
	# accidentally erases them.
	unless ( -p $INPUT ) {
		unlink $INPUT;
		mkfifo($INPUT, 0766)
		|| die "Couldn't create $INPUT";
	}
	unless ( -p $OUTPUT ) {
		unlink $OUTPUT;
		mkfifo($OUTPUT, 0744)
		|| die "Couldn't create $OUTPUT";
	}
	
	# Here it opens the INPUT FIFO and set it as STDIN
	open(my $myinput, '<', $INPUT) || die "Couldn't open $INPUT";
	STDIN->fdopen( \*$myinput, 'r') || die "Couldn't set STDIN to $INPUT";
	
	# Here it opens the OUPUT FIFO
	open(my $myoutput, '>', $OUTPUT) || die "Couldn't open $OUTPUT";
	
	# Here it starts waiting for an input
	while( defined(my $line = <STDIN>)){
		# Here it starts processing the command
		print "Processing command: $line";
		
		# Deleting return at the end of the line
		chomp($line);
		
		# Splitting $line in an array depending on blank...
		my @words = split /[[:blank:]]/, $line;
		# ... first word will be the command...
		my $command = shift(@words);
		# ... everything else, if exist, are options.
		my @options = splice(@words, 0);
		
		# Switch on the value of command
		for($command){
			
			# Here is the HELP case
			if($_ eq 'help' or $_ eq 'h') { help($command, $myoutput, @options) }
			
			# Here is the EXIT case
			elsif($_ eq 'stop') { exit 0 }
			
			# Here is the KILL case
			elsif($_ eq 'kill') { kill_process(@options) }
		}
		
		close $myoutput;
		close $myinput;
	}
}
	

