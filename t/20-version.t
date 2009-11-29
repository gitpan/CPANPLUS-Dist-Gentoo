#!perl -T

use strict;
use warnings;

use Test::More tests => 2 + 21 * (3 + 2);

use CPANPLUS::Dist::Gentoo::Version;

sub V () { 'CPANPLUS::Dist::Gentoo::Version' }

eval { V->new('dongs') };
like $@, qr/Couldn't\s+parse\s+version\s+string/, "V->('dongs')";

eval { my $res = 'dongs' < V->new(1) };
like $@, qr/Couldn't\s+parse\s+version\s+string/, "'dongs' < V->new(1)";

my @tests = (
 [ 0, 0,  0 ],
 [ 1, 0,  1 ],
 [ 0, 1, -1 ],
 [ 1, 1,  0 ],

 [ '1.0', 1,      0 ],
 [ '1.1', 1,      1 ],
 [ '1.1', '1.0',  1 ],
 [ 1,     '1.0',  0 ],
 [ 1,     '1.1', -1 ],
 [ '1.0', '1.1', -1 ],

 [ '1.0_p0',   '1.0_p0',    0 ],
 [ '1.0_p0',   '1.0_p1',   -1 ],
 [ '1.1_p0',   '1.0_p1',    1 ],
 [ '1.1_p0',   '1.1_p0.1', -1 ],
 [ '1.1_p0.1', '1.1_p0.1',  0 ],

 [ '1.2_p0-r0', '1.2_p0',  0 ],
 [ '1.2_p0-r1', '1.2_p0',  1 ],
 [ '1.2-r0',    '1.2_p0',  0 ],
 [ '1.2-r1',    '1.2_p0',  1 ],
 [ '1.2-r1',    '1.2_p1', -1 ],
 [ '1.2-r2',    '1.2_p1', -1 ],
);

for (@tests) {
 my ($s1, $s2, $res) = @$_;

 my $v1 = V->new($s1);
 my $v2 = V->new($s2);

 is $s1 <=> $v2, $res, "'$s1' <=> V->new('$s2')";
 is $v1 <=> $s2, $res, "V->new('$s1') <=> '$s2'";
 is $v1 <=> $v2, $res, "V->new('$s1') <=> V->new('$s2')";

 cmp_ok "$v1", 'eq', $s1, "V->new('$s1') eq '$s1'";
 cmp_ok "$v2", 'eq', $s2, "V->new('$s2') eq '$s2'";
}
