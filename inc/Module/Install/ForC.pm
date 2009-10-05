#line 1
package Module::Install::ForC;
use strict;
use warnings;
our $VERSION = '0.03';
use 5.008000;
use Module::Install::ForC::Env;
use Config;
use File::Basename ();
use FindBin;

use Module::Install::Base;
our @ISA     = qw(Module::Install::Base);

our @TARGETS;
our %OBJECTS;
our $POSTAMBLE;
our @TESTS;
our %INSTALL;

sub env_for_c {
    my $self = shift;
    $self->admin->copy_package('Module::Install::ForC::Env');
    Module::Install::ForC::Env->new(@_)
}
sub is_linux () { $^O eq 'linux'  }
sub is_mac   () { $^O eq 'darwin' }
sub WriteMakefileForC {
    my $self = shift;

    my $src = $self->_gen_makefile();

    open my $fh, '>', 'Makefile' or die "cannot open file: $!";
    print $fh $src;
    close $fh;
}

sub _gen_makefile {
    my $self = shift;
    $self->name(File::Basename::basename($FindBin::Bin)) unless $self->name;
    $self->version('') unless defined $self->version;

    (my $make = <<"...") =~ s/^[ ]{4}/\t/gmsx;
RM=$Config{rm}
NAME=@{[ $self->name ]}
FIRST_MAKEFILE=Makefile
NOECHO=@
TRUE = true
NOOP = \$(TRUE)
PERL = $^X
VERSION = @{[ $self->version ]}
DISTVNAME = \$(NAME)-\$(VERSION)
PREOP = \$(PERL) -I. "-MModule::Install::Admin" -e "dist_preop(q(\$(DISTVNAME)))"
TO_UNIX = \$(NOECHO) \$(NOOP)
TAR = tar
TARFLAGS = cvf
RM_RF = rm -rf
COMPRESS = gzip --best
POSTOP = \$(NOECHO) \$(NOOP)
DIST_DEFAULT = tardist
DIST_CP = best
PERLRUN = \$(PERL)

all: @Module::Install::ForC::TARGETS

test: @TESTS
	prove --exec "/bin/sh -c " @TESTS

dist: \$(DIST_DEFAULT) \$(FIRST_MAKEFILE)

tardist: \$(NAME).tar.gz
    \$(NOECHO) \$(NOOP)

\$(NAME).tar.gz: distdir Makefile
    \$(PREOP)
    \$(TO_UNIX)
    \$(TAR) \$(TARFLAGS) \$(DISTVNAME).tar \$(DISTVNAME)
    \$(RM_RF) \$(DISTVNAME)
    \$(COMPRESS) \$(DISTVNAME).tar
    \$(POSTOP)

distdir:
    \$(RM_RF) \$(DISTVNAME)
    \$(PERLRUN) "-MExtUtils::Manifest=manicopy,maniread" \\
        -e "manicopy(maniread(),'\$(DISTVNAME)', '\$(DIST_CP)');"

clean:
	\$(RM) @Module::Install::ForC::TARGETS @{[ keys %Module::Install::ForC::OBJECTS ]}
	\$(RM) Makefile
	$Config{rm_try}

install: all
	@{[ join("\n\t", map { @{ $_ } } values %Module::Install::ForC::INSTALL) ]}

manifest:
	$^X -MExtUtils::Manifest -e 'ExtUtils::Manifest::mkmanifest()'

@{[ $Module::Install::ForC::POSTAMBLE || '' ]}
...
    $make;
}

1;
__END__

#line 191
