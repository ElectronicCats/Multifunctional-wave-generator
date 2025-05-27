import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_full_functionality(dut):
    """Complete system test without external dependencies"""
    clock = Clock(dut.clk, 40, units="ns")  # 25MHz
    cocotb.start_soon(clock.start())
    
    # Initialize system
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0xFF  # UART idle
    await Timer(1, units="us")
    
    # Release reset
    dut.rst_n.value = 1
    dut.ena.value = 1
    await Timer(10, units="us")
    
    # Execute test sequence
    await basic_sanity_check(dut)
    await test_waveforms(dut)
    await test_frequency_range(dut)
    await test_adsr_functionality(dut)
    
    dut._log.info("All functionality verified!")

async def basic_sanity_check(dut):
    """Verify basic I2S clock activity"""
    sck_values = []
    for _ in range(1000):
        sck_values.append(dut.uo_out[0].value)
        await Timer(100, units="ns")
    
    transitions = sum(1 for a,b in zip(sck_values, sck_values[1:]) if a != b)
    assert transitions > 100, "I2S clock not active"

async def test_waveforms(dut):
    """Test all waveform types"""
    waveforms = {
        'square': 0x51,
        'sine': 0x57,
        'triangle': 0x54,
        'sawtooth': 0x53
    }
    
    for name, cmd in waveforms.items():
        await send_uart(dut, cmd)
        await Timer(20, units="us")  # Settling time
        
        samples = await capture_samples(dut, 500)
        assert verify_waveform(samples, name), f"{name} verification failed"

def verify_waveform(samples, waveform):
    """Waveform analysis using pure Python"""
    # Build histogram
    hist = {}
    for val in samples:
        hist[val] = hist.get(val, 0) + 1
    
    if waveform == 'square':
        return (hist.get(0, 0) > len(samples)*0.3 and \
               (hist.get(255, 0) > len(samples)*0.3)
    
    if waveform == 'sine':
        # Check bell curve properties
        mean = sum(samples)/len(samples)
        variance = sum((x-mean)**2 for x in samples)/len(samples)
        return 80 < variance < 120 and 100 < mean < 150
    
    if waveform == 'triangle':
        # Check linear distribution
        sorted_samples = sorted(samples)
        q1 = sorted_samples[len(samples)//4]
        q3 = sorted_samples[3*len(samples)//4]
        return (q3 - q1) > 100
    
    if waveform == 'sawtooth':
        return max(samples) - min(samples) > 200
    
    return False

async def test_frequency_range(dut):
    """Test frequency scaling through zero-crossings"""
    freqs = {
        'low': 0x30,   # C2
        'mid': 0x5B,   # A4
        'high': 0x7A   # B6
    }
    
    counts = []
    for name, cmd in freqs.items():
        await send_uart(dut, cmd)
        await Timer(20, units="us")
        
        samples = await capture_samples(dut, 1000)
        counts.append(count_zero_crossings(samples))
    
    assert counts[2] > counts[1] > counts[0], "Invalid frequency scaling"

def count_zero_crossings(samples):
    """Calculate zero-crossings without numpy"""
    median = sorted(samples)[len(samples)//2]
    return sum(1 for i in range(len(samples)-1) 
            if (samples[i] > median) != (samples[i+1] > median))

async def test_adsr_functionality(dut):
    """Test ADSR envelope functionality"""
    await send_uart(dut, 0x54)  # Triangle wave
    await send_uart(dut, 0x5B)  # A4
    
    ref_samples = await capture_samples(dut, 1000)
    
    # Adjust ADSR parameters
    await rotate_encoder(dut, 0, 10)  # Attack
    await rotate_encoder(dut, 1, 5)   # Decay
    await rotate_encoder(dut, 2, 8)   # Sustain
    await rotate_encoder(dut, 3, 4)   # Release
    await Timer(50, units="us")
    
    env_samples = await capture_samples(dut, 2000)
    
    assert verify_adsr(env_samples, ref_samples), "ADSR failure"

def verify_adsr(env_samples, ref_samples):
    """Verify envelope attenuation"""
    ref_avg = sum(ref_samples)/len(ref_samples)
    env_avg = sum(env_samples)/len(env_samples)
    return env_avg < ref_avg * 0.8

async def send_uart(dut, data):
    """Simulate UART transmission"""
    # Start bit
    dut.ui_in.value = 0
    await Timer(2, units="us")
    
    # Data bits (LSB first)
    for _ in range(8):
        dut.ui_in.value = data & 0x01
        data >>= 1
        await Timer(2, units="us")
    
    # Stop bit
    dut.ui_in.value = 1
    await Timer(2, units="us")

async def rotate_encoder(dut, encoder_id, steps):
    """Simulate encoder rotation"""
    base_pin = encoder_id * 2
    pattern = [0b00, 0b01, 0b11, 0b10]
    
    for _ in range(steps):
        for state in pattern:
            dut.uio_in.value = (state << base_pin) | \
                              (dut.uio_in.value & ~(0b11 << base_pin))
            await Timer(400, units="ns")

async def capture_samples(dut, count):
    """Capture I2S output samples"""
    samples = []
    for _ in range(count):
        samples.append(dut.uo_out[2].value)
        await Timer(100, units="ns")  # 10MHz sampling
    return samples