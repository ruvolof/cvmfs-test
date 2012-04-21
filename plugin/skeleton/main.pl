# The main.pl file under the plugin folder will be automatically launched
# everytime you launch the command. Here you should write your script.

use strict;
use warnings;
use feature 'say';

my $message = << "EOF"
Don't expect anything by this command.
Everytime you launch a command, the main.pl in its folder will be executed.
These lines you're reading are inside the skeleton main.pl.
EOF
;

print $message;
