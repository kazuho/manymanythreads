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
#include "picoev.h"
#include <msgpack.hpp>

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
  msgpack::unpacker m_pac;
  m_pac.reserve_buffer(16384);
  
  /* read request */
  assert((revents & PICOEV_READ) != 0);
  size_t r = read(fd, m_pac.buffer(), m_pac.buffer_capacity());
  if (r == 0) {
    goto CLOSE;
  } else if (r == -1) {
    if (errno == EINTR || errno == EAGAIN) {
      return;
    }
    goto CLOSE;
  }
  m_pac.buffer_consumed(r);

  /* parse request, should arrive in one packat :-p */
  {
    assert(m_pac.execute());
    msgpack::object msg = m_pac.data();
    std::auto_ptr<msgpack::zone> life( m_pac.release_zone() );
    m_pac.reset();

    // deserialize
    std::vector<msgpack::object> rpc;
    msg.convert(&rpc);
    int msgtype;
    rpc.at(0).convert(&msgtype);
    assert(msgtype == 0);
    int msgid;
    rpc.at(1).convert(&msgid);
    std::string strbuf;
    rpc.at(3).convert(&strbuf);

    // serialize
    msgpack::sbuffer buf;
    msgpack::packer<msgpack::sbuffer> packer(buf);
    packer.pack_array(4);
    packer.pack_int(1);
    packer.pack_int(msgid);
    packer.pack_nil();
    packer.pack(strbuf);

    r = write(fd, buf.data(), buf.size());
    assert(r == buf.size());
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
