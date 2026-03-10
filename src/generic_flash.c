#include "config.h"
#include "gba/gba.h"
#include "gba/flash_internal.h"
#include "save.h"

//#ifdef FLASH_ROM_CHANGES

typedef u32 (*flash_ram_func)(u32);
#define FLASH_HWORD_WRITE(address, value) ((*(vu16 *)(address)) = (value))
#define FLASH_HWORD_READ(address) (*(vu16 *)(address))

//void Task_ClearSaveData_fillSramWithFF(void);
void CopyFuncToRamSpace(flash_ram_func function, u32 size);
void WriteCurrentSaveSlotToFlash(void);
u32 DetermineFlashType(u32);
u32 HandleFlashType0(u32);
u32 HandleFlashType1(u32);
u32 HandleFlashType2(u32);
u32 HandleFlashType3(u32);
void HandleFlashTypeEndStub(void);

EWRAM_DATA u8 gSaveSlot = 0;
// real address in ld_script.ld
extern u32 __ewram_code_space(u32);

#define EWRAM_FUNCTION ((flash_ram_func)(0x0203FC11))
#define __sram_space ((u8 *)(0x0E000000))

void LoadSaveSlotFromSaveSpace(void)
{
    u32 i;
    for (i = 0; i < INDIVIDUAL_SAVE_SIZE; i++)
    {
        __sram_space[i] = (*(u8 *)(SAVE_ADDRESS + gSaveSlot * FULL_SAVE_SIZE + i));
    }
    LoadGameSave(SAVE_NORMAL);
    // TODO:  check for errors and load backup if necessary
}

void Task_ClearSaveData_fillSramWithFF(void)
{
    vu8 *sram = (vu8 *)(0x0E000000);
    s32 i;
    for (i = 0; i < INDIVIDUAL_SAVE_SIZE; i++)
    {
        sram[i] = 0xFF;
    }
    WriteCurrentSaveSlotToFlash();
}

void CopyFuncToRamSpace(flash_ram_func function, u32 size)
{
    u8 *dest = (u8 *)__ewram_code_space;
    u8 *funcSpace = (u8 *)((u32)(function) & 0xFFFFFFFE);
    s32 i;

    for (i = 0; i < size; i++)
        dest[i] = funcSpace[i];
}

void WriteCurrentSaveSlotToFlash(void)
{
    u32 ramFuncSize;
    u32 flashType = 0;
    flash_ram_func functionToCopy;
#define __ewram_register_space ((u16 *)0x0203FC00)
    // DisableInterruptsAndLoadFlashCodeToRam
    __ewram_register_space[0] = REG_IME;
    __ewram_register_space[1] = REG_IE;
    __ewram_register_space[2] = REG_SOUNDCNT_H;
    __ewram_register_space[3] = REG_SOUNDCNT_L;
    __ewram_register_space[4] = REG_DMA0CNT_H;
    __ewram_register_space[5] = REG_DMA1CNT_H;
    __ewram_register_space[6] = REG_DMA2CNT_H;
    __ewram_register_space[7] = REG_DMA3CNT_H;
    REG_IME = 0;
    REG_IE = 0;
    REG_SOUNDCNT_H = 0;
    REG_SOUNDCNT_L = 0;
    REG_DMA0CNT_H = 0;
    REG_DMA1CNT_H = 0;
    REG_DMA2CNT_H = 0;
    REG_DMA3CNT_H = 0;

    ramFuncSize = (u32)(HandleFlashType0) - (u32)(DetermineFlashType);
    CopyFuncToRamSpace(DetermineFlashType, ramFuncSize);
    flashType = EWRAM_FUNCTION(0);

    // HandleFlashChipType + _handleTypeN
    switch (flashType & 0xFF)
    {
        case 0:
            functionToCopy = HandleFlashType0;
            ramFuncSize = (u32)(HandleFlashType1) - (u32)(HandleFlashType0);
            break;
        case 1:
            functionToCopy = HandleFlashType1;
            ramFuncSize = (u32)(HandleFlashType2) - (u32)(HandleFlashType1);
            break;
        case 2:
            functionToCopy = HandleFlashType2;
            ramFuncSize = (u32)(HandleFlashType3) - (u32)(HandleFlashType2);
            break;
        case 3:
            functionToCopy = HandleFlashType3;
            ramFuncSize = (u32)(HandleFlashTypeEndStub) - (u32)(HandleFlashType3);
            break;
    }
    CopyFuncToRamSpace(functionToCopy, ramFuncSize);
    EWRAM_FUNCTION(flashType);

    REG_IME = __ewram_register_space[0];
    REG_IE = __ewram_register_space[1];
    REG_SOUNDCNT_H = __ewram_register_space[2];
    REG_SOUNDCNT_L = __ewram_register_space[3];
    REG_DMA0CNT_H = __ewram_register_space[4];
    REG_DMA1CNT_H = __ewram_register_space[5];
    REG_DMA2CNT_H = __ewram_register_space[6];
    REG_DMA3CNT_H = __ewram_register_space[7];
}

