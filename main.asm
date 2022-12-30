#-----------------------------------------------#
# author: Jan Szachno, 310982                   #
# semester: 22Z                                 #
# project: Code 128 - barcode generation, set C #
#-----------------------------------------------#

.eqv BMP_FILE_SIZE 90122
.eqv BYTES_PER_ROW 1800

.eqv SYS_OPEN_FILE 1024
.eqv SYS_READ_FILE 63
.eqv SYS_CLOSE_FILE 57
.eqv SYS_PRINT_CHAR 11
.eqv SYS_PRINT_STRING 4
.eqv SYS_READ_INT 5
.eqv SYS_READ_STRING 8
.eqv SYS_EXIT 10
.eqv SYS_PRINT_INT 1
.eqv LF 10
.eqv SPACE 32
.eqv PATTERN_FILE_SIZE 325 # 106 symbols * 3 bytes + 7 for stop symbol
.eqv BYTES_PER_CODE 3
.eqv START_CODE_INDEX 105
.eqv STOP_CODE_INDEX 106

.eqv MAX_INPUT_LENGTH 80
.eqv MAX_NUM_VALUES 40 # half of max input length
.eqv ASCII_DIGIT_OFFSET 48

	.data
source_image: .asciz "source.bmp"
result_image: .asciz "result.bmp"

.align 4
res:	.space 2
image:	.space BMP_FILE_SIZE
	
pattern_file: .asciz "patterns"
patterns: .space PATTERN_FILE_SIZE
error_pattern_file: .asciz "Error: Could not open pattern file"
error_open_bmp_file: .asciz "Error: Could not open source bmp file"
error_save_bmp_file: .asciz "Error: Could not save result bmp file"

input: .space MAX_INPUT_LENGTH
width_prompt: .asciz "Enter the width of the narrowest bar (in pixels): "
text_prompt: .asciz "Enter data to encode: "
narrowest_bar_width: .byte 1

num_values: .byte 1
values: .byte MAX_NUM_VALUES
error_parse: .asciz "Error: Invalid input"

print_buffer: .byte 7

	.text
main:
	# get necessary data
	jal read_user_input
	jal parse_user_input
	jal read_pattern
	jal read_bmp
	
	# s11 - current x position
	la s10, narrowest_bar_width
	lbu s11, (s10) # set current x position to narrowest bar width
	li s10, 10
	mul s11, s11, s10 # set current x position to 10 times narrowest bar (quiet zone)
	
	# print the start code
	li a0, START_CODE_INDEX
	jal decode_symbol
	jal draw_code
	
	# print encoded user input
	jal draw_input
	
	# calculate checksum value
	li t0, START_CODE_INDEX
	la t1, values
	la t2, num_values
	lbu t3, (t2)
	li t4, 1
checksum_loop:
	bgt t4, t3, end_checksum_loop

	lbu t5, (t1) # read value of current symbol
	mul t5, t5, t4 # multiply by current index
	add t0, t0, t5 # add to the overall sum

	addi t1, t1, 1
	addi t4, t4, 1
	j checksum_loop
end_checksum_loop:

	li s0, 103
	remu s1, t0, s0 # calculate mod from sum of items
	
	mv a0, s1
	jal decode_symbol
	jal draw_code

	# print the stop code
	li a0, STOP_CODE_INDEX
	jal decode_symbol
	jal draw_code
	
	jal save_bmp
	
# ---------- The End ---------- 
	li a7, SYS_EXIT
	ecall





# ---------- Helper Functions ----------

# ============================================================================
draw_input:
# description: 
#	draw input from the user at current x position
# arguments: 
# 	s11 - x position
# return value: none
	addi sp, sp, -4
	sw ra, (sp)
	addi sp, sp, -4
	sw a0, (sp)
	addi sp, sp, -4
	sw t1, (sp)
	addi sp, sp, -4
	sw t2, (sp)
	addi sp, sp, -4
	sw t3, (sp)
	addi sp, sp, -4
	sw t4, (sp)

	la t1, values
	la t2, num_values
	lbu t3, (t2)
	li t4, 1
some_loop:
	bgt t4, t3, end_some_loop

	lbu a0, (t1)
	jal decode_symbol
	jal draw_code

	addi t1, t1, 1
	addi t4, t4, 1
	j some_loop
