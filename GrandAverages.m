%% This script does the grand averages analysis

%% Parameters (can be changed)

tBeforeStart = 0.2; %Time before movement onset in seconds
tAfterStart = 0.5; %Time after movement onset in seconds

channel = 30; %Channel to analyze: 30 is Cz

% Choose what to plot
do_temporal = false; % Plot temporal grand averages
do_topoplots = false; % Plot topoographies
do_spectogram = true; % Plot time-frequeny grand averages

% Max and min values for representations
minValueTopoplot = -12; %12 is a good choice
maxValueTopoplot = 12; %12 is a good choice
maxValuePowerTimeFreq = 30; %30 for active and 10 for passive are good choices
maxValueCohen = 0.7; % 0.7 is already quite a high effect size index value

%Significance thresholds
cohenThresh = 0.3; % Cohen's d value
significanceThresh = 0.05; %Significance threshold level for p values

%% Fixed variables (no need to change)
significanceThresh = 0.05; %Significance threshold level for p values

fsample  = 256; %Sampling frequency
load('LocationFile.mat');


%% File loading and epoching

brain0 = [];
brain20 = [];
brain40 = [];
brain60 = [];
size_average0 = [];
size_average20 = [];
size_average40 = [];
size_average60 = [];
for f_i = 1:size(files,2) %Loop to load all the chosen files
    clear markers
    clear eeg
    clear eog
    clear behavior

    load(files{f_i});
    
    % Divide the trials in four bins by their error
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
    for i=2:size(start,1)-1
        if markers.value(start(i)) == 0
            timestamp = markers.position(start(i));
            brain0_oneS = cat(3,brain0_oneS,eeg(timestamp-round(tBeforeStart*fsample):timestamp+tAfterStart*fsample,:));
        else
        
            if behaviour.traj(i).TangVel < limInferior
                %Bin small error
                timestamp = markers.position(start(i));
                brain20_oneS = cat(3,brain20_oneS,eeg(timestamp-round(tBeforeStart*fsample):timestamp+tAfterStart*fsample,:));

            elseif behaviour.traj(i).TangVel >= limSuperior
                %Bin large error
                timestamp = markers.position(start(i));
                brain60_oneS = cat(3,brain60_oneS,eeg(timestamp-round(tBeforeStart*fsample):timestamp+tAfterStart*fsample,:));

            else 
                %Bin medium error
                timestamp = markers.position(start(i));
                brain40_oneS = cat(3,brain40_oneS,eeg(timestamp-round(tBeforeStart*fsample):timestamp+tAfterStart*fsample,:));

            end
        end
    end

    % Select randomly only a few trials that don't have deviation, so that
    % the number of this bin is similar to the number of the other bins.
    brain0_oneS = brain0_oneS(:,:,randperm(size(brain0_oneS,3),round(mean([size(brain20_oneS,3),size(brain40_oneS,3),size(brain60_oneS,3)]))));
    
    brain0 = cat(3,brain0,brain0_oneS);
    brain20 = cat(3,brain20,brain20_oneS);
    brain40 = cat(3,brain40,brain40_oneS);
    brain60 = cat(3,brain60,brain60_oneS);
    
    size_average0 = cat(1,size_average0,size(brain0_oneS,3));
    size_average20 = cat(1,size_average20,size(brain20_oneS,3));
    size_average40 = cat(1,size_average40,size(brain40_oneS,3));
    size_average60 = cat(1,size_average60,size(brain60_oneS,3));
    
end

%Compute the average sizes of the bins to report them
size_average0 = mean(size_average0);
size_average20 = mean(size_average20);
size_average40 = mean(size_average40);
size_average60 = mean(size_average60);


% Define the time vector to plot the results in function of time instead of
% samples
time = -(round(tBeforeStart*fsample)/fsample):1/fsample:tAfterStart;

%Baseline correction
brain = cat(3,brain0,brain20,brain40,brain60);
brain = brain - nanmean(brain(1:round(0.2*fsample),:,:),1);

%Re-do the bins after the baseline correction
s = [size(brain0,3) size(brain20,3) size(brain40,3) size(brain60,3)];
lims = [s(1) s(1)+s(2) s(1)+s(2)+s(3)];
brain0 = brain(:,:,1:lims(1));
brain20 = brain(:,:,lims(1)+1:lims(2));
brain40 = brain(:,:,lims(2)+1:lims(3));
brain60 = brain(:,:,lims(3)+1:end);


