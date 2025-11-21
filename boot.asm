org 0x7C00
use16
; this comments down here explain the structure, addresses
; 	so you can read this clearer, you can find the structure
;	of the code and the structure of the RAM in C/C++ terms
; structure of this whole project, i just got tired of looking
; for everything, i'll look for notepad++ hyperlinks i guess
;
; code structure
; 	bootloader:
;		logo / background-desktop
;		kernel :3
;		mouse
; 	kernel:
;		mouse
;		keyboard
;		desktop
;		icon
;		text
;		timer
;		kernel
;		textures/bitmaps/data
;
; RAM structure: very necesary bc im forgetting
; 	0x00000600	uint32_t mouse button
;	0x00000604	uint32_t mouse old offset
;	0x00000605	uint32_tmouse offset
;	0x00000700	uint8_t keyboard scancodes
;	0x00000800	uint8_t keyboard ascii
; 	0x00001000 	uint8_t running app
; 	0x00001001 	uint8_t active app
; 	0x00002000 	[uint8_t] array of running apps :3
; 	0x00003000
; 	0x00007C00	kernel and bootloader
;	0x00100000 	[uint16_t] all VRAM addresess << 16 so 0xFD0C is 0xFD0C0000
; 	0x00200000 	void* all loop programs up to 0x10000, so app 1 goes from
;          		0x200000 to 0x210000
;	0x00600000	[uint16_t] address of where EIP ended at
; 	0x01000000 	[...] RAM of programs so prog 1 has 0x1000000 to
;           	0x4000000
; 	0xFD000000 	[int[0xC0000]] VRAM up to 0xFFFF0000, where
;            	0xFFFF0000 was used instead of now's 0x2000
;
; interrupt table commands:
;	modules:
;		0:
;	get VRAM address : 0x00
;	get RAM address	: 0x01
;	end process	: 0x02
;	update screen : 0x10
;	print text : 0x11
;	print char : 0x12
;	print half a char : 0x13
;	print in-built icon : 0x14
;	print .img file : 0x15
;	get key : 0x20
;	wait X milliseconds : 0x21
;	get time in cl:bh:bl : 0x22
; 	get date in cl/bh/bl: 0x23
; you're welcome, future me and whoever will read this
kernel.bootloader:
	mov ax, kernel.osend - 0x7C00
	shr ax, 9
	inc al
	mov ah, 0x02
	mov cx, 1
	mov dl, 0x80
	; this 0x80 means the disk 1, a.k.a. A:/
	; it's now 0 bc a hdd controller is harder than the fdd
	mov bx, 0x7C00
	int 0x13
	; todo: take desktop out of the HDD/floppy
	; also here i switch to graphics mode
	mov ax, 0x4F02
	mov bx, 0x4105
	int 0x10
	cli
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7C00
	lgdt [kernel.desc]
	mov eax, cr0
	or eax, 1
	mov cr0, eax
	jmp 08h:kernel.main
use32
kernel.main:
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov esp, 0x9FC00
	lidt [exception.desc]
	; debug code: prints to shell
	call kernel.message
	; here begginning code begins :)
	mov ecx, 0xC0000
	mov edi, 0xFD180000
	mov al, 0x03
	rep stosb
	call desktop
	; todo read desktop
	; now mousecursor
	call kernel.drivers
	mov esi, shell
	call kernel.load
kernel.loop:
	sti
	call kernel.run
	jmp kernel.loop
kernel.run: ; schedulers
	mov esi, 0x2000
kernel.run.loop:
	lodsb
	mov byte[0x1000], al
	cmp al, 0
	je kernel.run.end
	push esi
	push eax
	shl al, 1
	movzx eax, al
	mov esi, 0x600000
	add esi, eax
	shl eax, 23
	mov ebx, 0x1000000
	add ebx, eax
	add ebx, 32
	xor eax, eax
	lodsw
	pop edx
	pop esi
	movzx edx, dl
	shl edx, 16
	add eax, edx
	add eax, 0x200000
	pushad
	mov dword[0x900], esp
	mov esp, ebx
	mov dword[0x904], eax
	popad
	call dword[0x904] ; where eax is last address
	; if it comes here, program ends
	call kernel.unload ; i gotta close it...
kernel.run.return:
	mov esp, dword[0x900]
	popa
	call kernel.yield
	jmp kernel.run.loop
kernel.run.end:
	ret
kernel.load: ; a way to start an app
	; esi is RAM address, somehow
	lodsb
	and al, 3
	cmp al, 0
	je kernel.load.byte
	cmp al, 1
	je kernel.load.word
	; unavailable app idk
	ret
kernel.load.skip:
	mov ecx, eax
kernel.load.loop:
	lodsb
	cmp al, 0
	jne kernel.load.loop
	push esi
	mov esi, 0x2000
kernel.load.reg:
	lodsb
	cmp al, 0
	jne kernel.load.reg
	dec esi
	lodsb
	dec esi
	inc al
	cmp al, 62
	jae kernel.load.end
	mov edi, esi
	stosb
	pop esi
	; al is task #
	mov edi, 0x200000
	movzx eax, al
	shl eax, 16
	add edi, eax
	rep movsb
	ret
kernel.load.end:
	pop esi
	ret
kernel.load.byte:
	xor eax, eax
	lodsb
	jmp kernel.load.skip
kernel.load.word:
	xor eax, eax
	lodsw
	jmp kernel.load.skip
kernel.unload:
	; close app means:
	; erase VRAM
	; deregister from task manager
	xor eax, eax
	mov al, byte[0x1000]
	push eax
	mov ebx, 0xC
	mul ebx
	add eax, 0xFD24
	mov ebx, eax
	mov esi, 0x100000
kernel.unload.search:
	lodsw
	cmp ax, 0
	je kernel.unload.endsrch
	cmp ax, bx
	jne kernel.unload.search
	mov edi, esi
	sub edi, 2
kernel.unload.swap:
	lodsw
	stosw
	cmp ax, 0
	jne kernel.unload.swap
kernel.unload.endsrch:
	pop eax
	push eax
	mov bl, al
	mov esi, 0x2000
kernel.unload.task:
	lodsb
	cmp al, 0
	je kernel.unload.finish
	cmp al, bl
	jne kernel.unload.task
	mov edi, esi
	dec edi
kernel.unload.switch:
	lodsb
	stosb
	cmp al, 0
	jne kernel.unload.switch
	pop eax
	mov edi, 0x200000
	shl eax, 16
	add edi, eax
	mov ecx, 0x4000
	xor eax, eax
	rep stosd
	ret
kernel.unload.finish:
	pop eax
	ret
	; idt table and gdt table
kernel:
	dq 0x0000000000000000
	dq 0x00CF9A000000FFFF
	dq 0x00CF92000000FFFF
kernel.desc:
	dw kernel.end - kernel - 1
	dd kernel
kernel.end:
	; idt
; hehehe
; now an application, that does nothing... yet
	; time to uhm idk , "I'll make the desktop"
	; why not tho lol
	; this is me 5 days later, I regret it
	; the mouse worked, i didnt back up and it doesnt work anymlre
	; the mouse had scroll lock... yea, scroll lock I didn't know that existed
	; it has been one month, i unregret it i might have finished now only one thing left
	; the floppy disk controller, which is what i hate, has vanished
	; it has been 2 months and i still haven't made a disk controller
	; altough i could bc i finished multitasking
times 510 - ($ - $$) db 0
dw 0xAA55
exception.desc:
	dw exception.desc - exception - 1
	dd exception
