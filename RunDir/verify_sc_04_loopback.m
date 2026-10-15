%VERIFY_SC_04_LOOPBACK  Step-4: single-subch known-timing loopback BER=0
%
%   LTF full (option B); data pilots = adjacent pair; IDFT-s on active only.
%   Lbb=2 (freq OS). CPE ON (pilot-based).
%
%   >> run('RunDir/verify_sc_04_loopback.m')

clearvars -except SW_PATH DSP_PATH
close all

this_dir = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
cd(proj_root);
run('AddPath.m');

fprintf('\n=== verify_sc_04_loopback (active subch RX) ===\n');
nfail = 0;

for iu = 0:4   % 0=all, 1..4=single
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
    params.TXMatchedfilter.en = 0;
    params.TXMatchedfilter.alpha = 1.0;
    params.cpr.en = 1;          % pilot CPE with active pilots
    params.cpr.bcpr_en = 0;
    params.ce.en_ISFA = 0;
    params.TXAGC.en = 0;
    params.tpr.en = 0;
    sims.dataf.data_file = [DSP_PATH 'Ptn/prbs15.txt'];
    [sims, params] = ReInit(sims, params);

    if iu == 0
        label = 'all';
        nfail = nfail + check_eq('all: Nsd', params.Nsd, 120);
        nfail = nfail + check_eq('all: Npilot', numel(params.PilotIndex), 6);
    else
        label = sprintf('sc%d', iu);
        nfail = nfail + check_eq([label ': Nsd'], params.Nsd, 30);
        nfail = nfail + check_eq([label ': Npilot'], numel(params.PilotIndex), 2);
    end
    nfail = nfail + check_eq([label ': NSamplepersymbol'], params.NSamplepersymbol, 288);

    dataf = DataGen(sims.dataf, params.totalbits, 0);
    [~, txsignal] = TxMain(dataf, sims, params);

    txframe = txsignal.txframe;
    n_stf = params.NSTFSample;
    n_ofdm = params.NSymbol * params.NSamplepersymbol;
    if size(txframe, 2) < n_stf + n_ofdm
        fprintf('FAIL: %s txframe too short\n', label);
        nfail = nfail + 1;
        continue;
    end
    td = txframe(:, n_stf + (1:n_ofdm));

    fft_out = FFTnRemoveGI(td, params.fft);
    [data_f, H] = ChannelEst(fft_out, params.ce);

    frame = struct();
    [eq2_out, ~, ~, frame] = ChannelComp(data_f, H, params, frame); %#ok<ASGLU>
    nfail = nfail + check_eq([label ': despread len'], ...
        size(eq2_out, 2), params.Nsd * params.NDataSymbol);

    qam_mse = mean(abs(txsignal.mapper2(:) - eq2_out(:)).^2);
    if qam_mse >= 1e-10
        fprintf('FAIL: %s QAM MSE=%.3e\n', label, qam_mse);
        nfail = nfail + 1;
    else
        fprintf('PASS: %s QAM MSE=%.3e\n', label, qam_mse);
    end

    rx_bits = OFDMDemapper(SingleStreamOut(eq2_out, params), params);
    [BER, Nerr, Ntot] = calculate_BER(dataf, rx_bits);
    if BER ~= 0
        fprintf('FAIL: %s BER=%g (%d/%d)\n', label, BER, Nerr, Ntot);
        nfail = nfail + 1;
    else
        fprintf('PASS: %s BER=0 (%d bits, Npilot=%d)\n', ...
            label, Ntot, numel(params.PilotIndex));
    end
end

fprintf('\n----------------------------------------\n');
if nfail == 0
    fprintf('RESULT: PASS (verify_sc_04_loopback)\n');
else
    fprintf('RESULT: FAIL (%d check(s) failed)\n', nfail);
    error('verify_sc_04_loopback failed');
end
fprintf('----------------------------------------\n\n');

function n = check_eq(name, got, expv)
    if isequal(got, expv)
        fprintf('PASS: %s\n', name); n = 0;
    else
        fprintf('FAIL: %s\n  got=%s\n  exp=%s\n', name, mat2str(got), mat2str(expv));
        n = 1;
    end
end
