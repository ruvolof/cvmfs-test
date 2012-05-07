# The main.pl file under the plugin folder will be automatically launched
# everytime you launch the command. Here you should write your script.

use strict;
use warnings;

# You'll probably want your script to send back some feedback to the user,
# in this case you has to redirect your output to the FIFO used by the daemon.
# Here, I'm going to redirect the whole output by setting STDOUT to the FIFO.
use IO::Handle;
my $OUTPUT = '/tmp/cvmfs-testd-output.fifo';
open (my $myoutput, '>', $OUTPUT);
STDOUT->fdopen( \*$myoutput, 'w');

my $message = << "EOF"
Don't expect anything by this command.
Everytime you launch a command, the main.pl in its folder will be executed.
These lines you're reading are inside the skeleton main.pl.
EOF
;

print $message;

# Always close your file handler before exiting your script
close $myoutput;
