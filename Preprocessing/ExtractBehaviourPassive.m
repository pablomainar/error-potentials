%% This script is the first preprocessing step of passive conditions.

%% Parameters (can be changed)

file_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\Preprocessing\PreprocessedData\Passive\',subject,'\'); % Location where the file is going to be saved

file_name = strcat('behaviour_',subject,'_p.mat'); % Name of the behaviour file

rawdata_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\RawData\Recordings\Passive\',subject,'\Behaviour\'); % Location of raw data

%% Behaviour data preprocessing

% Add path to the raw data
addpath(rawdata_location);


% Build the complete location and name of the output behaviour file
filename_save = strcat(file_location,file_name);


% Build the name of all the behaviour inputs from the text files
file_behaviour1 = strcat(subject,'_p.txt');
file_deviations1 = strcat(subject,'_p_angles.txt');
file_timing1 = strcat(subject,'_p_timing.txt');
file_behaviour2 = strcat(subject,'_p_r2.txt');
file_deviations2 = strcat(subject,'_p_r2_angles.txt');
file_timing2 = strcat(subject,'_p_r2_timing.txt');

% S2 and S7 had an additional file
if subject == 'S2' | subject == 'S7'
    file_behaviour3 = strcat(subject,'_p_r3.txt');
    file_deviations3 = strcat(subject,'_p_r3_angles.txt');
    file_timing3 = strcat(subject,'_p_r3_timing.txt');
end

% Meta file
file_meta = strcat(subject,'_p_meta.txt');

% The files are loaded and concatenated
b1 = csvread(file_behaviour1);
b2 = csvread(file_behaviour2);
if subject == 'S2' | subject == 'S7'
   b3 = csvread(file_behaviour3);
   b = cat(1,b1,b2,b3);
else
    b = cat(1,b1,b2);
end

d1 = csvread(file_deviations1);
d2 = csvread(file_deviations2);
if subject == 'S2' | subject == 'S7'
    d3 = csvread(file_deviations3);
    d = cat(1,d1(:,2:end),d2(:,2:end),d3(:,2:end));
else
    d = cat(1,d1(:,2:end),d2(:,2:end));
end
% The deviations files is modified a bit
d(:,2) = 0;
d(find(d(:,1)<0),2) = -1;
d(find(d(:,1)>0),2)=1;
d(find(d(:,1)==3),1) = 1;
d(find(d(:,1)==-3),1) = 1;
d(find(d(:,1)==5),1) = 2;
d(find(d(:,1)==-5),1) = 2;
d(find(d(:,1)==7),1) = 3;
d(find(d(:,1)==-7),1) = 3;


t1 = csvread(file_timing1);
t2 = csvread(file_timing2);
if subject == 'S2' | subject == 'S7'
    t3 = csvread(file_timing3);
    t = cat(1,t1,t2,t3);
else
    t = cat(1,t1,t2);
end


% Number of trials in each file
nTrialsRound1 = length(d1);
nTrialsRound2 = length(d2);

% Starting and ending buttons of each trial are found and saved
ButtonsInd = find(b(:,1)==0 & b(:,2)==0 & b(:,3)==0 & b(:,4)==0 & b(:,5)~=0);
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
            %angle = abs(atand(deviation(15)/abs(M(15,1)-M(1,1))));
            tangVel = max(abs(vel(:,2)));
        case 'V'
            line = zeros(size(pos));
            line(:,2) = pos(:,2);
            line(:,1) = ones([size(pos,1),1]) * buttons(startButtons(i),1);
            deviation = abs(pos(:,1) - line(:,1));
            %angle = abs(atand(deviation(15)/abs(M(15,2)-M(1,2))));
            tangVel = max(abs(vel(:,1)));
    end
    maxDev = max(deviation);
   
   
   
   
    behaviour.traj = [behaviour.traj struct('Position',pos,'Velocity',vel,'Time',time,'Deviation',deviation,'MaxDeviation',maxDev,'TangVel',tangVel)]; 
end

% Correction so that everything is ok
behaviour.startButtons(nTrialsRound1+1) = [];
behaviour.endButtons(nTrialsRound1+1) = [];
behaviour.traj(nTrialsRound1+1) = [];
if subject == 'S2' | subject == 'S7'
    behaviour.startButtons(nTrialsRound1 + nTrialsRound2+1) = [];
    behaviour.endButtons(nTrialsRound1 + nTrialsRound2+1) = [];
    behaviour.traj(nTrialsRound1 + nTrialsRound2+1) = [];
end


% This is just a correction for S4 because trial 100 was perturbed
if subject == 'S4'
    behaviour.forces(100,:) = [];
    behaviour.traj(100) = [];
    behaviour.startButtons(100) = [];
    behaviour.endButtons(100) = [];
end

% Load the questions data from S7
if subject == 'S7'
    file_questions1 = strcat(subject,'_p_questions.txt');
    file_questions2 = strcat(subject,'_p_r2_questions.txt');
    file_questions3 = strcat(subject,'_p_r3_questions.txt');
    q1 = csvread(file_questions1);
    q2 = csvread(file_questions2);
    q3 = csvread(file_questions3);
    q = cat(1,q1(:,2),q2(:,2),q3(:,2));
    behaviour.questions = q; 
end

% Some other parameters are saved like tangential velocity or maximum
% deviation
for i=1:size(behaviour.traj,2)
    pos = behaviour.traj(i).Position;
    dev = behaviour.traj(i).Deviation;
    
    vertT = isVertical(behaviour.startButtons(i),behaviour.endButtons(i));
    vel = behaviour.traj(i).Velocity;
    if vertT == 1
        if behaviour.forces(i,2)==1
            [tangVel,indTV] = max(vel(:,1));
            [maxDev,indDev] = max(pos(:,1));
        elseif behaviour.forces(i,2)==-1
            [tangVel,indTV] = min(vel(:,1));
            [maxDev,indDev] = min(pos(:,1));
        else
            if size(vel,1) > 40
                indTV = 40;
            else
                indTV = size(vel,1)-1;
            end
            tangVel = vel(indTV,1);
            indDev = 0;
            maxDev = -1;
        end
    else
        if behaviour.forces(i,2)==1
            [tangVel,indTV] = max(vel(:,2));
            [maxDev,indDev] = max(pos(:,2));
        elseif behaviour.forces(i,2)==-1
            [tangVel,indTV] = min(vel(:,2));
            [maxDev,indDev] = min(pos(:,2));
        else
            if size(vel,1) > 40
                indTV = 40;
            else
                indTV = size(vel,1)-1;
            end
            tangVel = vel(indTV,2);
            indDev=0;
            maxDev = -1;
        end
    end   

    [behaviour.traj(i).MaxDeviation,behaviour.traj(i).StopImpulseDev] = max(behaviour.traj(i).Deviation);
    behaviour.traj(i).StopImpulseVel = indTV;
    behaviour.traj(i).TangVel = abs(tangVel);
end

% This is just a correction for S7 because trial 4 was perturbed
if subject == 'S7'
    behaviour.startButtons(4) = [];
    behaviour.endButtons(4) = [];
    behaviour.forces(4,:) = [];
    behaviour.traj(4) = [];
    behaviour.questions(4) = [];
end


% The file is saved
save(filename_save,'behaviour');
