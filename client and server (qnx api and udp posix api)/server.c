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
    name_attach_t *Attach; // ���������� ������ � ������������ ����
    char RecvBuffer[BUFFER_SIZE] = {0};
    char SendBuffer[BUFFER_SIZE] = {0};

    // ������ ����� � ����������� ��� ���, ����� ������ ����������� � ���� �� ���� ��� ����� ������
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
    	    // �������� ��������� �� �������
    	    printf("server recv: %c%c\n", RecvBuffer[0], RecvBuffer[1]);

    	    // ��������� ��������� � �����
    	    if(RecvBuffer[0] == 'r' && RecvBuffer[1] == '�')
    	    {
				SendBuffer[0] = ID; // ���������� ������������� ������
				SendBuffer[1] = 's'; // ����� ���������� ������
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
    	else if(RcvID == 0) // ���� ������� �����
    	{
    	    /*switch(Message.Type)
    	    {
    	        // ��������� ���������� �������
    	        case _PULSE_CODE_DISCONNECT:
    	        {
    	            // ��� ������� ���������� ������� � ������� scoid - ������������� ����������� � �������
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

    //  ������� ��� �� ������������ ��� � ���������� ����� ��������� name_attach()
    name_detach(Attach, 0);

    return EXIT_SUCCESS;
}
