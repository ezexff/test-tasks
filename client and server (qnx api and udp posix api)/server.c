#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/neutrino.h>
#include <sys/iofunc.h>
#include <sys/dispatch.h>
#include <errno.h>

#define NAME "QNX API Server"
#define BUFFER_SIZE 32

int main(void)
{
    name_attach_t *Attach; // Дескриптор записи в пространстве имен
    char RecvBuffer[BUFFER_SIZE] = {0};
    char SendBuffer[BUFFER_SIZE] = {0};

    // Создаём канал и присваиваем ему имя, чтобы клиент находящийся в этой же сети мог найти сервер
    if((Attach = name_attach(0, NAME, 0)) == 0)
    {
        perror("name_attach()");
        return EXIT_FAILURE;
    }
    printf("server wait client\n");

    int ID = 1;
    for(;;)
    {
    	int RcvID = MsgReceive(Attach->chid, &RecvBuffer, BUFFER_SIZE, 0);
    	if(RcvID > 0)
    	{
    	    // Получено сообщение от клиента
    	    printf("server recv: %c%c\n", RecvBuffer[0], RecvBuffer[1]);

    	    // Обработка сообщения и ответ
    	    if(RecvBuffer[0] == 'r' && RecvBuffer[1] == 'с')
    	    {
				SendBuffer[0] = ID; // Уникальный идентификатор пакета
				SendBuffer[1] = 's'; // Пакет отправляет сервер
				int TryIndex = 0;
				while(TryIndex < 5)
				{
					printf("server try reply: %d%c\n", SendBuffer[0], SendBuffer[1]);
					int Status = 1;
					int ReplyResult = MsgReply(RcvID, Status, SendBuffer, BUFFER_SIZE);
					if(ReplyResult == 0)
					{
						printf("server send: %d%c\n", SendBuffer[0], SendBuffer[1]);
						ID++;
						break;
					}
					else
					{
						printf("server try%d send failed: %d%c\n", TryIndex, SendBuffer[0], SendBuffer[1]);
					}
					TryIndex++;
				}
    	    }
    	    else
    	    {
    	    	printf("server incorrect MsgReceive() buffer: %c%c\n", RecvBuffer[0], RecvBuffer[1]);
    	    }
    	}
    	else if(RcvID == 0) // Если получен пульс
    	{
    	    /*switch(Message.Type)
    	    {
    	        // Обработка отключения клиента
    	        case _PULSE_CODE_DISCONNECT:
    	        {
    	            // Для разрыва соединения передаём в функцию scoid - идентификатор подключения к серверу
    	            ConnectDetach(msg.type);
    	            printf("client disconnected\n");
    	        } break;
    	    }*/
    	}
    	else
    	{
    	    perror("MsgReceive()");
    	    break;
    	}
        sleep(5);
    }

    //  Удаляем имя из пространства имён и уничтожаем канал созданный name_attach()
    name_detach(Attach, 0);

    return EXIT_SUCCESS;
}
