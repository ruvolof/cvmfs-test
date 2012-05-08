# The main.pl file under the plugin folder will be automatically launched
# everytime you launch the command. Here you should write your script.

use strict;
use warnings;

# You'll probably want your script to send back some feedback to the user,
# in this case you has to redirect your output to the FIFO used by the daemon.
# Have a look to the Functions::FIFOHandle package to find some useful functions.
use Functions::FIFOHandle qw(open_rfifo open_wfifo close_fifo print_to_fifo);

# In order to communicate with other process, you have to send your output to the right FIFO
my $OUTPUT = '/tmp/cvmfs-testd-output.fifo';

my $message = << "EOF"
Don't expect anything by this command.
Everytime you launch a command, the main.pl in its folder will be executed.
These lines you're reading are inside plugin/skeleton/main.pl. Have a look
there to get some hint on how to make your own plugin.
EOF
;

# You can send you output to the FIFO using the function print_to_fifo()
print_to_fifo ($OUTPUT, $message);
