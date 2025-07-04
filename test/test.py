import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
import random

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
    await Timer(10, units="us")
    
    # Test sequence
    await basic_sanity_check(dut)
    await test_waveforms(dut)
    await test_frequency_range(dut)
    await test_adsr_functionality(dut)
    await test_adsr_stages(dut)
    
    dut._log.info("All functionality verified!")

async def basic_sanity_check(dut):
    """Verify I2S clock activity"""
    sck_values = []
    for _ in range(1000):
        sck_values.append(dut.uo_out[0].value)
        await Timer(100, units="ns")
    
    transitions = sum(1 for a,b in zip(sck_values, sck_values[1:]) if a != b)
    assert transitions > 100, "I2S clock not active"

async def test_waveforms(dut):
    """Test all waveform types with enhanced verification"""
    waveforms = {
        'square': 0x51,
        'sine': 0x57,
        'triangle': 0x54,
        'sawtooth': 0x53
    }
    
    for name, cmd in waveforms.items():
        await send_uart(dut, cmd)
        await Timer(20, units="us")  # Settling time
        
        samples = await capture_samples(dut, 100)
        assert verify_waveform(samples, name), f"{name} verification failed"

def verify_waveform(samples, waveform):
    """Enhanced waveform analysis with statistical metrics"""
    if len(samples) < 20:
        return False
        
    if waveform == 'square':
        # Square wave specific checks
        high_count = sum(1 for x in samples if x > 250)
        low_count = sum(1 for x in samples if x < 5)
        total_cycles = high_count + low_count
        
        if total_cycles == 0:
            return False
            
        duty_cycle = high_count / total_cycles
        return (0.45 < duty_cycle < 0.55 and 
                high_count > 0 and 
                low_count > 0)
    
    elif waveform == 'sine':
        # Check distribution symmetry
        sorted_samples = sorted(samples)
        q1 = sorted_samples[len(samples)//4]
        q3 = sorted_samples[3*len(samples)//4]
        iqr = q3 - q1
        mean = sum(samples)/len(samples)
        return (
            80 < iqr < 120 and 
            100 < mean < 150 and
            abs((q3 - mean) - (mean - q1)) < 15
        )
    
    elif waveform == 'triangle':
        # Check linearity through quartiles
        sorted_samples = sorted(samples)
        q1 = sorted_samples[len(samples)//4]
        median = sorted_samples[len(samples)//2]
        q3 = sorted_samples[3*len(samples)//4]
        return (
            abs((q3 - median) - (median - q1)) < 10 and
            (max(samples) - min(samples)) > 200
        )
    
    elif waveform == 'sawtooth':
        # Check monotonicity
        transitions = sum(1 for i in range(len(samples)-1)
                       if samples[i+1] >= samples[i])
        monotonicity = transitions / len(samples)
        return (
            monotonicity > 0.85 and
            (max(samples) - min(samples)) > 200
        )
    
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
        
        freq = await measure_frequency(dut)
        dut._log.info(f"Measured {name} frequency: {freq:.1f} Hz")
        counts.append(freq)
    
    assert counts[2] > counts[1] > counts[0], "Invalid frequency scaling"
    assert 60 < counts[0] < 70, "Low frequency out of range"
    assert 430 < counts[1] < 450, "Mid frequency out of range"
    assert 1950 < counts[2] < 2000, "High frequency out of range"

async def test_adsr_functionality(dut):
    """Test ADSR envelope amplitude scaling"""
    await send_uart(dut, 0x54)  # Triangle wave
    await send_uart(dut, 0x5B)  # A4
    
    ref_samples = await capture_samples(dut, 100)
    ref_avg = sum(ref_samples)/len(ref_samples)
    
    # Adjust ADSR parameters
    await rotate_encoder(dut, 0, 10)  # Attack
    await rotate_encoder(dut, 1, 5)   # Decay
    await rotate_encoder(dut, 2, 8)   # Sustain
    await rotate_encoder(dut, 3, 4)   # Release
    await Timer(50, units="us")
    
    env_samples = await capture_samples(dut, 100)
    env_avg = sum(env_samples)/len(env_samples)
    
    assert env_avg < ref_avg * 0.8, "ADSR not reducing amplitude"

async def test_adsr_stages(dut):
    """Verify ADSR state transitions"""
    # Configure short envelope times
    await rotate_encoder(dut, 0, 2)  # Attack = 2
    await rotate_encoder(dut, 1, 2)  # Decay = 2
    await rotate_encoder(dut, 2, 4)  # Sustain = 4 (50%)
    await rotate_encoder(dut, 3, 3)  # Release = 3
    
    samples = await capture_samples(dut, 200)
    
    # Detect envelope phases
    attack_done = next((i for i, v in enumerate(samples) if v > 250), None)
    decay_done = next((i for i, v in enumerate(samples[attack_done:]) 
                     if v < 150), None)
    if decay_done is not None:
        decay_done += attack_done
    
    release_start = next((i for i, v in enumerate(samples) if v < 50), None)
    
    assert attack_done, "Attack stage missing"
    assert decay_done and decay_done > attack_done, "Decay stage missing"
    assert release_start and release_start > decay_done, "Release stage missing"

async def measure_frequency(dut, capture_ms=10):
    """Measure actual output frequency"""
    samples = await capture_samples(dut, int(capture_ms * 50))  # ~50 samples/ms
    median = sorted(samples)[len(samples)//2]
    crossings = 0
    last_state = samples[0] > median
    
    for sample in samples[1:]:
        current_state = sample > median
        if current_state != last_state:
            crossings += 1
        last_state = current_state
    
    # Each crossing = half cycle, convert to Hz
    return crossings / (2 * capture_ms * 0.001)

async def send_uart(dut, data):
    """Simulate UART transmission with exact timing"""
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
    """Simulate encoder rotation with realistic timing"""
    base_pin = encoder_id * 2
    pattern = [0b00, 0b01, 0b11, 0b10] if steps > 0 else [0b00, 0b10, 0b11, 0b01]
    steps = abs(steps)
    
    for _ in range(steps):
        for state in pattern:
            dut.uio_in.value = (state << base_pin) | (dut.uio_in.value & ~(0b11 << base_pin))
            await Timer(20000, units="ps")  # 50us per step

async def capture_samples(dut, count):
    """Capture and decode I2S output samples"""
    samples = []
    for _ in range(count):
        # Wait for WS edge to start frame
        await RisingEdge(dut.uo_out[1])
        
        sample = 0
        # Capture 16 bits (MSB first)
        for i in range(15, -1, -1):
            await RisingEdge(dut.uo_out[0])  # Wait for SCK rising edge
            sample_bit = dut.uo_out[2].value
            sample |= int(sample_bit) << i
        
        samples.append(sample >> 8)  # Use upper 8 bits
        
        # Skip right channel
        await RisingEdge(dut.uo_out[1])
    return samples