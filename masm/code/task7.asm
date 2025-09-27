includelib kernel32.lib
includelib user32.lib
includelib comdlg32.lib

extrn GetModuleHandleA: PROC
extrn RegisterClassA: PROC
extrn CreateWindowExA: PROC
extrn DefWindowProcA: PROC
extrn GetMessageA: PROC
extrn TranslateMessage: PROC
extrn DispatchMessageA: PROC
extrn MessageBoxA: PROC
extrn GetOpenFileNameA: PROC
extrn CreateFileA: PROC
extrn ReadFile: PROC
extrn SetWindowTextA: PROC
extrn BeginPaint: PROC
extrn FillRect: PROC
extrn EndPaint: PROC

extrn ExitProcess: PROC
extrn GetLastError: PROC

WNDCLASSA struct 8 ; 72 байта
    Style1 dword ?           ; UINT      style           CS_VREDRAW 0x0001 | CS_HREDRAW 0x0002
    LpfnWndProc qword ?     ; WNDPROC   lpfnWndProc                         rsp+8
    CbClsExtra dword ?      ; int       cbClsExtra
    CbWndExtra dword ?      ; int       cbWndExtra
    HInstance qword ?       ; HINSTANCE hInstance                           rsp+24
    HIcon qword ?           ; HICON     hIcon
    HCursor qword ?         ; HCURSOR   hCursor
    HbrBackground qword ?   ; HBRUSH    hbrBackground   COLOR_WINDOW = 5
    LpszMenuName qword ?    ; LPCSTR    lpszMenuName
    LpszClassName qword ?   ; LPCSTR    lpszClassName                       rsp+64
WNDCLASSA ends

OPENFILENAMEA struct 8
    lStructSize dword ?
    hwndOwner qword ?
    hInstance qword ?
    lpstrFilter qword ?
    lpstrCustomFilter qword ?
    nMaxCustFilter dword ?
    nFilterIndex dword ?
    lpstrFile qword ?
    nMaxFile dword ?
    lpstrFileTitle qword ?
    nMaxFileTitle dword ?
    lpstrInitialDir qword ?
    lpstrTitle qword ?
    Flags dword ?
    nFileOffset word ?
    nFileExtension word ?
    lpstrDefExt qword ?
    lCustData qword ?
    lpfnHook qword ?
    lpTemplateName qword ?
    ;lpEditInfo qword ?
    ;lpstrPrompt qword ?
    pvReserved qword ?
    dwReserved dword ?
    FlagsEx dword ?
OPENFILENAMEA ends

PAINTSTRUCT struct 4
    hdc qword ?
    fErase dword ?
    rcPaint byte 16 dup (?)
    fRestore dword ?
    fIncUpdate dword ?
    rgbReserved byte 32 dup (?)
PAINTSTRUCT ends

.const

INVALID_HANDLE_VALUE = -1
WM_COMMAND = 0111h
WM_PAINT   = 000Fh
COLOR_WINDOW = 17

; Окно
WindowClassName byte "WindowTask7", 0    ; Возможно RegisterClassA копирует строку в стек?
WindowText byte "WindowTask7 title!", 0
WindowStyle = 10cf0000h                  ; WS_OVERLAPPEDWINDOW | WS_VISIBLE
CW_USEDEFAULT = 80000000h

; Кнопка
ButtonID = 1
ButtonClassName byte "button", 0
ButtonText byte "Open file", 0
ButtonStyle = 1342177280                 ; WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON

; Текстовое поле
EditClassName byte "edit", 0
EditText byte "Opened file will be here", 0
EditStyle = 50800044h                    ; WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOVSCROLL | ES_MULTILINE

; MessageBox
MB_OK = 00000000h
MessageBoxTitle byte "Filed loaded", 0
MessageBoxText byte "fsdfdsfs", 0

; OpenFileName
OpenFileNameFlags = 00001800h
ES_AUTOHSCROLL = 0080h


.data
WindowHandle qword ?
ButtonHandle qword ?

MainInstance qword ?
MessageStorage byte 200 dup (0)
Paint PAINTSTRUCT <>

