#!perl
use v5.014;
use utf8;

package CrossView::Simple;

use strict;
use warnings;
use File::Spec::Functions qw(catfile);

my $module    = __PACKAGE__;
(my $dist = $module) =~ s/::/-/g;

my $github    = 'https://github.com/vipera/crossview';
my $main_file = catfile('lib', split /::/, "$module.pm");

my %WriteMakefile = (
	MIN_PERL_VERSION => '5.014',

	NAME => $module,
	VERSION_FROM => $main_file,
	ABSTRACT_FROM => $main_file,
	LICENSE => 'BSD',
	AUTHOR => 'Marin Rukavina <marin@shinyshell.net>',
	EXE_FILES => [ qw(script/crossview) ],
	
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker'   => '6.64',
		'File::Spec::Functions' => '0',
	},
	BUILD_REQUIRES => {
	},
	TEST_REQUIRES => {
	},
	PREREQ_PM => {
		'Term::ReadPassword' => '0',
		'Net::OpenSSH' => '0',
		'Net::EmptyPort' => '0',
	},
	META_MERGE => {
		'meta-spec' => { version => 2 },
		resources => {
			repository => {
				type => 'git',
				url  => "$github.git",
				web  => $github,
			},
			bugtracker => {
				web    => "$github/issues",
			},
			homepage => $github,
		},
	},
);

sub arguments { \%WriteMakefile }

do_it() unless caller;
sub do_it {
	my $MM ='ExtUtils::MakeMaker';
	my $MM_version = eval{ "$MM " .
		$WriteMakefile{'CONFIGURE_REQUIRES'}{'ExtUtils::MakeMaker'} }
		// "$MM 6.64";
	eval "use $MM_version; 1" or die "Could not load $MM_version: $@";

	my $arguments = arguments();
	my $minimum_perl = $arguments->{MIN_PERL_VERSION} || '5.008';
	eval "require $minimum_perl;" or die $@;

	WriteMakefile(%$arguments);
}

no warnings;
__PACKAGE__;