
all: testechoclient testhttpclient picoev_echod picoev_httpd mt_echod mt_httpd

clean:
	rm testechoclient testhttpclient picoev_echod picoev_httpd mt_echod mt_httpd picoev_httpd.o picoev_echod.o testhttpclient.o mt_httpd.o testechoclient.o picoev/picoev_epoll.o mt_echod.o picohttpparser/picohttpparser.o

testechoclient: picoev/picoev_epoll.o testechoclient.o
	g++  -fstack-protector -o testechoclient picoev/picoev_epoll.o testechoclient.o

picoev/picoev_epoll.o: picoev/picoev_epoll.c
	g++  -I picoev/ -I picohttpparser/ -c -o picoev/picoev_epoll.o picoev/picoev_epoll.c
testechoclient.o: testechoclient.c
	g++  -I picoev/ -I picohttpparser/ -c -o testechoclient.o testechoclient.c
testhttpclient: picoev/picoev_epoll.o testhttpclient.o
	g++  -fstack-protector -o testhttpclient picoev/picoev_epoll.o testhttpclient.o

testhttpclient.o: testhttpclient.c
	g++  -I picoev/ -I picohttpparser/ -c -o testhttpclient.o testhttpclient.c
picoev_echod: picoev/picoev_epoll.o picoev_echod.o
	g++  -fstack-protector -o picoev_echod picoev/picoev_epoll.o picoev_echod.o

picoev_echod.o: picoev_echod.c
	g++  -I picoev/ -I picohttpparser/ -c -o picoev_echod.o picoev_echod.c
picoev_httpd: picoev/picoev_epoll.o picoev_httpd.o picohttpparser/picohttpparser.o
	g++  -fstack-protector -o picoev_httpd picoev/picoev_epoll.o picoev_httpd.o picohttpparser/picohttpparser.o

picoev_httpd.o: picoev_httpd.c
	g++  -I picoev/ -I picohttpparser/ -c -o picoev_httpd.o picoev_httpd.c
picohttpparser/picohttpparser.o: picohttpparser/picohttpparser.c
	g++  -I picoev/ -I picohttpparser/ -c -o picohttpparser/picohttpparser.o picohttpparser/picohttpparser.c
mt_echod: mt_echod.o
	g++ -lpthread -fstack-protector -o mt_echod mt_echod.o

mt_echod.o: mt_echod.c
	g++  -I picoev/ -I picohttpparser/ -c -o mt_echod.o mt_echod.c
mt_httpd: mt_httpd.o picohttpparser/picohttpparser.o
	g++ -lpthread -lpthread -fstack-protector -o mt_httpd mt_httpd.o picohttpparser/picohttpparser.o

mt_httpd.o: mt_httpd.c
	g++  -I picoev/ -I picohttpparser/ -c -o mt_httpd.o mt_httpd.c

