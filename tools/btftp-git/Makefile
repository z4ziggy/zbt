all: obex.c sdp.c folder.c main.c
	gcc -lbluetooth -lopenobex -lreadline -lxml2 obex.c sdp.c folder.c main.c -o btftp -I/usr/include/libxml2/ -lopenobex-apps-common
