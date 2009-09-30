all: testechoclient picoev_echod
clean:
	rm testechoclient picoev_echod

testechoclient: picoev/picoev_epoll.c testechoclient.c
	gcc -O2 -I picoev/ testechoclient.c picoev/picoev_epoll.c -o testechoclient

picoev_echod: picoev_echod.c picoev/picoev_epoll.c
	gcc -O2 -I picoev/ picoev_echod.c picoev/picoev_epoll.c -o picoev_echod

