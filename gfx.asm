%define BLACK 0x0
%define BLUE 0x1
%define GREEN 0x2
%define CYAN 0x3
%define RED 0x4
%define MAGENTA 0x5
%define BROWN 0x6
%define LIGHT_GRAY 0x7
%define DARK_GRAY 0x8
%define LIGHT_BLUE 0x9
%define LIGHT_GREEN 0xa
%define LIGHT_CYAN 0xb
%define LIGHT_RED 0xc
%define LIGHT_MAGENTA 0xd
%define YELLOW 0xe
%define WHITE 0xf

; Blits a texture onto the screen
;
; width  12[bp]
; height 10[bp]
; xoffs   8[bp]
; yoffs   6[bp]
; tex     4[bp]
rendertex:
	push bp
	mov bp, sp
	
	mov ax, 0xa000
	mov es, ax
	
	mov cx, 0 ; cx = y
.jmpY:
	cmp cx, [bp + 10]
	jge .breakY
	
	mov di, 0 ; di = x
.jmpX:
	mov ax, [bp + 12]
	cmp di, ax
	jge .breakX
	
	mul cx
	add ax, di        ; (y * width) + x
	mov bx, ax
	mov si, [bp + 4] 
	mov bl, [si + bx] ; bl = tex[y * width + x]
	
	mov ax, [bp + 6]
	add ax, cx
	mov si, 320
	mul si          ; (yoffs + y) * 320
	add ax, [bp + 8]
	add ax, di      ; + xoffs + x
	mov si, ax
	mov [es:si], bl
	
	inc di
	jmp .jmpX
.breakX:
	inc cx
	jmp .jmpY
.breakY:
	
	pop bp
	retn 10

; Writes an int to the screen
;
; i     12[bp]
; base  10[bp]
; xoffs  8[bp]
; yoffs  6[bp]
; col    4[bp]
;
; Returns number of digits written in ax
renderint:
	push bp
	mov bp, sp
	
	mov cx, 0
	mov ax, [bp + 12]
	test ax, ax
	jnz .calcloop
	
	; i is zero
	push cx
	inc cx
	
.calcloop:
	cmp ax, 0
	je .leave         ; if (!i) break
	
	xor dx,dx
	div word [bp + 10] ; i /= base, dx has remainder
	push dx ; store rem on stack
	inc cx ; inc digit count
	jmp .calcloop
.leave:
	push cx     ;numDigits
	xor ax, ax
	push ax     ;numDigit
.renderloop:
	;render digits in reverse order
	
	pop di ;numDigit
	pop cx ;numDigits
	cmp di, cx
	jge .return
	
	pop bx ;pop the previously pushed remainder (digit) (first arg)
	
	push cx
	push di ;save numDigit, numDigits
	
	push bx ;digit: first arg
	mov ax, 5 
	mul di
	add ax, [bp + 8]
	push ax            ;xoffsnew = xoffs + 5*numDigit
	push word [bp + 6] ;yoffs
	
	push word [bp + 4] ;col
	call renderdigit
	; all regs destroyed
	
	pop bx
	inc bx
	push bx ;++numDigit (numDigit is at top of stack)
	
	jmp .renderloop
	
.return: ;numDigits in cx
	mov ax, cx
	
	pop bp
	retn 10

; Replaces non-zero colours from tex with dl
; note: leaves registers intact
;
; dl contains colour
; si contains tex
replcol:
	push bx
	
	mov bx, -1
.rcolloop:

	inc bx
	cmp bx, 20 ;4*5
	jge .breakcolloop
	cmp [si + bx], byte 0
	je .rcolloop
	mov [si + bx], dl
	jmp .rcolloop	
.breakcolloop:

	pop bx
	retn
	
; Write digit to the screen
;
; digit 10[bp]
; xoffs  8[bp]
; yoffs  6[bp]
; col    4[bp]
renderdigit:
	push bp
	mov bp, sp
	
	mov ax, 2
	mul word [bp + 10]
	mov bx, ax
	mov si, [texnummap + bx]
	
	mov dl, [bp + 4] ; little endian, col byte is the first one
	call replcol     ; replace colours with col
	
	mov ax, 4
	push ax ;w
	mov ax, 5
	push ax ;h
	push word [bp + 8] ;xoffs
	push word [bp + 6] ;yoffs
	
	push word si  ;tex
	call rendertex
	
	pop bp
	retn 8
	