%Find grand averages means
gA0 = squeeze(nanmean(brain0,3));
gA20 =squeeze(nanmean(brain20,3));
gA40 =squeeze(nanmean(brain40,3));
gA60 = squeeze(nanmean(brain60,3));


%Samples where the peaks should be looked for
areaMinimum = 76:95;
areaMaximum = 96:120;

%Find the locations of positive and negative peaks for each bin, and the
%ErrP amplitude.
[minimum0,indMin0] = min(gA0(areaMinimum,channel));
[maximum0,indMax0] = max(gA0(areaMaximum,channel));
ERPAmp0 = maximum0 - minimum0;
[minimum20,indMin20] = min(gA20(areaMinimum,channel));
[maximum20,indMax20] = max(gA20(areaMaximum,channel));
ERPAmp20 = maximum20 - minimum20;
[minimum40,indMin40] = min(gA40(areaMinimum,channel));
[maximum40,indMax40] = max(gA40(areaMaximum,channel));
ERPAmp40 = maximum40 - minimum40;
[minimum60,indMin60] = min(gA60(areaMinimum,channel));
[maximum60,indMax60] = max(gA60(areaMaximum,channel));
ERPAmp60 = maximum60 - minimum60;




%% Temporal analysis

if do_temporal == true
    figure
    hold on
    ylim([-12 10])
    
    % Get the same number of elements from each bin to do the significance
    % analysis.
    [minimum,ind] = min([size(brain0,3),size(brain20,3),size(brain40,3),size(brain60,3)]);
    switch ind
        case 1
            b0 = squeeze(brain0(:,channel,:))';
            b20 = squeeze(brain20(:,channel,randperm(size(brain20,3),size(brain0,3))))';
            b40 = squeeze(brain40(:,channel,randperm(size(brain40,3),size(brain0,3))))';
            b60 = squeeze(brain60(:,channel,randperm(size(brain60,3),size(brain0,3))))';
        case 2
            b0 = squeeze(brain0(:,channel,randperm(size(brain0,3),size(brain20,3))))';
            b20 = squeeze(brain20(:,channel,:))';
            b40 = squeeze(brain40(:,channel,randperm(size(brain40,3),size(brain20,3))))';
            b60 = squeeze(brain60(:,channel,randperm(size(brain60,3),size(brain20,3))))';
        case 3
            b0 = squeeze(brain0(:,channel,randperm(size(brain0,3),size(brain40,3))))';
            b20 = squeeze(brain20(:,channel,randperm(size(brain20,3),size(brain40,3))))';
            b40 = squeeze(brain40(:,channel,:))';
            b60 = squeeze(brain60(:,channel,randperm(size(brain60,3),size(brain40,3))))';
        case 4
            b0 = squeeze(brain0(:,channel,randperm(size(brain0,3),size(brain60,3))))';
            b20 = squeeze(brain20(:,channel,randperm(size(brain20,3),size(brain60,3))))';
            b40 = squeeze(brain40(:,channel,randperm(size(brain40,3),size(brain60,3))))';
            b60 = squeeze(brain60(:,channel,:))';
    end

    % Plot temporal grand averages
    plot(time,gA0(:,channel),'LineWidth',2,'Color',[160,160,160]/255)
    plot(time,gA20(:,channel),'LineWidth',2,'Color',[51,102,205]/255)
    plot(time,gA40(:,channel),'LineWidth',2,'Color',[205,51,51]/255)
    plot(time,gA60(:,channel),'LineWidth',2,'Color',[50,182,50]/255)

    % Do significance analysis (with anova)
    p_2040 = [];
    p_2060 = [];
    p_4060 = [];
    for t=1:size(brain,1)
        [p,~,stats] = anova1(cat(2,b20(:,t),b40(:,t),b60(:,t)),[],'off');
        [result] = multcompare(stats,'Display','off','CType','bonferroni');
        p_2040 = cat(2,p_2040,result(1,6));
        p_2060 = cat(2,p_2060,result(2,6));
        p_4060 = cat(2,p_4060,result(3,6));
    end
    
    cohend_2040 = abs(mean(b20,1) - mean(b40,1)) ./ sqrt((std(b20,0,1).^2 + std(b0,0,1).^2)/2);
    cohend_2060 = abs(mean(b20,1) - mean(b60,1)) ./ sqrt((std(b20,0,1).^2 + std(b60,0,1).^2)/2);
    cohend_4060 = abs(mean(b40,1) - mean(b60,1)) ./ sqrt((std(b40,0,1).^2 + std(b60,0,1).^2)/2);

    
    
    ind = find(p_2040<significanceThresh & cohend_2040>cohenThresh);
    scatter(time(ind),-9 * ones(length(ind),1),'filled','MarkerFaceColor',[245,72,233]/255);
    ind = find(p_4060<significanceThresh & cohend_4060>cohenThresh);
    scatter(time(ind),-10 * ones(length(ind),1),'filled','MarkerFaceColor',[242,242,64]/255);
    ind = find(p_2060<significanceThresh & cohend_2060>cohenThresh);
    scatter(time(ind),- 11 *ones(length(ind),1),'filled','MarkerFaceColor',[71,219,219]/255);

    plot([0,0], [-20,20],'k')
    plot(time,zeros(size(time,2)),'k')

    title('Temporal grand averages')
    lgd=legend('None\_TV','Small\_TV','Medium\_TV','Large\_TV','Small/Medium significant','Medium/Large significant','Small/Large significant');
    lgd.FontSize = 12;
    xlabel('Time (s)')
    ylabel('Voltage (uV)')
    set(gca,'fontsize',12)
    hold off
