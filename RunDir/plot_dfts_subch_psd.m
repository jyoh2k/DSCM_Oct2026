%PLOT_DFTS_SUBCH_PSD  Per-subchannel TX PSD (separate figures, peak-normalized)
%
%   MF=0, no AWGN on plot. Each active_subch gets its own figure.
%   PSD is normalized to 0 dB peak.
%
%   >> run('RunDir/plot_dfts_subch_psd.m')

clearvars -except SW_PATH DSP_PATH
close all

this_dir = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
cd(proj_root);
run('AddPath.m');
run('Units.m');

modes = 0:4;   % 0=all, 1..4=single
Fs = 64e9;

fprintf('\n=== plot_dfts_subch_psd (TX only, peak-normalized, MF=0) ===\n');

out_dir = fullfile(proj_root, 'Results', 'Figures', 'dfts_subch_psd');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

store = struct('mode', {}, 'F', {}, 'Pxx_tx', {}, 'Pxx_norm', {}, 'R', {});

for k = 1:numel(modes)
    iu = modes(k);
    [sims, params] = Init();
    params.NDataSymbol = 200;
    params.Nbpsc = 4;
    params.en_bit_alloc = 0;
    params.en_power_loading = 0;
    params.NTXStream = 2;
    params.NRXStream = 2;
    params.NFFT = 128;
    params.dfts.Lbb = 2;
    params.dfts.active_subch = iu;
    params.BaudFreq = Fs;
    params.TXSampleFreq = Fs;
    params.RXSampleFreq = Fs;
    params.AWGSampleFreq = Fs;
    params.OSCFreq = Fs;
    params.TXMatchedfilter.en = 0;
    params.TXMatchedfilter.alpha = 1.0;
    params.TXAGC.en = 0;
    params.cpr.en = 1;
    params.cpr.bcpr_en = 0;
    params.ce.en_ISFA = 0;
    params.tpr.en = 0;
    sims.dataf.data_file = [DSP_PATH 'Ptn/prbs15.txt'];
    [sims, params] = ReInit(sims, params);

    R = params.Nsd * params.Nbpsc * params.NTXStream ...
        * params.BaudFreq / params.NSamplepersymbol;

    dataf = DataGen(sims.dataf, params.totalbits, 0);
    [txout, ~] = TxMain(dataf, sims, params);

    [Pxx_tx, F] = pwelch(txout(1,:), [], [], [], Fs, 'centered');
    Pxx_norm = Pxx_tx / max(Pxx_tx);   % peak normalize -> 0 dB

    if iu == 0
        label = 'all';
    else
        label = sprintf('sc%d', iu);
    end
    fprintf('%s  Nsd=%d  Npilot=%d  R=%.2f Gb/s\n', ...
        label, params.Nsd, numel(params.PilotIndex), R/1e9);

    fig = figure('Name', sprintf('TX PSD %s', label), 'Color', 'w', ...
        'Position', [100+30*k, 100+20*k, 720, 420]);
    plot(F/1e9, 10*log10(Pxx_norm + eps), 'b-', 'LineWidth', 1.2);
    grid on;
    xlim([-Fs/2, Fs/2]/1e9);
    ylim([-80, 5]);
    xlabel('Frequency (GHz)');
    ylabel('Normalized PSD (dB)');
    title(sprintf(['TX PSD (peak-norm)  |  %s  Nsd=%d  Npilot=%d  ' ...
        'R=%.1f Gb/s  |  Lbb=2, MF=0, Fs=64 GHz'], ...
        label, params.Nsd, numel(params.PilotIndex), R/1e9));

    out_png = fullfile(out_dir, sprintf('dfts_psd_%s_mf0_peaknorm.png', label));
    saveas(fig, out_png);
    fprintf('  saved %s\n', out_png);

    store(k).mode = iu;
    store(k).F = F;
    store(k).Pxx_tx = Pxx_tx;
    store(k).Pxx_norm = Pxx_norm;
    store(k).R = R;
    store(k).Nsd = params.Nsd;
    store(k).PilotIndex = params.PilotIndex;
    store(k).label = label;
end

out_mat = fullfile(out_dir, 'dfts_subch_psd_mf0_peaknorm.mat');
save(out_mat, 'store', 'Fs', 'modes');
fprintf('\nSaved mat: %s\n\n', out_mat);
