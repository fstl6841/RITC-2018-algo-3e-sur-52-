function algo2018Main(rit, user)
%ALGO2017MAIN fonction main de l'algo

   switch user.state
        case 1
            user.mainPowerOff(rit);
            return;
        case 2
            user.mainInit();
            return;
        case 3
            user.mainTender(rit);
            return;
        case 4
            user.mainArbitrage(rit);
            return;
    end

end

