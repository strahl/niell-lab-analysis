close all
clear all
pack
done=0; nblock=0;
while ~done
    if nblock==0
        pname = uigetdir('C:\data\tdt tanks','block data')   %%% start location of tanks for search
    else
        pname = uigetdir(selected_path,'block data')
    end
    if pname==0;
        done=1;
    else
        nblock=nblock+1;
        delims = strfind(pname,'\');
        selected_path = pname(1 :delims(length(delims))-1)
        Tank_Name = pname(delims(length(delims)-1)+1 :delims(length(delims))-1)
        Block_Name{nblock} = pname(delims(length(delims))+1 :length(pname))
    end
end
nblocks = length(Block_Name);

[bname output_path] = uiputfile('','data folder');
save(fullfile(output_path,bname),'Xall','Tall','Block_Name','Tank_Name','nblocks');

for block = 1:nblocks;
    
    flags = struct('stream',1);
    chans = 1:32;
    clear t Vfilt Vfilt_ref
    
    
    sprintf('reading data')
    data = getTDTdata(Tank_Name,Block_Name{block},chans,flags);
    t=data.streamT;
    
    Vfilt = zeros(length(chans), length(t));
    
    
    for ch = chans
        
        sampRate = 1./median(diff(t));
        nyq = 0.5*sampRate;
        hp = 300;
        lp = 5000;
        [B,A] = butter(2,[hp lp]/nyq);
        
        sprintf('filtering %d',ch)
        tic
        
        Vfilt(ch,:) = filtfilt(B,A,double(data.streamV(ch,:)));
        toc
        df = 1/max(t);
        
        %     figure
        %     plot((1:length(t))*df,abs(fft(data.streamV{1})))
        
        close
        figure
        f= abs(fft(Vfilt(ch,:)));
        plot((1000:1000:length(t))*df,f(1000:1000:length(t)))
        title(sprintf('ch=%d',ch))
    end
    
    clear f data
    
    %     sprintf('calculating corr matrix')
    %     c= corrcoef(Vfilt(:,1000:1000:length(Vfilt))');
    %     figure
    %     imagesc(c,[-1 1]);
    
    %     mn_wv = mean(Vfilt,1);
    %     figure
    %     plot((1:length(t))*df, abs(fft(mn_wv)));
    
    sprintf('calculating median');
    med_wv = median(Vfilt);
    
    Vfilt_ref =zeros(size(Vfilt));
    for ch = 1:32;
        ch
        Vfilt_ref(ch,:) = Vfilt(ch,:)-med_wv;
    end
    
    %     sprintf('calculating referenced corr matrix')
    %     c_ref = corrcoef(Vfilt_ref(:,1000:1000:length(Vfilt_ref))')
    %     figure
    %     imagesc(c_ref,[-1 1]);
    %
    %     sprintf('calculating std')
    %     std_raw = std(Vfilt(:,1:length(Vfilt)/100)');
    %     std_ref = std(Vfilt_ref(:,1:length(Vfilt)/100)');
    %     figure
    %     plot(std_raw); hold on; plot(std_ref);
    
    
    clear Vfilt
    
    vmin =0;
    bins = -150:2:(vmin+1);
    
    if block==1
        chans = 1:32;
        for ch = chans
            %v = Vfilt(ch,:);
            v = Vfilt_ref(ch,:);
            h= hist(v(v<vmin),bins);
            figure
            
            plot(bins,(h))
            hold on
            plot(-5*median(abs(v(100:100:length(v))))/0.6745, 1000,'*');
            xlim([min(bins) max(bins)]);
            ylim([0 10^4]);
            title(sprintf('ch = %d',ch));
            %[thresh(ch) ~] = ginput(1);
            thresh(ch) = -5*median(abs(v(100:100:length(v))))/0.6745;
            lockoutRatio(ch)= sum(v<thresh(ch))/length(v);
            close
            %     figure
            %     plot(bins,cumsum(h)/sum(h))
        end
        
    end
    
    clear v
    
    lockoutPeriod = 32;
    %     pre_int=10;
    %     post_int = 21;
    pre_int=9;
    post_int=22;
    snipLength= pre_int+post_int+1;
    if block==1
        for tet=1:8
            Xall{tet}=[];
            Tall{tet}=[];
        end
    end
    for tet = 1:8
        tet
        crossing = [];
        for tet_ch = 1:4;
            ch = (tet-1)*4+tet_ch;
            threshcrossed = Vfilt_ref(ch,:)<thresh(ch);
            crossing = union(crossing,find(diff(threshcrossed)>0));
        end
        pre_win = diff(crossing);
        lockedout= find(pre_win<lockoutPeriod)+1;
        finalCrossings = setdiff(crossing, crossing(lockedout));
        finalCrossings = finalCrossings(finalCrossings>pre_int);
        finalCrossings =finalCrossings((finalCrossings < length(Vfilt_ref)-post_int));
        X=zeros(4,length(finalCrossings),snipLength);
        for snip=1:length(finalCrossings);
            X(1:4,snip,1:snipLength) = Vfilt_ref((tet-1)*4+(1:4),(finalCrossings(snip)-pre_int) : (finalCrossings(snip)+post_int) );
            
            % X(1:4,snip,1:snipLength) = Vfilt((tet-1)*4+(1:4), (finalCrossings(snip)-pre_int) : (finalCrossings(snip)+post_int));
        end
        X= shiftdim(X,1);  %%% much faster to make matrix as above, then shift
        figure
        for i = 1:16;
            subplot(4,4,i);
            plot(squeeze(X(i,:,:)));
        end
        figure
        for i = 1:4
            subplot(2,2,i)
            plot(bins,hist(min(squeeze(X(:,:,i)),[],2),bins));
        end
        Xall{tet} = [Xall{tet}; X];
        Tall{tet} = [Tall{tet} t(finalCrossings)+(block-1)*10^5];
        
        clear threshcrossed pre_win crossing
    end
    
end

[fname pname] = uiputfile('','data folder');
save(fullfile(pname,fname),'Xall','Tall','Block_Name','Tank_Name','nblocks');