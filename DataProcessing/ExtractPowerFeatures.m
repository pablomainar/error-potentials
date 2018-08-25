%% This function extracts the power change ratio features



% Power features
powerAll = [];
powerAllTest = [];
if usePowerChangeFeat == true
    load('eegLabels.mat');
    electrodesPowerChange = frontoCentralElectrodes;
    for elec = 1:length(electrodesPowerChange)
        chan = electrodesPowerChange(elec);
        electrodeName = channelLabels{chan};
        
        freqsLimTheta = [8,4];
        freqsLimAlpha = [12,9];
        freqsLimBeta = [30,13];
        avpowTheta = load(strcat(average_file_location,'AveragePowElectrode',electrodeName,'\','AveragePow_',subjectName,'_theta_electrode',num2str(chan),'.mat'));
        avpowTheta = avpowTheta.av_pow;
        avpowAlpha = load(strcat(average_file_location,'AveragePowElectrode',electrodeName,'\','AveragePow_',subjectName,'_alpha_electrode',num2str(chan),'.mat'));
        avpowAlpha = avpowAlpha.av_pow;
        avpowBeta = load(strcat(average_file_location,'AveragePowElectrode',electrodeName,'\','AveragePow_',subjectName,'_beta_electrode',num2str(chan),'.mat'));
        avpowBeta = avpowBeta.av_pow;
        powerTheta = [];
        powerAlpha = [];
        powerBeta = [];
        for t=1:size(X,3)
            [wt,f] = cwt(X(:,chan,t),'amor',fsample);
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

        powerAllSingleChan = cat(1,powerTheta,powerAlpha,powerBeta);
        powerAll = cat(1,powerAll,powerAllSingleChan);

        
        powerThetaTest = [];
        powerAlphaTest = [];
        powerBetaTest = [];
        for t=1:size(Xtest,3)
            [wt,f] = cwt(Xtest(:,chan,t),'amor',fsample);
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

        powerAllTestSingleChan = cat(1,powerThetaTest,powerAlphaTest,powerBetaTest);
        powerAllTest = cat(1,powerAllTest,powerAllTestSingleChan);
    end
    
    
end
limit2 = limit1 + size(powerAll,1);






