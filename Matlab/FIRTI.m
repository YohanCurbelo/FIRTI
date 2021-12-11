%% FIRTI (FIR Filter Type I) %%
%
% Description: 
% 1. Customazible and optimized FIR Filter.
% 2. The order of the filter has to be even (odd number of coefficients) 
% and its coefficients symmetric.
% 3. Customizable: The widths of input, output, and internal signals are 
% configurable, making natual growth and truncation of data possible. 
% 4. Optimized: As filter coefficients are symmetric, only half of values 
% that are symmetric to the middle address of the shift register are summed.
%
% Additional notes:
% 1. Stimuli is the result of adding 3 tones.
% 2. Stimuli, filter response, and filter coefficientes are exported to a
% txt file.
%
%
% Descripcion:
% 1. Filtro FIR personalizable.
% 2. El orden del filtro tiene que ser par (cantidad impar de coeficientes)
% y sus coeficientes simetricos.
% 3. Personalizable: El ancho de la senyal de entrada, salida, e internas son 
% configurables, haciendo posible el truncado y el crecimiento natural de los 
% datos internos.
% 4. Optimizado: Como el filtro es simetrico solo se realiza una suma de los 
% valores que son simetricos respecto a la direccion central del registro de 
% desplazamiento.
% 
% Notas adicionales:
% 1. La senyal de estimulo es la superposicion de 3 tonos.
% 2. Se exportan a txt la senyal de estimulo, la respuesta del filtro, y los
% valores de los coeficientes del filtro.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Configurable data %%
t_sim = 0.1;                    % Simulation time (seconds)

filter_order = 50;              % Filter order
filter_type = 1;                % 1: Low Pass Filter; 2: High Pass Filter; 3: Bandpass; 4: Bandstop
window = 1;                     % 1: hann; 2: hamming; 3: blackman; 4: triangular; 5: flat top; 6: nut tall
fc1 = 2000;                     % Cut-off frequency 1
fc2 = 3000;                     % Cut-off frequency 2. Only for highpass and bandstop filters
fs = 8000;                      % Sample frequency
f1 = 300;                       % Tone 1
f2 = 1000;                      % Tone 2
f3 = 2400;                      % Tone 3
amplitude = 2;                  % Amplitude of stimuli

wordlength_coeff = 10;          % Word length filter coefficients
fractionallength_coeff = 9;     % Fractional length filter coefficients

wordlength_input = 12;          % Word length stimuli
fractionallength_input = 10;    % Fractional length stimuli
    
wordlength_sum = 12;            % Word length adder
fractionallength_sum = 9;       % Fractional length adder

wordlength_mult = 12;           % Word length multiplier
fractionallength_mult = 8;      % Fractional length multiplier

wordlength_output = 12;         % Word length output signal
fractionallength_output = 3;    % Fractional length output signal


%% Senyales intermedias %%
Ts = 0:1/fs:t_sim-1/fs;
signal1 = sin(2*pi*f1*Ts);
signal2 = sin(2*pi*f2*Ts);
signal3 = sin(2*pi*f3*Ts);
signal = (amplitude/3)*(signal1 + signal2 + signal3);
q = quantizer('fixed','round','saturate',[wordlength_input fractionallength_input]);
signal_q = quantize(q,signal);


%% Validacion de las entradas %%
if mod(filter_order,2) ~= 0
    error('Filter order has to be even')
elseif filter_type ~= 1 && filter_type ~= 2 && filter_type ~= 3 && filter_type ~= 4
    error('Invalid filter type.')
elseif window ~= 1 && window ~= 2 && window ~= 3 && window ~= 4 && window ~= 5 && window ~= 6
    error('Invalid window type.')
elseif fractionallength_coeff >= wordlength_coeff
    error('Coefficients length has to be larger than its fractional length')
elseif fractionallength_input >= wordlength_input
    error('Input length has to be larger than its fractional length')
elseif fractionallength_sum >= wordlength_sum
    error('Sum length has to be larger than its fractional length')
elseif fractionallength_mult >= wordlength_mult
    error('Multiplication length has to be larger than its fractional length')
elseif fractionallength_output >= wordlength_output
    error('Output length has to be larger than its fractional length')
elseif fs/2 < fc1
    error('Cutt-off frequency cannot be higher than Nyquist frequency') 
elseif filter_type == 3 || filter_type == 4
    if fc2 <= fc1
        error('Cut-off frequency has to be increasing')
    end 
    if fs/2 < fc2
        error('Cutt-off frequency cannot be higher than Nyquist frequency')
    end 
end


%% Filtro %%
if filter_type == 3 || filter_type == 4 
    fc = [fc1 fc2]/(fs/2);
else
    fc = fc1/(fs/2);
end

type = ["low" "high" "bandpass" "stop"];
filter_type = char(type(filter_type));

