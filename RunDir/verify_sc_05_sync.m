%VERIFY_SC_05_SYNC  Step-5: single-subch RxMain sync (full STF, ideal wrap)
%
%   >> run('RunDir/verify_sc_05_sync.m')

clearvars -except SW_PATH DSP_PATH
close all

this_dir = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
cd(proj_root);
run('AddPath.m');

fprintf('\n=== verify_sc_05_sync (STF sync + active subch) ===\n');
nfail = 0;

for iu = [0, 1, 3]   % all + two representative singles
    [sims, params] = Init();
    params.NDataSymbol = 20;
    params.Nbpsc = 4;
    params.en_bit_alloc = 0;
    params.en_power_loading = 0;
    params.NTXStream = 2;
    params.NRXStream = 2;
    params.NFFT = 128;
    params.dfts.Lbb = 2;
    params.dfts.active_subch = iu;
    params.BaudFreq = 64e9;
    params.TXSampleFreq = params.BaudFreq;
    params.RXSampleFreq = params.BaudFreq;
    params.AWGSampleFreq = params.TXSampleFreq;
    params.OSCFreq = params.RXSampleFreq;
    params.RX_IF_band = 0;
    params.TXMatchedfilter.en = 0;
    params.TXMatchedfilter.alpha = 1.0;
    params.TXAGC.en = 0;
    params.AGC.en = 1;
    params.DCCancel.en = 0;
    params.rxskew.en = 0;
    params.cpr.en = 1;
    params.cpr.bcpr_en = 0;
    params.ce.en_ISFA = 0;
    params.tpr.en = 0;
    params.cfr.en = 0;
    params.fcfr.en = 0;
    params.searchframe.en = 1;
    params.searchframe.th = 0;
    params.searchfineframe.en = 1;
    params.searchfineframe.type = 1;
    sims.dataf.data_file = [DSP_PATH 'Ptn/prbs15.txt'];
    [sims, params] = ReInit(sims, params);

    if iu == 0
        label = 'all';
    else
        label = sprintf('sc%d', iu);
    end

    dataf = DataGen(sims.dataf, params.totalbits, 0);
    [txout, txsignal] = TxMain(dataf, sims, params);
    pre = min(1001, size(txout, 2));
    post = min(2000, size(txout, 2));
    rx_in = [txout(:, end-pre+1:end), txout, txout(:, 1:post)];

    [~, frame] = RxMain_OFDM(rx_in(1:params.NRXStream, :), txsignal, sims, params);
    if ~isfield(frame, 'fecin') || isempty(frame.fecin)
        fprintf('FAIL: %s fecin missing\n', label); nfail = nfail + 1;
        continue;
    end

    [BER, Nerr, Ntot] = calculate_BER(dataf(:).', frame.fecin(:).');
    if BER ~= 0
        fprintf('FAIL: %s BER=%g (%d/%d)\n', label, BER, Nerr, Ntot);
        nfail = nfail + 1;
    else
        fprintf('PASS: %s BER=0 (%d bits) with full STF sync\n', label, Ntot);
    end
end

fprintf('\n----------------------------------------\n');
if nfail == 0
    fprintf('RESULT: PASS (verify_sc_05_sync)\n');
else
    fprintf('RESULT: FAIL (%d check(s) failed)\n', nfail);
    error('verify_sc_05_sync failed');
end
fprintf('----------------------------------------\n\n');
