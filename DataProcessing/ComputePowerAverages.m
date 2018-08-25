%% This script computes and saves in a file the power averages for each file

%% Parameters (can be changed)

file_location = 'C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\ComputedData\';

electrodes = [12,20:22,29,31]; % Cz is 30

tBeforeStart = 2; % Time in seconds before movement onset
tAfterStart = 2; % Time in seconds after movement onset

%% Fixed variables (no need to change)

fsample  = 256; %Sampling frequency
time = -(round(tBeforeStart*fsample)/fsample):1/fsample:tAfterStart; %Time vector

%% Power average computation

for elec = 1:length(electrodes)
    
    % Iterate over all files
    for subj = 1:length(files)
        %Get the name of the subject to save it as the file name afterwards
        name = strsplit(files{subj},'Data');
        cond = strsplit(name{2},'.mat');
        if strcmp(cond{1},'_p')
            subjectName = strcat(name{1},'_Pas');
        else
            subjectName = strcat(name{1},'_Act');
        end

        display(subjectName)
        load(files{subj});

        %Iterate over the three frequency bands
        for fBand = 1:3
            switch(fBand)
                case 1
                    frequencyBand = 'theta';
                    freqsLim = [8,4];
                case 2
                    frequencyBand = 'alpha';
                    freqsLim = [12,9];
                case 3
                    frequencyBand = 'beta';
                    freqsLim = [30,13];
            end

            display(frequencyBand);

            % Band pass filter to remove artifacts from other bands (might be
            % redundant)
            freqfilt1 = freqsLim(2);
            freqfilt2 = freqsLim(1);
            filter = designfilt('bandpassiir','FilterOrder',20, ...
                     'HalfPowerFrequency1',freqfilt1,'HalfPowerFrequency2',freqfilt2, ...
                     'SampleRate',fsample);
            eegFilt = cat(1,zeros(2000,64),eeg); %Smalll trick to avoid artifacts at beginning
            eegFilt = filtfilt(filter,eegFilt);
            eegFilt(1:2000,:) = [];

            % Obtain time-freq coefficients
            [wt,f] = cwt(eegFilt(:,elec),'amor',fsample);

            % Keep only the frequency from the band
            valid_f = find(f<freqsLim(1) & f>freqsLim(2));
            fS = f(valid_f);
            wtS = wt(valid_f,:);

            % Compute the log-power and find the average
            av_pow = abs(wtS).^2 + 1;
            av_pow = log10(av_pow);
            av_pow = mean(av_pow,2);

            % Save the file
            save(strcat(file_location,'\AveragePow_',subjectName,'_',frequencyBand,'_electrode',num2str(electrodes(elec)),'.mat'),'av_pow')

        end



    end


end