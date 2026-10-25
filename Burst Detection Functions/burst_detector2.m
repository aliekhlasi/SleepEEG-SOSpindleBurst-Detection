%% 30 SEC SLIDING WINDOWS

function [starts,ends,nb_starts,nb_ends]=burst_detector2(filtered_Signal,Fs,ignore_cycle,std_tr,band,max_cycles_befor_after,min_cycles_tostart,min_cycles,power_damp_ratio_befor_after)
%% un comment this section to run not as a function
% filtered_Signal=filtered_data;
% Fs=EEG.srate;
% ignore_cycle = floor(mean(freq_band)/3);
% std_tr=2;
% band=freq_band;
% max_cycles_befor_after=15
% min_cycles_tostart=0
% min_cycles=ceil(mean(freq_band)/3)
% power_damp_ratio_befor_after=.5

%%
% defult values for sigma
% ignore_cycle=1;
% std_tr=2;
% band=[12 16];
% max_cycles_befor_after=10;
% min_cycles_tostart=2;
% min_cycles=5;
% power_damp_ratio_befor_after=.5;


% defult values for SO
% ignore_cycle=0;
% std_tr=2;
% band=[.7 1.4];
% max_cycles_befor_after=10;
% min_cycles_tostart=0;
% min_cycles=1;
% power_damp_ratio_befor_after=.5;

%default values for theta
% ignore_cycle=2;
% std_tr=2;
% band=[4 8];
% max_cycles_befor_after=15;
% min_cycles_tostart=0;
% min_cycles=2;
% power_damp_ratio_befor_after=.5;



filtered_Signal = hilbert(filtered_Signal); %filtered sig output is filter
Pha=angle(filtered_Signal);                 %phase 0 is equal to hilbert output is max amplitdue
Amp=abs(filtered_Signal);
ignore_cycle=ignore_cycle+1;                

%window time is specific time window used to find threshold, which is 20x
%the average of the wavelength
%min and max cycle, min cycle is how many cycle we need
%min_cycle_start_ min cycle before
%max cycle before and after, tells us many cycles it can grow

%%not using this window_time now
%%window_time=min_cycles*20/mean(band); %chunks sliding across the signal
%%window_time=floor(window_time*Fs);

%instead use epoch (30 s) window time
window_time=30; %chunks sliding across the signal
window_time=floor(window_time*Fs);

M=smooth(Amp,window_time);            %smooth: average over time window across the amp of the signal

