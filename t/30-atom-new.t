#!perl

use strict;
use warnings;

use Test::More tests => 15;

use CPANPLUS::Dist::Gentoo::Atom;

sub A () { 'CPANPLUS::Dist::Gentoo::Atom' }

my $no_info      = qr/^Not enough information/;
my $range_no_ver = qr/^Range atoms require a valid version/;
my $inv_atom     = qr/^Invalid atom/;
my $inv_ebuild   = qr/^Invalid ebuild/;

my $a0 = { category => 'test', name => 'a' };
my $a1 = { category => 'test', name => 'a', version => '1.0' };

my @tests = (
 [ { }                     => $no_info ],
 [ { category => 'test' }  => $no_info ],
 [ $a0                     => $a0 ],
 [ { %$a0, range => '<=' } => $range_no_ver ],
 [ $a1                     => { %$a1, range => '=' } ],
 [ { %$a1, range => '<=' } => { %$a1, range => '<=' } ],

 [ { atom => 'test/a' }        => $a0 ],
 [ { atom => 'test/a-1.0' }    => { %$a1, range => '=' } ],
 [ { atom => '>=test/a-v1.0' } => { %$a1, range => '>=' } ],
 [ { atom => '=<test/a-v1.0' } => $inv_atom ],
 [ { atom => '>=test/a' }      => $range_no_ver ],

 [ { ebuild => undef }                      => $inv_ebuild ],
 [ { ebuild => '/wat/test/a/a.ebuild' }     => $inv_ebuild ],
 [ { ebuild => '/wat/test/a/a-1.0.ebuild' } => { %$a1, range => '=' } ],
 [ { ebuild => '/wat/test/a/b-1.0.ebuild' } => $inv_ebuild ],
);

my @fields = qw/range category name version ebuild/;

for my $t (@tests) {
 my ($args, $exp) = @$t;

 my ($meth, @args);
 if (exists $args->{ebuild}) {
  $meth = 'new_from_ebuild';
  @args = ($args->{ebuild});
 } else {
  $meth = 'new';
  @args = %$args;
 }

 my $atom = eval { A->$meth(@args) };
 my $err  = $@;

 if (ref $exp eq 'Regexp') {
  like $err, $exp;
 } elsif ($err) {
  fail $err;
 } else {
  $exp = { %$exp };
  for (@fields) {
   next if exists $exp->{$_};
   $exp->{$_} = ($_ eq 'ebuild' and exists $args->{ebuild})
                ? $args->{ebuild}
                : undef;
  }
  is_deeply {
   map { my $val = $atom->$_; $_ => (defined $val ? "$val" : undef) } @fields
  }, $exp;
 }
}
