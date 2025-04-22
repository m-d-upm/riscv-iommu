# Copyright © 2023 Manuel Rodríguez & Zero-Day Labs, Lda.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author:   Manuel Rodríguez <manuel.cederog@gmail.com>
# Date:     28/03/2023
#
# Description:  Makefile to perform lint checks in the RISC-V IOMMU IP using verilator

VERILATOR = verilator

WARN_FLAGS :=
WARN_FLAGS += -Wno-LATCH

COMP_FLAGS := --cc \
	      --Wall \
	      --Wno-fatal \
	      +1800-2017ext+ \
	      --assert \
	      --error-limit 1000 \
	      --hierarchical \
	      --no-skip-identical \
	      #-DUSE_LOCAL_VENDOR_PKGS
# COMP_FLAGS +=

LINT_FLAGS := --lint-only \
	      -DUSE_LOCAL_VENDOR_PKGS
# LINT_FLAGS += --report-unoptflat

INC += -I./packages/dependencies
INC += -I./packages/rv_iommu
INC += -I./vendor
INC += -I./include
INC += -I./rtl
INC += -I./rtl/translation_logic
INC += -I./rtl/translation_logic/cdw
INC += -I./rtl/translation_logic/ptw
INC += -I./rtl/translation_logic/wrapper
INC += -I./rtl/software_interface
INC += -I./rtl/software_interface/regmap
INC += -I./rtl/software_interface/wrapper
INC += -I./rtl/ext_interfaces

all: lint

lint:
	$(VERILATOR) ${LINT_FLAGS} lint_checks.sv ${INC} ${WARN_FLAGS}

lint2log:
	$(VERILATOR) ${LINT_FLAGS} lint_checks.sv ${INC} ${WARN_FLAGS} 2> verilator.log

build:
	$(VERILATOR) ${COMP_FLAGS} lint_checks.sv ${INC} ${WARN_FLAGS}

build2log:
	$(VERILATOR) ${COMP_FLAGS} lint_checks.sv ${INC} ${WARN_FLAGS} 2> verilator.log
