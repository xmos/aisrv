# Copyright 2020-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.


# This is all copied from xvf3610
# A lot of stuff in here is unnecessary, like the rPI stuff
# But... if we want to automatically test the SPI Interface that may come in useful
# nothing has been deleted...

import os
import sh
import sys
import re
from contextlib import contextmanager
import numpy as np
import matplotlib.pyplot as plt
from time import sleep
from pathlib import Path
import random
from sys import platform
import math
import asyncio, asyncssh


APP_NAME = "app_testing"
XMOS_ROOT = Path('/Users/henk/gitAISERV_default/')
sw_aisrv = XMOS_ROOT / "aisrv"
APP_PATH = sw_aisrv / APP_NAME
SRC_TEST_PATH = sw_aisrv / "tests/src_test"

host_utility_locations = {}

class HardwareTestException(Exception):
    """ Exception class for Hardware Test errors """
    pass

@contextmanager
def pushd(new_dir):
    last_dir = os.getcwd()
    os.chdir(new_dir)
    try:
        yield
    finally:
        os.chdir(last_dir)

def get_firmware_version():
    with pushd(sw_aisrv):
        changelog_file = Path("CHANGELOG.rst")
        assert changelog_file.is_file()
        with open(changelog_file) as c:
            return c.read().splitlines()[3].strip()

def get_tools_version():
    xcc_s = re.search(r"Compiler version: (\d+\.\d+\.\d+)", str(sh.xcc("--version")))
    if xcc_s:
        return xcc_s.group(1)
    else:
        print("Warning: XCC version not found")
        return ""

def print_output(x, verbose):
    if verbose:
        print(x, end="")
    else:
        print(".", end="", flush=True)


def verbose_sleep(seconds: int):
    for i in range(seconds):
        print(".", end="", flush=True)
        sleep(1)
    print()


def prepare_host(extra_utilities = []):
    return build_host(extra_utilities)


def prepare_firmware(host, xe_path=None, data_partition_image=None, config="usb_adaptive", build_flags="", adapter_id=None):
    rand_str = str(random.randint(1, 4096))
    if xe_path is None:
        xe_path = build_firmware(False, build_flags + f" --message {rand_str}", config=config)
    run_firmware(xe_path, data_partition_image, adapter_id=adapter_id)
    if host:
        check_bld_message(host, rand_str)

def build_host(extra_utilities):
    binaries = {}
    for utility in extra_utilities:
        sh_print = lambda x: print_output(x, False)
        CMakeCache_file = host_utility_locations[utility] / "CMakeCache.txt"
        if CMakeCache_file.is_file():
            sh.rm(CMakeCache_file)
        print("Building %s..." % utility)
        with pushd(host_utility_locations[utility]):
            if utility != "vfctrl_json":
                sh.cmake(".")
            else:
                sh.cmake([".", "-DJSON=ON"])
            sh.make(_out=sh_print)
            print()
        path = host_utility_locations[utility] / "bin" / utility
        assert path.is_file()
        binaries[utility] = sh.Command(str(path))
    return binaries

def build_firmware(verbose=False, build_flags="", config="usb_adaptive", blank=False):
    if blank:
        return None
    sh_print = lambda x: print_output(x, True)
    sh_print_err = lambda x: print_output(x, True)
    print("Building firmware...")
    with pushd(APP_PATH):
        sh.xmake([], _out=sh_print, _err = sh_print_err)
        print()
    appname = "app_testing.xe"
    return APP_PATH / "bin" / appname

def build_src_xe(verbose=False):
    sh_print = lambda x: print_output(x, verbose)
    print("Building src xe...")
    with pushd(SRC_TEST_PATH):
        args = f"configure clean build"
        sh.waf(args.split(), _out=sh_print)
        print()
    return SRC_TEST_PATH / "bin/src_test.xe"


def run_firmware(xe_path, data_partition_image=None, adapter_id=None):
    if data_partition_image != None:
        print("Baking data partition")
        xflash_bake("--boot-partition-size", "0x100000", "--data", data_partition_image, xe_path)

    sh.xrun(xe_path)

    print("Waiting for firmware to boot...")
    verbose_sleep(2)

def erase_flash(xn_file, adapter_id=None):
    print("Calling xflash --erase-all...")
    if adapter_id:
        sh.xflash("--adapter-id", adapter_id, "--erase-all", "--target-file", xn_file)
    else:
        sh.xflash("--erase-all", "--target-file", xn_file)


def dfu_add_suffix(host, boot_bin, data_bin):
    boot_dfu = boot_bin + ".dfu"
    data_dfu = data_bin + ".dfu"
    host['dfu_suffix_generator']("0x20B1", "0x0016", "0x0001", boot_bin, boot_dfu)
    host['dfu_suffix_generator']("0x20B1", "0x0016", "0x0001", data_bin, data_dfu)
    return boot_dfu, data_dfu


def dfu_write_upgrade(host, boot_dfu, data_dfu, skip_boot_image=False, verbose=False):
    print("Writing upgrade...")
    sh_print = lambda x: print_output(x, verbose)
    extra_args = []
    if skip_boot_image:
        extra_args += ['--skip-boot-image']
    if not verbose:
        extra_args += ['--quiet']
    host['dfu_usb'](extra_args + ["write_upgrade", boot_dfu, data_dfu], _out=sh_print)
    print("Waiting for firmware to reboot...")
    verbose_sleep(15)
    

def check_bld_message(host_bin_paths, expected_msg, vfctrl_flags="", adapter_id=None):
    print("Checking firware version...")

    msg = host_bin_paths["vfctrl_usb"].bake("--no-check-version").get_bld_msg().strip()
    if f"GET_BLD_MSG: {expected_msg}" not in msg:
        raise HardwareTestException(
            f"'{expected_msg}' not found in build message. Build message:\n{msg}"
        )

def check_bld_message_INT(testrig, expected_msg, vfctrl_flags=""):
    print("Checking firware version...")
    dest_working_dir = testrig.dest_working_dir
    msg = testrig.cmd(f"{dest_working_dir}/host/Pi/bin/vfctrl_i2c --no-check-version get_bld_msg").strip()
    if f"GET_BLD_MSG: {expected_msg}" not in msg:
        raise HardwareTestException(
            f"'{expected_msg}' not found in build message. Build message:\n{msg}"
        )

def get_app_directory():
    return str(APP_PATH)

def reset_target(adapter_id=None):
    print("Resetting target...")

    if adapter_id:
        sh.xgdb('-batch', '-ex', f'connect --adapter_id {adapter_id} --reset-to-mode-pins', '-ex', 'detach')

    else:
        sh.xgdb('-batch', '-ex', 'connect --id 0 --reset-to-mode-pins', '-ex', 'detach')

    # alternative way to reboot using DFU utility
    #host['dfu_usb'].reboot()

    print("Waiting for firmware to boot...")
    verbose_sleep(15)


#Class to manipulate a remote RPI using ssh/scp commands
# First add the host public key to the target's allowed SSH keys. Note you must enable SSH on the target. 
# https://www.raspberrypi.org/documentation/remote-access/ssh/passwordless.md
class remote_pi_access:
    def __init__(self, server_ip, dest_working_dir, username="pi"):
        self.username           = username
        self.server_ip          = server_ip
        self.dest_working_dir   = dest_working_dir

    def _make_scp_remote_path(self, file):
        path = self.server_ip + ":" + self.dest_working_dir + "/" + file
        return path

    def _do_scp(self, src, dst):
        async def run_client():
            await asyncssh.scp(src, dst, username=self.username)
        try:
            asyncio.get_event_loop().run_until_complete(run_client())
        except (OSError, asyncssh.Error) as exc:
            print('SFTP operation failed: ' + str(exc), file=sys.stderr)

    def cmd(self, cmd, verbose=True, _bg=False, timeout_s=None):
        if verbose:
            print(f'Connecting to "{self.server_ip}" with command "{cmd}"')

        async def run_client():
            async with asyncssh.connect(self.server_ip, username=self.username) as conn:
                return await conn.run(cmd, check=True, timeout=timeout_s)

        loop = asyncio.get_event_loop()
        try:
            result = loop.run_until_complete(run_client())
            if verbose:
                print("Command returned:",result.stdout)
            return result.stdout
        except Exception as exc:
            print('SSH connection failed executing:', cmd, file=sys.stderr)
            print('OS Error code:', type(exc), file=sys.stderr) # This is a bit messy but for some reason cannot print exc, but this reports type of exc in error

    # send a file from the host to the remote device. If no dst is specified then the src file name is used
    def send_file(self, src, dst=None):
        if not dst:
            dst = self._make_scp_remote_path(src)
        else:
            dst = self._make_scp_remote_path(dst)
        self._do_scp(src, dst)

    # fetch a file from the the remote device to the host. If no src is specified then the dst file name is used
    def fetch_file(self, dst, src=None):
        if not src:
            src = self._make_scp_remote_path(dst)
        else:
            src = self._make_scp_remote_path(src)
        self._do_scp(src, dst)
        

class aisrv_test_rig(remote_pi_access):
    def __init__(self, UA=False):
        self.UA = UA
        dest_working_dir = "~/aisrv_hw_test"

    def get_adapter_id(self):
        return self.adapter_id

    def get_dest_working_dir(self):
        return self.dest_working_dir

    def vfctrl(self, cmd, verbose=True):
        dest_working_dir = self.dest_working_dir
        if self.UA:
            cmd = f"sudo {dest_working_dir}/host/Pi/bin/vfctrl_usb -n {cmd}"
        else:
            cmd = f"{dest_working_dir}/host/Pi/bin/vfctrl_i2c -n {cmd}"
        return self.cmd(cmd, verbose=verbose, timeout_s=5)

    #Assumes signals have already been setup before hand
    #i.e. I2S and MCLK driving from Pi for INT usage. Note we don't touch spi_oe_n, just i2s_oe_n & mclk_oe_n
    def enable_pi_to_aisrv_signals(self, disable=False):
        i2c_expander_addr = 0x20
        p1_dir_reg = 0x7 #Direction register for port 1
        direction_reg_mask_p1 = 0b11010111  #set X, mute, i2s_oe_n, spi_oe_n, mclk_oe_n, tp3, tp2, boot_sel
                                            #set high for high impedance, low to drive from pi to aisrv

        cmd = f"sudo i2cget -y 1 {i2c_expander_addr} {p1_dir_reg} b"
        val = self.cmd(cmd, verbose=False)
        val = int(val, 16)
        print(f"Port 1 direction reg before val: {val}")

        if disable:
            val |= (~direction_reg_mask_p1) & 0xff
        else:
            val &= direction_reg_mask_p1
        print(f"Port 1 direction after val: {val}, disable: {disable}")

        cmd = f"sudo i2cset -y 1 {i2c_expander_addr} {p1_dir_reg} {val} b"
        self.cmd(cmd, verbose=False)


    def prepare_host_remote_pi(self):
        # Add stuff in here about getting the host bins in place in /hardware_tests
        release_zip = "aisrv_UA.zip" if self.UA else "aisrv_INT.zip"
        remote_pi_access.cmd(self, f"mkdir -p {self.dest_working_dir}")
        #Now run a background audio stream to force I2S clock 
        if not self.UA:
            remote_pi_access.cmd(self, "nohup aplay -c 2 -f S32_LE -r 48000 /dev/zero &> /dev/null &")
        remote_pi_access.send_file(self, release_zip)
        remote_pi_access.cmd(self, f"unzip -o {self.dest_working_dir}/{release_zip} -d {self.dest_working_dir}")
        # print("***CONSTRUCTOR")

    def finalise_host_remote_pi(self):
        if not self.UA:
            ret = remote_pi_access.cmd(self, "killall -q aplay") #A bit brutal but works
        remote_pi_access.cmd(self, f"rm -rf {self.dest_working_dir}")
        # print("***DESTRUCTOR")
  
