import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
import random
import os

# Set environment variable to resolve 'x' states
os.environ["COCOTB_RESOLVE_X"] = "ZERO"

@cocotb.test()
async def test_full_functionality(dut):
    """Complete system test with enhanced verification"""
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
    await Timer(200, units="us")  # Increased initialization time
    
    # Test sequence
    await basic_sanity_check(dut)
    await test_waveforms(dut)
    await test_frequency_range(dut)
    await test_adsr_functionality(dut)
    
    dut._log.info("All functionality verified!")

async def basic_sanity_check(dut):
    """Verify I2S clock activity"""
    # Wait for initialization to complete
    await Timer(20, units="us")
    
    # Wait for I2S clock to start
    last_val = dut.uo_out[0].integer
    while last_val not in (0, 1):
        await RisingEdge(dut.clk)
        last_val = dut.uo_out[0].integer
    
    # Check for clock transitions
    transitions = 0
    for _ in range(1000):
        await Timer(100, units="ns")
        current_val = dut.uo_out[0].integer
        if current_val != last_val:
            transitions += 1
        last_val = current_val
    
    assert transitions > 50, f"I2S clock not active (transitions: {transitions})"

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
        await Timer(50, units="us")  # Increased settling time
        
        samples = await capture_samples(dut, 50)
        assert verify_waveform(samples, name), f"{name} verification failed"

def verify_waveform(samples, waveform):
    """Simplified waveform verification"""
    if len(samples) < 10:
        return False
        
    if waveform == 'square':
        high_count = sum(1 for x in samples if x > 200)
        low_count = sum(1 for x in samples if x < 50)
        total = high_count + low_count
        return total > 0 and 0.4 < high_count/total < 0.6
    
    # Other waveforms use simpler checks
    max_val = max(samples)
    min_val = min(samples)
    return (max_val - min_val) > 100  # Basic amplitude check

async def test_frequency_range(dut):
    """Test frequency scaling"""
    freqs = {
        'low': 0x30,   # C2
        'mid': 0x5B,   # A4
        'high': 0x7A   # B6
    }
    
    counts = []
    for name, cmd in freqs.items():
        await send_uart(dut, cmd)
        await Timer(50, units="us")  # Increased settling time
        
        # Simple frequency measurement
        edges = 0
        last_val = dut.uo_out[1].integer  # WS signal
        for _ in range(10000):
            await Timer(100, units="ns")
            current_val = dut.uo_out[1].integer
            if current_val != last_val:
                edges += 1
            last_val = current_val
        
        freq = edges / (2 * 0.001)  # Approximate frequency
        dut._log.info(f"Measured {name} frequency: {freq:.1f} Hz")
        counts.append(freq)
    
    # Verify frequency scaling
    assert counts[2] > counts[1] > counts[0], "Invalid frequency scaling"

async def test_adsr_functionality(dut):
    """Test ADSR envelope"""
    await send_uart(dut, 0x54)  # Triangle wave
    await send_uart(dut, 0x5B)  # A4
    
    # Capture reference amplitude
    ref_samples = await capture_samples(dut, 100)
    ref_avg = sum(ref_samples)/len(ref_samples)
    
    # Adjust ADSR parameters
    await rotate_encoder(dut, 0, 10)  # Attack
    await rotate_encoder(dut, 1, 5)   # Decay
    await rotate_encoder(dut, 2, 8)   # Sustain
    await rotate_encoder(dut, 3, 4)   # Release
    await Timer(100, units="us")      # Increased settling time
    
    # Capture ADSR amplitude
    env_samples = await capture_samples(dut, 100)
    env_avg = sum(env_samples)/len(env_samples)
    
    assert env_avg < ref_avg * 0.8, "ADSR not reducing amplitude"

async def send_uart(dut, data):
    """Simulate UART transmission"""
    baud_period = 104166  # 9600 baud in ps
    
    # Start bit
    dut.ui_in.value = 0
    await Timer(baud_period, units="ps")
    
    # Data bits (LSB first)
    for _ in range(8):
        dut.ui_in.value = data & 0x01
        data >>= 1
        await Timer(baud_period, units="ps")
    
    # Stop bit
    dut.ui_in.value = 1
    await Timer(baud_period, units="ps")

async def rotate_encoder(dut, encoder_id, steps):
    """Simulate encoder rotation"""
    base_pin = encoder_id * 2
    pattern = [0b00, 0b01, 0b11, 0b10] if steps > 0 else [0b00, 0b10, 0b11, 0b01]
    steps = abs(steps)
    
    for _ in range(steps):
        for state in pattern:
            # Use direct value assignment instead of uio_in
            current = dut.uio_in.value
            new_val = (current & ~(0b11 << base_pin)) | (state << base_pin)
            dut.uio_in.value = new_val
            await Timer(20000, units="ps")

async def capture_samples(dut, count):
    """Capture I2S output samples (simplified)"""
    samples = []
    for _ in range(count):
        # Use direct signal access instead of indexed signals
        samples.append(dut.uo_out[2].integer)
        await Timer(1, units="us")  # Reduced sampling rate
    return samples