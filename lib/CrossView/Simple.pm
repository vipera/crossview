package CrossView::Simple;
# ------------------------------------------------------------------------------
# CrossView::Simple - a simple VNC/SSH client and server wrapper.
# ------------------------------------------------------------------------------

use strict;
use warnings;

use Carp;
use Exporter qw(import);
use Data::Dumper;

use Net::OpenSSH;
use Net::EmptyPort qw(empty_port check_port);

#our @EXPORT = qw(make_server make_client kill_server); 
our @EXPORT_OK = qw(
	make_server make_client
	kill_server
);
our $VERSION = '0.01';

sub make_server {
	my ($display, $ssh_options) = @_;

	# start X11 VNC
	my $x11vnc_port = int `x11vnc -nap -bg -forever -nopw \\
		-desktop "VNC \${USER}@\${HOSTNAME}" -display :0 2>/dev/null \\
		| grep -Eo "[0-9]{4}"`;

	print "Started X11VNC server at localhost:$x11vnc_port\n";
	
	my $tunnel_port = 9000; # port on proxy machine to use (if necessary)
	my $ssh = 0;

	# do not do SSH if target host is localhost (no proxy used)
	unless ($ssh_options->{host} eq 'localhost') {
		$ssh_options = {
			%$ssh_options, 
			exitonfwdfail 	=> 1, # don't allow connection if port is used

			# reverse tunnel PORT:HOST:X11VNCPORT
			reverse			=> 1,
			local_port		=> $tunnel_port,
			remote_host		=> $ssh_options->{host},
			remote_port		=> $x11vnc_port,
		};

		for (; $tunnel_port < 10000; $tunnel_port++) {
			$ssh = open_ssh_tunnel(%$ssh_options);

			# break if error isn't 'port already used', otherwise try next port
			last unless ($ssh->error &&
				index($ssh->error, 'remote port forwarding failed') != -1);
		}

		if (!$ssh || $ssh->error) {
			kill_server();
			croak 'Could not connect to SSH server: ' . $ssh->error . "\n";
		}
	}

	# change localhost to something more explicit if no proxy is being used
	if ($ssh_options->{host} eq 'localhost') {
		$ssh_options->{host} = 'THIS_HOST';
		$tunnel_port = $x11vnc_port;
	}

	print "Run crossview on client with the following options:\n";
	print "$0 -c -p $tunnel_port [USER\@]$ssh_options->{host}\n";
}

sub kill_server {
	`x11vnc -R stop 2>/dev/null`;
	print "Stopped local X11VNC server instance.\n";
}

sub make_client {
	my ($remote_port, $ssh_options) = @_;

	# get a random empty port
	my $tunnel_port = empty_port();

	my $ssh = 0;
	if ($ssh_options->{host} eq 'localhost') {
		$tunnel_port = $remote_port;
	}
	else {
		$ssh_options = {
			%$ssh_options, 
			# normal tunnel PORT:HOST:X11VNCPORT
			local_port		=> $tunnel_port,
			remote_host		=> 'localhost',
			remote_port		=> $remote_port,
		};

		print "Establishing SSH tunnel to target machine...\n";
		$ssh = open_ssh_tunnel(%$ssh_options);

		if ($ssh->error) {
			croak 'Error connecting to server: ' . $ssh->error . "\n";
		}
	}

	print "Initiating VNC viewer for remote session...\n";
	`vncviewer localhost:$tunnel_port 2>/dev/null`;
}

sub open_ssh_tunnel {
	my %options = @_;

	my %sshoptions = (
		strict_mode => 0,
		timeout => 3,
		master_opts => [
			# allow proxy to be unknown host
			'-o' => 'StrictHostKeyChecking=no',
			'-c' => 'blowfish',

			# default to normal tunneling
			$options{reverse} ? '-R' : '-L' =>
				"$options{local_port}:$options{remote_host}:$options{remote_port}"
		],
		# add other options (if defined)
		map { $options{$_} ? ($_ => $options{$_}) : () }
			qw(user port),
	);

	# password if user based, passphrase if using public key
	if ($options{keyfile}) {
		$sshoptions{passphrase} = $options{password};
		$sshoptions{key_path} = $options{keyfile};
	}
	else {
		$sshoptions{password} = $options{password};
	}

	# only add ExitOnForwardFailure option if requested
	push $sshoptions{master_opts}, '-o' => 'ExitOnForwardFailure=yes'
		if ($options{exitonfwdfail});

	#print Dumper(\%sshoptions);

	my $ssh = Net::OpenSSH->new($options{host}, %sshoptions);

	#$ssh->error and
	#	die "Couldn't establish SSH connection: ". $ssh->error;

	return $ssh;
}

1;

__END__
=head1 NAME

CrossView Simple - module for VNC viewing over a common SSH-enabled proxy.

=head1 DESCRIPTION

Subroutines for creating a simple VNC/SSH client and server via an optional
proxy host. The proxy host should be an SSH server over which traffic can be
securely tunneled, avoiding firewalls, NAT, etc.

=head1 VERSION

Version 1.0

=head1 AUTHOR

Marin Rukavina, C<< <marin at shinyshell.net> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Marin Rukavina

This program is free software; you can redistribute it and/or modify it
under the terms of the BSD license. See COPYING file for details.

=cut