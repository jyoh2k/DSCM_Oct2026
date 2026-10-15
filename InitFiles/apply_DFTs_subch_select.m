function params = apply_DFTs_subch_select(params)
%APPLY_DFTS_SUBCH_SELECT  Select active DFT-s subchannel(s) for data path
%
%   params.dfts.active_subch :
%       0   -> all subchannels ON (default)
%       1..4 -> only that subchannel ON
%   or params.dfts.subch_enable : 1x4 logical/double mask
%
%   Updates (data / pilots for data symbols):
%       params.Nsd, params.DataSubcarrierIndex
%       params.PilotIndex, params.PilotSym  (adjacent pilots of active subch)
%   Keeps LTF / SubcarrierIndex full (option B).

    map = params.dfts.map;
    Nsubch = map.Nsubch;
    Nd = map.Nd;

    if ~isfield(params.dfts, 'active_subch') || isempty(params.dfts.active_subch)
        params.dfts.active_subch = 0;
    end

    if isfield(params.dfts, 'subch_enable') && ~isempty(params.dfts.subch_enable) ...
            && params.dfts.active_subch == 0
        en = params.dfts.subch_enable(:).';
        if numel(en) ~= Nsubch
            error('apply_DFTs_subch_select:EnableSize', ...
                'subch_enable must have %d elements.', Nsubch);
        end
    else
        as = params.dfts.active_subch;
        if as == 0
            en = ones(1, Nsubch);
        elseif as >= 1 && as <= Nsubch
            en = zeros(1, Nsubch);
            en(as) = 1;
        else
            error('apply_DFTs_subch_select:BadActive', ...
                'active_subch must be 0 (all) or 1..%d (got %d).', Nsubch, as);
        end
    end
    en = double(en ~= 0);
    if ~any(en)
        error('apply_DFTs_subch_select:NoneEnabled', 'At least one subchannel must be enabled.');
    end

    enabled = find(en);
    data_active = [];
    for k = 1:numel(enabled)
        data_active = [data_active, map.SubchDataIndex{enabled(k)}]; %#ok<AGROW>
    end
    data_active = sort(data_active);

    % Adjacent pilots (figure 0-based) per subchannel
    pilot_adj_0 = {
        [65, 96]
        [96, 127]
        [1, 32]
        [32, 63]
        };
    pilot_active_0 = [];
    for k = 1:numel(enabled)
        pilot_active_0 = [pilot_active_0, pilot_adj_0{enabled(k)}]; %#ok<AGROW>
    end
    pilot_active_0 = unique(pilot_active_0);
    % Keep same order as full map.PilotIndex (not enable-concatenation order)
    pilot_active = intersect(map.PilotIndex, pilot_active_0 + 1, 'stable');
    pilot_active_0 = pilot_active - 1;

    % Subset PilotSym to match active pilot order (get_LTF already set full)
    pilot_full = map.PilotIndex;
    [tf, loc] = ismember(pilot_active, pilot_full);
    if ~all(tf)
        error('apply_DFTs_subch_select:PilotMap', 'Active pilot not in full PilotIndex.');
    end
    pilot_sym_full = params.PilotSym;
    pilot_sym_act = pilot_sym_full(:, loc);

    params.dfts.subch_enable = en;
    params.dfts.enabled_subch = enabled;
    params.dfts.Nsd_full = map.Nsd;
    params.dfts.Nsd_active = numel(data_active);
    params.dfts.Npilot_active = numel(pilot_active);
    params.dfts.DataSubcarrierIndex_full = map.DataSubcarrierIndex;
    params.dfts.PilotIndex_full = pilot_full;
    params.dfts.PilotSym_full = pilot_sym_full;
    params.dfts.ActiveDataIndex = data_active;
    params.dfts.ActivePilotIndex = pilot_active;
    params.dfts.ActivePilotIndex_0 = pilot_active_0;
    params.dfts.PilotAdjIndex_0 = pilot_adj_0;

    % Data-path fields (mapper / AddPilot / CPE / bit accounting)
    params.Nsd = params.dfts.Nsd_active;
    params.DataSubcarrierIndex = data_active;
    params.PilotIndex = pilot_active;
    params.PilotSym = pilot_sym_act;
end
