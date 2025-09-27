includelib kernel32.lib
includelib ucrt.lib
includelib legacy_stdio_definitions.lib

extrn printf:PROC
extrn GetLastError: PROC
extrn GetStdHandle: PROC
extrn WriteFile: PROC
extrn ReadFile: PROC
extrn ExitProcess: PROC

; Последний символ в строках это null terminator
contact struct
    IsAdded byte ?
    CName byte 19 dup (?)      ; Name ключевое слово masm и на которое не вывод предупреждения компилятор!!!
    PhoneNumber byte 12 dup (?)
contact ends

.const
InputContactNameLenMax = 18
InputPhoneNumberLenMax = 10

FloatValueText byte "%Value = %lf", 0
EndLineStr byte 0dh, 0ah, 0

IncorrectInputText byte "Incorrect input!", 0dh, 0ah, 0dh, 0ah, 0
TextIncorrectSymbol byte "Error! Finded incorrect symbol. Only digits are allowed!", 0dh, 0ah, 0dh, 0ah, 0
TextValueOutOfRange byte "Error! Text symbol count is 0 or more 10!", 0dh, 0ah, 0
OperationNotFound byte "Error! Operation not found!", 0dh, 0ah, 0dh, 0ah, 0

IntroText byte "Phone Book", 0dh, 0ah, "1. Add contact", 0dh, 0ah, "2. Delete contact", 0dh, 0ah, "3. View contacts", 0dh, 0ah, "4. Exit", 0dh, 0ah, "Enter an operation number: ", 0

; Add contact
AddContactNameText byte "Enter contact name: ", 0
AddContactPhoneNumberText byte "Enter phone number: ", 0
AddResultText byte "Contact added.", 0dh, 0ah, 0dh, 0ah, 0
AddResultText2 byte "Phone book is full!", 0dh, 0ah, 0dh, 0ah, 0

; Delete contact
DeleteContactInputText byte "Enter contact name to delete: ", 0
DeleteContactResultText byte "Contact deleted.", 0dh, 0ah, 0dh, 0ah, 0
DeleteContactResult2Text byte "Contact not found!", 0dh, 0ah, 0dh, 0ah, 0
DeleteContactInputResultText byte "Incorrect name!", 0dh, 0ah, 0dh, 0ah, 0

; View contacts
ViewContactsText byte "Current contact list:", 0dh, 0ah, 0dh, 0ah, 0
ViewContactText byte "%d. %s - %s", 0dh, 0ah, 0

.data
InputBuffer byte 18 dup (0)
InputBufferLen = $ - InputBuffer
BytesRead qword ?

MAX_CONTACT_COUNT = 10
;ContactArray contact MAX_CONTACT_COUNT dup (<1, {'T','e','s','t',0,6,7,8,9,1,2,3,4,5,6,7,8,0}, {'9','8','7',0,5,6,7,8,9,10,11,0}>, <1, {'T','e','s','t','2',0,7,8,9,1,2,3,4,5,6,7,8,0}, {'5','5','5',0,5,6,7,8,9,10,11,0}>)
ContactArray contact MAX_CONTACT_COUNT dup (<>)

TempContactNameStrPtr qword ?
TempPhoneNumberStrPtr qword ?
StdHandle qword ?

DeleteContactInputBuffer byte 200 dup (0)

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
    ;mov rcx, -10                    ; STD_INPUT_HANDLE ((DWORD)-10). Стандартное устройство ввода
    ;call GetStdHandle
    mov rcx, StdHandle
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
    ;mov eax, -1
    ; Выход из программы
    ; call exit_process
end_convert:
    ret
ConvertString endp

InputName proc
    sub rsp, 40
    mov rcx, StdHandle
    
    mov rdx, TempContactNameStrPtr  ; Адрес записи строки
    mov r8, InputContactNameLenMax  ; Максимальное число символов
    lea r9, BytesRead
    mov qword ptr [rsp + 32], 0
    call ReadFile
    call check_error_zero           ; Проверяем результат ReadFile на ошибку
    
    
    ; Считанная строка должна быть меньше InputContactNameLenMax
    mov rax, BytesRead
    cmp rax, InputContactNameLenMax
    jae input_name_not_in_range
    
    ; Удаляем из считанной строки /r/n
    sub rax, 2
    mov r8, TempContactNameStrPtr
    add r8, rax
    mov byte ptr[r8], 0
    mov byte ptr[r8 + 1], 0
    jmp end_input_name
