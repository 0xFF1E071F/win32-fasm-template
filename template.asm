    format PE GUI
    include '\fasm\include\win32ax.inc'
    entry initialize

macro init_dll dll_id, dll_name, [func_name]
{
    common
        label dll_id
        .size = 0
        .dll db dll_name, 0
        label .functions
    forward
        .size = .size + 1
    forward
        dd func_name, fn#func_name
    forward
        label func_name dword
        .str db `func_name, 0
    forward
        label fn#func_name dword
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
    mov eax, esp
    invoke fnLoadLibraryEx, dll_id#.dll, 0, 0
    mov esi, eax
    xor ebx, ebx
..load_loop:
    invoke fnGetProcAddress, esi, dword [dll_id#.functions+ebx*8]
    mov edx, [dll_id#.functions+ebx*8+4]
    mov [edx], eax
    inc ebx
    cmp ebx, dll_id#.size
    jl ..load_loop
    pop edx
    pop esi
    pop ebx
}


section '.data' data readable writeable

    fnGetProcAddress    dd  0
    fnLoadLibraryEx     dd  0

    ;
    ; Declaring imports in a dll
    ; init_dll [dll_id], [dll_name], [function_1], [function_2], ...
    ;
    ; For Example
    ; init_dll user32, 'user32.dll', MessageBoxTimeoutA
    ; init_dll kernel32, 'kernel32.dll', ExitProcess
    ;


section '.text' code executable

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

hash:
    push ebx
    xor eax, eax
    sub esi, 2
@@:
    inc esi
    inc esi
    movzx ebx, word [esi]
    or ebx, ebx
    jz .ret
    ror eax, 9
    xor eax, ebx
    cmp ebx, 0x61
    jl @b
    cmp ebx, 0x7b
    jge @b
    xor eax, ebx
    sub ebx, 0x20
    xor eax, ebx
    jmp @b
.ret:
    pop ebx
    ret

initialize:
    mov eax, [fs:0x30]
    mov eax, [eax+12]
    mov ebx, [eax+0x1c]

.find:
    mov esi, [ebx+0x20]
    call hash
    cmp eax, KERNEL32_HASH
    jz .found
    mov ebx, [ebx]
    jmp .find

.found:
    mov ebx, [ebx+8]
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
    cmp eax, LOAD_LIBRARY
    jnz .is_proc_addr
    inc edi
    movzx eax, word [edx]
    mov [fnLoadLibraryEx], eax
    jmp .next_func

.is_proc_addr:
    cmp eax, GET_PROC_ADDRESS
    jnz .next_func
    inc edi
    movzx eax, word [edx]
    mov [fnGetProcAddress], eax

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
    mov eax, [fnLoadLibraryEx]
    mov ecx, [edx+eax*4]
    add ecx, ebx
    mov [fnLoadLibraryEx], ecx
    mov eax, [fnGetProcAddress]
    mov ecx, [edx+eax*4]
    add ecx, ebx
    mov [fnGetProcAddress], ecx
    jmp main

;
;   Entry Point
;
main:
    ; TODO: Write Code Here
    ; To load a library and get addresses of imports
    ; load_dll [dll_id1], [dll_id2], ...

