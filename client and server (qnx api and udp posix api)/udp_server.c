#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define PORT 8080
#define BUFFER_SIZE 32

int main()
{
    int Sockfd; // ���������� ������
	char RecvBuffer[BUFFER_SIZE] = {0};
	char SendBuffer[BUFFER_SIZE] = {0};
    struct sockaddr_in ServAddr, CliAddr;

    // ������ UDP �����, ��� ����� AF_INET - IPv4
    if((Sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    {
        perror("socket() failed");
        exit(EXIT_FAILURE);
    }
    memset(&ServAddr, 0, sizeof(ServAddr));
    memset(&CliAddr, 0, sizeof(CliAddr));

    // ���������� � ������� ��� ����������� ��������

    ServAddr.sin_family = AF_INET; // IPv4
    ServAddr.sin_addr.s_addr = INADDR_ANY; // ������������� ���� �������
    ServAddr.sin_port = htons(PORT);

    // ����������� ����� � ������ �������
    if(bind(Sockfd, (struct sockaddr *)&ServAddr, sizeof(ServAddr)) < 0)
    {
        perror("bind() failed");
        exit(EXIT_FAILURE);
    }

    // �������� �����, ��������� � Sockfd ��� ���������, �� ���� ��� �����,
    // ������� ����� �������������� ��� ����� �������� �������� ���������� � ������� accept
    int ListenSockfd = listen(Sockfd, SOMAXCONN);
    if(ListenSockfd < 0)
    {
    	perror("listen() failed");
    	exit(EXIT_FAILURE);
    }
    printf("server wait client\n");
    socklen_t SizeOfCliAddr = sizeof(CliAddr);
    int CliSockfd = accept(Sockfd, (struct sockaddr *)&CliAddr, &SizeOfCliAddr);
    if(CliSockfd < 0)
    {
        perror("accept() failed");
        exit(EXIT_FAILURE);
    }

    // ���� ���������� �����������, �� ���������� ��������� �������
    int ID = 1; // ���������� ������������� ������������ �������
    for(;;)
    {
		// �������� ���������� ������ sendto() �� ����������� �������� ���������
		// ������������ �������� -1 ������������� ������ � ��������� �������
    	SendBuffer[0] = ID; // ���������� ������������� ������
    	SendBuffer[1] = 's'; // ����� ���������� ������
		if(sendto(CliSockfd, (char *)SendBuffer, BUFFER_SIZE, 0, (struct sockaddr *)&CliAddr, SizeOfCliAddr) > 0)
		{
			printf("server send: %d%c\n", SendBuffer[0], SendBuffer[1]);

			// �������� ����� �� ������������ ��������� � ���� ����� ���������������, �� ������ ��������� ���� ���������� �������
			int RecvSize = recvfrom(CliSockfd, (char *)RecvBuffer, BUFFER_SIZE, MSG_WAITALL, (struct sockaddr *)&CliAddr, &SizeOfCliAddr);
			if(RecvSize > 0)
			{
				printf("server recv: %d%c\n", RecvBuffer[0], RecvBuffer[1]);
				if(RecvBuffer[0] == SendBuffer[0])
				{
					ID++;
					printf("send packet success\n");
				}
				else
				{
					printf("echo failed (sendbuf=%d%c, readbuf=%d%c)", SendBuffer[0], SendBuffer[1], RecvBuffer[0], RecvBuffer[1]);
				}
			}
			else
			{
				perror("recv() echo failed");
			}
		}
		else
		{
			perror("sendto() failed");
			break;
		}
    }

    close(Sockfd);
    return EXIT_SUCCESS;
}
