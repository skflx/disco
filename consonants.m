function percCorrect=consonants(subjID,howmany,feedback,atten)
% e.g. type "consonants('test'); for default 64 trials without feedback at 22 atten (65 dB SPL or 63 dBa)
%  or "consonants('test',64,'y'); for feedback
%  or "consonants('test',64,'n', 17.0); with no feedback, at 17 dB atten (70 dB SPL or 68 dBa).
%Default attenuation is 22 dB atten =
%      65dB SPL = 63 dBA to work with new speaker position and calibration 
%      at 10V-7.5V after 4/20/2011.  
%Code updated from shortpre program 7/8/2016 (LR and RD) to reorder and reduce input parameters 
%  for testing in quiet and without simulations, automatically save ear condition
%1/27/16 - New desired level at "red tab" in soundbooth is 67 dBA.  The
%existing default attenuation of 22 results in 67 dBA at the new distance -
%CH
% 11/23/2021 LR modified to make more vision accessible.  Black background,
% larger white text, different version of ark1.mat

if nargin<4, atten=22.0; end%% This is 65 dB SPL or 63 dBa when calibration at full out to 10 V -2.5 dB
if  nargin<3, feedback='n'; end
if feedback=='y', fdback=1; else fdback=0; end
if nargin<2, howmany=64; end
if nargin<1, subjID=input('Please enter the subject ID: ','s'); end
numBands=0;
targetID='SCN';
masker='unmod';
SNR=60;

ear_cond=input('How do you want to label this condition? (e.g. ear for HI or bCI (L,R,B) or device for bimodal CIHA (CI,HA,BM) ','s');
if isempty(ear_cond)
    ear_cond='NS'; 
end

wh=cd;
global shp;
close all;

fs=22050;

fncha=['ah-a';'ct-a';'lf-a';'sy-a'];  

cons='#_bdfgkmn%pstvz$';

pathOrg='C:/SoundFiles/Multi/Full/';
pathMulti='C:/SoundFiles/Multi/';
pathSave=['C:/Experiments/Data/' subjID '/'];
pathStim=['C:/SoundFiles/Multi/' num2str(numBands) 'bandSCN'];
pathCh=[num2str(numBands) 'band' targetID];
controlCh='%s  %5.2f%%  %s, %2d:%2d:%2d.  %d\n';

if exist(pathSave)~=7   %if file directory doesn't exist, create new dir
    success=mkdir(['C:/Experiments/Data/'],subjID);
    if success==0
        disp('Create directory failed!  Aborting...'); 
        return; 
    end
end
feval('cd',pathSave);

%Connect to PA5
PA5=actxcontrol('PA5.x',[5 5 26 26]);
invoke(PA5,'ConnectPA5','USB',1);
PA5_2=actxcontrol('PA5.x',[10 5 36 26]);
invoke(PA5_2,'ConnectPA5','USB',2);

%Set attens
PA5.SetAtten(atten);
errorl=PA5.GetError();
if length(errorl)~=0
    PA5.Display(errorl, 0);
end
PA5_2.SetAtten(90.0);
errorl=PA5_2.GetError();
if length(errorl)~=0
    PA5_2.Display(errorl, 0);
end

rand('state',sum(100*clock)); %for random seed resetting
pickaNum=mod(randperm(ceil(64)),64)+1;
scoreCum=0;
telapsedCum=0;

flist=dir; 
flist=flist(3:end); 
subjID=GetFolder(subjID);
outFile=fileExistCheck(flist,[subjID '_cons_' ear_cond '_' feedback '_0.out']);    %added 7/8/16 LR and RD
%     [subjID '_' num2str(numBands) 'ch' targetID num2str(masker) '_' num2str(SNR) '_att' num2str(atten) feedback '_0.out']);    %added 7/19/2011 LR
fid=fopen(outFile,'wt');
resFile=[subjID '_consch.all'];
fid2=fopen(resFile,'a');
fprintf('saved to %s \n',[pathSave outFile])
load banDivision

if ~numBands, numBands=12; special=1; else special=0; end % -> numBands changes here to 12
	eval(['filtCoeff=ch' num2str(numBands) '_710;'])
	
	
if numBands<10,
    noiseCompo=noiseGen(3e4,numBands,fs,filtCoeff);	
    noiseEnv=general('envelope',noiseCompo)+1e-5;
else	
    % I changed those above two lines into "retrieving from files" on 7/21/99
     pickNoise=ceil(rand*4);
     eval(['load noise4Ex1' num2str(pickNoise) '.mat']) %-> need to uncomment. now is at shortExec
