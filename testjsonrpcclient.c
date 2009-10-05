#define TEST_CLIENT_RES_SIZE (sizeof("{\"error\":null,\"id\":\"1\",\"result\":[\"hello\"]}") - 1)

#define TEST_CLIENT_REQ "{\"method\":\"echo\",\"params\":[\"hello\"],\"id\":1}"

#include "testclient.h"

