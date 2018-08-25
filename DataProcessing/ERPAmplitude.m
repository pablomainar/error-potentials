%% This script does the ErrP amplitude analysis


%% Parameters (can be changed)

tBeforeStart = 0.2; % Time in secons before movement onset
tAfterStart = 0.5; % Time in seconds after movement onset

bins = 3:50; % Number of bins to consider. Can be either one number (like 30) or an array (like 3:50)

channel = 30; %Cz is 30

% These two should only be changed if tBeforeStart has changed (different
% to 0.2)
areaMinimum = 76:95; % Samples where the minimum peak is looked for
areaMaximum = 96:120; % Samples where the maximum peak is looked for
     
file_location = 'C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\ComputedData\'; % Location where the data is saved


%% Fixed variables (no need to change)

fsample  = 256; % Sampling frequency
time = -(round(tBeforeStart*fsample)/fsample):1/fsample:tAfterStart; % Time vector

% Only draw the grand averages and the model visualization if the number of
% bins to consider is one. On the other hand, only draw the R^2 analysis if
% the number of bins to consider is bigger than one.
if length(bins) == 1
    draw_GA_Model = true;
    draw_R2 = false;
else
    draw_GA_Model = false;
    draw_R2 = true;
end


%% Compute the ErrP amplitude analysis

R_all = [];
% Iterate over all the number of bins
for nBins = bins
    R = [];
    disp(nBins)

    brain_All = [];
    meanDev_All = [];
    clusters = [];
    % Iterate over all subjects
    for f_i = 1:size(files,2)
        clear markers
        clear eeg
        clear eog
        clear behavior

        load(files{f_i});
        
        % Only get some non perturbed trials to get roughly the same number
        % of trials for different force magnitudes
        index0 = find(behaviour.forces(:,1)==0);
        index20 = find(behaviour.forces(:,1)==1);
        index40 = find(behaviour.forces(:,1)==2);
        index60 = find(behaviour.forces(:,1)==3);
        size0 = numel(index0);
        size20 = numel(index20);
        size40 = numel(index40);
        size60 = numel(index60);
        size0_new = round(mean([size20,size40,size60]));
        index0_new = randsample(index0,size0_new);
        indeces = sort(cat(1,index0_new,index20,index40,index60));
        
        
        
        % Build the equinumerable clusters
        maxDev = cell2mat({behaviour.traj(indeces).TangVel});
        maxDev = maxDev + rand(size(maxDev))/100; %This is a small trick to avoid having very big clusters becaue the trials have the same deviation
        sorted = sort(maxDev);
        lims = [];
        for bin = 1:nBins
            if bin < nBins
                lims = cat(1,lims,sorted(round(size(sorted,2)*bin/nBins)));
            else
                lims = cat(1,lims,sorted(end));
            end
        end


        % Find the values where trial starts
        start = find(markers.value==0 | markers.value == 51 | markers.value == 52 | markers.value == 53 | markers.value == 101 | markers.value == 102 | markers.value == 103);

        brain_All = [];
        meanDev_All = [];
        clusters = [];
        % Iterate over all the trials and cluster them
        for iter=1:size(indeces)
            i = indeces(iter);
            timestamp = markers.position(start(i));
            brain_All = cat(3,brain_All,eeg(timestamp-round(tBeforeStart*fsample):timestamp+tAfterStart*fsample,:));
            meanDev_All = cat(1,meanDev_All,maxDev(iter));
            clusters = cat(2,clusters,find((maxDev(iter) <= lims)==1,1));
        end
    

        %Baseline correction
        brain_All = brain_All - nanmean(brain_All(1:round(0.2*fsample),:,:),1);

        % Find grand averages for each cluster
        gA = [];
        gADev = [];
        for bin = 1:nBins
            ind = find(clusters==bin);
            gA = cat(3,gA,mean(brain_All(:,:,ind),3));
            gADev = cat(1,gADev,mean(meanDev_All(ind)));
        end


        if draw_GA_Model == true
            figure
            hold on
            ylim([-20 20])
        end

        % Find the ErrP mean amplitude for each bin
        ERPAmp = [];
        for i=1:nBins
            [minimum,indMin] = min(gA(areaMinimum,channel,i));
            [maximum,indMax] = max(gA(areaMaximum,channel,i));
            ERPAmp = cat(1,ERPAmp,maximum - minimum);
            if draw_GA_Model == true
                plot(time,gA(:,channel,i),'LineWidth',1.2)
                plot([0,0], [-20,20],'k')
                plot(time,zeros(size(time,2)),'k')
                scatter(time(indMin+areaMinimum(1)-1),minimum,'k');
                scatter(time(indMax+areaMaximum(1)-1),maximum,'k');
                set(gca,'fontsize',12)
                xlabel('Time (s)')
                ylabel('Voltage (uV)')
            end
        end

        % Do linear regression
        y = ERPAmp;
        x = sqrt(cat(2,ones(nBins,1),gADev));
        b = x\y;
        yCalc = x*b;

        % Draw figure with the linear model for this number of bins
        if draw_GA_Model == true
            figure
            hold on
            scatter(x(:,2).^2,y,'filled')
            plot(x(:,2).^2,yCalc,'LineWidth',2.5)
            xlabel('Perpendicular velocity (mm/s)')
            ylabel('ERP Amplitude (uV)')
            title('sqrt perpendicular velocity')
            lgd=legend('Data points','Linear model');
            set(gca,'fontsize',15);
            lgd.FontSize = 15;
        end

        % Compute R^2
        R = [R;1- (sum((y-yCalc).^2)/sum((y-mean(y)).^2))];
    end
    
    % Concatenate R^2 for all the bins
    R_all = cat(1,R_all,nanmean(R));
end

%save('C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\ComputedData\RActDev.mat','R_all');

%% Plot the R^2 analysis figure

if draw_R2 == true
    figure
    hold on
    plot(bins,R_all,'b','LineWidth',2)
    scatter(bins,R_all,50,'b','filled')
    title('Resolution of the ErrP modulation');
    xlabel('Number of bins');
    ylabel('Coefficient of determination (R^2)');
    ylim([0 1])
end