input_name_not_in_range:
    lea rcx, IncorrectInputText
    call Print
    mov eax, -1
end_input_name:
    add rsp, 40
    ret
InputName endp

InputPhoneNumber proc
    sub rsp, 40
    mov rcx, StdHandle
    mov rdx, TempPhoneNumberStrPtr   ; Адрес записи строки
    mov r8, InputPhoneNumberLenMax   ; Максимальное число символов
    lea r9, BytesRead
    mov qword ptr [rsp + 32], 0
    call ReadFile
    add rsp, 40
    call check_error_zero           ; Проверяем результат ReadFile на ошибку
    
    ; Считанная строка должна быть меньше InputPhoneNumberLenMax
    mov rax, BytesRead
    cmp rax, InputPhoneNumberLenMax
    jae input_name_not_in_range
    
    ; Удаляем из считанной строки /r/n
    mov rax, BytesRead
    sub rax, 2                      
    mov r8, TempPhoneNumberStrPtr
    add r8, rax
    mov byte ptr[r8], 0
    mov byte ptr[r8 + 1], 0
    jmp end_input_name
input_name_not_in_range:
    lea rcx, IncorrectInputText
    call Print
    mov rax, -1
end_input_name:
    ret
InputPhoneNumber endp

AddContact proc
    ; Ищем свободное место в массиве контактов
    mov r14, 0 ; Счётчик контактов
    lea r12, ContactArray
    mov r10, 0 ; Счётчик цикла
    mov r11, MAX_CONTACT_COUNT
find_free_contact_loop:
    cmp r10, r11
    je end_find_free_contact_loop

    ; Доступ к первому полю массива = ContactArray + i * 32, где 32 это размер структуры contact
    ; Заносим в r15 адрес на контакт
    mov r15, r10
    shl r15, 5                       ; Умножение на 32
    add r15, r12

    inc r10
    
    ; Проверка на добавленный контакт
    ; Если есть место под новый контакт, то добавляем и выходим из цикла
    mov al, byte ptr [r15]
    cmp al, 1
    je find_free_contact_loop
    mov byte ptr [r15], 1
    
        
    ; Имя
    lea rcx, AddContactNameText
    call Print
    ; Позиция в массиве для записи имени
    mov r8, r15
    add r8, 1
    mov TempContactNameStrPtr, r8
    ; Ввод
    call InputName
    cmp rax, -1
    je add_contact_exit
    
    
    ; Номер телефона
    lea rcx, AddContactPhoneNumberText
    call Print
    
    ; Позиция в массиве для записи номера телефона
    mov r8, TempContactNameStrPtr
    add r8, 19
    mov TempPhoneNumberStrPtr, r8
    ; Ввод
    call InputPhoneNumber
    cmp rax, -1
    je add_contact_exit
   
    ; Успешное добавление нового контакта
    lea rcx, AddResultText
    call Print
    
    jmp add_contact_exit
end_find_free_contact_loop:

    ; Нет места для нового контакта
    lea rcx, AddResultText2
    call Print
add_contact_exit:
    ret
AddContact endp

StringsAreEqual proc
    ; r10 - первая строка
    ; r11 - вторая строка
    mov r9, InputContactNameLenMax + 1 ; максимальная длина строки с null terminator
    
    ; Если адреса строк равны
    cmp r10, r11
    je strings_are_equal
    
    ; Посимвольное сравнение
    mov r8, 0 ; Счётчик и инкремент адреса
compare_loop:
    cmp r8, r9
    je strings_are_equal

    mov al, byte ptr [r10 + r8]
    mov cl, byte ptr [r11 + r8]
    
    cmp al, cl
    jne strings_not_equal
    
    cmp al, 0
    je strings_are_equal
    
    inc r8
    jmp compare_loop
    
strings_not_equal:
    mov rax, 0
    ret
strings_are_equal:
    mov rax, 1
    ret
StringsAreEqual endp


DeleteContact proc
    lea rcx, DeleteContactInputText
    call Print
    
    
    ; Ввод
    mov rcx, StdHandle
    
    sub rsp, 40
    lea rdx, DeleteContactInputBuffer  ; Адрес записи строки
    mov r8, InputContactNameLenMax  ; Максимальное число символов
    lea r9, BytesRead
    mov qword ptr [rsp + 32], 0
    call ReadFile
    call check_error_zero           ; Проверяем результат ReadFile на ошибку
    add rsp, 40
    
    ; Считанная строка должна быть меньше InputContactNameLenMax
    mov rax, BytesRead
    cmp rax, InputContactNameLenMax
    jae input_name_not_in_range
    
    ; Удаляем из считанной строки /r/n
    sub rax, 2
    lea r8, DeleteContactInputBuffer
    add r8, rax
    mov byte ptr[r8], 0
    mov byte ptr[r8 + 1], 0
    jmp end_input_name
