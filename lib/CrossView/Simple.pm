package CrossView::Simple;
# ------------------------------------------------------------------------------
# CrossView::Simple - a simple VNC/SSH client and server wrapper.
# ------------------------------------------------------------------------------

use warnings;
use strict;

use Carp 			qw(carp croak);
use Exporter 		qw(import);
use Net::OpenSSH 	qw();
use Net::EmptyPort 	qw(empty_port check_port);
use IPC::Cmd        qw(can_run run run_forked);
use IPC::Open3      qw(open3);
use Data::Dumper;

#our @EXPORT = qw(make_server make_client kill_server); 
our @EXPORT_OK = qw(
    make_server make_client
    kill_server
    random_password
);
our $VERSION = '0.02';

our @vnc_password_chars = ('A'..'Z', 'a'..'z', '1'..'9');

sub make_server {
	my %C = %{ shift() };

    my $x11vnc_executable = can_run('x11vnc')
        or croak 'X11VNC is not installed.';

    # pick window if option was specified, but a concrete window ID wasn't set
    if (!defined $C{windowid} && $C{pickwindow}) {
        $C{windowid} = pick_window();
    }

    # start a new x session and show it nested with Xephyr
    if ($C{newxsession}) {
        $C{display} = open_xephyr_display($C{newxsession});
    }

    # start X11 VNC
    my $x11vnc_command = "$x11vnc_executable " .
        ($C{viewonly} ? '-viewonly ' : '') .
        ($C{vnc_password} ? "-passwd $C{vnc_password} " : '-nopw ') .
        '-nap -bg -forever -noxdamage -nolookup ' .
        qq(-desktop "VNC \${USER}@\${HOSTNAME}" ) .
        (defined $C{windowid} ? "-id $C{windowid} " : '') .
        "-display :$C{display} 2>/dev/null";

    my $x11vnc_output = `$x11vnc_command`;
    my ($x11vnc_port) = $x11vnc_output =~ m/([0-9]{4})/;
    croak 'Unable to start X11VNC.' unless ($x11vnc_port);

    print "Started X11VNC server at localhost:$x11vnc_port\n";
    
    my $ssh = undef;
    my ($tunnel_port, $tunnel_max_port) = (9000, 10000); # port on proxy machine
    
    # do not do SSH if target host is localhost (no proxy used)
    unless ($C{ssh_host} eq 'localhost') {
        print "Establishing SSH tunnel to remote machine...\n";
        for (; $tunnel_port < $tunnel_max_port; $tunnel_port++) {
            # TODO: apparently ExitOnForwardFailure doesn't work on localhost
            # tunnels. This is ugly, see if there's a better way.
            my $try_ssh = ssh_connect(
            	host 		=> $C{ssh_host},
                user        => $C{ssh_user},
            	password 	=> $C{ssh_password},
            	port 		=> $C{ssh_port},
            	keyfile 	=> $C{key_file}
            );
            if (!$try_ssh || $try_ssh->error) {
                $ssh = $try_ssh;
                last;
            }
            my $port_error = $try_ssh->capture({ stderr_discard => 1 },
                "netstat -lep --tcp | grep ':$tunnel_port'");
            next if index($port_error, ":$tunnel_port") != -1;

            # establish tunnel
            $ssh = open_ssh_tunnel(
            	host 			=> $C{ssh_host},
                user            => $C{ssh_user},
	        	password 		=> $C{ssh_password},
	        	port 			=> $C{ssh_port},
	        	keyfile 		=> $C{key_file},
	            
	            # don't allow connection if port is used
	            exitonfwdfail 	=> 1,

	            # reverse tunnel PORT:HOST:X11VNCPORT
	            reverse 		=> 1,
	            local_port 		=> $tunnel_port,
	            remote_host 	=> 'localhost',
	            remote_port 	=> $x11vnc_port,
            );

            # break if error isn't 'port already used', otherwise try next port
            last unless ($ssh->error && (
                index($ssh->error, 'remote port forwarding failed') != -1 ||
                index($ssh->error, 'control command failed') != -1));
        }

        if ($tunnel_port > $tunnel_max_port) {
        	croak 'Could not open port on proxy at this time - max number of ' .
        		'connections established.';
        }

        if (!$ssh || $ssh->error) {
            kill_server();
            croak 'Could not connect to SSH server' .
                ($ssh ? ' (' . $ssh->error . ')' : '');
        }
    }

    print "Run crossview on client with the following options:\n";
    print join(' ', (
        "crossview -c",
        '-p ' . ($C{ssh_host} eq 'localhost' ? $x11vnc_port : $tunnel_port),
        defined $C{vnc_password} ? "--password $C{vnc_password}" : '',
        $C{ssh_host} eq 'localhost' ?
            'SSH_USER@THIS_HOST' :
            make_connection_string(\%C)
    )), "\n";
    print "Password: $C{vnc_password}\n" if defined $C{vnc_password};

    return { ssh => $ssh };
}

