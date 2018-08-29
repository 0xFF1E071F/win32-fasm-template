;
;   Simple Hello World using Runtime Loading
;   Written by x0r19x91
;
;   Date : 22:47 29-08-2018
;

    format PE GUI 6.0
    entry main
    include '\fasm\include\win32ax.inc'

struc UNICODE_STRING [bytes]
{
        .   dw  .size, .size
            dd  .bytes
    .bytes  du  bytes
    .size   =   $-.bytes
}

struc ANSI_STRING [bytes]
{
        .   dw  .size, .size
            dd  .bytes
    .bytes  db  bytes
    .size   =   $-.bytes
}

macro init_dll dll_id, dll_name, [func_name]
{
    common
        label dll_id
        .size = 0
    common
        .dll  UNICODE_STRING dll_name
        label .functions
    forward
        .size = .size + 1
    forward
        dd func_name, fn#func_name
    forward
        label func_name dword
        .str ANSI_STRING `func_name
    forward
        label fn#func_name dword
        dd  0
}

macro load_dll [dll_id]
{
    forward
    push ebx
    push ebx
    local ..next, ..load_loop
..next:
    mov eax, esp
    invoke fnLdrLoadDll, 1, 0, dll_id#.dll, eax
    xor ebx, ebx
..load_loop:
    mov eax, [dll_id#.functions+ebx*8+4]
    invoke fnLdrGetProcedureAddress, dword [esp+12], dword [dll_id#.functions+ebx*8], 0, eax
    inc ebx
    cmp ebx, dll_id#.size
    jl ..load_loop
    pop ebx
    pop ebx
}

section '.data' data readable writeable

    fnLdrLoadDll                dd      0
    fnLdrGetProcedureAddress    dd      0

    data 9
        .tls        dd  0, 0, .index, .callbacks, 0, 0
        .callbacks  dd  initialize
        .index      dd  0
    end data

    init_dll user32, 'user32.dll', MessageBoxTimeoutA
    init_dll kernel32, 'kernel32.dll', ExitProcess

    aMsg    db  'Hello World of Win32 Programming !', 0
    aCap    db  'NtDll Rocks !!', 0


section '.text' code executable writeable

    LDR_LOAD_DLL    =   26c4b1f1h
    LDR_GETPROC     =   69a5e1fbh

jenkins_hash:
    push ebx
    xor eax, eax
@@:
    movzx ebx, byte [esi]
    or bl, bl
    jz @f
    add eax, ebx
    mov ebx, eax
    shl ebx, 10
    add eax, ebx
    mov ebx, eax
    shr ebx, 6
    xor eax, ebx
    inc esi
    jmp @b
@@:
    mov ebx, eax
    shl ebx, 3
    add eax, ebx
    mov ebx, eax
    shr ebx, 11
    xor eax, ebx
    mov ebx, eax
    shl ebx, 15
    add eax, ebx
    pop ebx
    ret


initialize:
    mov eax, [fs:0x30]
    mov eax, [eax+12]
    mov eax, [eax+0x1c]
    mov ebx, [eax+8]
    mov eax, [ebx+0x3c]
    mov eax, [eax+ebx+24+96]
    add eax, ebx
    push eax
    mov ecx, [eax+24]
    mov ebp, [eax+32]   ; name table
    mov edx, [eax+36]   ; ordinal table
    add edx, ebx
    add ebp, ebx
    xor edi, edi

.search_loop:
    mov esi, [ebp]
    add esi, ebx
    call jenkins_hash
    cmp eax, LDR_LOAD_DLL
    jnz .is_proc_addr
    inc edi
    movzx eax, word [edx]
    mov [fnLdrLoadDll], eax
    jmp .next_func

.is_proc_addr:
    cmp eax, LDR_GETPROC
    jnz .next_func
    inc edi
    movzx eax, word [edx]
    mov [fnLdrGetProcedureAddress], eax

.next_func:
    add edx, 2
    add ebp, 4
    cmp edi, 2
    jz @f
    dec ecx
    jnz .search_loop

@@:
    pop edi
    mov edx, [edi+28]
    add edx, ebx
    mov eax, [fnLdrLoadDll]
    mov ecx, [edx+eax*4]
    add ecx, ebx
    mov [fnLdrLoadDll], ecx
    mov eax, [fnLdrGetProcedureAddress]
    mov ecx, [edx+eax*4]
    add ecx, ebx
    mov [fnLdrGetProcedureAddress], ecx

;
;   Entry Point
;
main:
    ; TODO: Write Code Here
    load_dll kernel32, user32
    invoke fnMessageBoxTimeoutA, 0, aMsg, aCap, 0x40, 0, 2000
    invoke fnExitProcess, 0
