package CPANPLUS::Dist::Gentoo;

use strict;
use warnings;

use Cwd        ();
use List::Util qw/reduce/;
use File::Copy ();
use File::Path ();
use File::Spec;

use IPC::Cmd          ();
use Parse::CPAN::Meta ();

use CPANPLUS::Error ();

use base qw/CPANPLUS::Dist::Base/;

use CPANPLUS::Dist::Gentoo::Atom;
use CPANPLUS::Dist::Gentoo::Guard;
use CPANPLUS::Dist::Gentoo::Maps;

=head1 NAME

CPANPLUS::Dist::Gentoo - CPANPLUS backend generating Gentoo ebuilds.

=head1 VERSION

Version 0.10

=cut

our $VERSION = '0.10';

=head1 SYNOPSIS

    cpan2dist --format=CPANPLUS::Dist::Gentoo \
              --dist-opts overlay=/usr/local/portage \
              --dist-opts distdir=/usr/portage/distfiles \
              --dist-opts manifest=yes \
              --dist-opts keywords=x86 \
              --dist-opts header="# Copyright 1999-2008 Gentoo Foundation" \
              --dist-opts footer="# End" \
              Any::Module You::Like

=head1 DESCRPITON

This module is a CPANPLUS backend that recursively generates Gentoo ebuilds for a given package in the specified overlay (defaults to F</usr/local/portage>), updates the manifest, and even emerges it (together with its dependencies) if the user requires it.
You need write permissions on the directory where Gentoo fetches its source files (usually F</usr/portage/distfiles>).
The valid C<KEYWORDS> for the generated ebuilds are by default those given in C<ACCEPT_KEYWORDS>, but you can specify your own with the C<keywords> dist-option.

The generated ebuilds are placed into the C<perl-gcpanp> category.
They favour depending on a C<virtual>, on C<perl-core>, C<dev-perl> or C<perl-gcpan> (in that order) rather than C<perl-gcpanp>.

=head1 INSTALLATION

Before installing this module, you should append C<perl-gcpanp> to your F</etc/portage/categories> file.

You have two ways for installing this module :

=over 4

=item *

Use the perl overlay located at L<http://git.overlays.gentoo.org/gitweb/?p=proj/perl-overlay.git>.
It contains an ebuild for L<CPANPLUS::Dist::Gentoo>.

=item *

Bootstrap an ebuild for L<CPANPLUS::Dist::Gentoo> using itself.
Note that if your Gentoo system C<perl> is C<5.8.x>, L<CPANPLUS> and its dependencies are not installed and not even available in the main portage tree.
So you need to bootstrap them as well.

First, fetch tarballs for L<CPANPLUS> and L<CPANPLUS::Dist::Gentoo> :

    $ cd /tmp
    $ wget http://search.cpan.org/CPAN/authors/id/B/BI/BINGOS/CPANPLUS-0.9003.tar.gz
    $ wget http://search.cpan.org/CPAN/authors/id/V/VP/VPIT/CPANPLUS-Dist-Gentoo-0.10.tar.gz

Log in as root and unpack them in e.g. your home directory :

    # cd
    # tar xzf /tmp/CPANPLUS-0.9003.tar.gz
    # tar xzf /tmp/CPANPLUS-Dist-Gentoo-0.10.tar.gz

Set up environment variables so that the toolchain is temporarily available :

    # export OLDPATH=$PATH
    # export PATH=/root/CPANPLUS-0.9003/bin:$PATH
    # export PERL5LIB=/root/CPANPLUS-Dist-Gentoo-0.10/blib/lib:/root/CPANPLUS-0.9003/lib:/root/CPANPLUS-0.9003/inc/bundle

Make sure you don't have an old C<.cpanplus> configuration visible :

    # [ -d /root/.cpanplus ] && mv /root/.cpanplus{,.bak}

