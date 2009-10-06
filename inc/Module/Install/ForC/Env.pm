#line 1
package Module::Install::ForC::Env;
use strict;
use warnings;
use Storable ();
use Config;
use File::Temp ();
use POSIX;
use Text::ParseWords ();

sub DEBUG () { $ENV{DEBUG} }

sub new {
    my $class = shift;

    # platform specific vars
    my %platformvars = do {
        my %unix = (
            CC  => $ENV{CC}  || 'gcc',
            CPP => $ENV{CPP} || 'cpp',
            CXX => $ENV{CXX} || 'g++',
            PREFIX        => $ENV{PREFIX} || '/usr/',
            LIBPREFIX     => 'lib',
            LIBSUFFIX     => '.a',
            SHLIBPREFIX   => 'lib',
            LDMODULEFLAGS => ['-shared'],
            CCDLFLAGS     => ['-fPIC'], # TODO: rename
        );
        my %win32 = (
            CC  => $ENV{CC}  || 'gcc',
            CPP => $ENV{CPP} || 'cpp',
            CXX => $ENV{CXX} || 'g++',
            PREFIX      => 'C:\\',
            LIBPREFIX   => '',
            LIBSUFFIX   => '.lib',
            SHLIBPREFIX => '',
            CCDLFLAGS   => [], # TODO: rename
        );
        my %darwin = ( LDMODULEFLAGS => ['-dynamiclib'], );
        my %solaris = (
            CCDLFLAGS     => ['-kPIC'],
            LDMODULEFLAGS => ['-G'],
        );

          $^O eq 'MSWin32'  ? %win32
        : $^O eq 'darwin'   ? (%unix, %darwin)
        : $^O eq 'solaris'  ? (%unix, %solaris)
        : %unix;
    };

    my $opt = {
        LD            => $Config{ld},
        LDFLAGS       => '',
        CCFLAGS       => [],
        CPPPATH       => [],
        LIBS          => [],
        LIBPATH       => [],
        SHLIBSUFFIX   => '.' . $Config{so},
        RANLIB        => 'ranlib',
        PROGSUFFIX    => ( $Config{exe_ext} ? ( '.' . $Config{exe_ext} ) : '' ),
        CXXFILESUFFIX => [ '.c++', '.cc', '.cpp', '.cxx' ],
        CFILESUFFIX   => ['.c'],
        AR            => $Config{ar},
        %platformvars,
        @_
    };
    for my $key (qw/CPPPATH LIBS CLIBPATH LDMODULEFLAGS CCFLAGS/) {
        $opt->{$key} = [$opt->{$key}] unless ref $opt->{$key};
    }
    my $self = bless $opt, $class;

    # fucking '.C' extension support.
    if ($^O eq 'Win32' || $^O eq 'darwin') {
        # case sensitive fs.Yes, I know the darwin supports case-sensitive fs.
        # But, also supports case-insensitive one :)
        push @{$self->{CFILESUFFIX}}, '.C';
    } else {
        push @{$self->{CXXFILESUFFIX}}, '.C';
    }

    return $self;
}

# pkg-config
sub parse_config {
    my ($self, $str) = @_;
    my @words = Text::ParseWords::shellwords($str);
    for (my $i=0; $i<@words; $i++) {
        local $_ = $words[$i];
        s/^-I// and do {
            $self->append('CPPPATH' => $_ || $words[++$i]);
            next;
        };
        s/^-L// and do {
            $self->append('LIBPATH' => $_ || $words[++$i]);
            next;
        };
        s/^-l// and do {
            $self->append('LIBS' => $_ || $words[++$i]);
            next;
        };
    }
    return $self;
}

