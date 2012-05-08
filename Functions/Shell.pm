package Functions::Shell;

#######################################
# Here will be store all the functions that will be used to change shell behaviour
# and environment
#######################################

use strict;
use warnings;

# Next lines are needed to export subroutines to the main package
use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw(check_daemon);

# This function will check wether the daemon is running.
sub check_daemon {
	my $running = `ps -ef | grep cvmfs-testd.pl | grep -v grep`;
	return $running;
}

# This function is used to check if the command typed has to be ran by the shell
# or by the daemon. If the command is bundled in the shell, it launches the
# corresponding function.
sub check_command {
	# Retrieving arguments: command
	$command = shift;
	
	# Switching the value of $command
	for ($command){
		if ($_ eq 'exit' or $_ eq 'quit' or $_ eq 'q') { exit 0 }
		elsif ($_ eq 'status') { print_status() }
		elsif ($_ eq 'start' ) { start_daemon() }
	}
}

# This function will print the current status of the daemon
sub print_status {
	if(check_daemon){
		print "Daemon is running.\n";
	}
	else {
		print "The daemon is not running. Type 'start' to run it.\n";
	}
}

# This function will start the daemon if it's not already running
sub start_daemon {
	my 
	print 'Starting daemon...';
	($daempid, $daemin, $daemout, $daemerr) = spawn('perl ' . $Bin . '/cvmfs-testd.pl');
	print "Done.\n";
}
