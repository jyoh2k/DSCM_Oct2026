%VERIFY_SC_02_PILOT  Step-2: adjacent pilots only on data symbols (LTF full)
%
%   >> run('RunDir/verify_sc_02_pilot.m')

clearvars -except SW_PATH DSP_PATH
close all

this_dir = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
cd(proj_root);
run('AddPath.m');

fprintf('\n=== verify_sc_02_pilot (active adjacent pilots) ===\n');
nfail = 0;

exp_pilot0 = {
    [65, 96]
    [96, 127]
    [1, 32]
    [32, 63]
    };

%% --- All ON: still 6 unique pilots ---
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

nfail = nfail + check_eq('all: PilotIndex count', numel(params.PilotIndex), 6);
nfail = nfail + check_eq('all: PilotIndex', params.PilotIndex, params.dfts.map.PilotIndex);
nfail = nfail + check_eq('all: PilotSym size', size(params.PilotSym), [2, 6]);

% LTF still full active bins
map = params.dfts.map;
if any(abs(params.LTF(map.SubcarrierIndex)) == 0)
    fprintf('FAIL: all-ON LTF missing on full SubcarrierIndex\n'); nfail = nfail + 1;
else
    fprintf('PASS: all-ON LTF covers full SubcarrierIndex\n');
end

dataf = DataGen(sims.dataf, params.totalbits, 0);
[grid_s, ~] = OFDMMapper(dataf, params);
grid_s = reshape(grid_s, params.NTXStream, params.NFFT * params.NDataSymbol);
pilotout = AddPilotSymbol(grid_s, params.pilot);
grid = reshape(pilotout, params.NTXStream, params.NFFT, params.NDataSymbol);

for ip = 1:numel(map.PilotIndex)
    p = mean(abs(grid(:, map.PilotIndex(ip), :)).^2, 'all');
    if p <= 0
        fprintf('FAIL: all-ON pilot bin %d has no energy\n', map.PilotIndex(ip));
        nfail = nfail + 1;
    end
end
fprintf('PASS: all-ON has energy on every pilot\n');

%% --- Each single subchannel ---
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
    map = params.dfts.map;

    act_p0 = exp_pilot0{iu};
    act_p = act_p0 + 1;
    nfail = nfail + check_eq(sprintf('sc%d: PilotIndex', iu), params.PilotIndex, act_p);
    nfail = nfail + check_eq(sprintf('sc%d: Npilot', iu), params.dfts.Npilot_active, 2);
    nfail = nfail + check_eq(sprintf('sc%d: PilotSym cols', iu), size(params.PilotSym, 2), 2);

    % PilotSym matches subset of full map order
    [~, loc] = ismember(act_p, map.PilotIndex);
    exp_sym = params.dfts.PilotSym_full(:, loc);
    nfail = nfail + check_eq(sprintf('sc%d: PilotSym subset', iu), params.PilotSym, exp_sym);

    % LTF option B: still full
    if any(abs(params.LTF(map.SubcarrierIndex)) == 0)
        fprintf('FAIL: sc%d LTF not full\n', iu); nfail = nfail + 1;
    else
        fprintf('PASS: sc%d LTF still full (option B)\n', iu);
    end
    nfail = nfail + check_eq(sprintf('sc%d: SubcarrierIndex full', iu), ...
        numel(params.SubcarrierIndex), numel(map.SubcarrierIndex));

    dataf = DataGen(sims.dataf, params.totalbits, 0);
    [grid_s, ~] = OFDMMapper(dataf, params);
    grid_s = reshape(grid_s, params.NTXStream, params.NFFT * params.NDataSymbol);
    pilotout = AddPilotSymbol(grid_s, params.pilot);
    grid = reshape(pilotout, params.NTXStream, params.NFFT, params.NDataSymbol);

    % Active pilots non-zero and match PilotSym
    for k = 1:numel(act_p)
        got = grid(:, act_p(k), 1);
        expv = params.PilotSym(:, k);
        if max(abs(got - expv)) > 1e-12
            fprintf('FAIL: sc%d pilot bin %d mismatch\n', iu, act_p(k));
            nfail = nfail + 1;
        end
    end
    fprintf('PASS: sc%d active pilots match PilotSym\n', iu);

    % Inactive pilots zero
    inactive = setdiff(map.PilotIndex, act_p);
    leak = max(abs(grid(:, inactive, :)), [], 'all');
    if leak > 1e-12
        fprintf('FAIL: sc%d inactive pilot energy (max=%.3g)\n', iu, leak);
        nfail = nfail + 1;
    else
        fprintf('PASS: sc%d inactive pilots are zero\n', iu);
    end

    % Inactive data still zero
    for jv = setdiff(1:4, iu)
        leakd = max(abs(grid(:, map.SubchDataIndex{jv}, :)), [], 'all');
        if leakd > 1e-12
            fprintf('FAIL: sc%d data leak into subch%d\n', iu, jv);
            nfail = nfail + 1;
        end
    end
    fprintf('PASS: sc%d inactive data still zero after AddPilot\n', iu);
end

fprintf('\n----------------------------------------\n');
if nfail == 0
    fprintf('RESULT: PASS (verify_sc_02_pilot)\n');
else
    fprintf('RESULT: FAIL (%d check(s) failed)\n', nfail);
    error('verify_sc_02_pilot failed');
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
