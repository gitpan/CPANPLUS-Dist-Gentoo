#!perl -T

use strict;
use warnings;

use Test::More tests => 10;

use CPANPLUS::Dist::Gentoo::Maps;

*vc2g  = \&CPANPLUS::Dist::Gentoo::Maps::version_c2g;

is vc2g('1'),       '1',      "version_c2g('1')";
is vc2g('a1b'),     '1',      "version_c2g('a1b')";
is vc2g('..1'),     '1',      "version_c2g('..1')";
is vc2g('1.0'),     '1.0',    "version_c2g('1.0')";
is vc2g('1._0'),    '1.0',    "version_c2g('1._0')";
is vc2g('1_1'),     '1_p1',   "version_c2g('1_1')";
is vc2g('1_.1'),    '1_p1',   "version_c2g('1_.1')";
is vc2g('1_.1._2'), '1_p1.2', "version_c2g('1_.1._2')";
is vc2g('1_.1_2'),  '1_p1.2', "version_c2g('1_.1_2')";
is vc2g('1_.1_.2'), '1_p1.2', "version_c2g('1_.1_.2')";
