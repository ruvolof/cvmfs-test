package Functions::Launcher;

#################################
# Here will be stored all functions to launch the various tests
#################################

use strict;
use warnings;
use File::Find;
use Proc::Spawn;
use Functions::FIFOHandle qw(open_rfifo open_wfifo close_fifo print_to_fifo);

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

# This code is needed to export the functions in the main package
use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw{ launch kill_process jobs };

# These are the paths where FIFOs are stored
my $INPUT = '/tmp/cvmfs-testd-input.fifo';
my $OUTPUT = '/tmp/cvmfs-testd-output.fifo';

# This function will be launched everytime a command is invoked from the shell. It will
# search recursively from $Bin for a main.pl file inside a folder named as the requested command.
# If found, it will launch the main.pl file. Else, it will return back to the shell.
sub launch {
	# Retrieving argument: command, output file handler and options
	my $test = shift;
	my @options = @_;
	
	# Declaring variables used for the fork
	my ($pid, $infh, $outfh, $errfh);
	
	# Joining all options in a unique string
	my $options = join(' ', @options);
	
	# Searching fot the script to be executed
	my $mainfile;
	my $select = sub {
		if($File::Find::name =~ m/.*\/$test\/main\.pl$/){
			$mainfile = $&;
		}
	};
	finddepth( { wanted => $select }, '.');
	
	# Executing the script, if found
	if(defined ($mainfile)){
		($pid, $infh, $outfh, $errfh) = spawn('perl ' . $mainfile . ' ' . $options);
		my $fh = open_wfifo($OUTPUT);
		while (defined(my $line = <$outfh>)){
			print $fh $line;
		}
		close $outfh;
		close_fifo($fh);
	}
	else {
		print_to_fifo ($OUTPUT, "Command not found. Type 'help' for a list of available command.\n");
	}
}

# This function will be used to kill the processes.
sub kill_process {
	# Retrieving arguments: a list of PID that must be killed.
	my @pids = @_;
	
	my $success;
	my $cnt;
	
	# Start killing all process
	my $fh = open_wfifo($OUTPUT);
	foreach(@pids){
		my $process = `ps -u cvmfs-test -p $_ | grep $_`;
		if ($process) {
			$cnt = kill 0, $_;
			if ($cnt > 0) {
				print $fh "Sending TERM signal to process $_ ... ";
				$success = kill 15, $_;
			}
			if ( defined($success) and $success > 0) {
				print $fh "Process terminated.\n";
			}
			else {
				print $fh "Impossible to terminate the process $_\n";
			}
		}
		else {
			print $fh "No process with PID $_\n";
		}
	}
	close_fifo($fh);
}

sub jobs {
	my @process = `ps -u cvmfs-test -o pid,args | grep -v defunct | grep -v cvmfs-test`;
	
	my $fh = open_wfifo($OUTPUT);
	foreach (@process) {
		print $fh $_;
	}
	close_fifo($fh);
}

1;
