use strict;
use warnings;
use feature qw(say switch);
use File::Find;

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

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
	my $helpfile = shift;
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

# This function will be launched everytime a command is invoked from the shell. It will
# search recursively from $Bin for a main.pl file inside a folder named as the requested command.
# If found, it will launch the main.pl file. Else, it will return back to the shell.
sub launch {
	my $test = shift;
	my $mainfile;
	my $select = sub {
		if($File::Find::name =~ m/.*\/$test\/main\.pl$/){
			$mainfile = $&;
		}
	};
	finddepth( { wanted => $select }, $Bin);
	if(defined ($mainfile)){
		system('perl ' . $mainfile);
	}
	else {
		say 'Command not found. Type "help" for a list of available command.';
	}
}

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
		@options = @command[1, -1];
	}
	
	# Switch on the value of $command[0].
	given($command[0]){
		when ($_ eq 'help' or $_ eq 'h') {
			if(scalar (@options) != 0){
				my $helpfile = get_help_file($options[0]);
				print_command_help($helpfile);
			}
			else{
				print_help();
			}
		}
		when ($_ eq 'exit' or $_ eq 'q') { exit 0 }
		default { launch($command[0]) }
	}		
}
