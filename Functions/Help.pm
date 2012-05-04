package Functions::Help;

##############################
# Here will be stored all help related functions
##############################

use strict;
use warnings;
use File::Find;

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

# This code is needed to export the functions in the main package
use base 'Exporter';
use vars qw/ @EXPORT /;
@EXPORT= qw{ help get_help_file print_command_help print_help };

# This functions will be launched everytime the user type the help command.
# The goal of this function is only to select wich other help functions is needed.
sub help {
	# Retrieving arguments
	my $command = shift;
	my $myoutput = shift;
	my @options = @_;
	
	if( @options and scalar(@options) > 1){
		print $myoutput "Please, one command at time.\n";
	}
	elsif( @options and scalar(@options) == 1 and $options[0]){
		print_command_help($options[0], $myoutput);
	}
	else{
		print_help($myoutput);
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
	# Retrieving argument: the file handler
	my $myoutput = shift;
	
	# Retrieving all help files
	my @helpfiles;
	my $select = sub {
		if($File::Find::name =~ m/.*\/help$/){			
			push @helpfiles,$File::Find::name; # adds help files in the @helpfiles array.
		}
	};
	find( { wanted => $select }, $Bin);
	
	# Here it will open all the files and will print their contents.
	foreach (@helpfiles) {
		open (my $file, $_);
		while (defined (my $line = <$file>)){
			if($line =~ m/^Short:.*/){
				my @helpline = split /[:]/,$line,2;
				print $myoutput $helpline[1];
			}
		}
		close $file;
	}
}

# This function will print the Long help of a specific help file, probably found thanks
# to the get_command_help() function. Probably it can be integrated in that function, as
# already done with generic help, I think they will be almost everytime used together.
sub print_command_help {
	# Retrieving argument: the command asked and the file handler
	my $command = shift;
	my $myoutput = shift;
	
	# Retrieving the right help file
	my $helpfile = get_help_file($command);
	
	# If the helpfile exists, now it's time to print is content.
	if ( defined ($helpfile) && -e $helpfile){
		open (my $file, $helpfile);
		while (defined (my $line = <$file>)){
			if($line =~ m/^Long:.*/){
				my @helpline = split /[:]/,$line,2;
				print $myoutput $helpline[1];
			}
		}
		close $file;
	}
	else {
		print $myoutput "No help file found for the command $command.\nType \"help\" for a list of available commands.\n";
	}
}

1;
