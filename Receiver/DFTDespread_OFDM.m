function out = DFTDespread_OFDM(eq_grid, params)
%DFTDESPREAD_OFDM  Subchannel IDFT-s after frequency-domain equalization
%
%   eq_grid : NTXStream x (NFFT * NDataSymbol)  equalized freq samples
%   out     : NTXStream x (Nsd * NDataSymbol)   time-domain QAM (active-subch packed)
%
%   For each enabled subchannel: x = ifft(X, Nd) * sqrt(Nd)

    Nd = params.dfts.Nd;
    Nsubch = params.dfts.Nsubch;
    Nsd = params.Nsd;
    NFFT = params.NFFT;
    Nsym = params.NDataSymbol;
    subch_idx = params.dfts.map.SubchDataIndex;

    if ~isfield(params.dfts, 'subch_enable') || isempty(params.dfts.subch_enable)
        enabled = 1:Nsubch;
    else
        enabled = find(params.dfts.subch_enable);
    end
    Nact = numel(enabled);
    if Nsd ~= Nact * Nd
        error('DFTDespread_OFDM:NsdMismatch', ...
            'Nsd (%d) must equal N_active*Nd (%d*%d).', Nsd, Nact, Nd);
    end

    ntx = size(eq_grid, 1);
    data_symbol = zeros(ntx, Nsd, Nsym);

    for itx = 1:ntx
        for isym = 1:Nsym
            onesym = eq_grid(itx, (isym-1)*NFFT + (1:NFFT));
            for k = 1:Nact
                iu = enabled(k);
                X = onesym(subch_idx{iu});
                x = ifft(X, Nd) * sqrt(Nd);
                data_symbol(itx, (k-1)*Nd + (1:Nd), isym) = x;
            end
        end
    end

    out = reshape(data_symbol, ntx, Nsd * Nsym);
end
