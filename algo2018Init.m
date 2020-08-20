%s'assurer de tout fermer avant de rouvrir une connection
try
delete (rit);
clear rit;
catch
end

close all;
clear all; %#ok<CLSCR>
clc;

%ouvrir une connection
rit = rotmanTrader;

%subscribe les data qu'on aura besoin
subscribe(rit, {'LATESTNEWS|1'});

subscribe(rit, {'CAD|LAST'});
subscribe(rit, {'USD|LAST'});
subscribe(rit, {'USD|BID'});
subscribe(rit, {'USD|ASK'});

subscribe(rit, {'BULL|LAST'});
subscribe(rit, {'BULL|BID'});
subscribe(rit, {'BULL|ASK'});

subscribe(rit, {'BEAR|LAST'});
subscribe(rit, {'BEAR|BID'});
subscribe(rit, {'BEAR|ASK'});

subscribe(rit, {'RITC|LAST'});
subscribe(rit, {'RITC|BID'});
subscribe(rit, {'RITC|ASK'});
subscribe(rit, {'RITC|ASZ|1'});
subscribe(rit, {'RITC|BSZ|1'});


subscribe(rit, {'BULL|BIDBOOK'});
subscribe(rit, {'BULL|ASKBOOK'});
subscribe(rit, {'BEAR|BIDBOOK'});
subscribe(rit, {'BEAR|ASKBOOK'});
subscribe(rit, {'RITC|BIDBOOK'});
subscribe(rit, {'RITC|ASKBOOK'});

subscribe(rit, {'RITC|POSITION'});
subscribe(rit, {'BEAR|POSITION'});
subscribe(rit, {'BULL|POSITION'});
subscribe(rit, {'USD|POSITION'});

subscribe(rit, {'TENDERINFO|1'});
subscribe(rit, {'TIMEREMAINING'});

%ajouter la fonction main aux updates
user = userTrader2018(1);

runAlgo = @(rit) algo2018Main(rit, user);
addUpdateFcn(rit, runAlgo); 
rit.updateFreq = 1;