end


%% Topoplots analysis

if do_topoplots == true
    figure
    hold on
    
    %Do the average of the times of the peaks
    timeMin = round(mean([indMin20,indMin40,indMin60])) + areaMinimum(1);
    timeMax = round(mean([indMax20,indMax40,indMax60])) + areaMaximum(1);
    topoplots_time = [timeMin,timeMax];
    
    %Plot the topoplots of the positivity and negativity for each bin
    for i=1:4
        switch(i)
            case 1
                topoMin = mean(brain0,3);
                topoMin = topoMin(timeMin,:);
                topoMax = mean(brain0,3);
                topoMax = topoMax(timeMax,:);
                subplotcounts = [1,2];
                categoryText = 'None\_TV';
            case 2
                topoMin = mean(brain20,3);
                topoMin = topoMin(timeMin,:);
                topoMax = mean(brain20,3);
                topoMax = topoMax(timeMax,:);
                subplotcounts = [3,4];
                categoryText = 'Small\_TV';
            case 3
                topoMin = mean(brain40,3);
                topoMin = topoMin(timeMin,:);
                topoMax = mean(brain40,3);
                topoMax = topoMax(timeMax,:);
                subplotcounts = [5,6];
                categoryText = 'Medium\_TV';
            case 4
                topoMin = mean(brain60,3);
                topoMin = topoMin(timeMin,:);
                topoMax = mean(brain60,3);
                topoMax = topoMax(timeMax,:);
                subplotcounts = [7,8];
                categoryText = 'Large\_TV';
        end
        
        subplot(4,2,subplotcounts(1));
        hold on
        topoplot(topoMin,channelLocation,'maplimits',[minValueTopoplot,maxValueTopoplot]);
        if i == 1
            title('Negativity')
        end
        text(-2,0,categoryText,'FontSize',10,'FontWeight','bold');
        subplot(4,2,subplotcounts(2));
        hold on
        topoplot(topoMax,channelLocation,'maplimits',[minValueTopoplot,maxValueTopoplot]);
        if i == 1
            title('Positivity')
        end
        caxis([minValueTopoplot,maxValueTopoplot])
        colorbar;
    end
    
end


%% Time-frequency analysis

