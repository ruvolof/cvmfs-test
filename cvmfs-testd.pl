#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw(mkfifo);
use IO::Handle;
use Functions::Help qw(help);
use Functions::Launcher qw(launch kill_process);
use Functions::FIFOHandle qw(open_rfifo open_wfifo close_fifo print_to_fifo);
use Functions::Testd qw(stop_daemon);

# These are the paths where FIFOs are stored
my $INPUT = '/tmp/cvmfs-testd-input.fifo';
my $OUTPUT = '/tmp/cvmfs-testd-output.fifo';

# Here are created the two FIFO that will be used for INPUT and OUTPUT
unless ( -p $INPUT ) {
	unlink $INPUT;
	mkfifo($INPUT, 0666)
	|| die "Couldn't create $INPUT";
}
unless ( -p $OUTPUT ) {
	unlink $OUTPUT;
	mkfifo($OUTPUT, 0666)
	|| die "Couldn't create $OUTPUT";
}

# Fixing permission on the FIFO, it seems umask prevent them to be set correctly
system("chmod 666 $INPUT");
system("chmod 666 $OUTPUT");

while(1) {
	# Here it opens the INPUT FIFO and set it as STDIN
	my $inputfh = open_rfifo($INPUT);
	STDIN->fdopen( \*$inputfh, 'r') || die "Couldn't set STDIN to $INPUT";
	# Here it starts waiting for an input
	while( defined(my $line = <STDIN>)){
		# Here it starts processing the command
		print "Processing command: $line ... ";
		
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
			if($_ eq 'help' or $_ eq 'h') { help($line) }
			
			# Here is the STOP case
			elsif($_ eq 'stop') { stop_daemon() }
			
			# Here is the KILL case
			elsif($_ eq 'kill') { kill_process(@options) }
			
			# The default case will try to launch the appropriate plugin
			else { launch($command, @options) }
		}
		
		# Logging the end of processing
		print "Done.\n";
		
		# Closing the input FIFO
		close_fifo($inputfh);
	}
}
	

