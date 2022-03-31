################################################################################
# \file MCUBootApp.mk
# \version 1.0
#
# \brief
# Makefile for Cypress MCUBoot-based application.
#
################################################################################
# \copyright
# Copyright 2018-2019 Cypress Semiconductor Corporation
# SPDX-License-Identifier: Apache-2.0
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
################################################################################

include host.mk

APP_NAME := MCUBootApp

# Cypress' MCUBoot Application supports GCC ARM only at this moment
# Set default compiler to GCC if not specified from command line
COMPILER ?= GCC_ARM

CUR_APP_PATH = $(PRJ_DIR)/$(APP_NAME)

ifneq ($(FLASH_MAP), )
$(CUR_APP_PATH)/flashmap.mk:
	$(PYTHON_PATH) scripts/flashmap.py -p $(PLATFORM) -i $(FLASH_MAP) -o $(PRJ_DIR)/cy_flash_pal/cy_flash_map.h > $(CUR_APP_PATH)/flashmap.mk
include $(CUR_APP_PATH)/flashmap.mk
DEFINES_APP := -DCY_FLASH_MAP_JSON
endif

MCUBOOT_IMAGE_NUMBER ?= 1
ENC_IMG ?= 0
USE_BOOTSTRAP ?= 1
MCUBOOT_LOG_LEVEL ?= MCUBOOT_LOG_LEVEL_DEBUG
USE_SHARED_SLOT ?= 0

ifneq ($(COMPILER), GCC_ARM)
$(error Only GCC ARM is supported at this moment)
endif

# Output folder
OUT := $(APP_NAME)/out
# Output folder to contain build artifacts
OUT_TARGET := $(OUT)/$(PLATFORM)

OUT_CFG := $(OUT_TARGET)/$(BUILDCFG)

include $(PRJ_DIR)/platforms.mk
include $(PRJ_DIR)/common_libs.mk
include $(PRJ_DIR)/toolchains.mk

ifeq ($(MAX_IMG_SECTORS), )
MAX_IMG_SECTORS ?= $(PLATFORM_MAX_IMG_SECTORS)
endif

# Application-specific DEFINES
DEFINES_APP += -DMBEDTLS_CONFIG_FILE="\"mcuboot_crypto_config.h\""
DEFINES_APP += -DECC256_KEY_FILE="\"keys/$(SIGN_KEY_FILE).pub\""
DEFINES_APP += -D$(CORE)
DEFINES_APP += -DMCUBOOT_IMAGE_NUMBER=$(MCUBOOT_IMAGE_NUMBER)
DEFINES_APP += -DUSE_SHARED_SLOT=$(USE_SHARED_SLOT)

# Define MCUboot size and pass it to linker script
BOOTLOADER_SIZE ?= $(PLATFORM_BOOTLOADER_SIZE)
LDFLAGS_DEFSYM  += -Wl,--defsym,BOOTLOADER_SIZE=$(BOOTLOADER_SIZE)


APP_DEFAULT_POLICY ?= $(PLATFORM_APP_DEFAULT_POLICY)

ifeq ($(USE_EXTERNAL_FLASH), 1)
ifeq ($(USE_XIP), 1)
DEFINES_APP += -DUSE_XIP
endif
DEFINES_APP += -DCY_BOOT_USE_EXTERNAL_FLASH
DEFINES_APP += -DCY_MAX_EXT_FLASH_ERASE_SIZE=$(PLATFORM_CY_MAX_EXT_FLASH_ERASE_SIZE)
endif

