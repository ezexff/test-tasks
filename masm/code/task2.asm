includelib kernel32.lib
includelib ucrt.lib
includelib legacy_stdio_definitions.lib

extrn printf:PROC
extrn GetLastError: PROC
extrn GetStdHandle: PROC
extrn WriteFile: PROC
extrn ReadFile: PROC
extrn ExitProcess: PROC


.const
EnterValueText byte "Enter value (0 - 12): ", 0
IncorrectInputText byte "Incorrect input!", 0dh, 0ah, 0
EndLineStr byte 0dh, 0ah, 0
TextIncorrectSymbol byte "Error! Finded incorrect symbol. Only digits are allowed!", 0dh, 0ah, 0
TextValueOutOfRange byte "Error! Text symbol count is 0 or more 10!", 0dh, 0ah, 0
ResultText byte "Factorial result = %d", 0dh, 0ah, 0
NumberMoreThan12Text byte "Error! Number more than 12!", 0dh, 0ah, 0

.data
InputBuffer byte 200 dup (0)
InputBufferLen = $ - InputBuffer
BytesRead qword ?

.code

exit_process proc
    mov rcx, -1
    call ExitProcess
    ret
exit_process endp

check_error_zero proc
    cmp eax, 0
    jnz check_error_zero_exit
    call GetLastError
    mov rcx, rax
    call ExitProcess
check_error_zero_exit:
    ret
check_error_zero endp

check_error_minus_1 proc
    cmp eax, -1
    jne check_error_minus_1_exit
    call exit_process
check_error_minus_1_exit:
    ret
check_error_minus_1 endp

CheckRangeError proc
    cmp eax, -1
    jne check_error_exit
    lea rcx, TextValueOutOfRange
    call Print
    call exit_process
check_error_exit:
    ret
CheckRangeError endp

PrintEndLine proc
    sub rsp, 32
    lea rcx, EndLineStr
    call printf
    add rsp, 32
    ret
PrintEndLine endp

Print proc
    sub rsp, 32
    call printf
    add rsp, 32
    ret
Print endp

InputText proc
    sub rsp, 40
    mov rcx, -10                    ; STD_INPUT_HANDLE ((DWORD)-10). Стандартное устройство ввода
    call GetStdHandle
    mov rcx, rax
    lea rdx, InputBuffer
    mov r8d, InputBufferLen
    lea r9, BytesRead
    mov qword ptr [rsp + 32], 0
    call ReadFile
    call check_error_zero           ; Проверяем результат ReadFile на ошибку
    mov rax, BytesRead              ; Если ошибки нет, в RAX количество считанных байтов
    sub rax, 2                      ; Убираем из числа считанных байт символы /r/n добавленные автоматически
    ; Проверяем считано ли символов больше 0
    mov BytesRead, rax
    jnz input_text_check            ; Если в RAX ненулевое значение
    mov rax, -1                     ; Помещаем код ошибки
    jnz input_text_exit
input_text_check:
    ; Проверяем считано ли символов меньше 11 (допустимо число с 10ю и менее цифр)
    cmp rax, 11
    jb input_text_exit
    mov rax, -1
input_text_exit:
    add rsp, 40
    ret
InputText endp

ConvertString proc
    mov eax, 0
    mov r8, offset InputBuffer  ; r8 это указатель на начало строки
    mov r9, BytesRead
    mov r10, r8
    add r10, r9                 ; Адрес конца строки
convert_loop:
    mov cl, [r8]                ; Получаем текущий символ из буфера
    cmp r8, r10                  ; Сравниваем адреса начала и конца строки
    je end_convert

    ; Является ли символ цифрой
    cmp cl, '0'
    jb incorrect_symbol
    cmp cl, '9'
    ja incorrect_symbol

    ; Конвертируем ASCII цифру в число
    sub cl, '0'                 ; Конвертируем цифру в число
    movzx ecx, cl               ; Расширяем значение до ecx регистра (для умножения)
    mov edx, 10
    mul edx                     ; Умножаем на 10, чтобы цифра оказалась на нужном разряде
    add eax, ecx                ; Добавляем разряд к итоговому числу

    inc r8
    jmp convert_loop
incorrect_symbol:
    ; Вывод сообщения об ошибке
    lea rcx, TextIncorrectSymbol
    call Print
    ; Выход из программы
    call exit_process
end_convert:
    
    ; Если число больше 12, то выводим ошибку
    cmp eax, 12
    jbe end_convert2
    lea rcx, NumberMoreThan12Text
    call Print
    call exit_process
end_convert2:
    ret
ConvertString endp

CalcFactorial proc
    ; Если введено число 0, то факториал = 1
    cmp rax, 0
    mov eax, 1
    je end_factorial_loop

    mov r10, rax
    mov rcx, 1  ; Счётчик
factorial_loop:
    cmp rcx, r10
    je end_factorial_loop
    mul rcx
    inc rcx
    jmp factorial_loop
end_factorial_loop:
    ret
CalcFactorial endp

main proc
    ; Ввод числа
    lea rcx, EnterValueText
    call Print
    call InputText
    call CheckRangeError
    call ConvertString
    
    ; Вычисление факториала
    call CalcFactorial
    
    ; Вывод результата
    lea rcx, ResultText
    mov rdx, rax
    call Print
    
    ret
main endp
end