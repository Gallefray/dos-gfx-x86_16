%include "gfx.asm"

main:
	push word 655
	push word 10
	push word 0
	push word 0
	push word 0xf
	call renderint
	
	push word 100
	push word 100
	push word 100
	push word 100
	push word 10
	call fillrect
	
	jmp main
	