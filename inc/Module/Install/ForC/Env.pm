#line 1
package Module::Install::ForC::Env;
use strict;
use warnings;
use Storable ();
use Config;

sub new {
    my $class = shift;
    my $opt = {
        CC       => $Config{cc},
        LD       => $Config{ld},
        LDFLAGS  => $Config{ldflags},
        OPTIMIZE => $Config{optimize},
        CCFLAGS  => $Config{ccflags},
        LIBS     => [],
        @_
    };
    $opt->{CPPPATH} = [$opt->{CPPPATH}] unless ref $opt->{CPPPATH};
    bless $opt, $class;
}

sub clone {
    my $self = shift;
    return Storable::dclone($self);
}

sub append {
    my ($self, $key, $val) = @_;

    if ((ref($self->{$key})||'') eq 'ARRAY') {
        push @{ $self->{$key} }, @{$val};
    } else {
        $self->{$key} = $val;
    }
}

sub program {
    my ($self, $bin, $srcs, %specific_opts) = @_;
    my %opts = do {
        my $clone = $self->clone;
        while (my ($key, $val) = each %specific_opts) {
            $clone->append($key => $val);
        }
        %$clone;
    };

    push @Module::Install::ForC::targets, $bin;

    my @objects = map { my $x = $_; $x =~ s/\.c$/\.o/; $x } @$srcs;
    my @libs = map { "-l$_" } @{$opts{LIBS}};

    $Module::Install::ForC::postamble .= <<"...";
$bin: @objects
	$opts{LD} @libs $opts{LDFLAGS} -o $bin @objects

...

    my @cppopts = map { "-I $_" } @{ $opts{CPPPATH} };
    for my $i (0..@$srcs-1) {
        next if $Module::Install::ForC::OBJECTS{$objects[$i]}++ != 0;
        $Module::Install::ForC::postamble .= <<"...";
$objects[$i]: $srcs->[$i]
	$opts{CC} $opts{CCFLAGS} @cppopts -c -o $objects[$i] $srcs->[$i]
...
    }
}

1;
