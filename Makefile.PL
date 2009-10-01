use inc::Module::Install;

my $poller =   is_linux() ? 'epoll'
             : is_mac()   ? 'kqueue'
             :              'select';
my $picoev = "picoev/picoev_$poller.c";

my $env = env_for_c(CPPPATH => ['picoev/', 'picohttpparser/']);
$env->program('testechoclient' => ["testechoclient.c", $picoev]);
$env->program('testhttpclient' => ["testhttpclient.c", $picoev]);
$env->program('picoev_echod' => ["picoev_echod.c", $picoev]);
$env->program('picoev_httpd' => ["picoev_httpd.c", $picoev, 'picohttpparser/picohttpparser.c']);
{
    my $mtenv = $env->clone();
    $mtenv->append(LIBS => ['pthread']) if is_linux;
    $mtenv->program('mt_echod' => ["mt_echod.c"], LIBS => ['pthread']);
    $mtenv->program('mt_httpd' => ["mt_httpd.c", 'picohttpparser/picohttpparser.c'], LIBS => ['pthread']);
}

WriteMakefileForC();

