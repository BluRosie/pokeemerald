#include "config.h"
	.include "asm/macros.inc"
	.include "constants/gba_constants.inc"

#ifdef FLASH_ROM_CHANGES

	.text

	.syntax unified

	.thumb

	.align 2, 0
	thumb_func_start Task_ClearSaveData_fillSramWithFF
Task_ClearSaveData_fillSramWithFF:
	push {r0-r5, lr}
	ldr r0, =0x0E000004
	ldr r1, =0x0E010004
	subs r0, r0, #4
	subs r1, r1, #4
	movs r3, #0xFF
_loop_clearsavedata:
	strb r3, [r0]
	adds r0, r0, #1
	cmp r0, r1
	bne _loop_clearsavedata
	movs r4, #1 @ believe this is a signal to erase everything
	ldr r0, =DisableInterruptsAndLoadFlashCodeToRam
	bx r0

ReturnFromTaskClearSaveData:
	pop {r0-r5}
@	pop {r4}
	pop {r0}
	bx r0

	thumb_func_end Task_ClearSaveData_fillSramWithFF


	non_word_aligned_thumb_func_start SaveNormalFlashChunk
SaveNormalFlashChunk:
	push {lr}
	movs r4, #0
	ldr r1, =DisableInterruptsAndLoadFlashCodeToRam
	bx r1

ReturnFromSaveNormalFlashChunk:
@	pop {r4-r7}
	pop {r1}
	bx r1


.align 2
.pool

	thumb_func_end SaveNormalFlashChunk

.align 4

.arm

