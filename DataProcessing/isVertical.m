function [ vert ] = isVertical( s, e )

    if (s==1 & e==4) | (s==4 & e==1) | (s==2 & e==3) | (s==3 & e==2)
        vert = true;
    else
        vert = false;
    end
        


end

