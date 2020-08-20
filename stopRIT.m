%s'assurer de tout fermer avant de rouvrir une connection
 try
delete (rit);
clear rit;
catch
end

close all;
clear all; %#ok<CLSCR> 
clc;