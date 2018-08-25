%% This script is a wrap up for the passive recordings

%% Parameters (can be changed)

file_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\Preprocessing\PreprocessedData\Passive\',subject,'\'); % Location where the file is going to be saved

file_name = strcat(subject,'Data_p.mat'); % Name of the whole data file

file_clean_eeg_name = strcat(subject,'_p_eeg.mat'); % Name of the behaviour file created before
file_clean_behaviour_name = strcat('behaviour_',subject,'_p.mat'); % Name of the eeg file created before
file_clean_markers_name = strcat('markers_',subject,'_p.mat'); % Name of the markers file created before

%% Wrap up

% Add path to the raw data
addpath(file_location);

% Build the complete location and name of the output eeg file
filename_save = strcat(file_location,file_name);

% Load the files created in the two precious preprocessing steps
load(file_clean_behaviour_name);
load(file_clean_eeg_name);
load(file_clean_markers_name);

% Save the data in one file
save(filename_save,'markers','eeg','behaviour');