WindowClass WNDCLASSA <>
OpenFileName OPENFILENAMEA <>
FileName byte 260 dup (0)
;FileName byte "testfile.txt", 0
FileNameSize = $ - FileName
LpstrFilter byte ".txt"

ReadFileBuffer byte 1048576 dup (0)      ; Буфер размером 1024 * 1024 байт
ReadFileBufferLen = $ - ReadFileBuffer
FileHandle qword ?
BytesRead qword ?

EditHandle qword ?

TmpWndProcHwnd qword ?

.code

check_error_zero proc
    cmp rax, 0
    jnz check_error_zero_exit
    sub rsp, 40
    call GetLastError
    mov rcx, rax
    call ExitProcess
    add rsp, 40
check_error_zero_exit:
    ret
check_error_zero endp

ReadWindowsFile proc
    sub rsp, 56
    lea rcx, FileName   ; lpFileName
    mov rdx, 80000000h  ; dwDesiredAccess GENERIC_READ
    mov r8, 0           ; dwShareMode
    mov r9, 0           ; lpSecurityAttributes
    mov r10, 4          ; dwCreationDisposition OPEN_ALWAYS = 4
    mov [rsp + 32], r10
    mov r10, 128        ; dwFlagsAndAttributes FILE_ATTRIBUTE_NORMAL 128 (0x80)
    mov [rsp + 40], r10 
    mov [rsp + 48], r8  ; hTemplateFile
    call CreateFileA
    
    cmp rax, INVALID_HANDLE_VALUE
    jne continue_read
    call ExitProcess
continue_read:
    mov FileHandle, rax
    
    mov rcx, rax                ; hFile
    lea rdx, ReadFileBuffer     ; lpBuffer
    mov r8d, ReadFileBufferLen   ; nNumberOfBytesToRead
    lea r9, BytesRead           ; lpNumberOfBytesRead
    mov qword ptr [rsp + 32], 0 ; lpOverlapped
    call ReadFile
    call check_error_zero
    add rsp, 56
    ret
ReadWindowsFile endp

WindowProc proc ; WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
    sub rsp, 40

    mov TmpWndProcHwnd, rcx

    ; Проверяем uMsg
    cmp rdx, WM_COMMAND
    je wm_command_events
    
    cmp rdx, WM_PAINT
    je wm_paint_events
   
    jmp exit

wm_command_events:
    ; Событие нажатия на кнопку
    cmp r8, ButtonID
    je button_event
    
    jmp exit
button_event:

    mov rcx, 0
    ;lea rdx, MessageBoxText
    ;lea r8, MessageBoxTitle
    ;mov r9, MB_OK
    ;call MessageBoxA
    
    ; Диалоговое окно с выбором файла
    lea rcx, OpenFileName
    call GetOpenFileNameA
    
    ; Если файл выбран, то отображение содержимого в текстовом поле
    cmp rax, 1          ; Если пользователь задал имя файла и нажал кнопку ОК
    jne exit
    call ReadWindowsFile
    mov rcx, EditHandle
    lea rdx, ReadFileBuffer
    call SetWindowTextA
    jmp exit
wm_paint_events:
    ; Очищаем структуру для рисования
    lea rax, Paint
    mov r10, 200
    mov r11, 0
clear_start:
    cmp r11, r10
    je clear_end
    mov byte ptr [rax], 0
    inc r11
    jmp clear_start
clear_end:

    ; Заполняем окно цветом
    mov rcx, TmpWndProcHwnd
    lea rdx, Paint
    call BeginPaint

    mov rcx, rax
    lea rdx, Paint.rcPaint
    mov r8, COLOR_WINDOW
    call FillRect
    
    mov rcx, TmpWndProcHwnd
    lea rdx, Paint
    call EndPaint
    jmp exit
    
exit:

    call DefWindowProcA
    
    add rsp, 40
    ret
WindowProc endp

