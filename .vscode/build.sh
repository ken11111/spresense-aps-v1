#!/bin/bash

# Name: check_exit_status
# Description: Check exit status after executed and if it is not 0, exit this script
function check_exit_status (){
    EXIT_STATUS=$?
    if [ "${EXIT_STATUS}" != "0" ]; then
        exit ${EXIT_STATUS}
    fi
}

# Name: build_kernel
# Description: Build NuttX Kernel
# Usage: build_kernel
# If <Project folder's .config> = <SDK folder's .config>, will not update .config file
function build_kernel (){
    # App folder config
    if [ "${SPRESENSE_HOME}" != "" ]; then
        APP_KERNEL_CFG=${SPRESENSE_HOME}/kernel.config
    else
        APP_KERNEL_CFG=${SDK_PATH}/nuttx/.config
    fi

    # SDK folder config
    KERNEL_CFG=${SDK_PATH}/nuttx/.config

    # Check target config file
    if [ ! -f "${APP_KERNEL_CFG}" ]; then
        echo "Kernel is not configured. Please use "Spresense: Kernel config""
        exit 1
    fi

    # Check Kernel config
    if [ ! -f "${KERNEL_CFG}" -o "`diff ${APP_KERNEL_CFG} ${KERNEL_CFG}`" != "" ]; then
        # Update to new configuration file
        cp ${APP_KERNEL_CFG} ${KERNEL_CFG}
    fi

    # Check Make.defs and copy it if not exist
    if [ ! -f "${SDK_PATH}/nuttx/Make.defs" ]; then
        cp -a ${SDK_PATH}/sdk/bsp/scripts/Make.defs.nuttx ${SDK_PATH}/nuttx/Make.defs
    fi

    cd ${SDK_PATH}/sdk
    make buildkernel

    # Check exit status
    check_exit_status
}

# Name: build_sdk
# Description: Build SDK with application
# If <Project folder's .config> = <SDK folder's .config>, will not update .config file
function build_sdk (){
    # App folder config
    if [ "${SPRESENSE_HOME}" != "" ]; then
        APP_SDK_CFG=${SPRESENSE_HOME}/sdk.config
    else
        APP_SDK_CFG=${SDK_PATH}/sdk/.config
    fi

    # SDK folder config
    SDK_CFG=${SDK_PATH}/sdk/.config

    # Check target config file
    if [ ! -f "${APP_SDK_CFG}" ]; then
        echo "SDK is not configured. Please use "Spresense: SDK config""
        exit 1
    fi

    # Initialize builtin registry
    rm -f ${SDK_PATH}/sdk/system/builtin/registry/.updated

    # Check SDK config
    if [ ! -f "${SDK_CFG}" -o "`diff ${APP_SDK_CFG} ${SDK_CFG}`" != "" ]; then
        # Update to new configuration file
        cp ${APP_SDK_CFG} ${SDK_CFG}
    fi

    cd ${SDK_PATH}/sdk
    make

    # Check exit status
    check_exit_status

    # If project folder task, copy ELF file and SPK file into project folder
    if [ "${SPRESENSE_HOME}" != "" ]; then
        mkdir -p ${SPRESENSE_HOME}/out
        cp -a ${SDK_PATH}/sdk/nuttx.spk ${SPRESENSE_HOME}/out/${PROJECT_NAME}.nuttx.spk
        cp -a ${SDK_PATH}/sdk/nuttx ${SPRESENSE_HOME}/out/${PROJECT_NAME}.nuttx
    fi
}

# Name: build_worker
# Description: Build ASMP Worker. This function build all ASMP worker in this project folder.
#              Need to configure kernel/SDK before the build.
# Usage: build_worker
function build_worker (){
    # Only for project folder task
    if [ "${SPRESENSE_HOME}" != "" ]; then
        # Move to project folder
        cd ${SPRESENSE_HOME}

        # Setup parameters
        SDKDIR=${SDK_PATH}/sdk
        TOPDIR=${SDK_PATH}/nuttx
        APPDIR=${SPRESENSE_HOME}
        OUTDIR=${SPRESENSE_HOME}/out/worker

        # Check make context
        if [ ! -f ${TOPDIR}/include/nuttx/config.h -o ! -f ${SDKDIR}/bsp/include/sdk/config.h ]; then
            echo "Error: Please configure build first."
            exit 1
        fi

        # Check mkdeps
        if [ ! -f ${TOPDIR}/tools/mkdeps ]; then
            make -C ${TOPDIR}/tools -f Makefile.host mkdeps
        fi

        # Create out directory
        mkdir -p ${OUTDIR}

        for dirname in *
        do
            if [ -f ${dirname}/.worker ]; then
                WORKERDIR=${SPRESENSE_HOME}/${dirname}
                make -C ${WORKERDIR} SDKDIR=${SDKDIR} TOPDIR=${TOPDIR} APPDIR=${APPDIR} OUTDIR=${OUTDIR}

                # Check exit status
                check_exit_status
            fi
        done
    fi
}

# Name: clean_kernel
# Description: Clean NuttX Kernel
# Usage: clean_kernel
function clean_kernel (){
    cd ${SDK_PATH}/sdk
    make cleankernel
}

# Name: clean_sdk
# Description: Clean SDK
# Usage: clean_sdk
function clean_sdk (){
    cd ${SDK_PATH}/sdk
    make clean

    # Check exit status
    check_exit_status

    # If project folder task, remove ELF file and SPK file into project folder
    if [ "${SPRESENSE_HOME}" != "" ]; then
        rm -f ${SPRESENSE_HOME}/out/${PROJECT_NAME}.nuttx.spk
        rm -f ${SPRESENSE_HOME}/out/${PROJECT_NAME}.nuttx
    fi
}

# Name: clean_worker
# Description: Clean Worker
# Usage: clean_worker
function clean_worker (){
    # Only for project folder task
    if [ "${SPRESENSE_HOME}" != "" ]; then
        # Move to project folder
        cd ${SPRESENSE_HOME}

        # Setup parameters
        SDKDIR=${SDK_PATH}/sdk
        TOPDIR=${SDK_PATH}/nuttx
        APPDIR=${SPRESENSE_HOME}
        OUTDIR=${SPRESENSE_HOME}/out/worker

        for dirname in *
        do
            if [ -f ${dirname}/.worker ]; then
                WORKERDIR=${SPRESENSE_HOME}/${dirname}
                make -C ${WORKERDIR} SDKDIR=${SDKDIR} TOPDIR=${TOPDIR} APPDIR=${APPDIR} OUTDIR=${OUTDIR} clean

                # Check exit status
                check_exit_status
            fi
        done
    fi
}

if [ "${ISAPPFOLDER}" == "true" ]; then
    export SPRESENSE_HOME=`pwd`
    PROJECT_NAME=`basename ${SPRESENSE_HOME}`
fi

CMD=${1}

if [ "${CMD}" == "buildkernel" ]; then
    # Build kernel first
    build_kernel
elif [ "${CMD}" == "build" ]; then
    # Build SDK with app
    build_sdk

    # Build ASMP WOrker
    build_worker
elif [ "${CMD}" == "cleankernel" ]; then
    # Clean kernel
    clean_kernel
elif [ "${CMD}" == "clean" ]; then
    # Clean SDK
    clean_sdk

    # Clean Worker
    clean_worker
fi