Bootstrap L<CPANPLUS> :

    # cd /root/CPANPLUS-Dist-Gentoo-0.10
    # samples/g-cpanp CPANPLUS

Reset the environment :

    # export PATH=$OLDPATH
    # unset PERL5LIB OLDPATH

Emerge L<CPANPLUS> with the ebuilds you've just generated :

    # emerge -tv CPANPLUS

As of september 2009, C<podlators> and C<ExtUtils-MakeMaker> may fail to emerge due to collisions.
You can work around this by disabling the C<protect-owned> C<FEATURE> for them :

    # FEATURES="-protect-owned" emerge podlators
    # FEATURES="-protect-owned" emerge ExtUtils-MakeMaker

You may need to run each of these commands two times for them to succeed.

At this point, you can bootstrap L<CPANPLUS::Dist::Gentoo> using the system L<CPANPLUS> :

    # PERL5LIB=/root/CPANPLUS-Dist-Gentoo-0.10/blib/lib samples/g-cpanp CPANPLUS::Dist::Gentoo
    # emerge -tv CPANPLUS-Dist-Gentoo

=back

=head1 METHODS

This module inherits all the methods from L<CPANPLUS::Dist::Base>.
Please refer to its documentation for precise information on what's done at each step.

=cut

use constant CATEGORY => 'perl-gcpanp';

my $overlays;
my $default_keywords;
my $default_distdir;
my $main_portdir;

my %forced;

