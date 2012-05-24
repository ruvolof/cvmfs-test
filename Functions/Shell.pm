package Functions::Shell;

#######################################
# Here will be store all the functions that will be used to change shell behaviour
# and environment
#######################################

use strict;
use warnings;
use Functions::Help qw(help);
use Proc::Daemon;
use Fcntl ':mode';
use Getopt::Long;
use Functions::Setup qw(setup fixperm);

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
		elsif ($_ =~ m/^start\s*.*/ ) { start_daemon($command); $executed = 1 }
		elsif ($_ =~ m/^help\s*.*/ or $_ =~ m/^h\s.*/) { help($command), $executed = 1 }
		elsif ($_ eq 'setup' ) { setup(); $executed = 1 }
		elsif ($_ eq 'fixperm') { fixperm(); $executed = 1 }
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
	my ($user, $suid, $owner, $log_owner);
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
	
	# Checking if the log directory exists and the owner is cvmfs-test
	if ( -e '/var/log/cvmfs-test' ) {
		my $log_uid = (stat('/var/log/cvmfs-test'))[4];
		$log_owner = (getpwuid($log_uid))[0];
	}
	else {
		$log_owner = 0;
	}
	
	# Return true only if all conditions are true
	if ($user and $owner eq "root" and $suid and $log_owner eq 'cvmfs-test'){
		return 1;
	}
	else {
		return 0;
	}
}

# This function will start the daemon if it's not already running
sub start_daemon {
	if (defined (@_) and scalar(@_) > 0) {
		# Retrieving arguments
		my $line = shift;
		
		# Splitting $line in an array depending on blank...
		my @words = split /[[:blank:]]/, $line;
		# Everything else, if exist, are options.
		my @options = splice(@words, 1);
	
		# Setting ARGV to @options for GetOptions works properly
		@ARGV = @options;
	}
	
	# Setting default values for options
	my $daemon_output = '/var/log/cvmfs-test/daemon.output';
	my $daemon_error = '/var/log/cvmfs-test/daemon.error';
	
	if (!check_daemon()){
		if(check_permission()){				
			# Parsing options
			my $ret = GetOptions ( "stdout=s" => \$daemon_output,
								   "stderr=s" => \$daemon_error );								  
			
			my ($daempid, $daemin, $daemout, $daemerr);
			print 'Starting daemon...';
			my $daemonpid = Proc::Daemon::Init( { 
													work_dir => $Bin,
													pid_file => '/tmp/daemon.pid',
													child_STDOUT => $daemon_output,
													child_STDERR => $daemon_error,
													exec_command => "./cvmfs-testdwrapper ./cvmfs-testd.pl",
												} );
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
