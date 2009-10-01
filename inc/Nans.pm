package inc::Nans;
use strict;
use warnings;
use lib 'inc';
use Nans::Env;

our @targets;
our %OBJECTS;
our $postamble;

sub import {
    my $caller = caller(0);
    strict->import;
    warnigns->import;

    no strict 'refs';
    for my $method (qw/env is_linux is_mac WriteMakefile/) {
        *{"${caller}::${method}"} = __PACKAGE__->can($method);
    }
}

sub env {
    Nans::Env->new(@_)
}
sub is_linux { $^O eq 'linux'  }
sub is_mac   { $^O eq 'darwin' }
sub WriteMakefile {
    open my $fh, '>', 'Makefile' or die "cannot open file: $!";
    print $fh <<"...";

all: @Nans::targets

clean:
	rm @Nans::targets @{[ keys %Nans::OBJECTS ]}
	rm Makefile

$Nans::postamble
...
    close $fh;
}

1;
