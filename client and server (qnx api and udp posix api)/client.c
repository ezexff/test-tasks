#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/neutrino.h>
#include <sys/iofunc.h>
#include <sys/dispatch.h>
#include <unistd.h>

#define NAME "QNX API Server"
#define BUFFER_SIZE 32

int main(void)
{
    int CoID; // Идентификатор соединения
	char RecvBuffer[BUFFER_SIZE] = {0};
	char SendBuffer[BUFFER_SIZE] = {0};

    // Объявляем имя для соединения с сервером
    if((CoID = name_open(NAME, 0)) == -1)
    {
        perror("name_open()");
        return EXIT_FAILURE;
    }
    printf("client connected to server\n");

    for(;;)
    {
    	// Сообщение гарантированно отправляется локальному микроядру
    	SendBuffer[0] = 'r'; // Запрос сообщения от сервера
    	SendBuffer[1] = 'с'; // Пакет отправляет клиент
        printf("client MsgSend send: %c%c\n", SendBuffer[0], SendBuffer[1]);
    	int MsgSendResult = MsgSend(CoID, &SendBuffer, BUFFER_SIZE, &RecvBuffer, BUFFER_SIZE);
        if(MsgSendResult > 0)
        {
        	printf("client MsgSend recv: %d%c\n", RecvBuffer[0], RecvBuffer[1]);
        }
        else
        {
            perror("client MsgSend() failed");
        }
    	sleep(5);
    }

    name_close(CoID);
    return EXIT_SUCCESS;
}
