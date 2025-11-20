function percCorrect=vowels9(subjID,howmany,feedback,atten)
% e.g. type: "vowels9('test');      for default 180 trials (1 run) with default no feedback 
%  or type: vowels9('test',10,'n');    for 10 trials (incomplete), no feedback
%  or type: vowels9('test',180,'y',20.0);    for feedback, at 20 dB atten
%Code last updated 7/19/2011 (LR).  Changes include:
%   1) Fix default attenuation to 24 dB atten = 65dB SPL = 63 dBA to work 
%   with new speaker position and calibration at 10V-7.5V after 4/20/2011.  
%   Before change, default was 28 dB atten = 59 dBA with new speaker position 
%   after 4/20/2011.   Before 4/20/2011, 20 dB atten = 61 dBA for calibration 
%   at V=10V-7.5V.
%   2) Automatically save vowel file name as vow9*.txt for 9-vowel stimuli,
%   attenuation level, and feedback parameters.
%Update code 12/5/2013 to prompt for ear or device condition.
% Updated 12/11/2013 to add instructions at top of screen
%Updated 12/13/2013 to rearrange order of parameters to put subject ID
%   first and howmany second, and set default howmany to 180.
%1/26/17 - Changed default attenuation from 24 dB to 21.4 dB to produce 65
%dBA at "red tab" on soundbooth ceiling. - CH
%12/08/17 - Changed default attenuation from 21.4 to 22.9 dB for desired
%dBA (65) at "red tab" in soundbooth - CH
%6/10/2021 - Changed default attenuation to 18.0 dB to produce 65 dBa - LR 

if nargin<2, howmany=180; end
if  nargin<3, feedback='n'; end 
if feedback=='y', fdback=1; else fdback=0; end
%if nargin<4, atten=24.0; end % LR/RI 07/19/2011 note: This value is 65dBSPL for new speaker position after 4/20/2011
%if nargin<4, atten=21.4; end %1/26/17 - Changed default attenuation from 24 to 21.4 dB for desired dBA (65) at "red tab" in soundbooth - CH
%if nargin<4, atten=22.9; end %12/08/17 - Changed default attenuation from 21.4 to 22.9 dB for desired dBA (65) at "red tab" in soundbooth - CH
if nargin<4, atten=18.0; end %12/08/17 - Changed default attenuation from 22.9 dB to 18 for desired dBA (65)  = 67 dB SPL at "red tab" in soundbooth - LR

ear_cond=input('How do you want to label this condition? (e.g. ear for HI or bCI (L,R,B) or device for bimodal CIHA (CI,HA,BM) ','s');
if isempty(ear_cond)
    ear_cond='NS'; 
end

wh=cd; 
global shp;
close all;

%Instructions KB
Instructions(8);

fs=44100;

fncha=['M01';'M03';'M06';'M08'; 'M11'; 'M24'; 'M30'; 'M33'; 'M39'; 'M41'; ...
    'W01'; 'W04'; 'W09'; 'W14'; 'W15'; 'W23'; 'W25'; 'W26'; 'W44'; 'W47'];  

%vow=['AE'; 'AH'; 'AW'; 'EH'; 'EI'; 'ER'; 'IH'; 'IY'; 'OA'; 'OO'; 'UH'; 'UW'];
vow=['AE'; 'AH'; 'AW'; 'EH'; 'IH'; 'IY'; 'OO'; 'UH'; 'UW'];

soundPath='C:/SoundFiles/Vowels/';
pathSave=['C:/Experiments/Data/' subjID '/'];
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
pickaNum=mod(randperm(ceil(180)),180)+1;
scoreCum=0;
telapsedCum=0;

flist=dir; 
flist=flist(3:end); 
subjID=GetFolder(subjID);
outFile=fileExistCheck(flist,...
     [subjID '_vow9_' ear_cond '_0.txt']); %updated 1/4/2014 LR
%     [subjID '_vow_60_0.txt']);    %used up to 7/19/2011 LR
%     [subjID '_vow9_att' num2str(atten) feedback ear_cond '_0.txt']); %added 7/19/2011 LR, updated 12/5/2013 LR
fid=fopen(outFile,'wt');
resFile=[subjID '_vowch.all'];
fid2=fopen(resFile,'a');
fprintf('saved to %s \n',[pathSave outFile])


disp('Starting by subject''s pressing a button...')
cr=status_bar;  % initializing the current run status bar
%loading and executing the "new" GUI derived from matlab:
load C:/Development/Matlab/ark1.mat
h=ark1v9;

buttonv9(10).name='Press any button to start.';
bcontrol(h,1,buttonv9,10,'w',20);    

shp=0;
waitButton; %light_response2((1:24),0); 

 
bcontrol(h,9,buttonv9,0,blue,40);  %turn all on
pause(1);
bcontrol(h,9,buttonv9,0,red,30); % turn all off
pause(1);
	
%trial begins...
for nn=1:howmany
	set(cr,'String',num2str(nn));
	%matCom(7) %hide cursor
	whichVowID=mod(pickaNum(nn),9)+1; 
	whoSpeakID=mod(fix(pickaNum(nn)/9),20)+1;
	whichVow=vow(whichVowID,:);     
	whoSpeak=fncha(whoSpeakID,:);
	soundName=[soundPath whoSpeak whichVow '.wav'];
	len=length(audioread(soundName));
	target=audioread(soundName);
	y=target*1.982;

    buttonv9(10).name='Playing...';
    bcontrol(h,1,buttonv9,10,'w',20);    
    pause(0.7);
	sound(y,fs)
	pause(0.3);
        
	vowID = mod(pickaNum(nn),9)+1;
		
	%matCom(7); %hide cursor		
    buttonv9(10).name='Which vowel did you hear?';
    bcontrol(h,1,buttonv9,10,'w',20);    
 	shp=0; 
	tstart=tic;     %Added 10/3/2011 to save time elapsed during data collection - LR
    waitButton;
    telapsed=toc(tstart);   %Added 10/3/2011 to save time elapsed during data collection - LR
    
	answer=shp;
		
	if fdback==1,
		%matCom(7);
		bcontrol(h,1,buttonv9,vowID,blue,40);  %turn  correct button on
		pause(1);
		bcontrol(h,1,buttonv9,vowID,red,30); % turn correct button off
		pause(1);
	else
		pause(0.5);
	end
	
	%answer=resp(0,,feedback); % if the response box then put 0
	%[mod(pickaNum(nn),9)+1 answer] %debug to make sure correct output
	
    score= (answer == mod(pickaNum(nn),9)+1 );
	scoreCum=scoreCum+score;
	%fprintf(1,'%3d:',nn)  % --> Canceled output by Prof. Turner's request
	%fprintf(1,'              %s %3d %3d %3d\n',whoSpeak(1:2),...
	%whichVowID, answer , score);
   	fprintf(fid,'%3d %3d %3d %3d %.4f\n',whoSpeakID,...     %Updated 10/3/2011 to save time data
        whichVowID,answer , score, telapsed);
    telapsedCum=telapsedCum+telapsed;
    
	
end

buttonv9(10).name=sprintf('Run finished.');
bcontrol(h,1,buttonv9,10,'w',20);    

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
       bcontrol(h,9,buttonv9,0,blue,30);  %turn all on	
       pause(0.8);
       bcontrol(h,9,buttonv9,0,red,20); % turn all off
       pause(0.8);
end

%matCom(8); %show cursor 
close all;

closereq;
closereq;
	
clear;