end

if isSame(masker,'unmod')
	intendedNoiseEnv=noiseEnv;
else
	intendedNoiseEnv=abs(general('envShape',noiseCompo,masker,fs,(rand-.5)*4*pi,'y'));
end

if special, numBands=0; end
disp('Starting by subject''s pressing a button...')
cr=status_bar;  % initializing the current run status bar
%loading and executing the "new" GUI derived from matlab:
load C:/Development/Matlab/ark1.mat
h=ark1;

shp=0;
waitButton; %light_response2((1:24),0); 

 
%bcontrol(h,16,button,0,red,40);  %turn all on
bcontrol(h,16,button,0,red,48);  %turn all on, vision accessible version
pause(1);
%bcontrol(h,16,button,0,blue,30); % turn all off
bcontrol(h,16,button,0,[0 0 0],48); % turn all off, vision accessible version
pause(1);

	
if ( strcmp(targetID,'SCN') & ~numBands )
    soundPath=[pathMulti 'Full/'];
else
	soundPath=[pathMulti num2str(numBands) 'band' targetID '/'];
end
load([soundPath 'miscInfo'])



%trial begins...
for nn=1:howmany
	set(cr,'String',num2str(nn));
	%matCom(7) %hide cursor
	whichConsID=mod(pickaNum(nn),16)+1; 
	whoSpeakID=mod(fix(pickaNum(nn)/16),4)+1;
	whichCons=cons(whichConsID);     
	whoSpeak=fncha(whoSpeakID,:);
	soundName=[soundPath whoSpeak whichCons 'a.wav'];
	len=length(audioread(soundName));
	noiseID=fix((3e4-len-100))+1;
	noiseC=noiseCompo(noiseID:noiseID+len-1,:);
	noiseE=noiseEnv(noiseID:noiseID+len-1,:);
	iENoise=intendedNoiseEnv(noiseID:noiseID+len-1,:);
	masker=noiseC./noiseE.*iENoise;
	target=audioread(soundName);
		
	energyNoise=general('energy',masker);
		
	matchedNoise=SNRmatchedNoise(energyTarget{whoSpeakID,whichConsID},...
	masker,energyNoise,SNR,numBands);
		
	y=target+matchedNoise;
	sound(y*1.982,fs)
		
	consID = mod(pickaNum(nn),16)+1;
		
	%matCom(7); %hide cursor		
 	shp=0; 
	tstart=tic;     %Added 10/3/2011 to save time elapsed during data collection - LR
    waitButton;
    telapsed=toc(tstart);   %Added 10/3/2011 to save time elapsed during data collection - LR
	answer=shp;
		
	if fdback==1,
		%matCom(7);
		%bcontrol(h,1,button,consID,red,40);  %turn  correct button on
		bcontrol(h,1,button,consID,red,48);  %turn  correct button on, vision accessible version
		pause(1);
		%bcontrol(h,1,button,consID,blue,30); % turn correct button off
		bcontrol(h,1,button,consID,[0 0 0],48); % turn correct button off, vision accessible version
		pause(1);
	else
		pause(2);
	end
	
	%answer=resp(0,,feedback); % if the response box then put 0
	%[mod(pickaNum(nn),16)+1 answer] %debug to make sure correct output
	
    score= (answer == mod(pickaNum(nn),16)+1 );
	scoreCum=scoreCum+score;
    telapsedCum=telapsedCum+telapsed;
   	fprintf(fid,'%3d %3d %3d %3d %.4f\n',whoSpeakID,...     %Updated 10/3/2011 to save time data
        whichConsID,answer , score, telapsed);
    	
end

percentScore=scoreCum/howmany*100;
responseTime=telapsedCum/howmany;
fprintf(1,'Score is %5.2f%%.\n',percentScore);
fprintf(1,'Average response time is %5.2f sec\n',responseTime);
cl=clock;



fprintf(fid2,controlCh, outFile,...
percentScore,date,cl(4),cl(5),round(cl(6)),howmany);
	
fclose('all');
fprintf('saved to %s \n',[pathSave resFile])   
	
feval('cd',wh); 

% end of experiment
for i=1:3
       %bcontrol(h,16,button,0,red,30);  %turn all on	
       bcontrol(h,16,button,0,red,48);  %turn all on, vision accessible version	
       pause(0.8);
       %bcontrol(h,16,button,0,blue,20); % turn all off
       bcontrol(h,16,button,0,[0 0 0],48); % turn all off, vision accessible version
       pause(0.8);
end

%matCom(8); %show cursor 
	
close all;

closereq;
closereq;
	
clear;