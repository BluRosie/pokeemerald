#include "config.h"
#include "gba/gba.h"
#include "gba/flash_internal.h"
#include "save.h"

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
extern u16 *__ewram_register_space;
extern flash_ram_func __ewram_code_space;

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
    s32 i;

    for (i = 0; i < size; i++)
        dest[i] = ((u8 *)(function))[i];
}

void WriteCurrentSaveSlotToFlash(void)
{
    u32 ramFuncSize;
    u32 flashType = 0;
    flash_ram_func functionToCopy;
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
    flashType = __ewram_code_space(0);

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
    __ewram_code_space(flashType);

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
    FLASH_HWORD_WRITE(0x08000154, 0xF0F0);
    FLASH_HWORD_WRITE(0x08000154, 0x9898);
    if (FLASH_HWORD_READ(0x08000040) == 0x5152)
    {
        FLASH_HWORD_WRITE(0x08000000, 0xF0F0);
        flashType = 0;
    }
    else
    {
        FLASH_HWORD_WRITE(0x08000000, 0xF0F0);
    }

    return flashType;
}

u32 HandleFlashType0(u32 param UNUSED)
{
    return;
}

u32 HandleFlashType1(u32 param UNUSED)
{
    return;
}

u32 HandleFlashType2(u32 param UNUSED)
{
    return;
}

u32 HandleFlashType3(u32 param UNUSED)
{
    return;
}

void HandleFlashTypeEndStub(void)
{
    return;
}
