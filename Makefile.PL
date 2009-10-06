use inc::Module::Install;

my $poller =   is_linux() ? 'epoll'
             : is_mac()   ? 'kqueue'
             :              'select';
my $picoev = "picoev/picoev_$poller.c";

my $env = env_for_c(CPPPATH => ['picoev/', 'picohttpparser/'], CCFLAGS => '-g');

# client
for my $type (qw/echo http msgpackrpc jsonrpc thrift/) {
    $env->program("test${type}client" => ["test${type}client.c", $picoev]);
}

# picoev based servers
$env->program('picoev_echod' => ["picoev_echod.c", $picoev]);
$env->program('picoev_httpd' => ["picoev_httpd.c", $picoev, 'picohttpparser/picohttpparser.c']);
$env->program('picoev_jsonrpcd' => ["picoev_jsonrpcd.cc", $picoev]);
if ($env->have_library('msgpackc')) {
    $env->program('picoev_msgpackrpcd' => ["picoev_msgpackrpcd.cc", $picoev], LIBS => ['msgpack', 'msgpackc']);
}
if ($env->have_library('thrift')) {
    my $tenv = $env->clone()->parse_config(`pkg-config thrift --cflags --libs`);
    $tenv->program('thrift_simpled' => [map { "thrift/gen-cpp/$_.cpp" } qw/Echo_server-simple Echo/]);
    $tenv->program('thrift_threadd' => [map { "thrift/gen-cpp/$_.cpp" } qw/Echo_server-thread Echo/]);

    if ($env->have_library('event')) {
        my $nbenv = $tenv->clone()->append(LIBS => 'event');
        if ($nbenv->have_library('thriftnb')) {
            $nbenv->program('thrift_nbd' => [map { "thrift/gen-cpp/$_.cpp" } qw/Echo_server-nb Echo/], LIBS => 'thriftnb');
        }
    }
}

# multithreaded servers
{
    my $mtenv = $env->clone();
    $mtenv->append(LIBS => ['pthread']) if is_linux;
    $mtenv->program('mt_echod' => ["mt_echod.c"], LIBS => ['pthread']);
    $mtenv->program('mt_httpd' => ["mt_httpd.c", 'picohttpparser/picohttpparser.c'], LIBS => ['pthread']);
}

WriteMakefileForC();

