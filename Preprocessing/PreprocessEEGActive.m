%% Script to preprocess the EEG data in active recordings

%% Parameters (can be changed)

file_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\Preprocessing\PreprocessedData\Active\',subject,'\'); % Location where the file is going to be saved

file_name = strcat(subject,'_eeg.mat'); % Name of the EEG file

rawdata_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\RawData\Recordings\Active\',subject,'\'); % Location of raw data


%% EEG preprocessing

% Add path to the raw data
addpath(rawdata_location);

% Build the complete location and name of the output eeg file
filename_save = strcat(file_location,file_name);

% Select specific parameters for each subject
switch(subject)
    case 'S1'
        file_eeg = 'S1_offlineMIW_20171129175209.gdf';
        expBeg = 311657;
        expEnd = 1878492;
        restBeg = [933787;1279216;1362257;1880865];
        restEnd = [953998;1297936;1433865;1890508];
        bad_channels = [39,56];
        channelsAroundBadChannels = [30,48,38,40;50,60,55,57];
    case 'S1b'
        file_eeg = 'S1_active2_offlineMIW_20171218110353.gdf';
        expBeg = [135873];
        expEnd = [1754913];
        restBeg = [865041];
        restEnd = [1029320];
        bad_channels = [14];
        channelsAroundBadChannels = [13,15,6,23];
    case 'S2'
        file_eeg = 'S2_offlineMIW_20171130172638.gdf';
        expBeg = 37150;
        expEnd = 1419925;
        restBeg = [1102228];
        restEnd = [1139973];
        bad_channels = [20,45,56,61,5,17,54,14]; %There are too many!!
        channelsAroundBadChannels = [19,21,11,29;44,46,36,53;55,57,50,60;4,8,8,17;1,4,10,11;18,18,8,26;58,46,55,47;6,13,15,23];
    case 'S3'
        file_eeg = 'S3_offlineMIW_20171204102310.gdf';
        expBeg = [13877];
        expEnd = [1771721];
        restBeg = [400856;856671];
        restEnd = [425835;1007649];
        bad_channels = [28,39,14,31,22];
        channelsAroundBadChannels = [27,29,19,37;30,48,38,40;6,13,15,23;30,32,21,40;21,23,13,30];
    case 'S4'
        file_eeg = 'S4_offlineMIW_20171208124649.gdf';
        expBeg = [376671];
        expEnd = [1956452];
        restBeg = [1037586;1360244];
        restEnd = [1187906;1367437];
        bad_channels = [20,7];
        channelsAroundBadChannels = [19,21,11,29;3,16,6,15];
    case 'S5'
        file_eeg = 'S5_offlineMIW_20171208145242.gdf';
        expBeg = [73860];
        expEnd = [1723469];
        restBeg = [794960];
        restEnd = [1009458];
        bad_channels = [23,56,26];
        channelsAroundBadChannels = [22,24,14,32;55,57,50,60;27,27,17,35];
    case 'S6'
        file_eeg = 'S6_offlineMIW_20171211143703.gdf';
        expBeg = [831841];
        expEnd = [2050404];
        restBeg = [1126877];
        restEnd = [1652886];
        bad_channels = [14,34,25,26,35];
        channelsAroundBadChannels = [13,15,23,6;43,43,33,33;16,24,24,16;27,27,17,17;36,36,44,44];
    case 'S7'
        file_eeg = 'S7_offlineMIW_20180109143430.gdf';
        expBeg = [96518];
        expEnd = [1756685];
        restBeg = [812756];
        restEnd = [1035656];
        bad_channels = [];
        channelsAroundBadChannels = [];
end

% Load subject raw data
[eeg_raw,header] = sload(file_eeg);
fs = header.SampleRate;


% Remove the parts of the EEG where no task is being done
switch(size(restBeg,1))
    case 0
        eeg_raw([1:expBeg expEnd:end],:) = [];
    case 1
        eeg_raw([1:expBeg restBeg(1):restEnd(1)  expEnd:end],:) = [];
    case 2
        eeg_raw([1:expBeg restBeg(1):restEnd(1) restBeg(2):restEnd(2)  expEnd:end],:) = [];
    case 3
        eeg_raw([1:expBeg restBeg(1):restEnd(1) restBeg(2):restEnd(2) restBeg(3):restEnd(3) expEnd:end],:) = [];
    case 4
        eeg_raw([1:expBeg restBeg(1):restEnd(1) restBeg(2):restEnd(2) restBeg(3):restEnd(3) restBeg(4):restEnd(4) expEnd:end],:) = [];  
end

% Get the triggers and the channels from the electrodes of the EEG
trig = round(eeg_raw(:,81));
eeg_raw = eeg_raw(:,1:64);
% S1 had problems with the triggers, this is to correct them
if strcmp(subject,'S1')
    trig(find(isnan(trig))) = 250;
end


% Remove NaN and extreme values from EEG
eegMask = abs(eeg_raw) >= 500;
eeg_raw(eegMask) = NaN;
eeg_raw = fillmissing(eeg_raw,'linear');

% Resample the data (from 512 to 256 Hz):
% Anti aliasing  filter
[b,a] = butter(30,128/(fs/2));
eeg = filtfilt(b,a,eeg_raw);
% Take one sample out of two
eeg = eeg(1:2:end,:);
trig = trig(1:2:end);
fs = 256; % New sampling frequency

% Pass band filter between 1 and 35 Hz
freqfilt1 = 1;
freqfilt2 = 35;
filter = designfilt('bandpassiir','FilterOrder',20, ...
         'HalfPowerFrequency1',freqfilt1,'HalfPowerFrequency2',freqfilt2, ...
         'SampleRate',fs);
eeg = cat(1,zeros(2000,64),eeg); % This is just a trick to avoid artifacts
eeg = filtfilt(filter,eeg); % filtfilt to avoid phase latency
eeg(1:2000,:) = [];


% Remove bad channels (don't consider them for CAR)
eeg_nobadchan = eeg;
eeg_nobadchan(:,bad_channels) = [];

% CAR: Substract to each channel the mean of all the channels
eeg = eeg - repmat(nanmean(eeg_nobadchan,2),1); 

% Replace bad electrodes with the average of the electrodes around
for c=1:size(bad_channels,2)
   eeg(:,bad_channels(c)) = mean(cat(2,eeg(:,channelsAroundBadChannels(c,1)),eeg(:,channelsAroundBadChannels(c,2)),eeg(:,channelsAroundBadChannels(c,3)),eeg(:,channelsAroundBadChannels(c,4))),2);
end

% Save EEG files
save(filename_save,'eeg','trig');