%% This script is used to know if the preprocessing went well

%% Parameters (can be changed)

switch(condition)
    case 'active'
        file_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\Preprocessing\PreprocessedData\Active\',subject,'\'); % Location where the preprocessed file is
        file_name = strcat(subject,'Data.mat'); % Name of the whole data file
    case 'passive'
        file_location = strcat('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\Preprocessing\PreprocessedData\Passive\',subject,'\'); % Location where the preprocessed file is
        file_name = strcat(subject,'Data_p.mat'); % Name of the whole data file
end

%% Checker

% Add path to the preprocessed data
addpath(file_location);

% Load the preprocessed data
load(file_name);

% Find all the starting markers
start = find(markers.value==0 | markers.value == 51 | markers.value == 52 | markers.value == 53 | markers.value == 101 | markers.value == 102 | markers.value == 103);

% Compare the trials with no force to the markers with a value of 0
markers0 = find(markers.value==0);
locations0 = [];
for i=1:size(markers0)
    n = markers0(i);
    locations0 = cat(1,locations0,find(start==n));
end
shouldBeZero = unique((behaviour.forces(locations0,1)));

% Compare the trials with small force to the markers with a value of 51 or
% 101
markers20 = find(markers.value==51 | markers.value==101);
locations20 = [];
for i=1:size(markers20)
    n = markers20(i);
    locations20 = cat(1,locations20,find(start==n));
end
shouldBeOne = unique((behaviour.forces(locations20,1)));

% Compare the trials with medium force to the markers with a value of 52 or
% 102
markers40 = find(markers.value==52 | markers.value==102);
locations40 = [];
for i=1:size(markers40)
    n = markers40(i);
    locations40 = cat(1,locations40,find(start==n));
end
shouldBeTwo = unique((behaviour.forces(locations40,1)));

% Compare the trials with large force to the markers with a value of 53 or
% 103
markers60 = find(markers.value==53 | markers.value==103);
locations60 = [];
for i=1:size(markers60)
    n = markers60(i);
    locations60 = cat(1,locations60,find(start==n));
end
shouldBeThree = unique((behaviour.forces(locations60,1)));

% Check that the number of forces of each category is the same as the
% markers for each category
forcesNumber0 = numel(find(behaviour.forces(:,1)==0));
forcesNumber20 = numel(find(behaviour.forces(:,1)==1));
forcesNumber40 = numel(find(behaviour.forces(:,1)==2));
forcesNumber60 = numel(find(behaviour.forces(:,1)==3));

shouldBeTrue0 = forcesNumber0==size(markers0,1);
shouldBeTrue20 = forcesNumber20==size(markers20,1);
shouldBeTrue40 = forcesNumber40==size(markers40,1);
shouldBeTrue60 = forcesNumber60==size(markers60,1);

% Assert everything
assert(shouldBeOne==1)
assert(shouldBeTwo==2)
assert(shouldBeThree==3)
assert(shouldBeTrue0==true)
assert(shouldBeTrue20==true)
assert(shouldBeTrue40==true)
assert(shouldBeTrue60==true)

% Display this if everything went well
display('Everythig is correct! :D')



