%VERIFY_SC_03_RATE_PSD  Step-3: payload rate + active-band TX energy
%
%   Rate (payload only, no STF/LTF OH):
%     R = Nsd * Nbpsc * NTX * Fs / NSamplepersymbol
%
%   >> run('RunDir/verify_sc_03_rate_psd.m')

clearvars -except SW_PATH DSP_PATH
close all

this_dir = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
cd(proj_root);
run('AddPath.m');
run('Units.m');

fprintf('\n=== verify_sc_03_rate_psd (rate / TX energy) ===\n');
nfail = 0;

Fs = 64e9;
Nbpsc = 4;
NTX = 2;
Nsp = 288;   % Lbb=2
exp_rate = @(Nsd) Nsd * Nbpsc * NTX * Fs / Nsp;

fprintf('\n%-6s %6s %8s %12s\n', 'mode', 'Nsd', 'Npilot', 'R_payload');
fprintf('%s\n', repmat('-', 1, 40));

for iu = 0:4
    [sims, params] = Init();
    params.NDataSymbol = 8;
    params.Nbpsc = Nbpsc;
    params.en_bit_alloc = 0;
    params.en_power_loading = 0;
    params.NTXStream = NTX;
    params.NFFT = 128;
    params.dfts.Lbb = 2;
    params.dfts.active_subch = iu;
    params.BaudFreq = Fs;
    params.TXSampleFreq = Fs;
    params.RXSampleFreq = Fs;
    params.AWGSampleFreq = Fs;
    params.OSCFreq = Fs;
    params.TXMatchedfilter.en = 0;
    params.TXAGC.en = 0;
    sims.dataf.data_file = [DSP_PATH 'Ptn/prbs15.txt'];
    [sims, params] = ReInit(sims, params);

    if iu == 0
        label = 'all';
        exp_Nsd = 120;
        exp_Np = 6;
    else
        label = sprintf('sc%d', iu);
        exp_Nsd = 30;
        exp_Np = 2;
    end

    R = exp_rate(params.Nsd);
    fprintf('%-6s %6d %8d %10.2f Gb/s\n', label, params.Nsd, ...
        numel(params.PilotIndex), R/1e9);

    nfail = nfail + check_eq([label ': Nsd'], params.Nsd, exp_Nsd);
    nfail = nfail + check_eq([label ': Npilot'], numel(params.PilotIndex), exp_Np);
    nfail = nfail + check_eq([label ': Nsp'], params.NSamplepersymbol, Nsp);

    if abs(R - exp_rate(exp_Nsd)) > 1
        fprintf('FAIL: %s rate mismatch\n', label); nfail = nfail + 1;
    else
        fprintf('PASS: %s payload rate = %.3f Gb/s\n', label, R/1e9);
    end

    % 1-subch ≈ 1/4 of all
    if iu == 1
        R_all = exp_rate(120);
        if abs(R / R_all - 0.25) > 1e-9
            fprintf('FAIL: sc1 rate not 1/4 of all\n'); nfail = nfail + 1;
        else
            fprintf('PASS: sc1 rate is 1/4 of all-ON\n');
        end
    end

    % TX frequency-grid energy (mapper + pilot): active bins only
    dataf = DataGen(sims.dataf, params.totalbits, 0);
    [grid_s, ~] = OFDMMapper(dataf, params);
    grid_s = reshape(grid_s, params.NTXStream, params.NFFT * params.NDataSymbol);
    pilotout = AddPilotSymbol(grid_s, params.pilot);
    grid = reshape(pilotout, params.NTXStream, params.NFFT, params.NDataSymbol);
    map = params.dfts.map;

    act_bins = unique([params.DataSubcarrierIndex, params.PilotIndex]);
    inact = setdiff(1:params.NFFT, act_bins);
    % Keep DC/Null in inactive; also inactive data/pilots
    p_act = mean(abs(grid(:, act_bins, :)).^2, 'all');
    p_inact = max(abs(grid(:, inact, :)), [], 'all');
    if p_act <= 0
        fprintf('FAIL: %s active-bin power=0\n', label); nfail = nfail + 1;
    elseif p_inact > 1e-12
        fprintf('FAIL: %s inactive-bin leak max=%.3g\n', label, p_inact);
        nfail = nfail + 1;
    else
        fprintf('PASS: %s TX grid energy only on active data+pilot\n', label);
    end
end

fprintf('\n----------------------------------------\n');
if nfail == 0
    fprintf('RESULT: PASS (verify_sc_03_rate_psd)\n');
else
    fprintf('RESULT: FAIL (%d check(s) failed)\n', nfail);
    error('verify_sc_03_rate_psd failed');
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
