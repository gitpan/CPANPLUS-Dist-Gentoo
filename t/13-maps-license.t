#!perl -T

use strict;
use warnings;

use Test::More tests => 4;

use CPANPLUS::Dist::Gentoo::Maps;

sub check_licenses {
 my @licenses = CPANPLUS::Dist::Gentoo::Maps::license_c2g(@{$_[0]});
 is_deeply \@licenses, $_[1], $_[2];
}

check_licenses [ 'woo' ],         [ ],                        'nonexistent';
check_licenses [ 'perl' ],        [ qw/Artistic GPL-2/ ],     'perl';
check_licenses [ qw/perl gpl2/ ], [ qw/Artistic GPL-2/ ],     'perl + gpl2';
check_licenses [ qw/perl bsd/ ],  [ qw/Artistic GPL-2 BSD/ ], 'perl + bsd';
