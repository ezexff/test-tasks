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

IntroText byte "Unit converter", 0dh, 0ah, "Select conversion type:", 0dh, 0ah, "1. Meters to kilometers", 0dh, 0ah, "2. Centimeters to meters", 0dh, 0ah, "3. Kilometers in meters", 0dh, 0ah, "4. Inches to centimeters", 0dh, 0ah, "Enter an operation number: ", 0
ConverterNotFound byte "Error! Converter not found!", 0dh, 0ah, 0

Converter1InputText byte "Enter value in meters: ", 0
Converter2InputText byte "Enter value in centimeters: ", 0
Converter3InputText byte "Enter value in kilometers: ", 0
Converter4InputText byte "Enter value in inches: ", 0

Converter1ResultText byte "Result: %d meters = %lf kilometers", 0
Converter2ResultText byte "Result: %d centimeters = %lf meters", 0
Converter3ResultText byte "Result: %d kilometers = %lf meters", 0
Converter4ResultText byte "Result: %d inches = %lf centimeters", 0

FloatValueText byte "%Value = %lf", 0

.data
InputBuffer byte 200 dup (0)
InputBufferLen = $ - InputBuffer
BytesRead qword ?

FloatValue real8 ?
InchesToCentimetersConst real8 2.54

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
    ret
ConvertString endp

MetersToKilometers proc
    lea rcx, Converter1InputText
    mov rdx, rax
    call Print
    
    ; Ввод числа
    call InputText
    call CheckRangeError
    call ConvertString
    
    ; Вычисляем вещественное значение в xmm регистрах
    mov FloatValue, rax
    vcvtdq2pd xmm0, FloatValue
    mov rcx, 1000
    mov FloatValue, rcx
    vcvtdq2pd xmm1, FloatValue
    divsd xmm0, xmm1
    movapd FloatValue, xmm0
    
    ;Вывод результата
    lea rcx, Converter1ResultText
    mov rdx, rax
    mov r8, FloatValue
    call Print
    
    ret
MetersToKilometers endp

CentimetersToMeters proc
    lea rcx, Converter2InputText
    mov rdx, rax
    call Print
    
    ; Ввод числа
    call InputText
    call CheckRangeError
    call ConvertString
    
    ; Вычисляем вещественное значение в xmm регистрах
    mov FloatValue, rax
    vcvtdq2pd xmm0, FloatValue
    mov rcx, 100
    mov FloatValue, rcx
    vcvtdq2pd xmm1, FloatValue
    divsd xmm0, xmm1
    movapd FloatValue, xmm0
    
    ;Вывод результата
    lea rcx, Converter2ResultText
    mov rdx, rax
    mov r8, FloatValue
    call Print
    
    ret
CentimetersToMeters endp

KilometersInMeters proc
    lea rcx, Converter3InputText
    mov rdx, rax
    call Print
    
    ; Ввод числа
    call InputText
    call CheckRangeError
    call ConvertString
    
    ; Вычисляем вещественное значение в xmm регистрах
    mov FloatValue, rax
    vcvtdq2pd xmm0, FloatValue
    mov rcx, 1000
    mov FloatValue, rcx
    vcvtdq2pd xmm1, FloatValue
    mulsd xmm0, xmm1
    movapd FloatValue, xmm0
    
    ;Вывод результата
    lea rcx, Converter3ResultText
    mov rdx, rax
    mov r8, FloatValue
    call Print
    
    ret
KilometersInMeters endp

InchesToCentimeters proc
    lea rcx, Converter4InputText
    mov rdx, rax
    call Print
    
    ; Ввод числа
    call InputText
    call CheckRangeError
    call ConvertString
    
    ; Вычисляем вещественное значение в xmm регистрах
    mov FloatValue, rax
    vcvtdq2pd xmm0, FloatValue
    movsd xmm0, InchesToCentimetersConst
    vcvtdq2pd xmm1, FloatValue
    mulsd xmm0, xmm1
    movapd FloatValue, xmm0
    
    ;Вывод результата
    lea rcx, Converter4ResultText
    mov rdx, rax
    mov r8, FloatValue
    call Print
    
    ret
InchesToCentimeters endp

UnitConverter proc
    cmp rax, 0
    je converter_not_found
    cmp rax, 4
    ja converter_not_found
converter1:
    cmp rax, 1
    jne converter2
    call MetersToKilometers
    jmp end_convertion
converter2:
    cmp rax, 2
    jne converter3
    call CentimetersToMeters
    jmp end_convertion
converter3:
    cmp rax, 3
    jne converter4
    call KilometersInMeters
    jmp end_convertion
converter4:
    cmp rax, 4
    call InchesToCentimeters
    jmp end_convertion
converter_not_found:
    lea rcx, ConverterNotFound
    call Print
end_convertion:
    ret
UnitConverter endp

main proc
    ; Выбор конвертера
    lea rcx, IntroText
    call Print
    call InputText
    call CheckRangeError
    call ConvertString
    push rax
    call PrintEndLine
    pop rax
    
    ; Конвертер единиц измерения
    call UnitConverter
    
    ret
main endp
end