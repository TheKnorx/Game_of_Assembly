section .bss
section .data
    ALLOC_ERROR_TEXT:   db "Calloc failed"
section .text

global try_alloc_fields
; Project internal functions and variables
extern FIELD_AREA, FIELDS_ARRAY
; glibc functions
extern calloc, _exit, NULL, perror

try_alloc_fields:  
    ; Prolog
    push    rbp
    mov     rbp, rsp
    and     rsp, -16

    push    r12             ; make r12 available for storage

    xor     r12, r12        ; index for loop --> set to 0
    .for: 
        cmp     r12, 0x2        ; if r12 >= 2, then break the loop
        jge     .return         ;   by returning from this function

        ; allocate the first game field
        ; void *calloc(size_t nmemb, size_t size);
        xor     rax, rax        ; clear rax
        mov     rdi, [FIELD_AREA]; size_t nmemb
        mov     rsi, 0x1        ; allocate nmemb units of size 1 byte
        call    calloc          ; pointer to allocated memory in rax
        test    rax, rax        ; if rax == NULL, the allocation failed
        jz      .failed         ;   and we print a error message and exit the program
        mov     [FIELDS_ARRAY+0x8*r12], rax  ; move pointer to correct array-field into field pointer array
        ; continue allocating the next game field

        inc     r12             ; r12++
        jmp     .for            ; continue to next loop iteration

    .failed:  ; print some error information; !NORETURN!
        pop     r12
        ; void perror(const char *s);
        xor     rax, rax        ; clear rax
        mov     rdi, ALLOC_ERROR_TEXT   ;const chat *s
        call    perror
        mov     rax, -1         ; move exit code into rax
        call    _exit           ; exit the program
        hlt                     ; we should never reach this code

    .return:
        pop     r12         ; pop the pushed register
        ; Epilog
        mov     rsp, rbp
        pop     rbp
        ret


