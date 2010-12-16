package CPANPLUS::Dist::Gentoo::Maps;

use strict;
use warnings;

=head1 NAME

CPANPLUS::Dist::Gentoo::Maps - Map CPAN objects to Gentoo and vice versa.

=head1 VERSION

Version 0.11

=cut

our $VERSION = '0.11';

=head1 DESCRPITON

This is an helper package to L<CPANPLUS::Dist::Gentoo>.

=cut

my %name_mismatch;

/^\s*([\w-]+)\s+([\w-]+)\s*$/ and $name_mismatch{$1} = $2 while <DATA>;

close DATA;

=head1 FUNCTIONS

=head2 C<name_c2g $name>

Maps a CPAN distribution name to its Gentoo counterpart.

=cut

sub name_c2g {
 my ($name) = @_;
 return $name_mismatch{$name} || $name;
}

=head2 C<license_c2g @licenses>

Maps F<META.yml> C<license> tag values to the corresponding list of Gentoo licenses identifiers.
Duplicates are stripped off.

The included data was gathered from L<Module::Install> and L<Software::License>.

=cut

my %licenses = (
 apache     => [ 'Apache-2.0' ],
 artistic   => [ 'Artistic' ],
 artistic_2 => [ 'Artistic-2' ],
 bsd        => [ 'BSD' ],
 gpl        => [ 'GPL-1' ],
 gpl2       => [ 'GPL-2' ],
 gpl3       => [ 'GPL-3' ],
 lgpl       => [ 'LGPL-2.1' ],
 lgpl2      => [ 'LGPL-2.1' ],
 lgpl3      => [ 'LGPL-3' ],
 mit        => [ 'MIT' ],
 mozilla    => [ 'MPL-1.1' ],
 perl       => [ 'Artistic', 'GPL-2' ],
);

sub license_c2g {
 my %seen;

 grep !$seen{$_}++,
  map @{$licenses{+lc} || []},
   grep defined,
    @_;
}

=head2 C<version_c2g $name, $version>

Converts the C<$version> of a CPAN distribution C<$name> to a Gentoo version.

=cut

my $default_mapping = sub {
 my ($v) = @_;

 $v =~ s/^v//;
 $v =~ y/-/_/;

 $v =~ s/^[._]*//;
 $v =~ s/[._]*$//;
 $v =~ s/([._])[._]*/$1/g;

 ($v, my $patch) = split /_/, $v, 2;
 if (defined $patch) {
  $patch =~ s/_//g;
  $v .= "_p$patch";
 }

 return $v;
};

my $insert_dot_at = sub {
 my ($v, $pos, $all) = @_;

 my ($int, $frac) = split /\./, $v, 2;
 return $v unless defined $frac;

 my @p;
 push @p, $-[0] while $frac =~ /[0-9]/g;
 my %digit = map { $_ => 1 } @p;

 my $shift = 0;
 for (my $i = $pos; $i < @p; $i += $pos) {
  if ($digit{$i}) {
   substr($frac, $i + $shift, 0) = '.';
   ++$shift;
  }
  last unless $all;
 }

 "$int.$frac";
};

my $insert_dot_at_1     = sub { $insert_dot_at->($_[0], 1, 0) },
my $insert_dot_at_all_1 = sub { $insert_dot_at->($_[0], 1, 1) },
my $insert_dot_at_2     = sub { $insert_dot_at->($_[0], 2, 0) },
my $insert_dot_at_all_2 = sub { $insert_dot_at->($_[0], 2, 1) },
my $insert_dot_at_all_3 = sub { $insert_dot_at->($_[0], 3, 1) },

my $pad_decimals_to = sub {
 my ($v, $n) = @_;

 my ($int, $frac) = split /\./, $v, 2;
 return $v unless defined $v;

 my $l = length $frac;
 if ($l < $n) {
  $frac .= '0' x ($n - $l);
 }

 "$int.$frac";
};

my $pad_decimals_to_2 = sub { $pad_decimals_to->($_[0], 2) };
my $pad_decimals_to_4 = sub { $pad_decimals_to->($_[0], 4) };

my $correct_suffixes = sub {
 my ($v) = @_;

 $v = $default_mapping->($v);
 $v =~ s/(?<!_)((?:alpha|beta|pre|rc|p)\d*)\b/_$1/g;

 return $v;
};

my $strip_letters = sub {
 my ($v) = @_;

 $v = $default_mapping->($v);
 $v =~ s/(?<=\d)[a-z]+//g;

 return $v;
};

my $letters_as_suffix = sub {
 my ($v) = @_;

 $v = $default_mapping->($v);
 $v =~ s/(?<=\d)b(?=\d)/_beta/g;

 return $v;
};

my %version_mismatch;

$version_mismatch{$_} = $insert_dot_at_1 for qw<
 CGI-Simple
>;

$version_mismatch{$_} = $insert_dot_at_all_1 for qw<
 AnyEvent
 Archive-Rar
 IO-AIO
 Image-Size
 Linux-Inotify2
 PadWalker
 Tie-Array-Sorted
 Tk-TableMatrix
 XML-RSS-Feed
>;

$version_mismatch{$_} = $insert_dot_at_2 for qw<
 Error
>;

$version_mismatch{$_} = $insert_dot_at_all_2 for qw<
 Authen-Htpasswd
 BSD-Resource
 CDDB
 Cairo
 Curses-UI
 DBD-mysql
 Email-MessageID
 Exception-Base
 ExtUtils-CBuilder
 ExtUtils-ParseXS
 FileHandle-Unget
 FreezeThaw
 Lexical-Persistence
 Lingua-EN-Inflect
 Mail-Mbox-MessageParser
 Module-Build
 SQL-Abstract-Limit
 Term-ReadLine-Perl
 Test-Differences
 Time-HiRes
 Time-Local
 perl-ldap
