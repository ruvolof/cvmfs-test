use strict;
use warnings;
use feature qw(say switch);
use File::Find;
use Functions::Help;
use Functions::Launcher;

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

# A simple welcome.
say '#'x80;
say 'Welcome in the interactive shell of the CernVM-FS testing system.';
say 'Type "help" for a list of available commands.';
say '#'x80;

# Infinite loop for the shell. It will exit on "exit" command.
while(1){
	print '-> ';
	# Reading an input line.
	my $line = <STDIN>;
	# Deleting the return character.
	chomp($line);
	
	# Splitting the line in an array depending on blank. So the command will be in $command[0]
	my @command = split /[[:blank:]]/, $line;
	
	# Everything else will be considered option and will be stored in @options.
	my @options;
	if(scalar (@command) > 1){
		@options = splice (@command, 1);
	}
	
	# Switch on the value of $command[0].
	given($command[0]){
		when ($_ eq 'help' or $_ eq 'h') {
			if(scalar (@options) != 0){
				print_command_help($options[0]);
			}
			else{
				print_help();
			}
		}
		when ($_ eq 'exit' or $_ eq 'q') { exit 0 }
		default { launch($command[0], @options) }
	}		
}