u32 DetermineFlashType(u32 param UNUSED)
{
    s32 i;
    u32 flashType;
    u16 flashRead = 0;
    FLASH_HWORD_WRITE(0x08000154, 0xF0F0);
    FLASH_HWORD_WRITE(0x08000154, 0x9898);
    if (FLASH_HWORD_READ(0x08000040) == 0x5152)
    {
        FLASH_HWORD_WRITE(0x08000000, 0xF0F0);
        flashType = 0;
    }
    else
    {
        // _5152_check_fail
        FLASH_HWORD_WRITE(0x08000000, 0xFF);
        asm("nop");
        FLASH_HWORD_WRITE(0x08000000, 0x50);
        asm("nop");
        FLASH_HWORD_WRITE(0x08000000, 0x90);
        asm("nop");
        for (i = 0; i < 8; i++)
        {
            flashRead = FLASH_HWORD_READ(0x08000000);
            if (flashRead == 0x8A)
            {
                // _8A_check_success
                FLASH_HWORD_WRITE(0x08000000, 0xFF);
                asm("nop");
                FLASH_HWORD_WRITE(0x08000000, 0x90);
                asm("nop");
                flashRead = FLASH_HWORD_READ(0x08000002);
                if (flashRead == 0x8815)
                {
                    FLASH_HWORD_WRITE(0x08000002, 0xFF);
                    flashType = 3;
                    break;
                }
                else if (flashRead == 0x887D || flashRead == 0x88B0)
                {
                    FLASH_HWORD_WRITE(0x08000000, 0xFF);
                    flashType = 1; // type 1 r6 = 0
                    break;
                }
                else
                {
                    // generic flash type 0
                    FLASH_HWORD_WRITE(0x08000000, 0xF0);
                    flashType = 0;
                    break;
                }
            }
        }
        if (flashRead == 0x89)
        {
            // _status_89
            FLASH_HWORD_WRITE(0x08000000, 0xFF);
            flashType = 0xFF01; // type 1 r6 = 0xFF
        }
        else
        {
            FLASH_HWORD_WRITE(0x08000000, 0xF0);
            flashType = 2;
        }
    }

    return flashType;
}

u32 HandleFlashType0(u32 param UNUSED)
{
    // TODO: adapt code for slots
    s32 i;
    u16 flashRead;
    u16 *saveAddress = (u16 *)(SAVE_ADDRESS);
    FLASH_HWORD_WRITE((u32)saveAddress, 0xF0F0);
    FLASH_HWORD_WRITE(0x08001554, 0xAAA9);
    FLASH_HWORD_WRITE(0x08000AAA, 0x5556);
    FLASH_HWORD_WRITE(0x08001554, 0x8080);
    FLASH_HWORD_WRITE(0x08001554, 0xAAA9);
    FLASH_HWORD_WRITE(0x08000AAA, 0x5556);
    FLASH_HWORD_WRITE((u32)saveAddress, 0x3030);
    // FlashType0_MakeWriteable
    for (i = 0x100000; i > 0; i--)
    {
        flashRead = FLASH_HWORD_READ((u32)saveAddress);
        if (flashRead & 0x8000) break;
        if ((flashRead & 0x2000) == 0) continue;
        flashRead = FLASH_HWORD_READ((u32)saveAddress);
        if (flashRead & 0x8000) break;
    }
    for (i = 0x100000; i > 0; i--)
    {
        flashRead = FLASH_HWORD_READ((u32)saveAddress);
        if (flashRead & 0x80) break;
        if ((flashRead & 0x20) == 0) continue;
        flashRead = FLASH_HWORD_READ((u32)saveAddress);
        if (flashRead & 0x80) break;
    }
    // back in main function
    FLASH_HWORD_WRITE((u32)saveAddress, 0xF0F0);
    FLASH_HWORD_WRITE(0x08001554, 0xAAA9);
    FLASH_HWORD_WRITE(0x08000AAA, 0x5556);
    FLASH_HWORD_WRITE(0x08001554, 0x2020);
    // FlashType0_TransferSRAMToSaveSpace
    for (i = 0; i < INDIVIDUAL_SAVE_SIZE; i += 2)
    {
        s32 j;
        flashRead = __sram_space[i] | (__sram_space[i+1] << 8);
        FLASH_HWORD_WRITE((u32)&saveAddress[i/2], 0xA0A0);
        asm("nop");
        FLASH_HWORD_WRITE((u32)&saveAddress[i/2], flashRead);
        for (j = 0x100; j > 0; j--)
        {
            if (flashRead == saveAddress[i/2])
                break;
        }
    }
    FLASH_HWORD_WRITE((u32)saveAddress, 0xF0F0);
    return 0;
}

