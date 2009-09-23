#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

int num_threads = 10000;
unsigned short port = 11111;
int listen_sock;

void* start_thread(void* _unused)
{
  int fd, r, r2;
  char buf[4096];
  
  while (1) {
    fd = accept(listen_sock, NULL, NULL);
    if (fd == -1)
      continue;
    r2 = 1;
    r = setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &r2, sizeof(r2));
    assert(r == 0);
    
    while (1) {
      r = read(fd, buf, sizeof(buf));
      if (r == 0 || (r == -1 && errno != EINTR)) {
	break;
      }
      r2 = write(fd, buf, r);
      assert(r == r2);
    }
    close(fd);
  }
  
  return NULL;
}

int main(int argc, char** argv)
{
  int ch, i, r, flag;
  struct sockaddr_in listen_addr;
  pthread_attr_t tattr;
  
  while ((ch = getopt(argc, argv, "c:p:")) != -1) {
    switch (ch) {
    case 'c':
      assert(sscanf(optarg, "%d", &num_threads) == 1);
      break;
    case 'p':
      assert(sscanf(optarg, "%hu", &port) == 1);
      break;
    default:
      exit(1);
    }
  }
  
  listen_sock = socket(AF_INET, SOCK_STREAM, 0);
  assert(listen_sock != -1);
  flag = 1;
  r = setsockopt(listen_sock, SOL_SOCKET, SO_REUSEADDR, &flag, sizeof(flag));
  assert(r == 0);
  listen_addr.sin_family = AF_INET;
  listen_addr.sin_port = htons(port);
  listen_addr.sin_addr.s_addr = htonl(INADDR_ANY);
  r = bind(listen_sock, (struct sockaddr*)&listen_addr, sizeof(listen_addr));
  assert(r == 0);
  r = listen(listen_sock, SOMAXCONN);
  assert(r == 0);
  
  pthread_attr_init(&tattr);
  pthread_attr_setstacksize(&tattr, 65536);
  for (i = 0; i < num_threads; ++i) {
    pthread_t tid;
    pthread_create(&tid, &tattr, start_thread, NULL);
  }
  
  while (1) {
    sleep(60);
  }
  
  return 0;
}
