import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles
import random
import os

# Set environment variable to resolve 'x' states
os.environ["COCOTB_RESOLVE_X"] = "ZERO"

# UART and I2S configuration
BAUD_RATE = 115200
CLK_FREQ = 25e6  # 25MHz
BAUD_PERIOD_NS = round(1e9 / BAUD_RATE)  # Fixed: proper rounding

@cocotb.test()
async def test_full_functionality(dut):
    clock = Clock(dut.clk, 40, units="ns")  # 25MHz
    cocotb.start_soon(clock.start())
    
    # Initialize system
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0xFF  # UART idle
    await Timer(500, units="ns")
    await ClockCycles(dut.clk, 10)  # Reset sync cycles
    
    # Release reset and enable
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)  # Post-reset stabilization
    dut.ena.value = 1
    await ClockCycles(dut.clk, 100)  # Initialization
    
    # Test sequence
    await basic_sanity_check(dut)
    await test_waveforms(dut)
    await test_frequency_range(dut)
    await test_adsr_functionality(dut)
    
    dut._log.info("All functionality verified!")

async def basic_sanity_check(dut):
    await ClockCycles(dut.clk, 100)
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
        'sawtooth': 0x53
    }
    
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
    unique_vals = len(set(samples))
    peak_to_peak = max_val - min_val
    
    if waveform == 'square':
        return min_val < 50 and max_val > 200 and unique_vals < 10
    elif waveform == 'sine':
        return 50 < min_val < 100 and 150 < max_val < 200 and unique_vals > 30
    elif waveform == 'triangle':
        return peak_to_peak > 150 and unique_vals > 40
    elif waveform == 'sawtooth':
        return unique_vals > 45 and min_val < 50 and max_val > 200
    return True

async def test_frequency_range(dut):
    freqs = {'low': 0x30, 'mid': 0x5B, 'high': 0x7A}
    periods = []
    for name, cmd in freqs.items():
        await send_uart(dut, cmd)
        await ClockCycles(dut.clk, 1000)
        await RisingEdge(dut.uo_out[1])
        start_time = cocotb.utils.get_sim_time(units='ns')
        await RisingEdge(dut.uo_out[1])
        end_time = cocotb.utils.get_sim_time(units='ns')
        periods.append(end_time - start_time)
    assert periods[2] < periods[1] < periods[0], "Invalid frequency scaling"

async def test_adsr_functionality(dut):
    await send_uart(dut, 0x54)  # Triangle
    await send_uart(dut, 0x5B)  # A4
    await ClockCycles(dut.clk, 500)
    
    # Reset ADSR parameters
    await rotate_encoder(dut, 0, -10)  # Reset attack
    await rotate_encoder(dut, 2, -10)  # Reset sustain
    await ClockCycles(dut.clk, 1000)
    
    ref_samples = await capture_samples(dut, 100)
    ref_peak = max(ref_samples)
    
    await rotate_encoder(dut, 0, 5)  # Attack up
    await rotate_encoder(dut, 2, -3)  # Sustain down
    await ClockCycles(dut.clk, 1000)
    
    env_samples = await capture_samples(dut, 100)
    env_peak = max(env_samples)
    assert env_peak < ref_peak * 0.7, "ADSR amplitude not reduced"

async def send_uart(dut, data):
    dut.ui_in[0].value = 0  # Start bit
    await Timer(BAUD_PERIOD_NS, units="ns")
    for i in range(8):  # LSB first
        dut.ui_in[0].value = (data >> i) & 0x01
        await Timer(BAUD_PERIOD_NS, units="ns")
    dut.ui_in[0].value = 1  # Stop bit
    await Timer(BAUD_PERIOD_NS, units="ns")
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
    samples = []
    for _ in range(count):
        await RisingEdge(dut.uo_out[1])  # WS edge
        await RisingEdge(dut.uo_out[0])  # SCK edge
        sample = 0
        for i in range(8):  # LSB-first capture
            await RisingEdge(dut.uo_out[0])
            sample = (sample >> 1) | (dut.uo_out[2].value.integer << 7)
        samples.append(sample)
        await ClockCycles(dut.clk, 10)
    return samples