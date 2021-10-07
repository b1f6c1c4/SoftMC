#ifndef SOFTMC_H
#define SOFTMC_H

#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/time.h>
#include <riffa.h>

#define GET_TIME_INIT(num) struct timeval _timers[num]

#define GET_TIME_VAL(num) gettimeofday(&_timers[num], NULL)

#define TIME_VAL_TO_MS(num) (((double)_timers[num].tv_sec*1000.0) + ((double)_timers[num].tv_usec/1000.0))


#define BANK_OFFSET 3
#define ROW_OFFSET 16
#define CMD_OFFSET 4
#define COL_OFFSET 10
#define SIGNAL_OFFSET 6

// The current instruction format is 32 bits wide. But we allocate
// 64 bits (2 words) for each instruction to keep the hardware simple.
// Having C_PCI_DATA_WIDTH of 64 performs better than 32 when sending
// data that we read from the DRAM back to the host machine.
// TODO: modify the hardware to support 32-bit instructions.
#define INSTR_SIZE 2 //2 words

#define NUM_CHIPS 8
#define NUM_ROWS 32768
#define NUM_COLS 1024
#define NUM_BANKS 8
#define SUBARRAY_SIZE 512
#define NUM_SUBARRAYS (NUM_ROWS / SUBARRAY_SIZE)





typedef uint64_t Instruction;
typedef uint32_t uint;

//DO NOT EDIT (unless you change the verilog code)
enum INSTR_TYPE {
    INSTR_TYPE_END_OF_INSTRS = 0,
    INSTR_TYPE_SET_BUS_DIR = 1,
    INSTR_TYPE_WAIT = 4,
    INSTR_TYPE_DDR = 8
};
//END - DO NOT EDIT

enum BUSDIR {
	BUSDIR_READ = 0,
	BUSDIR_WRITE = 2
};

enum AUTO_PRECHARGE {
	AUTO_PRECHARGE_NO_AP = 0,
	AUTO_PRECHARGE_AP = 1
};

enum PRE_TYPE {
	PRE_TYPE_SINGLE = 0,
	PRE_TYPE_ALL = 1
};

enum BURST_LENGTH {
	BURST_LENGTH_CHOP = 0,
	BURST_LENGTH_FIXED = 1
};

enum REGISTER {
	REGISTER_TREFI = 2,
	REGISTER_TRFC = 3
};


Instruction genACT(uint bank, uint row);
Instruction genPRE(uint bank, enum PRE_TYPE pt /* PRE_TYPE_SINGLE */);
Instruction genWR(uint bank, uint col, uint8_t pattern, enum AUTO_PRECHARGE ap /* AUTO_PRECHARGE_NO_AP */, enum BURST_LENGTH bl /* BURST_LENGTH_FIXED */);
Instruction genWR_burst(uint bank, uint col, enum AUTO_PRECHARGE ap /* AUTO_PRECHARGE_NO_AP */);
Instruction genRD(uint bank, uint col, enum AUTO_PRECHARGE ap /* AUTO_PRECHARGE_NO_AP */, enum BURST_LENGTH bl /* BURST_LENGTH_FIXED */);
Instruction genWAIT(uint cycles);
Instruction genBUSDIR(enum BUSDIR dir);
Instruction genEND();
Instruction genZQ();
Instruction genREF();
Instruction genREF_CONFIG(uint val, enum REGISTER r);


#endif //SOFTMC_H
