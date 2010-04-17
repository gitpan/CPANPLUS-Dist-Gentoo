#!perl -T

use strict;
use warnings;

use Test::More tests => 10 + 7;

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

*pvc2g = \&CPANPLUS::Dist::Gentoo::Maps::perl_version_c2g;

is pvc2g('5'),       '5',       "perl_version_c2g('5')";
is pvc2g('5.1'),     '5.1',     "perl_version_c2g('5.1')";
is pvc2g('5.01'),    '5.10',    "perl_version_c2g('5.01')";
is pvc2g('5.10'),    '5.10',    "perl_version_c2g('5.10')";
is pvc2g('5.1.2'),   '5.1.2',   "perl_version_c2g('5.1.2')";
is pvc2g('5.01.2'),  '5.1.2',   "perl_version_c2g('5.01.2')";
is pvc2g('5.01002'), '5.10.20', "perl_version_c2g('5.01002')";
