"""
    Engineer: Yohan Curbelo Angles
    
    Module Name: FIRTI (FIR Filter Type I)

    Description: 
    1. Customazible and optimized FIR Filter.
    2. The order of the filter has to be even (odd number of coefficients) 
    and its coefficients symmetric.
    3. Customizable: The widths of input, output, and internal signals are 
    configurable, making natual growth and truncation of data possible. 
    4. Optimized: As filter coefficients are symmetric, only half of values 
    that are symmetric to the middle address of the shift register are summed.

    Additional notes:
    1. Stimuli is the result of adding 3 tones.
    2. Stimuli, filter response, and filter coefficientes are exported to a
    txt file.

    Descripcion:
    1. Filtro FIR personalizable.
    2. El orden del filtro tiene que ser par (cantidad impar de coeficientes)
    y sus coeficientes simetricos.
    3. Personalizable: El ancho de la senyal de entrada, salida, e internas son 
    configurables, haciendo posible el truncado y el crecimiento natural de los 
    datos internos.
    4. Optimizado: Como el filtro es simetrico solo se realiza una suma de los 
    valores que son simetricos respecto a la direccion central del registro de 
    desplazamiento.
    
    Notas adicionales:
    1. La senyal de estimulo es la superposicion de 3 tonos.
    2. Se exportan a txt la senyal de estimulo, la respuesta del filtro, y los
    valores de los coeficientes del filtro.
"""

import numpy as np
import my_functions as mf
import matplotlib.pyplot as plt
from scipy import signal
from scipy.fft import fft


# 1. CONFIGURABLE PARAMETERS
# Filter especification
fc1 = 2000                              # Cut-off frequency 1
fc2 = 3000                              # Cut-off frequency 2. Only for bandpass or bandstop filters
FILTER_ORDER = 50	                    # Filter order
TOTAL_COEFFICIENTS = FILTER_ORDER + 1   # Total of coefficientes is order + 1
filter_type = 'lowpass'                 # Options: lowpass; highpass; bandpass; bandstop
window_type = 'hann'                    # Options: hann; hamming; blackman; triang; flattop; nuttall
COEFFICIENTS_LENGTH = 10
COEFFICIENTS_FRACTIONAL_LENGTH = 9

# Data growth
INPUT_LENGTH = 12
INPUT_FRACTIONAL_LENGTH = 10
SUM_LENGTH = 12
SUM_FRACTIONAL_LENGTH = 9
MULT_LENGTH = 12
MULT_FRACTIONAL_LENGTH = 8
OUTPUT_LENGTH = 12
OUTPUT_FRACTIONAL_LENGTH = 3

# Stimuli
pi = np.pi
A = 2                   # Amplitud of input signal 
f1 = 300
f2 = 1000
f3 = 2400
fsample = 8000          # Sampling frequency
t_sim = 0.1             # Simulation time (seconds)
Ts = np.arange(0, t_sim, 1/fsample)
stimuli = A/3*np.sin(2*pi*f1*Ts) + A/3*np.sin(2*pi*f2*Ts) + A/3*np.sin(2*pi*f3*Ts)

# 2. VALIDATION OF THE INPUTS
if FILTER_ORDER%2 != 0:
    raise Exception('Filter order has to be even')
elif filter_type != 'lowpass' and filter_type != 'highpass' and filter_type != 'bandpass' and filter_type != 'bandstop':
    raise Exception('Invalid filter type.')
elif filter_type == 'bandpass' or filter_type == 'bandstop':
    if fc2 <= fc1:
        raise Exception('Cut-off frequency has to be increasing') 
    if fsample/2 < fc2:
        raise Exception('Cutt-off frequency cannot be higher than Nyquist frequency') 
elif fsample/2 < fc1:
    raise Exception('Cutt-off frequency cannot be higher than Nyquist frequency') 
elif window_type != 'hann' and window_type != 'hamming' and window_type != 'blackman' and window_type != 'triang' and window_type != 'flattop' and window_type != 'nuttall':
    raise Exception('Invalid window type.')
elif COEFFICIENTS_FRACTIONAL_LENGTH >= COEFFICIENTS_LENGTH:
    raise Exception('Coefficients length has to be larger than its fractional length')
elif INPUT_FRACTIONAL_LENGTH >= INPUT_LENGTH:
    raise Exception('Input length has to be larger than its fractional length')
elif SUM_FRACTIONAL_LENGTH >= SUM_LENGTH:
    raise Exception('Sum length has to be larger than its fractional length')
elif MULT_FRACTIONAL_LENGTH >= MULT_LENGTH:
    raise Exception('Multiplication length has to be larger than its fractional length')
elif OUTPUT_FRACTIONAL_LENGTH >= OUTPUT_LENGTH:
    raise Exception('Output length has to be larger than its fractional length')


# 3. FILTER DESIGN
# Set the cut-off frequency
if filter_type == 'bandpass' or filter_type == 'bandstop':
    fc = [fc1, fc2]
else:
    fc = fc1
    
# Coefficients     
num = signal.firwin(TOTAL_COEFFICIENTS, fc, window=window_type, pass_zero=filter_type, fs=fsample)

