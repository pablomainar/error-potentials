%% This script analyzes the questions from the passive session of S7

%% Parameters (can be changed)

behaviour_file = 'C:\Users\Pablo\Documents\Universidad\MasterProject\Matlab\AllCode\Preprocessing\PreprocessedData\Passive\S7\behaviour_S7_p.mat';

%% Analysis
load(behaviour_file);


ForceIs = double(behaviour.forces(:,1) >0);
ForcePerc = behaviour.questions;


corr = corrcoef(cat(2,ForceIs,ForcePerc));

falsePositive = numel(find(ForceIs==0 & ForcePerc==1));
falseNegative = numel(find(ForceIs==1 & ForcePerc==0));
truePositive = numel(find(ForceIs==1 & ForcePerc==1));
trueNegative = numel(find(ForceIs==0 & ForcePerc==0));


confMatrix = [truePositive,falsePositive;falseNegative,trueNegative];

