%% This script computes the power change ratio

%% Parameters (can be changed)

average_file_location = 'C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\ComputedData\';

electrode = 22; %Cz is 30

tBeforeStart = 2.4; % Time in seconds before movement onset
tAfterStart = 2.4; % Time in seconds after movement onset

do_significance = true; % Do significance analysis
significanceThresh = 0.05; % p value significance threshold
cohenThresh = 0.3; % Cohen's d threshold

%% Fixed variables (no need to change)

fsample  = 256; %Sampling frequency
time = -(round(tBeforeStart*fsample)/fsample):1/fsample:tAfterStart; %Time vector

%% Power change ratio computation

figure
hold on
magSignificance = {};
% Iterate over all frequency bands
for fBand = 1:3
    switch(fBand)
        case 1
            frequencyBand = 'theta';
            freqsLim = [8,4];
        case 2
            frequencyBand = 'alpha';
            freqsLim = [12,9];
        case 3
            frequencyBand = 'beta';
            freqsLim = [30,13];
    end
    

    mag_smoothed0 = [];
    mag_smoothed20 = [];
    mag_smoothed40 = [];
    mag_smoothed60 = [];
    % Iterate over all subjects
    for s=1:length(files)
        %Get the name of the subject to load its average power file
        name = strsplit(files{s},'Data');
        cond = strsplit(name{2},'.mat');
        if strcmp(cond{1},'_p')
            subjectName = strcat(name{1},'_Pas');
        else
            subjectName = strcat(name{1},'_Act');
        end
        display(subjectName)
        
        % Load the average power file
        %av_pow = load(strcat(average_file_location,'AveragePower_',subjectName,'_',frequencyBand,'.mat'));
        av_pow = load(strcat(average_file_location,'AveragePow_',subjectName,'_',frequencyBand,'_electrode',num2str(electrode),'.mat'));
        av_pow = av_pow.av_pow;

        % Load the file
        load(files{s});

        % Band pass filter to remove artifacts from other bands (might be
        % redundant)
        freqfilt1 = freqsLim(2);
        freqfilt2 = freqsLim(1);
        filter = designfilt('bandpassiir','FilterOrder',20, ...
                 'HalfPowerFrequency1',freqfilt1,'HalfPowerFrequency2',freqfilt2, ...
                 'SampleRate',fsample);
        eeg = cat(1,zeros(2000,64),eeg); %Smalll trick to avoid artifacts at beginning
        eeg = filtfilt(filter,eeg);
        eeg(1:2000,:) = [];

        % Split the trials into groups according to their error
        brain0 = [];
        brain20 = [];
        brain40 = [];
        brain60 = [];
        maxDev = cell2mat({behaviour.traj.TangVel});
        maxDev(find(behaviour.forces(:,1)==0)) = [];
        sorted = sort(maxDev);
        limInferior = sorted(round(size(sorted,2)/3));
        limSuperior = sorted(round(size(sorted,2)*2/3));

        % Find the values where trial starts
        start = find(markers.value==0 | markers.value == 51 | markers.value == 52 | markers.value == 53 | markers.value == 101 | markers.value == 102 | markers.value == 103);

        brain0_oneS = [];
        brain20_oneS = [];
        brain40_oneS = [];
        brain60_oneS = [];
        % Iterate over all trials
        for i=2:size(start,1)-1
            if markers.value(start(i)) == 0
                timestamp = markers.position(start(i));
                brain0_oneS = cat(3,brain0_oneS,eeg(timestamp-round(tBeforeStart*fsample):timestamp+floor(tAfterStart*fsample),:));
            else

                if behaviour.traj(i).TangVel < limInferior
                    %Bin small deviation
                    timestamp = markers.position(start(i));
                    brain20_oneS = cat(3,brain20_oneS,eeg(timestamp-round(tBeforeStart*fsample):timestamp+floor(tAfterStart*fsample),:));

                elseif behaviour.traj(i).TangVel >= limSuperior
                    %Bin big deviation
                    timestamp = markers.position(start(i));
                    brain60_oneS = cat(3,brain60_oneS,eeg(timestamp-round(tBeforeStart*fsample):timestamp+floor(tAfterStart*fsample),:));

                else 
                    %Bin medium deviation
                    timestamp = markers.position(start(i));
                    brain40_oneS = cat(3,brain40_oneS,eeg(timestamp-round(tBeforeStart*fsample):timestamp+floor(tAfterStart*fsample),:));

                end
            end
        end

        % Get only some trials with no deviation so that the clusters are
        % roughly equinumerable
        brain0_oneS = brain0_oneS(:,:,randperm(size(brain0_oneS,3),round(mean([size(brain20_oneS,3),size(brain40_oneS,3),size(brain60_oneS,3)]))));

        brain0 = cat(3,brain0,brain0_oneS);
        brain20 = cat(3,brain20,brain20_oneS);
        brain40 = cat(3,brain40,brain40_oneS);
        brain60 = cat(3,brain60,brain60_oneS);

        % Iterate over the four clusters
        for iteration=1:4
            switch(iteration)
                case 1
                    b = brain0;
                    deviation = 'None';
                case 2
                    b = brain20;
                    deviation = 'Weak';
                case 3
                    b = brain40;
                    deviation = 'Medium';
                case 4
                    b = brain60;
                    deviation = 'Strong';
            end


            coef = [];
            f_coef = [];
            mag = [];
            ph = [];
            % Iterate over all trials of this cluster
            for t=1:size(b,3)
                [wt,f] = cwt(b(:,electrode,t),'amor',fsample); %Get the time-freq coefficients
                valid_f = find(f<freqsLim(1) & f>freqsLim(2)); %Keep only the frequencies of this band
                f = f(valid_f);
                wt = wt(valid_f,:);
                pow = abs(wt).^2+1; %Compute the power
                pow = log10(pow); %Log normalization
                mag = cat(3,mag,100*pow ./ av_pow - 100); %Concatente all the trials
            end

            % Get the average for all trials and all frequencies
            mag_1 = mean(mag,3);
            mag_2 = mean(mag_1,1);
            
            % Save the  values for significance analysis
            magSignificance{s,fBand,iteration} = squeeze(mean(mag,1));
            

            % Concatenate all the powers from all the subjects
            switch(iteration)
                case 1
                    mag_smoothed0 = cat(2,mag_smoothed0,mag_2');
                case 2
                    mag_smoothed20 = cat(2,mag_smoothed20,mag_2');
                case 3
                    mag_smoothed40 = cat(2,mag_smoothed40,mag_2');
                case 4
                    mag_smoothed60 = cat(2,mag_smoothed60,mag_2');
            end

        end
    end

    % Do the average for all the subjects
    mag_smoothed0 = mean(mag_smoothed0,2);
    mag_smoothed20 = mean(mag_smoothed20,2);
    mag_smoothed40 = mean(mag_smoothed40,2);
    mag_smoothed60 = mean(mag_smoothed60,2);

    % Plot the results
    subplot(1,3,fBand);
    hold on
    plot(time,mag_smoothed0,'LineWidth',2);
    plot(time,mag_smoothed20,'LineWidth',2);
    plot(time,mag_smoothed40,'LineWidth',2);
    plot(time,mag_smoothed60,'LineWidth',2);
    plot([0,0],[-40,120],'k','LineStyle','--')
    plot([-2,2],[0,0],'k','LineStyle','--')
    ylim([-40,120])
    xlim([-2,2])
    xlabel('Time (s)')
    title(frequencyBand);
    if fBand == 1
        ylabel('Power change (%)');
    end
    if fBand == 3
        legend('None\_TV','Small\_TV','Medium\_TV','Large\_TV')
    end
    
    
end



%%
if do_significance == true
    
    % Find p values doing ANOVA and multiple comparisons correction
    magTheta = cat(2,[magSignificance{:,1,2}],[magSignificance{:,1,3}],[magSignificance{:,1,4}]);
    magAlpha = cat(2,[magSignificance{:,2,2}],[magSignificance{:,2,3}],[magSignificance{:,2,4}]);
    magBeta = cat(2,[magSignificance{:,3,2}],[magSignificance{:,3,3}],[magSignificance{:,3,4}]);

    for t=1:length(time)
        vectorTheta = magTheta(t,:)';
        groupsTheta = cat(1,1*ones(size([magSignificance{:,1,2}],2),1),2*ones(size([magSignificance{:,1,3}],2),1),3*ones(size([magSignificance{:,1,4}],2),1));    
        [p,~,stats] = anova1(vectorTheta,groupsTheta,'off');
        [result] = multcompare(stats,'Display','off','CType','bonferroni');
        p_2040_Theta(t) = result(1,6);
        p_2060_Theta(t) = result(2,6);
        p_4060_Theta(t) = result(3,6);

        vectorAlpha = magAlpha(t,:)';
        groupsAlpha = cat(1,1*ones(size([magSignificance{:,2,2}],2),1),2*ones(size([magSignificance{:,2,3}],2),1),3*ones(size([magSignificance{:,2,4}],2),1));
        [p,~,stats] = anova1(vectorAlpha,groupsAlpha,'off');
        [result] = multcompare(stats,'Display','off','CType','bonferroni');
        p_2040_Alpha(t) = result(1,6);
        p_2060_Alpha(t) = result(2,6);
        p_4060_Alpha(t) = result(3,6);

        vectorBeta = magBeta(t,:)';
        groupsBeta = cat(1,1*ones(size([magSignificance{:,3,2}],2),1),2*ones(size([magSignificance{:,3,3}],2),1),3*ones(size([magSignificance{:,3,4}],2),1));
        [p,~,stats] = anova1(vectorBeta,groupsBeta,'off');
        [result] = multcompare(stats,'Display','off','CType','bonferroni');
        p_2040_Beta(t) = result(1,6);
        p_2060_Beta(t) = result(2,6);
        p_4060_Beta(t) = result(3,6);

    end
    
    
    % Find Cohen's d size effect index
    cohend_2040_Theta = (abs(mean([magSignificance{:,1,2}],2) - mean([magSignificance{:,1,3}],2)) ./ sqrt((std([magSignificance{:,1,2}],0,2).^2 + std([magSignificance{:,1,3}],0,2).^2)/2))';
    cohend_2060_Theta = (abs(mean([magSignificance{:,1,2}],2) - mean([magSignificance{:,1,4}],2)) ./ sqrt((std([magSignificance{:,1,2}],0,2).^2 + std([magSignificance{:,1,3}],0,2).^2)/2))';
    cohend_4060_Theta = (abs(mean([magSignificance{:,1,3}],2) - mean([magSignificance{:,1,4}],2)) ./ sqrt((std([magSignificance{:,1,2}],0,2).^2 + std([magSignificance{:,1,3}],0,2).^2)/2))';

    cohend_2040_Alpha = (abs(mean([magSignificance{:,2,2}],2) - mean([magSignificance{:,2,3}],2)) ./ sqrt((std([magSignificance{:,1,2}],0,2).^2 + std([magSignificance{:,1,3}],0,2).^2)/2))';
    cohend_2060_Alpha = (abs(mean([magSignificance{:,2,2}],2) - mean([magSignificance{:,2,4}],2)) ./ sqrt((std([magSignificance{:,1,2}],0,2).^2 + std([magSignificance{:,1,3}],0,2).^2)/2))';
    cohend_4060_Alpha = (abs(mean([magSignificance{:,2,3}],2) - mean([magSignificance{:,2,4}],2)) ./ sqrt((std([magSignificance{:,1,2}],0,2).^2 + std([magSignificance{:,1,3}],0,2).^2)/2))';

    cohend_2040_Beta = (abs(mean([magSignificance{:,3,2}],2) - mean([magSignificance{:,3,3}],2)) ./ sqrt((std([magSignificance{:,1,2}],0,2).^2 + std([magSignificance{:,1,3}],0,2).^2)/2))';
    cohend_2060_Beta = (abs(mean([magSignificance{:,3,2}],2) - mean([magSignificance{:,3,4}],2)) ./ sqrt((std([magSignificance{:,1,2}],0,2).^2 + std([magSignificance{:,1,3}],0,2).^2)/2))';
    cohend_4060_Beta = (abs(mean([magSignificance{:,3,3}],2) - mean([magSignificance{:,3,4}],2)) ./ sqrt((std([magSignificance{:,1,2}],0,2).^2 + std([magSignificance{:,1,3}],0,2).^2)/2))';

    
    % Plot figure with significance analysis
    figure
    hold on

    subplot(1,3,1)
    hold on
    plot(time,mean([magSignificance{:,1,1}],2),'LineWidth',2);
    plot(time,mean([magSignificance{:,1,2}],2),'LineWidth',2);
    plot(time,mean([magSignificance{:,1,3}],2),'LineWidth',2);
    plot(time,mean([magSignificance{:,1,4}],2),'LineWidth',2);
    plot([0,0],[-40,120],'k','LineStyle','--')
    plot([-2,2],[0,0],'k','LineStyle','--')
    ylim([-40,120])
    xlim([-2,2])
    xlabel('Time (s)')
    ylabel('Power change (%)')
    title('theta')
    ind = find(p_2040_Theta<significanceThresh & cohend_2040_Theta>cohenThresh);
    scatter(time(ind),-25 * ones(length(ind),1),'filled','MarkerFaceColor',[245,72,233]/255);
    ind = find(p_2060_Theta<significanceThresh & cohend_2060_Theta>cohenThresh);
    scatter(time(ind),-30 * ones(length(ind),1),'filled','MarkerFaceColor',[242,242,64]/255);
    ind = find(p_4060_Theta<significanceThresh & cohend_4060_Theta>cohenThresh);
    scatter(time(ind),-35 * ones(length(ind),1),'filled','MarkerFaceColor',[71,219,219]/255);
    set(gca,'fontsize',15)

    subplot(1,3,2)
    hold on
    plot(time,mean([magSignificance{:,2,1}],2),'LineWidth',2);
    plot(time,mean([magSignificance{:,2,2}],2),'LineWidth',2);
    plot(time,mean([magSignificance{:,2,3}],2),'LineWidth',2);
    plot(time,mean([magSignificance{:,2,4}],2),'LineWidth',2);
    plot([0,0],[-40,120],'k','LineStyle','--')
    plot([-2,2],[0,0],'k','LineStyle','--')
    ylim([-40,120])
    xlim([-2,2])
    xlabel('Time (s)')
    title('alpha')
    ind = find(p_2040_Alpha<significanceThresh & cohend_2040_Alpha>cohenThresh);
    scatter(time(ind),-25 * ones(length(ind),1),'filled','MarkerFaceColor',[245,72,233]/255);
    ind = find(p_2060_Alpha<significanceThresh & cohend_2060_Alpha>cohenThresh);
    scatter(time(ind),-30 * ones(length(ind),1),'filled','MarkerFaceColor',[242,242,64]/255);
    ind = find(p_4060_Alpha<significanceThresh & cohend_4060_Alpha>cohenThresh);
    scatter(time(ind),-35 * ones(length(ind),1),'filled','MarkerFaceColor',[71,219,219]/255);
    set(gca,'fontsize',15)
    

    subplot(1,3,3)
    hold on
    plot(time,mean([magSignificance{:,3,1}],2),'LineWidth',2);
    plot(time,mean([magSignificance{:,3,2}],2),'LineWidth',2);
    plot(time,mean([magSignificance{:,3,3}],2),'LineWidth',2);
    plot(time,mean([magSignificance{:,3,4}],2),'LineWidth',2);
    ylim([-40,120])
    xlim([-2,2])
    xlabel('Time (s)')
    title('beta')
    ind = find(p_2040_Beta<significanceThresh & cohend_2040_Beta>cohenThresh);
    scatter(time(ind),-25 * ones(length(ind),1),'filled','MarkerFaceColor',[245,72,233]/255);
    ind = find(p_2060_Beta<significanceThresh & cohend_2060_Beta>cohenThresh);
    scatter(time(ind),-30 * ones(length(ind),1),'filled','MarkerFaceColor',[242,242,64]/255);
    ind = find(p_4060_Beta<significanceThresh & cohend_4060_Beta>cohenThresh);
    scatter(time(ind),-35 * ones(length(ind),1),'filled','MarkerFaceColor',[71,219,219]/255);
    plot([0,0],[-40,120],'k','LineStyle','--')
    plot([-2,2],[0,0],'k','LineStyle','--')
    set(gca,'fontsize',15)
    
    
    
    lgd=legend('None\_PV','Small\_PV','Medium\_PV','Large\_PV','Small/Medium significant','Small/Large significant','Medium/Large significant');
    %lgd=legend('None\_PV','Small\_PV','Medium\_PV','Large\_PV');
    lgd.FontSize = 15;
    
end

