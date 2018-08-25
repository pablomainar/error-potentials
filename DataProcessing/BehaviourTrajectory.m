%% This scrip does the trajectory analysis for active condition recordings


%% Parameters (no need to change)

load(files{1}); %Only consider the first file because different subjects might have different paths

nZeros = 50; %Trick to reduce noise when resampling

% Parameters from the screen UI
xRes = behaviour.meta(1);
yRes = behaviour.meta(2);
dist = behaviour.meta(3);
topLeft = [xRes/2 - dist,-(yRes/2 - dist)];
topRight = [xRes/2 + dist,-(yRes/2 - dist)];
bottomLeft = [xRes/2 - dist,-(yRes/2 + dist)];
bottomRight = [xRes/2 + dist,-(yRes/2 + dist)];


%This is a small detail for compatibility between ative and passive: active
%forces are in three columns while passive are only in two
if strcmp(condition,'active')
    forceColumn = 3;
elseif strcmp(condition,'passive')
    forceColumn = 2;
end

%% Mean trajectory calculation and plotting

figure
hold on
r = 56.6; %Just for visualization neetness
pos = [bottomLeft(1)-r,bottomLeft(2)-r,2*r,2*r];
rectangle('Position',pos,'Curvature',[1 1],'FaceColor',[131,4,1]/255); % Target button drawn at the beginning so that after the trajectories are overposed
xlim([1400 1800])
ylim([-1150 -650])

forces = [0,1,2,3];