window_type = {hann(filter_order+1) hamming(filter_order+1) blackman(filter_order+1) triang(filter_order+1) flattopwin(filter_order+1) nuttallwin(filter_order+1)};
window_type = cell2mat(window_type(window));

% Coeficientes con precision infinita
b = fir1(filter_order, fc, filter_type, window_type);
[H,w] = freqz(b,1);

% Cuantificacion
q = quantizer('fixed','round','saturate',[wordlength_coeff fractionallength_coeff]);
b_q = quantize(q,b);
[H_q,w_q] = freqz(b_q,1);

% Figures
figure
subplot(2,1,1)
plot(w/2/pi*fs,20*log10(abs([H H_q])));
legend('Infinite precision', [num2str(wordlength_coeff) ' bits precision']);
xlabel('Frequency (Hz)')
ylabel('Module (dB)')
grid

subplot(2,1,2)
plot(w/2/pi*fs,unwrap(angle([H H_q])));
legend('Infinite precision', [num2str(wordlength_coeff) ' bits precision']);
xlabel('Frequency (Hz)')
ylabel('Phase (rad)')
grid


%% Filtrado de la senyal - Filtro con coeficientes simetrico y de orden par %%
% Filtro con truncado interno
sr = zeros(1,length(b));
add = zeros(1,ceil(length(b)/2));
mult = zeros(1,ceil(length(b)/2));
response_q = zeros(1,length(signal));

for i = 1:length(signal_q)
    % shift register
    for j = length(b)-1:-1:1
        sr(j+1) = sr(j);
    end
    sr(1) = signal_q(i);
    
    % filter
    for k = 1:ceil(length(b)/2)
        if k == ceil(length(b)/2)
            add(k) = sr(k);
        else
            add(k) = sr(k) + sr(length(b)+1-k);
        end
        q = quantizer('fixed','round','saturate',[wordlength_sum fractionallength_sum]);
        add_q = quantize(q,add);
        
        mult(k) = b_q(k)*add_q(k);
        q = quantizer('fixed','round','saturate',[wordlength_mult fractionallength_mult]);
        mult_q = quantize(q,mult);
    end
    
    response = sum(mult_q);
    q = quantizer('fixed','round','saturate',[wordlength_output fractionallength_output]);
    response_q(i) = quantize(q,response);
end

% Filtro con crecimiento natural dentro del filtro pero con el estimulo y
% la respuesta cuantificadas
response = filter(quantize(q,b),1,signal_q);


%% Figuras %%
stimulispectrum = abs(fft(signal_q));
response_q_spectrum = abs(fft(response_q));
response_spectrum = abs(fft(response));

figure
subplot(2,2,1)
plot(Ts,signal_q)
title("Estimulo en el tiempo")

subplot(2,2,2)
plot(0:fs/length(stimulispectrum):fs-fs/length(stimulispectrum),stimulispectrum)
title("Estimulo en frecuencia")

subplot(2,2,3)
plot(Ts,response_q)
hold on
plot(Ts,response)
hold off
legend('Respuesta filtro cuantificado', 'Respuesta filtro con crecimiento natural')
title("Respuesta del filtro al estimulo en el tiempo")

subplot(2,2,4)
plot(0:fs/length(response_q_spectrum):fs-fs/length(response_q_spectrum),response_q_spectrum)
hold on
plot(0:fs/length(response_spectrum):fs-fs/length(response_spectrum),response_spectrum)
hold off
legend('Espectro filtro cuantificado', 'Espectro filtro con crecimiento natural')
title("Respuesta en frecuencia del filtro al estimulo")


%% Exportar datos cuantificados %%
% Coeficientes del filtro en formato binario y float
coeficientes = fopen('coefficients_b.txt','w');
q = quantizer('fixed','round','saturate',[wordlength_coeff fractionallength_coeff]);
for i = 1:length(b)
    fprintf(coeficientes,[num2bin(q,b(i)) '\n']);
end

coeficientes = fopen('coefficients_f.txt','w');
for i = 1:length(b)
    fprintf(coeficientes,[num2str(b(i)) '\n']);
end

% Estimulo en formato binario y float
estimulo = fopen('stimuli_b.txt','w');
q = quantizer('fixed','round','saturate',[wordlength_input fractionallength_input]);
for i = 1:length(signal)
    fprintf(estimulo,[num2bin(q,signal(i)) '\n']);
end

estimulo = fopen('stimuli_f.txt','w');
for i = 1:length(signal)
    fprintf(estimulo,[num2str(signal(i)) '\n']);
end

% Respuesta en formato binario y float
respuesta = fopen('response_b.txt','w');
q = quantizer('fixed','round','saturate',[wordlength_output fractionallength_output]);
for i = 1:length(response_q)
    fprintf(respuesta,[num2bin(q,response_q(i)) '\n']);
end

respuesta = fopen('response_f.txt','w');
for i = 1:length(response_q)
    fprintf(respuesta,[num2str(response_q(i)) '\n']);
end