end_some_loop:

	lw t4, (sp)
	addi sp, sp, 4
	lw t3, (sp)
	addi sp, sp, 4
	lw t2, (sp)
	addi sp, sp, 4
	lw t1, (sp)
	addi sp, sp, 4
	lw a0, (sp)
	addi sp, sp, 4
	lw ra, (sp)
	addi sp, sp, 4
	jr ra

# ============================================================================
draw_code:
# description: 
#	read symbol from print buffer and draw it to the screen
# arguments: 
# 	s11 - x position
# return value: none
	addi sp, sp, -4
	sw ra, (sp)
	
	addi sp, sp, -4
	sw t0, (sp)
	
	addi sp, sp, -4
	sw t1, (sp)
	
	addi sp, sp, -4
	sw t2, (sp)
	
	la t0, print_buffer
	
	li t1, 1 # loop counter
	li t2, 7 # loop limit
print_loop:
	bgt t1, t2, end_print_loop
	
	lbu a0, (t0)
	mv s0, t1
	andi s0, s0, 1 # s0 will have 0 if counter is even
	beqz s0, space
	
	bar:
	jal draw_bar
	j continue
	space:
	la s0, narrowest_bar_width
	lbu s1, (s0)
	mul s1, s1, a0
	add s11, s11, s1
	continue:

	li a7, SYS_PRINT_INT
	ecall
	li a0, SPACE
	li a7, SYS_PRINT_CHAR
	ecall
	
	addi t1, t1, 1
	addi t0, t0, 1
	j print_loop
end_print_loop:

	li a7, SYS_PRINT_CHAR
	li a0, LF
	ecall
	
	lw t2, (sp)
	addi sp, sp, 4
	
	lw t1, (sp)
	addi sp, sp, 4

	lw t0, (sp)
	addi sp, sp, 4
	
	lw ra, (sp)
	addi sp, sp, 4
	jr ra

# ============================================================================
draw_bar:
# description: 
#	draws black vertical bar of given width at given x position
# arguments: 
#       a0 - bar width
# 	s11 - x position
# return value: none
	addi sp, sp, -4
	sw ra, (sp)
	
	addi sp, sp, -4
	sw a0, (sp)	
	
	addi sp, sp, -4
	sw t0, (sp)
	
	addi sp, sp, -4
	sw t1, (sp)
	
	li t0, 1
	mv t1, a0
	la s0, narrowest_bar_width
	lbu s1, (s0)
	mul t1, t1, s1
draw_bar_loop:
	bgt t0, t1 end_draw_bar_loop
	jal draw_line
	addi t0, t0, 1
	addi s11, s11, 1
	j draw_bar_loop
end_draw_bar_loop:

	lw t1, (sp)
	addi sp, sp, 4

	lw t0, (sp)
	addi sp, sp, 4
	
	lw a0, (sp)
	addi sp, sp, 4
	
	lw ra, (sp)
	addi sp, sp, 4
	jr ra
# ============================================================================
draw_line:
# description: 
#	draws 1px black vertical line at given x position
# arguments: 
# 	s11 - x position
# return value: none
	addi sp, sp, -4
	sw ra, (sp)
	
	addi sp, sp, -4
	sw t0, (sp)
	
	addi sp, sp, -4
	sw t1, (sp)
	
	li t1, 5  # loop counter
	li t0, 45 # loop limit
line_loop:
	bgt t1, t0, end_line_loop
	mv a0, s11
	mv a1, t1
	li a2, 0x0000000
	jal put_pixel
	addi t1, t1, 1
	j line_loop
end_line_loop:

	lw t1, (sp)
	addi sp, sp, 4
	
	lw t0, (sp)
	addi sp, sp, 4
	
	lw ra, (sp)
	addi sp, sp, 4
	jr ra

