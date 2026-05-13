# SPDX-License-Identifier: Apache-2.0
# Build .dtbo from the .dts overlay using dtc. Also stages firmware/ files
# in the layout that xmutil loadapp expects:
#
#   build/pccx_npu/
#     shell.json
#     pccx_npu.dtbo
#     pccx_npu.bit.bin     <- requires `make bitbin` after bitstream exists
#
# Then on a KV260:
#   sudo cp -r build/pccx_npu /lib/firmware/xilinx/
#   sudo xmutil loadapp pccx_npu

DTC      ?= dtc
BOOTGEN  ?= bootgen

SRC_DIR  := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
BUILD    := $(SRC_DIR)build/pccx_npu

BIT_SRC  ?= $(SRC_DIR)../../hw/build/reports/pccx_v002_kv260.bit

.PHONY: all dtbo bitbin stage clean

all: dtbo stage

dtbo: $(BUILD)/pccx_npu.dtbo

$(BUILD)/pccx_npu.dtbo: $(SRC_DIR)pccx_npu.dts
	@mkdir -p $(BUILD)
	$(DTC) -@ -O dtb -o $@ $<

stage: dtbo
	@mkdir -p $(BUILD)
	cp $(SRC_DIR)shell.json $(BUILD)/

# bitbin requires a .bif and bootgen. The .bif points at the post-impl .bit.
bitbin: $(BUILD)/pccx_npu.bit.bin

$(BUILD)/pccx_npu.bit.bin: $(BIT_SRC)
	@mkdir -p $(BUILD)
	@echo "all:" > $(BUILD)/pccx_npu.bif
	@echo "{" >> $(BUILD)/pccx_npu.bif
	@echo "    [destination_device = pl] $(BIT_SRC)" >> $(BUILD)/pccx_npu.bif
	@echo "}" >> $(BUILD)/pccx_npu.bif
	$(BOOTGEN) -arch zynqmp -image $(BUILD)/pccx_npu.bif -o $@ -w on -process_bitstream bin

clean:
	rm -rf $(BUILD)
