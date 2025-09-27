#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/select.h>

#define PORT 8080
#define SERVER_IP "192.168.174.128"
#define BUFFER_SIZE 32

int main()
{
    int Sockfd; // Дескриптор сокета
    char RecvBuffer[BUFFER_SIZE] = {0};
    char SendBuffer[BUFFER_SIZE] = {0};
    struct sockaddr_in Servaddr;

    // Создаём UDP сокет, где домен AF_INET - IPv4
    if((Sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    {
    	// Функция perror() помещает значение глобальной переменной errno в строку и записывает эту строку в файл stderr.
    	// Если str имеет ненулевое значение, то сначала выводится строка, а за ней следует двоеточие и сообщение об ошибке,
    	// соответствующее значению errno
        perror("socket() failed");
        exit(EXIT_FAILURE);
    }
    memset(&Servaddr, 0, sizeof(Servaddr));

    Servaddr.sin_family = AF_INET;
    Servaddr.sin_port = htons(PORT);
    Servaddr.sin_addr.s_addr = inet_addr(SERVER_IP);

    if(connect(Sockfd, (struct sockaddr *)&Servaddr, sizeof(Servaddr)) < 0)
    {
    	perror("connect() failed");
    }
    else
    {
    	printf("client connected to server\n");

    	// Получаем сообщение от сервера и отправляем ответный пакет, чтобы сервер убедился в том, что сообщение доставлено
		for(;;)
		{
			int RecvSize = recv(Sockfd, (char *)RecvBuffer, BUFFER_SIZE, 0);
			if(RecvSize > 0)
			{
				printf("client recv: %d%c\n", RecvBuffer[0], RecvBuffer[1]);

				SendBuffer[0] = RecvBuffer[0];
				SendBuffer[1] = 'c'; // Пакет отправляет клиент
				send(Sockfd, (char *)SendBuffer, BUFFER_SIZE, 0);
				printf("client send: %d%c\n", SendBuffer[0], SendBuffer[1]);
			}
			sleep(2);
		}
    }

    close(Sockfd);
    return 0;
}