# ============================================================================
read_pattern:
# description: 
#	reads the contents of the pattern file into memory
# arguments: none
# return value: none
	addi sp, sp, -4
	sw ra, (sp)

	# open file
	li a7, SYS_OPEN_FILE
        la a0, pattern_file
        li a1, 0 # 0-read file
        ecall
	mv s1, a0 # save the file descriptor
	
	# check for errors - if the file was opened
	li s10, -1
	bne s1, s10, no_error # if the file descriptor!=-1 - continue
	# display error message
	li a7, SYS_PRINT_STRING
	la a0, error_pattern_file
	ecall
	# close program
	li a7, SYS_EXIT
	ecall
	no_error:
	
	# read file
	li a7, SYS_READ_FILE
	mv a0, s1
	la a1, patterns
	li a2, PATTERN_FILE_SIZE
	ecall

	# close file
	li a7, SYS_CLOSE_FILE
	mv a0, s1
        ecall
        
        lw ra, (sp)
	addi sp, sp, 4
	jr ra

# ============================================================================
read_user_input:
# description: 
#	reads the input values from user and saves them into memory
# arguments: none
# return value: none
        addi sp, sp, -4
	sw ra, (sp)
	# print narrowest bar prompt
	li a7, SYS_PRINT_STRING
	la a0, width_prompt
	ecall
	# read the narrowest bar width
	li a7, SYS_READ_INT
	ecall
	la a1, narrowest_bar_width
	sb a0, (a1)
	# print input string prompt
	li a7, SYS_PRINT_STRING
	la a0, text_prompt
	ecall
	# load the input string
	li a7, SYS_READ_STRING
	la a0, input
	li a1, MAX_INPUT_LENGTH
	ecall
	
        lw ra, (sp)
	addi sp, sp, 4
	jr ra

# ============================================================================
parse_user_input:
# description: 
#	reads saved user input from memory and parses it into array of bytes
#	representing the symbols
# arguments: none
# return value: none
        addi sp, sp, -4
	sw ra, (sp)

	la t0, input
	la t1, values
	li s0, 0
	li s9, 9
	li s10, 10
	li s8, LF
	li s4, 0 # num values
parse_loop:
	lbu s1, (t0)
	beqz s1, end_parse_loop
	beq s1, s8, end_parse_loop
	addi t0, t0, 1
	
	lbu s2, (t0)
	beqz s2, invalid_string
	beq s2, s8, invalid_string
	addi t0, t0, 1

	addi s1, s1, -ASCII_DIGIT_OFFSET
	addi s2, s2, -ASCII_DIGIT_OFFSET
	
	blt s1, s0, invalid_string
	bgt s1, s9, invalid_string
	blt s2, s0, invalid_string
	bgt s2, s9, invalid_string
	
	mv s3, s1
	mul s3, s1, s10
	add s3, s3, s2
	
	sb s3, (t1)
	addi t1, t1, 1
	addi s4, s4, 1

	j parse_loop
	
	invalid_string:
	li a7, 4
	la a0, error_parse
	ecall
	li a7, 10
	ecall
end_parse_loop:
	la t3, num_values
	sb s4, (t3)
	
        lw ra, (sp)
	addi sp, sp, 4
	jr ra

# ============================================================================
decode_symbol:
# description: 
#	decodes the given symbol and saves it into the print buffer
# arguments: 
#	a0 - symbol to decode (unsigned 8bit int)
# return value: none
	addi sp, sp, -4
	sw ra, (sp)
	
	addi sp, sp, -4
	sw a0, (sp)

	mv s1, a0
	la s0, print_buffer
	
	# calculate where in memory the decoded pattern is stored
	li s2, BYTES_PER_CODE
	mul s3, s1, s2
	la s4, patterns
	add s4, s4, s3 # s4 - pointer to start of decoded pattern
	
	li s7, 1 # loop counter
	li s8, 3 # num iterations needed
	
decode_loop:
	bgt s7, s8, end_decode_loop
	lbu s5, (s4)    # load the 8 bit pattern
	mv s6, s5
	srli s6, s6, 4  # get only first 4 bits
	sb s6, (s0)     # store in the print buffer
	addi s0, s0, 1  # advance the pointer to print buffer
	mv s6, s5
	andi s6, s6, 15 # get only the last 4 bytes
	sb s6, (s0)     # store in the print buffer
	addi s0, s0, 1  # advance the pointer to print buffer
	addi s7, s7, 1  # advance the loop counter
	addi s4, s4, 1  # advance the pointer to the next pattern byte
	j decode_loop
end_decode_loop:
	
	li s6, 0
	sb s6, (s0)
	
	li s8, STOP_CODE_INDEX
	beq s1, s8, stop_code # test if current symbol is the stop symbol
	j end_function
