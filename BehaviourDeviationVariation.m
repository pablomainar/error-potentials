%% This script analyzes the deviation variation with the forces magnitude

startB = [];
endB = [];
devs = [];
forces = [];
vert = [];
%Get the deviations from all files
for i=1:length(files)
    f = files{i};
    load(f);    
    devs = cat(1,devs,[behaviour.traj.MaxDeviation]');
    forces = cat(1,forces,behaviour.forces(:,1));
end



%Find the indices for each group
ind0 = find(forces==0);
ind20 = find(forces==1);
ind40 = find(forces==2);
ind60 = find(forces==3);

%Concatenate the deviations by their group
allDevs = cat(1,devs(ind0),devs(ind20),devs(ind40),devs(ind60));
g = cat(1,repmat({'None'},size(devs(ind0))),repmat({'Small'},size(devs(ind20))),repmat({'Medium'},size(devs(ind40))),repmat({'Large'},size(devs(ind60))));


%Plot the figure
figure
hold on
hold on
bAct=boxplot(allDevs,g,'Symbol','');
set(bAct,{'linew'},{1.5})
%title('Deviation variation')
title('Active')
ylim([0 800])
ylabel('Deviation (px)')
xlabel('Force magnitude')
set(gca,'fontsize',12)


