import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles
import random
import os
import numpy as np

# Set environment variable to resolve 'x' states
os.environ["COCOTB_RESOLVE_X"] = "ZERO"

# UART and I2S configuration
BAUD_RATE = 115200
CLK_FREQ = 25e6  # 25MHz
BAUD_PERIOD_NS = int(1e9 / BAUD_RATE)

@cocotb.test()
async def test_full_functionality(dut):
    """Complete system test with Tiny Tapeout compatibility"""
    clock = Clock(dut.clk, 40, units="ns")  # 25MHz
    cocotb.start_soon(clock.start())
    
    # Initialize system
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0xFF  # UART idle
    await Timer(1, units="us")
    
    # Release reset and enable
    dut.rst_n.value = 1
    dut.ena.value = 1
    await ClockCycles(dut.clk, 100)  # Wait for initialization
    
    # Test sequence
    await basic_sanity_check(dut)
    await test_waveforms(dut)
    await test_frequency_range(dut)
    await test_adsr_functionality(dut)
    
    dut._log.info("All functionality verified!")

async def basic_sanity_check(dut):
    """Verify I2S clock activity"""
    # Wait for I2S clock to start
    await ClockCycles(dut.clk, 100)
    
    # Check for clock transitions on SCK (uo_out[0])
    transitions = 0
    last_val = dut.uo_out[0].value
    for _ in range(1000):
        await RisingEdge(dut.clk)
        current_val = dut.uo_out[0].value
        if current_val != last_val:
            transitions += 1
        last_val = current_val
    
    assert transitions > 50, f"I2S clock not active (transitions: {transitions})"

async def test_waveforms(dut):
    """Test all waveform types with Tiny Tapeout constraints"""
    waveforms = {
        'square': 0x51,
        'sine': 0x57,
        'triangle': 0x54,
        'sawtooth': 0x53
    }
    
    for name, cmd in waveforms.items():
        await send_uart(dut, cmd)
        await ClockCycles(dut.clk, 500)  # Waveform switching time
        
        # Capture multiple samples for verification
        samples = await capture_samples(dut, 50)
        
        # Skip verification for noise (unpredictable)
        if name != 'noise':
            assert verify_waveform(samples, name), f"{name} verification failed"

def verify_waveform(samples, waveform):
    """Improved waveform verification with statistical checks"""
    if len(samples) < 10:
        return False
        
    # Calculate statistical properties
    mean = np.mean(samples)
    std_dev = np.std(samples)
    unique_vals = len(set(samples))
    
    if waveform == 'square':
        # Should have mostly extreme values
        return std_dev > 80 and unique_vals < 10
    elif waveform == 'sine':
        # Should have Gaussian-like distribution
        return 50 < std_dev < 90 and unique_vals > 30
    elif waveform == 'triangle':
        # Should have linear distribution
        return 40 < std_dev < 70 and unique_vals > 40
    elif waveform == 'sawtooth':
        # Should have many unique values
        return unique_vals > 45 and std_dev > 60
        
    return True

async def test_frequency_range(dut):
    """Test frequency scaling with representative notes"""
    # Only test 3 frequencies to keep test time reasonable
    freqs = {
        'low': 0x30,   # C2 (65.41Hz)
        'mid': 0x5B,   # A4 (440Hz)
        'high': 0x7A   # B6 (1975.53Hz)
    }
    
    periods = []
    for name, cmd in freqs.items():
        await send_uart(dut, cmd)
        await ClockCycles(dut.clk, 1000)  # Frequency settling
        
        # Measure period using WS (uo_out[1])
        await RisingEdge(dut.uo_out[1])
        start_time = cocotb.utils.get_sim_time(units='ns')
        await RisingEdge(dut.uo_out[1])
        end_time = cocotb.utils.get_sim_time(units='ns')
        period_ns = end_time - start_time
        
        dut._log.info(f"Measured {name} period: {period_ns} ns")
        periods.append(period_ns)
    
    # Verify frequency scaling (high freq = short period)
    assert periods[2] < periods[1] < periods[0], "Invalid frequency scaling"

async def test_adsr_functionality(dut):
    """Test ADSR envelope with rotary encoders"""
    await send_uart(dut, 0x54)  # Triangle wave
    await send_uart(dut, 0x5B)  # A4
    await ClockCycles(dut.clk, 500)
    
    # Capture reference amplitude
    ref_samples = await capture_samples(dut, 100)
    ref_peak = max(ref_samples)
    
    # Adjust ADSR parameters
    await rotate_encoder(dut, 0, 5)  # Increase attack
    await rotate_encoder(dut, 2, 3)  # Decrease sustain
    await ClockCycles(dut.clk, 1000)  # ADSR settling
    
    # Capture ADSR amplitude
    env_samples = await capture_samples(dut, 100)
    env_peak = max(env_samples)
    
    # Should see amplitude reduction
    assert env_peak < ref_peak * 0.7, "ADSR not reducing amplitude"

async def send_uart(dut, data):
    """Simulate UART transmission at 115200 baud"""
    # Start bit
    dut.ui_in[0].value = 0
    await Timer(BAUD_PERIOD_NS, units="ns")
    
    # Data bits (LSB first)
    for i in range(8):
        dut.ui_in[0].value = (data >> i) & 0x01
        await Timer(BAUD_PERIOD_NS, units="ns")
    
    # Stop bit
    dut.ui_in[0].value = 1
    await Timer(BAUD_PERIOD_NS, units="ns")
    await ClockCycles(dut.clk, 10)  # Small delay after transmission

async def rotate_encoder(dut, encoder_id, steps):
    """Simulate encoder rotation with quadrature signaling"""
    base_pin = encoder_id * 2
    pattern = [0b00, 0b10, 0b11, 0b01] if steps > 0 else [0b00, 0b01, 0b11, 0b10]
    
    for _ in range(abs(steps)):
        for state in pattern:
            current = dut.uio_in.value
            # Preserve other encoder states
            mask = ~(0b11 << base_pin)
            new_val = (current & mask) | (state << base_pin)
            dut.uio_in.value = new_val
            await ClockCycles(dut.clk, 4)  # Encoder step timing

async def capture_samples(dut, count):
    """Capture I2S output samples from SD line (uo_out[2])"""
    samples = []
    for _ in range(count):
        # Wait for WS transition (start of frame)
        await RisingEdge(dut.uo_out[1])
        # Wait for first SCK edge
        await RisingEdge(dut.uo_out[0])
        
        # Capture 8-bit value (MSB first)
        sample = 0
        for i in range(8):
            await RisingEdge(dut.uo_out[0])
            sample = (sample << 1) | dut.uo_out[2].value.integer
            
        samples.append(sample)
        await ClockCycles(dut.clk, 10)  # Between samples
        
    return samples