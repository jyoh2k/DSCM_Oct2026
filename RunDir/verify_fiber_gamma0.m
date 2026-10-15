%VERIFY_FIBER_GAMMA0  Linear fiber (Gamma=0) vs default NLSE — run_simple path
%
%   Sets sims.channel.ssmf.Gamma before ReInit (same as run_simple + fiber sweep).
%   >> run('RunDir/verify_fiber_gamma0.m')

clearvars -except SW_PATH DSP_PATH
close all

this_dir = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
cd(proj_root);
run('AddPath.m');
run('Units.m');

fprintf('\n=== verify_fiber_gamma0 (run_simple path) ===\n');

[sims0, ~] = Init();
gamma_default = sims0.channel.ssmf.Gamma;
clear sims0;
fprintf('Default ssmf.Gamma = %.6g (W/km unit in NLSE)\n', gamma_default);

% Knobs (match run_all / run_simple)
sim_case = 22;
mode = 87;
X_coor_list = [10, 12, 14, 16];   % mode-87 SNR/ROP sweep axis
fiber_km_list = [1, 6, 11, 16, 21, 26];
PhaseNoise = 0; PMD = 0; CFO = 0;

out_dir = fullfile(proj_root, 'Results');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
results = struct('fiber_km', {}, 'X_coor', {}, 'gamma', {}, 'BER', {}, 'EVM', {}, 'label', {});

for ig = 1:2
    if ig == 1
        gamma = 0;
        gtag = 'gamma0';
        fprintf('\n--- Gamma = 0 (linear) ---\n');
    else
        gamma = gamma_default;
        gtag = 'gammaDef';
        fprintf('\n--- Gamma = default (%.6g) ---\n', gamma);
    end

    for ifl = 1:numel(fiber_km_list)
        FiberLen = fiber_km_list(ifl);

        for ix = 1:numel(X_coor_list)
            X_coor = X_coor_list(ix);

            [sims, params] = Init();
            load([SW_PATH 'RunDir/savedState.mat']);
            defaultStream = RandStream.getGlobalStream;
            defaultStream.State = savedState;

            % --- same as run_simple_dfts_ofdm_sim.m ---
            params.BaudFreq = 64*GHz;
            params.RX = 64*GHz;
            params.Nbpsc = 4;
            params.Nsd = 120;
            params.NFFT = 128;
            params.dfts.Lbb = 2;
            params.dfts.active_subch = 0;
            params.TXSampleFreq = params.BaudFreq;
            params.RXSampleFreq = params.BaudFreq;
            params.AWGSampleFreq = params.TXSampleFreq;
            params.OSCFreq = params.RXSampleFreq;
            params.NTXStream = 2;
            params.NRXStream = 2;
            params.NLTF = 1;
            params.NDataSymbol = 200;
            params.en_bit_alloc = 0;
            params.en_power_loading = 0;
            params.TXMatchedfilter.en = 3;
            params.TXMatchedfilter.alpha = 1.0;
            params.searchframe.en = 1;
            params.searchfineframe.en = 1;
            params.searchframe.th = 0.5;
            params.searchfineframe.type = 1;
            params.cfr.en = 1;
            params.fcfr.en = 1;
            params.cpr.en = 1;
            params.cpr.bcpr_en = 0;
            params.tpr.en = 1;
            params.tpr.K1 = -2*pi;
            params.tpr.K2 = -0.001;
            sims.mode = mode;
            sims.X_coor = X_coor;
            sims.max_num_sim = 1;
            sims.en_disp_result = 0;
            sims.dataf.data_file = [DSP_PATH 'Ptn/prbs15.txt'];

            sims = SetChannel_OFDM(sim_case, sims, params);
            sims.channel.SNRdB = 20;
            sims.channel.TXLineWidth = PhaseNoise * MHz;
            sims.channel.RXLineWidth = PhaseNoise * MHz;
            sims.channel.PMD = PMD * ps;
            sims.channel.CarrierFreqOff = CFO * GHz;
            sims.channel.fiber_length = FiberLen * km;
            sims.channel.ssmf.Gamma = gamma;

            [sims, params] = ReInit(sims, params);

            dataf = DataGen(sims.dataf, params.totalbits, 0);
            [txout, txsignal] = TxMain(dataf, sims, params);
            txout_ext = [txout(:, end-1001+1:end), txout, txout(:, 1:2000)];
            [txout_awg] = Resample(txout_ext, params.TXSampleFreq, params.AWGSampleFreq);
            channelin = txout_awg;
            txsignal.txout_ext = txout_awg;

            [sims, params] = SweepSim(sims, params, 1);
            defaultStream.State = savedState;

            [channelout, sims] = Channel(sims, channelin, sims.channel);
            [~, frame] = RxMain_OFDM(channelout(1:params.NRXStream, :), ...
                txsignal, sims, params);
            [frameout, ~] = FrameAnalysis(txsignal, frame, params, sims);

            [BER, Nerr, Ntot] = calculate_BER(dataf(:).', frame.fecin(:).');
            EVM = frameout.EVM;

            fprintf('L=%2d km  X=%2g  %s  BER=%.3e  EVM=%.4f  ROP=%.1f dBm\n', ...
                FiberLen, X_coor, gtag, BER, EVM, sims.X_val);

            k = numel(results) + 1;
            results(k).fiber_km = FiberLen;
            results(k).X_coor = X_coor;
            results(k).gamma = gamma;
            results(k).BER = BER;
            results(k).EVM = EVM;
            results(k).ROP_dBm = sims.X_val;
            results(k).label = gtag;
        end
    end
