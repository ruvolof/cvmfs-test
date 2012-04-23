package Server::HTTP::AppServer::Plugin::Retriever404;
# Plugin for Server::HTTP::AppServer that retrieves files from a document root.
# 2010 by Tom Kirchner

use 5.010000;
use strict;
use warnings;
use IO::File;
use JSON;
use Path::Trim;
use Server::HTTP::AppServer::Plugin;
use base qw(Server::HTTP::AppServer::Plugin);

our $VERSION = '0.01';

# document root for file retrieval
my $DocRoot = '/tmp';

# all the mimetypes of files handled by the plugin
my $MimeTypes = {
	'html' => 'text/html',
	'css'  => 'text/css',
	'js'   => 'text/javascript',
	'png'  => 'image/png',
	'jpg'  => 'image/jpg',
	'jpeg' => 'image/jpg',
	'gif'  => 'image/gif',
};	

my $PathTrimmer = Path::Trim->new();

# called by the server when the plugin is installed
# to determine which routes are handled by the plugin
sub init
{
	my ($class, $server, %options) = @_;

	$PathTrimmer->set_directory_separator('/');

	# analyse options
	$DocRoot = $options{'DocRoot'} if exists $options{'DocRoot'};

	# install properties in server
	$server->set('mimetypes', $MimeTypes);
	$server->set('docroot', $DocRoot);

	return (
		# handle file (and directory) requests
		'^\/(.*)$' => \&_handle_file,
	);
}

sub _handle_file
{
	my $server = shift;
	$server->errorpage(404);
}


1;
__END__
=head1 NAME

Server::HTTP::AppServer::Plugin::FileRetriever - Plugin for Server::HTTP::AppServer that retrieves files from a document root.

=head1 SYNOPSIS

  use Server::HTTP::AppServer;
  my $server = Server::HTTP::AppServer->new();
  $server->plugin('FileRetriever', DocRoot => '/path/to/docroot');

=head1 DESCRIPTION

Plugin for Server::HTTP::AppServer that retrieves files from a document root.

=head2 Plugin configuration

=head3 DocRoot => I<dir>

Defines the document root directory where the files are retrieved from.

=head2 Installed URL handlers

FileRetriever handles all URLs matching '^\/(.*)$'.
It stops the server from processing any other URL handlers after that
so it is best loaded as the last one.

=head2 Installed server properties

None.

=head2 Installed server methods

None.

=head2 Handled mimetypes

Currently FileRetriever can handle HTML, CSS, JS, PNG, JPG/JPEG
and GIF files. The mimetype is determined by inspecting the
filename extension.

=head1 SEE ALSO

Server::HTTP::AppServer, Server::HTTP::AppServer::Plugin

=head1 AUTHOR

Tom Kirchner, E<lt>tom@tkirchner.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Tom Kirchner

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
