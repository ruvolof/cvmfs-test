#!/usr/bin/perl

use strict;
use warnings;
use Functions::Setup qw(setup);
use LWP::Simple;

print 'To complete the installation process you need to be able to use sudo on your system. Are you? (N/y)';
my $sudoers = <STDIN>;
unless ($sudoers eq "y\n" or $sudoers eq "Y\n") { exit 0 }

setup("true", "true");

my $zmq_retrieve = 'http://download.zeromq.org/zeromq-2.2.0.tar.gz';
my $zmq_source = './zeromq-2.2.0.tar.gz';
my $zmq_source_dir = './zeromq-2.2.0';

my $arch = `arch`;
my $libsuffix = '';

if ($arch eq 'x86_64') { $libsuffix = '64' }

print 'Downloading ZeroMQ source tarball... ';
getstore($zmq_retrieve, $zmq_source);
print "Done.\n";

print 'Extracting ZeroMQ source... ';
system("tar -xzf $zmq_source");
print "Done.\n";

chdir $zmq_source_dir;

system("./configure --prefix=/usr --libdir=/usr/lib" . $libsuffix);
system('make');
system('sudo make install');

chdir '..';

print 'Installing cpanminus... ';
system('curl -L http://cpanmin.us | perl - --sudo App:cpanminus');
print "Done.\n";

print 'Installing ZeroMQ perl modules... ';
system('sudo cpanm ZeroMQ');
print "Done.\n";

print 'Upgrading Socket.pm version... ';
system('sudo cpanm Socket');
print "Done.\n";
