
# mp1.S - missile-command version
# Good luck, and have fun!

.data
	
    # Constants for accessing the fields of a struct missile, 
    # struct missile is defined in rtc.h and mp1.h

	NEXT 	  = 0
	X	  = 4
	Y	  = 8
	VX	  = 12
	VY	  = 16
	DEST_X	  = 20
	DEST_Y	  = 24
	EXPLODED  = 28
	C	  = 32

    # Character to draw for an explosion - '@'

	EXPLOSION = 64


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:	.long 0x0	# Head of list pointer
base_alive:		.long 0x0	# Array of 3 bytes, plus a padding byte
mp1_score:		.long 0x0	# Player's current score


# Data private to this  file

base_pic:     	    .string "/^^^\\"	# Picture of a live base
dead_base_pic: 	    .string "xxxxx"	# Picture of a dead base
crosshairs_x:		.long 0x0	# X-position of the crosshairs
crosshairs_y:		.long 0x0	# Y-position of the crosshairs

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
		movl    vmem_base_addr(,1),%edx  #
		movb    %cl,(%edx,%eax,1)
		ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#	(1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#	(2) Redraw the bases - they may have been overwritten with missiles
#	(3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
# start the stack frame
  pushl %ebp
  movl %esp, %ebp
# Protect callee saved registers
pushl %ebx 
pushl %esi 
pushl %edi

    
    call update_missiles # all the changed to the state of the missiles should be achieved here (3 steps on page 1)
	call redraw_cities # that is the second step which is redraw cities
	call redraw_crosshairs
# poping out all the value to make sure there is no leak
	    popl %edi
		popl %esi
		popl %ebx	
		ret

update_cities
redraw_cities
redraw_crosshairs

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
mp1_ioctl:
    movl 8(%esp), %eax # we need to first load in ebx parameter arg


	cpml $0, %eax # smaller than 0
	jg error_cmd

    cpml $4, %eax # bigger than 4
	jl error_cmd 

	jmp *jumptable(,%eax,4)

error_cmd 
    movl $-1, %eax

	ret


jumptable:
		.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame

	


# ----------------- Functions private to this file -------------------
update_missiles:
        pushl		%ebp
		movl		%esp, %ebp
		pushl		%ebx
		pushl		%esi
		pushl		%edi
		movl mp1_missile_list, %ebx
		
		# this remove missile if it goes out of boundary or update the status of the missile
		missile_trace:
        cmpl $0, %ebx 
		je end_update

# check if the missile have go out of boundary if it is jump to mp1 missile remove
        movl		X(%ebx), %eax
		roll		$16, %eax
		andl		$0x0000ffff, %eax  
		cmpl		$0, %eax
		jl			missile_remove
		cmpl        $79, X(%edx)
		jg          missile_remove
		movl		Y(%ebx), %ecx
	    roll		$16, %ecx
		andl		$0x0000ffff, %ecx
		cmpl		$0, %ecx
		jl          missile_remove
		cmpl        $24, %ecx
		jg          missile_remove

# check if the missile is exploding if yes then jump to missile explosion
        addl EXPLODED(%ebx),%esi
        cmpl		$0,%esi 
		jne			missile_explosion
        

# check if the missile reach the destination of itself
      movl		X(%ebx), %eax
	  roll		$16, %eax
	  andl		$0x0000ffff, %eax 
	  movl		Y(%ebx), %ecx
	  roll		$16, %ecx
      andl		$0x0000ffff, %ecx
	  cmpl		%eax, DEST_X(%edx)
	  je checklist_y
	  jmp missile_safe

	  checklist_y:
	  cmpl		%ecx, DEST_Y(%edx)
	  je start_to_explode
      jmp missile_safe

start_to_explode:
	  pushl		%ebx
      call		missile_explode
	  popl		%ebx
	  cmpl		$0, %eax
	  call		missile_explode
	  popl		%edx
	  cmpl		$0, %eax
	  je	    missile_explosion
	  pushl		%edx
	  call		mp1_notify_user
	  popl		%edx
	  jmp missile_explosion  # ?
