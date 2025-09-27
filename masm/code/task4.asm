includelib kernel32.lib
includelib ucrt.lib
includelib legacy_stdio_definitions.lib


extrn GetLastError: PROC

extrn GetStdHandle: PROC
extrn WriteFile: PROC
extrn ReadFile: PROC
extrn ExitProcess: PROC

extrn VirtualAlloc: PROC
extrn VirtualFree: PROC

extrn printf:PROC
;extrn scanf:PROC

dynamic_array struct
    MemoryPtr qword ?
    MemorySize qword ?
    Used qword ?
    BytesPerValue qword ?
dynamic_array ends

.const
AddingElementText byte "Adding element: %d.", 0
CurrentArrayText byte "Current array: ", 0
ElementFoundText byte "Element %d found at index: %d.", 0
ElementNotFoundText byte "Element %d not found!", 0
DeletingElementText byte "Deleting element at index: %d.", 0
ArrayIsEmptyText byte "Array is empty and memory freed.", 0
IncorrectInputText byte "Incorrect input!", 0
AddElementText byte "Add element: ", 0
FindElementText byte "Find element: ", 0
DeleteElementByIndexText byte "Delete element by index: ", 0

TextIncorrectSymbol byte "Error! Finded incorrect symbol. Only digits are allowed!", 0
TextValueOutOfRange byte "Error! Text symbol count is 0 or more 10!", 0

ValueText byte "%d ", 0
EndLineText byte "%c", 0

MAX_ARRAY_SIZE = 1024   ; Максимальный размер массива (в байтах) - защита от переполнения, т.к. новый размер массива это старый размер умноженный на 2
INIT_ARRAY_SIZE = 16    ; Изначальный размер массива (в байтах)

;ScanfInitParameter byte "%d", 0

.data
DynamicArray dynamic_array <>

;ScanfBuffer byte 200 dup (0)
;ScanValue qword 0

InputBuffer byte 200 dup (0)          ; Массив из 200 элементов инициализирован 0. Возможны варианты DUP (?), DUP (0), DUP ('q')
InputBufferLen = $ - InputBuffer
BytesRead qword ?

.code

;
; Вспомогательные функции
;

PrintEndLine proc
    sub rsp, 32
    lea rcx, EndLineText   ; Указатель на строку текста
    mov rdx, 10            ; Символ конца строки
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

; Scan proc ; Пробовал реализовать ввод через scanf, но отказался от этой идеи из-за кривой валидации у этой функции.
; Она позволяет считывать числа с плавающей точкой и со за знаком (автоматически получаются очень большие числа из-за установленного первого бита)
;    sub rsp, 32
;    lea rcx, ScanfInitParameter
;    lea rdx, ScanValue
;    call scanf
;    add rsp, 32
;    cmp rax, 1
;    je scan_exit
;    lea rcx, IncorrectInputText
;    call Print
;    call PrintEndLine
;    call exit_process
;scan_exit:
;    ret
;Scan endp

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

;
; Динамический массив
;
DynamicArrayMemoryAlloc proc
    mov DynamicArray.MemorySize, rax
    mov DynamicArray.Used, 0
    mov DynamicArray.BytesPerValue, 8
    sub rsp, 32 
    mov rcx, 0          ; Начальный адрес региона для выделения 
    mov rdx, rax        ; Размер региона в байтах
    mov r8, 3000h       ; Тип выделения памяти MEM_RESERVE|MEM_COMMIT (0x00002000|0x00001000)
    mov r9, 4h          ; PAGE_READWRITE 0x04
    call VirtualAlloc
    add rsp, 32
    mov DynamicArray.MemoryPtr, rax
    call check_error_zero
    ret
DynamicArrayMemoryAlloc endp

DynamicArrayMemoryFree proc
    sub rsp, 32
    mov rcx, rax
    mov rdx, 0
    mov r8, 8000h       ; MEM_RELEASE (0x00008000)
    call VirtualFree
    add rsp, 32
    call check_error_zero
    ret
DynamicArrayMemoryFree endp

GetFromDynamicArray proc
    mov rcx, DynamicArray.MemoryPtr
    mov rdx, DynamicArray.BytesPerValue
    mov rax, r8
    mul rdx
    mov rax, [rcx + rax]
    ret
