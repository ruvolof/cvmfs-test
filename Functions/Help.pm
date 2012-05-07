package Functions::Help;

##############################
# Here will be stored all help related functions
##############################

use strict;
use warnings;
use File::Find;
use Functions::FIFOHandle qw{ open_rfifo open_wfifo close_fifo print_to_fifo };

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

# Next lines are needed to export subroutines to the main package
use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw(help print_command_help print_help get_help_file);

# These are the paths where FIFOs are stored
my $INPUT = '/tmp/cvmfs-testd-input.fifo';
my $OUTPUT = '/tmp/cvmfs-testd-output.fifo';

# This functions will be launched everytime the user type the help command.
# The goal of this function is only to select wich other help functions is needed.
sub help {
	# Retrieving arguments
	my $command = shift;
	my @options = @_;
	
	if( @options and scalar(@options) > 1){
		print_to_fifo ($OUTPUT, "Please, one command at time.\n");
	}
	elsif( @options and scalar(@options) == 1 and $options[0]){
		print_command_help($options[0]);
	}
	else{
		print_help();
	}
}

# This function will retrive the position of plugin related help file.
# It search recursively in all folder inside $Bin (that is the directory
# where the script is located). In this way we can organize our plugins in
# "subject related" subfolder.
sub get_help_file {
	# Retrieving argument, the command asked
	my $command = shift;
	
	# Searching the right help file
	my $helpfile;
	my $select = sub {
		if ($File::Find::name =~ m/.*\/$command\/help/){	
			$helpfile = $&;		
		}
	};
	finddepth( { wanted => $select }, $Bin);
	
	# Returning the help file path to print_command_help
	return $helpfile;
}

# This function will retrieve all the help file inside $Bin and for each one of them
# it prints the Short description. It needs no argument.
sub print_help {	
	# Retrieving all help files
	my @helpfiles;
	my $select = sub {
		if($File::Find::name =~ m/.*\/help$/){			
			push @helpfiles,$File::Find::name; # adds help files in the @helpfiles array.
		}
	};
	find( { wanted => $select }, $Bin);
	
	# Here it will open the FIFO for output
	my $outputfh = open_wfifo($OUTPUT);
	
	# Here it will open all the files and will print their contents.
	foreach (@helpfiles) {
		open (my $file, $_);
		while (defined (my $line = <$file>)){
			if($line =~ m/^Short:.*/){
				my @helpline = split /[:]/,$line,2;
				print $outputfh $helpline[1];
			}
		}
		close $file;
	}
	
	# Here it closes the output FIFO
	close_fifo($outputfh);
}

# This function will print the Long help of a specific help file, probably found thanks
# to the get_command_help() function. Probably it can be integrated in that function, as
# already done with generic help, I think they will be almost everytime used together.
sub print_command_help {
	# Retrieving argument: the command
	my $command = shift;
	
	# Retrieving the right help file
	my $helpfile = get_help_file($command);
	
	# Here it opens the output FIFO
	my $outputfh = open_wfifo($OUTPUT);
	
	# If the helpfile exists, now it's time to print is content.
	if ( defined ($helpfile) && -e $helpfile){
		open (my $file, $helpfile);
		while (defined (my $line = <$file>)){
			if($line =~ m/^Long:.*/){
				my @helpline = split /[:]/,$line,2;
				print $outputfh $helpline[1];
			}
		}
		close $file;
	}
	else {
		print $outputfh "No help file found for the command $command.\nType \"help\" for a list of available commands.\n";
	}
	
	# Here it closes the output FIFO
	close_fifo($outputfh);
}

1;
