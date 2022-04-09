IDEAL
MODEL small
STACK 100h
DATASEG

	winWidth dw 320
	winHeight dw 200

	; Img {
		; Note: every function or variable with 1 at the end means you need to make a copy for each img

		imgName db 'test.bmp'
		imgFileHandle1 dw ? ; Keeps track on which file is open - current file's id. create a new one for each img
		imgHeader db 54 dup (0)
		imgPalette db 256*4 dup (0)
		imgScrLine db 320 dup (0) ; windowWidths zeros
		imgStartX dw ?
		imgStartY dw ?
		imgWidth dw ?
		imgHeight dw ?
	; }

	; Line {
		lineColor db ?
		lineHOrV db ?
		lineStartX dw ?
		lineStartY dw ?
		lineLength dw ?
	; }

	; Circle {
		circleX dw ? ; Middle point.x
		circleY dw ? ; Middle point.y
		circleR dw ? ; Radius, max value = 181d / b5h
		circleColor db ? ; 8 bit color
		circleRSqr dd ? ; Radius squared
		circleCounterX dw ? ; Loop helper
		circleCounterY dw ? ; Loop helper
		circleDeltaX dd ? ; Middle point.x - The pixel's place.x
		circleDeltaY dd ? ; Middle point.y - The pixel's place.y
		circleDistanceSqr dd ? ; circleDeltaX + circleDeltaY
		circlePixelPlaceX dw ? ; current pixel.x
		circlePixelPlaceY dw ? ; current pixel.y
	; }

	; Table {
		tableSquareLength dw ? ; Each cell's width and 
		tableSquareHorizontalNum db ? ; Number of columns
		tableSquareVerticalNum db ? ; Number of rows
		tableSquaresStartX dw ? ; Where does the table start.x
		tableSquaresStartY dw ? ; Where does the table start.y
		tableCurrentX dw ?
		tableCurrentY dw ?
		tableCounterX dw ?
		tableCounterY dw ?
		tableBorderColor db ? ; Table's border color
	; }

	; Delay {
		microSec dd ?
	; }

CODESEG

proc openImgFile1
	; Made By Amit Mathov
	; Open file in reading mode
	mov ah, 3Dh
	xor al, al
	mov dx, offset imgName
	int 21h
	
	mov [imgFileHandle1], ax
	ret
endP openImgFile1

proc readImgHeader1
	; Made By Amit Mathov
	; Read BMP file header, 54 bytes
	mov ah, 3fh
	mov bx, [imgFileHandle1]
	mov cx, 54
	mov dx,offset imgHeader
	int 21h
	ret
endP readImgHeader1

proc readImgPalette
	; Made By Amit Mathov
	; Read BMP file color palette, 256 colors * 4 bytes (400h)
	mov ah, 3fh
	mov cx, 400h
	mov dx, offset imgPalette
	int 21h
	ret
endP readImgPalette

proc copyImgPal
	; Made By Amit Mathov
	; Copy the colors palette to the video memory
	; The number of the first color should be sent to port 3C8h
	; The palette is sent to port 3C9h
	mov si, offset imgPalette
	mov cx, 256
	mov dx, 3C8h
	mov al, 0

	; Copy starting color to port 3C8h
	out dx, al

	; Copy imgPalette itself to port 3C9h
	inc dx
		
	PalLoop:
		; Note: Colors in a BMP file are saved as BGR values rather than RGB
		
		mov al, [si+2] ; Get red value.
		shr al, 2 ; Max is 255, but video palette maximal value is 63, Therefore dividing by 4

		out dx, al ; Send it
		mov al, [si+1] ; Get green value
		shr al, 2
		out dx, al ; Send it
		mov al, [si] ; Get blue value
		shr al, 2
		out dx, al ; Send it
		add si, 4 ; Point to next color

		; Note: There is a null char after every color

		loop PalLoop

	ret
endP copyImgPal

