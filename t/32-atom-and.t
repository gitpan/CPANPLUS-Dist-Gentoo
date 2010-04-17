#!perl

use strict;
use warnings;

use Test::More tests => 2 * (2 + (8 * 7) / 2 + 2);

use CPANPLUS::Dist::Gentoo::Atom;

sub A () { 'CPANPLUS::Dist::Gentoo::Atom' }

my $a0 = A->new(
 category => 'test',
 name     => 'a',
);

my $a1 = A->new(
 category => 'test',
 name     => 'a',
 version  => '1.0',
 range    => '=',
);

my $a2 = A->new(
 category => 'test',
 name     => 'a',
 version  => '1.0',
 range    => '<',
);

my $a3 = A->new(
 category => 'test',
 name     => 'a',
 version  => '1.0',
 range    => '<=',
);

my $a4 = A->new(
 category => 'test',
 name     => 'a',
 version  => '2.0',
 range    => '=',
);

my $a5 = A->new(
 category => 'test',
 name     => 'a',
 version  => '2.0',
 range    => '>=',
);

my $a6 = A->new(
 category => 'test',
 name     => 'a',
 version  => '2.0',
 range    => '>',
);

my $x_ver   = qr/Version mismatch/;
my $x_range = qr/Incompatible ranges/;

my @tests = (
 [ [ $a0 ] => $a0 ],
 [ [ $a1 ] => $a1 ],

 [ [ $a0, $a0 ] => $a0 ],
 [ [ $a0, $a1 ] => $a1 ],
 [ [ $a0, $a2 ] => $a2 ],
 [ [ $a0, $a3 ] => $a3 ],
 [ [ $a0, $a4 ] => $a4 ],
 [ [ $a0, $a5 ] => $a5 ],
 [ [ $a0, $a6 ] => $a6 ],

 [ [ $a1, $a1 ] => $a1 ],
 [ [ $a1, $a2 ] => $x_ver ],
 [ [ $a1, $a3 ] => $a1 ],
 [ [ $a1, $a4 ] => $x_ver ],
 [ [ $a1, $a5 ] => $x_ver ],
 [ [ $a1, $a6 ] => $x_ver ],

 [ [ $a2, $a2 ] => $a2 ],
 [ [ $a2, $a3 ] => $a2 ],
 [ [ $a2, $a4 ] => $x_ver ],
 [ [ $a2, $a5 ] => $x_range ],
 [ [ $a2, $a5 ] => $x_range ],

 [ [ $a3, $a3 ] => $a3 ],
 [ [ $a3, $a4 ] => $x_ver ],
 [ [ $a3, $a5 ] => $x_range ],
 [ [ $a3, $a6 ] => $x_range ],

 [ [ $a4, $a4 ] => $a4 ],
 [ [ $a4, $a5 ] => $a4 ],
 [ [ $a4, $a6 ] => $x_ver ],

 [ [ $a5, $a5 ] => $a5 ],
 [ [ $a5, $a6 ] => $a6 ],

 [ [ $a6, $a6 ] => $a6 ],

 [ [ ($a1) x 3 ] => $a1 ],
 [ [ ($a2) x 4 ] => $a2 ],
);

for my $t (@tests) {
 my ($args, $exp) = @$t;

 for my $r (0 .. 1) {
  my @a = @$args;
  @a = reverse @a if $r;

  my $desc = join ' AND ', map "'$_'", @a;

  my $a   = eval { A->and(@a) };
  my $err = $@;

  if (ref $exp eq 'Regexp') {
   like $err, $exp, "$desc should fail";
  } elsif ($err) {
   fail "$desc failed but shouldn't: $err";
  } else {
   ok +($a == $exp), "$desc == '$exp'";
  }
 }
}
