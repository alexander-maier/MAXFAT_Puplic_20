function [phic,psic,DLc,DL] = criticalplaneV6(...
                                      sigepsfile,ndata,ntens,ndi,...
                                      dphi,phimax,phimin,dpsi,psimax,psimin,...
                                      DMGs,...
                                      optdisplay,...
                                      optcritplane,...
                                      optrainflow,...
                                      optallhcm,...
                                      jobname,outpath)
%
% Funktion zum durchführen der kritischen Ebenen Schleife und
% Schädigungsrechnung
%
% -------------------------------------------------------------------------
% INPUT:
% Lokale Spannungen Dehnungen
%   ndata    -> (int) Anzahl Datenpunkte in sigepsfile (Anzahl Zeitpunkte
%               der Lstfolge)
% ntens,ndi  -> (int) Anzahl der Tensorkomponenten zum Unterscheiden von
%               Spannungszuständen
%               ntens - Anzahl Tensorkomponenten insagesamt
%               ndi   - Anzahl Tensorkomponenten auf der Hauptdiagonalen
% sigepsfile -> (str) Verweis auf Datei mit lokalem Lastpfad aus der
%               Kerbnäherung, enthält die folgenden Daten:
%   SIG      -> Lastfolge der Spannungen e R^(3,numink)
%   EPS      -> Lastfolge der Dehnungen e R^(3,numink)
%   EPSP     -> Lastfolge der plastischen Dehnungen e R^(3,numink)
%   DLZ      -> Ordnet Spannungen und Dehnungen den einzelnen Durchläufen
%               durch die Lastfolge zu
%
% Winkel Kritische Ebene
%   dphi     -> Inkrement des Winkels phi e R (Angabe in Grad)
%   dpsi     -> Inkrement des Winkels psi e R (Angabe in Grad)
% phimax,..  -> Maximal und Minimalwerte der Winkel für kritische Ebene
%              (Angabe in Grad)
%              (Default phi e [0, 180]; psi e [-90,90])
%
% Schädigungsmodell
% DMGs       -> cell array mit Objekten einer Schädigungsparameterklasse,
%                Der schädigungsparameter muss die Folgenden Funktionen
%                enthalten:
%                P = DMG.rainflow([sig;eps;DLZ]) -> Rainflow zum Identifizeiren und
%                                                   Berechnen der Schädigungsereignisse
%                DL = DMG.lebensdauer(P)         -> Schadensakkumulation 
%                (DMG.Name                       -> Name des Parameters
%                                          (nur für Display & Datei Output)
%
% Outputoptionen
% optdisplay     -> bool 1 = Display Ausgabe
%                        0 = keine Display Ausgabe
% optcritplane   -> bool 1 = Speichern der Ergebnisse Aller Ebenen in Datei
%                        0 = kein Speichern in Datei
% optrainflow    -> bool 1 = Speichern Rainflow Ergebniss der kritischen
%                            Ebene in Datei
%                        0 = kein Speichern in Datei
% opthcmall      -> bool 1 = Speichern Rainflow Ergbnisse ALLER Ebenen
%                        0 = nur speichern kritische Ebene
% jobname        -> str, name der Rechnung
% outpath        -> str, pfad für Output Dateien
%
% -------------------------------------------------------------------------
% OUTPUT:
% PHI     -> alle Winkel
% PSI     -> alle WInkel
% DL      -> Durchläufe 
% phic    -> phi der kritischen Ebene
% psic    -> psi der kritischen Ebene
% DLc     -> minimale Durchläufe
% _________________________________________________________________________
%
% ANMERKUNGEN
%
% Die Input Spannungen und Dehnungen befinden sich im Ebenen
% Spannungszustand. Es wird von lokalen Koordinatensystem {X,Y,Z} in der 
% Kerbe ausgegangen. Die Z-Achse steht dabei normal zur Bauteiloberfläche.
%
% Darstellung von Tensoren im globalen Koordinatensystem der Kerbe
%         sigXX              epsXX
%  sig =  sigYY       eps =  epsYY
%         sigXY             2epsXY
%
%
% Darstellung von Tensoren in gedrehten lokalen Koordinatensystemen (im
% Allgemeinen stellt sich 3D Spannungszustand ein). Spannungen und
% Dehnungen in den gedrehten Koordinatensystemen der kritischen Ebene
% {x,y,z}. Es wird dabei davon ausgegangen, dass die lokale x-Achse immer
% normal auf der betrachteten Schnittebene/dem Riss steht. die Spannung
% sigxx bezeichnet also die Normalspannung in der Schnittebene.
% -> y-Achse Bezeichnet Risslänge auf der Bauteiloberfläche
% -> z-Achse Bezeichnet Risslänge in Bauteiltiefe
% Bei dieser Wahl des lokalen Koordinatensystems lassen sich Normal- &
% Schubspannungen/-dehnungen direkt aus dem transformierten tensor ablesen
% es ist genau genommen keine weitere ebnen transformation mehr nötig.
%
%         sigxx              epsxx
%         sigyy              epsyy
%  sig =  sigzz       eps =  epszz
%         sigxy             2epsxy
%         sigyz             2epsyz
%         sigxz             2epsxz
%
% Definition der Winkel
% phi = Winkel zwischen Y,y => Rotation um Z e [0,pi]
% psi = Winkel zwischen Z,z => Rotation um y e [-pi/2,pi/2]
%
% _________________________________________________________________________

% ----------------------------------------------------------------------- %
% |                 Lade lokalen Lastpfad                               | %
% ----------------------------------------------------------------------- %
% reservierter Speicher für Daten
%          sigxx             
%          sigyy             
%          sigzz     
%          sigxy       Data(1:6,:)  -> Spannungen im Koordinatensystem der kritischen Ebee    
%          sigyz          
%          sigxz           
%  Data =  epsxx
%          epsyy
%          epszz
%         2epsxy      Data(7:12,:)  -> Dehnugnen im Koordinatensystem der kritischen Ebee  
%         2epsyz
%         2epsxz
%            DLZ      Data(13,:)    -> Durchlaufzähler
Data = zeros(13,ndata); 

% öffne Datei
fid = fopen(sigepsfile,'r'); 

% Unterscheide Spannungszustände & Und Lese Werte ein
if ntens == 6 && ndi == 3 % 3D
    Data([13 1 2 3 4 5 6 7 8 9 10 11 12],:) = fread(fid,[13,Inf],'double');
elseif ntens == 3 && ndi == 2 % ESZ
    Data([13 1 2 4 7 8 9 10],:) = fread(fid,[8,Inf],'double');
elseif ntens == 2 && ndi == 1 % Sigma - Tau
    Data([13 1 4 7 8 9 10],:) = fread(fid,[7,Inf],'double');
elseif ntens == 1 && ndi == 1 % reiner Zug
    Data([13 1 7 8 9],:) = fread(fid,[5,Inf],'double');
else % Spannungszustand nicht erkannt
    msg = 'Spannungszustand nicht erkannt';
    error(msg)
end

% schließe Datei
fclose(fid);


% aktueller Winkel (Kerbkoordinatensystem)
phi1 = 0;
psi1 = 0;

% ----------------------------------------------------------------------- %
% |                 Umrechnene Winkelinkremente in rad                  | %
% ----------------------------------------------------------------------- %
dpsi = pi/180 * dpsi;
psimax = pi/180 * psimax;
psimin = pi/180 * psimin; 
dphi = pi/180 * dphi;
phimax = pi/180 * phimax;
phimin = pi/180 * phimin; 

% ----------------------------------------------------------------------- %
% |                 Speicher für Lebensdauerrechnung                    | %
% ----------------------------------------------------------------------- %
numdmg = length(DMGs);                                                     % Anzahl Schädigungsparameter
numpsi = ceil((psimax-psimin)/dpsi)+1;
numphi = ceil((phimax-phimin)/dphi)+1;
numwinkel = numpsi * numphi;
DL = zeros(numwinkel,2+numdmg);                                            % Speicher für output Variable

% ----------------------------------------------------------------------- %
% |                 Schleife über alle Ebenen                           | %
% ----------------------------------------------------------------------- %
% ... Init Variablen
zahler_planes = 1;   % Zähler variable der ebenen
DLc = 1e21 * ones(1,numdmg);        % minimale Durchläufe initial sau hoch setzten
Pcrit = struct();                  % Schädigungsparameter in kritischer Ebene
phic = zeros(1,numdmg);            % Winkel kritische Ebene
psic = zeros(1,numdmg);            % Winkel kritische Ebene

% ... Display Ausgabe
if optdisplay
    fprintf(' plane phi   psi   ');
    for i = 1 : numdmg
        sizename = length(DMGs{i}.Name);
        fprintf([' ',DMGs{i}.Name]);
        for j = 1:13-sizename
            fprintf(' ')
        end
    end
    fprintf('\n');
end
        
% ... Schleife
for phi = phimin : dphi : phimax % Drehung um Z

    for psi = psimin : dpsi : psimax % Drehung um y
        
        % ... Display Ausgabe
        if optdisplay
            fprintf('%6i%6.3f%6.3f',zahler_planes,phi,psi);
        end
        
        % --------------------------------------------------------------- %
        % |                 Koordinatentransformation                   | %
        % --------------------------------------------------------------- %
        % ... Abspeichern Winkel
        DL(zahler_planes,1,:) = phi * 180/pi;
        DL(zahler_planes,2,:) = psi * 180/pi;
        
        % ... Transformation der Spannungen aus altem Koordinatensystem 
        % ins neue lokale Koordinatensystem 
        DS = transformCP2CP(phi1,phi,psi1,psi,0);
        Data(1:6,:) = DS * Data(1:6,:);
                
        % ... Transformation der Dehnungen aus altem Koordinatensystem 
        % ins neue lokale Koordinatensystem 
        DE = transformCP2CP(phi1,phi,psi1,psi,1);
        Data(7:12,:) = DE * Data(7:12,:);

        % --------------------------------------------------------------- %
        % |                 Rainflowzählung                             | %
        % --------------------------------------------------------------- %
        P = rainflowV3(Data,DMGs,psi);
        
        % --------------------------------------------------------------- %
        % |                 Schädigungsrechnung                         | %
        % --------------------------------------------------------------- %
        for i = 1:numdmg
            % ... aktueller Schädigungsparameter
            DMG = DMGs{i};
            
            if optallhcm && optrainflow
                write_RAINFLOW(jobname,DMG.Name,outpath,P{i},phi,psi);
            end
            
            % ... Lebendsdauer berechnen
            DL(zahler_planes,2+i) = DMG.lebensdauer(P{i});
            
            % ... merke kritische ebene
            if DL(zahler_planes,2+i) < DLc(i)
                DLc(i) = DL(zahler_planes,2+i);
                Pcrit.(DMG.Name) = P{i};
                phic(i) = phi;
                psic(i) = psi;
            end
            
            
            % ... Display Ausgabe
            if optdisplay
                fprintf('%14.6d',DL(zahler_planes,2+i));
            end
        end
        
        % ... Display Ausgabe
        if optdisplay
            fprintf('\n');
        end
        
        % ... Inkrementieren des ebenen zählers
        zahler_planes = zahler_planes + 1;

        % ... merke aktuelles Koordinatensystem
        phi1 = phi;
        psi1 = psi;
        
    end % Ende Schleife psi
    
end % Ende Schleife phi

% ... Dateiausgabe kritische Ebene
if optcritplane
    write_CRITPLANE(jobname,outpath,DMGs,DL);
end

% ... Dateiausgabe Rainflow kritische Ebene
if optrainflow && ~optallhcm
    for i = 1:numdmg
        write_RAINFLOW(jobname,DMGs{i}.Name,outpath,Pcrit.(DMGs{i}.Name),phic(i),psic(i))
    end
end

end % Ende Funktion