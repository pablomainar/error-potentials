clear all
close all
clc

%% Parameters (can be changed)

subject = 'S4'; % Subject to preprocess
condition = 'passive'; %active or passive


%% Preprocessing

switch(condition)
    case 'active'
        ExtractBehaviourActive;
        PreprocessEEGActive;
        CleanBehaviourActive;
        WrapUpActive;
    case 'passive'
        ExtractBehaviourPassive;
        PreprocessEEGPassive;
        CleanBehaviourPassive;
        WrapUpPassive;     
end

CheckerPreprocessing;
