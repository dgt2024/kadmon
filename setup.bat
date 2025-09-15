@echo off
cd C:\Users\ENVY\Desktop\Proyects\EszettOS
fasm boot.asm boot.bin
qemu-system-i386 -fda boot.bin -display gtk,zoom-to-fit=on -full-screen
pause