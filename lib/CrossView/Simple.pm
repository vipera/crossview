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
    my ($display, $viewonly, $password, $ssh_options) = @_;

    # start X11 VNC
    my $x11vnc_command = 'x11vnc ' .
        ($viewonly ? '-viewonly ' : '') .
        ($password ? "-passwd $password " : '-nopw ') .
        '-nap -bg -forever -noxdamage -nolookup ' .
        qq(-desktop "VNC \${USER}@\${HOSTNAME}" ) .
        "-display :$display 2>/dev/null";
    my $x11vnc_output = `$x11vnc_command`;

    my ($x11vnc_port) = $x11vnc_output =~ m/([0-9]{4})/;
    unless ($x11vnc_port) {
        croak "Unable to start X11VNC.";
    }

    print "Started X11VNC server at localhost:$x11vnc_port\n";
    
    my $ssh = 0;
    my $tunnel_port = 9000; # port on proxy machine
    
    my $try_ssh_options = $ssh_options;
    # do not do SSH if target host is localhost (no proxy used)
    unless ($ssh_options->{host} eq 'localhost') {
        $ssh_options = {
            %$ssh_options, 
            exitonfwdfail     => 1, # don't allow connection if port is used

            # reverse tunnel PORT:HOST:X11VNCPORT
            reverse            => 1,
            remote_host        => 'localhost',
            remote_port        => $x11vnc_port,
        };

        for (; $tunnel_port < 10000; $tunnel_port++) {
            # TODO: apparently ExitOnForwardFailure doesn't work on localhost
            # tunnels. This is ugly, see if there's a better way.
            my $try_ssh = ssh_connect(%$try_ssh_options);
            my $port_error = $try_ssh->capture({ stderr_discard => 1 },
                "netstat -lep --tcp | grep ':$tunnel_port'");
            if (!$try_ssh) {
                $ssh = $try_ssh;
                last;
            }
            next if index($port_error, ":$tunnel_port") != -1;

            # establish tunnel
            $ssh_options->{local_port} = $tunnel_port;
            $ssh = open_ssh_tunnel(%$ssh_options);

            # break if error isn't 'port already used', otherwise try next port
            last unless ($ssh->error && (
                index($ssh->error, 'remote port forwarding failed') != -1 ||
                index($ssh->error, 'control command failed') != -1));

        }

        if (!$ssh || $ssh->error) {
            kill_server();
            croak 'Could not connect to SSH server' .
                ($ssh ? ' (' . $ssh->error . ')' : '');
        }
    }

    # change localhost to something more explicit if no proxy is being used
    if ($ssh_options->{host} eq 'localhost') {
        $ssh_options->{host} = 'THIS_HOST';
        $tunnel_port = $x11vnc_port;
    }

    print "Run crossview on client with the following options:\n";
    print "$0 -c -p $tunnel_port [USER\@]$ssh_options->{host}\n";
    print "Password: $password\n" if $password;

    return { ssh => $ssh };
}

sub kill_server {
    `x11vnc -R stop 2>/dev/null`;
    print "Stopped local X11VNC server instance.\n";
}

sub make_client {
    my ($remote_port, $password, $ssh_options) = @_;

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
            local_port  => $tunnel_port,
            remote_host => 'localhost',
            remote_port => $remote_port,
        };

        print "Establishing SSH tunnel to target machine...\n";
        $ssh = open_ssh_tunnel(%$ssh_options);

        if ($ssh->error) {
            croak 'Error connecting to server: ' . $ssh->error . "\n";
        }
    }

    print "Initiating VNC viewer for remote session over localhost:$tunnel_port...\n";
    `vncviewer localhost:$tunnel_port 2>/dev/null`;

    return { ssh => $ssh };
}

sub open_ssh_tunnel {
    my %options = @_;

    my $ssh = ssh_connect(
        (%options, opts => [
            $options{reverse} ? '-R' : '-L' =>
            "$options{local_port}:$options{remote_host}:$options{remote_port}"
        ])
    );
    return $ssh;
}

sub ssh_connect {
    my %options = @_;

    $options{opts} = [] unless $options{opts};

    my %sshoptions = (
        strict_mode => 0,
        batch_mode => 1,
        timeout => 30,
        master_opts => [
            # allow proxy to be unknown host
            '-o' => 'StrictHostKeyChecking=no',
            '-c' => 'blowfish-cbc',
            @{$options{opts}}
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
    push @{$sshoptions{master_opts}}, '-o' => 'ExitOnForwardFailure=yes'
        if ($options{exitonfwdfail});

    my $ssh = Net::OpenSSH->new($options{host}, %sshoptions);

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