exception:
	dw exception.divby0, 0x08 ; some guy divided by 0
	db 0, 0x8E
	dw exception.divby0/0x10000
	dw exception.unused, 0x08
	db 0, 0x8E
	dw exception.unused/0x10000
	dw exception.panic, 0x08 ; memory, CPU, motherboard is damaged
	db 0, 0x8E
	dw exception.panic/0x10000
	dw exception.debug, 0x08
	db 0, 0x8E
	dw exception.debug/0x10000
	dw exception.debug2, 0x08
	db 0, 0x8E
	dw exception.debug2/0x10000
	dw exception.unused, 0x08 ; unused (BOUND)
	db 0, 0x8E
	dw exception.unused/0x10000
	dw exception.invalidopc, 0x08 ; invalid opcode
	db 0, 0x8E
	dw exception.invalidopc/0x10000
	dw exception.nofloat, 0x08 ; lazy FPU/no FPU
	db 0, 0x8E
	dw exception.nofloat/0x10000
	dw exception.dfault, 0x08 ; double fault
	db 0, 0x8E
	dw exception.dfault/0x10000
	dw exception.nofloat, 0x08 ; legacy FPU
	db 0, 0x8E
	dw exception.nofloat/0x10000
	dw exception.invalidtask, 0x08 ; invalid task (TSS task selector)
	db 0, 0x8E
	dw exception.invalidtask/0x10000
	dw exception.invalidtask, 0x08 ; non-present-segment
	db 0, 0x8E
	dw exception.invalidtask/0x10000
	dw exception.memoryleak, 0x08
	db 0, 0x8E
	dw exception.memoryleak/0x10000
	dw exception.memoryleak, 0x08; protection violation
	db 0, 0x8E
	dw exception.memoryleak/0x10000
	dw exception.memoryleak, 0x08 ; invalid memory access
	db 0, 0x8E
	dw exception.memoryleak/0x10000
	times 8 db 0 ; reserved
	dw exception.nofloat, 0x08 ; FPU error
	db 0, 0x8E
	dw exception.nofloat/0x10000
	dw exception.memoryleak, 0x08 ; unaligned mem access
	db 0, 0x8E
	dw exception.memoryleak/0x10000
	dw exception.panic, 0x08
	db 0, 0x8E
	dw exception.panic/0x10000
	dw exception.nofloat, 0x08
	db 0, 0x8E
	dw exception.nofloat/0x10000
	times 8*12 db 0
	; IRQ0 0x20
	dw time, 0x08
	db 0, 0x8E
	dw time/0x10000
	dw keyboard, 0x08
	db 0, 0x8E
	dw keyboard/0x10000
	times 8*10 db 0
	dw mouse, 0x08
	db 0, 0x8E ; int 44 / 0x2C?
	dw mouse/0x10000
	times 8*3 db 0
	dw kernel.system, 0x08 ; system call, a.k.a int 0x30 :3 (i think lol)
	db 0, 0x8E
	dw kernel.system/0x10000
; syscalls :3 (data section i could say)
; todo: fix this to add exceptions plz i dont wanna have eip at indonesia
; GDT org: limit low - limit high - base low - base high - base middle -  access -
; flags+limit high(4bits) - base high
exception.unused:
	iret
exception.divby0:
	mov eax, 0
	mov edx, 0
	iret
exception.panic:
	cli
	mov edi, 0xFD000000
	mov al, 0x07
	rep stosb
	mov esi, exception.panic.message
	mov edi, 0xFD010000
	mov bl, 0x1E
	call text
	hlt
	iret
exception.panic.message: db "FATAL ERROR: Your computer is broken", 0
exception.invalidopc:
	call kernel.unload
	iret ; todo message
exception.nofloat:
	iret ;  i don't think ill use floats but maybe idk whats an FPU
exception.dfault:
	cli
	mov edi, 0xFD000000
	mov ecx, 0xC0000
	mov al, 0x07
	rep stosb
	mov esi, exception.dfault.message
	mov edi, 0xFD010000
	mov bl, 0x1E
	call text
	hlt
	iret
exception.dfault.message: db "FATAL ERROR: An error has ocurred, reset your computer", 0
exception.invalidtask:
	; todo: using paging, jump to task 0 or open shell
	iret
exception.memoryleak:
	; show memory leak error
	call kernel.unload
	iret
exception.debug:
	mov dx, 0x3F8
	mov al, '#'
	out dx, al
	iret
exception.debug2:
	mov dx, 0x3F8
	mov al, '$'
	out dx, al
	iret
shell:
; app.asm
; file headers
db 00101000b
db shell.end - shell.init
db "shell", 0
shell.init: ; my first app
	ret
shell.end:
mouse:
	cli
	int3
	pushad
	in al, 0x60
	mov byte[0x600], al ; buttons at 0x600
	mov eax, dword[0x601]
	mov esi, 0xFD0C0000
	mov edi, 0xFD000000 
	add esi, eax
	add edi, eax
	mov cl, 0x11
mouse.replace:
	push ecx ; save ecx, it will get poped after loop
	mov cl, 0x0C
mouse.replace.loop:
	cmp edi, 0xFD0C0000
	jnb mouse.replace.skip
	movsb
mouse.replace.skip:
	loop mouse.replace.loop
	add edi, 0x3F4
	add esi, 0x3F4
	pop ecx
	loop mouse.replace
	in al, 0x60
	mov cl, al
	in al, 0x60
	mov dl, al
	mov ebx, dword[0x601]
	mov eax, ebx
	movsx ecx, cl ; cl is x delta
	movsx edx, dl ; dl is -y delta
	shl edx, 10 ; edx *= 1024(2^10)
	neg edx ; edx = -edx
	add eax, ecx ; pos = pos+x+y*1024
	add eax, edx
	call mouse.clamp
	mov dword[0x601], eax ; calculated result
	call mouse.print
mouse.jump:
	mov al, 0x20
	out 0xA0, al
	out 0x20, al
	popad
	sti
	iret
	; here went mouse position
	; goes*, went*, goes*, went*, goes*, went*
	; i decided to put it on stack, copying windows
	; i regret that decision
	; plz dont sue me
mouse.print:
	mov edx, eax ; eax is mouse position (which will then be pushed back in)
	mov ecx, mouse.end - mouse.init ; ecx = 1
	mov esi, mouse.init ; esi = ???
	shr ecx, 1
mouse.print.loop:
	mov eax, edx ; sets back the backup
	mov edi, 0xFD000000 ; edi = 0xFD000000 / vram but temporary
	add edi, eax ; edi = 0xFD0C0802
	lodsw ; mov ax, word [ds:esi] / load mouse texture
	mov ebx, eax ; ebx = 0x9000
	and eax, 0x7FFF ; eax = 0x1000
	call mouse.print.check
	add edi, eax ; edi = 0xFD0C1802
	and ebx, 0x8000
	shr ebx, 15
	add ebx, 0x0F
	mov al, bl
	cmp edi, 0xFD0C0000
	jns mouse.print.skip
	stosb ; mov byte [es:edi], al
mouse.print.skip:
	loop mouse.print.loop
	ret
mouse.clamp:
	; ebx is old
	; ecx is X
	add ebx, 0x400
	mov edx, ebx
	add edx, ecx
	shr ebx, 10
	shr edx, 10
	cmp ebx, edx ; is old.Y > new.Y?	
	ja mouse.left
	cmp ebx, edx
	jb mouse.right
mouse.vertical:
	cmp eax, 0xC0400
	jb mouse.skip
	cmp eax, 0x180400
	jb mouse.down
mouse.up:
	add eax, 0x400
	cmp eax, 0xC0400
	jb mouse.skip
	jmp mouse.up
mouse.down:
	sub eax, 0x400
	cmp eax, 0xC0400
	jb mouse.skip
	jmp mouse.down
mouse.skip:
    sub ebx, 0x400
	ret
mouse.left:
	shl ebx, 10
	mov eax, ebx
	jmp mouse.vertical
mouse.right:
	shl ebx, 10
	add ebx, 0x3FF
	mov eax, ebx
	jmp mouse.vertical
mouse.print.check:
	push edx
	push edi
	push eax
	mov edx, edi
	and eax, 0x03FF
	add edi, eax
	shr edx, 10
	shr edi, 10
	cmp edx, edi
	js mouse.print.bounds
	pop eax
	pop edi
	pop edx
	ret
mouse.print.bounds:
	pop eax
	pop edi
	pop edx
	mov edi, 0xFD0C0000
	ret
keyboard:
	cli
	pushad
	in al, 0x64
	test al, 0x20
	jnz keyboard.end
	mov al, byte[0x700]
	cmp al, ':'
	je keyboard.special
	in al, 0x60
	mov byte[0x700], al
keyboard.return:
	mov esi, keyboard.ascii
	movzx eax, al
	add esi, eax
	cmp al, 0x48
	ja keyboard.end
	lodsb
	mov byte[0x800], al
keyboard.end:
	mov al, 0x20
	out 0x20, al
	popad
	sti
	iret
keyboard.special:
	in al, 0x60
	mov byte[0x701], al
	cmp al, 0xBA
	je keyboard.capslock
	jmp keyboard.return
keyboard.capslock:
	mov al, 0x04
	out 0x60, al
	jmp keyboard.return
keyboard.ascii:
	db 0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0
	db ' ', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']'
	db ' ', 0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", 0
	db 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/'
	db 0, 0, 0, ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '7', '8', '9'
	db '-', '4', '5', '6', '+', '1', '2', '3', '0', '.', 0, 0, '/', 0, 0