%these parts are to do a faster estijmation; smooth is exact average, S is
%stdev
S=(Amp-M').^2;
S=sqrt(smooth(S,window_time)); %average and standard devation over the time windows
TR=(M+std_tr.*S)';  %mean and STD threshold, default threshold of 2
Amp_tred=Amp>TR;    %amplitdue which is greater than threshold, output is a logical value for where amp is greater than treshold
                     %each number minus previous one 

                     %each number minus previous one to get start and ends,
                     %if it's =1 we have an edge, 1 is the start, end end
                     %point is -1, start 
starts=find(Amp_tred(2:end)-Amp_tred(1:end-1)==1)+1;
ends=find(Amp_tred(1:end-1)-Amp_tred(2:end)==1);

    if ~isempty(starts) && ~isempty(ends)
    
        %it could be that there might not be a start (so catches where starts would
        %be bigger than ends (could only happen at very beginning)
        if (starts(1)>ends(1))
            starts=starts(2:end);
        end
        
        %it could also be that it has start but no end, so this catches
        starts=starts(1:min(length(starts),length(ends)));
        ends=ends(1:min(length(starts),length(ends)));
        
        % cheking for min cycle to start
        %in each burst part, we need at least a number of whole cycles
        %for each start, we take the phase from start to end point threshold time,
        %and look for the 0 cross (downline)
        inds=zeros(1,length(starts));
        for i =1:length(starts)
            temp_pha=Pha(starts(i):ends(i));
            M=temp_pha(1:end-1).*temp_pha(2:end); 
            N_pi_to_npi=sum(M<0&(M<-8)); %# cycles if M is less than -8 (threshold for pi * pi), any number of these that we have is # cycoles
            N_ZX=sum(M<0&(M>-.1));       %# 0 cross
            N_cycle=min(N_pi_to_npi,N_ZX);
            if N_cycle>=min_cycles_tostart %checks to make sure that there are enough cycles to start, 2
                inds(i)=1;
            end
        end
        
        %starts and ends when that index is one
        starts=starts(logical(inds));
        ends=ends(logical(inds));
        
        %wanted a flexible and adaptive comparison for rest of code
        %for each window, he found what threshold was at first and used that as the
        %threshold based on avg and standard dev of the window
        new_TR=zeros(1,length(starts));
        for i=1:length(starts)
            new_TR(i)=mean(TR(starts(i):ends(i)));
        end
        
        %expanding
        %for each start point
        for i =1:length(starts)
            check_start=0;
            check_end=0;
        
            tmp_ZX1=0;
        
            tmp_ZX2=0;
        
            for C=1:max_cycles_befor_after   %how many cycles we need to look for, before and after the threshold amplitude; 
                %
        
                if check_start<ignore_cycle && starts(i)>floor(Fs/band(1))
                    new_start=starts(i)-floor(Fs/band(1)); %band 1 is the lower frequency, floor of this would be the wavelenght, do 1 cycle before this
                    M=Pha(new_start:starts(i)-1).*Pha(new_start+1:starts(i)); %find closest 0 phase before start point to get start point of the cycle; so at most you would go 1 cycle and the biggest cycle (wavelenght of lower frequency)
                    ZX=find(M<=0&(M>-.1));          %ZX is last zero cross
        
                        %if there is a xero cross and amplitude of the new start +
                        %the xero cross is greater than power damp ratio before and
                        %after (threshold .5); we can grow if the amp is bigger
                        %than half of the threshold that we set
                    if ~isempty(ZX) && Amp(new_start+ZX(end))>power_damp_ratio_befor_after*new_TR(i)
                        starts(i)=new_start+ZX(end)-1;
                        check_start=0;
                        tmp_ZX1=0;
                    elseif ~isempty(ZX) %if xero cross is not empty, so a zero cross exists but doesn't meet above criteria, this is counting how many cycles I'mignoring
                        check_start=check_start+1;
                        temp=starts(i);
                        starts(i)=new_start+ZX(end)-1;
                        tmp_ZX1=tmp_ZX1+temp-starts(i);
                    else
                        check_start=ignore_cycle; %if check start is less than the number that we can ignore
                    end
                end
        %loop through number of cycles for this aboev
        
        %same thing, but looking at ends, last time we had last xero cross, but
        %this time we look at first zero cross
                if check_end<ignore_cycle && ends(i)+floor(Fs/band(1))<length(Amp)
                    new_end=ends(i)+floor(Fs/band(1));
                    M=Pha(ends(i):new_end-1).*Pha(ends(i)+1:new_end);
                    ZX=find(M<=0&(M>-.1));
        
                    if ~isempty(ZX) && Amp(ends(i)+ZX(end))>power_damp_ratio_befor_after*new_TR(i)
                        ends(i)=ends(i)+ZX(end)+1;
                        check_end=0;
                        tmp_ZX2=0;
                    elseif ~isempty(ZX)
                        check_end=check_end+1;
                        ends(i)=ends(i)+ZX(end)+1;
                        tmp_ZX2=tmp_ZX2+ZX(end)+1;
                    else
                        check_end=ignore_cycle;
                    end
                end
        
        
            end
            
            %
            if check_start~=0
                starts(i)=starts(i)+tmp_ZX1;
            end
            if check_end~=0
                ends(i)=ends(i)-tmp_ZX2;
            end
        end
        
        
        %if they overlap, combine these. checks if start is before end, and then
        %make new end end of the next one and remove the second one
        check=true;
        while (check)
            for i=1:length(starts)-1
                if (starts(i+1)<ends(i))
                    ends(i)=ends(i+1);
                    starts(i+1)=[];
                    ends(i+1)=[];
        
                    break
                end
        
            end
        
            if i==length(starts)-1
                check=false;
            end
        
        end

        %another parameter for how many cycles minimum we need for bursts, which is
        %min cycle, based on number of times the phase crosses zero,
        % cheking for min cycle to end
        inds=zeros(1,length(starts));
        for i =1:length(starts)
            temp_pha=Pha(starts(i):ends(i));
            M=temp_pha(1:end-1).*temp_pha(2:end);
            N_pi_to_npi=sum(M<0&(M<-8));
            N_ZX=sum(M<0&(M>-.1));
            N_cycle=min(N_pi_to_npi,N_ZX);
            if N_cycle>=min_cycles
                inds(i)=1;
            end
        end
        starts=starts(logical(inds));
        ends=ends(logical(inds));
        
        %define nb starts & ends
        
        if starts(1)==1 %if start signal contains burst activity
            nb_ends = starts(2:end);    %remove first index because defined burst is at beginning

            if ends(end)==length(S) %if end of signal contains burst activity
                nb_starts=ends(1:end-1);  %remove last index because defined burst is at end
            
            else                    %else end of signal does not contain burst activity, so capture end of signal after last burst identified                          
                nb_starts = ends(1:end);
                nb_ends = [nb_ends length(S)];
            end
        else %if start is NOT burst defined
            nb_starts=1;       %nb starts at beginning of signal 
            nb_starts=[nb_starts ends];
            
            nb_ends = starts;   %nb ends

            if ends(end)==length(S)      %again if end of signal contains burst activity
                nb_starts=nb_starts(1:end-1);
            else                         %else if end of signal is NB activity
                nb_ends = [nb_ends length(S)];
            end
        end
    end
end