# now we know our missile is safe but it will be moving so we will update out missile position or we will unchange when it is exploding
missile_safe:
      jmp change_x_y
missile_explosion:
     subl		$1, EXPLODED(%ebx)
	 # cmpl		$0, EXPLODED(%ebx) # ?
	 je missile_remove
        movl		$0, VX(%edx)  # clear vx and vy
		movl		$0, VY(%edx)
		movl		X(%ebx), %eax
		roll		$16, %eax
		andl		$0x0000ffff, %eax
		movl		Y(%ebx), %ecx
		roll		$16, %ecx
		andl		$0x0000ffff, %ecx
		

		imull		$2, %eax
		imull		$160, %ecx
		addl		%ecx, %eax

		pushl		%ebx
	    call		mp1_notify_user
	    popl		%ebx
		movb		$EXPLOSION, %cl
		pushl		%edx
		call		mp1_poke
		popl		%edx

        jmp			fetch_next_missile
		# now this one is for those that have changed their x_y position we need to update is and 
change_x_y:
		movl		X(%ebx), %eax
		movl		Y(%ebx), %ecx
		roll		$16, %eax
		roll		$16, %ecx
		andl		$0x0000ffff, %eax
		andl		$0x0000ffff, %ecx
		imull		$2, %eax
		imull		$160, %ecx

		addl		%ecx, %eax
		movb		$32, %cl
		pushl		%edx
		call		mp1_poke
		popl		%edx

		movl		X(%ebx), %eax
		addl VX(%ebx), %eax
		addl %eax, X(%ebx)
        movl		Y(%ebx), %eCx
		addl VY(%ebx), %ecx
		addl %ecx, Y(%ebx)
		
		movl		X(%edx), %eax
		movl		Y(%edx), %eCx
		roll		$16, %eax		
		roll		$16, %ecx
		andl		$0x0000ffff, %eax
		andl		$0x0000ffff, %ecx
		imull		$2, %eax
		imull		$160, %ecx
		addl		%ecx, %eax
		addl		%ecx, %eax

		movb		C(%ebx), %cl
		pushl		%edx
		call		mp1_poke
		popl		%edx
		jmp			fetch_next_missile
# this is the case where the missile don't exist on the list
missile_remove:
        # remove the missile from screen
		movl		X(%ebx), %eax
		roll		$16, %eax
		andl		$0x0000ffff, %eax
		movl		Y(%ebx), %ecx
		roll		$16, %ecx
		andl		$0x0000ffff, %esi

		imull		$2, %eax
		imull		$160, %esi
		addl		%esi, %eax

		movb		$32, %cl
		pushl		%edx
		call		mp1_poke
		popl		%edx
        # remove the linked list
		pushl		%eax
		pushl		%ecx
		pushl		%edx
		call		mp1_missile_remove
		addl		$4, %esp
		popl		%ecx
		popl		%eax
		jmp fetch_next_missile
end_update:
		popl		%edi
		popl		%esi
		popl		%ebx
		leave
		ret 
mp1_missile_remove:
        pushl		%ebp
		movl		%esp, %ebp

		pushl		%ebx
		pushl		%esi
		pushl		%edi

		addl %ebx, %esi # copy the pointer to have reference
        movl mp1_missile_list, %edi
        cmpl $0, %edi	
		jmp end_update
		cmpl %esi, %edi
		jne more_steps
		movl		$0, NEXT(%ebx), %ebp
		movl		%ebp, mp1_missile_list
		pushl		%ebx
		call		mp1_free
		addl		$4, %esp
		popl		%eax 
		movl		%ebp, %ebx 
		movl		%ebx, mp1_missile_list
		jmp removal_complete

		more_steps:
		cmpl		$0, %esi
		je removal_complete
		cmpl		NEXT(%edi), %esi
		je find_its_before
		movl NEXT(%edi), %edi
		jmp more_steps

		find_its_before:
		movl		$0, NEXT(%ebx)
        movl		NEXT(%ebx), %ebp
		pushl		%eax
        
		pushl		%ebx
		call		mp1_free
		addl		$4, %esp
		popl		%eax
		movl		%edi, NEXT(%esi)
        movl %ebp, %ebx

