package Functions::Help;

##############################
# Here will be stored all help related functions
##############################

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
@EXPORT= qw{ get_help_file print_command_help print_help };

# This function will retrive the position of plugin related help file.
# It search recursively in all folder inside $Bin (that is the directory
# where the script is located). In this way we can organize our plugins in
# "subject related" subfolder.

sub get_help_file {
	# First argument when calling this function must be the command
	my $command = shift;
	my $helpfile;
	my $select = sub {
		if ($File::Find::name =~ m/.*\/$command\/help/){	
			$helpfile = $&;		
		}
	};
	finddepth( { wanted => $select }, $Bin);
	return $helpfile;
}

# This function will retrieve all the help file inside $Bin and for each one of them
# it prints the Short description. It needs no argument.

sub print_help {
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
				print $helpline[1];
			}
		}
		close $file;
	}
}

# This function will print the Long help of a specific help file, probably found thanks
# to the get_command_help() function. Probably it can be integrated in that function, as
# already done with generic help, I think they will be almost everytime used together.

sub print_command_help {
	my $command = shift;
	my $helpfile = get_help_file($command);
	if ( defined ($helpfile) && -e $helpfile){
		open (my $file, $helpfile);
		while (defined (my $line = <$file>)){
			if($line =~ m/^Long:.*/){
				my @helpline = split /[:]/,$line,2;
				print $helpline[1];
			}
		}
		close $file;
	}
	else {
		say "No help file found for the given command.\nType \"help\" for a list of available commands.";
	}
}

1;
