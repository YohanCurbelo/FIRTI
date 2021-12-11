import numpy as np

def quantize(data, word_length, fractional_length):
    """
        This function quantizes the input in_data with these parameters:
        mode:           fixed point
        round mode:     round
        overflow mode:  saturate
        format:         [word_length fractional_length]
        
        In order to make the function more general, if data input is not an array
        it is converted to a 1d array. In this way the for loop is always functional.
    """
    
    # Convert input data to an array if it is a single data 
    if 1 == len(np.atleast_1d(data)):
        in_data = np.array([data])
    else:
        in_data = data
    
    min_value = -2**(word_length - fractional_length - 1)                   # Negative bound
    resolution = 2**(-fractional_length)                                    # Resolution of the quantization
    max_value = 2**(word_length - fractional_length - 1) - resolution       # Positive bound
    
    data_q = np.zeros(len(np.atleast_1d(in_data)))
    for i in range(len(np.atleast_1d(in_data))):
        
        index = int(in_data[i]/resolution)        
        error_to_down = abs(in_data[i]) - resolution * abs(index)
        error_to_up = resolution * (abs(index) + 1) - abs(in_data[i])

        if in_data[i] >= max_value:         # Positive saturation
            data_q[i] = max_value           
        elif in_data[i] <= min_value:       # Negative saturation
            data_q[i] = min_value      
        elif in_data[i] >= 0:
            if error_to_down <= error_to_up:
                data_q[i] = resolution * index
            else:
                data_q[i] = resolution * (index + 1)
        elif in_data[i] < 0:
            if error_to_down <= error_to_up:
                data_q[i] = resolution * index
            else:
                data_q[i] = resolution * (index - 1)
    
    return data_q



def float_to_bin(float_data, word_length, fractional_length):
    """
        This function convert the signed float input to binary representation
        according to the specified lengths. 
        
        Input can´t be an array.
    """      
    # Quantize float_data 
    float_data = quantize(float_data, word_length, fractional_length)
    
    # MSB bit of the binary representation to concatenated it later.
    # Modify float_data if it's negative
    if float_data >= 0:
        MSB = '0'
    else:
        MSB = '1'
        float_data = 2**(word_length - fractional_length - 1) + float_data    
    
    # Separates float_data in its whole and fractional part
    fractional_part = abs(float_data - int(float_data))
    whole_part = np.sign(float_data) * (abs(float_data) - fractional_part) 
  
    # Convert the whole part of float_data to its binary form
    binary_data = np.binary_repr(int(whole_part), width=word_length-fractional_length)
        # np.binary_repr leads to a wrong conversion since the output 
        # will be all zeros for inputs between 0 and -1.0 (0 > float input > -1.0). 
        # The solution is to remove the signed bit and concatenate the MSB
        # caclulated at the beginning to the others bit.
    binary_data = MSB + binary_data[1:len(binary_data)]
  
    # Calculate the binary representation of the fractional part bit to bit
    for x in range(fractional_length):
                  
        fractional_part_shifted = 2 * fractional_part
            
        whole = int(fractional_part_shifted)
        fractional_part = fractional_part_shifted - whole
  
        # Concatenate the Xth bit of the fractional part
        binary_data += str(whole)
    
    return binary_data