sub kill_server {
    my $x11vnc_executable = can_run('x11vnc') or return;
    system "$x11vnc_executable -R stop 2>/dev/null";
    print "Stopped local X11VNC server instance.\n";
}

sub pick_window {
    print "Please select a window to be shared with your mouse!\n";
    my ($windowid) = `xwininfo` =~ /Window id: (0x[\da-fA-F]+)/;
    return $windowid;
}

sub get_current_screen_resolution {
    my $screeninfo = `xrandr -q`;
    if (my ($h, $v) = $screeninfo =~ m/current (\d+) x (\d+)/) {
        return "${h}x${v}";
    }
    return undef;
}

sub open_xephyr_display {
    my $x_port = shift;

    my $dbus_launch_executable = can_run('dbus-launch')
        or croak 'Dbus-launch is unavailable. Could not open Xephyr display.';

    # detect desktop environment
    my $desktop_executable = undef;
    if ($ENV{DESKTOP_SESSION}) {
        # try detecting via this environment variable, which is often unreliable
        for ($ENV{DESKTOP_SESSION}) {
            /xfce/      and do { $desktop_executable = 'xfce4-session'; last; };
            /ubuntu-2d/ and do { $desktop_executable = 'unity-panel'; last; };
        }
    }
    else {
        # try detecting available IDEs from available executables in path
        for my $desktop ('gnome-session',  'kded4', 'unity-panel',
            'xfce4-session', 'cinnamon', 'mate-panel', 'lxsession') {
            $desktop_executable = can_run($desktop);
            last if $desktop_executable;
        }
    }

    carp 'Cannot detect desktop environment. Will launch empty X session.'
        unless $desktop_executable;

    my $resolution = get_current_screen_resolution();

    print "Starting Xephyr nested X session...\n";
    system "Xephyr :$x_port -ac -screen $resolution -br -reset -terminate &>/dev/null &";
    sleep 1; # some time for Xephyr to start

    if ($desktop_executable) {
        local $ENV{DISPLAY} = ":$x_port.0";
        local $ENV{SESSION_MANAGER}; # fix for xfce4-session

        print "Starting $desktop_executable...\n";
        system "$dbus_launch_executable $desktop_executable &>/dev/null &";
        sleep 3;
    }

    return $x_port;
}

sub make_connection_string {
    my %C = %{ shift() };
    return ($C{ssh_user} ?
        ($C{ssh_password} ?
            "$C{ssh_user}:$C{ssh_password}\@" : "$C{ssh_user}\@") : '')
    . $C{ssh_host} . ($C{ssh_port} ? ":$C{ssh_port}" : '');
}

sub make_client {
	my %C = %{ shift() };

    # get a random empty port
    my $tunnel_port = empty_port();

    my $ssh = undef;
    if ($C{ssh_host} eq 'localhost') {
        $tunnel_port = $C{remote_port};
    }
    else {
        print "Establishing SSH tunnel to target machine...\n";
        $ssh = open_ssh_tunnel(
        	host 		=> $C{ssh_host},
            user        => $C{ssh_user},
        	password 	=> $C{ssh_password},
        	port 		=> $C{ssh_port},
        	keyfile 	=> $C{key_file},

            # normal tunnel PORT:HOST:X11VNCPORT
            local_port  => $tunnel_port,
            remote_host => 'localhost',
            remote_port => $C{remote_port},
        );

        if ($ssh->error) {
            croak 'Error connecting to server: ' . $ssh->error;
        }
    }

    print "Initiating VNC viewer for remote session over localhost:$tunnel_port...\n";

    my $vncviewer_executable = can_run('vncviewer')
        or croak 'Cannot initiate: vncviewer not installed or not in path.';
    system "$vncviewer_executable " .
        ($C{viewonly} ? '-ViewOnly ' : '') .
        "localhost:$tunnel_port 2>/dev/null";

    return { ssh => $ssh };
}

sub random_password {
	my $length = shift // 8;
	
	my $string;
	$string .= $vnc_password_chars[rand @vnc_password_chars] for 1 .. $length;
	return $string;
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
            qw(host user port),
    );

    # password if user based, passphrase if using key auth
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