removal_complete:
		popl		%edi
		popl		%esi
		popl		%ebx
		leave
		ret



redraw_cities: 
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi
		movl $3840, %ebx #bottom most row has offset 3840 bytes
		movl $36, %esi  #first character in column 18 (18*2 bytes offset)
		xorl %edx, %edx
		movl base_alive, %edi
		andl $0x00000001, %edi #bitmask for first city byte
		cmpl $0, %edi
		je first_base_dead #draw city 1 dead if 0
first_base_alive:		
		movl %ebx, %eax
		addl %esi, %eax  
		movb base_pic(,%edx,1), %cl #move character draw into cl (edx shifts the character to draw by one each loop)
		pushl %edx
		call mp1_poke
		popl %edx
		addl $2, %esi #move to next offset location (2 bytes) for column, no change in x because still bottom row
		incl %edx
		cmpl $5, %edx #bases have 5 characters
		jl first_base_alive #if count<5, keep drawing, else go on to second base
		jmp second_base
first_base_dead:
		movl %ebx, %eax
		addl %esi, %eax  
		movb dead_base_pic(,%edx,1), %cl #move character into cl
		pushl %edx
		call mp1_poke
		popl %edx
		addl $2, %esi 
		incl %edx
		cmpl $5, %edx #bases have 5 characters
		jl first_base_dead #if count<5, keep drawing, else go on to second base
second_base:
		movl $3840, %ebx #bottom most row has offset 3840 bytes
		movl $76, %esi #first character in column 38 (38*2 bytes offset)
		xorl %edx, %edx
		movl base_alive, %edi
		andl $0x00000100, %edi #bitmask for second city byte
		cmpl $0, %edi
		je second_base_dead #draw city 2 dead if 0
second_base_alive:
		movl %ebx, %eax
		addl %esi, %eax
		movb base_pic(,%edx,1), %cl
		pushl %edx
		call mp1_poke
		popl %edx
		addl $2, %esi
		incl %edx
		cmpl $5, %edx #bases have 5 characters
		jl second_base_alive #if count<5, keep drawing, else go on to third base
		jmp third_base 
second_base_dead:
		movl %ebx, %eax
		addl %esi, %eax  
		movb dead_base_pic(,%edx,1), %cl 
		pushl %edx
		call mp1_poke
		popl %edx
		addl $2, %esi 
		incl %edx
		cmpl $5, %edx
		jl second_base_dead #if count<5, keep drawing, else go on to third base
third_base:
		movl $3840, %ebx #bottom most row has offset 3840 bytes
		movl $116, %esi #first character in column 58 (58*2 bytes offset)
		xorl %edx, %edx
		movl base_alive, %edi
		andl $0x00010000, %edi #bitmask for third city byte
		cmpl $0, %edi
		je third_base_dead #draw city 3 dead if 0
third_base_alive:
		movl %ebx, %eax
		addl %esi, %eax
		movb base_pic(,%edx,1), %cl
		pushl %edx 
		call mp1_poke
		popl %edx
		addl $2, %esi
		incl %edx
		cmpl $5, %edx
		jl third_base_alive #if count<5 keep drawing, otherwise wrap up and return
		jmp city_draw_return
third_base_dead:
		movl %ebx, %eax
		addl %esi, %eax  
		movb dead_base_pic(,%edx,1), %cl 
		pushl %edx
		call mp1_poke
		popl %edx
		addl $2, %esi
		incl %edx
		cmpl $5, %edx
		jl third_base_dead #if count<5, keep drawing,else wrap up and return
city_draw_return:
		popl %edi
		popl %esi
		popl %ebx
		leave
		ret