stop_code:
	lbu s5, (s4)    # load the 8 bit pattern
	mv s6, s5
	srli s6, s6, 4  # get only first 4 bits
	sb s6, (s0)     # store in the print buffer
end_function:
	
	lw a0, (sp)
	addi sp, sp, 4
	
        lw ra, (sp)
	addi sp, sp, 4
	jr ra

# ============================================================================
read_bmp:
# description: 
#	reads the contents of a bmp file into memory
# arguments:
#	none
# return value: none
	addi sp, sp, -4
	sw ra, (sp)
#open file
	li a7, 1024
        la a0, source_image		#file name 
        li a1, 0		#flags: 0-read file
        ecall
	mv s1, a0      # save the file descriptor
	
	# check for errors
	li s10, -1
	bne s1, s10, no_error_open_bmp # if the file descriptor!=-1 - continue
	# display error message
	li a7, SYS_PRINT_STRING
	la a0, error_open_bmp_file
	ecall
	# close program
	li a7, SYS_EXIT
	ecall
	no_error_open_bmp:

#read file
	li a7, 63
	mv a0, s1
	la a1, image
	li a2, BMP_FILE_SIZE
	ecall

#close file
	li a7, 57
	mv a0, s1
        ecall
	
        lw ra, (sp)
	addi sp, sp, 4
	jr ra

# ============================================================================
save_bmp:
#description: 
#	saves bmp file stored in memory to a file
#arguments:
#	none
#return value: none
	addi sp, sp, -4
	sw ra, (sp)
#open file
	li a7, 1024
        la a0, result_image		#file name 
        li a1, 1		#flags: 1-write file
        ecall
	mv s1, a0      # save the file descriptor
	
	#check for errors
	li s10, -1
	bne s1, s10, no_error_save_bmp # if the file descriptor!=-1 - continue
	# display error message
	li a7, SYS_PRINT_STRING
	la a0, error_save_bmp_file
	ecall
	# close program
	li a7, SYS_EXIT
	ecall
	no_error_save_bmp:

#save file
	li a7, 64
	mv a0, s1
	la a1, image
	li a2, BMP_FILE_SIZE
	ecall

#close file
	li a7, 57
	mv a0, s1
        ecall
	
        lw ra, (sp)
	addi sp, sp, 4
	jr ra

# ============================================================================
put_pixel:
#description: 
#	sets the color of specified pixel
#arguments:
#	a0 - x coordinate
#	a1 - y coordinate - (0,0) - bottom left corner
#	a2 - 0RGB - pixel color
#return value: none
	addi sp, sp, -4
	sw ra, (sp)
	
	addi sp, sp, -4
	sw a0, (sp)
	
	addi sp, sp, -4
	sw t0, (sp)
	
	addi sp, sp, -4
	sw t1, (sp)
	
	addi sp, sp, -4
	sw t2, (sp)
	
	addi sp, sp, -4
	sw t3, (sp)
	
	addi sp, sp, -4
	sw t4, (sp)

	la t1, image	#adress of file offset to pixel array
	addi t1,t1,10
	lw t2, (t1)		#file offset to pixel array in $t2
	la t1, image		#adress of bitmap
	add t2, t1, t2	#adress of pixel array in $t2
	
	#pixel address calculation
	li t4,BYTES_PER_ROW
	mul t1, a1, t4 #t1= y*BYTES_PER_ROW
	mv t3, a0		
	slli a0, a0, 1
	add t3, t3, a0	#$t3= 3*x
	add t1, t1, t3	#$t1 = 3x + y*BYTES_PER_ROW
	add t2, t2, t1	#pixel address 
	
	#set new color
	sb a2,(t2)		#store B
	srli a2,a2,8
	sb a2,1(t2)		#store G
	srli a2,a2,8
	sb a2,2(t2)		#store R

	lw t4, (sp)
	addi sp, sp, 4
	
	lw t3, (sp)
	addi sp, sp, 4

	lw t2, (sp)
	addi sp, sp, 4

	lw t1, (sp)
	addi sp, sp, 4
	
	lw t0, (sp)
	addi sp, sp, 4

        lw a0, (sp)
	addi sp, sp, 4

        lw ra, (sp)
	addi sp, sp, 4
	jr ra