; Fills a rectangle with a colour.
;
; xoffs 12[bp]
; yoffs 10[bp]
; width  8[bp]
; height 6[bp]
; colour 4[bp]
fillrect:
	push bp
	mov bp, sp
	
	mov ax, 0xa000
	mov es, ax
	
	mov cx, 0 ;y
.jmpY1:
	cmp cx, [bp + 6]
	jge .breakY1

	mov bx, 0 ;x
.jmpX1:
	cmp bx, [bp + 8]
	jge .breakX1
	
	mov ax, cx
	add ax, [bp + 10]
	mov di, 320
	mul di
	add ax, [bp + 12]
	add ax, bx
	mov di, ax
	mov al, [bp + 4]
	mov [es:di], al
	
	inc bx
	jmp .jmpX1
.breakX1:
	inc cx
	jmp .jmpY1
.breakY1:
	pop bp
	retn 10

; Render a vertical line.
;
; xoffs 10[bp]
; yoffs  8[bp]
; height 6[bp]
; colour 4[bp]
renderlinev:
	push bp
	mov bp, sp
	
	mov ax, 0xa000
	mov es, ax
	
	mov cx, 0 ;y
.rlvloop:
	cmp cx, [bp + 6]
	jge .rlvbreak
	
	mov ax, 320
	mov dx, [bp + 8]
	add dx, cx        ; yoffs + y
	mul dx           ; ^ * 320
	mov bx, [bp + 10] ; xoffs
	add bx, ax        ; + xoffs
	mov al, [bp + 4]  ; col
	mov [es:bx], al
	
	inc cx
	jmp .rlvloop
.rlvbreak:
	pop bp
	retn 8

; Render a horizontal line.
;
; xoffs 10[bp]
; yoffs  8[bp]
; width  6[bp]
; colour 4[bp]
renderlineh:
	push bp
	mov bp, sp
	
	mov ax, 0xa000
	mov es, ax
	
	mov ax, 320
	mul word [bp + 8]
	
	mov cx, 0 ;x
.loop:
	cmp cx, [bp + 6]
	jge .break
	
	mov bx, ax
	add bx, [bp + 10]
	add bx, cx
	mov dl, [bp + 4]  ; col
	mov [es:bx], dl
	
	inc cx
	jmp .loop
.break:
	pop bp
	retn 8

; Writes a character to the screen
;
; ch    10[bp]
; xoffs  8[bp]
; yoffs  6[bp]
; col    4[bp]
renderchar:
	push bp
	mov bp, sp
	
	mov ax, 2
	mul word [bp + 10]
	mov bx, ax
	mov si, [texasciimap + bx] ;texamap[2*ch]
	
	test si, si
	jz .ret
	
	mov dl, byte [bp + 4] ;little endian
	call replcol
	; registers intact
	
	mov ax, 4
	push ax
	mov ax, 5
	push ax
	push word [bp + 8]
	push word [bp + 6]
	push si
	call rendertex
	
.ret:
	pop bp
	retn 8
	
; Writes a string to the screen
;
; str   12[bp]
; len   10[bp]
; xoffs  8[bp]
; yoffs  6[bp]
; col    4[bp]
renderstring:
	push bp
	mov bp, sp
	
	xor bx, bx ;idx
.loop:
	cmp bx, [bp + 10]
	jge .break
	
	push bx
	
	mov si, word [bp + 12]
	xor ax, ax
	mov al, byte [bx + si]
	push ax ;arg0: char
	mov ax, 5
	mul bx ;5*idx
	add ax, [bp + 8]
	push ax ;arg1: x
	push word [bp + 6] ;arg2: y
	push word [bp + 4] ;arg3: col
	call renderchar
	
	pop bx
	inc bx
	jmp .loop
	
