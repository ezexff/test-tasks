includelib kernel32.lib

extrn CreateThread: PROC
extrn CreateEventA: PROC
extrn SetEvent: PROC
extrn WaitForMultipleObjects: PROC
extrn ExitThread: PROC
extrn Sleep: PROC
extrn GetStdHandle: PROC
extrn WriteFile: PROC
extrn ExitProcess: PROC
extrn GetLastError: PROC

; Каждому из потоков соответствует свой уникальный участок памяти, а также каждый из потоков
; имеет по собственной переменной, в которых будут храниться результаты собственных сумм. 
; Навигация по общей памяти происходит при помощи двух параметров: смещения от начала массива
; и число элементов. Подобная архитектура позволяет избавиться от проблем с гонкой данных и 
; с утечками данных, т.к. обращение к одним и тем же ресурсам происходит лишь после синхронизации,
; т.е. на этапе, когда все потоки выполнили свою работу (посчитали свои суммы)

.const
; Общая память
Memory qword 64 dup (1)

Thread1ResultStr byte "Thread 1 work completed!", 0dh, 0ah
Thread1ResultStrLen = $ - Thread1ResultStr
Thread2ResultStr byte "Thread 2 work completed!", 0dh, 0ah
Thread2ResultStrLen = $ - Thread2ResultStr

Thread1StartStr byte "Thread 1 created!", 0dh, 0ah
Thread1StartStrLen = $ - Thread1StartStr
Thread2StartStr byte 'Thread 2 created!', 0dh, 0ah
Thread2StartStrLen = $ - Thread2StartStr

.data
MemoryPtr qword ?
Thread1Sum qword 0
Thread2Sum qword 0
EventHandleArray qword 2 dup (0)
EventHandleArrayPtr qword ?

.code

check_error_zero proc
    cmp eax, 0
    jnz check_error_zero_exit
    sub rsp, 32
    call GetLastError
    add rsp, 32
    mov rcx, rax
    sub rsp, 32
    call ExitProcess
    add rsp, 32
check_error_zero_exit:
    ret
check_error_zero endp

Sum proc
; rbx - in - смещение начала массива
; rcx - in - число элементов массива
    shl rcx, 3 ; Умножение на 8 (размер массива в байтах)
    mov rax, 0 ; Результат
    mov r10, 0 ; Счётчик
    shl rbx, 3
    add rbx, MemoryPtr ; Начало массива уникальное для потока
sum_loop:
    cmp r10, rcx
    je end_sum_loop
    mov rdx, [rbx + r10]
    add rax, rdx
    add r10, 8
    jmp sum_loop
end_sum_loop:
    ret
Sum endp

Print proc
    sub  rsp, 40
    mov rcx, -11                    ; Аргумент для GetStdHandle это STD_OUTPUT_HANDLE ((DWORD)-11)
    call GetStdHandle
    mov rcx, rax                    ; HANDLE       hFile,
    mov rdx, r10                    ; LPCVOID      lpBuffer,
    mov r8, r11                     ; DWORD        nNumberOfBytesToWrite,
    xor r9, r9                      ; LPDWORD      lpNumberOfBytesWritten,
    mov qword ptr [rsp + 32], 0     ; LPOVERLAPPED lpOverlapped
    call WriteFile
    add rsp, 40                     ; Освобождение стека
    ret
Print endp

ExitThreadFunc proc
    call ExitThread
ExitThreadFunc endp

Thread1Proc proc
    ; Строка о начале работы
    lea r10, Thread1StartStr
    mov r11, Thread1StartStrLen
    call Print

    ; Вычисление суммы
    mov rbx, 0  ; rbx смещение начала массива
    mov rcx, 16  ; rcx число элементов массива
    call Sum
    mov Thread1Sum, rax

    ; Имитиация неравномерной работы 4 секунды
    sub rsp, 32
    mov rcx, 4000
    call Sleep
    add rsp, 32

    ; Установка события
    sub rsp, 32
    mov rcx, [EventHandleArray]
    call SetEvent
    add rsp, 32
    
    ; Строка об окончании работы
    lea r10, Thread1ResultStr
    mov r11, Thread1ResultStrLen
    call Print
    
    ; Thread exit
    sub rsp, 32
    mov rcx, 0
    call ExitThread
    add rsp, 32
    ret
Thread1Proc endp

Thread2Proc proc
    ; Строка о начале работы
    lea r10, Thread2StartStr
    mov r11, Thread2StartStrLen
    call Print

    ; Вычисление суммы
    mov rbx, 16  ; rbx смещение начала массива
    mov rcx, 5  ; rcx число элементов массива
    call Sum
    mov Thread2Sum, rax

    ; Имитиация неравномерной работы 2 секунды
    sub rsp, 32
    mov rcx, 2000
    call Sleep
    add rsp, 32

    ; Установка события
    sub rsp, 32
    mov rcx, [EventHandleArray + 8]
    call SetEvent
    add rsp, 32
    ;call check_error_zero
    
    ; Строка об окончании работы
    lea r10, Thread2ResultStr
    mov r11, Thread2ResultStrLen
    call Print
    
    ; Thread exit
    sub rsp, 32
    mov rcx, 0
    call ExitThread
    add rsp, 32
    ret
Thread2Proc endp

main proc
    lea rax, Memory
    mov MemoryPtr, rax
    
    lea rax, EventHandleArray
    mov EventHandleArrayPtr, rax

    ; Создание события 1
    sub rsp, 32
    mov rcx, 0
    mov rdx, 1                  ; bManualReset
    mov r8, 0                   ; bInitialState
    mov r9, 0
    call CreateEventA
    ;call check_error_zero
    mov [EventHandleArray], rax
    add rsp, 32
    
    ; Создание события 2
    sub rsp, 32
    mov rcx, 0
    mov rdx, 1                  ; bManualReset
    mov r8, 0                   ; bInitialState
    mov r9, 0
    call CreateEventA
    ;call check_error_zero
    mov [EventHandleArray + 8], rax
    add rsp, 32

    ; Create thread 1
    sub rsp, 48
    mov rcx, 0
    mov rdx, 0
    mov r8, Thread1Proc         ; Указатель на функцию треда
    mov r9, 0                   ; Передача параметра в поток
    mov qword ptr [rsp + 32], 0
    mov qword ptr [rsp + 40], 0 ; Out ThreadID
    call CreateThread
    add rsp, 48
    
    ; Create thread 2
    sub rsp, 48
    mov rcx, 0
    mov rdx, 0
    mov r8, Thread2Proc         ; Указатель на функцию треда
    mov r9, 0                   ; Передача параметра в поток
    mov qword ptr [rsp + 32], 0
    mov qword ptr [rsp + 40], 0 ; Out ThreadID
    call CreateThread
    add rsp, 48
    
    ; Ожидание событий от потоков
    sub rsp, 32
    mov rcx, 2                   ; nCount
    mov rdx, EventHandleArrayPtr ; lpHandles
    mov r8, 1                    ; bWaitAll
    mov r9, -1                   ; dwMilliseconds INFINITE = FFFFFFFF
    call WaitForMultipleObjects
    add rsp, 32
    
    ; Ожидание вывода сообщения потоков на экран (если не ждать, то программа закрывается раньше, чем последний поток усевает уведомить пользователя о завершении своей работы)
    sub rsp, 32
    mov rcx, 500
    call Sleep
    add rsp, 32
    
    ; Итоговая сумма
    mov rax, Thread1Sum
    add rax, Thread2Sum
    
    ; Вывод
    sub rsp, 32
    mov rcx, rax
    call ExitProcess
    add rsp, 32
    
    ret
main endp
end