/* Data::MessagePack->pack([1,1,undef,'hello']); */
#define TEST_CLIENT_RES_SIZE (sizeof("\x94\x01\x01\xc0\xa5\x68\x65\x6c\x6c\x6f") - 1)

/* Data::MessagePack->pack([0,1,'echo','hello']); */
#define TEST_CLIENT_REQ "\x94\x00\x01\xa4\x65\x63\x68\x6f\xa5\x68\x65\x6c\x6c\x6f"

#include "testclient.h"