.break:
	pop bp
	retn 10

	tex0 db 0,1,1,0, 1,0,0,1, 1,0,0,1, 1,0,0,1, 0,1,1,0
	tex1 db 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0
	tex2 db 0,1,1,0, 1,0,0,1, 0,0,1,0, 0,1,0,0, 1,1,1,1
	tex3 db 1,1,1,0, 0,0,0,1, 0,1,1,0, 0,0,0,1, 1,1,1,0
	tex4 db 1,0,0,1, 1,0,0,1, 1,1,1,1, 0,0,0,1, 0,0,0,1
	tex5 db 1,1,1,1, 1,0,0,0, 1,1,1,0, 0,0,0,1, 1,1,1,0
	tex6 db 0,1,1,1, 1,0,0,0, 1,1,1,1, 1,0,0,1, 1,1,1,1
	tex7 db 1,1,1,1, 0,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0
	tex8 db 0,1,1,0, 1,0,0,1, 0,1,1,0, 1,0,0,1, 0,1,1,0
	tex9 db 1,1,1,1, 1,0,0,1, 1,1,1,1, 0,0,0,1, 1,1,1,0
	texA db 0,1,1,0, 1,0,0,1, 1,1,1,1, 1,0,0,1, 1,0,0,1
	texB db 1,1,1,0, 1,0,0,1, 1,1,1,1, 1,0,0,1, 1,1,1,1
	texC db 0,1,1,1, 1,0,0,0, 1,0,0,0, 1,0,0,0, 0,1,1,1
	texD db 1,1,1,0, 1,0,0,1, 1,0,0,1, 1,0,0,1, 1,1,1,1
	texE db 1,1,1,1, 1,0,0,0, 1,1,1,0, 1,0,0,0, 1,1,1,1
	texF db 1,1,1,1, 1,0,0,0, 1,1,1,0, 1,0,0,0, 1,0,0,0
	texG db 1,1,1,1, 1,0,0,0, 1,0,0,1, 1,0,0,1, 1,1,1,1
	texH db 1,0,0,1, 1,0,0,1, 1,1,1,1, 1,0,0,1, 1,0,0,1
	texI db 1,1,1,0, 0,1,0,0, 0,1,0,0, 0,1,0,0, 1,1,1,0
	texJ db 1,1,1,0, 0,1,0,0, 0,1,0,0, 0,1,0,0, 1,1,0,0
	texK db 1,0,0,1, 1,0,1,0, 1,1,0,0, 1,0,1,0, 1,0,0,1
	texL db 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,1,1,1
	texM db 1,0,0,1, 1,1,1,1, 1,0,0,1, 1,0,0,1, 1,0,0,1
	texN db 1,1,0,1, 1,0,1,1, 1,0,0,1, 1,0,0,1, 1,0,0,1
	texO db 1,1,1,1, 1,0,0,1, 1,0,0,1, 1,0,0,1, 1,1,1,1
	texP db 1,1,1,0, 1,0,0,1, 1,1,1,0, 1,0,0,0, 1,0,0,0
	texQ db 1,1,1,1, 1,0,0,1, 1,0,0,1, 1,0,1,1, 1,1,1,1
	texR db 1,1,1,0, 1,0,0,1, 1,1,1,0, 1,0,1,0, 1,0,0,1
	texS db 1,1,1,1, 1,0,0,0, 1,1,1,1, 0,0,0,1, 1,1,1,1
	texT db 1,1,1,1, 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0
	texU db 1,0,0,1, 1,0,0,1, 1,0,0,1, 1,0,0,1, 0,1,1,0
	texV db 1,0,0,1, 1,0,0,1, 0,1,0,1, 0,0,1,1, 0,0,0,1
	texW db 1,0,0,1, 1,0,0,1, 1,0,0,1, 1,1,1,1, 1,0,0,1
	texX db 1,0,0,1, 1,0,0,1, 0,1,1,0, 1,0,0,1, 1,0,0,1
	texY db 1,0,0,1, 1,0,0,1, 1,1,1,1, 0,0,1,0, 0,0,1,0
	texZ db 1,1,1,1, 0,0,0,1, 0,0,1,0, 0,1,0,0, 1,1,1,1
	texEM db 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,0,0, 0,0,1,0
	texnummap dw tex0,tex1,tex2,tex3,tex4,tex5,tex6,tex7,tex8,tex9,texA,texB,texC,texD,texE,texF
	texasciimap dw 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, \
	               0,texEM,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, \
	               0,texA,texB,texC,texD,texE,texF,texG,texH,texI,texJ,texK,texL,texM,texN,texO,texP,texQ,texR,texS,texT,texU,texV,texW,texX,texY,texZ,0,0,0,0,0,
	