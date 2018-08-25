%% This script is the first preprocessing step of active conditions.

%% Parameters (can be changed)

file_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\Preprocessing\PreprocessedData\Active\',subject,'\'); % Location where the file is going to be saved

file_name = strcat('behaviour_',subject,'.mat'); % Name of the behaviour file

rawdata_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\RawData\Recordings\Active\',subject,'\Behaviour\'); % Location of raw data

%% Behaviour data preprocessing

% Add path to the raw data
addpath(rawdata_location);

% Build the complete location and name of the output behaviour file
filename_save = strcat(file_location,file_name);

% Build the name of all the behaviour inputs from the text files
file_behaviour1 = strcat(subject,'.txt');
file_deviations1 = strcat(subject,'_angles.txt');
file_timing1 = strcat(subject,'_timing.txt');
file_behaviour2 = strcat(subject,'_round2.txt');
file_deviations2 = strcat(subject,'_round2_angles.txt');
file_timing2 = strcat(subject,'_round2_timing.txt');
% For S4 the name of the input files are a bit different:
if strcmp(subject,'S4') 
    file_behaviour1 = strcat(subject,'_round2.txt');
    file_deviations1 = strcat(subject,'_round2_angles.txt');
    file_timing1 = strcat(subject,'_round2_timing.txt');
    file_behaviour2 = strcat(subject,'_round3.txt');
    file_deviations2 = strcat(subject,'_round3_angles.txt');
    file_timing2 = strcat(subject,'_round3_timing.txt');
end
% For S6 the name of the input files are a bit different:
if strcmp(subject,'S6') 
    file_behaviour1 = strcat(subject,'_round3.txt');
    file_deviations1 = strcat(subject,'_round3_angles.txt');
    file_timing1 = strcat(subject,'_round3_timing.txt');
    file_behaviour2 = strcat(subject,'_round5.txt');
    file_deviations2 = strcat(subject,'_round5_angles.txt');
    file_timing2 = strcat(subject,'_round5_timing.txt');
end

% This is the meta file
file_meta = strcat(subject,'_meta.txt');

% The files are loaded and concatenated
b1 = csvread(file_behaviour1);
b2 = csvread(file_behaviour2);
b = cat(1,b1,b2);

d1 = csvread(file_deviations1);
d2 = csvread(file_deviations2);
d = cat(1,d1(:,2:end),d2(:,2:end));
d(d(:,2)==2,2) = -1; 
d(d(:,3)==2,3) = -1;

t1 = csvread(file_timing1);
t2 = csvread(file_timing2);
t = cat(1,t1,t2);

% Number of trials in each file
nTrialsRound1 = length(d1);
nTrialsRound2 = length(d2);

% Starting and ending buttons of each trial are found and saved
ButtonsInd = find(b(:,1)==0 & b(:,2)==0 & b(:,3)==0 & b(:,4)==0 & b(:,5)~=0);
stopImpulseInd = find(b(:,5)==97);
startButtons = b(ButtonsInd(1:end-1),5);
endButtons = b(ButtonsInd(2:end),5);

behaviour = struct;
behaviour.startButtons = startButtons;
behaviour.endButtons = endButtons;
behaviour.forces = d;
behaviour.traj = [];

% Meta parameters are read and saved
meta = csvread(file_meta);
behaviour.meta = meta;
xRes = behaviour.meta(1);
yRes = behaviour.meta(2);
dist = behaviour.meta(3);
    
% Buttons coordinates are computed
topLeft = [xRes/2 - dist,-(yRes/2 - dist)];
topRight = [xRes/2 + dist,-(yRes/2 - dist)];
bottomLeft = [xRes/2 - dist,-(yRes/2 + dist)];
bottomRight = [xRes/2 + dist,-(yRes/2 + dist)];
buttons = [topLeft;topRight;bottomRight;bottomLeft];
    