update_crosshairs:
# Set up the stack frame
		pushl		%ebp
		movl		%esp, %ebp
		
		# Protect the callee saved registers
		pushl		%ebx
		pushl		%esi
		pushl		%edi
		
		
		movl		crosshairs_x, %eax
		movl		crosshairs_y, %ebx
		imull		$2, %eax
		imull		$160, %ebx

		
		addl		%ebx, %eax
		movb		$43, %cl
		call		mp1_poke

	
		popl		%ebx
		popl		%esi
		popl		%edi
		leave
		ret


    
		ret


# crosshair in the middle : (40,12)
# vx = 0, vy = 0
mp1_ioctl_startgame:
    # start the stack frame.
    pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	pushl %esi
	pushl %edi

	# initialize all the global variable in mp1
	# mp1_missile_list:	.long 0x0	# Head of list pointer
# base_alive:		.long 0x0	# Array of 3 bytes, plus a padding byt
# mp1_score:		.long 0x0	# Player's current score


# Data private to this  file

# base_pic:     	    .string "/^^^\\"	# Picture of a live base
# dead_base_pic: 	    .string "xxxxx"	# Picture of a dead base
# crosshairs_x:		.long 0x0	# X-position of the crosshairs
# crosshairs_y:		.long 0x0	# Y-position of the crosshairs
    
	# load in the initial value of the crosshair
	movl $0, mp_1missile_list 
	movl $0x00010101, base_alive
	movl $0, mp1_score
	movl $40, crosshairs_x
    movl $12, crosshairs_y
 	
	 
	# restore stack; 
	# Q: we save everytime for restore but is it always necessary or just in case. 
	popl %edi
	popl %esi
	popl %ebx
	leave
		ret

# this part of the code intended to add the user's missile to the platform
mp1_ioctl_addmissile:
    # start the stack frame
		pushl		%ebp
		movl		%esp, %ebp
		
	
		pushl		%ebx
		pushl		%esi
		pushl		%edi
		 
		# load in the parameter
        movl 8(%ebp), %ebx
		movl $33, %ecx # leave out the space for the 33 bytes for a missle ecx has the number needed for mp1_malloc
		pushl %eax
		pushl %ecx
		call mp1_malloc # could it be _malloc?
		cmpl $0 %eax 
		jne malloc_failed_cases
		popl %ecx # restore contents of ecx
        popl %eax

        pushl		%ecx
		pushl		%ebx	
		pushl		%eax
        
		call mp1_copy_from_user
		cmpl $0 %eax
		jne copy_failed_cases

		popl		%eax
		popl		%ebx
		popl		%ecx # restore the value of the three register
		pushl %edi
		movl mp1_missile_list, %edi
		movl %edi, NEXT(%eax)
		movl %eax, mp1_missile_list
		movl $0, %eax
		popl %edi

 

	    movl		$0, %eax
		# restore
		popl		%edi
		popl		%esi
		popl		%ebx
		leave
		  
		ret
     
        malloc_failed_cases:
		movl $-1, %eax
        popl		%edi
		popl		%esi
		popl		%ebx
		leave
		ret

		copy_failed_cases:
		popl		%eax
		popl		%ebx
		popl		%ecx

		pushl		%eax
		call mp1_free
		popl %eax
        popl		%edi
		popl		%esi
		popl		%ebx
		leave
		ret

 # how many return and leave?       

