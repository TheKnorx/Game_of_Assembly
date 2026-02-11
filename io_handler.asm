section .bss
    CURRENT_FILENAME:   resq 0x01   ; for storing the currently generated file name to write the game field into
    CURRENT_FILESTREAM: resq 0x01   ; for storing the current pointer to the opened file using the generated filename
section .data
    FILENAME:           db "gol_%05d.pbm", 0x00 ; file name for the game saved fields 
    FILENAME_SIZE:      equ 14                  ; size of filename after format expansion
    FOPEN_FILEMODE:     db "w", 0x00            ; file mode to open file with --> create on write
    FILE_PREMABEL:      db "P1", 0x0A, "%d %d", 0x0A, 0x00  ; .pbm files need this for beeing interpreted/displayed correcty
    ERROR_TEXT:         db "A fatal error occured", 0x00  ; error text to be displayed alongside with additional error information
section .text

global try_write_game_field
; glibc functions and variables
extern malloc, snprintf, fopen, fprintf, fputc, _exit, perror, free
; core.lib functions and variables
extern sys_malloc, sys_free
; project intern functions and variables
extern FIELD_AREA, FIELD_WIDTH, FIELD_HEIGHT, GENERATIONS

%include "core.lib.inc"


; function for converting a ascii encoded number to a integer
; yes we could use atoi or snprintf or something similar to this, but where would be the fun in that? why dont DIY?
; (char* ascii_number)[int number]
DEPRECATED_ascii_to_int:  
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


; function for writing a specified game field to a file for later creating that gif
; !we might not return from this function!
; this might get improved in the future by migrating to the usage of virtual memory instead of real file...
; (int* field_to_save, int generation)[]
try_write_game_field: 
    .enter: ENTER 

    push    r12             ; use as temp storage for generation and as index for iterating through the game field
    push    r13             ; use as a temp storage for the passed field pointer
    mov     r13, rdi        ; save field pointer into r13

    ; first "invert" the generation, cause in main we count from high to low
    mov     r12, [GENERATIONS]; move amount of generations into rax
    sub     r12, rsi        ; subtract absolute amount of gens from current "reverse" gen to get to the inverted real gen


    ; then allocate memory for the new file name
    ; void *malloc(size_t size);
    ;xor     rax, rax                ; clear rax for glibc call
    mov     rdi, FILENAME_SIZE      ; parameter size - allocate exactly 14 bytes
    call    sys_malloc              ; allocate space for new filename
    cmp     rax, 0x00               ; check if the pointer from malloc is NULL
    je      .failed                 ; if its NULL, we print an error message and exit
    mov     [CURRENT_FILENAME], rax ; else we store the pointer in the variable

    ; now create the new filename and copy it into the allocated buffer
    ;int snprintf(char str[restrict .size], size_t size,
    ;               const char *restrict format, ...);
    xor     rax, rax                ; clear rax once again for glibc call
    mov     rdi, [CURRENT_FILENAME] ; parameter char str[restrict .size]
    mov     rsi, FILENAME_SIZE      ; parameter size
    mov     rdx, FILENAME           ; parameter char *restrict format
    mov     rcx, r12                ; format parameter - fill into the filename the generation
    call    snprintf                ; do the magick!
    cmp     rax, 0x00               ; compare return value of snprintf --> success means not negative
    jl      .failed                 ; the return value is negativ fuck --> print error and exit

    ; next open the file using the newly generated filename
    ; FILE *fopen(const char *restrict pathname, const char *restrict mode);
    xor     rax, rax                ; clear rax
    mov     rdi, [CURRENT_FILENAME] ; parameter *restrict pathname
    mov     rsi, FOPEN_FILEMODE     ; parameter *restrict mode
    call    fopen                   ; create the new file and open it
    cmp     rax, 0x00               ; compare return value of fopen --> success means != NULL
    je      .failed                 ; the return value == NULL --> print error and exit
    mov     [CURRENT_FILESTREAM], rax; move file stream ptr into variable

    ; as the filename is not longer of use, free its allocated space
    ; void free(void *_Nullable ptr);
    ;xor     rax, rax                ; clear rax
    mov     rdi, [CURRENT_FILENAME] ; parameter ptr
    call    sys_free                ; free allocated memory

    ; next write the file premable into the file
    ; int fprintf(FILE *restrict stream,
    ;             const char *restrict format, ...);
    xor     rax, rax                ; clear rax
    mov     rdi, [CURRENT_FILESTREAM]; parameter stream
    mov     rsi, FILE_PREMABEL      ; parameter format
    mov     rdx, [FIELD_WIDTH]      ; first format parameter
    mov     rcx, [FIELD_HEIGHT]     ; second format parameter
    call    fprintf                 ; write the formatted premable into the file
    ; starting now, we skip watching for errors concerning file operations

    ; if we came till here, we are ready to write the cells into the file:
    xor     r12, r12        ; now use r12 as the index --> set r12/index to 0
    .for:  ; iterate through all cells and write them to the file
        cmp     r12, [FIELD_AREA]; if we indexed all cells
        jge     .return         ;   then leave the loop and consequently return from the function
        ; else continue writing 

        ; int fputc(int c, FILE *stream);
        xor     rax, rax        ; clear rax
        xor     rdi, rdi        ; clear rdi
        mov     dil, [r13+r12]  ; move current cell into rdi (8 bit dil) --> parameter int c
        cmp     dil, 0x00       ; if there is no cell there, write a '0' to the file --> .dead
        jne     .alive          ; else write a '1' to the file --> .alive
        .dead:
            mov     dil, '0'    ; move the '0' char into dil
            jmp     .write      ; skip the .alive part and write char into file
        .alive:
            mov     dil, '1'    ; move the '1' char into dil
        .write:
        ; write char into file
        mov     rsi, [CURRENT_FILESTREAM]  ; parameter FILE *stream
        call    fputc           ; write cell into file (--> gets buffered most likely by stdout)

        inc     r12             ; r12++ (index++)
        jmp     .for            ; continue the loop

    .failed:  ; print the error text alongside with additional error information and exit the program
        ; void perror(const char *s);
        xor     rax, rax        ; clear rax
        mov     rdi, ERROR_TEXT ; parameter const char *s
        call    perror          ; print error text with additional error information
        mov     rax, -1         ; exit code
        call    _exit           ; exit the program
        hlt                     ; this code should never be reached

    .return: 
        pop     r13         ; restore pushed r13
        pop     r12         ; restore pushed r12
        LEAVE
        ret