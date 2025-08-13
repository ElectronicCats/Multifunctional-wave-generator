import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles
import random
import os

os.environ["COCOTB_RESOLVE_X"] = "ZERO"

# UART and I2S configuration
BAUD_RATE = 115200
CLK_FREQ = 25e6
BAUD_PERIOD_NS = round(1e9 / BAUD_RATE)

async def wait_for_sck(dut):
    """Helper function to wait for I2S clock to start"""
    timeout = 10000
    while timeout > 0:
        await RisingEdge(dut.clk)
        if dut.uo_out[0].value == 1:
            return
        timeout -= 1
    assert False, "I2S clock did not start"

@cocotb.test()
async def test_full_functionality(dut):
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())
    
    # Extended initialization
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0xFF
    dut.uio_in.value = 0
    
    await Timer(2000, units="ns")
    await ClockCycles(dut.clk, 100)
    
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 50)
    dut.ena.value = 1
    
    # Wait for first I2S activity using helper
    await wait_for_sck(dut)
    await ClockCycles(dut.clk, 500)
    
    await basic_sanity_check(dut)
    await test_waveforms(dut)
    await test_frequency_range(dut)
    await test_adsr_functionality(dut)
    
    dut._log.info("All functionality verified!")

async def basic_sanity_check(dut):
    await ClockCycles(dut.clk, 500)
    transitions = 0
    last_val = dut.uo_out[0].value
    for _ in range(1000):
        await RisingEdge(dut.clk)
        current_val = dut.uo_out[0].value
        if current_val != last_val:
            transitions += 1
        last_val = current_val
    assert transitions > 50, f"I2S clock inactive (transitions: {transitions})"

async def test_waveforms(dut):
    waveforms = {
        'square': 0x51,
        'sine': 0x57,
        'triangle': 0x54,
        'sawtooth': 0x53,
        'noise': 0x4E
    }
    
    # Set frequency first
    await send_uart(dut, 0x5B)  # A4
    await ClockCycles(dut.clk, 500)
    
    for name, cmd in waveforms.items():
        await send_uart(dut, cmd)
        await ClockCycles(dut.clk, 500)
        
        samples = await capture_samples(dut, 50)
        
        if name != 'noise':
            assert verify_waveform(samples, name), f"{name} verification failed"

def verify_waveform(samples, waveform):
    if len(samples) < 10: return False
    min_val = min(samples)
    max_val = max(samples)
    peak_to_peak = max_val - min_val
    
    if waveform == 'square':
        return min_val < 50 and max_val > 200 and peak_to_peak > 150
    elif waveform == 'sine':
        return 50 < min_val < 100 and 150 < max_val < 200 and peak_to_peak > 100
    elif waveform == 'triangle':
        return peak_to_peak > 150
    elif waveform == 'sawtooth':
        return min_val < 50 and max_val > 200 and peak_to_peak > 200
    return True

async def test_frequency_range(dut):
    freqs = {'low': 0x30, 'mid': 0x5B, 'high': 0x7A}
    periods = []
    
    await send_uart(dut, 0x54)  # Triangle
    await ClockCycles(dut.clk, 500)
    
    for name, cmd in freqs.items():
        await send_uart(dut, cmd)
        await ClockCycles(dut.clk, 1000)
        
        # Wait for WS edge
        while True:
            await RisingEdge(dut.clk)
            if dut.uo_out[1].value == 1:
                break
        start_time = cocotb.utils.get_sim_time(units='ns')
        while True:
            await RisingEdge(dut.clk)
            if dut.uo_out[1].value == 0:
                break
        end_time = cocotb.utils.get_sim_time(units='ns')
        periods.append(end_time - start_time)
    
    assert periods[2] < periods[1] < periods[0], "Invalid frequency scaling"

async def test_adsr_functionality(dut):
    await send_uart(dut, 0x5B)  # A4
    await send_uart(dut, 0x54)  # Triangle
    await ClockCycles(dut.clk, 1000)
    
    # Reset ADSR
    await rotate_encoder(dut, 0, -10)
    await rotate_encoder(dut, 2, -10)
    await ClockCycles(dut.clk, 1000)
    
    ref_samples = await capture_samples(dut, 100)
    ref_peak = max(ref_samples)
    
    # Apply ADSR
    await rotate_encoder(dut, 0, 5)
    await rotate_encoder(dut, 2, -3)
    await ClockCycles(dut.clk, 2000)
    
    env_samples = await capture_samples(dut, 100)
    env_peak = max(env_samples)
    assert env_peak < ref_peak * 0.7, "ADSR amplitude not reduced"

async def send_uart(dut, data):
    dut.ui_in[0].value = 0  # Start bit
    await Timer(BAUD_PERIOD_NS, units="ns")
    
    # LSB first transmission
    for i in range(8):
        dut.ui_in[0].value = (data >> i) & 0x01
        await Timer(BAUD_PERIOD_NS, units="ns")
    
    dut.ui_in[0].value = 1  # Stop bit
    await Timer(BAUD_PERIOD_NS * 2, units="ns")
    await ClockCycles(dut.clk, 10)

async def rotate_encoder(dut, encoder_id, steps):
    base_pin = encoder_id * 2
    pattern = [0b00, 0b10, 0b11, 0b01] if steps > 0 else [0b00, 0b01, 0b11, 0b10]
    
    for _ in range(abs(steps)):
        for state in pattern:
            current = dut.uio_in.value
            mask = ~(0b11 << base_pin)
            dut.uio_in.value = (current & mask) | (state << base_pin)
            await ClockCycles(dut.clk, 4)

async def capture_samples(dut, count):
    """Capture I2S samples with proper SCK/WS synchronization"""
    samples = []
    for _ in range(count):
        # Wait for WS falling edge
        while True:
            await RisingEdge(dut.clk)
            if dut.uo_out[1].value == 0:
                break
        
        # Capture 8 bits
        sample = 0
        for i in range(8):
            # Wait for SCK rising edge
            while True:
                await RisingEdge(dut.clk)
                if dut.uo_out[0].value == 1:
                    break
            sample = (sample << 1) | (dut.uo_out[2].value & 1)
        samples.append(sample)
    return samples