#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <sstream>
#include "picoev.h"
#include "picojson.h"

unsigned short port = 11111;
int listen_sock;

static void setup_sock(int fd)
{
  int on = 1, r;

  r = setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on));
  assert(r == 0);
  r = fcntl(fd, F_SETFL, O_NONBLOCK);
  assert(r == 0);
}

static void read_cb(picoev_loop* loop, int fd, int revents, void* cb_arg)
{
  char buf[16384];
  
  /* read request */
  assert((revents & PICOEV_READ) != 0);
  int r = read(fd, buf, sizeof(buf));
  if (r == 0) {
    goto CLOSE;
  } else if (r == -1) {
    if (errno == EINTR || errno == EAGAIN) {
      return;
    }
    goto CLOSE;
  }

  /* parse request, should arrive in one packat :-p */
  {
    picojson::value v;
    std::string err;
    picojson::parse(v, (const char *)buf, (const char*)buf+r, &err);
    assert(err.empty());
    picojson::object req = v.get<picojson::object>();

    std::stringstream res_ss;
    res_ss << "{\"error\":null,\"id\":\"";
    res_ss << (int)req["id"].get<double>();
    res_ss << "\",\"result\":";
    res_ss << req["params"].serialize();
    res_ss << "}";

    r = write(fd, res_ss.str().c_str(), res_ss.str().size());
    assert(r == res_ss.str().size());
  }
  
  return;
  
 CLOSE:
  picoev_del(loop, fd);
  close(fd);
}

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

static void accept_cb(picoev_loop* loop, int fd, int revents, void* cb_arg)
{
  int newfd;
  assert((revents & PICOEV_READ) != 0);
  if ((newfd = accept(fd, NULL, NULL)) != -1) {
    setup_sock(newfd);
    picoev_add(loop, newfd, PICOEV_READ, 0, read_cb, NULL);
  }
}

int main(int argc, char** argv)
{
  int ch, r, flag;
  struct sockaddr_in listen_addr;
  picoev_loop* loop;
  
  while ((ch = getopt(argc, argv, "p:")) != -1) {
    switch (ch) {
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
  setup_sock(listen_sock);
  r = listen(listen_sock, SOMAXCONN);
  assert(r == 0);
  
  picoev_init(1048576 + 10);
  loop = picoev_create_loop(60);
  picoev_add(loop, listen_sock, PICOEV_READ, 0, accept_cb, NULL);
  while (1) {
    picoev_loop_once(loop, 10);
  }
  
  return 0;
}
