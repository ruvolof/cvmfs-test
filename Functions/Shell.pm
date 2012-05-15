package Functions::Shell;

#######################################
# Here will be store all the functions that will be used to change shell behaviour
# and environment
#######################################

use strict;
use warnings;
use Functions::Help qw(help);
use Proc::Spawn;
use Fcntl ':mode';
use Functions::Setup qw(setup);

# Next lines are needed to export subroutines to the main package
use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw(check_daemon check_command start_daemon);

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

# This function will check whether the daemon is running.
sub check_daemon {
	my $running = `ps -ef | grep cvmfs-testdwrapper | grep -v grep | grep -v defunct`;
	return $running;
}

# This function is used to check if the command typed has to be ran by the shell
# or by the daemon. If the command is bundled in the shell, it launches the
# corresponding function.
sub check_command {
	# Retrieving arguments: command
	my $command = shift;
	
	# Variables to memorize if the command was found and executed
	my $executed = 0;
	
	# Switching the value of $command
	for ($command){
		if ($_ eq 'exit' or $_ eq 'quit' or $_ eq 'q') { exit 0 }
		elsif ($_ eq 'status') { print_status(); $executed = 1 }
		elsif ($_ eq 'start' ) { start_daemon(); $executed = 1 }
		elsif ($_ =~ m/^help\s*.*/ or $_ =~ m/^h\s.*/) { help($command), $executed = 1 }
		elsif ($_ eq 'setup') { setup(); $executed = 1 }
	}
	
	# If the daemon is not running and no command was executed, print on screen a message
	# saying that the command was not found
	if(!check_daemon and !$executed){
		print "Command not found. Type 'help' for a list of available commands.\n";
	}
	
	# Returning the value of $executed to check if the command was found and executed
	return $executed;
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

# This functions will check that file permission are set
sub check_permission {
	my ($user, $suid, $owner);
	# Checking if the user exists in the system
	$user = `cat /etc/passwd | grep cvmfs-test`;
	
	# Checking if the user own the daemon file
	if (-e "$Bin/cvmfs-testdwrapper"){
		my $uid = (stat("$Bin/cvmfs-testdwrapper"))[4];
		$owner = (getpwuid($uid))[0];
	}
	else {
		$owner = 0;
	}
	
	# Checking if the file has the setuid bit
	if (-e "$Bin/cvmfs-testdwrapper") {
		my $mode = (stat("$Bin/cvmfs-testdwrapper"))[2];
		$suid = $mode & S_ISUID;
	}
	else {
		$suid = 0;
	}
	
	# Return true only if all conditions are true
	if ($user and $owner eq "cvmfs-test" and $suid){
		return 1;
	}
	else {
		return 0;
	}
}

# This function will start the daemon if it's not already running
sub start_daemon {
	if (!check_daemon()){
		if(check_permission()){
			my ($daempid, $daemin, $daemout, $daemerr);
			print 'Starting daemon...';
			($daempid, $daemin, $daemout, $daemerr) = spawn($Bin . '/cvmfs-testdwrapper ' . $Bin . '/cvmfs-testd.pl');
			print "Done.\n";
		}
		else {
			print "Wrong permission on important files. Did you run 'setup'?\n";
		}
	}
	else {
		print "Daemon is already running. Cannot run another instance.\n";
	}
}

1;
