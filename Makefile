TECH ?= tsmc65-12t9m
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

include config/$(TECH)/macro.mk
MACRO_CONFIG_FLAGS = $(addprefix -p , $(MACRO_CONFIG))

CONFIG_DIR=config
COMMON_CONFIG = $(CONFIG_DIR)/common.yml
TECH_CONFIG = $(CONFIG_DIR)/$(TECH)/$(TECH).yml
PROJECT_CONFIG = $(ROOT_DIR)/project.yml
CONFIGS= $(COMMON_CONFIG) $(TECH_CONFIG) $(MACRO_CONFIG) $(PROJECT_CONFIG)


# run dirs for the tools
SYN_DIR = syn
PAR_DIR = par
DRC_DIR = drc
LVS_DIR = lvs
SIM_DIR = sim
LOG_DIR = log
LOG_FILE = $(LOG_DIR)/hammer.log

PLUGIN_FLAGS=export "PYTHONPATH=$(ROOT_DIR)/tools/hammer-hni-cad-plugin/:$$PYTHON_PATH" && export HAMMER_HOME=$(ROOT_DIR)/tools/hammer/
HAMMER_BIN=$(PLUGIN_FLAGS) && source $(ROOT_DIR)/tools/hammer/sourceme.sh && $(ROOT_DIR)/ips/scripts/pulpino-vlsi

HAMMER_FLAGS= -p $(PROJECT_CONFIG) -p $(COMMON_CONFIG) -p $(TECH_CONFIG) $(MACRO_CONFIG_FLAGS) \
			  --syn_rundir $(SYN_DIR) \
			  --par_rundir $(PAR_DIR) \
			  --drc_rundir $(DRC_DIR) \
			  --lvs_rundir $(LVS_DIR) \
			  --sim_rundir $(SIM_DIR) \
			  -l $(LOG_FILE)

RTL_EXCLUDE := -not \( -path "*/includes/*" \) \
               -not \( -path  "*/random_stalls.sv" \) \
               -not \( -path  "*/dp_ram_wrap.sv" \) \
               -not \( -path  "*/dp_ram.sv" \) \
               -not \( -path  "*/apb_mock_uart.sv" \) \
               -not \( -path  "*/cluster_clock_gating.sv" \) \
               -not \( -path  "*/cluster_clock_inverter.sv" \) \
               -not \( -path  "*/cluster_clock_mux2.sv" \) \
               -not \( -path  "*/pulp_clock_mux2.sv" \) \
               -not \( -path  "*/sp_ram_wrap.sv" \) \
               -not \( -path  "*/tsmc_wrap.sv" \)

TOP=tsmc65_wrap
RTL:=$(shell find rtl/pulpino/rtl -type f \( -name '*.sv' -o -name "*.v" -o -name "*.vhd" \)  $(RTL_EXCLUDE))
RTL_PDK_DEP:=$(shell find ips/rtl//$(TECH) -type f \( -name '*.sv' -o -name "*.v" -o -name "*.vhd" \))
IPS = $(shell python3 scripts/ips_to_hammer.py $(shell pwd)/rtl/pulpino/ips/)
INPUTS:=$(IPS) $(RTL) $(RTL_PDK_DEP)
ARGS_INPUTS = $(addprefix -v , $(INPUTS))

.PHONY: dump syn par drc lvs folder setup submodules editconfig

setup: submodules

submodules:
	git submodule update --init --recursive
	cd rtl/pulpino/ && python2 update-ips.py

$(PROJECT_CONFIG):
	echo "project.path: \"$(ROOT_DIR)\"" > $@

folder:
	@mkdir -p log
	@mkdir -p syn
	@mkdir -p par
	@mkdir -p drc
	@mkdir -p sim
	@mkdir -p lvs

dump: $(PROJECT_CONFIG)
	echo $(ROOT_DIR)
	$(HAMMER_BIN) $(HAMMER_FLAGS) dump

#
# Syn rules
#
syn: $(SYN_DIR)/syn-output.json
$(SYN_DIR)/syn-output.json: $(INPUTS) $(CONFIGS)
	make folder
	$(HAMMER_BIN) $(HAMMER_FLAGS) $(ARGS_INPUTS) -t $(TOP) syn

syn_start: $(INPUT)
	$(HAMMER_BIN) $(HAMMER_FLAGS) -v $< -t $(TOP) syn

$(PAR_DIR)/input.json: $(SYN_DIR)/syn-output.json
	$(HAMMER_BIN) $(HAMMER_FLAGS) -p $< syn-to-par -o $@

#
# Sim post synth
#

sim_ps: $(SIM_DIR)/sim-output.json
$(SIM_DIR)/sim-output.json: $(SIM_DIR)/input_ps.json
	@mkdir -p $(SIM_DIR)/stdout/
	@touch $(SIM_DIR)/stdout/uart
	$(HAMMER_BIN) $(HAMMER_FLAGS) -p $< -t $(TOP) sim

$(SIM_DIR)/input_ps.json: $(SYN_DIR)/syn-output.json
	$(HAMMER_BIN) $(HAMMER_FLAGS) -p $< syn-to-sim -o $@



#
# Par rules
#
par: $(PAR_DIR)/par-output.json
$(PAR_DIR)/par-output.json: $(PAR_DIR)/input.json
	$(HAMMER_BIN) $(HAMMER_FLAGS) -e $< par

$(DRC_DIR)/input.json: $(PAR_DIR)/par-output.json
	$(HAMMER_BIN) $(HAMMER_FLAGS) -p $< par-to-drc -o $@

$(LVS_DIR)/input.json: $(PAR_DIR)/par-output.json
	$(HAMMER_BIN) $(HAMMER_FLAGS) -p $< par-to-lvs -o $@

#
# DRC rules
#
drc: $(DRC_DIR)/drc-output.json
$(DRC_DIR)/drc-output.json: $(DRC_DIR)/input.json
	$(HAMMER_BIN) $(HAMMER_FLAGS) -e $< drc

#
# LVS rules
#
lvs: $(LVS_DIR)/lvs-output.json
$(LVS_DIR)/lvs-output.json: $(LVS_DIR)/input.json
	$(HAMMER_BIN) $(HAMMER_FLAGS) -e $< lvs

all: $(DRC_DIR)/drc-output.json $(LVS_DIR)/lvs-output.json

clean:
	rm -rf $(SYN_DIR)/*
	rm -rf $(PAR_DIR)/*
	rm -rf $(DRC_DIR)/*
	rm -rf $(LVS_DIR)/*
	rm -rf $(LOG_DIR)/*
	rm -rf $(SIM_DIR)/*

mrpropper: clean
	rm -rf $(PROJECT_CONFIG)
