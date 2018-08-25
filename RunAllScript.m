clear all
%close all
clc


AddDataPaths;

%% Parameters

getAllSubjects = false; % true if you want to do analysis for all subjects
individualSubjects = {'S1'}; % Only taken into account if getAllSubjects==false
condition = 'active'; %active or passive



%% File selection
if strcmp(condition,'active')
    if getAllSubjects == true
        files ={'S1Data.mat','S2Data.mat','S3Data.mat','S4Data.mat','S5Data.mat','S7Data.mat'}; 
    else
        files = {};
        for i=1:length(individualSubjects)
            files{i} = strcat(individualSubjects{i},'Data.mat');
        end
    end
elseif strcmp(condition,'passive')
    if getAllSubjects == true
        files = {'S1Data_p.mat','S2Data_p.mat','S4Data_p.mat','S7Data_p.mat'};
    else
        files = {};
        for i=1:length(individualSubjects)
            files{i} = strcat(individualSubjects{i},'Data_p.mat');
        end
    end
end



%% Behavioural analysis

% BehaviourTime;
% BehaviourTrajectory;
% BehaviourDeviationVariation;


%% Grand averages analysis

% GrandAverages;


%% Power change ratio analysis

% ComputePowerAverages;
% PowerChangeRatio;

%% ErrP amplitude analysis

% ERPAmplitude;

%% Single trial decoding

% SingleTrialChanceLevel;
% SingleTrialDecoding;




