package Functions::Setup;

####################################################
# Here will be stored all the functions needed to setup the environment
# for the daemon
####################################################

use strict;
use warnings;
use Fcntl ':mode';
use Functions::Shell qw(check_daemon);

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

# Next lines are needed to export subroutines to the main package
use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw(setup);

sub setup {
	if (!Functions::Shell::check_daemon()){
		print "You will need to be in the sudoers file to complete the setup process. Are you? [N,y]";
		my $answer = <STDIN>;
		
		# Variables to record success and failure
		my ($compile_success, $user_added, $wrapper_chown, $wrapper_setuid);
		
		# The setup process will start only if the user states he is able to perform sudo commands
		if ($answer eq "y\n" or $answer eq "Y\n"){
			$compile_success = compile_wrapper();
			
			# If the wrapper was successfully compiled, creating the user for the wrapper
			if ($compile_success){
				$user_added = create_user();
				
				# If the user was successfully created, chowning the programm
				if ($user_added) {
					$wrapper_chown = chown_wrapper();
					
					# If the wrapper is owned by the user cvmfs-test, setuid on the wrapper
					$wrapper_setuid = setuid_wrapper();
				}
			}
		}
	}
	else {
		print "The daemon is running. Can't run setup while the daemon is running. Stop it and retry.\n";
	}
}

# This function will try to compile the c wrapper for the script. It will return 1 on success and 0 on failure.
sub compile_wrapper {
	if (-e '/usr/bin/gcc') {
		print "Compiling the wrapper... \n";
		my $compile = system("/usr/bin/gcc -o $Bin/cvmfs-testdwrapper $Bin/cvmfs-testdwrapper.c");
		if ($compile == -1){
			print "FAILED: $!\n";
			return 0;
		}
		else {
			print ("Done.\n");
			return 1;
		}
	}
	else {
		print "It seems you don't have gcc installed on your system. Install it and retry.\n";
		return 0;
	}
}

# This function will try to create a new user for the daemon, return 1 on success and 0 on failure
sub create_user {
	# Checking if the user exists in the system
	my $user = `cat /etc/passwd | grep cvmfs-test`;
	# If it doesn't, create it
	if (!$user) {
		if (-e '/usr/sbin/useradd') {
			print "Adding user 'cvmfs-test'.\n";
			my $added = system('sudo /usr/sbin/useradd --system --user-group --key UMASK=0000 cvmfs-test');
			if ($added == -1) {
				print "FAILED: $!\n";
				return 0;
			}
			else {
				print "User 'cvmfs-test' added.\n";
				return 1;
			}
		}
		else {
			print "It seems you don't have useradd on your system. Install it and retry.\n";
			return 0;
		}
	}
	else {
		print "User already present on the system.\n";
		return 1;
	}
}

# This function will check if the wrapper is owned by the user cvmfs-test, return 1 on success and 0 on failure
sub chown_wrapper {
	# Checking if the user own the daemon wrapper
	my $uid = (stat("$Bin/cvmfs-testdwrapper"))[4];
	my $owner = (getpwuid($uid))[0];
	if($owner ne 'cvmfs-test') {
		print "Changing the owner of the wrapper... \n";
		my $chowned = system("sudo chown cvmfs-test:cvmfs-test $Bin/cvmfs-testdwrapper");
		if ($chowned == -1){
			print "FAILED: $!\n";
			return 0;
		}
		else {
			print "Done.\n";
			return 1;
		}
	}
	else {
		print "Wrapper already owned by cvmfs-test.\n";
		return 1;
	}
}

# This function will add the setuid byte to wrapper permission
sub setuid_wrapper {
	# Checking if the file has the setuid bit
	my $mode = (stat("$Bin/cvmfs-testdwrapper"))[2];
	my $suid = $mode & S_ISUID;
	
	if($suid) {
		print "setuid byte already set on the wrapper.\n";
		return 1;
	}
	else {
		print "Adding setuid byte... \n";
		my $setuid = system("sudo chmod +s $Bin/cvmfs-testdwrapper");
		if ($setuid == -1){
			print "FAILED: $!\n";
			return 0;
		}
		else {
			print "Done.\n";
			return 1;
		}
	}
}

1;
