org 0x7C00
use16
kernel.bootloader:
	mov ax, 0x4F02
	mov bx, 0x4105
	int 0x10
	mov ah, 0x02 ; number of sectors like at the end
	mov al, 10
	mov cx, 1
	mov dl, 0
	; this 0x80 means the disk 1, a.k.a. A:/
	; it's now 0 bc a hdd controller is harder than the fdd
	mov bx, 0x7C00
	int 0x13
	; todo: take desktop out of the HDD/floppy
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
kernel:
	dq 0x0000000000000000
	dq 0x00CF9A000000FFFF
	dq 0x00CF92000000FFFF
kernel.desc:
	dw kernel.end - kernel - 1
	dd kernel
kernel.end:
use32
kernel.main:
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	; here begginning code begins :)
	mov ecx, 0xB7000
	mov edi, 0xFD0C0000
background:
	mov al, 0x03
	stosb
	loop background
	mov ecx, 0x9000
	mov al, 0x07
	rep stosb
	xor dx, dx
	mov ds, dx
	mov es, dx
	mov esi, logo.init
	mov ecx, logo.end - logo.init
	shr ecx, 1
	xor eax, eax
logo.render:
	lodsw ; mov ax, word [ds:esi]
	mov edi, 0xFD178806 ; top left
	add edi, eax
	mov al, 0
	stosb ; mov word [es:edi], ax
	loop logo.render
    ; squareloop
    mov ecx, 34
    mov edi, 0xFD177401
    mov al, 0x0F
    rep stosb
	mov ecx, 34
    mov edi, 0xFD177801
    mov al, 0x0F
    rep stosb
    mov ecx, 34
    mov edi, 0xFD17F401
    mov al, 0x08
    rep stosb
	mov ecx, 34
    mov edi, 0xFD17F801
    mov al, 0x08
    rep stosb
    mov ecx, 30
    mov edi, 0xFD177C01
logo.render.border:
    times 2 stosb
    add edi, 0x1E
	mov al, 0x0F
    times 2 stosb
    add edi, 0x3DE
    loop logo.render.border
	; code to add this is end
	; debugging .raw
	call desktop
	; todo: read desktop
	; now mousecursor
	mov al, 0xA8
	out 0x64, al
	mov al, 0x20
	out 0x64, al
	in al, 0x60
	and al, 0xDF
	or al, 0x02
	mov ah, al
	mov al, 0x60
	out 0x64, al
	mov al, ah
	out 0x60, al
	mov al, 0xD4
	out 0x64, al
	mov al, 0xF4
	out 0x60, al
	push 0 ; buttons
	push 0 ; old mouse pos
	push 0 ; mouse position first in stacks
    mov edi, 0xFD000000
    mov esi, 0xFD0C0000
    mov ecx, 0xC0000
    rep movsb
mouse:
    xor eax, eax
	mov ebx, eax
	mov ecx, eax
	mov edx, eax
	call mouse.poll
	mov bl, al
	and al, 00001000b
	jz mouse
    pop edx ; ebx = new mouse pos/now old
    pop eax ; eax = old mouse pos/now older
    pop esi
    mov esi, 0xFD0C0000
    mov edi, 0xFD000000
    add esi, eax
    add edi, eax
    mov cl, 0x11
mouse.replace:
    push ecx ; save ecx, it will get poped after loop
    mov cl, 0x0C
	rep movsb
    add edi, 0x3F4
    add esi, 0x3F4
    pop ecx
    loop mouse.replace
    push ebx ; mouse state
    push eax ; old pos
    push edx ; new pos
	xor eax, eax
	mov ebx, eax
	mov ecx, eax
	mov edx, eax
	call mouse.poll
	mov cl, al
	call mouse.poll
	mov dl, al
	pop eax ; new pos
	pop ebx ; old pos
	push eax ; new->old
	movsx ecx, cl ; cl is x delta
	movsx edx, dl ; dl is -y delta
	shl edx, 10 ; edx *= 1024(2^10)
	neg edx ; edx = -edx
	add eax, ecx ; pos = pos+x+y*1024
	add eax, edx
	cmp eax, 0xC0000
	jb mouse.skip
	xor eax, eax
