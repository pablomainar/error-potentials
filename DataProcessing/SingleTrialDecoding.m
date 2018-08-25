%% This script does single trial decoding

%% Parameters (can be changed)

tBeforeStart = 0.2; % Time before movement onset
tAfterStart = 0.5; % Time after movement onset

k = 5; % k-fold cross validation
nFeat = 5; % Number of features
nRepetitions = 1; % Number of repetitions to get the final accuracy value

kinematic_error = 'tangVel'; % Error to use: 'tangVel', 'deviation', 'force'

average_file_location = 'C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\ComputedData\';

determineFeatures = true; % Determine which features have been selected

useTemporalFeat = true;
usePowerChangeFeat = true;
useERPAmpFeat = true;

frontoCentralElectrodes = [12,20:22,29:31]; %Fz, FC1, FCz, FC2, C1, Cz, C2
%% Fixed variables (no need to change)

fsample  = 256; % Sampling frequency
time = -(round(tBeforeStart*fsample)/fsample):1/fsample:tAfterStart; % Time vector

%% Single trial decoding

% Only get the first file
load(files{1});
%Get the name of the subject to save it as the file name afterwards
name = strsplit(files{1},'Data');
cond = strsplit(name{2},'.mat');
if strcmp(cond{1},'_p')
    subjectName = strcat(name{1},'_Pas');
else
    subjectName = strcat(name{1},'_Act');
end

% Get the indeces for all the trials
start = find(markers.value==0 | markers.value == 51 | markers.value == 52 | markers.value == 53 | markers.value == 101 | markers.value == 102 | markers.value == 103);
ind0 = find(behaviour.forces(:,1)==0);
ind20 = find(behaviour.forces(:,1)==1);
ind40 = find(behaviour.forces(:,1)==2);
ind60 = find(behaviour.forces(:,1)==3);

% Only get a few unperturbed trials
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

% We only consider features after movement onset
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


mean_accuracy_train = [];
mean_accuracy_test = [];
% Iterate over all the repetitions
for nRep = 1:nRepetitions
    disp(nRep)
    accuracy_train = [];
    accuracy_test = [];
    permutations = randperm(size(brain,3));
    % Do k-fold cross validation
    for i = 1:k
        % Split trand and test sets
        perm = permutations((i-1)*floor(size(permutations,2)/k)+1:i*floor(size(permutations,2)/k));
        Xtest = brain(:,:,perm);
        labelsTest = labels(perm);
        X = brain;
        X(:,:,perm) = [];
        labelsX = labels;
        labelsX(perm) = [];

        Xraw = X;
        Xtestraw = Xtest;


        
        % Compute all features

        % Temporal features
        Xresh = [];
        Xtestresh = [];
        if useTemporalFeat == true
            Xresh = reshape(X,[size(time,2)*64,size(Xraw,3)]);
            Xtestresh = reshape(Xtest,[size(time,2)*64,size(Xtest,3)]);
        end
        limit1 = size(Xresh,1);
        
       % Power Features
       ExtractPowerFeatures;

        %ERP amplitude features
        ERPAmp = [];
        ERPAmpTest = [];
        if useERPAmpFeat == true
            channel = frontoCentralElectrodes;
            areaMinimum = 25:44;%76:95 - 51;
            areaMaximum = 45:69;%96:120 - 51;
            [minimum,indMin] = min(X(areaMinimum,channel,:));
            [maximum,indMax] = max(X(areaMaximum,channel,:));
            ERPAmp = squeeze(maximum-minimum);
            [minimum,indMin] = min(Xtest(areaMinimum,channel,:));
            [maximum,indMax] = max(Xtest(areaMaximum,channel,:));
            ERPAmptest = squeeze(maximum-minimum);
        end
        
        %Join all the features
        AllFeatures = cat(1,Xresh,powerAll,ERPAmp,labelsX);
        corr = corrcoef(AllFeatures');
        corr = corr(1:end-1,end);
        corr = abs(corr);
        [sorted,I] = sort(corr,'descend');
        
        %Build X and Xtest features vectors
        X_feat = [];
        Xtest_feat = [];
        featureGroups = [];
        for iF=1:nFeat
            if I(iF) <= limit1
                X_feat = cat(1,X_feat,Xresh(I(iF),:));
                Xtest_feat = cat(1,Xtest_feat,Xtestresh(I(iF),:));
                featureGroups = cat(1,featureGroups,1);
            elseif I(iF) > limit1 & I(iF) <= limit2
                X_feat = cat(1,X_feat,powerAll(I(iF)-limit1,:));
                Xtest_feat = cat(1,Xtest_feat,powerAllTest(I(iF)-limit1,:));
                featureGroups = cat(1,featureGroups,2);
            elseif I(iF) > limit2
                X_feat = cat(1,X_feat,ERPAmp(I(iF)-limit2,:));
                Xtest_feat = cat(1,Xtest_feat,ERPAmptest(I(iF)-limit2,:));
                featureGroups = cat(1,featureGroups,3);
            end
            
        end
        
        % Determine which features have been selected
        if determineFeatures == true
            elecFeat = [];
            timeTempFeat = [];
            frecBandFeat = [];
            electrodePowerFeat = [];
            timePowerFeat = [];
            elecFeatERPAmp = [];
            for iF=1:nFeat
                switch(featureGroups(iF))
                    case 1
                        [elecFeatIter,sampleTempFeatIter] = determineTemporalFeatures(I(iF),Xraw,Xresh);
                        elecFeat = cat(2,elecFeat,elecFeatIter);
                        timeTempFeat = cat(2,timeTempFeat,time(sampleTempFeatIter));
                    case 2
                        [electrodePowerFeatIter,frecBandFeatIter,samplePowerFeatIter] = determinePowerFeatures(I(iF)-limit1,time);
                        electrodePowerFeat = cat(2,electrodePowerFeat,electrodePowerFeatIter);
                        frecBandFeat = cat(2,frecBandFeat,frecBandFeatIter);
                        timePowerFeat = cat(2,timePowerFeat,time(samplePowerFeatIter));
                    case 3
                        elecFeatERPAmp = cat(2,elecFeatERPAmp,I(iF) - limit2);
                        
                end
            end
        end
        
        
        
        X_feat = X_feat';
        Xtest_feat = Xtest_feat';
        

        % Fit linear model with the training data
        beta = glmfit(X_feat,labelsX)';
        % Obtain training and testing accuracies
        yhat_train = (beta * cat(2,ones([size(X_feat,1),1]),X_feat)')';
        yhat_test = (beta * cat(2,ones([size(Xtest_feat,1),1]),Xtest_feat)')';
        corr = corrcoef(labelsX,yhat_train);
        accuracy_train = [accuracy_train;corr(2,1)];
        corr = corrcoef(labelsTest,yhat_test);
        accuracy_test = [accuracy_test;corr(2,1)];

        disp(i)
    end

    mean_accuracy_train = [mean_accuracy_train mean(accuracy_train)];
    mean_accuracy_test = [mean_accuracy_test mean(accuracy_test)];


end

% Compute the final accuracies
mean_accuracy_train = mean(mean_accuracy_train);
mean_accuracy_test = mean(mean_accuracy_test);





