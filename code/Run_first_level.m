%% Settings
nsubjects = 60;
TR = 3.6;
TE = 0.05;

nregions    = 4;
nconditions = 3;

% Index of each condition in the DCM
TASK=1; PICTURES=2; WORDS=3;

% Index of each region in the DCM
lvF=1; ldF=2; rvF=3; rdF=4;

%% Specify DCMs (one per subject)

% Whether to include each condition from the design matrix
% (Task, Pictures, Words)
include = [1 1 1]';

% A-matrix (on / off)
a = ones(nregions,nregions);
a(lvF,rdF) = 0;
a(rdF,lvF) = 0;
a(ldF,rvF) = 0;
a(rvF,ldF) = 0;

% B-matrix
b(:,:,TASK)     = zeros(nregions); % Task
b(:,:,PICTURES) = eye(nregions);   % Pictures
b(:,:,WORDS)    = eye(nregions);   % Words

% C-matrix
c = zeros(nregions,nconditions);
c(:,TASK) = 1;

% D-matrix (disabled)
d = zeros(nregions,nregions,0);

start_dir = pwd;
for subject = 1:nsubjects
    
    name = sprintf('sub-%02d',subject);
    
    % Load SPM
    glm_dir = fullfile('..','GLM',name);
    SPM     = load(fullfile(glm_dir,'SPM.mat'));
    SPM     = SPM.SPM;
    
    % Load ROIs
    f = {fullfile(glm_dir,'VOI_lvF_1.mat');
         fullfile(glm_dir,'VOI_ldF_1.mat');
         fullfile(glm_dir,'VOI_rvF_1.mat');
         fullfile(glm_dir,'VOI_rdF_1.mat')};    
    for r = 1:length(f)
        XY = load(f{r});
        xY(r) = XY.xY;
    end
    
    % Move to output directory
    cd(glm_dir);
    
    % Specify. Corresponds to the series of questions in the GUI.
    s = struct();
    s.name       = 'full';
    s.u          = include;                 % Conditions
    s.delays     = repmat(TR,1,nregions);   % Slice timing for each region
    s.TE         = TE;
    s.nonlinear  = false;
    s.two_state  = false;
    s.stochastic = false;
    s.centre     = true;
    s.induced    = 0;
    s.a          = a;
    s.b          = b;
    s.c          = c;
    s.d          = d;
    DCM = spm_dcm_specify(SPM,xY,s);
    
    % Return to script dir
    cd(start_dir);
end

%% Collate into a GCM file and estimate

% Find all DCM files
dcms = spm_select('FPListRec','../GLM','DCM_full.mat');

% Prepare output directory
out_dir = '../analyses';
if ~exist(out_dir,'file')
    mkdir(out_dir);
end

% Check if it exists
if exist(fullfile(out_dir,'GCM_full.mat'),'file')
    opts.Default = 'No';
    opts.Interpreter = 'none';
    f = questdlg('Overwrite existing GCM?','Overwrite?','Yes','No',opts);
    tf = strcmp(f,'Yes');
else
    tf = true;
end

