#include <sys/epoll.h>
#include <fcntl.h>
#include <unistd.h>
#include <iostream>
#include <arpa/inet.h>
#include <string.h>
#include <ctime>

#define SERVER_PORT 5433
#define DB_PORT 5432
#define BUFFER_SIZE 1024
#define MAX_EVENTS 10000
#define MAX_CONNECTION_COUNT 1000

struct connection
{
    int DstSockFD;
    int BufferLen;
    char Buffer[BUFFER_SIZE];
};

void SetNonBlock(int SockFD)
{
    // Получаем текущие флаги
    int Flags;
    Flags = fcntl(SockFD, F_GETFL, 0);
    if(Flags == -1)
    {
        perror("fcntl(F_GETFL)");
        exit(EXIT_FAILURE);
    }
    // Устанавливаем сокет в неблокирующий режим
    if(fcntl(SockFD, F_SETFL, Flags | O_NONBLOCK) == -1)
    {
        perror("fcntl(F_SETFL)");
        exit(EXIT_FAILURE);
    }
}

int main()
{
    connection ConnectionArray[MAX_CONNECTION_COUNT]; // Индекс элемента массива это сокет источника подключения
    int ServSockFD; // Сокет слушающий подключения к прокси-серверу
    struct sockaddr_in ServAddr, CliAddr, DBAddr;
    socklen_t SizeOfCliAddr = sizeof(CliAddr);;

    // Адрес подключения к БД
    {
        memset(&DBAddr, 0, sizeof(DBAddr));
        DBAddr.sin_family = AF_INET; // IPv4
        DBAddr.sin_addr.s_addr = inet_addr("127.0.0.1");
        DBAddr.sin_port = htons(DB_PORT);
    }

    // Создание слушающего серверного сокета, который принимает входящие подключения
    {
        memset(&ServAddr, 0, sizeof(ServAddr));
        memset(&CliAddr, 0, sizeof(CliAddr));

        if((ServSockFD = socket(AF_INET, SOCK_STREAM, 0)) < 0)
        {
            perror("socket() failed");
            exit(EXIT_FAILURE);
        }

        ServAddr.sin_family = AF_INET; // IPv4
        ServAddr.sin_addr.s_addr = INADDR_ANY;
        ServAddr.sin_port = htons(SERVER_PORT);

        if(bind(ServSockFD, (struct sockaddr *)&ServAddr, sizeof(ServAddr)) < 0)
        {
            perror("bind() failed");
            exit(EXIT_FAILURE);
        }

        // Функция listen в программировании сокетов переводит сокет сервера в режим ожидания входящих запросов на соединение. 
        // Она сигнализирует операционной системе о готовности сервера принимать клиентские запросы и создает очередь для них, 
        // чтобы последующие запросы не отклонялись сразу, а ожидали своей очереди
        int ListenServSockFD = listen(ServSockFD, SOMAXCONN);
        if(ListenServSockFD < 0)
        {
            perror("listen() failed");
            exit(EXIT_FAILURE);
        }

        SetNonBlock(ServSockFD);
    }

    // Создание очереди epoll
    int EpollFD = epoll_create1(0);

    // Добавление серверного сокета в очередь epoll
    struct epoll_event Ev;
    Ev.events = EPOLLIN; // Попробовать использовать EPOLLET, но тогда нужно считывать через read() в цикле, пока не вернётся EAGAIN?
    Ev.data.fd = ServSockFD;
    epoll_ctl(EpollFD, EPOLL_CTL_ADD, ServSockFD, &Ev);

    printf("server loop started\n");

    for(;;)
    {
        // Ожидание событий
        struct epoll_event Events[MAX_EVENTS];
        // epoll_wait ждет, пока не произойдут события на одном из отслеживаемых файловых дескрипторов или пока не истечет время ожидания
        // в данном случае -1 это бесконечное ожидание
        int nfds = epoll_wait(EpollFD, Events, MAX_EVENTS, -1);
        if(nfds < 0)
        {
            perror("epoll_wait() failed");
            exit(EXIT_FAILURE);
        }

        if(nfds >= MAX_EVENTS)
        {
            perror("nfds >= MAX_EVENTS");
            exit(EXIT_FAILURE);
        }

        // Обработка готовых дескрипторов (перебираются дескрипторы, которые вернул epoll_wait)
        for(int n = 0; n < nfds; ++n)
        {
            int EventSockFD = Events[n].data.fd;
            if(EventSockFD >= MAX_CONNECTION_COUNT)
            {
                perror("EventSockFD >= MAX_CONNECTION_COUNT)");
                exit(EXIT_FAILURE);
            }

            if(EventSockFD == ServSockFD) // Обработка нового соединения
            {
                int CliSockFD = accept(ServSockFD, (struct sockaddr *)&CliAddr, &SizeOfCliAddr);
                if(CliSockFD == -1)
                {
                    perror("accept() failed");
                    return -1;
                }
                SetNonBlock(CliSockFD);

                // Connect to db, get db_df, set non blocking
                int DBSockFD = -1;
                if((DBSockFD = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0)) < 0)
                {
                    perror("socket() failed");
                    exit(EXIT_FAILURE);
                }
                if(connect(DBSockFD, (struct sockaddr *)&DBAddr, sizeof(DBAddr)) < 0)
                {
                    perror("connect() failed");
                    exit(EXIT_FAILURE);
                }
                SetNonBlock(DBSockFD);

                if(DBSockFD >= MAX_CONNECTION_COUNT)
                {
                    perror("DBSockFD >= MAX_CONNECTION_COUNT");
                    exit(EXIT_FAILURE);
                }

                ConnectionArray[CliSockFD].BufferLen = 0; 
                ConnectionArray[CliSockFD].DstSockFD = DBSockFD;

                ConnectionArray[DBSockFD].BufferLen = 0; 
                ConnectionArray[DBSockFD].DstSockFD = CliSockFD;

                
                struct epoll_event ClientEvent;
                ClientEvent.events = EPOLLIN; // | EPOLLET;
                ClientEvent.data.fd = CliSockFD;
                epoll_ctl(EpollFD, EPOLL_CTL_ADD, CliSockFD, &ClientEvent);
                
                struct epoll_event BackendEvent;
                BackendEvent.events = EPOLLIN; // | EPOLLET;
                BackendEvent.data.fd = DBSockFD;
                epoll_ctl(EpollFD, EPOLL_CTL_ADD, DBSockFD, &BackendEvent);
                
                printf("accepted new connection: CliSockFD=%d DBSockFD=%d\n", CliSockFD, DBSockFD);
            }
            else // Переправка данных (от клиента к БД и от БД к клиенту)
            {
                if(Events[n].events & EPOLLIN)
                {
                    ConnectionArray[EventSockFD].BufferLen = recv(EventSockFD, ConnectionArray[EventSockFD].Buffer, BUFFER_SIZE, 0);
                    if(ConnectionArray[EventSockFD].BufferLen  == -1)
                    {
                        perror("recv() failed");
                    }
                    else if(ConnectionArray[EventSockFD].BufferLen == 0)
                    {
                        int DstSockFD = ConnectionArray[EventSockFD].DstSockFD;
                        printf("src=%d and dst=%d sockets were closed\n", EventSockFD, DstSockFD);
                        close(DstSockFD);
                        epoll_ctl(EpollFD, EPOLL_CTL_DEL, DstSockFD, nullptr);
                        ConnectionArray[DstSockFD].BufferLen = 0; 
                        ConnectionArray[DstSockFD].DstSockFD = 0;

                        close(EventSockFD);
                        epoll_ctl(EpollFD, EPOLL_CTL_DEL, EventSockFD, nullptr);
                        ConnectionArray[EventSockFD].BufferLen = 0; 
                        ConnectionArray[EventSockFD].DstSockFD = 0;
                    }
                    else
                    {
                        if(ConnectionArray[EventSockFD].BufferLen > BUFFER_SIZE)
                        {
                            perror("not enough space in buffer");
                            exit(EXIT_FAILURE);
                        }
                        else
                        {
                            if(ConnectionArray[EventSockFD].Buffer[0] == 0x51) // Если SQL-запрос, то записываем в файл
                            {
                                char *SQLPtr = &ConnectionArray[EventSockFD].Buffer[5];

                                time_t RawTime;
                                struct tm *TimeInfo;
                                char TmpBuffer[80];
                                time(&RawTime);
                                TimeInfo = localtime(&RawTime);
                                strftime(TmpBuffer, 80, "%Y-%m-%d %H:%M:%S", TimeInfo);
                                
                                //printf("sql found (%s: %s)\n", TmpBuffer, SQLPtr);

                                // Можно оптимизировать, если не сохранять файл после каждого найденного запроса
                                // Такой вариант реализован, чтобы данные гарантированно сохранялись в файл
                                FILE *FilePtr = fopen("log.txt", "a");
                                fprintf(FilePtr, "%s: %s\n", TmpBuffer, SQLPtr);
                                fclose(FilePtr);
                            }
                        }
                    }

                    send(ConnectionArray[EventSockFD].DstSockFD, ConnectionArray[EventSockFD].Buffer, ConnectionArray[EventSockFD].BufferLen, 0);
                }
                else if(Events[n].events & EPOLLOUT)
                {
                    printf("=====\n");
                    printf("TODO: EPOLLOUT = %d\n", EventSockFD);
                    printf("=====\n");
                }
                else if(Events[n].events & (EPOLLERR | EPOLLHUP))
                {
                    printf("=====\n");
                    printf("EPOLLERR | EPOLLHUP = %d\n", EventSockFD);
                    printf("=====\n");

                    close(EventSockFD);
                    epoll_ctl(EpollFD, EPOLL_CTL_DEL, EventSockFD, nullptr);
                    ConnectionArray[EventSockFD].BufferLen = 0; 
                    ConnectionArray[EventSockFD].DstSockFD = 0;
                    printf("EPOLLERR\n");
                }
                else
                {
                    printf("=====\n");
                    printf("TODO: UNKNOWN EVENT = %d\n", EventSockFD);
                    printf("=====\n");
                }
            }
        }
    }

    close(EpollFD);
    close(ServSockFD);
    return(0);
}
