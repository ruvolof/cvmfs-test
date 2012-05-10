use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin";
use HTTP::AppServer;
use Getopt::Long;

my $not_found;
my $port = 8080;
my $background = 1;
my $fg;
my $docroot = '/tmp';
my $retriever = 'FileRetriever';

my $ret = GetOptions ( "404" => \$not_found,
					   "port=i" => \$port,
					   "fg" => \$fg,
					   "root=s" => \$docroot );
					   
if (defined ($fg)){
	$background = 0;
}

if (defined ($not_found)){
	$retriever = 'Retriever404';
}

# create server instance at localhost:$port
my $server = HTTP::AppServer->new( StartBackground => $background, ServerPort => $port );
 
# alias URL
$server->handle('^\/$', '/index.html');

# load plugin for simple file retrieving from a document root
$server->plugin("$retriever", DocRoot => "$docroot");
        
# start server
$server->start;