mouse.skip:
	call mouse.print
	push edx ; calced result
	mov ecx, 0xFFFFFFFF
	rep nop
	jmp mouse.skip
	; here went mouse position
	; goes*, went*, goes*, went*, goes*, went*
	; i decided to put it on stack, copying windows
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
	and eax, 0x7FFF ; eax = 0x9000
	add edi, eax ; edi = 0xFD009802
	and ebx, 0x8000
	shr ebx, 15
	add ebx, 0x0F
	mov al, bl
	stosb ; mov word [es:edi], ax
	loop mouse.print.loop
	ret
mouse.poll:
	in al, 0x64
	test al, 0x21
	jz mouse.poll
	in al, 0x60
	ret
	; time to uhm idk , "I'll make the desktop"
	; why not tho lol
	; this is me 5 days later, I regret it
	; the mouse worked, i didnt back up and it doesnt work anymlre
	; the mouse had scroll lock... yea, scroll lock I didn't know that existed
	; it has been one month, i unregret it i might have finished now only one thing left
	; the floppy disk controller, which ja what i hate  
times 510 - ($ - $$) db 0
dw 0xAA55
desktop:
	mov esi, desktop.files
	mov edi, 0xFD0C080A
	call desktop.proc
	ret
desktop.proc:
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
	mov bl, 0
	call text
desktop.proc.skip:
	ret
icon:
    cmp al, 0
    je icon.print.raw
    cmp al, 1
    je icon.print.folder
    cmp al, 2
    je icon.print.folder
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
icon.print.raw:
    mov esi, icon.raw.init
	mov ecx, icon.raw.end - icon.raw.init
	jmp icon.print
icon.print.folder:
    mov esi, icon.folder.init
    mov ecx, icon.folder.end - icon.folder.init
    jmp icon.print
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
	; bl is color ; 0x0F
	; al is char = 0 a.k.a null just for debugging
	; cl is nibble (least significant bit / 1)
	; btw this is a copy from another OS i made (altough its real-mode, so i couldn't copy paste)
	; I wanted to copy and paste my own code, but they were made for different devices
	and cl, 1
	shl cl, 2 ; multiply by 4 bytes and add
	movzx ecx, cl
	mov esi, text.database
	and al, 0x7F ; filter out non-ascii characters
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
    dd 0x180E, 0x180F, 0x1810, 0x1811
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
	;ascii database holds all ascii characters as bitmaps
text.database: ;  a bunch of bitmaps, a.k.a. .bmp files
	times 64 dd 0; 32 chars, each 2 dw 64 dw?
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
	; btw i didn't include non-printable characters, they're just a space
; here's finally where the files are :)
; Hard-coded folder's I've made:
; file system:
	; b1:bitflag Hidden?/4-bit protocol #/Tbit/2bit length size in bytes
	; b2:size (accordingly)
	; bN: name
	; bM: 0x00
desktop.files: 
	db 00001000b, 0x00, "My File", 0 ; a file!
times 512 * 9 - ($ - $$) db 0 ; just to know if I surpass limit to add another secto
; 5 sectors already probably more, just FOURTEEN MORE ICONS (if you ask, this is only 1)
; 6 sectors, and I have 2 proyects, this is B, but i changed the name on this one, i guess this is the real
; 9 sectors, pretty unnoticeable to the eye :) maybe 5 kB
	pusha
	cmp cl, 0x01 ; text
	je kernel.text
	cmp cl, 0x02 ; icon
	je kernel.icon
kernel.return:
	popa
	ret
kernel.text:
	call text
	jmp kernel.return
kernel.icon:
	call icon
	jmp kernel.return