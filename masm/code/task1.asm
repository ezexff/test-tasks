; https://learn.microsoft.com/en-us/cpp/build/x64-software-conventions
; https://learn.microsoft.com/ru-ru/cpp/assembler/masm/ml-and-ml64-command-line-reference

includelib kernel32.lib

extrn GetLastError: PROC

extrn GetStdHandle: PROC
extrn WriteFile: PROC
extrn ReadFile: PROC
extrn ExitProcess: PROC

.const
FirstText byte "Enter value = "
FirstTextLen = $ - FirstText
TextEven byte "Value is even!"                ; Чётное
TextEvenLen = $ - TextEven
TextOdd byte "Value is odd!"                  ; Нечётное
TextOddLen = $ - TextOdd
TextIncorrectSymbol byte "Error! Finded incorrect symbol. Only digits are allowed!"
TextIncorrectSymbolLen = $ - TextIncorrectSymbol
TextValueOutOfRange byte "Error! Text symbol count is 0 or more 10!"
TextValueOutOfRangeLen = $ - TextValueOutOfRange

.data
PrintBuffer byte 200 dup (0)          ; Массив из 200 элементов инициализирован 0. Возможны варианты DUP (?), DUP (0), DUP ('q')
PrintBufferLen = $ - PrintBuffer
PrintTextPtr qword ?
PrintTextLen dword ?
BytesRead qword ?

.code

exit_process proc
    mov rcx, -1                     ; Код возврата
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

Print proc
    sub  rsp, 40                    ; Для параметров функций WriteFile и GetStdHandle резервируем в стеке 40 байт,
                                    ; где 32 байта "shadow storage" и плюс 8 байт - 5ый параметр, который будет храниться в стеке.
                                    ; Первые 4 параметря хранятся в регистрах. Добавляя число в стек значение регистра RSP уменьшается.
                                    ; Используя инструкцию "sub, rsp, 40" мы резервируем место в стеке
    mov rcx, -11                    ; Аргумент для GetStdHandle это STD_OUTPUT_HANDLE ((DWORD)-11)
    call GetStdHandle
    mov rcx, rax                    ; Первый параметр функции. Параметры начинаются с регистра rcx
    mov rdx, PrintTextPtr           ; Второй параметр
    mov r8d, PrintTextLen           ; Третий параметр
    xor r9, r9                      ; Четвертый параметр
    mov qword ptr [rsp + 32], 0     ; Пятый параметр
    call WriteFile
    add rsp, 40                     ; Освобождение стека
    ret
Print endp

CheckRangeError proc
    cmp eax, -1
    jne check_error_exit
    lea r8, TextValueOutOfRange
    mov PrintTextPtr, r8
    mov PrintTextLen, TextValueOutOfRangeLen
    call Print
    call exit_process
check_error_exit:
    ret
CheckRangeError endp

InputText proc
    sub rsp, 40
    mov rcx, -10                    ; STD_INPUT_HANDLE ((DWORD)-10). Стандартное устройство ввода
    call GetStdHandle
    mov rcx, rax
    lea rdx, PrintBuffer
    mov r8d, PrintBufferLen
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

IsEvenOrOdd proc
    and eax, 1
    jz is_even
    lea r8, TextOdd
    mov PrintTextPtr, r8
    mov PrintTextLen, TextOddLen
    call Print
    jmp exit
is_even:
    lea r8, TextEven
    mov PrintTextPtr, r8
    mov PrintTextLen, TextEvenLen
    call Print
exit:
    ret
IsEvenOrOdd endp

ConvertString proc
    mov eax, 0
    mov r8, offset PrintBuffer  ; r8 это указатель на начало строки
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
    lea r8, TextIncorrectSymbol
    mov PrintTextPtr, r8
    mov PrintTextLen, TextIncorrectSymbolLen
    call Print
    ; Выход из программы
    call exit_process
end_convert:
    ret
ConvertString endp

main proc
    ; Просьба ввести значение
    lea r8, FirstText
    mov PrintTextPtr, r8
    mov PrintTextLen, FirstTextLen
    call Print
    
    ; Ввод значения с клавиатуры
    call InputText
    call CheckRangeError
    
    ; Конвертация ввода из ASCII в число
    call ConvertString
    
    ; Проверка значения и вывод результата
    call IsEvenOrOdd
    ret
main endp
end