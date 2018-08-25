%% This script is the final preprocessing for active recordings

%% Parameters (can be changed)

file_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\Preprocessing\PreprocessedData\Active\',subject,'\'); % Location where the file is going to be saved

file_name = strcat('markers_',subject,'.mat'); % Name of the markers file

file_clean_eeg_name = strcat(subject,'_eeg.mat'); % Name of the behaviour file created before
file_clean_behaviour_name = strcat('behaviour_',subject,'.mat'); % Name of the eeg file created before


%% Markers preprocessing

% Add path to the raw data
addpath(file_location);

% Build the complete location and name of the output eeg file
filename_save = strcat(file_location,file_name);

% Load the files created in the two precious preprocessing steps
load(file_clean_behaviour_name);
load(file_clean_eeg_name);


% Get all the triggers
n = 9999;
seqT = [];
for i=1:size(trig)
    if n ~= trig(i)
        n = trig(i);
        seqT = [seqT; trig(i)];
    end
end

% Keep the triggers for starting trial (99, 51, 52, 53, 101, 102, 103) to
% align with forces and solve S1 problem.
seqT(find(~seqT)) = [];
ninetyeights = find(seqT==98);
seqT([ninetyeights ninetyeights+1]) = [];
seqT(find(seqT==1 | seqT==2 | seqT==3 | seqT==4)) = [];
seqT(find(seqT==11 | seqT==12 | seqT==13 | seqT==14)) = [];


% Convert trigger 99 to 0 and also fix the problem with S1
forces250 = [];
for i=1:size(seqT)
    if seqT(i)==99 && behaviour.forces(i,1)==0
        seqT(i) = 0;
    end
    if seqT(i)==250
        forces250 = [forces250;i];
        switch(behaviour.forces(i))
            case 1
                seqT(i) = 101;
            case 2
                seqT(i) = 102;
            case 3
                seqT(i) = 103;
        end
    end
end

% Get the position and value of the triggers
triggersPos = [];
triggersValue = [];
trig2 = trig;
n = 999;
for i=1:size(trig,1)
    if trig(i) ~= 0 && trig(i) ~= n
        n = trig(i);
        triggersPos = [triggersPos; i];
        triggersValue = [triggersValue; trig(i)];
    end
end
triggersValue(find(triggersValue==99)) = 0;

% This is for the problem of S1
count=0;
for i=1:size(triggersValue)
    if triggersValue(i) == 250
        count = count + 1;
        switch(behaviour.forces(forces250(count),1))
            case 1
                triggersValue(i) = 51;
            case 2
                triggersValue(i) = 52;
            case 3
                triggersValue(i) = 53;
        end
    end
end

% Save the position and values of the triggers
markers = struct;
markers.position = triggersPos;
markers.value = triggersValue;
save(filename_save,'markers');