sub install_bin {
    my ($self, $bin) = @_;
    $self->install($bin, 'bin');
}
sub install_lib {
    my ($self, $lib) = @_;
    $self->install($lib, 'lib');
}
sub install {
    my ($self, $target, $suffix) = @_;
    my $dst = File::Spec->catfile($self->{PREFIX}, $suffix);
    ($target =~ m{['"\n\{\}]}) and die "invalid file name for install: $target";
    ($suffix =~ m{['"\n\{\}]}) and die "invalid file name for install: $suffix";
    push @{$Module::Install::ForC::INSTALL{$suffix}}, "\$(PERL) -e 'use File::Copy; File::Copy::copy(q{$target}, q{$dst}) or die qq{Copy failed: $!}'";
}

sub try_cc {
    my ($self, $src) = @_;
    my ( $ch, $cfile ) = File::Temp::tempfile(
        'assertlibXXXXXXXX',
        SUFFIX => '.c',
        UNLINK => 1,
    );
    print $ch $src;
    my $cmd = "$self->{CC} @{[ $self->_libs ]} @{[ $self->_cpppath ]} @{ $self->{CCFLAGS} } $cfile";
    print "$cmd\n" if DEBUG;
    my $exit_status = _quiet_system($cmd);
    WIFEXITED($exit_status) && WEXITSTATUS($exit_status) == 0 ? 1 : 0;
}

# code substantially borrowed from IPC::Run3                                                                                          
sub _quiet_system {
    my (@cmd) = @_;

    # save handles
    local *STDOUT_SAVE;
    local *STDERR_SAVE;
    open STDOUT_SAVE, ">&STDOUT" or die "CheckLib: $! saving STDOUT";
    open STDERR_SAVE, ">&STDERR" or die "CheckLib: $! saving STDERR";

    # redirect to nowhere
    local *DEV_NULL;
    open DEV_NULL, ">" . File::Spec->devnull
      or die "CheckLib: $! opening handle to null device";
    open STDOUT, ">&" . fileno DEV_NULL
      or die "CheckLib: $! redirecting STDOUT to null handle";
    open STDERR, ">&" . fileno DEV_NULL
      or die "CheckLib: $! redirecting STDERR to null handle";

    # run system command
    my $rv = system(@cmd);

    # restore handles
    open STDOUT, ">&" . fileno STDOUT_SAVE
      or die "CheckLib: $! restoring STDOUT handle";
    open STDERR, ">&" . fileno STDERR_SAVE
      or die "CheckLib: $! restoring STDERR handle";

    return $rv;
}


sub have_header {
    my ($self, $header,) = @_;
    _checking_for(
        "C header $header",
        $self->try_cc("#include <$header>\nint main() { return 0; }")
    );
}

sub _checking_for {
    my ($msg, $result) = @_;
    print "Checking for $msg ... @{[ $result ? 'yes' : 'no' ]}\n";
    return $result;
}

sub have_library {
    my ($self, $library,) = @_;
    _checking_for(
        "C library $library",
        $self->clone()->append( 'LIBS' => $library )->try_cc("int main(){return 0;}")
    );
}

sub clone {
    my ($self, ) = @_;
    return Storable::dclone($self);
}

sub append {
    my $self = shift;
    while (my ($key, $val) = splice(@_, 0, 2)) {
        if ((ref($self->{$key})||'') eq 'ARRAY') {
            $val = [$val] unless ref $val;
            push @{ $self->{$key} }, @{$val};
        } else {
            $self->{$key} = $val;
        }
    }
    return $self; # for chain
}

sub _objects {
    my ($self, $srcs) = @_;
    my @objects;
    my $regex = join('|', map { quotemeta($_) } @{$self->{CXXFILESUFFIX}}, @{$self->{CFILESUFFIX}});
    for my $src (@$srcs) {
        if ((my $obj = $src) =~ s/$regex/$Config{obj_ext}/) {
            push @objects, $obj;
        } else {
            die "unknown src file type: $src";
        }
    }
    @objects;
}

sub _libs {
    my $self = shift;
    return map { "-l$_" } @{$self->{LIBS}};
}

sub _libpath {
    my $self = shift;
    return join ' ', map { "-L$_" } @{$self->{LIBPATH}};
}

sub program {
    my ($self, $bin, $srcs, %specific_opts) = @_;
    $srcs = [$srcs] unless ref $srcs;
    my $clone = $self->clone()->append(%specific_opts);

    my $target = "$bin" . $clone->{PROGSUFFIX};
    _push_target($target);
    push @Module::Install::ForC::TESTS, $target if $target =~ m{^t/};

    my @objects = $clone->_objects($srcs);

    my $ld = $clone->_ld(@$srcs);

    $self->_push_postamble(<<"...");
$target: @objects
	$ld $clone->{LDFLAGS} -o $target @objects @{[ $clone->_libpath ]} @{[ $clone->_libs ]}

...

    $clone->_compile_objects($srcs, \@objects, '');

    return $target;
}

sub _is_cpp {
    my ($self, $src) = @_;
    my $pattern = join('|', map { quotemeta($_) } @{$self->{CXXFILESUFFIX}});
    $src =~ qr/$pattern$/ ? 1 : 0;
}

sub _push_postamble {
    $Module::Install::ForC::POSTAMBLE .= $_[1];
}

sub _cpppath {
    my $self = shift;
    join ' ', map { "-I $_" } @{ $self->{CPPPATH} };
}

sub _compile_objects {
    my ($self, $srcs, $objects, $opt) = @_;
    $opt ||= '';

    for my $i (0..@$srcs-1) {
        next if $Module::Install::ForC::OBJECTS{$objects->[$i]}++ != 0;
        my $compiler = $self->_is_cpp($srcs->[$i]) ? $self->{CXX} : $self->{CC};
        $self->_push_postamble(<<"...");
$objects->[$i]: $srcs->[$i] Makefile
	$compiler $opt @{ $self->{CCFLAGS} } @{[ $self->_cpppath ]} -c -o $objects->[$i] $srcs->[$i]

...
    }
}

sub _ld {
    my ($self, @srcs) = @_;
    (scalar(grep { $self->_is_cpp($_) } @srcs) > 0) ? $self->{CXX} : $self->{LD};
}

sub _push_target {
    my $target = shift;
    push @Module::Install::ForC::TARGETS, $target;
}

sub shared_library {
    my ($self, $lib, $srcs, %specific_opts) = @_;
    $srcs = [$srcs] unless ref $srcs;
    my $clone = $self->clone->append(%specific_opts);

    my $target = "$clone->{SHLIBPREFIX}$lib$clone->{SHLIBSUFFIX}";

    _push_target($target);

    my @objects = $clone->_objects($srcs);

    my $ld = $clone->_ld(@$srcs);
    $self->_push_postamble(<<"...");
$target: @objects Makefile
	$ld @{ $clone->{LDMODULEFLAGS} } @{[ $clone->_libpath ]} @{[ $clone->_libs ]} $clone->{LDFLAGS} -o $target @objects

...
    $clone->_compile_objects($srcs, \@objects, @{$self->{CCCDLFLAGS}});

    return $target;
}

sub static_library {
    my ($self, $lib, $srcs, %specific_opts) = @_;
    $srcs = [$srcs] unless ref $srcs;
    my $clone = $self->clone->append(%specific_opts);

    my $target = "$clone->{LIBPREFIX}$lib$clone->{LIBSUFFIX}";

    _push_target($target);

    my @objects = $clone->_objects($srcs);

    $self->_push_postamble(<<"...");
$target: @objects Makefile
	$clone->{AR} rc $target @objects
	$clone->{RANLIB} $target

...
    $clone->_compile_objects($srcs, \@objects, @{$self->{CCCDLFLAGS}});

    return $target;
}

sub have_type {
    my ($self, $type, $src) = @_;
    $src ||= '';

    $self->try_cc(<<"...");
$src

int main() {
    if ( ( $type * ) 0 ) return 0;
    if ( sizeof($type) ) return 0;
    return 0;
}
...
}

1;
__END__

#line 453
