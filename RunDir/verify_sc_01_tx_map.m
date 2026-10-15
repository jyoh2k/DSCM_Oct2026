%VERIFY_SC_01_TX_MAP  Step-0/1: subchannel enable + TX data map only
%
%   >> run('RunDir/verify_sc_01_tx_map.m')

clearvars -except SW_PATH DSP_PATH
close all

this_dir = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
cd(proj_root);
run('AddPath.m');

fprintf('\n=== verify_sc_01_tx_map (subch enable / TX data) ===\n');
nfail = 0;

%% --- All ON (default) ---
[sims, params] = Init();
params.NDataSymbol = 4;
params.Nbpsc = 4;
params.en_bit_alloc = 0;
params.en_power_loading = 0;
params.NTXStream = 2;
params.NFFT = 128;
params.dfts.active_subch = 0;
sims.dataf.data_file = [DSP_PATH 'Ptn/prbs15.txt'];
[sims, params] = ReInit(sims, params);

nfail = nfail + check_eq('all: Nsd', params.Nsd, 120);
nfail = nfail + check_eq('all: enable', params.dfts.subch_enable, [1 1 1 1]);
nfail = nfail + check_eq('all: Nbpsym', params.Nbpsym, 120*4*2);
nfail = nfail + check_eq('all: Pilot still 6', numel(params.PilotIndex), 6);

dataf = DataGen(sims.dataf, params.totalbits, 0);
[grid_s, ~] = OFDMMapper(dataf, params);
grid = reshape(grid_s, params.NTXStream, params.NFFT, params.NDataSymbol);
map = params.dfts.map;
for iu = 1:4
    p = mean(abs(grid(:, map.SubchDataIndex{iu}, :)).^2, 'all');
    if p <= 0
        fprintf('FAIL: all-ON subch%d has no energy\n', iu); nfail = nfail + 1;
    end
end
fprintf('PASS: all-ON has energy on every subch data region\n');

%% --- Each single subchannel ---
exp_pilot0 = {
    [65, 96]
    [96, 127]
    [1, 32]
    [32, 63]
    };
for iu = 1:4
    [sims, params] = Init();
    params.NDataSymbol = 4;
    params.Nbpsc = 4;
    params.en_bit_alloc = 0;
    params.en_power_loading = 0;
    params.NTXStream = 2;
    params.NFFT = 128;
    params.dfts.active_subch = iu;
    sims.dataf.data_file = [DSP_PATH 'Ptn/prbs15.txt'];
    [sims, params] = ReInit(sims, params);

    nfail = nfail + check_eq(sprintf('sc%d: Nsd', iu), params.Nsd, 30);
    nfail = nfail + check_eq(sprintf('sc%d: Nbpsym', iu), params.Nbpsym, 30*4*2);
    nfail = nfail + check_eq(sprintf('sc%d: enable', iu), ...
        params.dfts.subch_enable, double((1:4)==iu));
    nfail = nfail + check_eq(sprintf('sc%d: ActivePilot_0', iu), ...
        params.dfts.ActivePilotIndex_0, exp_pilot0{iu});

    % Data-symbol pilots = adjacent pair; LTF still full (option B)
    nfail = nfail + check_eq(sprintf('sc%d: PilotIndex active', iu), ...
        params.PilotIndex, exp_pilot0{iu} + 1);
    if any(abs(params.LTF(map.SubcarrierIndex)) == 0)
        fprintf('FAIL: sc%d LTF missing on full active bins\n', iu); nfail = nfail + 1;
    else
        fprintf('PASS: sc%d LTF still covers full SubcarrierIndex\n', iu);
    end

    dataf = DataGen(sims.dataf, params.totalbits, 0);
    [grid_s, ~] = OFDMMapper(dataf, params);
    grid = reshape(grid_s, params.NTXStream, params.NFFT, params.NDataSymbol);

    act_pwr = mean(abs(grid(:, map.SubchDataIndex{iu}, :)).^2, 'all');
    if act_pwr <= 0
        fprintf('FAIL: sc%d active data energy=0\n', iu); nfail = nfail + 1;
    else
        fprintf('PASS: sc%d active data energy>0\n', iu);
    end
    for jv = setdiff(1:4, iu)
        leak = max(abs(grid(:, map.SubchDataIndex{jv}, :)), [], 'all');
        if leak > 1e-12
            fprintf('FAIL: sc%d leaks into subch%d (max=%.3g)\n', iu, jv, leak);
            nfail = nfail + 1;
        end
    end
    fprintf('PASS: sc%d no leakage into other data subch\n', iu);

    % Pilot/DC/Null still zero before AddPilot
    if max(abs(grid(:, map.PilotIndex, :)), [], 'all') > 0 ...
            || max(abs(grid(:, [map.DCIndex, map.NullIndex], :)), [], 'all') > 0
        fprintf('FAIL: sc%d pilot/DC/Null non-zero in mapper out\n', iu);
        nfail = nfail + 1;
    else
        fprintf('PASS: sc%d pilot/DC/Null zero at mapper output\n', iu);
    end
end

fprintf('\n----------------------------------------\n');
if nfail == 0
    fprintf('RESULT: PASS (verify_sc_01_tx_map)\n');
else
    fprintf('RESULT: FAIL (%d check(s) failed)\n', nfail);
    error('verify_sc_01_tx_map failed');
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