GetFromDynamicArray endp

AddToDynamicArray proc
    ; Вывод сообщения
    lea rcx, AddingElementText
    mov rdx, rax
    mov r15, DynamicArray.MemoryPtr
    push rax
    call Print
    call PrintEndLine
    pop rax
    
    ; Проверяем есть ли место для нового элемента в памяти массива
    mov r9, DynamicArray.Used
    add r9, DynamicArray.BytesPerValue
    cmp r9, DynamicArray.MemorySize
    jb contniue_adding                   
    push rax ; Сохраняем добавляемое значение в стек
    
    ; Если места в памяти для нового элемента не хватает, то увеличиваем размер массива в 2 раза
    ; Сохраняем данные о старом массиве в регистрах
    mov r12, DynamicArray.MemoryPtr
    mov r14, DynamicArray.Used
    
    ; Получаем новый размер массива и выделяем для него память, если размер нового массива меньше константы
    mov rax, DynamicArray.MemorySize
    mov rcx, 2
    mul rcx
    cmp rax, MAX_ARRAY_SIZE
    jb end_max_size_check
    call exit_process
end_max_size_check:
    call DynamicArrayMemoryAlloc
    mov DynamicArray.Used, r14
    
    ; Копируем данные из старого массива в новый
    mov r10, 0 ; Счётчик цикла
copy_array_loop:                    
    cmp r10, r14
    jz end_copy_array_loop                                     
    mov rax, [r12 + r10]
    mov rcx, DynamicArray.MemoryPtr
    mov [rcx + r10], rax
    add r10, DynamicArray.BytesPerValue
    jmp copy_array_loop
end_copy_array_loop:

    ; Освобождаем память от старого массива
    mov rax, r12
    call DynamicArrayMemoryFree
    pop rax ; Восстанавливаем добавляемое значение
    
    ; Добавляем новый элемент в конец массива
contniue_adding:
    mov rcx, DynamicArray.MemoryPtr
    mov rdx, DynamicArray.Used
    mov [rcx + rdx], rax
    mov rax, DynamicArray.BytesPerValue
    add DynamicArray.Used, rax
    ret
AddToDynamicArray endp

FindElementInDynamicArray proc
    mov r12, DynamicArray.MemoryPtr
    mov r14, DynamicArray.Used
    mov r10, 0 ; Счётчик цикла
find_element_in_array_loop:
    cmp r10, r14
    jz element_not_found
    
    ; Сравниваем элемент массива с введённым значением
    mov rcx, [r12 + r10]
    cmp rax, rcx
    jz element_found
    
    add r10, DynamicArray.BytesPerValue
    jmp find_element_in_array_loop
element_found:
    ; Вычисляем числовой индекс элемента
    mov r15, rax
    mov rax, r10
    mov r14, DynamicArray.BytesPerValue
    xor rdx, rdx
    div r14
    mov r8, rax
    mov rax, r15
    
    ; Выводим результат
    lea rcx, ElementFoundText
    mov rdx, rax
    call Print
    call PrintEndLine
    jmp find_element_exit
element_not_found:
    lea rcx, ElementNotFoundText
    mov rdx, rax
    call Print
    call PrintEndLine
    mov rax, -1
find_element_exit:
    ret
FindElementInDynamicArray endp

DeleteElementByIndex proc
    ; Если попытка удалить из пустого массива
    cmp DynamicArray.Used, 0
    ja start_delete_element
    mov eax, -1
    call exit_process
    
start_delete_element:
    ; Вывод сообщения
    lea rcx, DeletingElementText
    mov rdx, r8
    push r8
    call Print
    call PrintEndLine
    pop r8

    mov rcx, DynamicArray.MemoryPtr
    mov r14, DynamicArray.Used
    mov r9, DynamicArray.BytesPerValue
    
    ; Смещение элемента в памяти
    mov rax, r8
    mul r9
    mov r10, rax
    
    ; Проверяем находится ли элемент в пределах массива
    cmp r10, r14
    jnb end_shift_array_loop
    
    ; Уменьшаем размер массива
    sub r14, r9
    mov DynamicArray.Used, r14
    
    ; Все элементы справа от удаленного сдвигаем на одну позицию влево
