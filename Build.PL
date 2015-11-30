#!perl
package CrossView::Simple;

use strict;
use warnings;

my $abstract = 'Wrapper for a VNC/SSH server and viewer';
my $github   = 'https://github.com/vipera/crossview';

use File::Spec::Functions qw(catfile);

my $module    = __PACKAGE__;
(my $dist = $module) =~ s/::/-/g;
my $main_file = catfile('lib', split /::/, "$module.pm");

use Module::Build;
my $build = Module::Build->new(
	module_name => $module,
	dist_abstract => $abstract,
	dist_author => 'Marin Rukavina <marin@shinyshell.net>',
	license => 'bsd',
	requires => {
		'perl' => '5.6.1',

		'Term::ReadPassword' => 0,
		'Net::OpenSSH' => 0,
		'Net::EmptyPort' => 0,

		'IO::Pty' => 0,
	},
	script_files => [ qw(script/crossview) ],
);
$build->create_build_script;