mp1_ioctl_movexhairs:
# startof the stack frame
    pushl %ebp
	movl %esp, %ebp

	# protect callee saved register
	pushl		%ebx
	pushl		%esi
	pushl		%edi

	# save the register we might use
	pushl		%eax
	pushl		%ecx
	pushl		%edx
	# check if these two are changed if yes then jump to "done_change" which is actually the whole string didn't change
	movl		8(%ebp), %ebx
	cmpl		$0, %ebx
	je			done_change

	movl		crosshairs_x, %eax
	movl		crosshairs_y, %ecx
	
	imull		$2, %eax
	imull		$160, %ecx
	addl		%ecx, %eax
	movb		$32, %cl
	call		mp1_poke


    movl $0 %eax
	movl $0 %ecx
	movl %ebx, %edi
	# fetch the high in eax which is y     # is this correct?
    sarl $16, %edi
	shll $16, %edi
	movl %eax, %eax    
	
	movl		%ebx, %edi
	# fetch the low in ecx which is x 
    shll $16, %edi
	sarl $16, %edi
	movl %eax, %ecx

    addl %eax, crosshairs_y
	addl %ecx, crosshairs_x
	# we need to check x in range? there will be four function : x_smaller x_larger y_smaller y_larger
    addl crosshairs_x, %esi
	cmpl $0, %esi
	jl x_smaller

	addl crosshairs_x, %esi
	cmpl $79, %esi
	jg x_larger

	addl crosshairs_y, %esi
	cmpl $0, %esi
	jl y_smaller

	addl crosshairs_y, %esi
	cmpl $24, %esi
	jl y_larger


    jmp			redraw_hairs
	x_smaller:
	movl		$0, crosshairs_x
	ret

	x_larger:
	movl		$79, crosshairs_x
	ret

	y_smaller:
	movl		$0, crosshairs_y
	ret

	y_larger:
    movl		$24, crosshairs_y
	ret

	# then we jump to a function called redraw_hairs
    redraw_hairs:
	movl		crosshairs_x, %eax
	movl		crosshairs_y, %ecx
	imull		$2, %eax
	imull		$160, %ecx
	addl		%ecx, %eax
	movb		$43, %cl
	call		mp1_poke

# making sure we are returning 0
    movl		$0, %eax
	leave
		ret
    done_change:
    popl		%edx
	popl		%ecx
	popl		%eax
	popl		%edi
	popl		%esi
	popl		%ebx

mp1_ioctl_getstatus:
    # Set up the stack frame
		pushl		%ebp
		movl		%esp, %ebp

		# Protect the callee saved registers
		pushl		%ebx
		pushl		%esi
		pushl		%edi

		movl		8(%ebp), %ebx
		# load in score
		movw mp1_score, %ax 
		# load in cities 1 and add it to 16 
        movl base_alive, %edi
		addl $0x00000001, %edi
		cmpl $0, %esi
		je load_2
		addl $0x00010000, %ecx
		# load in city 2 and add it to 17 jp load_2
		load_2:
		movl base_alive, %edi
		addl $0x00000010, %edi
		cmpl $0, %esi
		je load_3
		addl $0x00020000, %ecx 
		# load in city 3 and add it to 18 jp load_3
		load_3:
		movl base_alive, %edi
		addl $0x00010000, %edi
		cmpl $0, %esi
		je copy_to_user
		addl $0x00040000, %ecx 

		# copy to user space 
# copy_to_user:
        addl %edi, %ecx
		pushl		%edi
		pushl		%edx
		pushl		%ebx
		call		mp1_copy_to_user
		popl		%ebx
		popl		%edx
		popl		%edi
        
		cmpl		$0, %eax
		jne		copy_to_user_fail
		
return_state:		
		popl %edi
		popl %esi
		popl %ebx
		leave
		ret
copy_to_user_fail:
        
		pushl		%edx
		call	mp1_free
		popl		%edx
		
		
		movl		$-1, %eax

				
		popl		%edi
		popl		%esi
		popl		%ebx
		leave
		ret
mp1_ioctl_endgame:
    pushl		%ebp
	movl		%esp, %ebp
    
	pushl		%ebx
	pushl		%esi
	pushl		%edi


# getting in loop to clean all the missile struct elements(linked list that is why we need a loop)
   
    clean_missile_list:
    movl		mp1_missile_list, %ebx
	addl %ebx, %eax
	cmpl $0, %ebx
	je finish_clean
	pushl		%ebx
	call		mp1_free
	popl		%ebx
    cmpl		$0, NEXT(%ebx)	
	jne clean_missile_list

finish_clean:
        popl		%edi
		popl		%esi
		popl		%ebx
		leave
		ret