% The deviation is found for each trial
for i=1:size(startButtons,1)
    pos = b(ButtonsInd(i)+1:ButtonsInd(i+1)-1,1:2);
    vel = b(ButtonsInd(i)+1:ButtonsInd(i+1)-1,3:4);
    time = t(ButtonsInd(i)+1:ButtonsInd(i+1)-1);
    if (startButtons(i) == 1 && endButtons(i) == 2) ||(startButtons(i) == 2 && endButtons(i) == 1) ||(startButtons(i) == 3 && endButtons(i) == 4) ||(startButtons(i) == 4 && endButtons(i) == 3) 
        movement = 'H';
    else
        movement = 'V';
    end
    switch movement
        case 'H'
            line = zeros(size(pos));
            line(:,1) = pos(:,1);
            line(:,2) = ones([size(pos,1),1]) * buttons(startButtons(i),2);
            deviation = abs(pos(:,2) + line(:,2));
        case 'V'
            line = zeros(size(pos));
            line(:,2) = pos(:,2);
            line(:,1) = ones([size(pos,1),1]) * buttons(startButtons(i),1);
            deviation = abs(pos(:,1) - line(:,1));
    end   
    behaviour.traj = [behaviour.traj struct('Position',pos,'Velocity',vel,'Time',time,'Deviation',deviation,'StopImpulse',1)]; 
end

% Correction so that everything is ok
behaviour.startButtons(nTrialsRound1+1) = [];
behaviour.endButtons(nTrialsRound1+1) = [];
behaviour.traj(nTrialsRound1+1) = [];


% This is a check to remove trials with problems
a = [];
for t = 1:size(stopImpulseInd,1)
   a(t) = stopImpulseInd(t) > ButtonsInd(t) && stopImpulseInd(t) < ButtonsInd(t+1);
end
a = find(a==0,1);
behaviour.startButtons(a:nTrialsRound1) = [];
behaviour.endButtons(a:nTrialsRound1) = [];
behaviour.traj(a:nTrialsRound1) = [];
behaviour.forces(a:nTrialsRound1,:) = [];

ButtonsInd = ButtonsInd(1:end-1);
ButtonsInd(nTrialsRound1+1) = [];
ButtonsInd(a:nTrialsRound1) = [];

% The sample where the impulse stops is saved
x=stopImpulseInd - ButtonsInd;
for t = 1:size(behaviour.startButtons)
    behaviour.traj(t).StopImpulse = x(t);
end

% This is just a check to remove any possible trial where the impulse was
% not correcly applied
x = find(x<12 | x>20);
behaviour.traj(x) = [];
behaviour.startButtons(x) = [];
behaviour.endButtons(x) = [];
behaviour.forces(x,:) = [];

% Some other parameters are saved like tangential velocity or maximum
% deviation
for i=1:size(behaviour.traj,2)
    pos = behaviour.traj(i).Position;
    dev = behaviour.traj(i).Deviation;
    
    vertT = isVertical(behaviour.startButtons(i),behaviour.endButtons(i));
    vel = behaviour.traj(i).Velocity;
    if vertT == 1
        if behaviour.forces(i,2)==1
            [tangVel,stopI] = max(vel(:,1));
        elseif behaviour.forces(i,2)==-1
            [tangVel,stopI] = min(vel(:,1));
        else
            stopI = 6;
            tangVel = vel(stopI,1);
        end
    else
        if behaviour.forces(i,3)==1
            [tangVel,stopI] = max(vel(:,2));
        elseif behaviour.forces(i,3)==-1
            [tangVel,stopI] = min(vel(:,2));
        else
            stopI = 6;
            tangVel = vel(stopI,2);
        end
    end
    
    stopIOriginal = behaviour.traj(i).StopImpulse - 1;
        
    if (behaviour.startButtons(i) == 1 && behaviour.endButtons(i) == 2) ||(behaviour.startButtons(i) == 2 && behaviour.endButtons(i) == 1) ||(behaviour.startButtons(i) == 3 && behaviour.endButtons(i) == 4) ||(behaviour.startButtons(i) == 4 && behaviour.endButtons(i) == 3) 
        angle = abs(atand(dev(stopIOriginal)/abs(pos(stopIOriginal,1)-pos(1,1))));
    else
        angle = abs(atand(dev(stopIOriginal)/abs(pos(stopIOriginal,2)-pos(1,2))));
    end
    behaviour.traj(i).DevAngle = angle;
    behaviour.traj(i).MaxDeviation = dev(stopIOriginal);%dev(10);
    behaviour.traj(i).DeviationVel = dev(stopI);
    behaviour.traj(i).StopImpulseVel = stopI;
    behaviour.traj(i).TangVel = abs(tangVel);
end

% This is just a correction for S3 because trial 122 was perturbed
if subject == 'S3'
    behaviour.startButtons(122) = [];
    behaviour.endButtons(122) = [];
    behaviour.forces(122,:) = [];
    behaviour.traj(122) = [];
end



% The file is saved
save(filename_save,'behaviour');
