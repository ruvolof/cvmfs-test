package Functions::Testd;

#########################################
# Here will be stored all the functions needed for the daemon's environement
# mantainance
#########################################

use strict;
use warnings;
use Functions::FIFOHandle qw(open_rfifo open_wfifo close_fifo print_to_fifo);

# Next lines are needed to export subroutine to the main package
use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw(stop_daemon);

# These are the paths where FIFOs are stored
my $INPUT = '/tmp/cvmfs-testd-input.fifo';
my $OUTPUT = '/tmp/cvmfs-testd-output.fifo';

# This function will remove the two FIFO, it must be launched as the last command.
sub remove_fifo {
	if (-e $INPUT){
		print '\nDeleting input FIFO... ';
		unlink $INPUT;
		print "Done.\n";
	}
	if (-e $OUTPUT){
		print 'Deleting output FIFO... ';
		unlink $OUTPUT;
		print "Done.\n";
	}
}

# This functions is called when the daemon gets the 'stop' command. It launches
# some cleaning functions and exit.
sub stop_daemon {
	print_to_fifo ($OUTPUT, "Deamon stopped.\n");
	
	# Removing the FIFO. Do it only when you're sure you don't have any more output to send.
	remove_fifo();
	
	print "Daemon stopped.\n";
	exit 0;
}