end

%% Summary at highest X_coor (high ROP)
x_hi = max(X_coor_list);
fprintf('\n--- BER @ X_coor=%g (high power end) ---\n', x_hi);
fprintf('%-8s %12s %12s %10s\n', 'fiber_km', 'BER_gamma0', 'BER_gammaDef', 'EVM0');
for ifl = 1:numel(fiber_km_list)
    fk = fiber_km_list(ifl);
    b0 = results([results.fiber_km]==fk & [results.X_coor]==x_hi & ...
        strcmp({results.label}, 'gamma0'));
    bd = results([results.fiber_km]==fk & [results.X_coor]==x_hi & ...
        strcmp({results.label}, 'gammaDef'));
    if ~isempty(b0) && ~isempty(bd)
        fprintf('%6d   %12.3e %12.3e %10.4f\n', fk, b0.BER, bd.BER, b0.EVM);
    end
end

out_mat = fullfile(out_dir, 'verify_fiber_gamma0.mat');
save(out_mat, 'results', 'fiber_km_list', 'X_coor_list', 'gamma_default');

try
    fig = figure('Name', 'verify_fiber_gamma0', 'Color', 'w');
    cols = lines(numel(fiber_km_list));
    for ifl = 1:numel(fiber_km_list)
        fk = fiber_km_list(ifl);
        for ig = 1:2
            if ig == 1
                gtag = 'gamma0';
                mk = 'o';
            else
                gtag = 'gammaDef';
                mk = 's';
            end
            idx = [results.fiber_km]==fk & strcmp({results.label}, gtag);
            r = results(idx);
            [~, ord] = sort([r.X_coor]);
            r = r(ord);
            semilogy([r.X_coor], max([r.BER], 1e-7), ['-' mk], ...
                'Color', cols(ifl,:), 'DisplayName', sprintf('%d km %s', fk, gtag));
            hold on;
        end
    end
    grid on; xlabel('X\_coor (mode 87)'); ylabel('BER');
    title('Gamma=0 vs default NLSE (run\_simple path)');
    legend('Location', 'southwest');
    out_png = fullfile(out_dir, 'Figures', 'verify_fiber_gamma0.png');
    if ~exist(fileparts(out_png), 'dir'), mkdir(fileparts(out_png)); end
    saveas(fig, out_png);
catch ME
    fprintf('Plot note: %s\n', ME.message);
end

fprintf('\nSaved %s\n\n', out_mat);