>;

$version_mismatch{$_} = $insert_dot_at_all_3 for qw<
 Parse-RecDescent
 Return-Value
>;

$version_mismatch{$_} = $pad_decimals_to_2 for qw<
 Nmap-Parser
 XML-AutoWriter
>;

$version_mismatch{$_} = $pad_decimals_to_4 for qw<
 Convert-BER
>;

$version_mismatch{$_} = $correct_suffixes for qw<
 Gimp
 XML-Grove
>;

$version_mismatch{$_} = $strip_letters for qw<
 DelimMatch
 SGMLSpm
>;

$version_mismatch{$_} = $letters_as_suffix for qw<
 Frontier-RPC
>;

sub version_c2g {
 my ($n, $v) = @_;

 return unless defined $v;

 my $handler;
 $handler = $version_mismatch{$n} if defined $n;
 $handler = $default_mapping  unless defined $handler;

 return $handler->($v);
}

=head2 C<perl_version_c2g $version>

Converts a perl version as you can find it in prerequisites to a Gentoo version number.

=cut

sub perl_version_c2g {
 my ($v) = @_;

 return unless defined $v and $v =~ /^[0-9\.]+$/;

 my @parts;
 if (my ($version, $subversion) = $v =~ /^([0-9]+)\.(0[^\.]+)$/) {
  my $len = length $subversion;
  if (my $pad = $len % 3) {
   $subversion .= '0' x (3 - $pad);
  }
  @parts = ($version, $subversion =~ /(.{1,3})/g);
 } else {
  @parts = split /\./, $v;
 }

 return join '.', map int, @parts;
}

=head1 SEE ALSO

L<CPANPLUS::Dist::Gentoo>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-cpanplus-dist-gentoo at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CPANPLUS-Dist-Gentoo>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CPANPLUS::Dist::Gentoo

=head1 COPYRIGHT & LICENSE

Copyright 2009,2010 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of CPANPLUS::Dist::Gentoo::Maps

__DATA__
ANSIColor               Term-ANSIColor
AcePerl                 Ace
CGI-Simple              Cgi-Simple
CGI-SpeedyCGI           SpeedyCGI
CPAN-Mini-Phalanx100    CPAN-Mini-Phalanx
Cache-Mmap              cache-mmap
Class-Loader            class-loader
Class-ReturnValue       class-returnvalue
Config-General          config-general
Convert-ASCII-Armour    convert-ascii-armour
Convert-PEM             convert-pem
Crypt-CBC               crypt-cbc
Crypt-DES_EDE3          crypt-des-ede3
Crypt-DH                crypt-dh
Crypt-DSA               crypt-dsa
Crypt-IDEA              crypt-idea
Crypt-Primes            crypt-primes
Crypt-RSA               crypt-rsa
Crypt-Random            crypt-random
DBIx-SearchBuilder      dbix-searchbuilder
Data-Buffer             data-buffer
Date-Manip              DateManip
Digest                  digest-base
Digest-BubbleBabble     digest-bubblebabble
Digest-MD2              digest-md2
ExtUtils-Depends        extutils-depends
ExtUtils-PkgConfig      extutils-pkgconfig
Frontier-RPC            frontier-rpc
Gimp                    gimp-perl
Glib                    glib-perl
Gnome2                  gnome2-perl
Gnome2-Canvas           gnome2-canvas
Gnome2-GConf            gnome2-gconf
Gnome2-Print            gnome2-print
Gnome2-VFS              gnome2-vfs-perl
Gnome2-Wnck             gnome2-wnck
Gtk2                    gtk2-perl
Gtk2-Ex-FormFactory     gtk2-ex-formfactory
Gtk2-GladeXML           gtk2-gladexml
Gtk2-Spell              gtk2-spell
Gtk2-TrayIcon           gtk2-trayicon
Gtk2-TrayManager        gtk2-traymanager
Gtk2Fu                  gtk2-fu
I18N-LangTags           i18n-langtags
Image-Info              ImageInfo
Image-Size              ImageSize
Inline-Files            inline-files
Locale-Maketext         locale-maketext
Locale-Maketext-Fuzzy   locale-maketext-fuzzy
Locale-Maketext-Lexicon locale-maketext-lexicon
Log-Dispatch            log-dispatch
Math-Pari               math-pari
Module-Info             module-info
MogileFS-Server         mogilefs-server
NTLM                    Authen-NTLM
Net-Ping                net-ping
Net-SFTP                net-sftp
Net-SSH-Perl            net-ssh-perl
Net-Server              net-server
OLE-Storage_Lite        OLE-StorageLite
Ogg-Vorbis-Header       ogg-vorbis-header
PathTools               File-Spec
Perl-Tidy               perltidy
Pod-Parser              PodParser
Regexp-Common           regexp-common
SDL_Perl                sdl-perl
Set-Scalar              set-scalar
String-CRC32            string-crc32
Text-Autoformat         text-autoformat
Text-Reform             text-reform
Text-Template           text-template
Text-Wrapper            text-wrapper
Tie-EncryptedHash       tie-encryptedhash
Tk                      perl-tk
Wx                      wxperl
XML-Sablotron           XML-Sablot
YAML                    yaml
gettext                 Locale-gettext
txt2html                TextToHTML