ifeq ($(USE_OVERWRITE), 1)
DEFINES_APP += -DMCUBOOT_OVERWRITE_ONLY
ifeq ($(USE_SW_DOWNGRADE_PREV), 1)
DEFINES_APP += -DMCUBOOT_DOWNGRADE_PREVENTION
endif
else
ifeq ($(USE_BOOTSTRAP), 1)
DEFINES_APP += -DMCUBOOT_BOOTSTRAP
endif
endif
DEFINES_APP += -DMCUBOOT_MAX_IMG_SECTORS=$(MAX_IMG_SECTORS)
DEFINES_APP += -DMCUBOOT_LOG_LEVEL=$(MCUBOOT_LOG_LEVEL)
ifeq ($(USE_HW_ROLLBACK_PROT), 1)
DEFINES_APP += -DMCUBOOT_HW_ROLLBACK_PROT
# Service RAM app address (size 0x8000)
DEFINES_APP += -DSERVICE_APP_OFFSET=$(PLATFORM_SERVICE_APP_OFFSET)
# Service RAM app input parameters address (size 0x400)
DEFINES_APP += -DSERVICE_APP_INPUT_PARAMS_OFFSET=$(PLATFORM_SERVICE_APP_INPUT_PARAMS_OFFSET)
# Service RAM app descriptor addr (size 0x20)
DEFINES_APP += -DSERVICE_APP_DESC_OFFSET=$(PLATFORM_SERVICE_APP_DESC_OFFSET)
# Service RAM app size
DEFINES_APP += -DSERVICE_APP_SIZE=$(PLATFORM_SERVICE_APP_SIZE)
endif
# Hardrware acceleration support
ifeq ($(USE_CRYPTO_HW), 1)
DEFINES_APP += -DMBEDTLS_USER_CONFIG_FILE="\"mcuboot_crypto_acc_config.h\""
DEFINES_APP += -DCY_CRYPTO_HAL_DISABLE
DEFINES_APP += -DCY_MBEDTLS_HW_ACCELERATION
endif

# Compile with user redefined values for UART HW, port, pins
ifeq ($(USE_CUSTOM_DEBUG_UART), 1)
DEFINES_APP += -DUSE_CUSTOM_DEBUG_UART=1
endif

# Encrypted image support
ifeq ($(ENC_IMG), 1)
DEFINES_APP += -DENC_IMG=1
ifeq ($(PLATFORM), CYW20829)
DEFINES_APP += -DMCUBOOT_ENC_IMAGES_XIP
endif
# Use maximum optimization level for PSOC6 encrypted image with
# external flash so it would fit into 0x18000 size of MCUBootApp
ifneq ($(PLATFORM), CYW20829)
ifeq ($(BUILDCFG), Debug)
ifeq ($(USE_EXTERNAL_FLASH), 1)
CFLAGS_OPTIMIZATION := -Os -g3
endif
endif
endif
endif


