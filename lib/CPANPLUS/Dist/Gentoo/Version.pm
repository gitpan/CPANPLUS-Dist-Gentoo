package CPANPLUS::Dist::Gentoo::Version;

use strict;
use warnings;

=head1 NAME

CPANPLUS::Dist::Gentoo::Version - Gentoo version object.

=head1 VERSION

Version 0.09

=cut

our $VERSION = '0.09';

=head1 DESCRIPTION

This class models Gentoo versions.

=cut

use Scalar::Util ();

use overload (
 '<=>' => \&_spaceship,
 '""'  => \&_stringify,
);

my $int_rx        = qr/\d+/;
my $dotted_num_rx = qr/$int_rx(?:\.$int_rx)*/;

our $version_rx = qr/$dotted_num_rx(?:_p$dotted_num_rx)?(?:-r$int_rx)?/;

=head1 METHODS

=head2 C<new $vstring>

Creates a new L<CPANPLUS::Dist::Gentoo::Version> object from the version string C<$vstring>.

=cut

sub new {
 my $class = shift;
 $class = ref($class) || $class;

 my $vstring = shift;
 if (defined $vstring) {
  $vstring =~ s/^[._]+//g;
  $vstring =~ s/[._]+$//g;
  if ($vstring =~ /^($dotted_num_rx)(?:_p($dotted_num_rx))?(?:-r($int_rx))?$/) {
   return bless {
    string   => $vstring,
    version  => [ split /\.+/, $1 ],
    patch    => [ defined $2 ? (split /\.+/, $2) : () ],
    revision => [ defined $3 ? $3                : () ],
   }, $class;
  }
 }

 require Carp;
 Carp::croak("Couldn't parse version string '$vstring'");
}

my @parts;
BEGIN {
 @parts = qw/version patch revision/;
 eval "sub $_ { \$_[0]->{$_} }" for @parts;
}

=head2 C<version>

Read-only accessor for the C<version> part of the version object.

=head2 C<patch>

Read-only accessor for the C<patch> part of the version object.

=head2 C<revision>

Read-only accessor for the C<revision> part of the version object.

=cut

sub _spaceship {
 my ($v1, $v2, $r) = @_;

 unless (Scalar::Util::blessed($v2) and $v2->isa(__PACKAGE__)) {
  $v2 = $v1->new($v2);
 }

 ($v1, $v2) = ($v2, $v1) if $r;

 for (@parts) {
  my @a = @{ $v1->$_ };
  my @b = @{ $v2->$_ };
  while (@a or @b) {
   my $x = shift(@a) || 0;
   my $y = shift(@b) || 0;
   my $c = $x <=> $y;
   return $c if $c;
  }
 }

 return 0;
}

sub _stringify {
 my ($v) = @_;

 my ($version, $patch, $revision) = map $v->$_, @parts;

 $version  = join '.', @$version;
 $version .= '_p' . join('.', @$patch)    if @$patch;
 $version .= '-r' . join('.', @$revision) if @$revision;

 $version;
}

=pod

This class provides overloaded methods for numerical comparison and strigification.

=head1 SEE ALSO

L<CPANPLUS::Dist::Gentoo>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-cpanplus-dist-gentoo at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CPANPLUS-Dist-Gentoo>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CPANPLUS::Dist::Gentoo

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of CPANPLUS::Dist::Gentoo::Version