proc copyImgBitmap
	; Made By Amit Mathov
	; BMP graphics are saved upside-down
	; Read the graphic line by line (200 lines in VGA format)
	; displaying the lines from bottom to top
	mov ax, 0A000h
	mov es, ax
	mov cx, 100
		
	PrintBMPLoop:
		push cx

		; di = cx*320, point to the correct screen line
		mov di,cx
		shl cx,6
		shl di,8
		add di,cx

		add di, [imgStartX] ; Add imgStartX
		; Add imgStartY * winWidth
		mov ax, [winWidth]
		mul [imgStartY]
		add di, ax

		; Read one line
		mov ah, 3fh
		push ax
		
		; BMP is stored in groups of 4, here I find the next multiple of 4 after imgWidth
		mov ax, [imgWidth]
		mov cx, 4
		div cx
		sub cx, dx
		
		add cx, [imgWidth]

		mov dx, offset imgScrLine
		pop ax
		int 21h

		; Copy one line into video memory
		cld ; Don't even bother to understand

		; Clear direction flag, for movsb
		mov cx, [imgWidth]
		mov si, offset imgScrLine
		rep movsb 

		; Copy line to the screen
		;rep movsb is same as the following code:
			;mov es:di, ds:si
			;inc si
			;inc di
			;dec cx
			;loop until cx=0

		pop cx
		loop PrintBMPLoop

	ret
endP copyImgBitmap

proc closeImgFill1
	; Made By Amit Mathov
	mov bx, [word ptr imgFileHandle1]
	mov ah, 3eh
	int 21h
	ret
endP closeImgFill1

proc line
	; Made By Amit Mathov
	mov cx, [lineLength]
	
	push ax
	push bx
	push dx
	
	loopLine:
		push cx
		
		mov ah, 0ch
		mov al, [lineColor]
		mov cx, [LineStartX]
		mov dx, [LineStartY]
		xor bx, bx
		int 10h
		
		cmp [lineHOrV], 0
		je horizontal
		jmp vertical
		
		returnLine:
			pop cx
			dec cx
			cmp cx, 0
			jne loopLine
	
	endProc:
		pop dx
		pop bx
		pop ax
		ret

	horizontal:
		inc [LineStartX]
		jmp returnLine

	vertical:
		inc [LineStartY]
		jmp returnLine

endP line

