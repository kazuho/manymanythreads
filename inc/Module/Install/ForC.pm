#line 1
package Module::Install::ForC;
use strict;
use warnings;
our $VERSION = '0.01';
use 5.008000;
use Module::Install::ForC::Env;

use Module::Install::Base;
our @ISA     = qw(Module::Install::Base);

our @targets;
our %OBJECTS;
our $postamble;

sub env {
    my $self = shift;
    Module::Install::ForC::Env->new(@_)
}
sub is_linux () { $^O eq 'linux'  }
sub is_mac   () { $^O eq 'darwin' }
sub WriteMakefileForC {
    my $self = shift;

    $self->requires_external_cc();
    $self->admin->copy_package('Module::Install::ForC::Env');

    open my $fh, '>', 'Makefile' or die "cannot open file: $!";
    print $fh <<"...";

all: @Module::Install::ForC::targets

clean:
	rm @Module::Install::ForC::targets @{[ keys %Module::Install::ForC::OBJECTS ]}
	rm Makefile

$Module::Install::ForC::postamble
...
    close $fh;
}


1;
__END__

#line 68