% Loop for every force magnitude
for f = forces
    ind = find(behaviour.forces(:,1)==f);

    tr_mean = [];
    % Loop over all the trials for this force magnitude
    % The idea is to translate, mirror and/or rotate each trial so that it
    % looks like the trajectory from button 1 to button 4.
    for iter=1:size(ind)
        i = ind(iter);

        % Go over all the possible trajectories
        % First the vertical movements
        % These movements only have to be translated or mirrored.
        if isVertical(behaviour.startButtons(i),behaviour.endButtons(i))
            switch behaviour.startButtons(i)
                case 1 
                    if behaviour.forces(i,1)==0 
                        a = behaviour.traj(i).Position;
                    elseif behaviour.forces(i,2)==1
                        a = behaviour.traj(i).Position;
                    else
                        a = behaviour.traj(i).Position;
                        a(:,1) = a(:,1) + 2*abs(a(:,1)-topLeft(1));
                    end  

                case 2
                    if behaviour.forces(i,1) == 0
                        a = behaviour.traj(i).Position;
                        a(:,1) = a(:,1) - 2*dist;
                    elseif behaviour.forces(i,2)==1
                        a = behaviour.traj(i).Position;
                        a(:,1) = a(:,1) - 2*dist;
                    else
                        a = behaviour.traj(i).Position;
                        a(:,1) = a(:,1) + 2*abs(a(:,1)-topRight(1));
                        a(:,1) = a(:,1) - 2*dist;
                    end

                case 3
                    if behaviour.forces(i,1) == 0
                        a = behaviour.traj(i).Position;
                        a(:,2) = a(:,2) - 2*(a(:,2)-(abs(topRight(2)+bottomRight(2))/2));
                        a(:,1) = a(:,1) - 2*dist;
                    elseif behaviour.forces(i,2) == 1
                        a = behaviour.traj(i).Position;
                        a(:,2) = a(:,2) - 2*(a(:,2)-(abs(topRight(2)+bottomRight(2))/2));
                        a(:,1) = a(:,1) - 2*dist;
                    else
                        a = behaviour.traj(i).Position;
                        a(:,2) = a(:,2) - 2*(a(:,2)-(abs(topRight(2)+bottomRight(2))/2));
                        a(:,1) = a(:,1) + 2*abs(a(:,1)-topRight(1));
                        a(:,1) = a(:,1) - 2*dist;
                    end
                case 4
                    if behaviour.forces(i,1) == 0
                        a = behaviour.traj(i).Position;
                        a(:,2) = a(:,2) - 2*(a(:,2)-(abs(topRight(2)+bottomRight(2))/2));
                    elseif behaviour.forces(i,2) == 1
                        a = behaviour.traj(i).Position;
                        a(:,2) = a(:,2) - 2*(a(:,2)-(abs(topRight(2)+bottomRight(2))/2));
                    else
                        a = behaviour.traj(i).Position;
                        a(:,2) = a(:,2) - 2*(a(:,2)-(abs(topRight(2)+bottomRight(2))/2));
                        a(:,1) = a(:,1) + 2*abs(a(:,1)-topLeft(1));
                    end

            end

        % Now the horizontal movements
        % These movements must be translated, mirrored and rotated
        else
            switch behaviour.startButtons(i)
                case 1
                    if behaviour.forces(i,1)==0
                        a = behaviour.traj(i).Position;
                    elseif behaviour.forces(i,forceColumn)==1
                        a = behaviour.traj(i).Position;
                    else
                        a = behaviour.traj(i).Position;
                        a(:,2) = a(:,2) + 2*abs(a(:,2)-abs(topLeft(2)));
                    end  

                case 2
                    if behaviour.forces(i,1) == 0
                        a = behaviour.traj(i).Position;
                        a(:,1) = a(:,1) - 2*(a(:,1)-abs(abs(topLeft(1))+abs(topRight(1)))/2);
                    elseif behaviour.forces(i,forceColumn) == 1
                        a = behaviour.traj(i).Position;
                        a(:,1) = a(:,1) - 2*(a(:,1)-abs(abs(topLeft(1))+abs(topRight(1)))/2);
                    else
                        a = behaviour.traj(i).Position;
                        a(:,1) = a(:,1) - 2*(a(:,1)-abs(abs(topLeft(1))+abs(topRight(1)))/2);
                        a(:,2) = a(:,2) + 2*abs(a(:,2)-abs(topLeft(2)));
                    end

                case 3
                    if behaviour.forces(i,1) == 0
                        a = behaviour.traj(i).Position;
                        a(:,1) = a(:,1) - 2*(a(:,1)-abs(abs(topLeft(1))+abs(topRight(1)))/2);
                        a(:,2) = a(:,2) - 2*dist;
                    elseif behaviour.forces(i,forceColumn) == 1
                        a = behaviour.traj(i).Position;
                        a(:,1) = a(:,1) - 2*(a(:,1)-abs(abs(topLeft(1))+abs(topRight(1)))/2);
                        a(:,2) = a(:,2) - 2*dist;
                    else
                        a = behaviour.traj(i).Position;
                        a(:,1) = a(:,1) - 2*(a(:,1)-abs(abs(topLeft(1))+abs(topRight(1)))/2);
                        a(:,2) = a(:,2) - 2*dist;
                        a(:,2) = a(:,2) + 2*abs(a(:,2)-abs(topLeft(2)));

                    end
                case 4
                   if behaviour.forces(i,1) == 0
                        a = behaviour.traj(i).Position;
                        a(:,2) = a(:,2) - 2*dist;
                    elseif behaviour.forces(i,forceColumn)==1
                        a = behaviour.traj(i).Position;
                        a(:,2) = a(:,2) - 2*dist;
                    else
                        a = behaviour.traj(i).Position;
                        a(:,2) = a(:,2) + 2*abs(abs(bottomLeft(2))-a(:,2));
                        a(:,2) = a(:,2) - 2*dist;
                    end

            end

            temp = a;
            a(:,2) = (temp(:,1) - topLeft(1)) / (topRight(1) - topLeft(1));
            a(:,2) = (a(:,2) * (abs(bottomLeft(2)) - abs(topLeft(2)))) + abs(topLeft(2));
            a(:,1) = (temp(:,2) - abs(topLeft(2))) / (abs(bottomLeft(2)) - abs(topLeft(2)));
            a(:,1) = (a(:,1) * (topRight(1) - topLeft(1))) + topLeft(1);





        end

        % Resample the trial so thatall of them have the same number of
        % samples (1000)
        t = a;
        t = cat(1,t(1,:).*ones(nZeros,1),t,t(end,:).*ones(nZeros,1));
        tr = resample(t,1000+2*nZeros-1,size(t,1));
        tr = tr(nZeros:end-nZeros,:); %This is just a trick to avoid the problems with resampling the first samples in matlab
        tr_mean = cat(3,tr_mean,tr);


    end

    tr_mean = mean(tr_mean,3);
    if f == 0
        startPoint = tr_mean(1,:);
    end


    % Plot the mean trajectory for this force
    plot([topLeft(1);startPoint(1);tr_mean(:,1)],[topLeft(2);-startPoint(2);-tr_mean(:,2)],'LineWidth',3)



end


% Final details of the plot
lgd = legend('None','Small','Medium','Large');
lgd.FontSize = 12;
pos = [topLeft(1)-r,topLeft(2)-r,2*r,2*r];
rectangle('Position',pos,'Curvature',[1 1],'FaceColor',[77,149,28]/255);
scatter([xRes/2 - dist,xRes/2 - dist],[-(yRes/2 - dist),-(yRes/2 + dist)],100,[0.5,0.5,0.5],'filled')

axis equal
ax = gca;
ax.Visible = 'off';