main proc
    sub rsp, 104 ; 96 используется для аргументов и 8 выравнивание
    ; !!!!!
    ; После call, rsp на позиции 16 * n + 8
    ; Согласно правилам masm, перед call, rsp нужно выровнять по 16
    ; Следовательно при call нужно, чтобы стек был размером 16 * n + 8
    ; !!!!!

    ; Получение Handle
    mov rcx, 0
    call GetModuleHandleA
    mov MainInstance, rax
    call check_error_zero
    
    ; Регистрация класса окна
    lea rax, WindowProc
    mov WindowClass.LpfnWndProc, rax
    mov rax, MainInstance
    mov WindowClass.HInstance, rax
    lea rax, WindowClassName
    mov WindowClass.LpszClassName, rax
    lea rcx, WindowClass
    call RegisterClassA
    
    
   
    ; Создание окна
    mov rcx, 0                          ; Window styles
    lea rdx, WindowClassName            ; Window class
    lea r8, WindowText                  ; Window text
    mov r9, WindowStyle                 ; Window style
    
    mov r10, CW_USEDEFAULT
    mov [rsp + 32], r10 ; x
    mov [rsp + 40], r10 ; y
    mov [rsp + 48], r10 ; width
    mov [rsp + 56], r10 ; height
    
    mov r10, 0
    mov [rsp + 64], r10 ; hwndparent    ; Parent window   
    mov [rsp + 72], r10 ; hmenu         ; Menu
    mov rax, MainInstance
    mov [rsp + 80], rax ; hInstance     ; Instance handle
    mov [rsp + 88], r10 ; lpParam       ; Additional application data
    call CreateWindowExA
    
    mov WindowHandle, rax
    call check_error_zero
    
    
    
    ; Инициализация OpenFileName
    nop
    nop
    nop
    mov rax, sizeof(OPENFILENAMEA)
    mov OpenFileName.lStructSize, eax
    mov rax, WindowHandle
    mov OpenFileName.hwndOwner, rax
    lea rax, FileName
    mov OpenFileName.lpstrFile, rax
    mov eax, FileNameSize
    mov OpenFileName.nMaxFile, eax
    lea rax, LpstrFilter
    mov OpenFileName.lpstrFilter, rax
    mov rax, OpenFileNameFlags
    mov OpenFileName.Flags, eax
    mov OpenFileName.lpstrFileTitle, 0
    
    
    ; Создание кнопки
    mov rcx, 0
    lea rdx, ButtonClassName
    lea r8, ButtonText
    mov r9, ButtonStyle
    
    mov rax, 0
    mov [rsp + 32], rax
    mov [rsp + 40], rax
    mov rax, 100
    mov [rsp + 48], rax
    mov rax, 50
    mov [rsp + 56], rax
    
    mov rax, WindowHandle
    mov [rsp + 64], rax
    mov rax, ButtonID
    mov [rsp + 72], rax
    mov rax, 0
    mov [rsp + 80], rax
    mov [rsp + 88], rax
    call CreateWindowExA
    mov ButtonHandle, rax
    call check_error_zero
    
    
    
    ; Создание поля с текстом
    mov rcx, 0
    lea rdx, EditClassName
    lea r8, EditText
    mov r9, EditStyle
    
    mov rax, 100
    mov [rsp + 32], rax
    mov [rsp + 40], rax
    mov rax, 1250
    mov [rsp + 48], rax
    mov rax, 600
    mov [rsp + 56], rax
    
    mov rax, WindowHandle
    mov [rsp + 64], rax
    mov rax, 0
    mov [rsp + 72], rax
    mov [rsp + 80], rax
    mov [rsp + 88], rax
    call CreateWindowExA
    mov EditHandle, rax
    call check_error_zero
    
    
    
message_loop:
    ; Обработка сообщений
    lea rcx, MessageStorage
    mov rdx, 0
    mov r8, 0
    mov r9, 0
    call GetMessageA
    cmp rax, 0
    push rax
    call check_error_zero
    pop rax
    jb exit_message_loop

    lea rcx, MessageStorage
    call TranslateMessage
    
    lea rcx, MessageStorage
    call DispatchMessageA

    jmp message_loop
exit_message_loop:
    add rsp, 104
    ret
main endp
end