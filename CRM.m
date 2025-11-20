function [rundata,runrev]=CRM(subjID,talker,maskers,fdback,baseatten,nrun);
%CRM targets in sentence with masker sentences - SNR test
%e.g.   CRM_babble('test',0,[1 3],0,0); %for 3 runs, subject 'test',
%           %target=talker 0, maskers = talkers 1 and 3, feedback=0 (no), 
%           %and baseatten=0 (max loudness), and number runs (default 2)
%Inputs:    Subject ID
%           Talker ID (0-7), 0-3 are male, 4-7 are female
%           Masker 1 and Masker 2 IDs (0-7), must be different from Talker
%           Optional base attenuation, dB.  Default is 0 attenuation.  For
%               NH subjects, can increase attenuation to 10.
%           Optional feedback parameter, 0=no feedback, 1=feedback.   If
%               not input as parameter, default is no feedback.
%           Optional number of runs
%Outputs:   rundata=cell/structure with detailed trial by trial results by run
%           runrev=cell of reversal levels by run

if nargin<6
    nrun=2;
end
if nargin<5
    baseatten=15;
end
if nargin<4
    feedback=0; %default no feedback
else
    if strcmp(fdback,'y')
        feedback=1;
    else
        feedback=0;
    end
end

soundbasedir='C:\SoundFiles\CRMCorpus';
targetdir=[soundbasedir '\original\Talker' num2str(talker) '\'];
maskerdir1=[soundbasedir '\original\Talker' num2str(maskers(1)) '\'];
maskerdir2=[soundbasedir '\original\Talker' num2str(maskers(2)) '\'];
pathSave=['C:\Experiments\Data\' subjID '\'];
if exist(pathSave)~=7   %if file directory doesn't exist, create new dir
    success=mkdir(['C:\Experiments\Data\'],subjID);
    if success==0
        disp('Create directory failed!  Aborting...'); 
        return; 
    end
end
feval('cd',pathSave);
flist=dir; 
flist=flist(3:end); 
subjID=GetFolder(subjID);
outFile=fileExistCheck(flist,...
     [subjID '_crm_0.txt']);
fid=fopen(outFile,'wt');
disp(sprintf('saved to %s \n',[pathSave outFile]));
fprintf(fid,'Subject %s, Talker %i, Maskers %i and %i, Base atten=%i, feedback=%i:\n',subjID,talker,maskers(1),maskers(2),baseatten,feedback);
fprintf(fid,'Run#\tCol\tAns\tNum\tAns\tSNR(dB)\tTimeElapsed(s)\n');

%Connect to PA5
PA5=actxcontrol('PA5.x',[5 5 26 26]);
invoke(PA5,'ConnectPA5','USB',1);
PA5_2=actxcontrol('PA5.x',[10 5 36 26]);
invoke(PA5_2,'ConnectPA5','USB',2);

%Set attens
PA5.SetAtten(baseatten);
errorl=PA5.GetError();
if length(errorl)~=0
    PA5.Display(errorl, 0);
end

% Set the random number generator to a unique state
rand('state',sum(100*clock))
randn('state',sum(100*clock))
f=ark1CRM;
%set(f,'Position',[0 -60 205 60]);   %LR - position gui over touchscreen display
buttonhandles=guidata(f);

%Wait for button press - added by LR
set(f,'UserData',[]);
mydata=get(f,'UserData');
set(buttonhandles.pb_start,'Enable','on');
set(buttonhandles.tx_instructions,'String','Press Start when ready')
pause(.5)
while isempty(mydata)
    pause(.1)
    mydata=get(f,'UserData');
end
set(buttonhandles.pb_start,'Enable','off');

for i=1:nrun
    %startlevel=75;
    %trials=10;
    %tlevel=startlevel-85;
    tlevel=-15;
    mlevel=tlevel-20;
    
    
    %for t=1:10
    t=0;
    nrev=0;
    prevdir=1;
    step=2;
    while nrev<14
        if nrev>4
            step=2;
        end
        t=t+1;
        pause(1)
        for n=1:32
            commandtext=['set(buttonhandles.pushbutton' num2str(n) ',''Enable'',''off'')'];
            eval(commandtext)
        end
        
        num=randperm(8)-1; col=randperm(4)-1;
        target=['000' num2str(col(1)) '0' num2str(num(1)) '.wav'];
        masker1=['020' num2str(col(2)) '0' num2str(num(2)) '.wav'];
        masker2=['030' num2str(col(3)) '0' num2str(num(3)) '.wav'];
        
        [ta,fs]=audioread([targetdir target]);
        [m1,fs]=audioread([maskerdir1 masker1]);
        [m2,fs]=audioread([maskerdir2 masker2]);
        
        ta=ta.*10.^(tlevel/20);
        m1=m1.*10.^(mlevel/20);
        m2=m2.*10.^(mlevel/20);
        
        tlen=length(ta); m1len=length(m1); m2len=length(m2);
        maxlen=max([tlen,m1len,m2len]);
        tbuff=maxlen-tlen; m1buff=maxlen-m1len; m2buff=maxlen-m2len;
        tzeros=zeros(tbuff,1); m1zeros=zeros(m1buff,1); m2zeros=zeros(m2buff,1);
        
        targ=[ta; tzeros]; mask1=[m1; m1zeros]; mask2=[m2; m2zeros];
        
        
        x=targ+mask1+mask2;
        
        if max(abs(x))>1    %safeguard code provided by LR
            disp('Warning!  Stimuli values larger than maximum allowed sound output');
            disp(sprintf('For masker level %i',mlevel));
            return
        end
        
        set(buttonhandles.tx_instructions,'String','Listen')
        set(f,'UserData',[]);
        pause(.5)
        sound(x,fs)
        pause(length(x)/fs)

        tstart=tic;     %Added to save time elapsed during data collection - LR
        
        %[col(1) num(1)]
        
        for n=1:32
            commandtext=['set(buttonhandles.pushbutton' num2str(n) ',''Enable'',''on'')'];
            eval(commandtext)
        end
        
        mydata=get(f,'UserData');
        
        while isempty(mydata)
            pause(.1)
            mydata=get(f,'UserData');
        end
        telapsed=toc(tstart);   %Added to save time elapsed during data collection - LR

        mydata.tlevel=tlevel;
        mydata.mlevel=mlevel;
        if mydata.color==col(1)
            mydata.colcorr=1;
        else
            mydata.colcorr=0;
        end
        
        if mydata.number==num(1)
            mydata.numcorr=1;
        else
            mydata.numcorr=0;
        end
        
        if mydata.numcorr+mydata.colcorr == 2
            mydata.correct=1;
            if feedback==1
                set(buttonhandles.tx_instructions,'String','Correct')
            end
            if prevdir==-1 & t>1
                nrev=nrev+1;
                mlevelrev(nrev)=mlevel;
            end
            prevdir=1;
            mlevel=mlevel+step;
        else
            mydata.correct=0;
            if feedback==1
                set(buttonhandles.tx_instructions,'String','Incorrect.')
            end
            if prevdir==1 & t>1
                nrev=nrev+1;
                mlevelrev(nrev)=mlevel;
            end
            prevdir=-1;
            mlevel=mlevel-step;
        end
        trialdata(t)=mydata;
        fprintf(fid,'%i %3d %3d %3d %d %d %.4f\n',i,col(1),mydata.color,num(1),mydata.number,tlevel-mlevel,telapsed);  %Added 10/3/2011 to save time elapsed data
    end

    disp(['%Correct    mean run(dB)   SNR 50%Threshold(dB)'])
    summaryvals=[mean([trialdata.correct; trialdata.mlevel]') mean(mlevelrev(5:14))];
    disp(num2str([summaryvals(1)*100 (summaryvals(2)-(mydata.tlevel))*-1 (summaryvals(3)-(mydata.tlevel))*-1]))
    set(buttonhandles.tx_instructions,'String','Thank you.')
    rundata{i}=trialdata;
    runrev{i}=mlevelrev;
    
end

for i=1:nrun    
  fprintf(fid,'SRT for Run Number %i is  %.2f dB  and SD is  %.2f dB',i,tlevel-mean(runrev{i}(5:14)),std(runrev{i}(5:14),0,2));
  fprintf(fid,'\n')
end

return