input_name_not_in_range:
    lea rcx, IncorrectInputText
    call Print
    mov rax, -1
    jmp incorrect_input
end_input_name:


    ; Проверяем успешно ли считалась строка
    cmp rax, -1
    je incorrect_input
    
    
    ; Поиск контакта по введённому имени
    mov r14, 0 ; Счётчик контактов
    lea r12, ContactArray
    mov r15, 0 ; Счётчик цикла
    mov r11, MAX_CONTACT_COUNT
find_contact_loop:
    cmp r15, r11
    je contact_not_found
    
    ; Получаем строку текущего элемента
    mov rax, r15
    shl rax, 5
    add rax, r12
    
    inc r15
    cmp rax, 0
    je find_contact_loop
    inc rax

    ; Сравнение введённой строки со строкой из книги контактов
    lea r10, DeleteContactInputBuffer
    mov r11, rax
    call StringsAreEqual
    cmp rax, 1
    je contact_found
    

    jmp find_contact_loop
contact_found:
    ; !!! Реализовать Удаление
    mov byte ptr [r11 - 1], 0
    mov byte ptr [r11], 0
    
    lea rcx, DeleteContactResultText
    call Print
    ret
contact_not_found:
    lea rcx, DeleteContactResult2Text
    call Print
    ret
incorrect_input:
    lea rcx, DeleteContactInputResultText
    call Print
    ret
DeleteContact endp

ViewContacts proc
    lea rcx, ViewContactsText
    call Print
    
    mov r14, 0 ; Счётчик контактов
    lea r12, ContactArray
    mov r10, 0 ; Счётчик цикла
    mov r11, MAX_CONTACT_COUNT
view_contacts_loop:
    cmp r10, r11
    je end_view_contacts_loop
    
    ; Доступ к первому полю массива = ContactArray + i * 32, где 32 это размер структуры contact
    ; Заносим в r15 адрес на контакт
    mov r15, r10
    shl r15, 5                       ; Умножение на 32
    add r15, r12
    inc r10
    
    ; Проверка на добавленный контакт
    mov al, byte ptr [r15]
    cmp al, 0
    je view_contacts_loop
    
    ; Позиция в списке контактов (вывод позиции начинается с числа 1)
    inc r14
    mov rdx, r14
    
    ; Имя (после флага добавленного контакта)
    mov r8, r15
    add r8, 1

    ; Телефон (после имени)
    mov r9, r8
    add r9, 19
    
    push r14
    push r10
    push r11
    push r12
    lea rcx, ViewContactText
    call Print
    pop r12
    pop r11
    pop r10
    pop r14
    
    jmp view_contacts_loop
end_view_contacts_loop:
    call PrintEndLine
    call PrintEndLine
    ret
ViewContacts endp

PhoneBookOperation proc
    ; Если подобных операций сравнения будет много, то можно создать массив с указателями на функции и по ним делать вызовы (сделать имитацию работы switch)

    cmp rax, 0
    je operation_not_fount
    cmp rax, 4
    ja operation_not_fount
operation1:
    cmp rax, 1
    jne operation2
    call AddContact
    jmp end_convertion
operation2:
    cmp rax, 2
    jne operation3
    call DeleteContact
    jmp end_convertion
operation3:
    cmp rax, 3
    jne operation4
    call ViewContacts
    jmp end_convertion
operation4:
    cmp rax, 4
    mov rax, 0
    call ExitProcess
operation_not_fount:
    lea rcx, OperationNotFound
    call Print
end_convertion:
    ret
PhoneBookOperation endp

main proc
    lea rax, ContactArray
    
    sub rsp, 40
    mov rcx, -10                    ; STD_INPUT_HANDLE ((DWORD)-10). Стандартное устройство ввода
    call GetStdHandle
    mov StdHandle, rax
    add rsp, 40
    
main_loop:
    ; Выбор операции
    lea rcx, IntroText
    call Print
    call InputText
    ;call CheckRangeError
    call ConvertString
    push rax
    call PrintEndLine
    pop rax

    call PhoneBookOperation
    jmp main_loop
    
    ret
main endp
end