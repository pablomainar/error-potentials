%% This script does the time duration analysis from the movements

%% Load files

s = [];
forces = [];
for i=1:length(files)
    f = files{i};
    load(f);
    
    lengths = {behaviour.traj.Position}';
    for l = 1:length(lengths)
        % Each sample is taken in mean every 17 ms. The last second is
        % removed because it is the time taken to press the target button,
        % but the movement has finished already.
        new_s = size(lengths{l},1) * 17e-3 - 1;
        
        % A few passive trials (less than 5) are corrupted and give a
        % negative time, so they are removed
        if new_s < 0
            continue
        end
        
        s = cat(1,s,new_s);
        forces = cat(1,forces,behaviour.forces(l,1));
        
    end
    
    
end



%% Find mean, median and standart deviation of times for each force

% No force
ind = find(forces==0);
mean_s_0 = mean(s(ind));
median_s_0 = median(s(ind));
std_s_0 = std(s(ind));

% Force (any type)
ind = find(forces==1 | forces==2 | forces == 3);
mean_s_any = mean(s(ind));
median_s_any = median(s(ind));
std_s_any = std(s(ind));

% Small force
ind = find(forces==1);
mean_s_1 = mean(s(ind));
median_s_1 = median(s(ind));
std_s_1 = std(s(ind));

% Medium force
ind = find(forces==2);
mean_s_2 = mean(s(ind));
median_s_2 = median(s(ind));
std_s_2 = std(s(ind));

% Strong force
ind = find(forces==3);
mean_s_3 = mean(s(ind));
median_s_3 = median(s(ind));
std_s_3 = std(s(ind));

%% Statitical significance analysis

% Any Force / No force
ind_NoForce = find(forces==0);
ind_Force = find(forces==1 | forces==2 | forces == 3);
if length(ind_NoForce)>length(ind_Force) %Select same number of samples from both groups
    ind_NoForce = ind_NoForce(randperm(length(ind_NoForce),length(ind_Force)));
elseif length(ind_Force)>length(ind_NoForce)
    ind_Force = ind_Force(randperm(length(ind_Force),length(ind_NoForce)));
end
p_NoForce_AnyForce = anova1(cat(2,s(ind_NoForce),s(ind_Force)),[],'off');

% Small force / No force
ind_NoForce = find(forces==0);
ind_Force = find(forces==1);
if length(ind_NoForce)>length(ind_Force) %Select same number of samples from both groups
    ind_NoForce = ind_NoForce(randperm(length(ind_NoForce),length(ind_Force)));
elseif length(ind_Force)>length(ind_NoForce)
    ind_Force = ind_Force(randperm(length(ind_Force),length(ind_NoForce)));
end
p_NoForce_SmallForce = anova1(cat(2,s(ind_NoForce),s(ind_Force)),[],'off');

% Medium force / No force
ind_NoForce = find(forces==0);
ind_Force = find(forces==2);
if length(ind_NoForce)>length(ind_Force) %Select same number of samples from both groups
    ind_NoForce = ind_NoForce(randperm(length(ind_NoForce),length(ind_Force)));
elseif length(ind_Force)>length(ind_NoForce)
    ind_Force = ind_Force(randperm(length(ind_Force),length(ind_NoForce)));
end
p_NoForce_MediumForce = anova1(cat(2,s(ind_NoForce),s(ind_Force)),[],'off');

% Large force / No force
ind_NoForce = find(forces==0);
ind_Force = find(forces==3);
if length(ind_NoForce)>length(ind_Force) %Select same number of samples from both groups
    ind_NoForce = ind_NoForce(randperm(length(ind_NoForce),length(ind_Force)));
elseif length(ind_Force)>length(ind_NoForce)
    ind_Force = ind_Force(randperm(length(ind_Force),length(ind_NoForce)));
end
p_NoForce_LargeForce = anova1(cat(2,s(ind_NoForce),s(ind_Force)),[],'off');



%% Plot time histogram

figure
hold on
histogram(s,100);
set(gca,'FontSize',15)
xlim([0 4])
xlabel('Movement time (s)')
ylabel('Counts')
title('Time histogram');