proc makeCircle
	; Made By Amit Mathov
	push ax
	push bx
	push cx
	push dx
	push [circleX]
	push [circleY]
	push [circleCounterX]
	push [circleCounterY]

	; check all x from the start of the circle to the end
	mov cx, [circleR]
	shl cx, 1
	mov [circleCounterX], 0
	
	loopX:
		push cx
		; check all y from the start of the circle to the end
		mov cx, [circleR]
		shl cx, 1
		mov [circleCounterY], 0

		loopY:
			push cx
			; Ax = checking.x = x-r+counter
			mov ax, [circleX]
			sub ax, [circleR]
			add ax, [circleCounterX]
			mov [circlePixelPlaceX], ax
			; Dx = checking.y = y-r+counter
			mov dx, [circleY]
			sub dx, [circleR]
			add dx, [circleCounterY]
			mov [circlePixelPlaceY], dx
			; Find delta x
			mov bx, ax
			mov ax, [circleX]
			sub ax, bx
			mov [word ptr circleDeltaX], ax
			mov [word ptr circleDeltaX + 2], 0
			; Find delta y
			mov bx, dx
			mov dx, [circleY]
			sub dx, bx
			mov [word ptr circleDeltaY], dx
			mov [word ptr circleDeltaY + 2], 0
			jmp continue1
			;======this part is to fix a loop bug just continue on======
			loopHelper1:
				jmp loopX
			
			loopHelper2:
				jmp loopY
			;===========================================================
			continue1:
				; Calculating distance between current xy to circle center using the Pythagorean theorem:
				; First: sqr circleDeltaX
				mov ax, [word ptr circleDeltaX]
				imul ax
				mov [word ptr circleDeltaX], ax
				mov [word ptr circleDeltaX + 2], dx
				; Second: sqr circleDeltaY
				mov ax, [word ptr circleDeltaY]
				mov dx, [word ptr circleDeltaY]
				imul dx
				mov [word ptr circleDeltaY], ax
				mov [word ptr circleDeltaY + 2], dx
				; Third: sqr radius
				mov ax, [word ptr circleR]
				mov dx, [word ptr circleR]
				imul dx
				mov [word ptr circleRSqr], ax
				mov [word ptr circleRSqr + 2], dx
				; Final, sqr circleDeltaX + sqr circleDeltaY
				mov [word ptr circleDistanceSqr], 0
				mov [word ptr circleDistanceSqr + 2], 0
				mov ax, [word ptr circleDeltaX]
				add ax, [word ptr circleDeltaY]
				mov [word ptr circleDistanceSqr], ax
				jc reminder
				mov ax, [word ptr circleDeltaX + 2]
				add ax, [word ptr circleDeltaY + 2]
				mov [word ptr circleDistanceSqr + 2], ax
			continue2:
				; Cmp [word ptr circleDistanceSqr + 2], [word ptr circleRSqr + 2]
				mov ax, [word ptr circleDistanceSqr + 2]
				sub ax, [word ptr circleRSqr + 2]
				cmp ax, 0
				jl inside ; If pixel is inside the circle
				je needMoreData ; If First 4 digs aren't anough, try next 4 digs
			continue3:
				pop cx
				inc [circleCounterY]
				dec cx
				cmp cx, 0
				ja loopHelper2
		pop cx
		inc [circleCounterX]
		dec cx
		cmp cx, 0
		ja loopHelper1
	
	pop [circleCounterY]
	pop [circleCounterX]
	pop [circleY]
	pop [circleX]
	pop dx
	pop cx
	pop bx
	pop ax

	ret

	reminder:
		mov ax, [word ptr circleDeltaX + 2]
		add ax, [word ptr circleDeltaY + 2]
		mov [word ptr circleDistanceSqr + 2], ax
		inc ax
		jmp continue2
	
	inside:
		mov bh, 0h
		mov cx, [circlePixelPlaceX] ; X
		mov dx, [circlePixelPlaceY] ; Y
		mov al, [circleColor] ; Color
		mov ah, 0ch
		int 10h
		jmp continue3
	
	needMoreData:
		mov ax, [word ptr circleDistanceSqr]
		sub ax, [word ptr circleRSqr]
		cmp ax, 0
		jl inside ; If pixel is inside the circle
		jmp continue3
endP makeCircle

proc linesVertical
	; Made By Amit Mathov
	; Loop tableSquareHorizontalNum times
	mov cl, [tableSquareHorizontalNum]
	xor ch, ch
	mov [tableCounterX], 0
	inc cx
	
	loopingX1:
		push cx
		
		; Find x cordinate
		mov al, [byte ptr tableCounterX]
		xor ah, ah
		mul [tableSquareLength]
		add ax, [tableSquaresStartX]
		mov [tableCurrentX], ax

		; loop tableSquareVerticalNum * tableSquareLength times
		mov al, [tableSquareVerticalNum]
		xor ah, ah
		mov dx, [tableSquareLength]
		mul dx
		mov cx, ax

		mov ax, [tableSquaresStartY]
		mov [tableCounterY], 0
		mov [tableCurrentY], ax
		
		loopingY1:
			push cx

			; Find if pixel is in screen
			mov ax, [tableCurrentY]
			cmp ax, [winHeight]
			jge endProc1

			; Draw pixel
			mov bh, 0h
			mov cx, [tableCurrentX] ; X
			mov dx, [tableCurrentY] ; Y
			mov al, [tableBorderColor] ; Color
			mov ah, 0ch
			int 10h

			inc [tableCounterY]
			inc [tableCurrentY]
			pop cx
			loop loopingY1

		inc [tableCounterX]
		pop cx
		loop loopingX1
	
	endProc1:
		ret