arm_func_start DisableInterruptsAndLoadFlashCodeToRam
DisableInterruptsAndLoadFlashCodeToRam:
	stmfd sp!, {r0-r7}
	ldr r0, =REG_IME
	ldr r1, =__ewram_register_space
	ldrh r2, [r0]
	strh r2, [r1]
	ldr r0, =REG_IE
	ldr r1, =__ewram_register_space + 2
	ldrh r2, [r0]
	strh r2, [r1], #2
	mov r0, #REG_BASE
	ldrh r2, [r0, #OFFSET_REG_SOUNDCNT_H]
	strh r2, [r1], #2
	ldrh r2, [r0, #OFFSET_REG_SOUNDCNT_L]
	strh r2, [r1], #2
	ldrh r2, [r0, #OFFSET_REG_DMA0CNT_H]
	strh r2, [r1], #2
	ldrh r2, [r0, #OFFSET_REG_DMA1CNT_H]
	strh r2, [r1], #2
	ldrh r2, [r0, #OFFSET_REG_DMA2CNT_H]
	strh r2, [r1], #2
	ldrh r2, [r0, #OFFSET_REG_DMA3CNT_H]
	strh r2, [r1], #2
	mov r0, #0
	ldr r1, =REG_IME
	strh r0, [r1]
	ldr r1, =REG_IE
	strh r0, [r1]
	mov r1, #REG_BASE
	strh r0, [r1, #OFFSET_REG_SOUNDCNT_L]
	strh r0, [r1, #OFFSET_REG_DMA0CNT_H]
	strh r0, [r1, #OFFSET_REG_DMA1CNT_H]
	strh r0, [r1, #OFFSET_REG_DMA2CNT_H]
	strh r0, [r1, #OFFSET_REG_DMA3CNT_H]
	mov r0, #3
	strh r0, [r1, #OFFSET_REG_SOUNDCNT_H]
	ldr r0, =REG_SOUNDCNT_X
	ldrh r1, [r0]
	b LoadCodeToRAMAndExecute

ReturnFromFlashCodeInRAM:
	ldr r0, =REG_IME
	ldr r1, =__ewram_register_space
	ldrh r2, [r1]
	strh r2, [r0]
	ldr r0, =REG_IE
	ldr r1, =__ewram_register_space + 2
	ldrh r2, [r1], #2
	strh r2, [r0]
	mov r0, #REG_BASE
	ldrh r2, [r1], #2
	strh r2, [r0, #OFFSET_REG_SOUNDCNT_H]
	ldrh r2, [r1], #2
	strh r2, [r0, #OFFSET_REG_SOUNDCNT_L]
	ldrh r2, [r1], #2
	strh r2, [r0, #OFFSET_REG_DMA0CNT_H]
	ldrh r2, [r1], #2
	strh r2, [r0, #OFFSET_REG_DMA1CNT_H]
	ldrh r2, [r1], #2
	strh r2, [r0, #OFFSET_REG_DMA2CNT_H]
	ldrh r2, [r1], #2
	strh r2, [r0, #OFFSET_REG_DMA3CNT_H]
	ldmfd sp!, {r0-r7}
	cmp r4, #1
	beq _taskClearSaveDataReturn
	ldr r1, =ReturnFromSaveNormalFlashChunk+1
	bx r1

_taskClearSaveDataReturn:
	ldr r0, =ReturnFromTaskClearSaveData+1
	bx r0

.align 2
.pool
arm_func_end DisableInterruptsAndLoadFlashCodeToRam

.align 2

LoadCodeToRAMAndExecute:
	ldr r0, ewramCodeAddress
	ldr r1, =DetermineFlashType
	ldr r2, =endOf_DetermineFlashType

_loadCodeToEwram:
	ldr r3, [r1]
	str r3, [r0]
	add r1, r1, #4
	add r0, r0, #4
	cmp r1, r2
	bne _loadCodeToEwram
	ldr r0, ewramCodeAddress
	bx r0


DetermineFlashType:
	ldr r0, =0xF0F0
	ldr r1, =0x08000154
	strh r0, [r1]
	ldr r0, =0x9898
	strh r0, [r1]
	ldr r0, =0x08000040
	ldrh r1, [r0]
	ldr r2, =0x5152
	cmp r1, r2
	bne _5152_check_fail
	ldr r0, =0xF0F0
	mov r1, #0x08000000
	strh r0, [r1]
	mov r0, #0
	b handle_type_r0_sw

_5152_check_fail:
	mov r0, #0x08000000
	mov r1, #0xFF
	strh r1, [r0]
	nop
	mov r1, #0x50
	strh r1, [r0]
	nop
	mov r1, #0x90
	strh r1, [r0]
	nop
	mov r2, #8

_8A_check_loop:
	ldrh r1, [r0]
	cmp r1, #0x8A
	beq _8A_check_success
	subs r2, r2, #1
	bne _8A_check_loop
	cmp r1, #0x89
	beq _status_89
	mov r0, #0x08000000
	mov r1, #0xF0
	strh r1, [r0]
	mov r0, #2
	b handle_type_r0_sw

_8A_check_success:
	mov r0, #0x08000000
	mov r1, #0xFF
	strh r1, [r0]
	nop
	mov r1, #0x90
	strh r1, [r0]
	nop
	mov r0, #0x08000000
	add r0, r0, #0x2
	ldrh r1, [r0]
	ldr r2, =0x8815
	cmp r1, r2
	bne _8815_check_failed
	mov r1, #0xFF
	strh r1, [r0]
	mov r0, #3
	b handle_type_r0_sw

_8815_check_failed:
	ldr r2, =0x887D
	cmp r1, r2
	bne _887D_failed
_88B0_success:
	subs r0, r0, #2
	mov r6, #0
	mov r1, #0xFF
	strh r1, [r0]
	mov r0, #1
	b handle_type_r0_sw

_887D_failed:
	ldr r2, =0x88B0
	cmp r1, r2
	beq _88B0_success
	mov r1, #0xF0
	strh r1, [r0]
	mov r0, #0

handle_type_r0_sw:
	ldr r1, =HandleFlashChipType
	bx r1

_status_89:
	mov r6, #0xFF
	mov r1, #0xFF
	strh r1, [r0]
	mov r0, #1
	b handle_type_r0_sw

HandleFlashChipType:
	cmp r0, #0
	beq _gotoType0
	cmp r0, #1
	beq _gotoType1
	cmp r0, #2
	beq _gotoType2
	cmp r0, #3
	beq _gotoType3

_gotoType0:
    b _handleType0

_gotoType1:
    b _handleType1

_gotoType2:
    b _handleType2

_gotoType3:
    b _handleType3

ewramCodeAddress:
	.word __ewram_code_space

.pool

endOf_DetermineFlashType:
	nop

_handleType0:
	ldr r0, ewramCodeAddress
	ldr r1, =HandleFlashType0
	ldr r2, =endOf_HandleFlashType0

_loop_handleFlashType0:
	ldr r3, [r1]
	str r3, [r0]
	add r1, r1, #4
	add r0, r0, #4
	cmp r1, r2
	bne _loop_handleFlashType0
	ldr r0, ewramCodeAddress
	bx r0

HandleFlashType0:
	mov r2, #0xFC
	mov r2, r2, lsl#16
	mov r0, #0x08000000
	orr r2, r2, r0 @ __rom_save_space
	ldr r0, =0x08001554
	ldr r1, =0x08000AAA
	ldr r4, =0xAAA9
	ldr r5, =0x5556
	ldr r3, =0xF0F1
	subs r3, r3, #1
	strh r3, [r2]
	strh r4, [r0]
	strh r5, [r1]
	ldr r3, =0x8080
	strh r3, [r0]
	strh r4, [r0]
	strh r5, [r1]
	ldr r3, =0x3030
	strh r3, [r2]
	bl FlashType0_MakeWriteable
	ldr r3, =0xF0F2
	subs r3, r3, #2
	strh r3, [r2]
	strh r4, [r0]
	strh r5, [r1]
	ldr r3, =0x2020
	strh r3, [r0]
	bl FlashType0_TransferSRAMToSaveSpace
	ldr r3, =0xF0F3
	subs r3, r3, #3
	strh r3, [r2]
	ldr r0, =ReturnFromFlashCodeInRAM
	bx r0


@ r2 = start of save space
FlashType0_MakeWriteable:
	stmfd sp!, {lr}
	mov r3, #0x100000 @ delay constant

FlashType0_MakeWriteable_loop1:
	subs r3, r3, #1
	beq FlashType0_MakeWriteable_nextStep
	ldrh r6, [r2]
	tst r6, #0x8000
	bne FlashType0_MakeWriteable_nextStep
	tst r6, #0x2000
	beq FlashType0_MakeWriteable_loop1
	ldrh r6, [r2]
	tst r6, #0x8000
	beq FlashType0_MakeWriteable_loop1

FlashType0_MakeWriteable_nextStep:
	mov r3, #0x100000 @ delay constant

FlashType0_MakeWriteable_loop2:
	subs r3, r3, #1
	beq FlashType0_MakeWriteable_return
	ldrh r6, [r2]
	tst r6, #0x80
	bne FlashType0_MakeWriteable_return
	tst r6, #0x20
	beq FlashType0_MakeWriteable_loop2
	ldrh r6, [r2]
	tst r6, #0x80
	beq FlashType0_MakeWriteable_loop2

FlashType0_MakeWriteable_return:
	ldmfd sp!, {lr}
	mov pc, lr @ possibly ret


@ r2 = save space
FlashType0_TransferSRAMToSaveSpace::
	stmfd sp!, {r2, lr}
	mov r1, #0x0E000000 @ sram space
	mov r3, #0x10
	mov r3, r3, lsl#12 @ save size 0x10000

FlashType0_TransferSRAMToSaveSpace_loop:
	ldrb r6, [r1], #1
	ldrb r7, [r1], #1
	orr r6, r6, r7, lsl#8 @ grab halfword and convert to big endian in r6
	ldr r5, =0xA0A0
	strh r5, [r2]
	nop
	strh r6, [r2]
	mov r0, #0x100

FlashType0_TransferSRAMToSaveSpace_confirmWrite:
	ldrh r7, [r2]
	cmp r6, r7
	beq FlashType0_TransferSRAMToSaveSpace_nextWrite
	subs r0, r0, #1
	bne FlashType0_TransferSRAMToSaveSpace_confirmWrite

FlashType0_TransferSRAMToSaveSpace_nextWrite:
	add r2, r2, #2
	subs r3, r3, #2
	bne FlashType0_TransferSRAMToSaveSpace_loop @ more bytes to go
	ldmfd sp!, {r2, lr}
	mov pc, lr @ possibly ret

.pool

endOf_HandleFlashType0:
	nop

_handleType2:
	ldr r0, ewramCodeAddress
	ldr r1, =HandleFlashType2
	ldr r2, =endOf_HandleFlashType2

_loop_handleFlashType2:
	ldr r3, [r1]
	str r3, [r0]
	add r1, r1, #4
	add r0, r0, #4
	cmp r1, r2
	bne _loop_handleFlashType2
	ldr r0, ewramCodeAddress
	bx r0

HandleFlashType2:
	mov r2, #0xFC
	mov r2, r2, lsl#16
	mov r0, #0x08000000
	orr r2, r2, r0
	ldr r0, =0x08000AAD
	subs r0, r0, #3
	ldr r1, =0x08000554
	mov r4, #0xA9
	mov r5, #0x56
	bl FlashType2_WriteHWordsToStatus
	strh r4, [r0]
	strh r5, [r1]
	mov r3, #0x80
	strh r3, [r0]
	strh r4, [r0]
	strh r5, [r1]
	mov r3, #0x30
	strh r3, [r2]
	bl FlashType2_MakeWriteable
	bl FlashType2_WriteHWordsToStatus
	strh r4, [r0]
	strh r5, [r1]
	mov r3, #0x20
	strh r3, [r0]
	bl FlashType2_TransferSRAMToSaveSpace
	mov r3, #0x90
	strh r3, [r2]
	mov r3, #0
	strh r3, [r2]
	bl FlashType2_WriteHWordsToStatus
	ldr r0, =ReturnFromFlashCodeInRAM+3
	subs r0, r0, #3
	bx r0


FlashType2_WriteHWordsToStatus:
	stmfd sp!, {lr}
	strh r4, [r0]
	strh r5, [r1]
	mov r3, #0xF0
	strh r3, [r2]
	ldmfd sp!, {lr}
	mov pc, lr


FlashType2_TransferSRAMToSaveSpace:
	stmfd sp!, {r0-r5, lr}
	mov r1, #0x0E000000
	mov r3, #0x10
	mov r3, r3, lsl#0xC @ save size 0x10000

FlashType2_TransferSRAMToSaveSpace_loop:
	ldrb r6, [r1], #1
	ldrb r7, [r1], #1
	orr r6, r6, r7, lsl#8
	mov r5, #0xA0
	strh r5, [r2]
	nop
	strh r6, [r2]
	mov r0, #0x100

FlashType2_TransferSRAMToSaveSpace_compareAttempts:
	ldrh r7, [r2]
	cmp r6, r7
	beq FlashType2_TransferSRAMToSaveSpace_finalStep
	subs r0, r0, #1
	bne FlashType2_TransferSRAMToSaveSpace_compareAttempts

FlashType2_TransferSRAMToSaveSpace_finalStep:
	add r2, r2, #2
	subs r3, r3, #2
	bne FlashType2_TransferSRAMToSaveSpace_loop
	ldmfd sp!, {r0-r5, lr}
	mov pc, lr


FlashType2_MakeWriteable:
	stmfd sp!, {r2, lr}
	mov r3, #0x100000 @ delay constant

FlashType2_MakeWriteable_loop:
	subs r3, r3, #1
	beq FlashType2_MakeWriteable_end
	ldrh r6, [r2]
	tst r6, #0x80
	bne FlashType2_MakeWriteable_end
	tst r6, #0x20
	beq FlashType2_MakeWriteable_loop
	ldrh r6, [r2]
	tst r6, #0x80
	beq FlashType2_MakeWriteable_loop

FlashType2_MakeWriteable_end:
	ldmfd sp!, {r2, lr}
	mov pc, lr

.pool

endOf_HandleFlashType2:
	nop

_handleType1:
	ldr r0, ewramCodeAddress
	ldr r1, =HandleFlashType1
	ldr r2, =endOf_HandleFlashType1

_loop_handleFlashType1:
	ldr r3, [r1]
	str r3, [r0]
	add r1, r1, #4
	add r0, r0, #4
	cmp r1, r2
	bne _loop_handleFlashType1
	ldr r0, ewramCodeAddress
	bx r0


HandleFlashType1:
	mov r2, #0xFC
	mov r2, r2, lsl#0x10
	mov r0, #0x08000000
	orr r2, r2, r0
	bl FlashType1_MakeWriteable
	mov r5, #0x0E000000
	mov r3, #0x10 @ save size 0x10000
	mov r3, r3, lsl#0xC
	bl FlashType1_TransferSRAMToSaveSpace
	ldr r0, =ReturnFromFlashCodeInRAM+1
	subs r0, r0, #1
	bx r0


FlashType1_TransferSRAMToSaveSpace:
	stmfd sp!, {lr}
FlashType1_TransferSRAMToSaveSpace_restart:
	mov r0, #0xFF
	strh r0, [r2]
	nop
	mov r0, #0x70
	strh r0, [r2]
	nop

FlashType1_TransferSRAMToSaveSpace_loopUntilGood:
	ldrb r0, [r2]
	and r0, r0, #0xFF
	cmp r0, #0x80
	bne FlashType1_TransferSRAMToSaveSpace_loopUntilGood
	mov r0, #0xFF
	strh r0, [r2]
	nop
	cmp r6, #0 @ FF or 00 within type 1 as detected above
	beq FlashType1_TransferSRAMToSaveSpace_EAOverE9
	mov r0, #0xE9
	b FlashType1_TransferSRAMToSaveSpace_PostEA

FlashType1_TransferSRAMToSaveSpace_EAOverE9:
	mov r0, #0xEA

FlashType1_TransferSRAMToSaveSpace_PostEA:
	strh r0, [r2]
	nop
	ldr r0, =0x1FF
	strh r0, [r2]
	nop
	mov r1, #0x200 @ 0x200 halfwords

FlashType1_TransferSRAMToSaveSpace_loop400AtATime:
	ldrb r0, [r5]
	add r5, r5, #1
	ldrb r7, [r5]
	add r5, r5, #1
	orr r0, r0, r7, lsl#8
	strh r0, [r2]
	add r2, r2, #2
	subs r1, r1, #1
	bne FlashType1_TransferSRAMToSaveSpace_loop400AtATime
	mov r0, #0xD0
	strh r0, [r2]
	nop

FlashType1_TransferSRAMToSaveSpace_loopUntilGood2:
	ldrb r0, [r2]
	and r0, r0, #0xFF
	cmp r0, #0x80
	bne FlashType1_TransferSRAMToSaveSpace_loopUntilGood2
	mov r4, #0x400
	subs r3, r3, r4
	bne FlashType1_TransferSRAMToSaveSpace_restart
	mov r0, #0xFF
	strh r0, [r2]
	ldmfd sp!, {lr}
	mov pc, lr


@ r2 = beginning of save space
FlashType1_MakeWriteable:
	stmfd sp!, {r2, lr}
	mov r0, #0xFF
	strh r0, [r2]
	nop
	mov r0, #0x60
	strh r0, [r2]
	nop
	mov r0, #0xD0
	strh r0, [r2]
	nop
	mov r0, #0x90
	strh r0, [r2]
	nop
	add r2, r2, #2

FlashType1_MakeWriteable_loopUntilGood:
	ldrb r0, [r2]
	and r0, r0, #3
	bne FlashType1_MakeWriteable_loopUntilGood
	subs r2, r2, #2
	nop
	mov r0, #0xFF
	strh r0, [r2]
	nop
	mov r0, #0x20
	strh r0, [r2]
	nop
	mov r0, #0xD0
	strh r0, [r2]
	nop

FlashType1_MakeWriteable_loopUntilGood2:
	ldrb r0, [r2]
	and r0, r0, #0xFF
	cmp r0, #0x80
	bne FlashType1_MakeWriteable_loopUntilGood2
	nop
	mov r0, #0xFF
	strh r0, [r2]
	ldmfd sp!, {r2, lr}
	mov pc, lr

.pool

endOf_HandleFlashType1:
	nop


_handleType3:
	ldr r0, ewramCodeAddress
	ldr r1, =HandleFlashType3
	ldr r2, =endOf_HandleFlashType3

_loop_handleFlashType3:
	ldr r3, [r1]
	str r3, [r0]
	add r1, r1, #4
	add r0, r0, #4
	cmp r1, r2
	bne _loop_handleFlashType3
	ldr r0, ewramCodeAddress
	bx r0

HandleFlashType3:
	mov r2, #0xFC
	mov r2, r2, lsl#0x10
	mov r0, #0x08000000
	orr r2, r2, r0
	bl FlashType3_MakeWriteable
	mov r5, #0x0E000000
	mov r3, #0x10
	mov r3, r3, lsl#0xC
	bl FlashType3_TransferSRAMToSaveSpace
	ldr r0, =ReturnFromFlashCodeInRAM+6
	subs r0, r0, #6
	bx r0


@ r2 = save space
@ r3 = save size
@ r5 = sram space
FlashType3_TransferSRAMToSaveSpace:
	stmfd sp!, {lr}

FlashType3_TransferSRAMToSaveSpace_restart:
	mov r0, #0xFF
	strh r0, [r2]
	nop
	mov r0, #0x70
	strh r0, [r2]
	nop

FlashType3_TransferSRAMToSaveSpace_loopUntilGood:
	ldrb r0, [r2]
	and r0, r0, #0xFF
	cmp r0, #0x80
	bne FlashType3_TransferSRAMToSaveSpace_loopUntilGood
	mov r0, #0xFF
	strh r0, [r2]
	nop
	mov r0, #0x40
	strh r0, [r2]
	ldrb r6, [r5]
	add r5, r5, #1
	ldrb r7, [r5]
	add r5, r5, #1
	orr r6, r6, r7, lsl#8
	strh r6, [r2]

FlashType3_TransferSRAMToSaveSpace_loopUntilGood2:
	ldrb r0, [r2]
	and r0, r0, #0xFF
	cmp r0, #0x80
	bne FlashType3_TransferSRAMToSaveSpace_loopUntilGood2
	add r2, r2, #2
	subs r3, r3, #2
	bne FlashType3_TransferSRAMToSaveSpace_restart
	mov r0, #0xFF
	strh r0, [r2]
	ldmfd sp!, {lr}
	mov pc, lr


@ r2 = save space
FlashType3_MakeWriteable:
	stmfd sp!, {r2, lr}
	mov r0, #0xFF
	strh r0, [r2]
	nop
	mov r0, #0x60
	strh r0, [r2]
	nop
	mov r0, #0xD0
	strh r0, [r2]
	nop
	mov r0, #0x90
	strh r0, [r2]
	nop
	add r2, r2, #2

FlashType3_MakeWriteable_loop:
	ldrb r0, [r2]
	and r0, r0, #3
	bne FlashType3_MakeWriteable_loop
	subs r2, r2, #2
	nop
	mov r0, #0xFF
	strh r0, [r2]
	nop
	mov r0, #0x20
	strh r0, [r2]
	nop
	mov r0, #0xD0
	strh r0, [r2]
	nop

FlashType3_MakeWriteable_loop2:
	ldrb r0, [r2]
	and r0, r0, #0xFF
	cmp r0, #0x80
	bne FlashType3_MakeWriteable_loop2
	nop
	mov r0, #0xFF
	strh r0, [r2]
	ldmfd sp!, {r2, lr}
	mov pc, lr

.pool

endOf_HandleFlashType3:
	nop
	nop

#endif // FLASH_ROM_CHANGES
