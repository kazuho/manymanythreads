use inc::Nans;

my $poller =   is_linux() ? 'epoll'
             : is_mac()   ? 'kqueue'
             :              'select';

my $env = env(CPPPATH => ['picoev/', 'picohttpparser/'], LD => 'cc', CC => 'cc');
$env->program('testechoclient' => ["testechoclient.c", "picoev/picoev_$poller.c"]);
$env->program('testhttpclient' => ["testhttpclient.c", "picoev/picoev_$poller.c"]);
$env->program('picoev_echod' => ["picoev_echod.c", "picoev/picoev_$poller.c"]);
$env->program('picoev_httpd' => ["picoev_httpd.c", "picoev/picoev_$poller.c", 'picohttpparser/picohttpparser.c']);
{
    my $mtenv = $env->clone();
    $mtenv->append(LIBS => ['pthread']) if is_linux;
    $mtenv->program('mt_echod' => ["mt_echod.c"], LIBS => ['pthread']);
    $mtenv->program('mt_httpd' => ["mt_httpd.c", 'picohttpparser/picohttpparser.c'], LIBS => ['pthread']);
}

WriteMakefile();

