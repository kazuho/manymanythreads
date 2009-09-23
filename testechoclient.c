#include <arpa/inet.h>
#include <assert.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <stdio.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
#include "picoev.h"

static int active_connections = 1000;
static int num_connections = 10000;
static int num_requests = 1000000;
static int fix_clients = 0;
static struct in_addr host;
static unsigned short port = 11111;

static int fds[1048576];
static int next_fd_idx = 0;
static int num_responses;

static void read_cb(picoev_loop* loop, int fd, int revents, void* cb_arg)
{
  char buf[6];
  int r;
  
  assert((revents & PICOEV_READ) != 0);
  
  r = read(fd, buf, sizeof(buf));
  assert(r == 6);
  assert(memcmp(buf, "hello\n", 6) == 0);
  ++num_responses;
  
  if (num_responses < num_requests) {
    int wfd;
    if (fix_clients) {
      wfd = fd;
    } else {
      wfd = fds[next_fd_idx];
      next_fd_idx = (next_fd_idx + 1) % num_connections;
    }
    r = write(wfd, "hello\n", 6);
    assert(r == 6);
  }
}

int main(int argc, char** argv)
{
  int ch, i, r;
  picoev_loop* loop;
  struct timeval start_at, end_at;
  double elapsed;
  
  host.s_addr = htonl(0x7f000001);
  
  while ((ch = getopt(argc, argv, "a:c:n:fh:p:")) != -1) {
    switch (ch) {
    case 'a':
      assert(sscanf(optarg, "%d", &active_connections) == 1);
      break;
    case 'c':
      assert(sscanf(optarg, "%d", &num_connections) == 1);
      break;
    case 'n':
      assert(sscanf(optarg, "%d", &num_requests) == 1);
      break;
    case 'f':
      fix_clients = 1;
      break;
    case 'h':
      if (inet_aton(optarg, &host) == 0) {
	struct hostent* h = gethostbyname(optarg);
	assert(h != NULL && "host not found");
	assert(h->h_addrtype == AF_INET);
	assert(h->h_length == sizeof(host));
	memcpy(&host, h->h_addr_list[0], sizeof(host));
      }
      break;
    case 'p':
      assert(sscanf(optarg, "%hu", &port) == 1);
      break;
    default:
      exit(1);
    }
  }
  
  picoev_init(num_connections + 10);
  loop = picoev_create_loop(60);
  
  /* setup connections */
  for (i = 0; i < num_connections; ++i) {
    int on;
    struct sockaddr_in addr;
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    assert(fd != -1 && "socket(2) failed");
    on = 1;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    memcpy(&addr.sin_addr, &host, sizeof(host));
    r = connect(fd, (struct sockaddr*)&addr, sizeof(addr));
    if (r == -1) {
      perror("could not connect to server");
      exit(2);
    }
    r = setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on));
    assert(r == 0);
    r = fcntl(fd, F_SETFL, O_NONBLOCK);
    assert(r == 0);
    picoev_add(loop, fd, PICOEV_READ, 0, read_cb, NULL);
    fds[i] = fd;
    usleep(1000);
  }
  
  gettimeofday(&start_at, NULL);
  
  /* fire first active_connections */
  for (i = 0; i < active_connections; ++i) {
    r = write(fds[next_fd_idx], "hello\n", 6);
    assert(r == 6);
    next_fd_idx = (next_fd_idx + 1) % num_connections;
  }
  /* the main loop */
  while (num_responses < num_requests) {
    picoev_loop_once(loop, 10);
  }
  
  gettimeofday(&end_at, NULL);
  
  elapsed = end_at.tv_sec + end_at.tv_usec / 1000000.0
    - (start_at.tv_sec + start_at.tv_usec / 1000000.0);
  printf("%f reqs./sec. (%d in %f seconds)\n", num_responses / elapsed,
	 num_responses, elapsed);
  
  return 0;
}
