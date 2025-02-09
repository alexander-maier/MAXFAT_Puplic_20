function [ak,bk] = defaultak(num_alpha)
% Setzt default ak und bk parameter des D�ring modells 
% Aus Dis.D�ring Tabelle 5.3 Seite 114
% Bis zu 10 Backstresstensoren angegeben, f�r den rest zu Null gesetzt
%
% INPUT:
%      Anzahl Backstresstensoren
%
% OUTPUT:
%      ak e R^(1xnum_alpha) 
%      bk = 1.2
%__________________________________________________________________________
bk = 1.2;

ak_dummy = [0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25;...
               0,  0.3,    0, 0.06, 0.12, 0.11, 0.11, 0.10, 0.10, 0.09;...
               0,    0,  0.3,    0,    0, 0.06, 0.06, 0.09, 0.09, 0.09;...
               0,    0,    0,  0.3,    0,    0,    0, 0.06, 0.06, 0.09;...
               0,    0,    0,    0,  0.3, 0.02,    0,    0,    0, 0.08;...
               0,    0,    0,    0,    0,  0.3, 0.02,    0,    0,    0;...
               0,    0,    0,    0,    0,    0,  0.3, 0.04,    0,    0;...
               0,    0,    0,    0,    0,    0,    0,  0.3, 0.04,    0;...
               0,    0,    0,    0,    0,    0,    0,    0,  0.3, 0.05;...
               0,    0,    0,    0,    0,    0,    0,    0,    0,  0.3]';
if num_alpha <= 10
    ak = ak_dummy(num_alpha,1:num_alpha);
else
    ak = zeros(1,num_alpha);
end