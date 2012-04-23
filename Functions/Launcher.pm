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
@EXPORT= qw{ launch };

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
