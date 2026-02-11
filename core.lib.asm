; This library contains functions and variables used by this project.
; Most functions are own implementations/replacments for glibc functions.
; The ultimate goal of this library is to replace the glibc usage across this project entirely

; Syscall register assignment: 
; rdi - rsi - rdx - r10 - r8 - r9 - rax = Syscall-number

; Functions in this file with have the following preceeding commentary layout:
; Replacement-function for:
; <glibc function signature>
; (Optional) --> needed libcalls: <names of need functions from this library> 
; (Optional) --> needed syscalls: <names of needed linux kernel syscalls>
; (Optional) --> needed asm-inst: <needed assembly instructions>
; (Optional) >>> <kernel syscall signatures> or <glibc function signatures>
; (Optional) <<< <additional implementation notes - behavior, special cases, ...>

; NOTE: all types (+ their extensions) in all signatures of the glibc functions
; are all seen as 64-bit/8-bytes in size here --> they take up one r* register each
; This is for protability purposes


section .bss
    SYS_ERRNO:  resd 0x01   ; custome errno status variable
section .data
section .text

global SYS_ERRNO, sys_malloc, sys_free, sys_realloc, sys_memset, sys_calloc, sys_strlen, sys_atoi

%include "core.lib.inc"

%macro SET_ERRNO 0
    neg     eax             ; negate rax
    mov     [SYS_ERRNO], eax; store the value in eax into sys_errno
%endmacro


; Replacement-function for: 
; int printf(const char *restrict format, ...);
; --> needed libcalls: 
; --> needed syscalls: 
; --> needed asm-inst: 
sys_printf: 
    .enter: ENTER
    



    .return: 
        LEAVE
        ret


; Replacement-function for: 
; void *malloc(size_t size);
; --> needed syscalls: mmap
; >>> void *mmap(void addr[.length], size_t length, int prot, int flags,
;                int fd, off_t offset);
; <<< if size == 0: return invalid pointer NULL
sys_malloc: 
    .enter: ENTER

    cmp     rdi, 0x00   ; check if parameter size_t size is 0
    je      .invalid    ; if its 0, then return NULL
    ; else allocate the memory

    mov     rax, SYS_MMAP ; move syscall number into rax
    mov     rsi, rdi    ; parameter length = size_t size in rdi
    add     rsi, MEM_HEAD_LEN  ; add to length additional bytes for header
    push    rsi         ; push length to stack for later use - stack alignment doesnt matter now
    xor     rdi, rdi    ; parameter addr[.length] = NULL
    mov     rdx, PROT_READ | PROT_WRITE ; parameter prot
    mov     r10, MAP_PRIVATE | MAP_ANONYMOUS ; parameter flags
    mov     r8, -1      ; parameter fd = -1
    xor     r9, r9      ; parameter offset = 0
    syscall             ; Execute mmap --> rax = addr of allocated memory or MAP_FAILED

    test     rax, rax       ; check if rax is invalid / mmap failed 
    js      .error          ; if its invalid meaning negative, set rax to NULL and exit this function 
    ; else write allocation information into the memory block
    pop     rsi             ; get length from stack
    mov     [rax], rsi      ; move into the memory region the size of it that we pushed onto stack before
    lea     rax, [rax+MEM_HEAD_LEN]  ; add len of header to the pointer -> rax now points to usable memory
    jmp     .return          ; return from function

    .error:
        SET_ERRNO           ; set sys_errno with the value in rax (-eax)
        pop     rax         ; clear the pushed length
        ; also fall through to invalid section
    .invalid: 
        mov     rax, NULL   ; move NULL into rax
    .return:
        LEAVE
        ret


; Replacement-function for: 
; void *calloc(size_t nmemb, size_t size);
; --> needed libcalls: sys_malloc, sys_memset
; >>> void *malloc(size_t size);
; >>> void *memset(void s[.n], int c, size_t n);
; <<< if nmemb * size doesnt fit rax when multiplying, we ignore it and use rax anyways
sys_calloc: 
    .enter: ENTER

    mov     rax, rdi    ; move factor into rax for MUL
    xor     rdx, rdx    ; clear rdx so it doesnt mess with MUL
    mul     rsi         ; rsi*rax = size_t nmemb * size_t size
    push    rax         ; push rax to stack for later use
    mov     rdi, rax    ; parameter size = calculated memory size
    call    sys_malloc  ; allocate memory with sys_malloc --> ptr in rax

    test     rax, rax   ; compare if rax contains a valid pointer
    jz      .invalid    ; if it does not, immediately exit the function
    ; else zero out the memory
    mov     rdi, rax    ; parameter s[.n] = move pointer to memory into rdi
    mov     rsi, 0x00   ; parameter c = 0x00 (empty byte)
    pop     rdx         ; parameter n = size of memory pushed to stack from earlier
    call    sys_memset  ; set memory at adress in rdi to 0x00
    jmp     .return     ; return from function

    .invalid: 
        add     rsp, 0x08  ; remove pushed rax without poping it
    .return: 
        LEAVE
        ret


