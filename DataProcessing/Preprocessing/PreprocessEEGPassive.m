%% Script to preprocess the EEG data in passive recordings

%% Parameters (can be changed)

file_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\Preprocessing\PreprocessedData\Passive\',subject,'\'); % Location where the file is going to be saved

file_name = strcat(subject,'_p_eeg.mat'); % Name of the behaviour file

rawdata_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\RawData\Recordings\Passive\',subject,'\'); % Location of raw data


%% EEG preprocessing

% Add path to the raw data
addpath(rawdata_location);

% Build the complete location and name of the output eeg file
filename_save = strcat(file_location,file_name);

% Select specific parameters for each subject
switch(subject)
    case 'S1'
        file_eeg = 'S1_Session2_offlineMIW_20171211113317.gdf';
        expBeg = 159882;
        expEnd = 1552876;
        restBeg = [744995];
        restEnd = [968679];
        bad_channels = [14];
        channelsAroundBadChannels = [13,15,23,6];
    case 'S2'
        file_eeg = 'S2_passive_offlineMIW_20171212140630.gdf';
        expBeg = 106191;
        expEnd = 1465592;
        restBeg = [693984;1237326];
        restEnd = [745014;1362197];
        bad_channels = [6,34];
        channelsAroundBadChannels = [7,3,13,14;33,33,25,43];
    case 'S4'
        file_eeg = 'S4_passive_offlineMIW_20171214102903.gdf';
        expBeg = 109889;
        expEnd = 1399128;
        restBeg = [703916;344050];
        restEnd = [822181;346093];
        bad_channels = [46,36];
        channelsAroundBadChannels = [54,47,45,37;37,35,45,27];
    case 'S7'
        file_eeg = 'S7_p_offlineMIW_20180111101943.gdf';
        expBeg = 103016;
        expEnd = 1596030;
        restBeg = [110883;728681;1212363];
        restEnd = [112569;926264;1318847];
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