if do_spectogram
    figure
    hold on
    
    % Do the spectogram and phase computation for each bin
    for iteration=1:4
        switch(iteration)
            case 1
                b = brain0;
                deviation = 'None\_TV';
            case 2
                b = brain20;
                deviation = 'Small\_TV';
            case 3
                b = brain40;
                deviation = 'Medium\_TV';
            case 4
                b = brain60;
                deviation = 'Large\_TV';
        end


        coef = [];
        f_coef = [];
        mag = [];
        ph = [];
        for t=1:size(b,3)
            [wt,f] = cwt(b(:,channel,t),'amor',fsample);
            fValid = find(f<=35);
            f = f(fValid);
            wt = wt(fValid,:);
            coef = cat(3,coef,wt);
            f_coef = cat(2,f_coef,f);
            mag = cat(3,mag,abs(wt));
            ph = cat(3,ph,cos(angle(wt))+j*sin(angle(wt)));
        end

        f = mean(f_coef,2);
        
        % Plot the power
        subplot(2,4,iteration);
        hold on
        imagesc(time,log2(f),mean(mag.^2,3))
        plot([0,0],[0,35],'k')
        xlim([-0.2,0.5])
        set(gca,'fontsize',10)
        title(strcat(deviation,'; Power'))
        caxis([0 maxValuePowerTimeFreq])
        xlabel('Time (s)')
        if iteration==1
            ylabel('Frequency (Hz)')
        end
        Yticks = 2.^(round(log2(min(f))):round(log2(max(f))));
        AX = gca;
        AX.YLim = log2([min(f), max(f)]);
        AX.YTick = log2(Yticks);
        AX.YDir = 'normal';
        set(AX,'YLim',log2([min(f),max(f)]), ...
            'layer','top', ...
            'YTick',log2(Yticks(:)), ...
            'YTickLabel',num2str(sprintf('%g\n',Yticks)), ...
            'layer','top')
        if iteration==4
            c = colorbar;
            set(c,'Position',[.92 .59 .03 .33]);
        end

        %Plot the phase
        subplot(2,4,iteration+4);
        hold on
        imagesc(time,log2(f),abs(mean(ph,3)))
        plot([0,0],[0,35],'k')
        xlim([-0.2,0.5])
        title(strcat(deviation,'; Phase'))
        caxis([0 1])
        xlabel('Time (s)')
        if iteration==1
            ylabel('Frequency (Hz)')
        end
        Yticks = 2.^(round(log2(min(f))):round(log2(max(f))));
        AX = gca;
        AX.YLim = log2([min(f), max(f)]);
        AX.YTick = log2(Yticks);
        AX.YDir = 'normal';
        set(AX,'YLim',log2([min(f),max(f)]), ...
            'layer','top', ...
            'YTick',log2(Yticks(:)), ...
            'YTickLabel',num2str(sprintf('%g\n',Yticks)), ...
            'layer','top')
        if iteration==4
            c = colorbar;
            set(c,'Position',[.92 .11 .03 .33]);
        end
        
        switch(iteration)
            case 1
                mag0 = mag;
                ph0 = ph;
            case 2
                mag20 = mag;
                ph20 = ph;
            case 3
                mag40 = mag;
                ph40 = ph;
            case 4
                mag60 = mag;
                ph60 = ph;
        end

    end
    
    % Statistical analysis
    % Do significance analysis (with anova)
    p_2040_mag = [];
    p_2060_mag = [];
    p_4060_mag = [];
    p_2040_ph = [];
    p_2060_ph = [];
    p_4060_ph = [];
    for fr = 1:size(mag,1)
        for t=1:size(brain,1)
            % Power significance
            vector = cat(1,squeeze(mag20(fr,t,:)),squeeze(mag40(fr,t,:)),squeeze(mag60(fr,t,:)));
            groups = cat(1,1*ones(size(mag20,3),1),2*ones(size(mag40,3),1),3*ones(size(mag60,3),1));
            [p,~,stats] = anova1(vector,groups,'off');
            [result] = multcompare(stats,'Display','off','CType','bonferroni');
            p_2040_mag(fr,t) = result(1,6);
            p_2060_mag(fr,t) = result(2,6);
            p_4060_mag(fr,t) = result(3,6);
            
            % Phase significance
            vector = cat(1,abs(squeeze(ph20(fr,t,:))),abs(squeeze(ph40(fr,t,:))),abs(squeeze(ph60(fr,t,:))));
            groups = cat(1,1*ones(size(ph20,3),1),2*ones(size(ph40,3),1),3*ones(size(ph60,3),1));
            [p,~,stats] = anova1(vector,groups,'off');
            [result] = multcompare(stats,'Display','off','CType','bonferroni');
            p_2040_ph(fr,t) = result(1,6);
            p_2060_ph(fr,t) = result(2,6);
            p_4060_ph(fr,t) = result(3,6);
            
        end
    end
    
    cohend_2040 = abs(mean(mag20,3) - mean(mag40,3)) ./ sqrt((std(mag20,0,3).^2 + std(mag40,0,3).^2)/2);
    cohend_2060 = abs(mean(mag20,3) - mean(mag60,3)) ./ sqrt((std(mag20,0,3).^2 + std(mag60,0,3).^2)/2);
    cohend_4060 = abs(mean(mag40,3) - mean(mag60,3)) ./ sqrt((std(mag40,0,3).^2 + std(mag60,0,3).^2)/2);

    
    figure
    hold on
    for iteration=1:3
        switch(iteration)
            case 1
                p_mag = p_2040_mag;
                cohend = cohend_2040;
                title_p = 'Small/Medium';
            case 2
                p_mag = p_2060_mag;
                cohend = cohend_2060;
                title_p = 'Small/Large';
            case 3
                p_mag = p_4060_mag;
                cohend = cohend_4060;
                title_p = 'Medium/Large';
        end
        
        subplot(3,3,iteration)
        hold on
        imagesc(time,log2(f),p_mag<0.05)
        plot([0,0],[0,35],'k')
        xlim([-0.2,0.5])
        if iteration==1
            ylabel('Frequency (Hz)')
        end
        xlabel('Time (s)')
        title(title_p)
        
        Yticks = 2.^(round(log2(min(f))):round(log2(max(f))));
        AX = gca;
        AX.YLim = log2([min(f), max(f)]);
        AX.YTick = log2(Yticks);
        AX.YDir = 'normal';
        set(AX,'YLim',log2([min(f),max(f)]), ...
            'layer','top', ...
            'YTick',log2(Yticks(:)), ...
            'YTickLabel',num2str(sprintf('%g\n',Yticks)), ...
            'layer','top')
        if iteration==3
            c = colorbar;
            set(c,'Position',[.92 .72 .03 .20]);
        end
        set(gca,'fontsize',12)
        
        subplot(3,3,iteration+3)
        hold on
        imagesc(time,log2(f),cohend);
        plot([0,0],[0,35],'k');
        xlim([-0.2,0.5]);
        if iteration==1
            ylabel('Frequency (Hz)');
        end
        xlabel('Time (s)');
        title(title_p);
        caxis([0 maxValueCohen]);

        Yticks = 2.^(round(log2(min(f))):round(log2(max(f))));
        AX = gca;
        AX.YLim = log2([min(f), max(f)]);
        AX.YTick = log2(Yticks);
        AX.YDir = 'normal';
        set(AX,'YLim',log2([min(f),max(f)]), ...
            'layer','top', ...
            'YTick',log2(Yticks(:)), ...
            'YTickLabel',num2str(sprintf('%g\n',Yticks)), ...
            'layer','top')
        if iteration==3
            c = colorbar;
            set(c,'Position',[.92 .42 .03 .20]);
        end
        set(gca,'fontsize',12)
        
        
        subplot(3,3,iteration+6)
        hold on
        imagesc(time,log2(f),p_mag<0.05 & cohend>0.3)
        plot([0,0],[0,35],'k')
        xlim([-0.2,0.5])
        if iteration==1
            ylabel('Frequency (Hz)')
        end
        xlabel('Time (s)')
        title(title_p)
        
        Yticks = 2.^(round(log2(min(f))):round(log2(max(f))));
        AX = gca;
        AX.YLim = log2([min(f), max(f)]);
        AX.YTick = log2(Yticks);
        AX.YDir = 'normal';
        set(AX,'YLim',log2([min(f),max(f)]), ...
            'layer','top', ...
            'YTick',log2(Yticks(:)), ...
            'YTickLabel',num2str(sprintf('%g\n',Yticks)), ...
            'layer','top')
        if iteration==3
            c = colorbar;
            set(c,'Position',[.92 .12 .03 .20]);
        end
        set(gca,'fontsize',12)
        
    end
    
   
  
end




