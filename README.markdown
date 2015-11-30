# CrossView - Wrapper for VNC over a common SSH host #

A program that allows a tunneled SSH connection to a proxy server by a server and
a client and the exchange of VNC traffic via that connection.

## Synopsis ##

Usage:
```
crossview [-c] [-s] [-i] [-h|--help] [-v|--version] [-p port] [-d X session]
[--password password] [--viewonly] [user[:password]@]host[:port]
```

To start the server, specify a display to share and an SSH proxy over which to
allow the connection:

```
marin@ananas:~$ crossview -s -d 0 user@hostname
Run crossview on client with the following options:
crossview -c -p 9000 [USER@]hostname
```

You can now run the client application to connect to the server via the given
port and SSH host.

```
ivana@pelikan:~$ crossview -c -p 9000 user@hostname
```

## Description ##

CrossView allows a desktop X session to be shared via an SSH proxy server with
another computer. First, x11vnc(1) will be started. Using ssh(1), a connection
will be established towards another computer and the local port used for
connecting to X11VNC will be forwarded. Another crossview user connecting to the
SSH proxy can connect to the session, thereby bypassing any NAT or firewalls
that would impede a direct connection.

The synopsis above gives a basic working example. Try crossview --help for more
information or see the CrossView::Simple manual page.

Let's say there are three machines, A, B and C. B is accessible by both A
and C, but A is not directly accessible from C or direct access would be
impractical.

A -- B -- C

A is a machine that would like to share its desktop with C, but is behind a
firewall, NAT or some other obstacle. Both machines can access B, which is
running an SSH server instance.

A starts CrossView in server mode, sharing X session :0

`crossview -s -d 0 user@B`

This creates a reverse tunnel from B to A that C can use after connecting to
B via the client mode. The user of C is told the port number that has been
reserved for traffic on B:

`crossview -c -p PORT_NO user@B`

This will open a VNC viewer for viewing and controlling the remote machine A.

## Options ##

| Command-line switch | Description |
| ------------------- | ----------- |
| -s      | Start in server mode (share a desktop) |
| -c      | Start in client mode (connect to a desktop) |
| -i | Use public key / passphrase authentication towards the SSH server instead of username/password. |
| -h, --help | Show program help |
| -v, --version | Show program version |
| -p | Client mode only. Connect to specified forwarded port on proxy server. To
	connect to a different SSH port (not 22), use the hostname:port notation
	when specifying the SSH proxy's address. |
| -d | Server mode only. Use the specified X session for displaying. The current
	desktop is usually 0 or 1, but this may vary depending on your settings. |
| --password | Server mode only. Use the specified password for the VNC session. Provides
	additional security against people logged into the SSH proxy from viewing
	other sessions. |
| --viewonly | Server mode only. Specify that a session is to be viewed only, with mouse
	and keyboard events not propagated to the target host. |

## Installation ##

### Prerequisites ###

Perl 5.6.x or higher with CPAN.

Server mode requirements:
- x11vnc

Client mode requirements:
- vncviewer (eg. TigerVNC)

### Installation instructions ###

See INSTALL file for instructions.

## License ##

This program is free software, licenced under the the BSD licence.
Please see the COPYING file for additional information.