time:
	cli
	push eax
	push edx
	mov al, byte[0x1000]
	cmp al, 0
	je time.end
	shl al, 1
	movzx eax, al
	mov edi, 0x600000
	add edi, eax
	shl eax, 23
	mov ebx, 0x1000000
	add ebx, eax
	mov eax, dword[esp+8]
	stosw
	pop edi
	pop eax
	mov esp, ebx
	mov ebx, dword[0x904]
	pushad
	mov al, 0x20
	out 0x20, al
	sti
	mov esp, dword[0x900]
	popad
	jmp kernel.run.loop
time.end:
	pop eax
	pop edi
	mov al, 0x20
	out 0x20, al
	sti
	iret
desktop:
	mov esi, desktop.files
	mov edi, 0xFD18080A
	call desktop.proc
	mov word[0x100000], 0xFD18
	call desktop.update
	ret
desktop.proc:
	; esi is the address of the file
	; edi is the address destination
	lodsb
	test al, 0x80
	jnz desktop.proc.skip
	mov bl, al
	and bl, 3
	inc bl
	movzx ebx, bl
	add esi, ebx
	mov ah, al
	and al, 0x78
	shr al, 3
	push edi
	push esi
	call icon
	pop esi
	pop edi
	add edi, 0x67FB
	mov bl, 0x0F
	call text
	call text
desktop.proc.skip:
	ret
desktop.update:
	mov esi, 0x100000
desktop.update.loop:
	xor eax, eax
	lodsw ; read 0xFD18 into ax
	push esi
	cmp ax, 0xFD00 ; yeah whatever
	jb desktop.update.end ; ends updates
	mov edi, 0xFD0C0000
	shl eax, 16
	mov esi, eax
	mov ecx, 0xC0000
desktop.update.repetition:
	lodsb ; from esi to al
	cmp al, 0
	je desktop.update.space
	stosb
desktop.update.skip:
	loop desktop.update.repetition
	pop esi
	jmp desktop.update.loop
desktop.update.end:
	pop esi
	mov edi, 0xFD000000
	mov esi, 0xFD0C0000
	mov ecx, 0xC0000
	rep movsb
	ret
desktop.update.space:
	inc edi
	jmp desktop.update.skip
desktop.files: 
	db 00111000b, 0x00, "f.lm", 0 ; a file!, such surprise
icon:
	cmp al, 0
	je icon.print.raw
	cmp al, 1
	je icon.print.folder
	cmp al, 2
	je icon.print.folder
	cmp al, 3
	je icon.print.html
	cmp al, 4
	je icon.print.sys
	cmp al, 5
	je icon.print.exe
	cmp al, 7
	je icon.print.bin
	cmp al, 8
	je icon.print.cfea
	cmp al, 11
	je icon.print.img
	ret
icon.print:
	shr ecx, 1
	mov edx, edi
icon.print.loop:
	mov edi, edx
	lodsw ; mov ax, word [ds:esi]
	mov ebx, eax
	and ebx, 0x7FFF
	add edi, ebx
   	and eax, 0x8000
   	shr eax, 15
   	add eax, 0x0F
	stosb ; mov word [es:edi], ax
	loop icon.print.loop
	ret
icon.bitmap:
    mov ecx, 24
icon.bitmap.row:
    xor eax, eax
    lodsd
    mov edx, 0x800000
    push ecx
    mov ecx, 24
icon.bitmap.loop:
    mov ebx, eax
    and ebx, edx
    shr edx, 1
    dec cl
    shr ebx, cl
    inc cl
    add ebx, 0x0F
    push eax
    mov al, bl
    stosb
    pop eax
    loop icon.bitmap.loop
    ; go down a row
    pop ecx
    add edi, 0x3E8
    loop icon.bitmap.row
    ret
icon.print.raw:
	mov esi, icon.raw.init
	mov ecx, icon.raw.end - icon.raw.init
	jmp icon.print
icon.print.folder:
	mov esi, icon.folder.init
	mov ecx, icon.folder.end - icon.folder.init
	jmp icon.print
icon.print.html:
	mov esi, icon.html.init
	jmp icon.bitmap
icon.print.sys:
	mov esi, icon.sys.init
	jmp icon.bitmap
icon.print.exe:
	mov esi, icon.exe.init
	jmp icon.bitmap
icon.print.bin:
    mov esi, icon.bin.init
    jmp icon.bitmap
icon.print.cfea:
	mov esi, icon.cfea.init
	jmp icon.bitmap
icon.print.img:
    mov esi, icon.img.init
    jmp icon.bitmap
text:
	lodsb
	push eax
	push esi
	call text.char
	pop esi
	pop eax
	cmp al, 0
	jne text
	ret
text.char:
	push edi
	push eax
	mov cl, 0
	call text.nibble
	pop eax
	mov cl, 1
	call text.nibble
	pop edi
	add edi, 6
	ret
