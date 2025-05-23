import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import numpy as np

@cocotb.test()
async def test_full_functionality(dut):
    """Full system test using I2S output analysis"""
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
    """Verify all waveform types through output statistics"""
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

async def test_frequency_range(dut):
    """Verify frequency changes through zero-crossing analysis"""
    freqs = {
        'low': 0x30,   # C2
        'mid': 0x5B,   # A4
        'high': 0x7A   # B6
    }
    
    ref_counts = []
    for name, cmd in freqs.items():
        await send_uart(dut, cmd)
        await Timer(20, units="us")
        
        samples = await capture_samples(dut, 1000)
        zero_crossings = count_zero_crossings(samples)
        ref_counts.append(zero_crossings)
    
    # Verify frequency relationships
    assert ref_counts[2] > ref_counts[1] > ref_counts[0], "Frequency scaling invalid"

async def test_adsr_functionality(dut):
    """Verify ADSR through amplitude envelope analysis"""
    # Set initial parameters
    await send_uart(dut, 0x54)  # Triangle wave
    await send_uart(dut, 0x5B)  # A4
    
    # Capture reference (no envelope)
    ref_samples = await capture_samples(dut, 1000)
    
    # Activate ADSR
    await rotate_encoder(dut, 0, 10)  # Attack
    await rotate_encoder(dut, 1, 5)   # Decay
    await rotate_encoder(dut, 2, 8)   # Sustain
    await rotate_encoder(dut, 3, 4)   # Release
    await Timer(50, units="us")
    
    # Capture ADSR samples
    env_samples = await capture_samples(dut, 2000)
    
    # Verify envelope shape
    assert verify_adsr_envelope(env_samples, ref_samples), "ADSR envelope invalid"

async def send_uart(dut, data):
    """Simplified UART transmission"""
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
    for _ in range(steps):
        # CW rotation pattern
        dut.uio_in.value = (0b00 << base_pin) | (dut.uio_in.value & ~(0b11 << base_pin))
        await Timer(400, units="ns")
        dut.uio_in.value = (0b01 << base_pin) | (dut.uio_in.value & ~(0b11 << base_pin))
        await Timer(400, units="ns")
        dut.uio_in.value = (0b11 << base_pin) | (dut.uio_in.value & ~(0b11 << base_pin))
        await Timer(400, units="ns")
        dut.uio_in.value = (0b10 << base_pin) | (dut.uio_in.value & ~(0b11 << base_pin))
        await Timer(400, units="ns")

async def capture_samples(dut, count):
    """Capture I2S samples through direct polling"""
    samples = []
    for _ in range(count):
        samples.append(dut.uo_out[2].value)
        await Timer(100, units="ns")  # Sample at 10MHz
    return np.array(samples)

def verify_waveform(samples, waveform):
    """Statistical waveform verification"""
    hist = np.histogram(samples, bins=256, range=(0,255))[0]
    
    if waveform == 'square':
        return hist[0] > len(samples)*0.3 and hist[-1] > len(samples)*0.3
    elif waveform == 'sine':
        # Check for bell-shaped distribution
        return np.var(hist) < 1e4 and np.abs(np.mean(hist) - 2) < 1
    elif waveform == 'triangle':
        # Linear distribution check
        return np.corrcoef(np.arange(256), hist)[0,1] > 0.7
    elif waveform == 'sawtooth':
        return hist.argmax() < 10 or hist.argmax() > 245
    return False

def count_zero_crossings(samples):
    """Count median crossings for frequency estimation"""
    median = np.median(samples)
    return sum((samples[i] > median) != (samples[i+1] > median) 
               for i in range(len(samples)-1))

def verify_adsr_envelope(env_samples, ref_samples):
    """Check for amplitude modulation"""
    env_max = env_samples.max()
    ref_max = ref_samples.max()
    return env_max < ref_max * 0.9 and np.mean(env_samples) < np.mean(ref_samples) * 0.8