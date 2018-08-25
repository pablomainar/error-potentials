%% This script computes the chance level in single trial decoding

%% Parameters (can be changed)

tBeforeStart = 0.2; % Time in seconds before movement onset
tAfterStart = 0.5; % Time in seconds after movement onset

k = 5; % k-fold cross validation

nFeatures = 5; % number of features

kinematic_error = 'tangVel'; % Error to use: 'tangVel', 'deviation', 'force'

file_location = 'C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\ComputedData\';
average_file_location = 'C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\ComputedData\AveragePowElectrodeCz\';

numRep = 3000; % Number of repetitions

%% Fixed variables (no need to change)

fsample  = 256; % Sampling frequency

%% Chance level computation
    
allAccuraciesTrain = [];
allAccuraciesTest = [];
% Iterate over all subjects
for subj = 1:length(files)
    %Get the name of the subject to save it as the file name afterwards
    name = strsplit(files{subj},'Data');
    cond = strsplit(name{2},'.mat');
    if strcmp(cond{1},'_p')
        subjectName = strcat(name{1},'_Pas');
    else
        subjectName = strcat(name{1},'_Act');
    end
    
    time = -(round(tBeforeStart*fsample)/fsample):1/fsample:tAfterStart; % Time vector
    load(files{subj});
    
    % Find indeces for all trials
    start = find(markers.value==0 | markers.value == 51 | markers.value == 52 | markers.value == 53 | markers.value == 101 | markers.value == 102 | markers.value == 103);
    ind0 = find(behaviour.forces(:,1)==0);
    ind20 = find(behaviour.forces(:,1)==1);
    ind40 = find(behaviour.forces(:,1)==2);
    ind60 = find(behaviour.forces(:,1)==3);

    % Get only a few trials from none perturbed trials
    n20 = numel(ind20);
    n40 = numel(ind40);
    n60 = numel(ind60);
    n0 = round(mean([n20,n40,n60]));
    ind0 = randsample(ind0,n0);


    indeces = sort(cat(1,ind0,ind20,ind40,ind60));

    brain = [];
    deviations = [];
    forces = [];
    tangVel = [];
    % Iterate over all trials and get all the possible kinematic errors
    for ind=1:size(indeces,1)
        i = indeces(ind);
        timestamp = markers.position(start(i));
        brain = cat(3,brain,eeg(timestamp-round(tBeforeStart*fsample):timestamp+tAfterStart*fsample,:));
        deviations = [deviations;behaviour.traj(i).MaxDeviation];
        forces = [forces;behaviour.forces(i,1)];
        tangVel = [tangVel;behaviour.traj(i).TangVel];
    end

    %Baseline correction
    brain = brain - nanmean(brain(1:round(0.2*fsample),:,:),1);

    % We only consider features aftetr movement onset
    brain = brain(round(tBeforeStart*fsample)+1:end,:,:);
    time = time(round(tBeforeStart*fsample)+1:end);


    i = find(forces == 0 |forces == 1 | forces == 2 | forces == 3);
    brain = brain(:,:,i);
    deviations = deviations(i);
    forces = forces(i);
    tangVel = tangVel(i);

    % Select the kinematic error to use as labels
    switch(kinematic_error)
        case 'tangVel'
            labels = sqrt(tangVel');
        case 'deviation'
            labels = deviations;
        case 'force'
            labels = forces;
    end



    accuracy_train = [];
    accuracy_test = [];
    % Iterate over all the repetitions
    for i = 1:numRep
        % Split test and train set randomly
        perm = randperm(size(brain,3),round(size(brain,3)/k));
        Xtest = brain(:,:,perm);
        labelsTest = labels(perm);
        X = brain;
        X(:,:,perm) = [];
        labelsX = labels;
        labelsX(perm) = [];

        Xraw = X;
        Xtestraw = Xtest;



        % Compute all the features:

        % Temporal features
        Xresh = reshape(X,[size(time,2)*64,size(Xraw,3)]);
        Xtestresh = reshape(Xtest,[size(time,2)*64,size(Xtest,3)]);
        limit1 = size(Xresh,1);


        % Power features
        freqsLimTheta = [8,4];
        freqsLimAlpha = [12,9];
        freqsLimBeta = [30,13];
        avpowTheta = load(strcat(average_file_location,'AveragePow_',subjectName,'_theta_electrode30.mat'));
        avpowTheta = avpowTheta.av_pow;
        avpowAlpha = load(strcat(average_file_location,'AveragePow_',subjectName,'_alpha_electrode30.mat'));
        avpowAlpha = avpowAlpha.av_pow;
        avpowBeta = load(strcat(average_file_location,'AveragePow_',subjectName,'_beta_electrode30.mat'));
        avpowBeta = avpowBeta.av_pow;
        powerTheta = [];
        powerAlpha = [];
        powerBeta = [];
        for t=1:size(X,3)
            [wt,f] = cwt(X(:,30,t),'amor',fsample);
            power = log10(abs(wt).^2 + 1);
            fTheta = find(f<freqsLimTheta(1) & f>freqsLimTheta(2));
            fAlpha = find(f<freqsLimAlpha(1) & f>freqsLimAlpha(2));
            fBeta = find(f<freqsLimBeta(1) & f>freqsLimBeta(2));
            powerTheta = cat(3,powerTheta,power(fTheta,:));
            powerAlpha = cat(3,powerAlpha,power(fAlpha,:));
            powerBeta = cat(3,powerBeta,power(fBeta,:));   
        end

        powerTheta = squeeze(mean(100*powerTheta ./ avpowTheta - 100,1));
        powerAlpha = squeeze(mean(100*powerAlpha ./ avpowAlpha - 100,1));
        powerBeta = squeeze(mean(100*powerBeta ./ avpowBeta - 100,1));

        powerAll = cat(1,powerTheta,powerAlpha,powerBeta);
        limit2 = limit1 + size(powerAll,1);

        powerThetaTest = [];
        powerAlphaTest = [];
        powerBetaTest = [];
        for t=1:size(Xtest,3)
            [wt,f] = cwt(Xtest(:,30,t),'amor',fsample);
            power = log10(abs(wt).^2 + 1);
            fTheta = find(f<freqsLimTheta(1) & f>freqsLimTheta(2));
            fAlpha = find(f<freqsLimAlpha(1) & f>freqsLimAlpha(2));
            fBeta = find(f<freqsLimBeta(1) & f>freqsLimBeta(2));
            powerThetaTest = cat(3,powerThetaTest,power(fTheta,:));
            powerAlphaTest = cat(3,powerAlphaTest,power(fAlpha,:));
            powerBetaTest = cat(3,powerBetaTest,power(fBeta,:));   
        end
        powerThetaTest = squeeze(mean(100*powerThetaTest ./ avpowTheta - 100,1));
        powerAlphaTest = squeeze(mean(100*powerAlphaTest ./ avpowAlpha - 100,1));
        powerBetaTest = squeeze(mean(100*powerBetaTest ./ avpowBeta - 100,1));

        powerAllTest = cat(1,powerThetaTest,powerAlphaTest,powerBetaTest);


        %ERP amplitude features
        channel = 30;
        areaMinimum = 25:44;%76:95 - 51;
        areaMaximum = 45:69;%96:120 - 51;
        [minimum,indMin] = min(X(areaMinimum,channel,:));
        [maximum,indMax] = max(X(areaMaximum,channel,:));
        ERPAmp = squeeze(maximum-minimum);
        [minimum,indMin] = min(Xtest(areaMinimum,channel,:));
        [maximum,indMax] = max(Xtest(areaMaximum,channel,:));
        ERPAmptest = squeeze(maximum-minimum);


        % Join all the features and select them randomly
        AllFeatures = cat(1,Xresh,powerAll,ERPAmp',labelsX);
        I = randperm(size(AllFeatures,1),nFeatures);


        %Build X and Xtest feature vector
        X_feat = [];
        Xtest_feat = [];
        featureGroups = [];
        for iF=1:nFeatures
            if I(iF) <= limit1
                X_feat = cat(1,X_feat,Xresh(I(iF),:));
                Xtest_feat = cat(1,Xtest_feat,Xtestresh(I(iF),:));
                featureGroups = cat(1,featureGroups,1);
            elseif I(iF) > limit1 & I(iF) <= limit2
                X_feat = cat(1,X_feat,powerAll(I(iF)-limit1,:));
                Xtest_feat = cat(1,Xtest_feat,powerAllTest(I(iF)-limit1,:));
                featureGroups = cat(1,featureGroups,2);
            elseif I(iF) > limit2
                X_feat = cat(1,X_feat,ERPAmp');
                Xtest_feat = cat(1,Xtest_feat,ERPAmptest');
                featureGroups = cat(1,featureGroups,3);
            end

        end

        X_feat = X_feat';
        Xtest_feat = Xtest_feat';

        % Shift randomly the labels
        labelsX = labelsX(randperm(size(labelsX,2)));
        X_feat = X_feat(randperm(size(X_feat,1)),:);
        labelsTest = labelsTest(randperm(size(labelsTest,2)));
        Xtest_feat = Xtest_feat(randperm(size(Xtest_feat,1)),:);
        

        % Fit linear model with the training data
        beta = glmfit(X_feat,labelsX)';
        % Obtain training and testing accuracies
        yhat_train = (beta * cat(2,ones([size(X_feat,1),1]),X_feat)')';
        yhat_test = (beta * cat(2,ones([size(Xtest_feat,1),1]),Xtest_feat)')';
        corr = corrcoef(labelsX,yhat_train);
        accuracy_train = [accuracy_train;corr(2,1)];
        corr = corrcoef(labelsTest,yhat_test);
        accuracy_test = [accuracy_test;corr(2,1)];

        disp(strcat(subjectName,'; ',num2str(i)))
    end

    % Compute chance level
    chanceLevel = prctile(accuracy_test,95);
    
    % Save the value
    save(strcat(file_location,'ChanceLevel_',subjectName,'_',condition,'.mat'),'chanceLevel');
    save(strcat(file_location,'ChanceLevelAllAccuracies_',subjectName,'_',condition,'.mat'),'accuracy_test');
    
    accuracy_train = [];
    accuracy_test = [];
    %clearvars -except subjects tBeforeStart tAfterStart fsample k nFeatures numRep subj files condition getAllSubjects individualSubjects kinematic_error average_file_location
    
    
end




