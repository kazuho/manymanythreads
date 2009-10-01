use inc::Nans;

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