% Collate & estimate
if tf
    % Collate all subjects' DCM filenames
    GCM = cellstr(dcms);
    
    % Filenames -> DCM structures
    GCM = spm_dcm_load(GCM);

    % Estimate DCMs (this won't effect original DCM files)
    GCM = spm_dcm_fit(GCM);
    
    % Save estimated GCM
    save('../analyses/GCM_full.mat','GCM');
end
%% Specify 112 alternative models for 1 subject
%  These will be templates for the group analysis

% Define B-matrix for each family (factor: task)
% -------------------------------------------------------------------------
% Both
b_task_fam = {};
b_task_fam{1}(:,:,1) = ones(4); % Objects
b_task_fam{1}(:,:,2) = ones(4); % Words

% Words
b_task_fam{2}(:,:,1) = zeros(4); % Objects
b_task_fam{2}(:,:,2) = ones(4);  % Words

% Objects
b_task_fam{3}(:,:,1) = ones(4);  % Objects
b_task_fam{3}(:,:,2) = zeros(4); % Words

task_fam_names = {'Both','Words','Objects'};

% Define C-matrix for each family (factor: driving input)
% -------------------------------------------------------------------------
% Both
c_fam{1} = [1 0 0;
            1 0 0;
            1 0 0;
            1 0 0];
      
% Dorsal
c_fam{2} = [0 0 0;
            1 0 0;
            0 0 0;
            1 0 0];
      
% Ventral
c_fam{3}  = [1 0 0;
             0 0 0;
             1 0 0;
             0 0 0];
         
% None
c_fam{4}  = zeros(4,3);

c_fam_names = {'Both','Dorsal','Ventral','None'};

% Define B-matrix for each family (factor: dorsal-ventral)
% -------------------------------------------------------------------------
% Both
b_dv_fam{1} = eye(4);

% Dorsal
b_dv_fam{2} = [0 0 0 0;
               0 1 0 0;
               0 0 0 0;
               0 0 0 1];
% Ventral   
b_dv_fam{3} = [1 0 0 0;
               0 0 0 0;
               0 0 1 0;
               0 0 0 0];

b_dv_fam_names = {'Both','Dorsal','Ventral'};
           
% Define B-matrix for each family (factor: left-right)
% -------------------------------------------------------------------------
% Both
b_lr_fam{1} = eye(4);

% Left
b_lr_fam{2} = [1 0 0 0;
               0 1 0 0;
               0 0 0 0;
               0 0 0 0];

% Right  
b_lr_fam{3} = [0 0 0 0;
               0 0 0 0;
               0 0 1 0;
               0 0 0 1];  

b_lr_fam_names = {'Both','Left','Right'};
           
% Make a DCM for each mixture of these factors
% -------------------------------------------------------------------------

% Load an example DCM
GCM_full = load('../analyses/GCM_full.mat');
GCM_full = spm_dcm_load(GCM_full.GCM);
DCM_template = GCM_full{1,1};

% Output cell array for new models
GCM_templates = {};

m = 1;
for t = 1:length(b_task_fam)
    for dr = 1:length(c_fam)
        for dv = 1:length(b_dv_fam)
            for lr = 1:length(b_lr_fam)

                % Prepare B-matrix
                b = zeros(4,4,3);
                b(:,:,2:3) = b_dv_fam{dv} & b_lr_fam{lr} & b_task_fam{t};

                % Prepare C-matrix
                c = c_fam{dr};

                % Prepare model name
                name = sprintf('Task: %s, Driving: %s, Dorsoventral: %s, Hemi: %s',...
                    task_fam_names{t}, c_fam_names{dr}, b_dv_fam_names{dv}, b_lr_fam_names{lr});

                % Build minimal DCM
                DCM = struct();
                DCM.a       = DCM_template.a;
                DCM.b       = b;
                DCM.c       = c;
                DCM.d       = DCM_template.d;
                DCM.options = DCM_template.options;
                DCM.name    = name;                    
                GCM_templates{1,m} = DCM;

                % Record the assignment of this model to each family
                task_family(m) = t;
                c_family(m)    = dr;
                b_dv_family(m) = dv;
                b_lr_family(m) = lr;
                m = m + 1;
                
            end
        end
    end
end

% Add a null model for each level of the driving inputs factor
for dr = 1:length(c_fam)
    b = zeros(4);
    c = c_fam{dr};

    name = sprintf('Task: %s Modulation: None', task_fam_names{t});

    DCM.b(:,:,2) = b;
    DCM.b(:,:,3) = b;
    DCM.c        = c;
    DCM.name     = name;

    GCM_templates{1,m} = DCM;

    % Record the assignment of this model to each family
    c_family(m)    = dr;
    b_dv_family(m) = length(b_dv_fam)+1;
    b_lr_family(m) = length(b_lr_fam)+1;
    task_family(m) = length(b_task_fam)+1;

    m = m + 1;    
end

% Save
GCM = GCM_templates;
save('../analyses/GCM_templates.mat','GCM',...
    'task_family','b_dv_family','b_lr_family','c_family');