text.nibble: ; its not printing fully, just half
	; edi is offset ; 0xFD0C0000
	; dl is color ; 0x0F
	; al is char = 0 a.k.a null just for debugging
	; cl is nibble (least significant bit / 1)
	; btw this is a copy from another OS i made (altough its real-mode, so i couldn't copy paste)
	; I wanted to copy and paste my own code, but they were made for different devices
	and cl, 1
	shl cl, 2 ; multiply by 4 bytes and add
	movzx ecx, cl
	mov esi, text.database
	and al, 0x7F ; filter out non-ascii characters
	cmp al, 0x20
	jbe text.nibble.skipadd
	sub al, 0x20
	movzx eax, al
	shl eax, 3
	add esi, eax
	add esi, ecx
	lodsd
	mov ecx, 0x20000000
text.nibble.row:
	mov edx, eax
	and edx, ecx
	shr ecx, 1
	cmp edx, 0
	je text.nibble.skipadd
	push eax
	mov al, bl
	stosb
	pop eax
text.nibble.skip:
	cmp ecx, 0x20000000 ;  it crashed at 0x4000000
	; just so ya know for debugging I crashed the vm lol
	je text.nibble.godown
	cmp ecx, 0x1000000
	je text.nibble.godown
	cmp ecx, 0x80000
	je text.nibble.godown
	cmp ecx, 0x4000
	je text.nibble.godown
	cmp ecx, 0x200
	je text.nibble.godown
	cmp ecx, 0x10
	je text.nibble.godown
	; six compares for six rows
	cmp ecx, 0
	jne text.nibble.row
	add edi, 0x3FB
	ret
text.nibble.godown:
	add edi, 0x3FB ; go down a row
	jmp text.nibble.row
text.nibble.skipadd:
	inc edi
	jmp text.nibble.skip
text.int:
	; eax
	push edx
	mov ebx, eax
	mov ecx, 28
text.int.loop:
	mov edx, 0x0000000F
	shl edx, cl
	mov eax, ebx
	and eax, edx
	push ecx
	neg cl
	add cl, 29
	shr eax, cl
	pop ecx
	add al, 48
	cmp al, 57
	ja text.int.hex
text.int.return:
	sub cl, 3
	pop edx
	push edx
	call text.char
	loop text.int.loop
	pop edx
	ret
text.int.hex:
	add al, 7
	jmp text.int.return
; mostly kernel stuff
kernel.yield:
	cli
	push eax
	push edi
	mov dword[0x904], ebx
	mov al, byte[0x1000]
	cmp al, 0
	je kernel.yield.end
	shl al, 1
	movzx eax, al
	mov edi, 0x600000
	add edi, eax
	shl eax, 23
	mov ebx, 0x1000000
	add ebx, eax
	mov eax, dword[esp+12]
	stosw
	pop edi
	pop eax
	mov esp, ebx
	mov ebx, dword[0x904]
	pushad
	mov esp, dword[0x900]
	popad
	jmp kernel.run.loop
kernel.yield.end:
	pop eax
	pop edi
	iret
kernel.drivers:
	cli
	mov al, 0x11
	out 0x20, al
	out 0xA0, al
	mov al, 0x20
	out 0x21, al
	mov al, 0x28
	out 0xA1, al
	mov al, 0x04
	out 0x21, al
	mov al, 0x02
	out 0xA1, al
	mov al, 0x01
	out 0x21, al
	out 0xA1, al
	; timer IRQ0 - int 0x20
	mov al, 0x34
	out 0x43, al
	mov ax, 1193
	out 0x40, al
	mov al, ah
	out 0x40, al
	; keyboard IRQ1 - int 0x21
kernel.drivers.keyboard:
	in al, 0x64
	test al, 2
	jnz kernel.drivers.keyboard
	mov al, 0xF4
	out 0x60, al
	; mouse IRQ12 - int 0x2C
kernel.drivers.mouse:
	call kernel.drivers.clear
	mov al, 0xA7
	out 0x64, al
	call kernel.drivers.clear
	mov al, 0xA8
	out 0x64, al
	call kernel.drivers.clear
	mov al, 0x20
	out 0x64, al
	call kernel.drivers.wait
	in al, 0x60
	test al, 0x20
	jnz kernel.drivers.mouse
	and al, 0xDF
	or al, 0x02
	push eax
	call kernel.drivers.clear
	mov al, 0x60
	out 0x64, al
	call kernel.drivers.clear
	pop eax
	out 0x60, al
kernel.drivers.send:
	call kernel.drivers.clear
	mov al, 0xD4
	out 0x64, al
	call kernel.drivers.clear
	mov al, 0xFF
	out 0x60, al
	call kernel.drivers.wait
	in al, 0x60
	mov bh, al
	call kernel.drivers.wait
	in al, 0x60
	mov bl, al
	call kernel.drivers.wait
	in al, 0x60
	mov cl, al
	call kernel.drivers.clear
	mov al, 0xD4
	out 0x64, al
	call kernel.drivers.clear
	mov al, 0xF4
	out 0x60, al
	call kernel.drivers.wait
	in al, 0x60
	cmp al, 0xFE
	je kernel.drivers.send
	; unmask
	in al, 0x21
	and al, 11111000b
	out 0x21, al
	in al, 0xA1
	and al, 11101111b
	out 0xA1, al
	mov dword[0x601], 0x60200
	sti
	ret
kernel.drivers.clear:
	in al, 0x64
	test al, 2
	jnz kernel.drivers.clear
	ret
kernel.drivers.wait:
	in al, 0x64
	test al, 1
	jz kernel.drivers.wait
	ret
kernel.system:
	cli
	pusha
	cmp cl, 0x00
	je kernel.system.kernel0
	cmp cl, 0x01
	je kernel.system.kernel1
	cmp cl, 0x02
	je kernel.system.kernel2
	cmp cl, 0x10
	je kernel.system.display0
	cmp cl, 0x11
	je kernel.system.display1
	cmp cl, 0x12
	je kernel.system.display2
	cmp cl, 0x13
	je kernel.system.display3
	cmp cl, 0x14
	je kernel.system.display4
	cmp cl, 0x15
	je kernel.system.display5
kernel.system.return:
	popa
	sti
	jmp kernel.yield
kernel.system.kernel0:
	popa
	call kernel.spawn
	sti
	jmp kernel.yield
kernel.system.kernel1:
	popa
	call kernel.memory
	sti
	jmp kernel.yield
kernel.system.kernel2:
	call kernel.unload
	jmp kernel.system.return
kernel.system.display0:
	call desktop.update
	jmp kernel.system.return
kernel.system.display1:
	call text
	jmp kernel.system.return
kernel.system.display2:
	call text.char
	jmp kernel.system.return
kernel.system.display3:
	call text.nibble
	jmp kernel.system.return
kernel.system.display4:
	call icon
	jmp kernel.system.return
kernel.system.display5:
	call icon.print
	jmp kernel.system.return
; task management - preemptive
; i had to do this twice :(
kernel.spawn:
	xor ebx, ebx
	mov bl, byte[0x1000]
	dec bl
kernel.spawn.return:
	mov esi, 0x100000
	mov eax, 0xC ; 0 :)
	mul ebx ; 0x0 = 0
	add eax, 0xFD24 ; jk 0xFD28
	mov bx, ax ; bx = 0xFD28
kernel.spawn.find:
	lodsw ; to ax
	cmp ax, bx ; is ax bx?
	je kernel.spawn.end ; yayy
	cmp ax, 0 ; noooo
	jne kernel.spawn.find
	mov edi, esi
	sub edi, 2
	mov ax, bx
	stosw
	shl eax, 16
	mov edi, eax
	ret
kernel.spawn.end:
	mov ax, bx
	shl eax, 16
	mov edi, eax
	ret
kernel.memory:
	xor eax, eax
	mov al, byte[0x1000]
	mov esi, eax
	shl esi, 26
	add esi, 1
	ret
kernel.message:
	mov esi, kernel.string
	mov edi, 0xFD0601BD
	mov bl, 0x1E
	mov cl, 0x11
	int 0x30
	ret
kernel.string: db "Booting Kasmon OS a0.1", 0 ; boot message
; this code down to the textures is uhh idk it was on the bottom
; every line makes this whole thing and is probably my only source
; of motivation, right now it has 1500 lines, exactly which makes me happy
	
; here's finally where the files are :)
; Hard-coded folder's I've made:
; file system:
	; exe T bit if 0 = no loop
	; b1:bitflag Hidden?/4-bit protocol #/Tbit/2bit length size in bytes
	; b2:size (accordingly)
	; bN: name
	; bM: 0x00
; this comment below chose the structure of this whole proyect
; from here until whenever i want, textures
logo.init: ; 1-color version of an .img
	dw 0x0006, 0x0007, 0x0008, 0x0009
	dw 0x000A, 0x000B
	dw 0x0403, 0x0404, 0x0405, 0x040C
	dw 0x040D, 0x040E
	dw 0x0801, 0x0802, 0x080F, 0x0810
	dw 0x0C00, 0x0C11
	dw 0x1000, 0x1011
	dw 0x1400, 0x1401, 0x1402, 0x140F
	dw 0x1410, 0x1411
	dw 0x1800, 0x1803, 0x1804, 0x1805
	dw 0x180C, 0x180D, 0x180E, 0x1811
	dw 0x1C00, 0x1C06, 0x1C07, 0x1C08
	dw 0x1C09, 0x1C0A, 0x1C0B, 0x1C0C
	dw 0x1C11, 0x1C12, 0x1C13, 0x1C14
	dw 0x2000, 0x200C, 0x2011, 0x2015
	dw 0x2400, 0x240C, 0x2411, 0x2416
	dw 0x2800, 0x280C, 0x2811, 0x2812
	dw 0x2813, 0x2817
	dw 0x2C00, 0x2C0C, 0x2C11, 0x2C14
	dw 0x2C17
	dw 0x3000, 0x300C, 0x3011, 0x3014
	dw 0x3017
	dw 0x3400, 0x340C, 0x3411, 0x3414
	dw 0x3417
	dw 0x3800, 0x380A, 0x380B, 0x380C
	dw 0x380D, 0x380E, 0x3811, 0x3817
	dw 0x3C00, 0x3C0A, 0x3C0E, 0x3C11
	dw 0x3C12, 0x3C13, 0x3C17
	dw 0x4000, 0x400A, 0x400E, 0x4011
	dw 0x4016
	dw 0x4400, 0x440B, 0x440E, 0x4411
	dw 0x4415
	dw 0x4800, 0x480B, 0x480E, 0x4811
	dw 0x4812, 0x4813, 0x4814
	dw 0x4C00, 0x4C0B, 0x4C0C, 0x4C0D
	dw 0x4C0E, 0x4C11
	dw 0x5000, 0x5011
	dw 0x5401, 0x5402, 0x540F, 0x5410
	dw 0x5803, 0x5804, 0x5805, 0x580C
	dw 0x580D, 0x580E
	dw 0x5C06, 0x5C07, 0x5C08, 0x5C09
	dw 0x5C0A, 0x5C0B
logo.end:
mouse.init:
; smaller version of a .img file with 2 colors
; brief explanation: edi+this but end-init times
; so at 0, 0(0) + 0x8000 would print it uhm in the same spot
; because color is the most significant bit, 1 is black and 0 is white
; pretty much moddable idrk how to add more colors, thats why
; all the icons are monotone
	dw 0x8000, 0x8001
	dw 0x8400, 0x0401, 0x8402
	dw 0x8800, 0x0801, 0x0802, 0x8803
	dw 0x8C00, 0x0C01, 0x0C02, 0x0C03
	dw 0x8C04
	dw 0x9000, 0x1001, 0x1002, 0x1003
	dw 0x1004, 0x9005
	dw 0x9400, 0x1401, 0x1402, 0x1403
	dw 0x1404, 0x1405, 0x9406
	dw 0x9800, 0x1801, 0x1802, 0x1803
	dw 0x1804, 0x1805, 0x1806, 0x9807
	dw 0x9C00, 0x1C01, 0x1C02, 0x1C03
	dw 0x1C04, 0x1C05, 0x1C06, 0x1C07
	dw 0x9C08
	dw 0xA000, 0x2001, 0x2002, 0x2003
	dw 0x2004, 0x2005, 0x2006, 0x2007
	dw 0x2008, 0xA009
	dw 0xA400, 0x2401, 0x2402, 0x2403
	dw 0x2404, 0x2405, 0x2406, 0x2407
	dw 0x2408, 0x2409, 0xA40A
	dw 0xA800, 0x2801, 0x2802, 0x2803
	dw 0x2804, 0x2805, 0x2806, 0x2807
	dw 0x2808, 0x2809, 0x280A, 0xA80B
	dw 0xAC00, 0x2C01, 0x2C02, 0x2C03
	dw 0x2C04, 0x2C05, 0x2C06, 0x2C07
	dw 0xAC08, 0xAC09, 0xAC0A, 0xAC0B
	dw 0xB000, 0x3001, 0x3002, 0xB003
	dw 0xB004, 0x3005, 0x3006, 0xB007
	dw 0xB400, 0x3401, 0xB402, 0xB404
	dw 0x3405, 0x3406, 0xB407
	dw 0xB800, 0xB801, 0xB805, 0x3806
	dw 0x3807, 0xB808
	dw 0xBC05, 0x3C06, 0x3C07, 0x3C08
	dw 0xC005, 0xC006, 0xC007, 0xC008
mouse.end:
icon.raw.init:
	dw 0x8004, 0x8005, 0x8006, 0x8707
	dw 0x8008, 0x8009, 0x800A, 0x800B
	dw 0x800C, 0x800D, 0x800E, 0x800F
	dw 0x8010, 0x8011, 0x8012, 0x8013
	dw 0x8014, 0x8015, 0x8016, 0x8017
	dw 0x8018
	dw 0x8403, 0x0404, 0x8405, 0x0406
	dw 0x0407, 0x0408, 0x0409, 0x040A
	dw 0x040B, 0x040C, 0x040D, 0x040E
	dw 0x040F, 0x0410, 0x0411, 0x0412
	dw 0x0413, 0x0414, 0x0415, 0x0416
	dw 0x0417, 0x8418
	dw 0x8802, 0x0803, 0x0804, 0x8805
	dw 0x0806, 0x0807, 0x0808, 0x0809
	dw 0x080A, 0x080B, 0x080C, 0x080D
	dw 0x080E, 0x080F, 0x0810, 0x0811
	dw 0x0812, 0x0813, 0x0814, 0x0815
	dw 0x0816, 0x0817, 0x8818
	dw 0x8C01, 0x0C02, 0x0C03, 0x0C04
	dw 0x8C05, 0x0C06, 0x0C07, 0x0C08
	dw 0x0C09, 0x0C0A, 0x0C0B, 0x0C0C
	dw 0x0C0D, 0x0C0E, 0x0C0F, 0x0C10
	dw 0x0C11, 0x0C12, 0x0C13, 0x0C14
	dw 0x0C15, 0x0C16, 0x0C17, 0x8C18
	dw 0x9000, 0x9001, 0x1002, 0x1003
	dw 0x1004, 0x9005, 0x1006, 0x1007
	dw 0x1008, 0x1009, 0x100A, 0x100B
	dw 0x100C, 0x100D, 0x100E, 0x100F
	dw 0x1010, 0x1011, 0x1012, 0x1013
	dw 0x1014, 0x1015, 0x1016, 0x1017
	dw 0x9018
	dw 0x9400, 0x9401, 0x9402, 0x9403
	dw 0x9404, 0x9405, 0x1406, 0x1407
	dw 0x1408, 0x1409, 0x140A, 0x940B
	dw 0x940C, 0x140D, 0x140E, 0x140F
	dw 0x1410, 0x1411, 0x1412, 0x1413
	dw 0x1414, 0x1415, 0x1416, 0x1417
	dw 0x9418
	dw 0x9800, 0x1801, 0x1802, 0x1803
	dw 0x1804, 0x1805, 0x1806, 0x9807
	dw 0x9808, 0x9809, 0x980A, 0x980B
	dw 0x980C, 0x980D, 0x980E, 0x980F
	dw 0x9810, 0x1811, 0x1812, 0x1813
	dw 0x1814, 0x1815, 0x1816, 0x1817
	dw 0x9818
	dw 0x9C00, 0x1C01, 0x1C02, 0x1C03
	dw 0x1C04, 0x9C05, 0x9C06, 0x9C07
	dw 0x9C08, 0x9C09, 0x9C0A, 0x9C0B
	dw 0x9C0C, 0x9C0D, 0x9C0E, 0x9C0F
	dw 0x9C10, 0x9C11, 0x9C12, 0x1C13
	dw 0x1C14, 0x1C15, 0x1C16, 0x1C17
	dw 0x9C18
	dw 0xA000, 0x2001, 0x2002, 0x2003
	dw 0x2004, 0xA005, 0xA006, 0x2007
	dw 0x2008, 0x2009, 0x200A, 0x200B
	dw 0x200C, 0x200D, 0x200E, 0x200F
	dw 0x2010, 0xA011, 0xA012, 0x2013
	dw 0x2014, 0x2015, 0x2016, 0x2017
	dw 0xA018
	dw 0xA400, 0x2401, 0x2402, 0x2403
	dw 0xA404, 0xA405, 0x2406, 0x2407
	dw 0x2408, 0x2409, 0x240A, 0x240B
	dw 0x240C, 0x240D, 0x240E, 0x240F
	dw 0x2410, 0x2411, 0xA412, 0xA413
	dw 0x2414, 0x2415, 0x2416, 0x2417
	dw 0xA418
	dw 0xA800, 0x2801, 0x2802, 0xA803
	dw 0xA804, 0x2805, 0x2806, 0x2807
	dw 0x2808, 0x2809, 0x280A, 0x280B
	dw 0x280C, 0x280D, 0x280E, 0x280F
	dw 0x2810, 0x2811, 0xA812, 0xA813
	dw 0x2814, 0x2815, 0x2816, 0x2817
	dw 0xA818
	dw 0xAC00, 0x2C01, 0x2C02, 0xAC03
	dw 0xAC04, 0x2C05, 0x2C06, 0x2C07
	dw 0x2C08, 0x2C09, 0x2C0A, 0x2C0B
	dw 0x2C0C, 0x2C0D, 0x2C0E, 0x2C0F
	dw 0x2C10, 0x2C11, 0xAC12, 0xAC13
	dw 0x2C14, 0x2C15, 0x2C16, 0x2C17
	dw 0xAC18
	dw 0xB000, 0x3001, 0x3002, 0xB003
	dw 0xB004, 0x3005, 0x3006, 0x3007
	dw 0x3008, 0x3009, 0x300A, 0x300B
	dw 0x300C, 0x300D, 0x300E, 0x300F
	dw 0x3010, 0x3011, 0xB012, 0xB013
	dw 0x3014, 0x3015, 0x3016, 0x3017
	dw 0xB018
	dw 0xB400, 0x3401, 0x3402, 0x3403
	dw 0x3404, 0x3405, 0x3406, 0x3407
	dw 0x3408, 0x3409, 0x340A, 0x340B
	dw 0x340C, 0x340D, 0x340E, 0x340F
	dw 0x3410, 0xB411, 0xB412, 0x3413
	dw 0x3414, 0x3415, 0x3416, 0x3417
	dw 0xB418
	dw 0xB800, 0x3801, 0x3802, 0x3803
	dw 0x3804, 0x3805, 0x3806, 0x3807
	dw 0x3808, 0x3809, 0x380A, 0x380B
	dw 0xB80C, 0xB80D, 0xB80E, 0xB80F
	dw 0xB810, 0xB811, 0x3812, 0x3813
	dw 0xB810, 0xB811, 0x3812, 0x3813
	dw 0x3814, 0x3815, 0x3816, 0x3817
	dw 0xB818
	dw 0xBC00, 0x3C01, 0x3C02, 0x3C03
	dw 0x3C04, 0x3C05, 0x3C06, 0x3C07
	dw 0x3C08, 0x3C09, 0x3C0A, 0x3C0B
	dw 0xBC0C, 0xBC0D, 0xBC0E, 0xBC0F
	dw 0xBC10, 0x3C11, 0x3C12, 0x3C13
	dw 0x3C14, 0x3C15, 0x3C16, 0x3C17
	dw 0xBC18
	dw 0xC000, 0x4001, 0x4002, 0x4003
	dw 0x4004, 0x4005, 0x4006, 0x4007
	dw 0x4008, 0x4009, 0x400A, 0x400B
	dw 0xC00C, 0xC00D, 0x400E, 0x400F
	dw 0x4010, 0x4011, 0x4012, 0x4013
	dw 0x4014, 0x4015, 0x4016, 0x4017
	dw 0xC018
	dw 0xC400, 0x4401, 0x4402, 0x4403
	dw 0x4404, 0x4405, 0x4406, 0x4407
	dw 0x4408, 0x4409, 0x440A, 0x440B
	dw 0xC40C, 0xC40D, 0x440E, 0x440F
	dw 0x4410, 0x4411, 0x4412, 0x4413
	dw 0x4414, 0x4415, 0x4416, 0x4417
	dw 0xC418
	dw 0xC800, 0x4801, 0x4802, 0x4803
	dw 0x4804, 0x4805, 0x4806, 0x4807
	dw 0x4808, 0x4809, 0x480A, 0x480B
	dw 0xC80C, 0xC80D, 0x480E, 0x480F
	dw 0x4810, 0x4811, 0x4812, 0x4813
	dw 0x4814, 0x4815, 0x4816, 0x4817
	dw 0xC818
	dw 0xCC00, 0x4C01, 0x4C02, 0x4C03
	dw 0x4C04, 0x4C05, 0x4C06, 0x4C07
	dw 0x4C08, 0x4C09, 0x4C0A, 0x4C0B
	dw 0x4C0C, 0x4C0D, 0x4C0E, 0x4C0F
	dw 0x4C10, 0x4C11, 0x4C12, 0x4C13
	dw 0x4C14, 0x4C15, 0x4C16, 0x4C17
	dw 0xCC18
	dw 0xD000, 0x5001, 0x5002, 0x5003
	dw 0x5004, 0x5005, 0x5006, 0x5007
	dw 0x5008, 0x5009, 0x500A, 0x500B
	dw 0xD00C, 0xD00D, 0x500E, 0x500F
	dw 0x5010, 0x5011, 0x5012, 0x5013
	dw 0x5014, 0x5015, 0x5016, 0x5017
	dw 0xD018
	dw 0xD400, 0x5401, 0x5402, 0x5403
	dw 0x5404, 0x5405, 0x5406, 0x5407
	dw 0x5408, 0x5409, 0x540A, 0x540B
	dw 0xD40C, 0xD40D, 0x540E, 0x540F
	dw 0x5410, 0x5411, 0x5412, 0x5413
	dw 0x5414, 0x5415, 0x5416, 0x5417
	dw 0xD418
	dw 0xD800, 0x5801, 0x5802, 0x5803
	dw 0x5804, 0x5805, 0x5806, 0x5807
	dw 0x5808, 0x5809, 0x580A, 0x580B
	dw 0x580C, 0x580D, 0x580E, 0x580F
	dw 0x5810, 0x5811, 0x5812, 0x5813
	dw 0x5814, 0x5815, 0x5816, 0x5817
	dw 0xD818
	dw 0xDC00, 0xDC01, 0xDC02, 0xDC03
	dw 0xDC04, 0xDC05, 0xDC06, 0xDC07
	dw 0xDC08, 0xDC09, 0xDC0A, 0xDC0B
	dw 0xDC0C, 0xDC0D, 0xDC0E, 0xDC0F
	dw 0xDC10, 0xDC11, 0xDC12, 0xDC13
	dw 0xDC14, 0xDC15, 0xDC16, 0xDC17
	dw 0xDC18
icon.raw.end:
icon.folder.init:
	dw 0x8010, 0x8011, 0x8012
	dw 0x840E, 0x840F, 0x0410, 0x0411
	dw 0x8412
	dw 0x880C, 0x880D, 0x080E, 0x080F
	dw 0x0810, 0x0811, 0x8812
	dw 0x880A, 0x880B, 0x080C, 0x080D
	dw 0x080E, 0x080F, 0x0810, 0x0811
	dw 0x8812
	dw 0x8C08, 0x8C09, 0x0C0A, 0x0C0B
	dw 0x0C0C, 0x0C0D, 0x0C0E, 0x0C0F
	dw 0x0C10, 0x0C11, 0x8C12
	dw 0x9006, 0x9007, 0x1008, 0x1009
	dw 0x100A, 0x100B, 0x100C, 0x100D
	dw 0x100E, 0x100F, 0x1010, 0x1011
	dw 0x9012
	dw 0x9404, 0x9405, 0x1406, 0x1407
	dw 0x1408, 0x1409, 0x140A, 0x140B
	dw 0x140C, 0x140D, 0x140E, 0x140F
	dw 0x1410, 0x1411, 0x9412
	dw 0x9802, 0x9803, 0x1804, 0x1805
	dw 0x1806, 0x1807, 0x1808, 0x1809
	dw 0x180A, 0x180B, 0x180C, 0x180D
	dw 0x180E, 0x180F, 0x1810, 0x1811
	dw 0x9812
	dw 0x9800, 0x9801, 0x1802, 0x1803
	dw 0x1804, 0x1805, 0x1806, 0x1807
	dw 0x1808, 0x1809, 0x180A, 0x180B
	dw 0x180C, 0x180D, 0x180E, 0x180F
	dw 0x1810, 0x1811, 0x9812
	dw 0x9C00, 0x9C01, 0x9C02, 0x9C03
	dw 0x9C04, 0x9C05, 0x9C06, 0x9C07
	dw 0x9C08, 0x9C09, 0x9C0A, 0x9C0B
	dw 0x9C0C, 0x9C0D, 0x9C0E, 0x9C0F
	dw 0x9C10, 0x9C11, 0x9C12, 0x9C13
	dw 0x9C14, 0x9C15, 0x9C16, 0x9C17
	dw 0xA000, 0x2001, 0x2002, 0x2003
	dw 0x2004, 0x2005, 0x2006, 0x2007
	dw 0x2008, 0x2009, 0x200A, 0x200B
	dw 0x200C, 0x200D, 0x200E, 0x200F
	dw 0x2010, 0x2011, 0x2012, 0x2013
	dw 0x2014, 0x2015, 0x2016, 0xA017
	dw 0xA400, 0x2401, 0x2402, 0x2403
	dw 0x2404, 0x2405, 0x2406, 0x2407
	dw 0x2408, 0x2409, 0x240A, 0x240B
	dw 0x240C, 0x240D, 0x240E, 0x240F
	dw 0x2410, 0x2411, 0x2412, 0x2413
	dw 0x2414, 0x2415, 0x2416, 0xA417
	dw 0xA800, 0x2801, 0x2802, 0x2803
	dw 0x2804, 0x2805, 0x2806, 0x2807
	dw 0x2808, 0x2809, 0x280A, 0x280B
	dw 0x280C, 0x280D, 0x280E, 0x280F
	dw 0x2810, 0x2811, 0x2812, 0x2813
	dw 0x2814, 0x2815, 0x2816, 0xA817
	dw 0xAC00, 0x2C01, 0x2C02, 0x2C03
	dw 0x2C04, 0x2C05, 0x2C06, 0x2C07
	dw 0x2C08, 0x2C09, 0x2C0A, 0x2C0B
	dw 0x2C0C, 0x2C0D, 0x2C0E, 0x2C0F
	dw 0x2C10, 0x2C11, 0x2C12, 0x2C13
	dw 0x2C14, 0x2C15, 0x2C16, 0xAC17
	dw 0xB000, 0x3001, 0x3002, 0x3003
	dw 0x3004, 0x3005, 0x3006, 0x3007
	dw 0x3008, 0x3009, 0x300A, 0x300B
	dw 0x300C, 0x300D, 0x300E, 0x300F
	dw 0x3010, 0x3011, 0x3012, 0x3013
	dw 0x3014, 0x3015, 0x3016, 0xB017
	dw 0xB400, 0x3401, 0x3402, 0x3403
	dw 0x3404, 0x3405, 0x3406, 0x3407
	dw 0x3408, 0x3409, 0x340A, 0x340B
	dw 0x340C, 0x340D, 0x340E, 0x340F
	dw 0x3410, 0x3411, 0x3412, 0x3413
	dw 0x3414, 0x3415, 0x3416, 0xB417
	dw 0xB800, 0x3801, 0x3802, 0x3803
	dw 0x3804, 0x3805, 0x3806, 0x3807
	dw 0x3808, 0x3809, 0x380A, 0x380B
	dw 0x380C, 0x380D, 0x380E, 0x380F
	dw 0x3810, 0x3811, 0x3812, 0x3813
	dw 0x3814, 0x3815, 0x3816, 0xB817
	dw 0xBC00, 0x3C01, 0x3C02, 0x3C03
	dw 0x3C04, 0x3C05, 0x3C06, 0x3C07
	dw 0x3C08, 0x3C09, 0x3C0A, 0x3C0B
	dw 0x3C0C, 0x3C0D, 0x3C0E, 0x3C0F
	dw 0x3C10, 0x3C11, 0x3C12, 0x3C13
	dw 0x3C14, 0x3C15, 0x3C16, 0xBC17
	dw 0xC000, 0x4001, 0x4002, 0x4003
	dw 0x4004, 0x4005, 0x4006, 0x4007
	dw 0x4008, 0x4009, 0x400A, 0x400B
	dw 0x400C, 0x400D, 0x400E, 0x400F
	dw 0x4010, 0x4011, 0x4012, 0x4013
	dw 0x4014, 0x4015, 0x4016, 0xC017
	dw 0xC400, 0x4401, 0x4402, 0x4403
	dw 0x4404, 0x4405, 0x4406, 0x4407
	dw 0x4408, 0x4409, 0x440A, 0x440B
	dw 0x440C, 0x440D, 0x440E, 0x440F
	dw 0x4410, 0x4411, 0x4412, 0x4413
	dw 0x4414, 0x4415, 0x4416, 0xC417
	dw 0xC418
	dw 0xC800, 0x4801, 0x4802, 0x4803
	dw 0x4804, 0x4805, 0x4806, 0x4807
	dw 0x4808, 0x4809, 0x480A, 0x480B
	dw 0x480C, 0x480D, 0x480E, 0x480F
	dw 0x4810, 0x4811, 0x4812, 0x4813
	dw 0x4814, 0x4815, 0x4816, 0x4817
	dw 0xC818
	dw 0xCC00, 0x4C01, 0x4C02, 0x4C03
	dw 0x4C04, 0x4C05, 0x4C06, 0x4C07
	dw 0x4C08, 0x4C09, 0x4C0A, 0x4C0B
	dw 0x4C0C, 0x4C0D, 0x4C0E, 0x4C0F
	dw 0x4C10, 0x4C11, 0x4C12, 0x4C13
	dw 0x4C14, 0x4C15, 0x4C16, 0x4C17
	dw 0xCC18
	dw 0xD000, 0x5001, 0x5002, 0x5003
	dw 0x5004, 0x5005, 0x5006, 0x5007
	dw 0x5008, 0x5009, 0x500A, 0x500B
	dw 0x500C, 0x500D, 0x500E, 0x500F
	dw 0x5010, 0x5011, 0x5012, 0x5013
	dw 0x5014, 0x5015, 0x5016, 0x5017
	dw 0xD018
	dw 0xD400, 0x5401, 0x5402, 0x5403
	dw 0x5404, 0x5405, 0x5406, 0x5407
	dw 0x5408, 0x5409, 0x540A, 0x540B
	dw 0x540C, 0x540D, 0x540E, 0x540F
	dw 0x5410, 0x5411, 0x5412, 0x5413
	dw 0x5414, 0x5415, 0x5416, 0x5417
	dw 0xD418
	dw 0xD800, 0x5801, 0x5802, 0x5803
	dw 0x5804, 0x5805, 0x5806, 0x5807
	dw 0x5808, 0x5809, 0x580A, 0x580B
	dw 0x5814, 0x5815, 0x5816, 0xD817
	dw 0x580C, 0x580D, 0x580E, 0x580F
	dw 0x5810, 0x5811, 0x5812, 0x5813
	dw 0x5814, 0x5815, 0x5816, 0xD817
	dw 0xD818
	dw 0xDC00, 0xDC01, 0xDC02, 0xDC03
	dw 0xDC04, 0xDC05, 0xDC06, 0xDC07
	dw 0xDC08, 0xDC09, 0xDC0A, 0xDC0B
	dw 0xDC0C, 0xDC0D, 0xDC0E, 0xDC0F
	dw 0xDC10, 0xDC11, 0xDC12, 0xDC13
	dw 0xDC14, 0xDC15, 0xDC16, 0xDC17
icon.folder.end:
icon.html.init:
    dd 111111111111111111111111b
    dd 100000000000001001001001b
    dd 100000000000001001001001b
    dd 111111111111111111111111b
    dd 100000000000000000000001b
    dd 101010111010001010000001b
    dd 101010010011011010000001b
    dd 101110010010101010000001b
    dd 101010010010001010000001b
    dd 101010010010001011100001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 111111111111111111111111b
icon.sys.init:
    dd 111111111111111111111111b
    dd 100000000000001001001001b
    dd 100000000000001001001001b
    dd 111111111111111111111111b
    dd 100000000000000000000001b
    dd 100110101001100000000001b
    dd 101000101010000000000001b
    dd 100100010001000000000001b
    dd 100010010000100000000001b
    dd 101100010011000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 111111111111111111111111b
icon.exe.init:
    dd 111111111111111111111111b
    dd 100000000000001001001001b
    dd 100000000000001001001001b
    dd 111111111111111111111111b
    dd 100000000000000000000001b
    dd 101110101011100000000001b
    dd 101000101010000000000001b
    dd 101110010011100000000001b
    dd 101000101010000000000001b
    dd 101110101011100000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 111111111111111111111111b
icon.bin.init:
    dd 111111111111111111111111b
    dd 100000000000000000000001b
    dd 100000110000000111110001b
    dd 100001010000001000001001b
    dd 100010010000010000000101b
    dd 100100010000010000000101b
    dd 100000010000010000000101b
    dd 100000010000010000000101b
    dd 100000010000010000000101b
    dd 100000010000001000001001b
    dd 101111111110000111110001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100011111000000001100001b
    dd 100100000100000010100001b
    dd 101000000010000100100001b
    dd 101000000010001000100001b
    dd 101000000010000000100001b
    dd 101000000010000000100001b
    dd 101000000010000000100001b
    dd 100100000100000000100001b
    dd 100011111000011111111101b
    dd 100000000000000000000001b
    dd 111111111111111111111111b
icon.cfea.init:
    dd 111111111111111111111111b
    dd 100000000000001001001001b
    dd 100000000000001001001001b
    dd 111111111111111111111111b
    dd 100000000000000000000001b
    dd 100100111011100100000001b
    dd 101010100010001010000001b
    dd 101000111011101110000001b
    dd 101010100010001010000001b
    dd 10010010001110101000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 111111111111111111111111b
icon.img.init:
    dd 111111111111111111111111b
    dd 100000000000000011111111b
    dd 100000000000000011111111b
    dd 100000000000000001111111b
    dd 100000000000000001111111b
    dd 100000000000000000111111b
    dd 100111100111000000000111b
    dd 101111111111100000000001b
    dd 100111100111000000000001b
    dd 100000000000000000000001b
    dd 100000000010000000000001b
    dd 100000000011111000000001b
    dd 100000000000100000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000000000001b
    dd 100000000000000100000001b
    dd 100000000000001110000001b
    dd 100000100000011111000001b
    dd 100001110000111111100001b
    dd 100011111111111111110001b
    dd 100111111111111111111001b
    dd 111111111111111111111111b
	;ascii database holds all ascii characters as bitmaps
text.database: ;  a bunch of bitmaps, a.k.a. .bmp files
	dd 000000000000000000000000000000b
	dd 000000000000000000000000000000b ; space
	dd 001000010000100001000010000100b
	dd 000000010000000000000000000000b ; ! / 0
	dd 010010100110010000000000000000b
	dd 000000000000000000000000000000b ; "
	dd 010100101011111010100101011111b
	dd 010100101000000000000000000000b ; #
	dd 001000111010100011100010100101b
	dd 011100010000000000000000000000b ; $
	dd 110011101000010001000010001000b
	dd 010111001100000000000000000000b ; %
	dd 011101000110000010001010010101b
	dd 100100110100000000000000000000b ; &
	dd 001000010000000000000000000000b
	dd 000000000000000000000000000000b ; '
	dd 000100010001000010000100001000b
	dd 001000001000000000000000000000b ; (
	dd 010000010001000010000100001000b
	dd 001000100000000000000000000000b ; )
	dd 010100010001010000000000000000b
	dd 000000000000000000000000000000b ; *
	dd 000000000000100001001111100100b
	dd 001000000000000000000000000000b ; +
	dd 000000000000000000000000000000b
	dd 011000110001000000000000000000b ; ,
	dd 000000000000000000000111000000b
	dd 000000000000000000000000000000b ; -
	dd 000000000000000000000000000000b
	dd 000000010000000000000000000000b ; .
	dd 000010001000010001000010001000b
	dd 010001000000000000000000000000b ; /
	dd 011101100110101100111000110001b
	dd 100010111000000000000000000000b ; 0
	dd 001000110010100001000010000100b
	dd 001001111100000000000000000000b ; 1
	dd 011101000100010001000100010000b
	dd 100001111100000000000000000000b ; 2
	dd 011101000100001011110000100001b
	dd 100010111000000000000000000000b ; 3
	dd 001010100110001111110000100001b
	dd 000010000100000000000000000000b ; 4
	dd 111111000010000111100000100001b
	dd 100010111000000000000000000000b ; 5
	dd 011101000110000111101000110001b
	dd 100010111000000000000000000000b ; 6
	dd 111110000100010001000010000100b
	dd 001000010000000000000000000000b ; 7
	dd 011101000110001011101000110001b
	dd 100010111000000000000000000000b ; 8
	dd 011101000110001011110000100001b
	dd 100010111000000000000000000000b ; 9
	dd 000000000000000000000010000000b
	dd 000000010000000000000000000000b ; :
	dd 000000000000000000000010000000b
	dd 000000010000100000000000000000b ; ;
	dd 000000000000000001110100010000b
	dd 010000011100000000000000000000b ; <
	dd 000000000000000000000111000000b
	dd 011100000000000000000000000000b ; =
	dd 000000000000000111000001000001b
	dd 000101110000000000000000000000b ; >
	dd 011101000100001000100010000100b
	dd 000000010000000000000000000000b ; ?
	dd 000000000011110000011110110101b
	dd 111010011000000000000000000000b ; @
	dd 011101000110001111111000110001b
	dd 100011000100000000000000000000b ; A
	dd 111101000110001111101000110001b
	dd 100011111000000000000000000000b ; B
	dd 011101000110000100001000010000b
	dd 100010111000000000000000000000b ; C
	dd 111101000110001100011000110001b
	dd 100011111000000000000000000000b ; D
	dd 111111000010000111101000010000b
	dd 100001111100000000000000000000b ; E
	dd 111111000010000111101000010000b
	dd 100001000000000000000000000000b ; F
	dd 011101000110000101101000110001b
	dd 100101110000000000000000000000b ; G
	dd 100011000110001111111000110001b
	dd 100011000100000000000000000000b ; H
	dd 111110010000100001000010000100b
	dd 001001111100000000000000000000b ; I
	dd 111110001000010000100001000010b
	dd 100100110000000000000000000000b ; J
	dd 100011001010100110001010010010b
	dd 100011000100000000000000000000b ; K
	dd 100001000010000100001000010000b
	dd 100001111100000000000000000000b ; L
	dd 100011101110101100011000110001b
	dd 100011000100000000000000000000b ; M
	dd 100011100110101100111000110001b
	dd 100011000100000000000000000000b ; N
	dd 011101000110001100011000110001b
	dd 100010111000000000000000000000b ; O
	dd 111101000110001111101000010000b
	dd 100001000000000000000000000000b ; P
	dd 011101000110001100011000110001b
	dd 100100110100000000000000000000b ; Q
	dd 111101000110001111101010010010b
	dd 100011000100000000000000000000b ; R
	dd 011101000110000011100000100001b
	dd 100010111000000000000000000000b ; S
	dd 111110010000100001000010000100b
	dd 001000010000000000000000000000b ; T
	dd 100011000110001100011000110001b
	dd 100010111000000000000000000000b ; U
	dd 100011000110001100011000110001b
	dd 010100010000000000000000000000b ; V
	dd 100011000110001100011000110101b
	dd 110111000100000000000000000000b ; W
	dd 100011000110001010100010001010b
	dd 100011000100000000000000000000b ; X
	dd 100011000110001010100010000100b
	dd 001000010000000000000000000000b ; Y
	dd 111110000100010001000100010000b
	dd 100001111100000000000000000000b ; Z
	dd 011100100001000010000100001000b
	dd 010000111000000000000000000000b ; [
	dd 100000100001000001000010000010b
	dd 000100000100000000000000000000b ; \
	; the fact that here, dd 0 i can't know if it works or not, i still don't understand
	; its like weird bc now its not needed
	dd 011100001000010000100001000010b
	dd 000100111000000000000000000000b ; ]
	dd 001000101010001000000000000000b
	dd 000000000000000000000000000000b ; ^
	dd 000000000000000000000000000000b
	dd 000001111100000000000000000000b ; _
	dd 010000010000010000000000000000b
	dd 000000000000000000000000000000b ; `
	dd 000000000000000011100000101111b
	dd 100010111100000000000000000000b ; a
	dd 000001000010000111101000110001b
	dd 100010111000000000000000000000b ; b
	dd 000000000000000011101000110000b
	dd 100010111000000000000000000000b ; c
	dd 000000000100001011111000110001b
	dd 100010111100000000000000000000b ; d
	dd 000000000000000011101000111110b
	dd 100000111000000000000000000000b ; e
	dd 000000000000000001100100101000b
	dd 010001110001000010000100000000b ; f
	dd 000000000000000011111000110001b
	dd 100010111100001000011000101110b ; g
	dd 000001000010000111101000110001b
	dd 100011000100000000000000000000b ; h
	dd 000000000000100000000010000100b
	dd 001000010000000000000000000000b ; i
	dd 000000000000010000000001000010b
	dd 000100001000010100100110000000b ; j
	dd 000001000010010101001100010100b
	dd 100101000100000000000000000000b ; k
	dd 000000010000100001000010000100b
	dd 001000001000000000000000000000b ; l
	dd 000000000000000110101010110101b
	dd 101011010100000000000000000000b ; m
	dd 000000000000000101101100110001b
	dd 100011000100000000000000000000b ; n
	dd 000000000000000011101000110001b
	dd 100010111000000000000000000000b ; o
	dd 000000000000000111101000110001b
	dd 100011111010000100001000010000b ; p
	dd 000000000000000011111000110001b
	dd 100010111100001001110000100001b ; q
	dd 000000000000000101111100010000b
	dd 100001000000000000000000000000b ; r
	dd 000000000000000011101000001110b
	dd 000010111000000000000000000000b ; s
	dd 000000000000000010001110001000b
	dd 010010011000000000000000000000b ; t
	dd 000000000000000100011000110001b
	dd 100010111100000000000000000000b ; u
	dd 000000000000000100011000110001b
	dd 010100010000000000000000000000b ; v
	dd 000000000000000100011000110001b
	dd 101010101100000000000000000000b ; w
	dd 000000000000000100010101000100b
	dd 010101000100000000000000000000b ; x
	dd 000000000000000100011000101010b
	dd 001000010000100101000100000000b ; y
	dd 000000000000000111110001000100b
	dd 000100000100001000011000101110b ; z
	dd 001100100101000110000100001000b
	dd 010010011000000000000000000000b ; {
	dd 001000010000100001000010000100b
	dd 001000010000100000000000000000b ; |
	dd 011001001000010000110001000010b
	dd 100100110000000000000000000000b ; }
	dd 000000000000000010011010110010b
	dd 000000000000000000000000000000b ; ~
	; I'm telling you know, this took me 6 hours to make, the whole ascii table :,(
	; btw i didn't include non-printable characters
	; if u try to print them, nothing prints
; i got well damn tired of scrolling 500 lines to get to this down here so welp
; just so y'all know, i used to calculate the amount of sectors so thats why this comments are here
; 5 sectors already probably more, just FOURTEEN MORE ICONS (if you ask, this is only 1)
; 6 sectors, and I have 2 proyects, this is B, but i changed the name on this one, i guess this is the real
; 9 sectors, pretty unnoticeable to the eye :) maybe 5 kB
; 13 sectors, i have 11 icons left and no way I am doing them lol
; note that this proyect is so big, i'm starting to use Ctrl+F
; to look for labels :O
; it's incredible how altough I kept trying to lower the amount
; I have finished the task manager (not with the UI) and now
; decided to make the icons and I reached 10kB, and 2000 lines
; this is the 2000th line after I wrote this(17 sectors lol)
; i decided 10kB is too much so I just made the code smaller than
; its now 1540 lines and 6kB, 4kb differemce
; it jumped back up to 1900 :D at least i'm not cheating lol, bc i just made the keyboard handler, 6.6kB too
kernel.osend: