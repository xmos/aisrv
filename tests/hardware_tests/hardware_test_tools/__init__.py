# Copyright 2020-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

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


APP_NAME = "app_alpr"
XMOS_ROOT = Path('/Users/henk/gitAISERV_default/')
sw_xvf3610 = XMOS_ROOT / "aisrv"
APP_PATH = sw_xvf3610 / APP_NAME
SRC_TEST_PATH = sw_xvf3610 / "tests/src_test"

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
    with pushd(sw_xvf3610):
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
        xmake = sh.Command("xmake")
        xmake([])
        print()
    appname = "app_alpr.xe"
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

def build_data_image(host, which, compatibility_ver=None, bcd_ver=None, config_file=None, crc_error_data=False, verbose=False, INT_version=False):
    config_path = APP_PATH / "data-partition"

    if config_file == None:
        #Note bcd_ver is ignored for INT
        config_file = config_path / "hardware_test.json"
        if INT_version:
            #INT version just copy the boggo config json - no changes needed
            with open(config_path / "i2s_slave.json") as file_in:
                with open(config_file, "w") as file_out:
                    file_out.write(file_in.read())

        else: #UA version, create a txt command file and insert into copy of json
            with open(config_path / "usb_adaptive.json") as file_in:
                with open(config_file, "w") as file_out:
                    contents = file_in.read()
                    contents = re.sub(r"\n\s+\"item_files\":\s*\[\n\s+\]",
                                      "\n    \"item_files\": [\n        {\n" +
                                      "            \"path\": \"hardware_test_usb_params.txt\",\n" +
                                      "            \"comment\": \"\"\n" +
                                      "        }\n    ]", contents)
                    contents = re.sub(r"\n\s+\"item_files\":\s*\[\n",
                                      "\n    \"item_files\": [\n        {\n" +
                                      "            \"path\": \"hardware_test_usb_params.txt\",\n" +
                                      "            \"comment\": \"\"\n" +
                                      "        },\n", contents)
                    file_out.write(contents)
            with open(config_path / "input" / "xmos_usb_params.txt") as file_in:
                with open(config_path / "hardware_test_usb_params.txt", "w") as file_out:
                    file_out.write("SET_MIC_START_STATUS 1\n") # SET_MIC_START_STATUS comes before SET_USB_SERIAL_NUMBER
                    if bcd_ver != None:
                        file_out.write("SET_USB_BCD_DEVICE %d\n" % bcd_ver) # bcdDevice comes first so it's before USB start command
                    file_out.write(file_in.read())

    sh_print = lambda x: print_output(x, verbose)

    extra_args = []
    if compatibility_ver:
        extra_args.extend(["--force-compatibility-version", compatibility_ver])
    if verbose:
        extra_args.append('--verbose')
    sh.Command(sys.executable)( # Python executable otherwise you get FileNotFoundError
        [config_path / "xvf3610_data_partition_generator.py",
         "--vfctrl-host-bin-path", host["vfctrl_json"],
         "--dpgen-host-bin-path", host["data_partition_generator"],
         config_file] + extra_args,
        _out=sh_print)
    if not compatibility_ver:
        compatibility_ver = get_firmware_version()
    return config_path / "output" / ("data_partition_%s_%s_v%s.bin" % (which, Path(config_file).stem, compatibility_ver.replace(".", "_")))


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


    #TODO - ONCE XUD IS WORKING RELIABLY THEN WE CAN REMOVE CALLS TO THIS - https://github.com/xmos/lib_xud/issues/244
def ensure_usb_device_is_up(host, adapter_id=None):
    #This loop keeps resetting the target until we can successfully see it in lsusb and issue a command 
    vfctrl = host['vfctrl_usb'].bake('--no-check-version')

    dev_found = False 
    vfctl_success = False
    num_resets = 0

    while True:
        #Note on linux you don't get the full product string so do VID:PID as search
        dev_found = "20b1:0016" in sh.lsusb()
        try:
            vfctrl.get_run_status()
            vfctl_success = True
        except:
            vfctl_success = False

        if dev_found and vfctl_success:
            break;

        if num_resets > 10:
            raise HardwareTestException(f"Could not enumerate after {num_resets} attempts to reset. Giving up....\n")


        print(f"+++++RESETTING DUE TO: dev_found-{dev_found}, vfctl_success-{vfctl_success}", file=sys.stderr)
        reset_target(adapter_id)
        num_resets += 1
        verbose_sleep(10)
   
    print(f"+++++SUCCESSFUL ENUMERATION AFTER {num_resets} resets", file=sys.stderr)

    

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

def get_xplay_version():
    try:
        output = str(sh.xplay("--version")) # force from sh.RunningCommand to dump of standard output
    except sh.ErrorReturnCode_1:
        output = "1.0" # heuristic: if it does not understand version command it must be 1.0
    return re.search(r"\b\d+\.\d+\b", output).group(0)


def find_alsa_device(alsa_output, vendor_str_search="Adaptive"):
    """ Looks for the vendor_str_search in aplay or arecord output """

    vendor_str_found = False
    for line in alsa_output:
        if vendor_str_search not in line:
            continue
        vendor_str_found = True
        card_num = int(line[len('card '):line.index(':')])
        dev_str = line[line.index('device'):]
        dev_num = int(dev_str[len('device '):dev_str.index(':')])
    if not vendor_str_found:
        raise HardwareTestException(
            f'Could not find "{vendor_str_search}"" in alsa output:\n'
            f"{alsa_output}"
        )
    return card_num, dev_num

def find_aplay_device(vendor_str_search="Adaptive"):
    aplay_out = sh.aplay("-l")
    return find_alsa_device(aplay_out, vendor_str_search)


def find_arecord_device(vendor_str_search="Adaptive"):
    arecord_out = sh.arecord("-l")
    return find_alsa_device(arecord_out, vendor_str_search)

def find_xplay_device_idx(product_string, in_out_string):
    XPLAY_REQUIRED_VERSION = "1.2"
    if get_xplay_version() != XPLAY_REQUIRED_VERSION:
        raise HardwareTestException("Did not detect xplay version %s" % XPLAY_REQUIRED_VERSION)
    xplay_device_idx = None
    lines = sh.xplay("-l")
    for line in lines:
        found = re.search(r"Found Device (\d): %s.*%s" % (product_string, in_out_string), line)
        if found:
            xplay_device_idx = found.group(1)
    if xplay_device_idx is None:
        raise HardwareTestException(
            f'Could not find "{product_string}" in xplay output:\n'
            f"{lines}")
    return xplay_device_idx

class audio_player:
    def __init__(self, audio_file, device_string, rate):
        if platform == "darwin":
            self.dev = find_xplay_device_idx(device_string, "/[^0][0-9]*out") # non-zero output channel count
        else:
            self.dev = find_aplay_device(device_string)
        self.play_file = audio_file
        self.process = None
        self.rate = rate

    def play_background(self):
        if platform == "darwin":
            cmd = f"-p {self.play_file} -r {self.rate} -d {self.dev}"
            self.process = sh.xplay(cmd.split(), _bg=True, _bg_exc=False)
        else:
            self.process = sh.aplay(f"{self.play_file} -r {self.rate} -D hw:{self.dev[0]},{self.dev[1]}".split(), _bg=True, _bg_exc=False)
            # _bg_exc=False fixes an uncatchable exception https://github.com/amoffat/sh/issues/399

    def end_playback(self):
        if not self.process._process_completed:
            self.process.terminate()

            if platform == "darwin":
                try: # see sh module issue 399
                    self.process.wait()
                except sh.SignalException_SIGTERM:
                    pass

    def wait_to_complete(self):
        self.process.wait()

    def play_to_completion(self):
        self.play_background()
        self.wait_to_complete()

class audio_recorder:
    def __init__(self, audio_file, device_string, rate, start_trim_s=0.0, end_trim_s=0.0):
        if platform == "darwin":
            self.dev = find_xplay_device_idx(device_string, " [^0][0-9]*in/") # non-zero input channel count
        else:
            self.dev = find_arecord_device(device_string)
        self.process = None
        self.tmp_wav_file = "tmp.wav"
        self.record_file = audio_file
        self.rate = rate
        self.start_trim_s = start_trim_s
        self.end_trim_s = end_trim_s

    def record_background(self):
        if platform == "darwin":
            cmd = f"-R {self.record_file} -r {self.rate} -b 32 -d {self.dev}"
            self.process = sh.xplay(cmd.split(), _bg=True, _bg_exc=False) # This runs background
        else:
            self.process = sh.arecord(f"{self.tmp_wav_file} -f S32_LE -c 2 -r {self.rate} -D plughw:{self.dev[0]},{self.dev[1]}".split(), _bg=True, _bg_exc=False)

    def end_recording(self):
        self.process.terminate()
        if platform == "darwin":
            try: # see sh module issue 399
                self.process.wait()
            except sh.SignalException_SIGTERM:
                pass
            # xplay leaves the header unpopulated on terminate so fix it
            sh.sox(f"--ignore-length {self.record_file} {self.tmp_wav_file}".split())
        capture_len = float(sh.soxi(f"-D {self.tmp_wav_file}".split()))
        assert capture_len > (self.start_trim_s + self.end_trim_s), f"Not enough recorded audio: {capture_len}s, {self.start_trim_s + self.end_trim_s}s needed"
        sh.sox(f"{self.tmp_wav_file} {self.record_file} trim {self.start_trim_s} {-self.end_trim_s}".split())

def record_and_play(play_file, play_device, record_file, record_device, rate=None, play_rate=None, rec_rate=None, trim_ends_s=0.0):
    if play_rate is None and rec_rate is None:
        play_rate = rec_rate = rate
    player = audio_player(play_file, play_device, play_rate)
    recorder = audio_recorder(record_file, record_device, rec_rate, start_trim_s=trim_ends_s, end_trim_s=trim_ends_s)
    recorder.record_background()
    print("Recording and playing audio...")
    player.play_to_completion()
    recorder.end_recording()
    # Belt and braces as xplay doesn't alway exit nicely
    if platform == "darwin":
        try:
            sh.killall(" xplay")
        except sh.ErrorReturnCode_1:
            pass
            # Nothing to kill

def play_and_record(play_file, play_device, record_file, record_device, rate=None, play_rate=None, rec_rate=None, trim_ends_s=0.0):
    if play_rate is None and rec_rate is None:
        play_rate = rec_rate = rate
    player = audio_player(play_file, play_device, play_rate)
    recorder = audio_recorder(record_file, record_device, rec_rate, start_trim_s=trim_ends_s, end_trim_s=trim_ends_s)
    player.play_background()
    recorder.record_background()
    print("Playing and recording audio...")
    player.wait_to_complete()
    recorder.end_recording()
    # Belt and braces as xplay doesn't alway exit nicely
    if platform == "darwin":
        try:
            sh.killall(" xplay")
        except sh.ErrorReturnCode_1:
            pass
            # Nothing to kill

def prepare_4ch_wav_for_harness(input_file_name, output_file_name = "output.wav"):
    gen_pdm_and_pack_ref(input_file_name, output_file_name)
    return output_file_name


def correlate_and_diff(output_file, input_file, out_ch_start_end, in_ch_start_end, skip_seconds_start, skip_seconds_end, tol, corr_plot_file=None, verbose=False):
    rate_usb_out, data_out = scipy.io.wavfile.read(output_file)
    rate_usb_in, data_in = scipy.io.wavfile.read(input_file)
    print(f"rate_usb_in={rate_usb_in}, rate_usb_out={rate_usb_out}")
    if rate_usb_out != rate_usb_in:
        assert False, "input and output file rates are not equal"

    #TODO handle dtypes not being same
    assert data_in.dtype == data_out.dtype, "input and output data_type are not same"

    assert out_ch_start_end[1]-out_ch_start_end[0] == in_ch_start_end[1]-in_ch_start_end[0], "input and output files have different channel nos."


    skip_samples_start = int(rate_usb_out * skip_seconds_start)
    skip_samples_end = int(rate_usb_out * skip_seconds_end)
    data_in = data_in[:,in_ch_start_end[0]:in_ch_start_end[1]+1]
    data_out = data_out[:,out_ch_start_end[0]:out_ch_start_end[1]+1]

    data_in_small = data_in[skip_samples_start:64000+skip_samples_start, :].astype(np.float64)
    data_out_small = data_out[skip_samples_start:64000+skip_samples_start, :].astype(np.float64)

    #TODO find correlations channel-wise
    corr = scipy.signal.correlate(data_in_small[:, 0], data_out_small[:, 0], "full")
    delay = (corr.shape[0] // 2) - np.argmax(corr)
    print(f"delay = {delay}")

    if corr_plot_file != None:
        plt.plot(corr)
        plt.savefig(corr_plot_file)
        plt.clf()
    delay_orig = delay

    #assert if output is ahead of the input
    #assert delay >= 0, "scipy.signal.correlate indicates output ahead of input!"
    #TODO figure out why delay is negative in the first place
    if delay < 0:
        temp = data_in
        data_in = data_out
        data_out = temp
        delay = -delay


    data_size = min(data_in.shape[0], data_out.shape[0])
    data_size -= skip_samples_end

    print(f"compare {data_size - skip_samples_start} samples")

    if verbose:
        for i in range(100):
            print("%d, %d"%(data_in[skip_samples_start+i, 0], data_out[skip_samples_start + delay+i, 0]))

    num_channels = out_ch_start_end[1]-out_ch_start_end[0]+1
    all_close = True
    for ch in range(num_channels):
        print(f"comparing ch {ch}")
        close = np.isclose(
                    data_in[skip_samples_start : data_size - delay, ch],
                    data_out[skip_samples_start + delay : data_size, ch],
                    atol=tol,
                )
        print(f"ch {ch}, close = {np.all(close)}")

        if verbose:
            int_max_idxs = np.argwhere(close[:] == False)
            print("shape = ", int_max_idxs.shape)
            print(int_max_idxs)
            if np.all(close) == False:
                if int_max_idxs[0] != 0:
                    count = 0
                    for i in int_max_idxs:
                        if count < 100:
                            print(i, data_in[skip_samples_start+i, ch], data_out[skip_samples_start + delay + i, ch])
                            count += 1

        diff = np.abs((data_in[skip_samples_start : data_size - delay, ch]) - (data_out[skip_samples_start + delay : data_size, ch]))
        max_diff = np.amax(diff)
        print(f"max diff value is {max_diff}")
        all_close = all_close & np.all(close)

    print(f"all_close: {np.all(all_close)}")
    return all_close, delay_orig

# This function finds all of the zero crossings and then does and RMS calculation for each cycle
# It to indicate a stretched wave, amplitude change or signal dropout
# This only really works for sine waves and uses time domain techniques
# Note num_half_cycles_per_rms which takes account of (kind of) aliasing of the time domain,
# for example when we see a 3kHz sine wave sampled at 16kHz. You get patter repeating every 3 whole cycles
# In the frequency domain it's all fine but in time domain you need to expect that the PCM samples will
# vary over 3 cycles in a repeated pattern.
def analyse_sine_rms(input_file, in_channel, num_half_cycles_per_rms, verbose=False):
    rate_usb_in, data_in = scipy.io.wavfile.read(input_file)
    audio = data_in[:,in_channel].astype(np.float64) / 2**31

    print(f"Computing stats on {audio.shape[0]} samples")

    def get_zero_crossings(array):
        sdiff = np.diff(np.sign(array))
        rising_1 = (sdiff == 2)
        rising_2 = (sdiff[:-1] == 1) & (sdiff[1:] == 1)
        rising_all = rising_1
        rising_all[1:] = rising_all[1:] | rising_2

        falling_1 = (sdiff == -2) #the signs need to be the opposite
        falling_2 = (sdiff[:-1] == -1) & (sdiff[1:] == -1)
        falling_all = falling_1
        falling_all[1:] = falling_all[1:] | falling_2

        indices_rising = np.where(rising_all)[0]
        indices_falling = np.where(falling_all)[0]
        indices_both = np.where(rising_all | falling_all)[0]

        return indices_both

    zero_crossings = get_zero_crossings(audio)
    if zero_crossings.shape[0] == 0:
        return 0.0, 0.0, 0.0, 0.0

    num_samples = zero_crossings[-num_half_cycles_per_rms] - zero_crossings[0]
    num_samps_per_half_cycle = (num_samples/(zero_crossings.shape[0]-num_half_cycles_per_rms))
    measured_freq = rate_usb_in/2/num_samps_per_half_cycle

    if verbose:
        print(f"Zero crossings: {zero_crossings.shape[0]}, freq: {measured_freq}")
    rms_array = []

    # Now calculate the RMS for each half wave in turn. Takes about 5s per miute of audio
    for wave_count in range(0,zero_crossings.shape[0] - 1, num_half_cycles_per_rms):
        idx0 = zero_crossings[wave_count]
        idx1 = zero_crossings[wave_count + 1]
        rms = np.sqrt(np.mean(np.absolute(audio[idx0:idx1])**2))
        # print(idx0, idx1, audio[idx0:idx1], rms)
        rms_array.append(rms)
    rms_array = np.array(rms_array)

    if verbose:
        print(f"argmin: {np.argmin(rms_array)}, argmax: {np.argmax(rms_array)}")
        print(f"num_samps_per_half_cycle: {num_samps_per_half_cycle}")
        print(rms_array.shape, rms_array)
        cycles = 3
        half_cycles = cycles * 2
        for idx in range(0,100,half_cycles):
            print(np.sum(rms_array[idx:idx+half_cycles]))
        print(audio)
        print(zero_crossings)


    return rms_array.mean(), rms_array.max(), rms_array.min(), measured_freq

def is_sine_good(input_file, channel, expected_hz, sine_peak_amplitude, rtol=0.0001, rtol_gain=0.1, verbose=False, num_half_cycles_per_rms=1):
    # Note we don't use abs_tol as numbers are never normally close to zero so leave as default zero
    expected_rms = sine_peak_amplitude / math.sqrt(2)

    if verbose:
        print(f"Analysing file {input_file}, channel {channel}")
    mean_rms, max_rms, min_rms, measured_freq = analyse_sine_rms(input_file, channel, num_half_cycles_per_rms, verbose=False)

    if verbose:
        print(f"Expected RMS: {expected_rms}, mean RMS: {mean_rms}, max RMS: {max_rms}, min RMS: {min_rms}")
        print(f"Expected Hz: {expected_hz}, Actual Hz: {measured_freq}")
    dropout_ok = math.isclose(mean_rms, min_rms, rel_tol=rtol)
    injected_noise_ok = math.isclose(mean_rms, max_rms, rel_tol=rtol)
    volume_flat = dropout_ok or injected_noise_ok
    gain_ok = math.isclose(mean_rms, expected_rms, rel_tol=rtol_gain)
    frequency_ok = math.isclose(expected_hz, measured_freq, rel_tol=rtol)

    if verbose:
        print(f"Dropout OK: {dropout_ok}")
        print(f"Injected noise OK: {injected_noise_ok}")
        print(f"Volume flat OK: {volume_flat}")
        print(f"Gain OK: {gain_ok}, ratio: {mean_rms/expected_rms}")
        print(f"Frequency OK: {frequency_ok}")

    return dropout_ok and injected_noise_ok and gain_ok

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
        

class xvf3610_test_rig(remote_pi_access):
    def __init__(self, UA=False):
        self.UA = UA
        dest_working_dir = "~/xvf3610_hw_test"

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
    def enable_pi_to_3610_signals(self, disable=False):
        i2c_expander_addr = 0x20
        p1_dir_reg = 0x7 #Direction register for port 1
        direction_reg_mask_p1 = 0b11010111  #set X, mute, i2s_oe_n, spi_oe_n, mclk_oe_n, tp3, tp2, boot_sel
                                            #set high for high impedance, low to drive from pi to 3610

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
        release_zip = "XVF3610_UA.zip" if self.UA else "XVF3610_INT.zip"
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
  
