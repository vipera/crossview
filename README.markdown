# CrossView VNC/SSH server and viewer #

A program that allows a tunneled SSH connection to a proxy server by a server and
a client and the exchange of VNC traffic via that connection.

## Description ##

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

## Installation ##

### Prerequisites ###

Perl 5.014+

Server mode requirements:
- x11vnc

Client mode requirements:
- vncviewer (eg. TigerVNC)

### Installation instructions ###



## License ##
This program is free software, licenced under the the BSD licence.
Please see the COPYING file for additional information.

