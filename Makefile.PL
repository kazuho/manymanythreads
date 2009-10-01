use strict;
use warnings;

my $poller =   is_linux() ? 'epoll'
             : is_mac()   ? 'kqueue'
             :              'select';

my $env = env(CPPPATH => ['picoev/', 'picohttpparser/'], LD => 'g++', CC => 'g++');
$env->program('testechoclient' => ["picoev/picoev_$poller.c", "testechoclient.c"]);
$env->program('testhttpclient' => ["picoev/picoev_$poller.c", "testhttpclient.c"]);
$env->program('picoev_echod' => ["picoev/picoev_$poller.c", "picoev_echod.c"]);
$env->program('picoev_httpd' => ["picoev/picoev_$poller.c", "picoev_httpd.c", 'picohttpparser/picohttpparser.c']);
$env->program('mt_echod' => ["mt_echod.c"], LIBS => ['pthread']);
$env->program('mt_httpd' => ["mt_httpd.c", 'picohttpparser/picohttpparser.c'], LIBS => ['pthread']);

WriteMakefile();
exit;

my @targets;
my %OBJECTS;
my $postamble = '';

sub env {
    Env->new(@_);
}
sub is_linux { $^O eq 'linux'  }
sub is_mac   { $^O eq 'darwin' }
sub WriteMakefile {
    open my $fh, '>', 'Makefile' or die "cannot open file: $!";
    print $fh <<"...";

all: @targets

clean:
	rm @targets @{[ keys %OBJECTS ]}

$postamble
...
}

package Env;

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

    push @targets, $bin;

    my @objects = map { my $x = $_; $x =~ s/\.c$/\.o/; $x } @$srcs;
    my @libs = map { "-l$_" } @{$opts{LIBS}};

    $postamble .= <<"...";
$bin: @objects
	$opts{LD} @libs $opts{LDFLAGS} -o $bin @objects

...

    my @cppopts = map { "-I $_" } @{ $opts{CPPPATH} };
    for my $i (0..@$srcs-1) {
        next if $OBJECTS{$objects[$i]}++ != 0;
        $postamble .= <<"...";
$objects[$i]: $srcs->[$i]
	$opts{CC} $opts{CCFLAGS} @cppopts -c -o $objects[$i] $srcs->[$i]
...
    }
}


