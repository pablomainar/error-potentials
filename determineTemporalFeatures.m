function [ elecF, sampleF ] = determineTemporalFeatures( I,Xraw,Xreshaped)
    % Function that draws the selected features
    % INPUTS:
    %   - I: [# of features,1] Indeces of selected features
    %   - Xraw: [# of time points, # of channels, # of trials]
    %   Training data matrix with original order
    %   - yraw: [1,# of trials] Labels of training data
    %   - Xreshaped: [# of time points * # of channels,# of trials]
    %   Training data matrix with reshaped order
    %   - time: [1,# of time points] Time vector
    
    
    sb = size(Xraw);

    load('eegLabels.mat')
    samples = [];
    channels = [];
    for i=1:size(I)
        [f,c] = ind2sub(sb,sub2ind(size(Xreshaped),I(i),1));
        channels = [channels c];
        samples = [samples f];
    end
    
    elecF = channels;
    sampleF = samples;

    
end