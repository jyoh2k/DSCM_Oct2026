%RUN_ALL_DFTS_OFDM_SIM  DFT-s-OFDM batch driver (same style as run_all_ofdm_sim)
%
%   Entry point:
%     >> run('RunSimSet/run_all_dfts_ofdm_sim.m')
%
%   Calls RunDir/run_simple_dfts_ofdm_sim.m
%   Branch feature/dfts-freq-os-lbb2: Lbb=2 (256 IFFT, STF time-OS x2)

run( ['Units.m']);
[sims, params]=  Init (    );
dir0 = [   SW_PATH './Results/Figures/260803_dfts/' ];
[s,messy] =mkdir([    dir0 ]); 

global SC
SC = 0;

IQGain =0; IQPhase=0;IQSkew=0;PhaseNoise=0;PMD=0;CFO=0; 
FiberLen = 0.1;
% idx =0;
% skewcomp_en =0;

color_list = {'bo-' 'm<-' 'g+-' 'cs-' 'rd-' 'k>-' 'bo:' 'm<:' 'g+:' 'cs:' 'rd:' 'k>:'...
    'mo--' 'g<--' 'c+--' 'rs--' 'kd--' 'b>--' 'mo-.' 'g<-.' 'c+-.' 'rs-.' 'kd-.' 'b>-.'};

sims.plot_axes{3}='';

mode = 87; %86;
num_sim = 1;

X_coor = [9:2:20];

%sim_case = 22; % [1 22];
simcases = 22; % [1 22];

% PNval = [0:0.1:0.5];
% FLval = [1:5:26];
% PMDval = [0:2:10];
%CFOval = [ 0:0.31:1.6];

% for k = 1:length(PNval)
%for k=1:length(CFOval)
%for k=1:length(FLval); %[1:3:30]
%for k = 1:length(PMDval)
for k = 1:length(simcases),
    sim_case = simcases(k);
    % PhaseNoise = PNval(k);
    % FiberLen = FLval(k);
    % PMD = PMDval(k);
    %CFO = CFOval(k);
    color = color_list{k};
    run([SW_PATH './RunDir/run_simple_dfts_ofdm_sim.m']);
end

ylim( sims.plothandle{3}.axes1, [1e-5 0.5e-1]) ;
xlim( sims.plothandle{3}.axes1,[ROP_dBm(1) ROP_dBm(length(X_coor))+1]);

%
dir1 = [   dir0 str  'w/'  ];
dir2= [  dir0 str  '/'];

[s,messy] =mkdir([    dir1 ]);
[s,messy] =mkdir([    dir2 ]); 

disp_ber( 1.0e-2, dir1, dir2, sims, simout, [   'DFTs-OFDM ' str '-260803' ] , params, X_coor, draw_new_plot, 2, 1);
