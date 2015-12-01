# CrossView - Wrapper for VNC over a common SSH host #

A program that allows a tunneled SSH connection to a proxy server by a server and
a client and the exchange of VNC traffic via that connection.

## Synopsis ##

Usage:
```
crossview [-c] [-s] [-i] [-h|--help] [-v|--version] [-p PORT_NO]
	[-d X_DISPLAY] [--password PASSWORD] [--no-pw] [--viewonly]
	[--pick-window] [-w|--window-id X_WINDOW_ID]
	[USER[:PASSWORD]@]HOST[:PORT]
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
| -s | Start in server mode (share a desktop). |
| -c | Start in client mode (connect to a desktop). |
| -i | Use key/passphrase authentication towards the SSH server instead of username/password. |
| -h, --help | Show program help. |
| -v, --version | Show program version. |
| -p | Client mode only. Connect to specified forwarded port on proxy server. To connect to a different SSH port (not 22), use the hostname:port notation when specifying the SSH proxy's address. |
| -d | Server mode only. Use the specified X session for displaying. The current desktop is usually 0 or 1, but this may vary depending on your settings. |
| --password | Server mode only. Use the specified password for the VNC session. Provides additional security against people logged into the SSH proxy from viewing other sessions. If not specified, a randomly-generated eight-character password will be used. If you do not want a password to be used, use the --no-pw option. |
| --no-pw | Server mode only. Explicitly run the VNC server without a password. |
| --viewonly | Server mode only. Specify that a session is to be viewed only, with mouse and keyboard events not propagated to the target host. |
| --pick-window | Server mode only. Will launch the xwininfo(1) tool for graphically selecting a window to be shared. Remote clients will only be able to see this window. |
| -w, --window-id | Share only window with the specified Window ID. A Window ID is in hex format like 0xaabbccdd which can be obtained through the use of tools such as xwininfo(1). To choose a window without specifying its ID, see the --pick-window option. |

## Installation ##

### Prerequisites ###

Perl 5.6.x or higher with CPAN.

Server mode requirements:
- x11vnc

Client mode requirements:
- vncviewer (eg. TigerVNC)

Optional requirements:
- Xephyr (for creating a nested X session with --new-x-session), available as:
  - xserver-xephyr (Ubuntu/Debian)
  - xorg-x11-server-Xephyr (Red Hat, Fedora)
  - xorg-server-xephyr (Arch).

### Installation instructions ###

See INSTALL file for instructions.

## License ##

This program is free software, licenced under the the BSD licence.
Please see the COPYING file for additional information.

