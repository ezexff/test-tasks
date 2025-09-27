includelib kernel32.lib
includelib ucrt.lib
includelib legacy_stdio_definitions.lib

extrn printf:PROC

.const
ARRAY_LENGTH = 10

ArrayBeforeSortStr byte "Array before sort: ", 0, 0dh, 0ah
ArrayAfterSortStr byte "Array after sort: ", 0, 0dh, 0ah
DecValueStr byte "%d ", 0
EndLineStr byte 0dh, 0ah, 0

.data
Array qword ARRAY_LENGTH dup (0)

.code

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

PrintArray proc
    mov r11, ARRAY_LENGTH
    shl r11, 3 ; Умножение на 8 (размер массива в байтах)
    lea r9, Array
    mov r10, 0 ; Счётчик
print_array_loop:
    cmp r10, r11
    je end_print_array_loop
    
    lea rcx, DecValueStr
    mov rdx, [r9 + r10]
    push r9
    push r10
    push r11
    call Print
    pop r11
    pop r10
    pop r9
    
    add r10, 8
    jmp print_array_loop
end_print_array_loop:
    call PrintEndLine
    ret
PrintArray endp

BubbleSortArray proc
    lea r8, Array         ; Указатель на массив
    
    mov r12, ARRAY_LENGTH ; Число интераций внешнего цикла (в байтах)
    shl r12, 3
    mov r14, r12          ; Число итераций внутреннго цикла (в байтах)     
    sub r14, 8
    mov r10, 0            ; Счётчик внешнего цикла
outer_loop:
    cmp r10, r12
    je exit_outer_loop
    mov r11, 0            ; Счётчик внутреннего цикла
    mov r9, 1             ; Флаг проверки отсортирован ли массив
inner_loop:
    cmp r11, r14
    je exit_inner_loop
    
    ; Swap
    mov rax, [r8 + r11]
    mov rcx, [r8 + r11 + 8]
    cmp rax, rcx
    jbe skip_swap
    mov [r8 + r11], rcx
    mov [r8 + r11 + 8], rax
    mov r9, 0             ; Массив не отсортирован
skip_swap:
    add r11, 8
    jmp inner_loop
exit_inner_loop:
    ; Если во время внутренней итерации не было операции swap, то значит массив отсортирован
    cmp r9, 1
    je exit_outer_loop
    
    add r10, 8
    jmp outer_loop
exit_outer_loop:
    ret
BubbleSortArray endp

main proc
    ; Инициализация массива
    lea rax, Array
    mov r11, 100
    mov [rax + 0], r11
    mov r11, 97
    mov [rax + 8], r11
    mov r11, 55
    mov [rax + 16], r11
    mov r11, 526
    mov [rax + 32], r11
    mov r11, 432
    mov [rax + 40], r11
    mov r11, 4
    mov [rax + 48], r11
    mov r11, 876
    mov [rax + 56], r11
    mov r11, 7
    mov [rax + 64], r11
    mov r11, 46
    mov [rax + 72], r11
    mov r11, 22
    mov [rax + 80], r11
    
    ; Вывод массива
    lea rcx, ArrayBeforeSortStr
    call Print
    call PrintArray
    
    ; Сортировка
    call BubbleSortArray
    
    ; Вывод массива
    lea rcx, ArrayAfterSortStr
    call Print
    call PrintArray
    ret
main endp
end