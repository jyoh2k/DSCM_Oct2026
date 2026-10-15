%RUN_ALL_DFTS_SUBCH_SWEEP  Per-subchannel rate/BER smoke (ideal loopback)
%
%   Sets params.dfts.active_subch = 0..4 and runs a short RxMain wrap.
%   >> run('RunSimSet/run_all_dfts_subch_sweep.m')

this_dir = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
cd(proj_root);
run('AddPath.m');
run('Units.m');
[sims0, params0] = Init(); %#ok<ASGLU>
fprintf('\n=== DFT-s subchannel sweep (ideal wrap) ===\n');
fprintf('%-6s %6s %8s %12s %12s\n', 'mode', 'Nsd', 'Npilot', 'R_Gb/s', 'BER');
fprintf('%s\n', repmat('-', 1, 50));

results = struct('active', {}, 'Nsd', {}, 'Npilot', {}, 'R', {}, 'BER', {});

for iu = 0:4
    [sims, params] = Init();
    params.NDataSymbol = 40;
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
    params.TXMatchedfilter.en = 0;   % ideal wrap (same as verify_sc_05)
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

    R = params.Nsd * params.Nbpsc * params.NTXStream ...
        * params.BaudFreq / params.NSamplepersymbol;

    dataf = DataGen(sims.dataf, params.totalbits, 0);
    [txout, txsignal] = TxMain(dataf, sims, params);
    pre = min(1001, size(txout, 2));
    post = min(2000, size(txout, 2));
    rx_in = [txout(:, end-pre+1:end), txout, txout(:, 1:post)];
    [~, frame] = RxMain_OFDM(rx_in(1:params.NRXStream, :), txsignal, sims, params);
    [BER, ~, Ntot] = calculate_BER(dataf(:).', frame.fecin(:).'); %#ok<ASGLU>

    if iu == 0
        label = 'all';
    else
        label = sprintf('sc%d', iu);
    end
    fprintf('%-6s %6d %8d %12.2f %12.3e\n', label, params.Nsd, ...
        numel(params.PilotIndex), R/1e9, BER);

    results(end+1).active = iu; %#ok<AGROW>
    results(end).Nsd = params.Nsd;
    results(end).Npilot = numel(params.PilotIndex);
    results(end).R = R;
    results(end).BER = BER;
end

out_mat = fullfile(SW_PATH, 'Results', 'dfts_subch_sweep_ideal.mat');
if ~exist(fileparts(out_mat), 'dir')
    mkdir(fileparts(out_mat));
end
save(out_mat, 'results');
fprintf('\nSaved %s\n', out_mat);
if any([results.BER] ~= 0)
    error('run_all_dfts_subch_sweep: nonzero BER');
end
fprintf('RESULT: PASS (all modes BER=0)\n\n');