my $unquote = sub {
 my $s = shift;
 $s =~ s/^["']*//;
 $s =~ s/["']*$//;
 return $s;
};

my $format_available;

sub format_available {
 return $format_available if defined $format_available;

 for my $prog (qw/emerge ebuild/) {
  unless (IPC::Cmd::can_run($prog)) {
   __PACKAGE__->_abort("$prog is required to write ebuilds");
   return $format_available = 0;
  }
 }

 if (IPC::Cmd->can_capture_buffer) {
  my $buffers;
  my ($success, $errmsg) = IPC::Cmd::run(
   command => [ qw/emerge --info/ ],
   verbose => 0,
   buffer  => \$buffers,
  );
  if ($success) {
   if ($buffers =~ /^PORTDIR_OVERLAY=(.*)$/m) {
    $overlays = [ map Cwd::abs_path($_), split ' ', $unquote->($1) ];
   }
   if ($buffers =~ /^ACCEPT_KEYWORDS=(.*)$/m) {
    $default_keywords = [ split ' ', $unquote->($1) ];
   }
   if ($buffers =~ /^DISTDIR=(.*)$/m) {
    $default_distdir = Cwd::abs_path($unquote->($1));
   }
   if ($buffers =~ /^PORTDIR=(.*)$/m) {
    $main_portdir = Cwd::abs_path($unquote->($1));
   }
  } else {
   __PACKAGE__->_abort($errmsg);
  }
 }

 $default_keywords = [ 'x86' ] unless defined $default_keywords;
 $default_distdir  = '/usr/portage/distfiles' unless defined $default_distdir;

 return $format_available = 1;
}

sub init {
 my ($self) = @_;
 my $stat = $self->status;
 my $conf = $self->parent->parent->configure_object;

 $stat->mk_accessors(qw/name version author distribution desc uri src license
                        meta min_perl
                        fetched_arch requires
                        ebuild_name ebuild_version ebuild_dir ebuild_file
                        portdir_overlay
                        overlay distdir keywords do_manifest header footer
                        force verbose/);

 $stat->force($conf->get_conf('force'));
 $stat->verbose($conf->get_conf('verbose'));

 return 1;
}

sub prepare {
 my $self = shift;
 my $mod  = $self->parent;
 my $stat = $self->status;
 my $int  = $mod->parent;
 my $conf = $int->configure_object;

 my %opts = @_;

 my $OK   = sub { $stat->prepared(1); 1 };
 my $FAIL = sub { $stat->prepared(0); $self->_abort(@_) if @_; 0 };
 my $SKIP = sub { $stat->prepared(1); $stat->created(1); $self->_skip(@_) if @_; 1 };

 my $keywords = delete $opts{keywords};
 if (defined $keywords) {
  $keywords = [ split ' ', $keywords ];
 } else {
  $keywords = $default_keywords;
 }
 $stat->keywords($keywords);

 my $manifest = delete $opts{manifest};
 $manifest = 1 unless defined $manifest;
 $manifest = 0 if $manifest =~ /^\s*no?\s*$/i;
 $stat->do_manifest($manifest);

 my $header = delete $opts{header};
 if (defined $header) {
  1 while chomp $header;
  $header .= "\n\n";
 } else {
  my $year = (localtime)[5] + 1900;
  $header = <<"  DEF_HEADER";
# Copyright 1999-$year Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# \$Header: \$
  DEF_HEADER
 }
 $stat->header($header);

 my $footer = delete $opts{footer};
 if (defined $footer) {
  $footer = "\n" . $footer;
 } else {
  $footer = '';
 }
 $stat->footer($footer);

 my $overlay = delete $opts{overlay};
 $overlay = (defined $overlay) ? Cwd::abs_path($overlay) : '/usr/local/portage';
 $stat->overlay($overlay);

 my $distdir = delete $opts{distdir};
 $distdir = (defined $distdir) ? Cwd::abs_path($distdir) : $default_distdir;
 $stat->distdir($distdir);

 return $FAIL->("distdir isn't writable") if $stat->do_manifest && !-w $distdir;

 $stat->fetched_arch($mod->status->fetch);

 my $cur = File::Spec->curdir();
 my $portdir_overlay;
 for (@$overlays) {
  if ($_ eq $overlay or File::Spec->abs2rel($overlay, $_) eq $cur) {
   $portdir_overlay = [ @$overlays ];
   last;
  }
 }
 $portdir_overlay = [ @$overlays, $overlay ] unless $portdir_overlay;
 $stat->portdir_overlay($portdir_overlay);

 my $name = $mod->package_name;
 $stat->name($name);

 my $version = $mod->package_version;
 $stat->version($version);

 my $author = $mod->author->cpanid;
 $stat->author($author);

 $stat->distribution($name . '-' . $version);

 $stat->ebuild_version(CPANPLUS::Dist::Gentoo::Maps::version_c2g($version));

 $stat->ebuild_name(CPANPLUS::Dist::Gentoo::Maps::name_c2g($name));

 $stat->ebuild_dir(File::Spec->catdir(
  $stat->overlay,
  CATEGORY,
  $stat->ebuild_name,
 ));

 my $file = File::Spec->catfile(
  $stat->ebuild_dir,
  $stat->ebuild_name . '-' . $stat->ebuild_version . '.ebuild',
 );
 $stat->ebuild_file($file);

 if ($stat->force) {
  # Always generate an ebuild in our category when forcing
  if ($forced{$file}) {
   $stat->dist($file);
   return $SKIP->('Ebuild already forced for', $stat->distribution);
  }
  ++$forced{$file};
  if (-e $file) {
   unless (-w $file) {
    $stat->dist($file);
    return $SKIP->("Can't force rewriting of $file");
   }
   1 while unlink $file;
  }
 } else {
  if (my $atom = $self->_cpan2portage($name, $version)) {
   $stat->dist($atom->ebuild);
   return $SKIP->('Ebuild already generated for', $stat->distribution);
  }
 }

 $stat->prepared(0);

 $self->SUPER::prepare(@_);

 return $FAIL->() unless $stat->prepared;

 my $desc = $mod->description;
 ($desc = $name) =~ s/-+/::/g unless $desc;
 $stat->desc($desc);

 $stat->uri('http://search.cpan.org/dist/' . $name);

 $author =~ /^(.)(.)/ or return $FAIL->('Wrong author name');
 $stat->src("mirror://cpan/modules/by-authors/id/$1/$1$2/$author/" . $mod->package);

 $stat->license($self->intuit_license);

 my $prereqs = $mod->status->requires;
 my @requires;
 for my $prereq (sort keys %$prereqs) {
  next if $prereq =~ /^perl(?:-|\z)/;
  my $obj = $int->module_tree($prereq);
  next unless $obj; # Not in the module tree (e.g. Config)
  next if $obj->package_is_perl_core;
  {
   my $version;
   if ($prereqs->{$prereq}) {
    if ($obj->installed_version && $obj->installed_version < $obj->version) {
     $version = $obj->installed_version;
    } else {
     $version = $obj->package_version;
    }
   }
   push @requires, [ $obj->package_name, $version ];
  }
 }
 $stat->requires(\@requires);

 $stat->min_perl(CPANPLUS::Dist::Gentoo::Maps::perl_version_c2g(
  eval { $self->meta->{requires}->{perl} }
 ));

 return $OK->();
}

=head2 C<meta>

Returns the contents of the F<META.yml> or F<META.json> files as parsed by L<Parse::CPAN::Meta>.

=cut

sub meta {
 my $self = shift;
 my $mod  = $self->parent;
 my $stat = $self->status;

 my $meta = $stat->meta;
 return $meta if defined $meta;

 my $extract_dir = $mod->status->extract;

 for my $name (qw/META.json META.yml/) {
  my $meta_file = File::Spec->catdir($extract_dir, $name);
  next unless -e $meta_file;

  my $meta = eval { Parse::CPAN::Meta::LoadFile($meta_file) };
  if (defined $meta) {
   $stat->meta($meta);
   return $meta;
  }
 }

 return;
}

=head2 C<intuit_license>

Returns an array reference to a list of Gentoo licences identifiers under which the current distribution is released.

=cut

my %dslip_license = (
 p => 'perl',
 g => 'gpl',
 l => 'lgpl',
 b => 'bsd',
 a => 'artistic',
 2 => 'artistic_2',
);

sub intuit_license {
 my $self = shift;
 my $mod  = $self->parent;

 my $dslip = $mod->dslip;
 if (defined $dslip and $dslip =~ /\S{4}(\S)/) {
  my @licenses = CPANPLUS::Dist::Gentoo::Maps::license_c2g($dslip_license{$1});
  return \@licenses if @licenses;
 }

 my $license = $self->meta->{license};
 if (defined $license) {
  my @licenses = CPANPLUS::Dist::Gentoo::Maps::license_c2g($license);
  return \@licenses if @licenses;
 }

 return [ CPANPLUS::Dist::Gentoo::Maps::license_c2g('perl') ];
}

sub create {
 my $self = shift;
 my $stat = $self->status;

 my $file;

 my $guard = CPANPLUS::Dist::Gentoo::Guard->new(sub {
  if (defined $file and -e $file and -w _) {
   1 while unlink $file;
  }
 });

 my $SIG_INT = $SIG{INT};
 local $SIG{INT} = sub {
  if ($SIG_INT) {
   local $@;
   eval { $SIG_INT->() };
   die $@ if $@;
  }
  die 'Caught SIGINT';
 };

 my $OK   = sub {
  $guard->unarm;
  $stat->created(1);
  $stat->dist($file) if defined $file;
  1;
 };

 my $FAIL = sub {
  $stat->created(0);
  $stat->dist(undef);
  $self->_abort(@_) if @_;
  0;
 };

 unless ($stat->prepared) {
  return $FAIL->(
   'Can\'t create', $stat->distribution, 'since it was never prepared'
  );
 }

 if ($stat->created) {
  $self->_skip($stat->distribution, 'was already created');
  $file = $stat->dist; # Keep the existing one.
  return $OK->();
 }

 my $dir = $stat->ebuild_dir;
 unless (-d $dir) {
  eval { File::Path::mkpath($dir) };
  return $FAIL->("mkpath($dir): $@") if $@;
 }

 $file = $stat->ebuild_file;

 # Create a placeholder ebuild to prevent recursion with circular dependencies.
 {
  open my $eb, '>', $file or return $FAIL->("open($file): $!");
  print $eb "PLACEHOLDER\n";
 }

 $stat->created(0);
 $stat->dist(undef);

 $self->SUPER::create(@_);

 return $FAIL->() unless $stat->created;

 {
  open my $eb, '>', $file or return $FAIL->("open($file): $!");
  my $source = $self->ebuild_source;
  return $FAIL->() unless defined $source;
  print $eb $source;
 }

 return $FAIL->() if $stat->do_manifest and not $self->update_manifest;

 return $OK->();
}

=head2 C<update_manifest>

Updates the F<Manifest> file for the ebuild associated to the current dist object.

=cut

sub update_manifest {
 my $self = shift;
 my $stat = $self->status;

 my $file = $stat->ebuild_file;
 unless (defined $file and -e $file) {
  return $self->_abort('The ebuild file is invalid or does not exist');
 }

 unless (File::Copy::copy($stat->fetched_arch => $stat->distdir)) {
  return $self->_abort("Couldn\'t copy the distribution file to distdir ($!)");
 }

 $self->_notify('Adding Manifest entry for', $stat->distribution);

 return $self->_run([ 'ebuild', $file, 'manifest' ], 0);
}

=head2 C<ebuild_source>

Returns the source of the ebuild for the current dist object, or C<undef> when one of the dependencies couldn't be mapped to an existing ebuild.

=cut

sub ebuild_source {
 my $self = shift;
 my $stat = $self->status;

 # We must resolve the deps now and not inside prepare because _cpan2portage
 # has to see the ebuilds already generated for the dependencies of the current
 # dist.
 my @requires;
 for (@{$stat->requires}) {
  my $atom = $self->_cpan2portage(@$_);
  unless (defined $atom) {
   $self->_abort(
    "Couldn't find an appropriate ebuild for $_->[0] in the portage tree"
   );
   return;
  }
  push @requires, $atom;
 }

 my $min_perl = $stat->min_perl;
 my $perl = CPANPLUS::Dist::Gentoo::Atom->new(
  category => 'dev-lang',
  name     => 'perl',
  (defined $min_perl ? (version => $min_perl, range => '>=') : ()),
 );

 @requires = CPANPLUS::Dist::Gentoo::Atom->fold($perl, @requires);

 my $d = $stat->header;
 $d   .= "# Generated by CPANPLUS::Dist::Gentoo version $VERSION\n\n";
 $d   .= 'MODULE_AUTHOR="' . $stat->author . "\"\ninherit perl-module\n\n";
 $d   .= 'S="${WORKDIR}/' . $stat->distribution . "\"\n";
 $d   .= 'DESCRIPTION="' . $stat->desc . "\"\n";
 $d   .= 'HOMEPAGE="' . $stat->uri . "\"\n";
 $d   .= 'SRC_URI="' . $stat->src . "\"\n";
 $d   .= "SLOT=\"0\"\n";
 $d   .= 'LICENSE="|| ( ' . join(' ', sort @{$stat->license}) . " )\"\n";
 $d   .= 'KEYWORDS="' . join(' ', sort @{$stat->keywords}) . "\"\n";
 $d   .= 'RDEPEND="' . join("\n", sort @requires) . "\"\n";
 $d   .= "DEPEND=\"\${RDEPEND}\"\n";
 $d   .= "SRC_TEST=\"do\"\n";
 $d   .= $stat->footer;

 return $d;
}

sub _cpan2portage {
 my ($self, $name, $version) = @_;

 $name    = CPANPLUS::Dist::Gentoo::Maps::name_c2g($name);
 $version = CPANPLUS::Dist::Gentoo::Maps::version_c2g($version);

 my @portdirs = ($main_portdir, @{$self->status->portdir_overlay});

 for my $category (qw/virtual perl-core dev-perl perl-gcpan/, CATEGORY) {
  my $name = ($category eq 'virtual' ? 'perl-' : '') . $name;

  for my $portdir (@portdirs) {
   my @ebuilds = glob File::Spec->catfile(
    $portdir,
    $category,
    $name,
    "$name-*.ebuild",
   ) or next;

   my $last = reduce { $a < $b ? $b : $a } # handles overloading
               map CPANPLUS::Dist::Gentoo::Atom->new_from_ebuild($_),
                @ebuilds;
   next if defined $version and $last < $version;

   return CPANPLUS::Dist::Gentoo::Atom->new(
    category => $last->category,
    name     => $last->name,
    (defined $version ? (version => $version, range => '>=') : ()),
    ebuild   => $last->ebuild,
   );
  }

 }

 return;
}

sub install {
 my $self = shift;
 my $stat = $self->status;
 my $conf = $self->parent->parent->configure_object;

 my $sudo = $conf->get_program('sudo');
 my @cmd = ('emerge', '=' . $stat->ebuild_name . '-' . $stat->ebuild_version);
 unshift @cmd, $sudo if $sudo;

 my $success = $self->_run(\@cmd, 1);
 $stat->installed($success);

 return $success;
}

sub uninstall {
 my $self = shift;
 my $stat = $self->status;
 my $conf = $self->parent->parent->configure_object;

 my $sudo = $conf->get_program('sudo');
 my @cmd = ('emerge', '-C', '=' . $stat->ebuild_name . '-' . $stat->ebuild_version);
 unshift @cmd, $sudo if $sudo;

 my $success = $self->_run(\@cmd, 1);
 $stat->uninstalled($success);

 return $success;
}

sub _run {
 my ($self, $cmd, $verbose) = @_;
 my $stat = $self->status;

 my ($success, $errmsg, $output) = do {
  local $ENV{PORTDIR_OVERLAY}     = join ' ', @{$stat->portdir_overlay};
  local $ENV{PORTAGE_RO_DISTDIRS} = $stat->distdir;
  IPC::Cmd::run(
   command => $cmd,
   verbose => $verbose,
  );
 };

 unless ($success) {
  $self->_abort($errmsg);
  if (not $verbose and defined $output and $stat->verbose) {
   my $msg = join '', @$output;
   1 while chomp $msg;
   CPANPLUS::Error::error($msg);
  }
 }

 return $success;
}

sub _abort {
 my $self = shift;

 CPANPLUS::Error::error("@_ -- aborting");

 return 0;
}

sub _notify {
 my $self = shift;

 CPANPLUS::Error::msg("@_");

 return 1;
}

sub _skip { shift->_notify(@_, '-- skipping') }

=head1 DEPENDENCIES

Gentoo (L<http://gentoo.org>).

L<CPANPLUS>, L<IPC::Cmd> (core modules since 5.9.5), L<Parse::CPAN::Meta> (since 5.10.1).

L<Cwd>, L<Carp> (since perl 5), L<File::Path> (5.001), L<File::Copy> (5.002), L<File::Spec> (5.00405), L<List::Util> (5.007003).

=head1 SEE ALSO

L<cpan2dist>.

L<CPANPLUS::Dist::Base>, L<CPANPLUS::Dist::Deb>, L<CPANPLUS::Dist::Mdv>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-cpanplus-dist-gentoo at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CPANPLUS-Dist-Gentoo>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CPANPLUS::Dist::Gentoo

=head1 ACKNOWLEDGEMENTS

The module was inspired by L<CPANPLUS::Dist::Deb> and L<CPANPLUS::Dist::Mdv>.

Kent Fredric, for testing and suggesting improvements.

=head1 COPYRIGHT & LICENSE

Copyright 2008,2009,2010 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of CPANPLUS::Dist::Gentoo