endP linesVertical

proc linesHorizontal
	; Made By Amit Mathov
	; Loop tableSquareVerticalNum times
	mov cl, [tableSquareVerticalNum]
	xor ch, ch
	mov [tableCounterY], 0
	inc cx

	loopingY2:
		push cx

		; Find y cordinate
		mov al, [byte ptr tableCounterY]
		xor ah, ah
		mul [tableSquareLength]
		add ax, [tableSquaresStartY]
		mov [tableCurrentY], ax

		; loop tableSquareHorizontalNum * tableSquareLength times
		mov al, [tableSquareHorizontalNum]
		xor ah, ah
		mov dx, [tableSquareLength]
		mul dx
		mov cx, ax

		mov ax, [tableSquaresStartX]
		mov [tableCounterX], 0
		mov [tableCurrentX], ax
		
		loopingX2:
			push cx

			; Find if pixel is in screen
			mov ax, [tableCurrentX]
			cmp ax, [winWidth]
			jge endProc2

			; Draw pixel
			mov bh, 0h
			mov cx, [tableCurrentX] ; X
			mov dx, [tableCurrentY] ; Y
			mov al, [tableBorderColor] ; Color
			mov ah, 0ch
			int 10h

			inc [tableCounterX]
			inc [tableCurrentX]
			pop cx
			loop loopingX2

		inc [tableCounterY]
		pop cx
		loop loopingY2
	
	endProc2:
		ret
endP linesHorizontal

proc clearKeyboardBuffer
	; Made By Amit Mathov
	; Useful for checking if a key was pressed
	push ax
	push es
	mov	ax, 0000h
	mov	es, ax
	mov	es:[041ah], 041eh
	mov	es:[041ch], 041eh	;clears keyboard buffer
	pop	es
	pop	ax
	ret
endP clearKeyboardBuffer

proc delay
	; Made By Amit Mathov
	; Starts delay for microSecond microseconds
	push cx
	push ax
	push dx
	mov cx, [word ptr microSec + 2]
	mov dx, [word ptr microSec]
	;mov cx, 0fh
	;mov dx, 4240h
	mov ah, 86h
	int 15h
	pop dx
	pop ax
	pop cx
	ret
endP delay

start:
	mov ax, @data
	mov ds, ax

	; Graphic mode
	mov ax, 13h
	int 10h

	call clearKeyboardBuffer

showBMP:
	; Show BMP in specific xy
	call openImgFile1
	call readImgHeader1
	call readImgPalette
	call copyImgPal
	mov [imgStartX], 100
	mov [imgStartY], 100
	mov [imgWidth], 105
	mov [imgHeight], 100
	call copyImgBitmap
	call closeImgFill1

drawLine:
	; Create a simple line
	mov [lineColor], 9
	mov [lineHOrV], 1
	mov [lineStartX], 250
	mov [lineStartY], 0
	mov ax, [winHeight]
	mov [lineLength], ax
	call line

drawCircle:
	; Draws a circle in xy with specified radius
	mov [circleX], 181
	mov [circleY], 50
	mov [circleR], 50
	mov [circleColor], 6h
	call makeCircle

drawTable:
	; Make table in xy, and lengths
	mov [tableSquareLength], 5
	mov [tableSquareHorizontalNum], 5
	mov [tableSquareVerticalNum], 5
	mov [tableSquaresStartX], 30
	mov [tableSquaresStartY], 30
	mov [tableBorderColor], 4ch
	call linesHorizontal
	call linesVertical

startDelay:
	; Start a delay for x microseconds
	; A second = 0f4240h
	; 1/30 second - a frame = 8235h
	mov [word ptr microSec], 4240h ; First 4 digits
	mov [word ptr microSec + 2], 0fh ; Last 4 digits
	call delay

exit:
	mov ax, 4c00h
	int 21h

END start