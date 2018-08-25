function [ electrodeF, frecBandF, sampleF ] = determinePowerFeatures(I,time)
    
    

    for i=1:size(I)
        
        electrodeF = floor((I(i) / (3*length(time))) + 1);
        I(i) = I(i) - (electrodeF - 1) * length(time) * 3;
        if I(i) <= length(time)
            frecBandF = 1;
            sampleF = I(i);
        elseif I(i) <= 2* length(time)
            frecBandF = 2;
            sampleF = I(i) - length(time);
        else
            frecBandF = 3;
            sampleF = I(i) - 2*length(time);
        end
        
    end

end