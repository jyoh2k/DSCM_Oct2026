function [ out, fscs ] = SearchFineFrameStart_Tr( in, in1, params)
%  Usage      :  [ out, fscs ] = SearchFineFrameStart( in, params, T )  
%
%  Function   :
%     1. Search Frame start using cross correlation
%
%  Port  :
%     1. in         : Original signal
%     2. params     : parameter
%     3. T          : Reserved for fixed sim.
%     4. out        : Recovered signal
%     5. fscs       : Synchronization results (For debugging use)
%
%  Author     : Rha, Hae Young.
%  Contact    : hyrha@miroandi.com   
%  Known bugs :


    out                   = in;
    fscs.phaseoffset      = 0;
    fscs.start_of_frame   = params.start_of_frame;
    fscs.metric   = 1;
    fscs.MaxPos   = 1;
    fscs.pol_est = 0;
    %params.en = 0;  % test
    if ( params.en  == 0 )
        out = in(:, fscs.start_of_frame:end);    
        return;
    end

    if ( params.CFEtype  == 1 )
        out = in ;
        fscs.start_of_frame = 1;
        cor_pattern  = TxUpsample( params.sync_pattern(:,1:50), params.RXoversample, 0 );
        search_range = floor(params.ptn_rep_length * params.RXoversample * 1)   ;  % 
        offset = 0 ;
        search_range1 = params.search_range1;
        search_range2 = search_range1 +size(cor_pattern,2);
    else
        cor_pattern  = TxUpsample( params.sync_pattern(:,1:params.cor_length), params.RXoversample, 0 );
%         cor_pattern = reshape([(params.sync_pattern);  zeros(size(params.sync_pattern) );], 1, []); 
        offset = params.offset  * params.RXoversample;
        sig_len = size(in, 2);
        search_range1 = max(1, offset + 1 -10);
        search_range2 = min(sig_len, search_range1 + size(cor_pattern,2) + params.search_range);
        if search_range2 <= search_range1
            fscs.start_of_frame = min(max(1, params.start_of_frame), sig_len);
            fscs.MaxPos = 1;
            fscs.metric = 0;
            out = in(:, fscs.start_of_frame:end);
            return;
        end
    end

    out1 = zeros(size(in,1), params.RXoversample * params.NFrameSample+100);
    metric_max=zeros(size(in,1)*2,1); 
    
    Msymt = 0;
    if ( params.type == 1)
        for itxstream=1:size(cor_pattern,1)
            for irxstream=1:size(in,1)
                search_idx = 1;
                k2 = 1: length(cor_pattern);
                [P2, R2, Msym, Msym1] = CrossCorr2D( in(irxstream,search_range1:1:search_range2), cor_pattern(itxstream,:), search_idx, k2  );
                [MaxVal(itxstream,irxstream ), MaxPos(itxstream,irxstream )] = max(Msym);
                start_of_frame(itxstream,irxstream )  = ( MaxPos(itxstream,irxstream) - 1 + offset ) * 1 + search_range1;
                Msymt = Msymt + Msym;
            end
        end
        
    end
    if ( params.type == 0)
        for itxstream=1:size(cor_pattern,1)
            for irxstream=1:size(in,1)
                search_idx = 1;
                k2 = 1: length(cor_pattern);
                [P2, R2, Msym, Msym1] = CrossCorr2D( in(irxstream,search_range1:1:search_range2), cor_pattern(itxstream,:), search_idx, k2  );
                [MaxVal(itxstream,irxstream ), MaxPos1] = max(Msym(1:params.RXoversample:end));
                MaxPos(itxstream,irxstream ) =( MaxPos1 - 1)* params.RXoversample+1  ; 
                start_of_frame(itxstream,irxstream )  = ( MaxPos(itxstream,irxstream) - 1 + offset ) * 1 + search_range1;
                Msymt = Msymt + Msym;
            end
        end
    end
        
    if ( params.type == 2) 
        search_idx = 1;
        k2 = 1: length(cor_pattern);
        [P2, R2, Msym, Msym1] = CrossCorr2D( in(:,search_range1:1:search_range2), cor_pattern(:,:), search_idx, k2  );
        [MaxVal , MaxPos1] = max(Msym(1:params.RXoversample:end));
        MaxPos =( MaxPos1 - 1)* params.RXoversample+1  ; 
        start_of_frame  = ( MaxPos - 1 + offset ) * 1 + search_range1;
         Msymt = Msym;
    end 
     if ( params.type == 3) 
        search_idx = 1;
        k2 = 1: length(cor_pattern);
        [P2, R2, Msym, Msym1] = CrossCorr2D( in(:,search_range1:1:search_range2), cor_pattern(:,:), search_idx, k2  );
        [MaxVal , MaxPos] = max(Msym ); 
        start_of_frame  = ( MaxPos - 1 + offset ) * 1 + search_range1;
         Msymt = Msym;
     end    
     
    [ out, fsfs] =StreamMap( in1, MaxPos, MaxVal, start_of_frame,params );
    fscs.metric   = Msymt;
    fscs.metric1   = Msym1;
    fscs.MaxPos   = fsfs.MaxPos;
    fscs.pol_est   = fsfs.pol_est;
    fscs.start_of_frame =start_of_frame;
end



function [ out, fsfs] =StreamMap( in, MaxPos, MaxVal, start_of_frame,params )
%  Usage      :  [ fsfs] =StreamMap( MaxPos, MaxVal, fsfs )
%
%  Function   :
 
     idx = params.RXoversample * params.NFrameSymbol + 1000;
    if ( size(MaxPos,1) == 1 )
        sf = clamp_start(start_of_frame, size(in, 2));
        out = extract_segment(in, sf, idx);
        fsfs.MaxPos = MaxPos;
        fsfs.MaxVal = MaxVal;
        fsfs.start_of_frame = sf;
        fsfs.pol_est = 0;
        return;
    end 
    
    if ( (MaxVal(1,1)+MaxVal(2,2) < MaxVal(1,2) + MaxVal(2,1))) 
        fsfs.MaxPos(1) = MaxPos(1,2);
        fsfs.MaxPos(2) = MaxPos(2,1);
        fsfs.start_of_frame(1) = clamp_start(start_of_frame(1,2), size(in, 2));
        fsfs.start_of_frame(2) = clamp_start(start_of_frame(2,1), size(in, 2));
        out = zeros(2, idx);
        out(1,:) = extract_segment(in(2,:), fsfs.start_of_frame(1), idx);
        out(2,:) = extract_segment(-in(1,:), fsfs.start_of_frame(2), idx);
        rot = 1;
    else
        fsfs.MaxPos(1) = MaxPos(1,1);
        fsfs.MaxPos(2) = MaxPos(2,2);        
        fsfs.start_of_frame(1) = clamp_start(start_of_frame(1,1), size(in, 2));
        fsfs.start_of_frame(2) = clamp_start(start_of_frame(2,2), size(in, 2));
        out = zeros(2, idx);
        out(1,:) = extract_segment(in(1,:), fsfs.start_of_frame(1), idx);
        out(2,:) = extract_segment(in(2,:), fsfs.start_of_frame(2), idx);
        rot = 0;
    end 
    
     fsfs.pol_est = rot ; 

end

function i0 = clamp_start(i0, sig_len)
    i0 = max(1, min(round(i0), sig_len));
end

function seg = extract_segment(sig, i0, n_want)
    seg = sig(i0:end);
    n_have = numel(seg);
    if n_have >= n_want
        seg = seg(1:n_want);
    else
        seg = [seg, zeros(1, n_want - n_have)]; %#ok<AGROW>
    end
end
