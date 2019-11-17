format PE GUI
include '\fasm\include\win32ax.inc'
entry initialize

struc UNICODE_STRING [bytes]
{
    .len        dw  .ssize
    .maxlen     dw  .size
    .pBuffer    dd  .str
    .str        du  bytes
    .ssize      =   $-.str
                dw  0
    .size       =   $-.str+2
}

struc ANSI_STRING [bytes]
{
    .len        dw  .ssize
    .maxlen     dw  .size
    .pBuffer    dd  .str
    .str        db  bytes
    .ssize      =   $-.str
                db  0
    .size       =   $-.str+2
}

macro init_dll dll_id, dll_name, [func_name]
{
    common
        label dll_id
        .size = 0
        .dll UNICODE_STRING dll_name
    forward
        .size = .size + 1
    common
        label .functions
    forward
        dd sz#func_name, func_name
    forward
        label sz#func_name dword
        .str ANSI_STRING `func_name
    forward
        label func_name dword
        dd  0
}

macro push [reg] { forward push reg }
macro pop [reg] { reverse pop reg }

macro load_dll [dll_id]
{
    forward
    push ebx
    push esi
    push edx
    local ..next, ..load_loop
..next:
    push 0
    mov esi, esp
    push 0
    mov ebx, esp
    invoke LdrLoadDll, 0, ebx, dll_id#.dll, esi
    pop esi
    pop esi
    xor ebx, ebx
..load_loop:
    invoke LdrGetProcedureAddress, esi, dword [dll_id#.functions+ebx*8], 0, dword [dll_id#.functions+ebx*8+4]
    inc ebx
    cmp ebx, dll_id#.size
    jl ..load_loop
    pop edx
    pop esi
    pop ebx
}


section '.data' data writeable

    LdrLoadDll    dd  0
    LdrGetProcedureAddress    dd 0

    ; init_dll dll_id, "dll_name", func1, func2, ...

section '.code' code readable executable

    LDR_LOAD_DLL = 0x032855A46
    LDR_GET_PROC_ADDR = 0x050E39822

hash:
    push ebx
    xor ebx, ebx
    xor eax, eax
@@:
    rol ebx, 9
    xor bl, al
    lodsb
    or al, al
    jnz @b
    mov eax, ebx
    pop ebx
    ret

initialize:
    mov eax, [fs:0x30]
    mov eax, [eax+0xc]  ; peb_ldr_module
    mov ebx, [eax+0x1c]
    mov ebx, [ebx+8]
    
    mov eax, [ebx+0x3c]
    mov eax, [eax+ebx+24+96]
    add eax, ebx
    push eax
    mov ecx, [eax+24]
    mov ebp, [eax+32]
    mov edx, [eax+36]
    add edx, ebx
    add ebp, ebx
    xor edi, edi

.search:
    mov esi, [ebp]
    add esi, ebx
    call hash
    cmp eax, LDR_LOAD_DLL
    jnz .isProcAddr
    inc edi
    movzx eax, word [edx]
    mov [LdrLoadDll], eax
    jmp .next

.isProcAddr:
    cmp eax, LDR_GET_PROC_ADDR
    jnz .next
    inc edi
    movzx eax, word [edx]
    mov [LdrGetProcedureAddress], eax

.next:
    add edx, 2
    add ebp, 4
    cmp edi, 2
    jz @f
    dec ecx
    jnz .search

@@:
    pop edi
    mov edx, [edi+28]
    add edx, ebx
    mov eax, [LdrLoadDll]
    mov ecx, [edx+eax*4]
    add ecx, ebx
    mov [LdrLoadDll], ecx
    mov eax, [LdrGetProcedureAddress]
    mov ecx, [edx+eax*4]
    add ecx, ebx
    mov [LdrGetProcedureAddress], ecx
    jmp main

; Entry Point
main:
  ; load dlls
  ; load_dll dll_id1, dll_id2, ...