# Collect MCUBoot sourses
SOURCES_MCUBOOT := $(wildcard $(PRJ_DIR)/../bootutil/src/*.c)
# Collect MCUBoot Application sources
SOURCES_APP_SRC := main.c cy_security_cnt.c keys.c

# Collect Flash Layer sources and header files dirs
INCLUDE_DIRS_FLASH := $(PLATFORM_INCLUDE_DIRS_FLASH)
INCLUDE_DIRS_UTILS := $(PLATFORM_INCLUDE_DIRS_UTILS)
SOURCES_FLASH := $(PLATFORM_SOURCES_FLASH)

# Collect all the sources
SOURCES_APP := $(SOURCES_MCUBOOT)
SOURCES_APP += $(SOURCES_FLASH)
SOURCES_APP += $(addprefix $(CUR_APP_PATH)/, $(SOURCES_APP_SRC))
SOURCES_APP += $(PLATFORM_APP_SOURCES)

INCLUDE_DIRS_MCUBOOT := $(addprefix -I, $(PRJ_DIR)/../bootutil/include)
INCLUDE_DIRS_MCUBOOT += $(addprefix -I, $(PRJ_DIR)/../bootutil/src)
INCLUDE_DIRS_MCUBOOT += $(addprefix -I, $(PRJ_DIR)/..)

INCLUDE_DIRS_APP += $(addprefix -I, $(PRJ_DIR))
INCLUDE_DIRS_APP += $(addprefix -I, $(CUR_APP_PATH))
INCLUDE_DIRS_APP += $(addprefix -I, $(CUR_APP_PATH)/config)
INCLUDE_DIRS_APP += $(addprefix -I, $(CUR_APP_PATH)/os)
INCLUDE_DIRS_APP += $(addprefix -I, $(INCLUDE_DIRS_FLASH))
INCLUDE_DIRS_APP += $(addprefix -I, $(INCLUDE_DIRS_UTILS))

ASM_FILES_APP :=
ASM_FILES_APP += $(ASM_FILES_STARTUP)

# Pass variables to linker script and overwrite path to it, if custom is required
ifeq ($(COMPILER), GCC_ARM)
LDFLAGS += $(LDFLAGS_DEFSYM)
LINKER_SCRIPT := $(CUR_APP_PATH)/$(APP_NAME)_$(CORE).ld
else
$(error Only GCC ARM is supported at this moment)
endif

###############################################################################
# Print debug information about all settings used and/or set in this file
ifeq ($(VERBOSE), 1)
$(info #### MCUBootApp.mk ####)
$(info APP_DEFAULT_POLICY --> $(APP_DEFAULT_POLICY))
$(info APP_NAME <-> $(APP_NAME))
$(info ASM_FILES_APP --> $(ASM_FILES_APP))
$(info ASM_FILES_STARTUP <-- $(ASM_FILES_STARTUP))
$(info BOOTLOADER_SIZE <-> $(BOOTLOADER_SIZE))
$(info BUILDCFG <-- $(BUILDCFG))
$(info CFLAGS_OPTIMIZATION --> $(CFLAGS_OPTIMIZATION))
$(info COMPILER <-> $(COMPILER))
$(info CORE <-- $(CORE))
$(info CUR_APP_PATH <-- $(CUR_APP_PATH))
$(info DEFINES_APP --> $(DEFINES_APP))
$(info ENC_IMG <-> $(ENC_IMG))
$(info EXTERNAL_FLASH_PRIMARY_2_OFFSET <-> $(EXTERNAL_FLASH_PRIMARY_2_OFFSET))
$(info EXTERNAL_FLASH_SCRATCH_OFFSET <-> $(EXTERNAL_FLASH_SCRATCH_OFFSET))
$(info EXTERNAL_FLASH_SECONDARY_1_OFFSET <-> $(EXTERNAL_FLASH_SECONDARY_1_OFFSET))
$(info EXTERNAL_FLASH_SECONDARY_2_OFFSET <-> $(EXTERNAL_FLASH_SECONDARY_2_OFFSET))
$(info FLASH_MAP <-- $(FLASH_MAP))
$(info IMAGE_1_SLOT_SIZE <-> $(IMAGE_1_SLOT_SIZE))
$(info IMAGE_2_SLOT_SIZE <-> $(IMAGE_2_SLOT_SIZE))
$(info INCLUDE_DIRS_APP --> $(INCLUDE_DIRS_APP))
$(info INCLUDE_DIRS_FLASH <-> $(INCLUDE_DIRS_FLASH))
$(info INCLUDE_DIRS_MCUBOOT --> $(INCLUDE_DIRS_MCUBOOT))
$(info LDFLAGS --> $(LDFLAGS))
$(info LDFLAGS_DEFSYM <-> $(LDFLAGS_DEFSYM))
$(info LINKER_SCRIPT --> $(LINKER_SCRIPT))
$(info MAX_IMG_SECTORS <-> $(MAX_IMG_SECTORS))
$(info MCUBOOT_IMAGE_NUMBER <-> $(MCUBOOT_IMAGE_NUMBER))
$(info MCUBOOT_LOG_LEVEL <-> $(MCUBOOT_LOG_LEVEL))
$(info OUT <-> $(OUT))
$(info OUT_CFG --> $(OUT_CFG))
$(info OUT_TARGET <-> $(OUT_TARGET))
$(info PLATFORM <-- $(PLATFORM))
$(info PLATFORM_APP_DEFAULT_POLICY <-- $(PLATFORM_APP_DEFAULT_POLICY))
$(info PLATFORM_APP_SOURCES <-- $(PLATFORM_APP_SOURCES))
$(info PLATFORM_BOOTLOADER_SIZE <-- $(PLATFORM_BOOTLOADER_SIZE))
$(info PLATFORM_CHUNK_SIZE <-- $(PLATFORM_CHUNK_SIZE))
$(info PLATFORM_CY_MAX_EXT_FLASH_ERASE_SIZE <-- $(PLATFORM_CY_MAX_EXT_FLASH_ERASE_SIZE))
$(info PLATFORM_EXTERNAL_FLASH_PRIMARY_2_OFFSET <-- $(PLATFORM_EXTERNAL_FLASH_PRIMARY_2_OFFSET))
$(info PLATFORM_EXTERNAL_FLASH_SCRATCH_OFFSET <-- $(PLATFORM_EXTERNAL_FLASH_SCRATCH_OFFSET))
$(info PLATFORM_EXTERNAL_FLASH_SECONDARY_1_OFFSET <-- $(PLATFORM_EXTERNAL_FLASH_SECONDARY_1_OFFSET))
$(info PLATFORM_EXTERNAL_FLASH_SECONDARY_2_OFFSET <-- $(PLATFORM_EXTERNAL_FLASH_SECONDARY_2_OFFSET))
$(info PLATFORM_IMAGE_1_SLOT_SIZE <-- $(PLATFORM_IMAGE_1_SLOT_SIZE))
$(info PLATFORM_IMAGE_2_SLOT_SIZE <-- $(PLATFORM_IMAGE_2_SLOT_SIZE))
$(info PLATFORM_INCLUDE_DIRS_FLASH <-- $(PLATFORM_INCLUDE_DIRS_FLASH))
$(info PLATFORM_MAX_IMG_SECTORS <-- $(PLATFORM_MAX_IMG_SECTORS))
$(info PLATFORM_SCRATCH_SIZE <-- $(PLATFORM_SCRATCH_SIZE))
$(info PLATFORM_SERVICE_APP_DESC_OFFSET <-- $(PLATFORM_SERVICE_APP_DESC_OFFSET))
$(info PLATFORM_SERVICE_APP_INPUT_PARAMS_OFFSET <-- $(PLATFORM_SERVICE_APP_INPUT_PARAMS_OFFSET))
$(info PLATFORM_SERVICE_APP_OFFSET <-- $(PLATFORM_SERVICE_APP_OFFSET))
$(info PLATFORM_SERVICE_APP_SIZE <-- $(PLATFORM_SERVICE_APP_SIZE))
$(info PLATFORM_SOURCES_FLASH <-- $(PLATFORM_SOURCES_FLASH))
$(info PLATFORM_STATUS_PARTITION_OFFSET <-- $(PLATFORM_STATUS_PARTITION_OFFSET))
$(info PRJ_DIR <-- $(PRJ_DIR))
$(info PYTHON_PATH <-- $(PYTHON_PATH))
$(info SCRATCH_SIZE <-> $(SCRATCH_SIZE))
$(info SIGN_KEY_FILE <-- $(SIGN_KEY_FILE))
$(info SOURCES_APP --> $(SOURCES_APP))
$(info SOURCES_APP_SRC <-> $(SOURCES_APP_SRC))
$(info SOURCES_FLASH <-> $(SOURCES_FLASH))
$(info SOURCES_MCUBOOT <-> $(SOURCES_MCUBOOT))
$(info STATUS_PARTITION_OFFSET <-> $(STATUS_PARTITION_OFFSET))
$(info USE_BOOTSTRAP <-> $(USE_BOOTSTRAP))
$(info USE_CRYPTO_HW <-- $(USE_CRYPTO_HW))
$(info USE_CUSTOM_DEBUG_UART <-- $(USE_CUSTOM_DEBUG_UART))
$(info USE_CUSTOM_MEMORY_MAP <-- $(USE_CUSTOM_MEMORY_MAP))
$(info USE_EXTERNAL_FLASH <-- $(USE_EXTERNAL_FLASH))
$(info USE_HW_ROLLBACK_PROT <-- $(USE_HW_ROLLBACK_PROT))
$(info USE_OVERWRITE <-- $(USE_OVERWRITE))
$(info USE_XIP <-- $(USE_XIP))
endif