; Replacement-function for: 
; void *realloc(void *_Nullable ptr, size_t size);
; --> needed syscalls: mremap
; >>> void *mremap(void old_address[.old_size], size_t old_size,
;              size_t new_size, int flags, ... /* void *new_address */);
; <<< On error, we return the old pointer, but also set an errror-code (that follow the mremap convention for better debugging)
sys_realloc: 
    .enter: ENTER

    test    rdi, rdi        ; check if ptr is NULL or not
    jnz     .do_realloc     ; if its not NULL, proceed with a normal realloc
    ; else do a malloc like its specified in the standard: if ptr == NULL, then its like a malloc(size) call
    .do_malloc:
        mov     rdi, rsi    ; parameter size - discard NULL-ptr in rdi
        call    sys_malloc  ; allocate memory using sys_malloc --> rax = ptr to memory or NULL on error
        jmp     .return     ; return from function
    .do_realloc:
    push    rdi             ; save parameter ptr to stack for potential later use

    mov     rax, SYS_MREMAP ; move syscall number into rax
    lea     rdi, [rdi-MEM_HEAD_LEN] ; parameter old_address[.old_size] from parameter ptr in rdi (- len of header)
    lea     rdx, [rsi+MEM_HEAD_LEN] ; parameter new_size from parameter size in rsi (+ len of header)
    push    rdx             ; save parameter new_size in stack for later use
    mov     rsi, [rdi]      ; parameter old_size - stored in head of memory region
    mov     r10, MREMAP_MAYMOVE     ; parameter int flags
    syscall                 ; execute mremap --> rax = new address or neg number on error
    test    rax, rax        ; check if rax is a negativ number, meaning if we got an error
    js     .invalid         ; if the syscall returned an error, jmp to .invalid

    ; else add the size of the new memory region into the memory region
    pop     rsi             ; get new_size from stack
    mov     [rax], rsi      ; write new_size into memory header
    lea     rax, [rax+MEM_HEAD_LEN] ; move into rax the user-pointer
    add     rsp, 0x08       ; remove pushed parameter ptr from stack without poping it
    jmp     .return         ; return from function

    .invalid:  ; set rax to previous pointer to old memory
        SET_ERRNO           ; set sys_errno with the value in rax (-eax)
        pop     rax         ; clear the new_size from stack 
        pop     rax         ; get pushed old address from stack and save into rax
    .return: 
        LEAVE
        ret


; Replacement-function for: 
; void free(void *_Nullable ptr);
; --> needed syscalls: munmap
; >>> int munmap(void addr[.length], size_t length)
; <<< if munmap returned with an error, we also return the error here, but dont really care about it --> just in case
sys_free:
    ; no prolog or epilod needed

    cmp     rdi, NULL       ; compare if parameter ptr is 0
    je      .return          ; if its NULL, we do nothing
    ; else we free the memory

    mov     rax, SYS_MUNMAP ; move syscall number into rax
    lea     rdi, [rdi-MEM_HEAD_LEN]  ; parameter ptr - subtract the header-area from memory pointer
    mov     rsi, [rdi]      ; parameter length - is stored in the first 8 byte of the memory
    syscall                 ; free the memory pointed to by parameter ptr --> rax = success/error
    test    rax, rax        ; check if munmap failed
    js      .invalid        ; if there was an error, set SYS_ERRNO
    jmp     .return         ; else just leave and return from this function

    .invalid: 
        SET_ERRNO           ; set sys_errno with the value in rax (-eax)
    .return: ret
    
    
; Replacement-function for: 
; size_t strlen(const char *s);
; --> needed syscalls: -
sys_strlen: 
    ; no prolog or epilog needed

    xor     rax, rax        ; clear rax and use it as an index and for the length storage
    .for: 
        cmp     byte [rdi+rax], 0x00 ; compare current char to null-terminator
        je      .return     ; if it matches, return from function
        inc     rax         ; increment length
        jmp     .for        ; continue the loop

    sub     rax, 0x01       ; we have to exclude the null terminator
    .return: ret

; Replacement-function for:
; void *memset(void s[.n], int c, size_t n);
; --> needed asm-inst: rep stosb
sys_memset:
    ; no prolog or epilog needed 

    ; rdi - parameter s[.n] - rdi already contains destination memory address
    mov     r9, rdi     ; save s[.n] into r9 for later use
    mov     rcx, rdx    ; move parameter n into counter register
    mov     al, sil     ; move parameter c into al
    cld                 ; clear direction flag so that we overwrite upwards from the base memory address
    rep stosb           ; overwrite whole allocated memory with char in al

    mov     rax, r9     ; move r9/s[.n] into rax for returning
    .return: ret


; Replacement function for:
; int atoi(const char *nptr);
sys_atoi:  
    .enter: ENTER

    ; init registers needed for convertion
    mov     rsi, rdi       ; copy ascii string into source register
    xor     rdi, rdi       ; clear rdi & use it for temporary storage of current extracted ascii char
    xor     rax, rax       ; clear rax for storing/returning the extracted number
    xor     rcx, rcx       ; clear counter registerfor indexing the string
    mov     r8, 0xA        ; factor for MUL to make space for next number
    .for:  ; loop through every ascii char
        mov    dil, [rsi+rcx]  ; move current byte to be converted into 8-bit part of rdx
        cmp    dil, 0x00       ; if the current byte is a null terminator
        je     .return         ; we are finished and return from this function
        ; else continue converting the ascii

        mul    r8              ; multiply rax by 10 so to make space for another number
        sub    dil, 0x30       ; sub 32 from ascii to convert it to int
        add    rax, rdi        ; add the int to rax
        inc    rcx             ; counter++
        jmp    .for            ; continue the loop

    .return:  ; return from function --> number in rax 
        LEAVE
        ret