u32 HandleFlashType1(u32 param UNUSED)
{
    // TODO:  type 1 code
    return 0;
}

u32 HandleFlashType2(u32 param UNUSED)
{
    u32 i, backupSlot;
    u16 flashRead;
    vu16 *saveAddress = (vu16 *)(SAVE_ADDRESS + gSaveSlot * FULL_SAVE_SIZE);
 
    // FlashType2_WriteHWordsToStatus
    FLASH_HWORD_WRITE(0x08000AAA, 0xA9);
    FLASH_HWORD_WRITE(0x08000554, 0x56);
    FLASH_HWORD_WRITE((u32)saveAddress, 0xF0);
    // back in main function
    FLASH_HWORD_WRITE(0x08000AAA, 0xA9);
    FLASH_HWORD_WRITE(0x08000554, 0x56);
    FLASH_HWORD_WRITE(0x08000AAA, 0x80);
    FLASH_HWORD_WRITE(0x08000AAA, 0xA9);
    FLASH_HWORD_WRITE(0x08000554, 0x56);
    FLASH_HWORD_WRITE((u32)saveAddress, 0x30);
    // FlashType2_MakeWriteable
    for (i = 0x100000; i > 0; i--)
    {
        flashRead = FLASH_HWORD_READ((u32)saveAddress);
        if (flashRead & 0x80) break;
        if ((flashRead & 0x20) == 0) continue;
        flashRead = FLASH_HWORD_READ((u32)saveAddress);
        if (flashRead & 0x80) break;
    }
    // FlashType2_WriteHWordsToStatus
    FLASH_HWORD_WRITE(0x08000AAA, 0xA9);
    FLASH_HWORD_WRITE(0x08000554, 0x56);
    FLASH_HWORD_WRITE((u32)saveAddress, 0xF0);
    // back in main function
    FLASH_HWORD_WRITE(0x08000AAA, 0xA9);
    FLASH_HWORD_WRITE(0x08000554, 0x56);
    FLASH_HWORD_WRITE(0x08000AAA, 0x20);
    // FlashType2_TransferSRAMToSaveSpace
    for (backupSlot = 0; backupSlot < 2; backupSlot++)
    {
        for (i = 0; i < INDIVIDUAL_SAVE_SIZE; i += 2)
        {
            u32 j, u16Addr = ((backupSlot * INDIVIDUAL_SAVE_SIZE) / 2) + i/2;
            flashRead = __sram_space[i] | (__sram_space[i+1] << 8);
            FLASH_HWORD_WRITE((u32)&saveAddress[u16Addr], 0xA0);
            asm("nop");
            FLASH_HWORD_WRITE((u32)&saveAddress[u16Addr], flashRead);
            for (j = 0x100; j > 0; j--)
            {
                if (flashRead == saveAddress[u16Addr])
                    break;
            }
        }
    }
    // back in main function
    FLASH_HWORD_WRITE((u32)saveAddress, 0x90);
    FLASH_HWORD_WRITE((u32)saveAddress, 0x00);
    // FlashType2_WriteHWordsToStatus
    FLASH_HWORD_WRITE(0x08000AAA, 0xA9);
    FLASH_HWORD_WRITE(0x08000554, 0x56);
    FLASH_HWORD_WRITE((u32)saveAddress, 0xF0);
    return 0;
}

u32 HandleFlashType3(u32 param UNUSED)
{
    // TODO:  type 3 code
    return 0;
}

void HandleFlashTypeEndStub(void)
{
    return;
}

//#endif