# Quantization
num_q = mf.quantize(num, COEFFICIENTS_LENGTH, COEFFICIENTS_FRACTIONAL_LENGTH)
stimuli_q = mf.quantize(stimuli, INPUT_LENGTH, INPUT_FRACTIONAL_LENGTH)

# Optimized filter
sr = np.zeros(TOTAL_COEFFICIENTS)             # There are FILTER_ORDER + 1 coefficients
add = np.zeros(int(np.ceil(TOTAL_COEFFICIENTS/2)))
add_q = np.zeros(int(np.ceil(TOTAL_COEFFICIENTS/2)))
mult = np.zeros(int(np.ceil(TOTAL_COEFFICIENTS/2)))
mult_q = np.zeros(int(np.ceil(TOTAL_COEFFICIENTS/2)))
response = np.zeros(len(stimuli_q))
response_q = np.zeros(len(stimuli_q))

for i in range(len(stimuli_q)):
    # Shift register stage
    for j in range(TOTAL_COEFFICIENTS - 1):
        sr[TOTAL_COEFFICIENTS - 1 - j] = sr[TOTAL_COEFFICIENTS - j - 2]
    sr[0] = stimuli_q[i]
    
    # Filter stage
    for k in range(int(np.ceil(TOTAL_COEFFICIENTS/2))):
        # Sum
        if k != int(TOTAL_COEFFICIENTS/2):
            add[k] = sr[k] + sr[TOTAL_COEFFICIENTS - 1 - k]
        else:
            add[k] = sr[int(TOTAL_COEFFICIENTS/2)]
        add_q = mf.quantize(add, SUM_LENGTH, SUM_FRACTIONAL_LENGTH) 
            
        # Multiplication
        mult[k] = add_q[k] * num_q[k]
        mult_q = mf.quantize(mult, MULT_LENGTH, MULT_FRACTIONAL_LENGTH)
    
    response[i] = sum(mult_q) 

response_q = mf.quantize(response, OUTPUT_LENGTH, OUTPUT_FRACTIONAL_LENGTH)

# 4. Figures
stimuli_spectrum = abs(fft(stimuli_q))
response_spectrum = abs(fft(response_q))

time_axis = np.arange(0, t_sim, t_sim/len(stimuli_q))
freq_axis = np.arange(0, fsample, fsample/len(response_q))

# Filter plot
w, h = signal.freqz(num_q)
fig, axe = plt.subplots()
axe.set_title('Digital filter frequency response')
axe.plot(w/2/pi*fsample, 20 * np.log10(abs(h)), 'b')
axe.set_ylabel('Amplitude [dB]', color='b')
axe.set_xlabel('Frequency [Hz]')
axe2 = axe.twinx()
angles = np.unwrap(np.angle(h))
axe2.plot(w/2/pi*fsample, angles, 'g')
axe2.set_ylabel('Angle [radians]', color='g')
axe2.grid()
axe2.axis('tight')

# Stimuli and response plot
fig, axe = plt.subplots(2, 2)
axe[0,0].plot(time_axis, stimuli_q)
axe[0,0].set_title('Stimuli (time domain')
axe[1,0].plot(freq_axis, stimuli_spectrum)
axe[0,0].set_title('Stimuli (frequency domain')
axe[0,1].plot(time_axis, response_q)
axe[0,0].set_title('Response (time domain')
axe[1,1].plot(freq_axis, response_spectrum)
axe[0,0].set_title('Response (frequency domain')
fig.suptitle('Filter behavior')

# Plot figures
plt.show()

# 5. Export data in float and binary format
# Float files
with open('Python\Stimuli_f.txt','w') as file:
    for line in stimuli_q:
        file.write(str(line))
        file.write('\n')
        
with open('Python\Coefficients_f.txt','w') as file:
    for line in num_q:
        file.write(str(line))
        file.write('\n')
        
with open('Python\Response_f.txt','w') as file:
    for line in response_q:
        file.write(str(line))
        file.write('\n')       
        
# Binary files
with open('Python\Stimuli_b.txt','w') as file:
    # Convert to binary representation
    stimuli_qb = ["" for i in range(len(stimuli_q))]        
    for i in range(len(stimuli_q)):        
        stimuli_qb[i] = mf.float_to_bin(stimuli_q[i], INPUT_LENGTH, INPUT_FRACTIONAL_LENGTH)
    # Write txt file
    for line in stimuli_qb:
        file.write(str(line))
        file.write('\n')

with open('Python\Coefficients_b.txt','w') as file:
    # Convert to binary representation
    num_qb = ["" for i in range(len(num_q))]           
    for i in range(len(num_q)):   
        num_qb[i] = mf.float_to_bin(num_q[i], COEFFICIENTS_LENGTH, COEFFICIENTS_FRACTIONAL_LENGTH)
    # Write txt file
    for line in num_qb:
        file.write(str(line))
        file.write('\n')
      
with open('Python\Response_b.txt','w') as file:
    # Convert to binary representation
    response_qb = ["" for i in range(len(response_q))]           
    for i in range(len(response_q)):                         
        response_qb[i] = mf.float_to_bin(response_q[i], OUTPUT_LENGTH, OUTPUT_FRACTIONAL_LENGTH)     
    # Write txt file
    for line in response_qb:
        file.write(str(line))
        file.write('\n')