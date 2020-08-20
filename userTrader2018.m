classdef userTrader2018 < handle
    %userTrader Classe qui va regrouper les paramètres et les méthodes qui
    %vont servir à changer les états paramétriques.
    %   
    
    properties
        state
        tempBook
        aggBook
        bullAskbook
        bullBidbook
        bearAskbook
        bearBidbook
        ritcAskbook
        ritcBidbook
        tenderOffer
        tenderAccepted
        tenderIndex
        myBlotter
        myOrders
        isRITC
        isBULL
        isBEAR
        ritc_limit
        bear_limit
        bull_limit
        arb_positions
        grossLimit
        netLimit
        dummy
        commission1
        commission2
        percentage
        obj
        lowestCost
        bearBidW
        bearAskW
        bullBidW
        bullAskW
        ritcBidW
        ritcAskW
    end
    
    methods
        
%{
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                    FONCTIONS D'INITIALISATIONS                          %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%}
        function this = userTrader2018(state)
            %Constructeur de la classe userTrader2018
            this.state = state;
            this.tenderOffer = {'' '' '' '' '' '0'};
            this.isBEAR = 0;
            this.isBULL = 0;
            this.isRITC = 0;
            this.ritc_limit = 0;
            this.bull_limit = 0;
            this.bear_limit = 0;
            this.arb_positions = 0;
            this.grossLimit = 0;
            this.netLimit = 0;
            this.tenderAccepted = 0;
            this.commission1 = 0.04;
            this.commission2 = 0.08;
            this.percentage = 0.20;
            this.obj = 0;
        end
        
 %{
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                            MAIN                                         %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%}    
        function this = mainPowerOff(this, rit)
        %STATE 1
        %
            if ((rit.timeRemaining > 1) && (rit.timeRemaining < 300))
                disp('changing state to main Init');
                this.state = 2;
            end
            disp('main power off');
            this.tenderAccepted = 0;
        end
            
        %STATE 2
        function this = mainInit(this, rit)
            this.state = 3;
            this.tenderOffer = {'' '' '' '' '' '0'};
            disp('main init')
            rit.updateFreq = 1;
        end
        
        %STATE 3 MISPRICE
        function this = mainTender(this, rit)

            this.obj = 0;
            time = 300 - rit.timeremaining;
            disp(time)
            
            %vérifie si la simulation est finie
            if rit.timeremaining == 300 || rit.timeremaining == 0
                disp('changing state to main power off')
                this.state = 1;
                return;
            end
            
            this.checkHedging(rit);
            this.liquidate(rit);
            
            %remet la limit à 0 avant de révérifier le tout
            this.netLimit = 0;
            
            %vérifie s'il y a une nouvelle tender disponible
            if isempty(rit.tenderinfo_1) == 0
                
                this.formatTender(rit.tenderinfo_1);
                this.checkProfit(rit);
                disp(this.tenderOffer)
                
                if this.tenderAccepted == 1
                    currentNetLimit = (2 * rit.ritc_position + rit.bear_position + rit.bull_position);
                    tenderLimit = str2double(this.tenderOffer(3)) * 2;
                    
                    %vérifie si on a la limite nécéssaire pour accepter la
                    %tender
                    if strcmp(this.tenderOffer(2), 'BUY')
                        if ((200000 - currentNetLimit) >= tenderLimit)
                            acceptActiveTender(rit, rit.getActiveTenders, 0);
                            this.netLimit = 0;
                            this.tenderAccepted = 0;
                        elseif tenderLimit > 200000
                            this.netLimit = -(tenderLimit - 200000);
                            this.obj = 1;
                            disp('working on limit')
                        else
                            disp('working on limit')
                        end
                        
                    elseif strcmp(this.tenderOffer(2), 'SELL')
                        if ((200000 + currentNetLimit) >= tenderLimit)
                            acceptActiveTender(rit, rit.getActiveTenders, 0);
                            this.netLimit = 0;
                            this.tenderAccepted = 0;
                        elseif tenderLimit > 200000
                            this.netLimit = tenderLimit - 200000;
                            this.obj = 1;
                            disp('working on limit')
                        else
                            disp('working on limit')
                        end
                    end
                        
                else
                    disp('tender not accepted')
                end
                
                
            elseif isempty(rit.tenderinfo_1) && (rit.ritc_position == -rit.bear_position) && (rit.bear_position == rit.bull_position)
                this.state = 4;
                this.tenderAccepted = 0;
                rit.updateFreq = 0.6;
                
                orders = getOrders(rit);
                if orders(1) > 0
                    for i = 1:length(orders)
                        cancelOrder(rit, orders(i));
                    end
                end
            end
%             
            disp('main tender')
        end
        
        function this = mainArbitrage(this, rit)
            %vérifie si la simulation est finie
            if rit.timeremaining == 300 || rit.timeremaining == 0
                disp('changing state to main power off')
                this.state = 1;
                return;
            end

            this.checkArb(rit);
            this.checkHedging(rit);
            %vérifie s'il y a une tender et retourne a l'état 3 si c'est le
            %cas
            if isempty(rit.tenderinfo_1) == 0
                this.formatTender(rit.tenderinfo_1);
                this.checkProfit(rit);
                disp(this.tenderOffer)
                this.state = 3;
                rit.updateFreq = 1;
            end
            
%             Vérifie s'il y a un bogue et dans les positions et met le
%             state en 3 si c'est le cas
            if abs(rit.ritc_position) > (abs(rit.bear_position) + abs(rit.bull_position)+ 20000)
                this.state = 3;
            end
            
            disp('main arbitrage')
        end
%{
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                                MODÈLE                                   %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%}    
        function this = createBook(this, rit, askOrBid, ticker)
            %createBook fonction qui créer un cell array du livre
            
            if strcmp(ticker, 'BULL')
                if strcmp(askOrBid, 'ASK')
                    strBook = rit.bull_askbook;
                else
                    strBook = rit.bull_bidbook;
                end
            elseif strcmp(ticker, 'BEAR')
                if strcmp(askOrBid, 'ASK')
                    strBook = rit.bear_askbook;
                else
                    strBook = rit.bear_bidbook;
                end
            elseif strcmp(ticker, 'RITC')
                if strcmp(askOrBid, 'ASK')
                    strBook = rit.ritc_askbook;
                else
                    strBook = rit.ritc_bidbook;
                end
            else
                disp('erreur')
            end
            
            book = strsplit(strBook, ';');
            retour = zeros(length(book), 3);

            for i = 1:length(book)
                splitbook = strsplit(strjoin(book (1,i)), ',');
                retour(i,1) = str2double(splitbook(1,2));
                retour(i,2) = str2double(splitbook(1,3));
                retour(i,3) = sum(retour(1:i, 2));
            end
            this.tempBook = retour;
            
        end
        
        function this = aggregateBook(this, rit, askOrBid)
        %Fonction qui met les book de bull et bear ensemble divisé par le
        %taux de change pour avoir un point de comparaison avec le ETF
            tic
            if strcmp(askOrBid, 'BID')
                this.createBook(rit, 'BID', 'BEAR');
                bearBook = this.tempBook;
                this.createBook(rit, 'BID', 'BULL');
                bullBook = this.tempBook;
            elseif strcmp(askOrBid, 'ASK')
                this.createBook(rit, 'ASK', 'BEAR');
                bearBook = this.tempBook;
                this.createBook(rit, 'ASK', 'BULL');
                bullBook = this.tempBook;
            end
            
            usd = rit.usd_last;
            
            indexBear = 1;
            indexBull = 1;
            indexETF = 1;
            
            bookETF = zeros(100,3);
            
            lengthBear = length(bearBook);
            lengthBull = length(bullBook);
            lengthETF = length(bookETF);
            
            while indexBear < lengthBear && indexBull < lengthBull && indexETF < lengthETF
    
                volume = min(bearBook(indexBear,2), bullBook(indexBull,2));
                bookETF(indexETF,1) = bearBook(indexBear,1) + bullBook(indexBull,1);
                bookETF(indexETF,2) = volume;

                if bearBook(indexBear,2) > bullBook(indexBull,2)
                    bearBook(indexBear, 2) = (bearBook(indexBear, 2) - bullBook(indexBull,2)) / usd;
                    indexBull = indexBull + 1;
                elseif bullBook(indexBull,2) > bearBook(indexBear,2); 
                    bullBook(indexBull, 2) = (bullBook(indexBull, 2) - bearBook(indexBear, 2)) / usd;
                    indexBear = indexBear + 1;
                else
                    indexBull = indexBull + 1;
                    indexBear = indexBear + 1;
                end
                indexETF = indexETF + 1;
            end
            
            for i = 1:length(bookETF)
                if bookETF(i,1) ~= 0
                    bookETF(i,3) = sum(bookETF(1:i, 2));
                end
            end
            
            if strcmp(askOrBid, 'ASK')
                bookETF(:,1) = bookETF(:,1) + 0.15;
            elseif strcmp(askOrBid, 'BID')
                bookETF(:,1) = bookETF(:,1) - 0.15;
            end
                
            this.aggBook = bookETF;
            toc
        end
        
        function this = checkProfit(this, rit)
            %Fonction qui vérifie si la tender est profitable. On doit
            %s'assurer qu'il y a une tender offer avant de lancer cette fonction.
            
            price = str2double(this.tenderOffer(1,4));
            volume = str2double(this.tenderOffer(1,3));
            buyOrSell = cell2mat(this.tenderOffer(1, 2));
            bidAsk = '';

            if strcmp(buyOrSell, 'BUY')
                bidAsk = 'BID';
                bookPrice = rit.ritc_bid;
            elseif strcmp(buyOrSell, 'SELL')
                bidAsk = 'ASK';
                bookPrice = rit.ritc_ask;
            end
            
            this.aggregateBook(rit, bidAsk);
            bbBook = this.aggBook;
            
            this.createBook(rit, bidAsk, 'RITC');
            etfBook = this.tempBook;
     
            if strcmp(buyOrSell, 'BUY')
                etfDummy = ((price + this.commission1) < etfBook(:,1));
                bbDummy = ((price + this.commission1) < bbBook(:,1));
            elseif strcmp(buyOrSell, 'SELL')
                etfDummy = (price > (etfBook(:,1) + this.commission1));
                bbDummy = (price > (bbBook(:,1) + this.commission1));
            end
            
            volumeETF = etfDummy' * etfBook(:,2);
            volumeBB = bbDummy' * bbBook(:,2);
            
            disp('VOLUME')
            disp((volumeETF + volumeBB) / volume)
            
            if strcmp(buyOrSell, 'BUY') && ((rit.ritc_bid - price) > this.commission2)
                if (((volumeETF + volumeBB) / volume) > this.percentage)
                    this.tenderAccepted = 1;
                else 
                    this.tenderAccepted = 0;
                end
            elseif strcmp(buyOrSell, 'SELL') && ((price - rit.ritc_ask) > this.commission2)
                if (((volumeETF + volumeBB) / volume) > this.percentage)
                    this.tenderAccepted = 1;
                else 
                    this.tenderAccepted = 0;
                end
            else
                this.tenderAccepted = 0;
            end
        end
        
        
        function this = formatTender(this, tender)
        %checkTender Fonction qui formate le tender info.
        %   On doit s'assurer que rit.tenderinfo_1 n'est pas vide avant d'utiliser
        %   cette fonction.
            
            stringTender = strsplit(tender, ',');

            formatTender = cell(1,6);

            %titre à vendre ou acheter
            formatTender(1,1) = stringTender(1,2);

            %buy/sell
            if (str2double(stringTender(1,3)) > 0)
                formatTender(1,2) = cellstr('BUY');
            else
                formatTender(1,2) = cellstr('SELL');
            end

            %nombre d'actions
            actions = abs(str2double(stringTender(1,3)));
            formatTender(1,3) = cellstr(num2str(actions));

            %prix
            prix = stringTender(1,4);
            formatTender(1,4) = cellstr(prix);

            %début et fin
            formatTender(1,5) = stringTender(1,5);
            formatTender(1,6) = stringTender(1,6);
            this.tenderOffer = formatTender;

        end
        
        function this = checkHedging(this, rit)
            ritc_pos = rit.ritc_position;
            usd_pos = rit.usd_position;
            
            expected_usd = -ritc_pos * rit.usd_last * rit.ritc_last;
            if (usd_pos - expected_usd) > 10000
                sell(rit, 'USD', (usd_pos - expected_usd));
            elseif (expected_usd - usd_pos) > 10000
                buy(rit, 'USD', (expected_usd - usd_pos));
            end
                
        end
        
        function this = checkMarket(this, rit, vol)
        %Fonction qui vérifie ce qui est le plus avantageux de liquider au
        %marché
            tic
            usd = rit.usd_last;
            
                bearBid = rit.bear_bidbook;
                bullBid = rit.bull_bidbook;
                ritcBid = rit.ritc_bidbook;
                bearAsk = rit.bear_askbook;
                bullAsk = rit.bull_askbook;
                ritcAsk = rit.ritc_askbook;

                bearBid = strsplit(bearBid, ';');
                bullBid = strsplit(bullBid, ';');
                ritcBid = strsplit(ritcBid, ';');
                bearAsk = strsplit(bearAsk, ';');
                bullAsk = strsplit(bullAsk, ';');
                ritcAsk = strsplit(ritcAsk, ';');

            cost = 0;
            volume = vol;
            for i = 1:length(bearBid)

                buffer = strsplit(cell2mat(bearBid(i)), ',');
                vol2 = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol2 >= volume
                    cost = cost + price * volume;
                    break
                else
                    cost = cost + price * vol2;
                    volume = volume - vol2;
                end
            end
            
            this.bearBidW = cost / vol;
            
            cost = 0;
            volume = vol;
            for i = 1:length(bearAsk)

                buffer = strsplit(cell2mat(bearAsk(i)), ',');
                vol2 = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol2 >= volume
                    cost = cost + price * volume;
                    break
                else
                    cost = cost + price * vol2;
                    volume = volume - vol2;
                end
            end
            this.bearAskW = cost / vol;
            
            cost = 0;
            volume = vol;
            for i = 1:length(bullBid)

                buffer = strsplit(cell2mat(bullBid(i)), ',');
                vol2 = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol2 >= volume
                    cost = cost + price * volume;
                    break
                else
                    cost = cost + price * vol2;
                    volume = volume - vol2;
                end
            end
            this.bullBidW = cost / vol;
            
            cost = 0;
            volume = vol;
            for i = 1:length(bullAsk)

                buffer = strsplit(cell2mat(bullAsk(i)), ',');
                vol2 = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol2 >= volume
                    cost = cost + price * volume;
                    break
                else
                    cost = cost + price * vol2;
                    volume = volume - vol2;
                end
            end
            this.bullAskW = cost / vol;
            
            cost = 0;
            volume = vol;
            for i = 1:length(ritcBid)

                buffer = strsplit(cell2mat(ritcBid(i)), ',');
                vol2 = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol2 >= volume
                    cost = cost + price * volume;
                    break
                else
                    cost = cost + price * vol2;
                    volume = volume - vol2;
                end
            end
            this.ritcBidW = cost * usd / vol;
            
            cost = 0;
            volume = vol;
            for i = 1:length(ritcAsk)

                buffer = strsplit(cell2mat(ritcAsk(i)), ',');
                vol2 = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol2 >= volume
                    cost = cost + price * volume;
                    break
                else
                    cost = cost + price * vol2;
                    volume = volume - vol2;
                end
            end
            this.ritcAskW = cost * usd / vol;

        end

%{
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                                TRADE                                    %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%}    

        function this = checkArb(this, rit)
            %Fonction qui vérifie s'il y a de l'arbitrage disponible
            bear = rit.bear_askbook;
            bull = rit.bull_askbook;
            ritc = rit.ritc_bidbook;
            usd = rit.usd_last;

            bear = strsplit(bear, ';');
            bull = strsplit(bull, ';');
            ritc = strsplit(ritc, ';');

            tic
            cost_bear = 0;
            volume = 10000;
            for i = 1:length(bear)

                buffer = strsplit(cell2mat(bear(i)), ',');
                vol = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol >= volume
                    cost_bear = cost_bear + price * volume;
                    break
                else
                    cost_bear = cost_bear + price * vol;
                    volume = volume - vol;
                end
            end

            cost_bull = 0;
            volume = 10000;
            for i = 1:length(bull)

                buffer = strsplit(cell2mat(bull(i)), ',');
                vol = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol >= volume
                    cost_bull = cost_bull + price * volume;
                    break
                else
                    cost_bull = cost_bull + price * vol;
                    volume = volume - vol;
                end
            end

            cost_ritc = 0;
            volume = 10000;
            for i = 1:length(ritc)

                buffer = strsplit(cell2mat(ritc(i)), ',');
                vol = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol >= volume
                    cost_ritc = cost_ritc + price * volume;
                    break
                else
                    cost_ritc = cost_ritc + price * vol;
                    volume = volume - vol;
                end
            end
            cost_ritc = cost_ritc * usd;

            arbitrage_short = cost_ritc - cost_bear - cost_bull - 1500 - 30000 * 0.02;

            bear = rit.bear_bidbook;
            bull = rit.bull_bidbook;
            ritc = rit.ritc_askbook;
            usd = rit.usd_last;

            bear = strsplit(bear, ';');
            bull = strsplit(bull, ';');
            ritc = strsplit(ritc, ';');

            cost_bear = 0;
            volume = 10000;
            for i = 1:length(bear)

                buffer = strsplit(cell2mat(bear(i)), ',');
                vol = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol >= volume
                    cost_bear = cost_bear + price * volume;
                    break
                else
                    cost_bear = cost_bear + price * vol;
                    volume = volume - vol;
                end
            end

            cost_bull = 0;
            volume = 10000;
            for i = 1:length(bull)

                buffer = strsplit(cell2mat(bull(i)), ',');
                vol = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol >= volume
                    cost_bull = cost_bull + price * volume;
                    break
                else
                    cost_bull = cost_bull + price * vol;
                    volume = volume - vol;
                end
            end

            cost_ritc = 0;
            volume = 10000;
            for i = 1:length(ritc)

                buffer = strsplit(cell2mat(ritc(i)), ',');
                vol = str2double(cell2mat(buffer(3)));
                price = str2double(cell2mat(buffer(2)));

                if vol >= volume
                    cost_ritc = cost_ritc + price * volume;
                    break
                else
                    cost_ritc = cost_ritc + price * vol;
                    volume = volume - vol;
                end
            end
            cost_ritc = cost_ritc * usd;

            arbitrage_long = cost_bull + cost_bear - cost_ritc - 1500 - 30000 * 0.02;
            
            if arbitrage_long > 500
                this.buyRITC(rit);
                disp(arbitrage_long)
            elseif arbitrage_short > 500
                this.sellRITC(rit);
                disp(arbitrage_short)
            else
                disp('no aribtrage')
            end
        end
        
        function this = buyRITC(this, rit)
            %Fonction qui fait de l'arbitrage en achetant RITC et en
            %shortant les 2 autres
            ticker = cell(3,1);
            action = cell(3,1);
            quantity = ones(3,1);
            
            ticker(1,1) = cellstr('RITC');
            action(1,1) = cellstr('BUY');
            
            ticker(2,1) = cellstr('BEAR');
            action(2,1) = cellstr('SELL');
            
            ticker(3,1) = cellstr('BULL');
            action(3,1) = cellstr('SELL');

            for i = 1:3
                quantity(i) = 10000;
            end

            blotter = table(ticker, action, quantity);
            blotterOrder(rit, blotter);
        end
        
        function this = sellRITC(this, rit)
            %Fonction qui fait de l'arbitrage en vendant RITC et en
            %achetant les 2 autres
            ticker = cell(3,1);
            action = cell(3,1);
            quantity = ones(3,1);
            
            ticker(1,1) = cellstr('RITC');
            action(1,1) = cellstr('SELL');
            
            ticker(2,1) = cellstr('BEAR');
            action(2,1) = cellstr('BUY');
            
            ticker(3,1) = cellstr('BULL');
            action(3,1) = cellstr('BUY');
            
            for i = 1:3
                quantity(i) = 10000;
            end

            blotter = table(ticker, action, quantity);
            blotterOrder(rit, blotter);
        end
        
        function this = liquidate(this, rit)
%             disp(getOrders(rit));

            orders = getOrders(rit);
            disp(orders)
            ritc_pos = rit.ritc_position;
            bear_pos = rit.bear_position;
            bull_pos = rit.bull_position;
            usd = rit.usd_last;
            
            ritc_net = (ritc_pos + ((bull_pos + bear_pos) / 2));
            
            bear_obj = 0;
            bull_obj = 0;
            ritc_obj = (this.netLimit - ritc_net);
            
            ritc_spread = abs(rit.ritc_bid - rit.ritc_ask);
            
            if ritc_pos > 0
               bb_profit = (rit.bull_ask + rit.bear_ask - 0.15) - rit.ritc_bid * usd;
            elseif ritc_pos < 0
               bb_profit = -(rit.bull_bid + rit.bear_bid + 0.15) + rit.ritc_ask * usd;
            else
               bb_profit = 0; 
            end
%             disp('bb profit')
%             disp(bb_profit);
            
            if abs(ritc_pos + bear_pos) < 15000 || bb_profit < (-ritc_spread / 2)
                if ritc_pos > 0
                    bear_obj = min(bear_pos, bull_pos) - bear_pos;
                elseif ritc_pos < 0
                    bear_obj = max(bear_pos, bull_pos) - bear_pos;
                end
            else
                bear_obj = -ritc_pos - bear_pos;
            end
            
            if abs(ritc_pos + bull_pos) < 15000 || bb_profit < (-ritc_spread / 2)
                if ritc_pos > 0
                    bull_obj = min(bear_pos, bull_pos) - bull_pos;
                elseif ritc_pos < 0
                    bull_obj = max(bear_pos, bull_pos) - bull_pos;
                end
            else
                bull_obj = -ritc_pos - bull_pos;
            end
            
%             disp('objectif')
%             disp(ritc_obj)

            if ritc_obj > 0
                ritc_price = rit.ritc_bid;
            elseif ritc_obj < 0
                ritc_price = rit.ritc_ask;
            end
            
            if bear_obj > 0
                bear_price = rit.bear_bid;
            elseif bear_obj < 0
                bear_price = rit.bear_ask;
            end
            
            if bull_obj > 0
                bull_price = rit.bull_bid;
            elseif bull_obj < 0
                bull_price = rit.bull_ask;
            end

            for i = 1:length(orders)
%                 disp(rit.getOrderInfo(orders(i)));
            end
            
            %MARKET
            if this.obj == 1
                while ritc_obj ~= 0
                    if ritc_obj > 0
                        quantity = min(10000, ritc_obj);
                        buy(rit, 'RITC', quantity)
                        ritc_obj = ritc_obj - quantity;
                    elseif ritc_obj < 0
                        quantity = -max(-10000, ritc_obj);
                        sell(rit, 'RITC', quantity)
                        ritc_obj = ritc_obj + quantity;
                    end
                end
                this.obj = 0;
                rit.cancelOrder(orders(1))
                return
            elseif this.obj == 0
                if ritc_spread < 0.06
                    if ritc_obj > 0
                        quantity = min(min(10000, rit.ritc_asz_1), ritc_obj);
                        buy(rit, 'RITC', quantity)
                        ritc_obj = ritc_obj - quantity;
                    elseif ritc_obj < 0
                        quantity = -max(max(-10000, -rit.ritc_bsz_1), ritc_obj);
                        sell(rit, 'RITC', quantity)
                        ritc_obj = ritc_obj + quantity;
                    end
                end
            end


            %LIMIT
            orders = rit.getOrderInfo(rit.getOrders);
            bearOrders = cell(0,0);
            bullOrders = cell(0,0);
            ritcOrders = cell(0,0);
            
            indexBear = 1;
            indexBull = 1;
            indexRitc = 1;
            
            %créer 3 book avec nos ordres limites existantes
            if ~isempty(orders)
                for i = 1:height(orders)
                    buffer = table2cell(orders(i,:));
                    if strcmp(buffer(2), 'RITC')
                        ritcOrders(indexRitc, :) = buffer;
                        indexRitc = indexRitc + 1;
                    elseif strcmp(buffer(2), 'BEAR')
                        bearOrders(indexBear, :) = buffer;
                        indexBear = indexBear + 1;
                    elseif strcmp(buffer(2), 'BULL')
                        bullOrders(indexBull, :) = buffer;
                        indexBull = indexBull + 1;
                    end
                end
            else
                
            end
            
            if ritc_obj > 0 && (isempty(ritcOrders) || abs(ritc_price - this.ritc_limit) > 0.01)
                if ~isempty(ritcOrders)
                    rit.cancelOrder(cell2mat(ritcOrders(1)));
                end
                ammount = min(7777, ritc_obj);
                addOrder(rit, 'RITC', ammount, ritc_price + 0.01);
                this.ritc_limit = ritc_price;
            elseif ritc_obj < 0 && (isempty(ritcOrders) || abs(ritc_price - this.ritc_limit) > 0.01)
                if ~isempty(ritcOrders)
                    rit.cancelOrder(cell2mat(ritcOrders(1)));
                end
                ammount = max(-7777,ritc_obj);
                addOrder(rit, 'RITC', ammount, ritc_price - 0.01);
                this.ritc_limit = ritc_price;
            end
            
            if bear_obj > 0 && (isempty(bearOrders) || abs(bear_price - this.bear_limit) > 0.01)
                if ~isempty(bearOrders)
                    rit.cancelOrder(cell2mat(bearOrders(1)));
                end
                ammount = min(7777, bear_obj);
                addOrder(rit, 'BEAR', ammount, bear_price + 0.01);
                this.bear_limit = bear_price;
            elseif bear_obj < 0 && (isempty(bearOrders) || abs(bear_price - this.bear_limit) > 0.01)
                if ~isempty(bearOrders)
                    rit.cancelOrder(cell2mat(bearOrders(1)));
                end
                ammount = max(-7777,bear_obj);
                addOrder(rit, 'BEAR', ammount, bear_price - 0.01);
                this.bear_limit = bear_price;
            end
            
            if bull_obj > 0 && (isempty(bullOrders) || abs(bull_price - this.bull_limit) > 0.01)
                if ~isempty(bullOrders)
                    rit.cancelOrder(cell2mat(bullOrders(1)));
                end
                ammount = min(7777, bull_obj);
                addOrder(rit, 'BULL', ammount, bull_price + 0.01);
                this.bull_limit = bull_price;
            elseif bull_obj < 0 && (isempty(bullOrders) || abs(bull_price - this.bull_limit) > 0.01)
                if ~isempty(bullOrders)
                    rit.cancelOrder(cell2mat(bullOrders(1)));
                end
                ammount = max(-7777,bull_obj);
                addOrder(rit, 'BULL', ammount, bull_price - 0.01);
                this.bull_limit = bull_price;
            end
            
        end
    end
end