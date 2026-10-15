function [out, mapperout]=  OFDMMapper( in,  params )

%  Usage      : [out, mapperout]=  OFDMMapper( in,  params )
%
%  DFT-s-OFDM mapper (기존 OFDMMapper 골격 수정)
%    1) 비트열 → QAM 심볼
%    2) 활성 서브채널별 Nd-point DFT precoding
%    3) SubchDataIndex 위치에 주파수 그리드 배치
%       (비활성 서브채널 / Pilot/DC/Null은 0 유지)

    Nd = params.dfts.Nd;           % 서브채널 DFT 크기 (=30)
    Nsubch = params.dfts.Nsubch;   % 서브채널 수 (=4)
    if ~isfield(params.dfts, 'subch_enable') || isempty(params.dfts.subch_enable)
        enabled = 1:Nsubch;
    else
        enabled = find(params.dfts.subch_enable);
    end
    Nact = numel(enabled);
    if params.Nsd ~= Nact * Nd
        error('OFDMMapper:NsdMismatch', ...
            'Nsd (%d) must equal N_active*Nd (%d*%d).', ...
            params.Nsd, Nact, Nd);
    end

    % --- QAM ---
    if ( params.en_bit_alloc == 1)
        mapperout = zeros(  params.NTXStream, params.Nsd, params.NDataSymbol );
        in1 = reshape(in, 1, params.Nbpsym, params.NDataSymbol);
        for itx=1:params.NTXStream
            for isd=1:params.Nsd
                mapper_t.Nbitspersymbol = params.Nbpsc_sc(itx,isd);
                mapperout(itx, isd,:) = QAMMapper( in1(1, params.mapper.sc_index_min(itx,isd):params.mapper.sc_index_max(itx,isd), :),  mapper_t);
            end
        end
        data_symbol = reshape( mapperout, params.NTXStream, params.Nsd, params.NDataSymbol );
        mapperout = reshape(mapperout,  1, params.NTXStream * params.Nsd * params.NDataSymbol );
    else
        mapperout     = QAMMapper( in,  params.mapper);
        % (stream, activeDataSC, OFDM심볼) — 활성 서브채널만 연속 패킹
        data_symbol = reshape( mapperout, params.NTXStream, params.Nsd, params.NDataSymbol );
    end

    % --- DFT-s precoding + 주파수 그리드 배치 (활성 서브채널만) ---
    one_symbol = zeros( params.NTXStream,  params.NFFT, params.NDataSymbol  );
    subch_idx = params.dfts.map.SubchDataIndex;

    for itx = 1:params.NTXStream
        for isym = 1:params.NDataSymbol
            for k = 1:Nact
                iu = enabled(k);
                loc = (k-1)*Nd + (1:Nd);
                x = data_symbol(itx, loc, isym);
                X = fft(x, Nd) / sqrt(Nd);
                one_symbol(itx, subch_idx{iu}, isym) = X;
            end
        end
    end

    out=reshape(one_symbol, 1, params.NTXStream * params.NFFT * params.NDataSymbol );

end
