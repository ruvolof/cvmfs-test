package Functions::Launcher;

#################################
# Here will be stored all functions to launch the various tests
#################################

use strict;
use warnings;
use feature 'say';
use File::Find;

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

# This code is needed to export the functions in the main package

use base 'Exporter';
use vars qw/ @EXPORT /;
@EXPORT= qw{ launch kill_process };

# This function will be launched everytime a command is invoked from the shell. It will
# search recursively from $Bin for a main.pl file inside a folder named as the requested command.
# If found, it will launch the main.pl file. Else, it will return back to the shell.

sub launch {
	my $test = shift;
	
	my @options = @_;
	my $options = join(' ', @options);
	
	my $mainfile;
	my $select = sub {
		if($File::Find::name =~ m/.*\/$test\/main\.pl$/){
			$mainfile = $&;
		}
	};
	finddepth( { wanted => $select }, $Bin);
	if(defined ($mainfile)){
		system('perl ' . $mainfile . ' ' . $options);
	}
	else {
		say 'Command not found. Type "help" for a list of available command.';
	}
}

# This function will be used to kill the processes.
sub kill_process {
	my $pid = shift;
	my $success;
	my $cnt = kill 0, $pid;
	if ($cnt > 0) {
		say "Sending TERM signal to process $pid";
		$success = kill 15, $pid;
	}
	if ($success > 0) {
		say "Process terminated";
	}
	else {
		say 'Impossible to terminate the process';
	}
}