shift_array_loop:                    
    cmp r10, r14
    jnb end_shift_array_loop
    
    ; Запоминаем смещение до текущего элемента
    mov r12, r10
    
    ; Вычисляем смещение до следующего элемента
    add r10, r9
    
    ; Перемещаем данные из следующего в текущий
    mov eax, [rcx + r10]
    mov [rcx + r12], eax

    jmp shift_array_loop
end_shift_array_loop:

    ; Если массив становится пустым, то освобождаем память
    cmp r14, 0
    jne delete_element_exit
    mov rax, rcx
    call DynamicArrayMemoryFree
    lea rcx, ArrayIsEmptyText
    call Print
    call PrintEndLine
delete_element_exit:
    ret
DeleteElementByIndex endp

PrintDynamicArray proc
    lea rcx, CurrentArrayText
    mov rdx, rax
    call Print

    ; Обход массива
    mov r12, DynamicArray.MemoryPtr
    mov r14, DynamicArray.Used

    mov r10, 0 ; Счётчик цикла
array_print_loop:    
    cmp r10, r14
    jz end_array_print_loop  
    
    ; Получем элемент массива
    mov rax, [r12 + r10]
    
    ; Вывод элемента массива на экран
    lea rcx, ValueText
    mov rdx, rax
    push r10
    push r12
    push r14
    call Print
    pop r14
    pop r12
    pop r10
    
    add r10, DynamicArray.BytesPerValue
    jmp array_print_loop
end_array_print_loop:
    call PrintEndLine
    ret
PrintDynamicArray endp

;
; Точка входа
;
main proc
    ; Инициализация массива 1 (без ввода)
    mov rax, INIT_ARRAY_SIZE
    call DynamicArrayMemoryAlloc
    call PrintDynamicArray
    
    ; Добавление элементов
    mov rax, 256
    call AddToDynamicArray
    call PrintDynamicArray
    
    mov rax, 7
    call AddToDynamicArray
    call PrintDynamicArray
    
    mov rax, 8
    call AddToDynamicArray
    call PrintDynamicArray
   
    ; Получение элементов
    mov r8, 0
    call GetFromDynamicArray
    mov r8, 1
    call GetFromDynamicArray
    mov r8, 2
    call GetFromDynamicArray
   
    ; Поиск элементов в массиве
    mov rax, 256
    call FindElementInDynamicArray
    mov rax, 7
    call FindElementInDynamicArray
    mov rax, 8
    call FindElementInDynamicArray
    mov rax, 11
    call FindElementInDynamicArray
    
    ; Удаление элементов
    mov r8, 0
    call DeleteElementByIndex
    call PrintDynamicArray
    mov r8, 1
    call DeleteElementByIndex
    call PrintDynamicArray
    ; Автоматическое освобождение памяти после удаления последнего элемента массива
    mov r8, 0
    call DeleteElementByIndex
    
    ; Попытка удалить из пустого массива
    ;mov r8, 0
    ;call DeleteElementByIndex
    
    call PrintEndLine
    call PrintEndLine
    call PrintEndLine
    
    ; Инициализация массива (со вводом)
    mov rax, INIT_ARRAY_SIZE
    call DynamicArrayMemoryAlloc
    call PrintDynamicArray
    
    ; Добавление элементов
    lea rcx, AddElementText
    call Print
    ;call Scan
    ;mov rax, ScanValue
    call InputText
    call CheckRangeError
    call ConvertString
    call AddToDynamicArray
    call PrintDynamicArray
    
    lea rcx, AddElementText
    call Print
    call InputText
    call CheckRangeError
    call ConvertString
    ;call Scan
    ;mov rax, ScanValue
    call AddToDynamicArray
    call PrintDynamicArray
    
    ; Поиск элемента
    lea rcx, FindElementText
    call Print
    call InputText
    call CheckRangeError
    call ConvertString
    ;call Scan
    ;mov rax, ScanValue
    call FindElementInDynamicArray
    call PrintDynamicArray
    
    ; Удаление элемента
    lea rcx, DeleteElementByIndexText
    call Print
    call InputText
    call CheckRangeError
    call ConvertString
    mov r8, rax
    ;call Scan
    ;mov r8, ScanValue
    call DeleteElementByIndex
    call PrintDynamicArray
    
    call DynamicArrayMemoryFree
    
    ret
main endp
end