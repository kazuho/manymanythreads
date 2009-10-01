package Nans::Env;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $opt = {
        CC       => 'cc',
        LD       => 'cc',
        LDFLAGS  => '-fstack-protector',
        OPTIMIZE => '-O2 -g',
        CCFLAGS  => '',
        LIBS     => [],
        @_
    };
    $opt->{CPPPATH} = [$opt->{CPPPATH}] unless ref $opt->{CPPPATH};
    bless $opt, $class;
}
sub program {
    my ($self, $bin, $srcs, %specific_opts) = @_;
    my %opts = %$self;
    while (my ($key, $val) = each %specific_opts) {
        if ((ref($opts{$key})||'') eq 'ARRAY') {
            push @{ $opts{$key} }, @{$val};
        } else {
            $opts{$key} = $val;
        }
    }

    push @Nans::targets, $bin;

    my @objects = map { my $x = $_; $x =~ s/\.c$/\.o/; $x } @$srcs;
    my @libs = map { "-l$_" } @{$opts{LIBS}};

    $Nans::postamble .= <<"...";
$bin: @objects
	$opts{LD} @libs $opts{LDFLAGS} -o $bin @objects

...

    my @cppopts = map { "-I $_" } @{ $opts{CPPPATH} };
    for my $i (0..@$srcs-1) {
        next if $Nans::OBJECTS{$objects[$i]}++ != 0;
        $Nans::postamble .= <<"...";
$objects[$i]: $srcs->[$i]
	$opts{CC} $opts{CCFLAGS} @cppopts -c -o $objects[$i] $srcs->[$i]
...
    }
}

1;
