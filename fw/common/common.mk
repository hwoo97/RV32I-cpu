# Common build rules for firmware programs (run in the WSL rv32i distro).
# A program Makefile sets PROG and SRCS, then includes this file:
#     PROG := hello
#     SRCS := main.c
#     include ../common/common.mk
#
#   make                 simulation build (-DSIM, short UART bit time, SIMCTL report at exit)
#                        -> ../hex/<PROG>.hex and ../hex/<PROG>.exp (committed: the school server has no RISC-V gcc)
#   make SIM_BAUDDIV=n   simulation build with another UART bit time (n + 1 clocks, default 9);
#                        use with BUILD=<dir> HEX_OUT=<file> so that the committed hex is not replaced
#   make TARGET=fpga     board build (UART 115200 @ 50 MHz, no SIMCTL) -> build/fpga/<PROG>.hex (not committed)
#   make clean
#
# Output of every build: build/<TARGET>/<PROG>.elf, .dump (disassembly), .map, .hex

FW_DIR  := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
COMMON  := $(FW_DIR)/common
CROSS   ?= riscv64-unknown-elf-
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE    := $(CROSS)size

TARGET  ?= sim
BUILD   := build/$(TARGET)

ARCH    := -march=rv32i -mabi=ilp32
CFLAGS  := $(ARCH) -O2 -g -Wall -Wextra -ffreestanding -fno-builtin \
           -fno-tree-loop-distribute-patterns -ffunction-sections -fdata-sections \
           -I$(COMMON) -I. $(EXTRA_CFLAGS)
LDFLAGS := $(ARCH) -nostdlib -nostartfiles -static -T$(COMMON)/link.ld -L$(COMMON) \
           -Wl,--gc-sections -Wl,-Map=$(BUILD)/$(PROG).map

ifeq ($(TARGET),sim)
  # UART bit = 10 clocks (BAUDDIV 9) so that printf output is quick to simulate
  SIM_BAUDDIV ?= 9
  CFLAGS += -DSIM -DUART_BAUDDIV_INIT=$(SIM_BAUDDIV)u
  HEX_OUT := $(FW_DIR)/hex/$(PROG).hex
  EXP_OUT := $(FW_DIR)/hex/$(PROG).exp
else ifeq ($(TARGET),fpga)
  HEX_OUT := $(BUILD)/$(PROG).hex
  EXP_OUT :=
else
  $(error TARGET must be sim or fpga)
endif

COMMON_SRCS := crt0.S uart.c printf.c timer.c sys.c libc_min.c
OBJS := $(addprefix $(BUILD)/common/,$(addsuffix .o,$(basename $(COMMON_SRCS)))) \
        $(addprefix $(BUILD)/,$(addsuffix .o,$(basename $(SRCS))))
HDRS := $(wildcard $(COMMON)/*.h) $(wildcard *.h)

.PHONY: all clean
all: $(HEX_OUT) $(EXP_OUT)

$(BUILD)/common/%.o: $(COMMON)/%.c $(HDRS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/common/%.o: $(COMMON)/%.S $(HDRS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/%.o: %.c $(HDRS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/%.o: %.S $(HDRS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/$(PROG).elf: $(OBJS) $(COMMON)/link.ld $(COMMON)/memmap.ld
	$(CC) $(LDFLAGS) $(OBJS) -lgcc -o $@
	$(OBJDUMP) -d -M no-aliases $@ > $(BUILD)/$(PROG).dump
	$(SIZE) $@

# word-wide hex for $readmemh (load addresses, so the .data image lands in IMEM after the code)
$(HEX_OUT): $(BUILD)/$(PROG).elf
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@

# expected UART output, compared by sim/ch14a_mcu/fw_tb.v
$(FW_DIR)/hex/$(PROG).exp: expected.txt
	@mkdir -p $(dir $@)
	cp $< $@

clean:
	rm -rf build
