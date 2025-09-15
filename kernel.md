Kasmon System Call Dictionary
	cl = function #
Note: To syscall:
	call 0x8E00

Function 1 - 'text':
	al  = Color as in the VGA Pallette
	edi = Destination Address
	esi = Character Array Address ending with 0x00

Function 2 - 'icon':
	al  = Protocol/Icon Number:
		 0: Raw File
		 1 & 2: Folder
		 3: HTML File/Webpage
		 4: System Application
		 5: Executable Application
		 6: Text File
		 7: Binary File
		 8: Custom File Extension
		 9 & 10: Encrypted Folder
		 11: Image File
		 12: Video File
		 13: Bitmap Image File
		 14: Audio File
		 15: File Extension Addon
	edi = Destination	