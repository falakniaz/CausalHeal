function CausalHeal_RealData_Benchmark_V15_2_Reproducibility_FIXED
clc;
close all;
clear functions;

fprintf('\n============================================================\n');
fprintf(' CausalHeal V15.2 Frozen Multi-Seed Reproducibility Benchmark\n');
fprintf('============================================================\n');

cfg.reproSeeds = [7 17 27 37 47 57 67 77 87 97];
cfg.reproConfidenceZ = 1.96;
cfg.reproPrimaryAlignment = 'SpectralCORAL';
cfg.reproPrimaryCalibration = 'IterativeTrimmedCore';
cfg.reproFreezeAlgorithms = true;

nSeeds=numel(cfg.reproSeeds);

% V15.2 recovery option: reuse completed per-seed CSVs when all are present.
reuseCompleted=true;
for si=1:nSeeds
    seedCheck=cfg.reproSeeds(si);
    required={ ...
        sprintf('RealDataV15_Seed%03d_DatasetWise_Detection.csv',seedCheck), ...
        sprintf('RealDataV15_Seed%03d_AttackType_Robustness.csv',seedCheck), ...
        sprintf('RealDataV15_Seed%03d_AttackFamily_Macro.csv',seedCheck), ...
        sprintf('RealDataV15_Seed%03d_SpectralCORAL_CrossDataset.csv',seedCheck), ...
        sprintf('RealDataV15_Seed%03d_TransferValidity.csv',seedCheck)};
    for rr=1:numel(required)
        if ~isfile(required{rr})
            reuseCompleted=false;
            break;
        end
    end
    if ~reuseCompleted
        break;
    end
end

AllDatasetWise=table();
AllAttackType=table();
AllAttackMacro=table();
AllCross=table();
AllValidity=table();

for si=1:nSeeds

    seed=cfg.reproSeeds(si);

    if reuseCompleted
        fprintf('V15.2 aggregation recovery %d/%d | seed=%d\n',si,nSeeds,seed);

        T=readtable(sprintf('RealDataV15_Seed%03d_DatasetWise_Detection.csv',seed));
        T.Seed=repmat(seed,height(T),1);
        AllDatasetWise=[AllDatasetWise;T]; %#ok<AGROW>

        T=readtable(sprintf('RealDataV15_Seed%03d_AttackType_Robustness.csv',seed));
        T.Seed=repmat(seed,height(T),1);
        AllAttackType=[AllAttackType;T]; %#ok<AGROW>

        T=readtable(sprintf('RealDataV15_Seed%03d_AttackFamily_Macro.csv',seed));
        T.Seed=repmat(seed,height(T),1);
        AllAttackMacro=[AllAttackMacro;T]; %#ok<AGROW>

        T=readtable(sprintf('RealDataV15_Seed%03d_SpectralCORAL_CrossDataset.csv',seed));
        T.Seed=repmat(seed,height(T),1);
        AllCross=[AllCross;T]; %#ok<AGROW>

        T=readtable(sprintf('RealDataV15_Seed%03d_TransferValidity.csv',seed));
        T.Seed=repmat(seed,height(T),1);
        AllValidity=[AllValidity;T]; %#ok<AGROW>

    else
        fprintf('\n------------------------------------------------------------\n');
        fprintf('V15 frozen run %d/%d | seed=%d\n',si,nSeeds,seed);
        fprintf('------------------------------------------------------------\n');

        R=runV15OneSeed(seed,cfg);

        T=R.DatasetWiseTable;
        T.Seed=repmat(seed,height(T),1);
        AllDatasetWise=[AllDatasetWise;T]; 

        T=R.AttackTypeTable;
        T.Seed=repmat(seed,height(T),1);
        AllAttackType=[AllAttackType;T]; 
        T=R.AttackMacroTable;
        T.Seed=repmat(seed,height(T),1);
        AllAttackMacro=[AllAttackMacro;T]; %#ok<AGROW>

        T=R.CrossDatasetTable;
        T.Seed=repmat(seed,height(T),1);
        AllCross=[AllCross;T]; %#ok<AGROW>

        T=R.TransferValidityTable;
        T.Seed=repmat(seed,height(T),1);
        AllValidity=[AllValidity;T]; %#ok<AGROW>
    end
end

% -------------------------------------------------------------------------
% Aggregate frozen reproducibility results
% -------------------------------------------------------------------------
DatasetWiseSummary=aggregateMetricTable( ...
    AllDatasetWise,{'Dataset','Method'}, ...
    {'Precision','Recall','F1','Accuracy','FPR', ...
     'BalancedAccuracy','AUROC','AUPRC'}, ...
    cfg.reproConfidenceZ);

AttackMacroSummary=aggregateMetricTable( ...
    AllAttackMacro,{'Dataset'}, ...
    {'MacroAttackRecall','MedianAttackRecall', ...
     'MinAttackRecall','MaxAttackRecall'}, ...
    cfg.reproConfidenceZ);

% Only evaluate cross-dataset performance rows if they were validity-approved.
supportedMask=false(height(AllCross),1);
if ismember('TransferSupported',AllCross.Properties.VariableNames)
    supportedMask=logical(AllCross.TransferSupported);
end

SupportedCross=AllCross(supportedMask,:);

if height(SupportedCross)>0
    CrossDatasetSummary=aggregateMetricTable( ...
        SupportedCross, ...
        {'TrainDataset','TestDataset','AlignmentMode','CalibrationMode'}, ...
        {'Precision','Recall','F1','Accuracy','FPR', ...
         'BalancedAccuracy','AUROC','AUPRC'}, ...
        cfg.reproConfidenceZ);
else
    CrossDatasetSummary=table();
end

ValidityFrequency=aggregateValidityFrequency(AllValidity);


primaryMask = ...
    strcmp(string(AllCross.AlignmentMode),cfg.reproPrimaryAlignment) & ...
    strcmp(string(AllCross.CalibrationMode),cfg.reproPrimaryCalibration);

PrimaryPolicyRows=AllCross(primaryMask,:);

PrimaryPolicySummary=aggregatePrimaryPolicy( ...
    PrimaryPolicyRows,cfg.reproConfidenceZ);

% -------------------------------------------------------------------------
% Write final paper-ready outputs
% -------------------------------------------------------------------------
writetable(AllDatasetWise,'RealDataV15_DatasetWise_Detection_AllSeeds.csv');
writetable(DatasetWiseSummary,'RealDataV15_DatasetWise_Detection_Summary.csv');

writetable(AllAttackType,'RealDataV15_AttackType_Robustness_AllSeeds.csv');
writetable(AllAttackMacro,'RealDataV15_AttackFamily_Macro_AllSeeds.csv');
writetable(AttackMacroSummary,'RealDataV15_AttackFamily_Macro_Summary.csv');

writetable(AllCross,'RealDataV15_SpectralCORAL_CrossDataset_AllSeeds.csv');
if height(CrossDatasetSummary)>0
    writetable(CrossDatasetSummary,'RealDataV15_SpectralCORAL_CrossDataset_Summary.csv');
end

writetable(AllValidity,'RealDataV15_TransferValidity_AllSeeds.csv');
writetable(ValidityFrequency,'RealDataV15_TransferValidity_Frequency.csv');
writetable(PrimaryPolicySummary,'RealDataV15_PrimaryPolicy_Summary.csv');

save('CausalHeal_RealData_V15_Results.mat', ...
    'cfg','AllDatasetWise','DatasetWiseSummary', ...
    'AllAttackType','AllAttackMacro','AttackMacroSummary', ...
    'AllCross','CrossDatasetSummary','AllValidity', ...
    'ValidityFrequency','PrimaryPolicyRows','PrimaryPolicySummary');

fprintf('\n============================================================\n');
fprintf('TABLE V15-A: DATASET-WISE REPRODUCIBILITY SUMMARY\n');
fprintf('============================================================\n');
disp(DatasetWiseSummary);

fprintf('\n============================================================\n');
fprintf('TABLE V15-B: TRANSFER VALIDITY FREQUENCY\n');
fprintf('============================================================\n');
disp(ValidityFrequency);

fprintf('\n============================================================\n');
fprintf('TABLE V15-C: PRIMARY POLICY SUMMARY\n');
fprintf('============================================================\n');
disp(PrimaryPolicySummary);

fprintf('\nV15 completed. Algorithm is frozen; no further tuning is performed.\n');
fprintf('Seeds: %s\n',mat2str(cfg.reproSeeds));
fprintf('Primary transfer policy: %s + %s\n', ...
    cfg.reproPrimaryAlignment,cfg.reproPrimaryCalibration);

end

function R=runV15OneSeed(seed,reproCfg)


seedRun=seed;
rng(seedRun,'twister');


cfg.reproSeeds=reproCfg.reproSeeds;
cfg.reproConfidenceZ=reproCfg.reproConfidenceZ;
cfg.reproPrimaryAlignment=reproCfg.reproPrimaryAlignment;
cfg.reproPrimaryCalibration=reproCfg.reproPrimaryCalibration;
cfg.reproFreezeAlgorithms=reproCfg.reproFreezeAlgorithms;

cfg.paths.CICIoT2023 = ...
    'C:\Users\Rahman\Desktop\Gimbal_Fuzzy_PID\mdpi\data\CICIOT23';

cfg.files.ToNIoT = ...
    'C:\Users\Rahman\Desktop\Gimbal_Fuzzy_PID\mdpi\data\ToN_IoT\train_test_network.csv';

cfg.files.InSDN = { ...
    'C:\Users\Rahman\Desktop\Gimbal_Fuzzy_PID\mdpi\data\InSDN_DatasetCSV\metasploitable-2.csv', ...
    'C:\Users\Rahman\Desktop\Gimbal_Fuzzy_PID\mdpi\data\InSDN_DatasetCSV\Normal_data.csv', ...
    'C:\Users\Rahman\Desktop\Gimbal_Fuzzy_PID\mdpi\data\InSDN_DatasetCSV\OVS.csv'};

cfg.files.EdgeIIoT = { ...
    'C:\Users\Rahman\Desktop\Gimbal_Fuzzy_PID\mdpi\data\Edge-IIoTset\DNN-EdgeIIoT-dataset.csv', ...
    'C:\Users\Rahman\Desktop\Gimbal_Fuzzy_PID\mdpi\data\Edge-IIoTset\ML-EdgeIIoT-dataset.csv', ...
    'C:\Users\Rahman\Desktop\Gimbal_Fuzzy_PID\mdpi\data\Edge-IIoTset\live_data_training.csv', ...
    'C:\Users\Rahman\Desktop\Gimbal_Fuzzy_PID\mdpi\data\Edge-IIoTset\train_test_network.csv'};

cfg.edgePreferredFile = 'DNN-EdgeIIoT-dataset.csv';


cfg.maxRowsPerDataset = 250000;


cfg.printSchema = true;
cfg.schemaPreviewVariables = 25;


cfg.randomSeed = 42;


cfg.normalTrainFraction = 0.70;


cfg.validationFraction = 0.20;


cfg.balanceEvaluation = true;
cfg.maxEvalPerClass = 50000;

% Temporal policy
cfg.temporalPolicy = 'auto';   % 'auto' | 'off' | 'on'
cfg.minTemporalRows = 1000;

% Encoder settings
cfg.latentDim = 12;
cfg.ridgeLambda = 1e-3;
cfg.maskProbability = 0.20;

% Detection score weights
cfg.wRec = 0.34;
cfg.wPred = 0.33;
cfg.wCross = 0.33;


cfg.thresholdK = 3.0;


cfg.commonDim = 12;


cfg.semanticMinShared = 6;
cfg.semanticMaxSourceBenign = 60000;
cfg.semanticMaxTargetPerClass = 40000;
cfg.semanticThresholdK = 3.0;
cfg.semanticUseDerived = true;
cfg.semanticEps = 1e-9;
cfg.semanticMaxAbs = 1e9;


cfg.domainAlignModes = {'SourceOnly','RobustLocationScale','CORAL'};
cfg.targetUnlabeledCalibMax = 20000;
cfg.coralRidge = 1e-3;
cfg.coralMaxDim = 40;
cfg.alignmentTrimQuantile = 0.95;

% V10 target-side threshold calibration (unlabeled calibration subset only)
cfg.targetThresholdQuantiles = [0.95 0.975 0.99 0.995];
cfg.robustTailK = 3.0;
cfg.minTargetCalibScores = 200;

% V11 contamination-aware target calibration
cfg.pseudoNormalFractions = [0.50 0.60];
cfg.iterativeTrimFraction = 0.60;
cfg.iterativeTrimRounds = 3;

% Transfer abstention safeguards
cfg.maxCalibrationAlarmForTransfer = 0.85;
cfg.minTargetCoreRows = 100;
cfg.minScoreSpreadRatio = 1e-6;

% V12 multi-criterion transfer validity gate
cfg.validSpreadRatioMin = 0.10;
cfg.validSpreadRatioMax = 10.0;
cfg.maxCoreMedianShiftMAD = 5.0;
cfg.validCoreScaleRatioMin = 0.10;
cfg.validCoreScaleRatioMax = 10.0;
cfg.maxCovarianceCondition = 1e6;
cfg.validityCoreFraction = 0.50;


cfg.spectralKappaGrid = [1e6 1e5 1e4 1e3];
cfg.primaryCalibrationMode = 'IterativeTrimmedCore';
cfg.spectralEigenFloorAbs = 1e-12;


cfg.minVariance = 1e-8;

datasets = {'CICIoT2023','ToNIoT','EdgeIIoT','InSDN'};

methods = { ...
    'PCA Reconstruction', ...
    'Mahalanobis', ...
    'CausalHeal w/o Reconstruction', ...
    'CausalHeal-Static', ...
    'CausalHeal Adaptive Full'};

fprintf('\n============================================================\n');
fprintf('        CausalHeal Real-Data Detection Benchmark\n');
fprintf('============================================================\n\n');

%% ------------------------------------------------------------------------
% 2. LOAD AND STANDARDIZE DATASETS
% -------------------------------------------------------------------------
Data = struct();

availableDatasets = {};

for d = 1:numel(datasets)

    name = datasets{d};
    fprintf('Loading %s ...\n',name);

    try
        switch name
            case 'CICIoT2023'
                Data.(name) = loadCICIoT2023(cfg.paths.CICIoT2023,cfg);

            case 'ToNIoT'
                Data.(name) = loadToNIoTV6(cfg.files.ToNIoT,cfg);

            case 'EdgeIIoT'
                Data.(name) = loadEdgeIIoTV6(cfg.files.EdgeIIoT,cfg);

            case 'InSDN'
                Data.(name) = loadInSDNV6(cfg.files.InSDN,cfg);
        end

        if sum(Data.(name).Y==0)==0
            warning('%s loaded with ZERO benign samples. Dataset skipped.',name);
            Data = rmfield(Data,name);
            continue;
        end

        if sum(Data.(name).Y==1)==0
            warning('%s loaded with ZERO attack samples. Dataset skipped.',name);
            Data = rmfield(Data,name);
            continue;
        end

        availableDatasets{end+1} = name; %#ok<SAGROW>

        fprintf('  rows       : %d\n',size(Data.(name).X,1));
        fprintf('  features   : %d\n',size(Data.(name).X,2));
        fprintf('  attacks    : %d\n',sum(Data.(name).Y==1));
        fprintf('  benign     : %d\n',sum(Data.(name).Y==0));

        if isfield(Data.(name),'TemporalInfo') && Data.(name).TemporalInfo.available
            fprintf('  temporal   : enabled candidate (%s)\n\n', ...
                Data.(name).TemporalInfo.variable);
        else
            fprintf('  temporal   : disabled (static tabular mode)\n\n');
        end

    catch ME
        warning('Skipping %s: %s',name,ME.message);
        fprintf('\n');
    end
end

datasets = availableDatasets;

if isempty(datasets)
    error('No usable datasets were loaded. Check paths and label formats.');
end

%% ------------------------------------------------------------------------
% 3. DATASET-WISE BENCHMARK
% -------------------------------------------------------------------------
nD = numel(datasets);
nM = numel(methods);

Precision = nan(nM,nD);
Recall    = nan(nM,nD);
F1        = nan(nM,nD);
Accuracy  = nan(nM,nD);
FPR       = nan(nM,nD);
AUROC     = nan(nM,nD);
Threshold = nan(nM,nD);
BalancedAccuracy = nan(nM,nD);
AUPRC     = nan(nM,nD);

models = struct();

for d = 1:nD

    name = datasets{d};
    D = Data.(name);

    fprintf('Dataset-wise benchmark: %s\n',name);

    [trainIdx,testIdx] = buildNormalTrainTestSplitV3(D.Y,cfg);

    XtrainRaw = D.X(trainIdx,:);
    XtestRaw  = D.X(testIdx,:);
    Ytest     = D.Y(testIdx);

    % Training-data-only preprocessing
    prep = fitPreprocessor(XtrainRaw);
    Xtrain = applyPreprocessor(XtrainRaw,prep);
    Xtest  = applyPreprocessor(XtestRaw,prep);

    % Feature-space self-supervised detector
    detector = trainCausalHealDetector(Xtrain,cfg,D.TemporalInfo);

    [scores,scoreNames] = scoreCausalHealDetector( ...
        detector,Xtrain,Xtest,cfg);

    yPred = cell(nM,1);

    for m = 1:nM

        trainScore = scores.train{m};
        testScore  = scores.test{m};

        threshold = median(trainScore) + ...
            cfg.thresholdK*robustMAD(trainScore);

        Threshold(m,d) = threshold;
        yPred{m} = testScore > threshold;

        [p,r,f,a,fpr,bacc] = classificationMetricsV3(Ytest,yPred{m});

        Precision(m,d) = p;
        Recall(m,d)    = r;
        F1(m,d)        = f;
        Accuracy(m,d)  = a;
        FPR(m,d)       = fpr;
        BalancedAccuracy(m,d) = bacc;
        AUROC(m,d)     = safeAUROC(Ytest,testScore);
        AUPRC(m,d)     = safeAUPRC(Ytest,testScore);
    end

    models.(name).prep = prep;
    models.(name).detector = detector;
    models.(name).scoreNames = scoreNames;
end

%% ------------------------------------------------------------------------
% 4. DATASET-WISE TABLE
% -------------------------------------------------------------------------
rowMethod = {};
rowDataset = {};
rowPrecision = [];
rowRecall = [];
rowF1 = [];
rowAccuracy = [];
rowFPR = [];
rowAUROC = [];
rowBalancedAccuracy = [];
rowAUPRC = [];
rowThreshold = [];

for d = 1:nD
    for m = 1:nM

        rowMethod{end+1,1} = methods{m}; %#ok<SAGROW>
        rowDataset{end+1,1} = datasets{d}; %#ok<SAGROW>

        rowPrecision(end+1,1) = Precision(m,d); %#ok<SAGROW>
        rowRecall(end+1,1)    = Recall(m,d); %#ok<SAGROW>
        rowF1(end+1,1)        = F1(m,d); %#ok<SAGROW>
        rowAccuracy(end+1,1)  = Accuracy(m,d); %#ok<SAGROW>
        rowFPR(end+1,1)       = FPR(m,d); %#ok<SAGROW>
        rowAUROC(end+1,1)     = AUROC(m,d); %#ok<SAGROW>
        rowBalancedAccuracy(end+1,1) = BalancedAccuracy(m,d); %#ok<SAGROW>
        rowAUPRC(end+1,1) = AUPRC(m,d); %#ok<SAGROW>
        rowThreshold(end+1,1) = Threshold(m,d); %#ok<SAGROW>
    end
end

DatasetWiseTable = table( ...
    rowDataset,rowMethod,rowPrecision,rowRecall,rowF1,rowAccuracy,rowFPR, ...
    rowBalancedAccuracy,rowAUROC,rowAUPRC,rowThreshold, ...
    'VariableNames',{ ...
    'Dataset','Method','Precision','Recall','F1','Accuracy','FPR', ...
    'BalancedAccuracy','AUROC','AUPRC','Threshold'});

fprintf('\n============================================================\n');
fprintf('TABLE A: DATASET-WISE DETECTION\n');
fprintf('============================================================\n');
disp(DatasetWiseTable);

writetable(DatasetWiseTable,'RealDataV15_DatasetWise_Detection_AllSeeds.csv');


AttackRows = {};
MacroRows = {};

for d = 1:nD

    name = datasets{d};
    D = Data.(name);

    if isempty(D.AttackType)
        continue;
    end

    [trainIdx,testIdx] = buildNormalTrainTestSplitV3(D.Y,cfg);

    XtrainRaw = D.X(trainIdx,:);
    XtestRaw  = D.X(testIdx,:);
    Ytest     = D.Y(testIdx);
    Atest     = D.AttackType(testIdx);

    prep = fitPreprocessor(XtrainRaw);
    Xtrain = applyPreprocessor(XtrainRaw,prep);
    Xtest  = applyPreprocessor(XtestRaw,prep);

    detector = trainCausalHealDetector(Xtrain,cfg,D.TemporalInfo);
    [scores,~] = scoreCausalHealDetector(detector,Xtrain,Xtest,cfg);

    fullTrain = scores.train{5};
    fullTest  = scores.test{5};

    threshold = median(fullTrain) + ...
        cfg.thresholdK*robustMAD(fullTrain);

    pred = fullTest > threshold;

    attackClasses = unique(string(Atest));

    validRecalls=[];

    for c = 1:numel(attackClasses)

        attackName = attackClasses(c);

        if isBenignLabel(attackName)
            continue;
        end

        idx = string(Atest)==attackName;

        if sum(idx)<10
            continue;
        end

        attackRecall = sum(pred(idx)==1)/(sum(idx)+eps);
        meanScore = mean(fullTest(idx),'omitnan');

        validRecalls(end+1,1)=attackRecall; %#ok<AGROW>

        AttackRows(end+1,:) = { ...
            name,char(attackName),sum(idx),attackRecall,meanScore}; %#ok<SAGROW>
    end

    if ~isempty(validRecalls)
        MacroRows(end+1,:)={ ...
            name,mean(validRecalls),median(validRecalls), ...
            min(validRecalls),max(validRecalls),numel(validRecalls)}; %#ok<SAGROW>
    end
end

if isempty(AttackRows)
    AttackTypeTable = table();
else
    AttackTypeTable = cell2table(AttackRows, ...
        'VariableNames',{ ...
        'Dataset','AttackType','Samples','DetectionRecall','MeanAnomalyScore'});
end

fprintf('\n============================================================\n');
fprintf('TABLE B: ATTACK-TYPE ROBUSTNESS\n');
fprintf('============================================================\n');
disp(AttackTypeTable);

writetable(AttackTypeTable,'RealDataV15_AttackType_Robustness_AllSeeds.csv');

if isempty(MacroRows)
    AttackMacroTable = table();
else
    AttackMacroTable = cell2table(MacroRows, ...
        'VariableNames',{ ...
        'Dataset','MacroAttackRecall','MedianAttackRecall', ...
        'MinAttackRecall','MaxAttackRecall','AttackFamilies'});
end

fprintf('\n============================================================\n');
fprintf('TABLE B2: MACRO ATTACK-FAMILY ROBUSTNESS\n');
fprintf('============================================================\n');
disp(AttackMacroTable);

writetable(AttackMacroTable,'RealDataV15_AttackFamily_Macro_AllSeeds.csv');

GeneralizationRows = {};
SemanticMapRows = {};
ValidityRows = {};

for s = 1:nD

    sourceName = datasets{s};
    Src = Data.(sourceName);

    for t = 1:nD

        if t==s
            continue;
        end

        targetName = datasets{t};
        Tgt = Data.(targetName);

        fprintf('\nV14 semantic transfer: %s -> %s\n', ...
            sourceName,targetName);

        [Xs,Xt,sharedNames,mapInfo] = ...
            buildPairwiseDerivedSemanticMatrices(Src,Tgt,cfg);

        fprintf('  shared harmonized features (%d): %s\n', ...
            numel(sharedNames),strjoin(sharedNames,', '));

        for k=1:numel(sharedNames)
            SemanticMapRows(end+1,:)={ ...
                sourceName,targetName,sharedNames{k}, ...
                mapInfo.FeatureType{k}, ...
                mapInfo.SourceFeature{k},mapInfo.TargetFeature{k}}; %#ok<SAGROW>
        end

        if numel(sharedNames)<cfg.semanticMinShared
            fprintf('  skipped: fewer than %d shared harmonized features.\n', ...
                cfg.semanticMinShared);
            continue;
        end


        srcBenign=find(Src.Y==0);

        if numel(srcBenign)>cfg.semanticMaxSourceBenign
            ids=randperm(numel(srcBenign),cfg.semanticMaxSourceBenign);
            srcBenign=srcBenign(ids);
        end

        XsrcRaw=Xs(srcBenign,:);

     
        allTarget=(1:size(Xt,1))';
        nCal=min(numel(allTarget),cfg.targetUnlabeledCalibMax);

        calibPick=randperm(numel(allTarget),nCal);
        calibIdx=allTarget(calibPick);

        remainingMask=true(numel(allTarget),1);
        remainingMask(calibPick)=false;
        remainingIdx=allTarget(remainingMask);

        XcalRaw=Xt(calibIdx,:);

        if size(XcalRaw,1)<cfg.minTargetCalibScores
            fprintf('  skipped: insufficient unlabeled target calibration rows.\n');
            continue;
        end

        % --------------------------------------------------------------
        % Held-out balanced target evaluation set.
        % Labels are used only for final metrics.
        % --------------------------------------------------------------
        targetNormal=remainingIdx(Tgt.Y(remainingIdx)==0);
        targetAttack=remainingIdx(Tgt.Y(remainingIdx)==1);

        nEval=min([numel(targetNormal),numel(targetAttack), ...
            cfg.semanticMaxTargetPerClass]);

        if nEval<10
            fprintf('  skipped: insufficient held-out target classes.\n');
            continue;
        end

        normalEval=targetNormal(randperm(numel(targetNormal),nEval));
        attackEval=targetAttack(randperm(numel(targetAttack),nEval));
        evalIdx=sort([normalEval;attackEval]);

        XevalRaw=Xt(evalIdx,:);
        Yeval=Tgt.Y(evalIdx);

        srcPrep=fitPreprocessor(XsrcRaw);

        Xsrc=applyPreprocessor(XsrcRaw,srcPrep);
        Xcal=applyPreprocessor(XcalRaw,srcPrep);
        Xeval=applyPreprocessor(XevalRaw,srcPrep);

        srcModel=trainSemanticOneClass(Xsrc,cfg);
        srcScore=semanticOneClassScore(srcModel,Xsrc);

        sourceThreshold=median(srcScore)+ ...
            cfg.semanticThresholdK*robustMAD(srcScore);

        sourceScoreMedian=median(srcScore);
        sourceScoreMAD=robustMAD(srcScore);

        if sourceScoreMAD<1e-12
            sourceScoreMAD=1e-12;
        end

        % --------------------------------------------------------------
        % Baselines: SourceOnly, RobustLocationScale, RawCORAL
        % --------------------------------------------------------------
        baselineModes={'SourceOnly','RobustLocationScale','RawCORAL'};

        for bm=1:numel(baselineModes)

            mode=baselineModes{bm};

            switch mode

                case 'SourceOnly'
                    XcalAligned=Xcal;
                    XevalAligned=Xeval;
                    alignmentCondition=1;

                case 'RobustLocationScale'
                    alignModel=fitRobustLocationScaleAlignment(Xsrc,Xcal,cfg);
                    XcalAligned=applyRobustLocationScaleAlignment( ...
                        Xcal,alignModel);
                    XevalAligned=applyRobustLocationScaleAlignment( ...
                        Xeval,alignModel);

                    alignmentCondition=max(alignModel.scaleRatio) / ...
                        max(min(alignModel.scaleRatio),eps);

                case 'RawCORAL'
                    alignModel=fitCORALAlignment(Xsrc,Xcal,cfg);
                    XcalAligned=applyCORALAlignment(Xcal,alignModel);
                    XevalAligned=applyCORALAlignment(Xeval,alignModel);
                    alignmentCondition=alignModel.conditionNumber;
            end

            [diagResult,calibScore,evalScore] = ...
                evaluateTransferValidityAndScores( ...
                Xsrc,XcalAligned,XevalAligned,srcModel,srcScore, ...
                sourceThreshold,sourceScoreMedian,sourceScoreMAD, ...
                alignmentCondition,cfg);

            fprintf(['  %s validity: support=%d | alarm=%.4f | ', ...
                'spread=%.4g | coreShift=%.4g | coreScale=%.4g | ', ...
                'cond=%.4g\n'], ...
                mode,diagResult.TransferSupported, ...
                diagResult.SourceThresholdAlarmRate, ...
                diagResult.ScoreSpreadRatio, ...
                diagResult.CoreMedianShiftMAD, ...
                diagResult.CoreScaleRatio, ...
                diagResult.AlignmentCondition);

            ValidityRows(end+1,:)={ ...
                sourceName,targetName,mode,NaN,false, ...
                numel(sharedNames), ...
                diagResult.SourceThresholdAlarmRate, ...
                diagResult.ScoreSpreadRatio, ...
                diagResult.CoreMedianShiftMAD, ...
                diagResult.CoreScaleRatio, ...
                diagResult.AlignmentCondition, ...
                diagResult.AlarmGate,diagResult.SpreadGate, ...
                diagResult.CoreShiftGate,diagResult.CoreScaleGate, ...
                diagResult.ConditionGate,diagResult.TransferSupported, ...
                diagResult.AbstainReason}; %#ok<SAGROW>

            [thresholdNames,thresholdValues,coreSizes,coreAlarmRates] = ...
                buildCalibrationThresholds(calibScore,srcScore, ...
                sourceThreshold,cfg);

            auc=safeAUROC(Yeval,evalScore);
            auprc=safeAUPRC(Yeval,evalScore);

            for th=1:numel(thresholdValues)

                if ~diagResult.TransferSupported
                    p=NaN; r=NaN; f=NaN; a=NaN; fpr=NaN; bacc=NaN;
                    abstained=true;
                else
                    pred=evalScore>thresholdValues(th);
                    [p,r,f,a,fpr,bacc]=classificationMetricsV3(Yeval,pred);
                    abstained=false;
                end

                GeneralizationRows(end+1,:)={ ...
                    sourceName,targetName,mode,NaN,false, ...
                    thresholdNames{th}, ...
                    numel(sharedNames),strjoin(sharedNames,' | '), ...
                    diagResult.TransferSupported,abstained, ...
                    diagResult.AbstainReason, ...
                    p,r,f,a,fpr,bacc,auc,auprc,thresholdValues(th), ...
                    diagResult.SourceThresholdAlarmRate, ...
                    coreAlarmRates(th),coreSizes(th), ...
                    diagResult.ScoreSpreadRatio, ...
                    diagResult.CoreMedianShiftMAD, ...
                    diagResult.CoreScaleRatio, ...
                    diagResult.AlignmentCondition, ...
                    diagResult.AlarmGate,diagResult.SpreadGate, ...
                    diagResult.CoreShiftGate,diagResult.CoreScaleGate, ...
                    diagResult.ConditionGate}; %#ok<SAGROW>
            end
        end

        selectedKappa=NaN;
        selectedDiag=[];
        selectedCalibScore=[];
        selectedEvalScore=[];

        for kk=1:numel(cfg.spectralKappaGrid)

            kappaMax=cfg.spectralKappaGrid(kk);

            alignModel=fitSpectralClippedCORALAlignment( ...
                Xsrc,Xcal,cfg,kappaMax);

            XcalAligned=applyCORALAlignment(Xcal,alignModel);
            XevalAligned=applyCORALAlignment(Xeval,alignModel);

            [diagResult,calibScore,evalScore] = ...
                evaluateTransferValidityAndScores( ...
                Xsrc,XcalAligned,XevalAligned,srcModel,srcScore, ...
                sourceThreshold,sourceScoreMedian,sourceScoreMAD, ...
                alignModel.conditionNumber,cfg);

            fprintf(['  SpectralCORAL kappa=%.0e: support=%d | ', ...
                'alarm=%.4f | spread=%.4g | coreShift=%.4g | ', ...
                'coreScale=%.4g | cond=%.4g | clipped=%d/%d\n'], ...
                kappaMax,diagResult.TransferSupported, ...
                diagResult.SourceThresholdAlarmRate, ...
                diagResult.ScoreSpreadRatio, ...
                diagResult.CoreMedianShiftMAD, ...
                diagResult.CoreScaleRatio, ...
                diagResult.AlignmentCondition, ...
                alignModel.totalClippedEigenvalues, ...
                2*size(Xsrc,2));

            isSelected=false;

            if isnan(selectedKappa) && diagResult.TransferSupported
                selectedKappa=kappaMax;
                selectedDiag=diagResult;
                selectedCalibScore=calibScore;
                selectedEvalScore=evalScore;
                isSelected=true;
            end

            ValidityRows(end+1,:)={ ...
                sourceName,targetName,'SpectralCORAL',kappaMax,isSelected, ...
                numel(sharedNames), ...
                diagResult.SourceThresholdAlarmRate, ...
                diagResult.ScoreSpreadRatio, ...
                diagResult.CoreMedianShiftMAD, ...
                diagResult.CoreScaleRatio, ...
                diagResult.AlignmentCondition, ...
                diagResult.AlarmGate,diagResult.SpreadGate, ...
                diagResult.CoreShiftGate,diagResult.CoreScaleGate, ...
                diagResult.ConditionGate,diagResult.TransferSupported, ...
                diagResult.AbstainReason}; %#ok<SAGROW>
        end


        if isnan(selectedKappa)

            fprintf('  SpectralCORAL selection: NO VALID kappa -> abstain.\n');

            thresholdNames={ ...
                'SourceThreshold', ...
                'FullUnlabeledRobustTail', ...
                'PseudoNormalCore50', ...
                'PseudoNormalCore60', ...
                'IterativeTrimmedCore'};

            for th=1:numel(thresholdNames)

                GeneralizationRows(end+1,:)={ ...
                    sourceName,targetName,'SpectralCORAL',NaN,true, ...
                    thresholdNames{th}, ...
                    numel(sharedNames),strjoin(sharedNames,' | '), ...
                    false,true,'NoSpectralKappaPassedValidity', ...
                    NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN, ...
                    NaN,NaN,NaN,NaN,NaN,NaN,NaN, ...
                    false,false,false,false,false}; %#ok<SAGROW>
            end

        else

            fprintf('  SpectralCORAL selected kappa=%.0e\n',selectedKappa);

            [thresholdNames,thresholdValues,coreSizes,coreAlarmRates] = ...
                buildCalibrationThresholds(selectedCalibScore,srcScore, ...
                sourceThreshold,cfg);

            auc=safeAUROC(Yeval,selectedEvalScore);
            auprc=safeAUPRC(Yeval,selectedEvalScore);

            for th=1:numel(thresholdValues)

                pred=selectedEvalScore>thresholdValues(th);
                [p,r,f,a,fpr,bacc]=classificationMetricsV3(Yeval,pred);

                GeneralizationRows(end+1,:)={ ...
                    sourceName,targetName,'SpectralCORAL', ...
                    selectedKappa,true,thresholdNames{th}, ...
                    numel(sharedNames),strjoin(sharedNames,' | '), ...
                    true,false,'', ...
                    p,r,f,a,fpr,bacc,auc,auprc,thresholdValues(th), ...
                    selectedDiag.SourceThresholdAlarmRate, ...
                    coreAlarmRates(th),coreSizes(th), ...
                    selectedDiag.ScoreSpreadRatio, ...
                    selectedDiag.CoreMedianShiftMAD, ...
                    selectedDiag.CoreScaleRatio, ...
                    selectedDiag.AlignmentCondition, ...
                    selectedDiag.AlarmGate,selectedDiag.SpreadGate, ...
                    selectedDiag.CoreShiftGate,selectedDiag.CoreScaleGate, ...
                    selectedDiag.ConditionGate}; %#ok<SAGROW>
            end
        end
    end
end

% -------------------------------------------------------------------------
% Cross-dataset output table
% -------------------------------------------------------------------------
if isempty(GeneralizationRows)

    CrossDatasetTable = table( ...
        strings(0,1),strings(0,1),strings(0,1),zeros(0,1),false(0,1), ...
        strings(0,1),zeros(0,1),strings(0,1), ...
        false(0,1),false(0,1),strings(0,1), ...
        zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),false(0,1),false(0,1),false(0,1),false(0,1), ...
        false(0,1), ...
        'VariableNames',{ ...
        'TrainDataset','TestDataset','AlignmentMode','SpectralKappa', ...
        'ValiditySelected','CalibrationMode', ...
        'SharedFeatureCount','SharedFeatures', ...
        'TransferSupported','Abstained','AbstainReason', ...
        'Precision','Recall','F1','Accuracy','FPR','BalancedAccuracy', ...
        'AUROC','AUPRC','Threshold', ...
        'SourceThresholdAlarmRate','CalibrationAlarmRate', ...
        'PseudoNormalCoreSize','ScoreSpreadRatio', ...
        'CoreMedianShiftMAD','CoreScaleRatio','AlignmentCondition', ...
        'AlarmGate','SpreadGate','CoreShiftGate','CoreScaleGate', ...
        'ConditionGate'});

else

    CrossDatasetTable=cell2table(GeneralizationRows, ...
        'VariableNames',{ ...
        'TrainDataset','TestDataset','AlignmentMode','SpectralKappa', ...
        'ValiditySelected','CalibrationMode', ...
        'SharedFeatureCount','SharedFeatures', ...
        'TransferSupported','Abstained','AbstainReason', ...
        'Precision','Recall','F1','Accuracy','FPR','BalancedAccuracy', ...
        'AUROC','AUPRC','Threshold', ...
        'SourceThresholdAlarmRate','CalibrationAlarmRate', ...
        'PseudoNormalCoreSize','ScoreSpreadRatio', ...
        'CoreMedianShiftMAD','CoreScaleRatio','AlignmentCondition', ...
        'AlarmGate','SpreadGate','CoreShiftGate','CoreScaleGate', ...
        'ConditionGate'});
end

% -------------------------------------------------------------------------
% Semantic mapping table
% -------------------------------------------------------------------------
if isempty(SemanticMapRows)

    SemanticMapTable=table( ...
        strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
        strings(0,1),strings(0,1), ...
        'VariableNames',{ ...
        'TrainDataset','TestDataset','CanonicalFeature','FeatureType', ...
        'SourceFeature','TargetFeature'});
else

    SemanticMapTable=cell2table(SemanticMapRows, ...
        'VariableNames',{ ...
        'TrainDataset','TestDataset','CanonicalFeature','FeatureType', ...
        'SourceFeature','TargetFeature'});
end

% -------------------------------------------------------------------------
% Transfer validity table
% -------------------------------------------------------------------------
if isempty(ValidityRows)

    TransferValidityTable=table( ...
        strings(0,1),strings(0,1),strings(0,1),zeros(0,1),false(0,1), ...
        zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        false(0,1),false(0,1),false(0,1),false(0,1),false(0,1), ...
        false(0,1),strings(0,1), ...
        'VariableNames',{ ...
        'TrainDataset','TestDataset','AlignmentMode','SpectralKappa', ...
        'ValiditySelected','SharedFeatureCount', ...
        'SourceThresholdAlarmRate','ScoreSpreadRatio', ...
        'CoreMedianShiftMAD','CoreScaleRatio','AlignmentCondition', ...
        'AlarmGate','SpreadGate','CoreShiftGate','CoreScaleGate', ...
        'ConditionGate','TransferSupported','AbstainReason'});
else

    TransferValidityTable=cell2table(ValidityRows, ...
        'VariableNames',{ ...
        'TrainDataset','TestDataset','AlignmentMode','SpectralKappa', ...
        'ValiditySelected','SharedFeatureCount', ...
        'SourceThresholdAlarmRate','ScoreSpreadRatio', ...
        'CoreMedianShiftMAD','CoreScaleRatio','AlignmentCondition', ...
        'AlarmGate','SpreadGate','CoreShiftGate','CoreScaleGate', ...
        'ConditionGate','TransferSupported','AbstainReason'});
end

fprintf('\n============================================================\n');
fprintf('TABLE C: SPECTRAL-CORAL CROSS-DATASET GENERALIZATION\n');
fprintf('============================================================\n');
disp(CrossDatasetTable);

fprintf('\n============================================================\n');
fprintf('TABLE D: SPECTRAL-CORAL VALIDITY DIAGNOSTICS\n');
fprintf('============================================================\n');
disp(TransferValidityTable);

writetable(CrossDatasetTable, sprintf('RealDataV15_Seed%03d_SpectralCORAL_CrossDataset.csv',seedRun));

writetable(TransferValidityTable, sprintf('RealDataV15_Seed%03d_TransferValidity.csv',seedRun));

if seedRun==cfg.reproSeeds(1), writetable(SemanticMapTable,'RealDataV15_DerivedSemantic_Feature_Mapping.csv'); end

%% ------------------------------------------------------------------------
% 7. FEATURE SUMMARY
% -------------------------------------------------------------------------
FeatureRows = cell(nD,8);

for d = 1:nD
    name = datasets{d};
    D = Data.(name);

    FeatureRows{d,1} = name;
    FeatureRows{d,2} = size(D.X,1);
    FeatureRows{d,3} = size(D.X,2);
    FeatureRows{d,4} = sum(D.Y==0);
    FeatureRows{d,5} = sum(D.Y==1);
    FeatureRows{d,6} = D.TemporalInfo.available;
    FeatureRows{d,7} = D.TemporalInfo.variable;

    if isfield(D,'SourceFiles')
        FeatureRows{d,8} = strjoin(string(D.SourceFiles),' | ');
    else
        FeatureRows{d,8} = "";
    end
end

FeatureSummary = cell2table(FeatureRows, ...
    'VariableNames',{'Dataset','Rows','Features','Benign','Attack', ...
    'TemporalAvailable','TemporalVariable','SourceFiles'});

writetable(FeatureSummary,'RealDataV15_FeatureSummary.csv');

fullIdx = 5;

figure('Name','Real Data Full Detector F1');
bar(F1(fullIdx,:));
set(gca,'XTick',1:nD,'XTickLabel',datasets);
ylabel('F1 Score');
ylim([0 1]);
grid on;
title('CausalHeal Full Detector Across Public Datasets');

% Detection ablation
figure('Name','Real Data Detection Ablation');

if nD==1
    bar(F1(:,1));
    set(gca,'XTick',1:nM,'XTickLabel',methods);
    xtickangle(30);
    xlabel('Method');
    ylabel('F1 Score');
    ylim([0 1]);
    grid on;
    title(['Detection Ablation - ',datasets{1}]);
else
    bar(F1');
    set(gca,'XTick',1:nD,'XTickLabel',datasets);
    ylabel('F1 Score');
    ylim([0 1]);
    legend(methods,'Location','bestoutside');
    grid on;
    title('Dataset-wise Detection Ablation');
end

% V14 fixed operating-point cross-dataset F1 matrix
% Uses validity-selected SpectralCORAL + predeclared primary calibration.
CrossF1 = nan(nD,nD);

if height(CrossDatasetTable)>0

    for s=1:nD
        for t=1:nD

            if s==t
                continue;
            end

            idx=strcmp(string(CrossDatasetTable.TrainDataset),datasets{s}) & ...
                strcmp(string(CrossDatasetTable.TestDataset),datasets{t}) & ...
                strcmp(string(CrossDatasetTable.AlignmentMode),'SpectralCORAL') & ...
                CrossDatasetTable.ValiditySelected & ...
                strcmp(string(CrossDatasetTable.CalibrationMode), ...
                    cfg.primaryCalibrationMode) & ...
                CrossDatasetTable.TransferSupported;

            if any(idx)
                CrossF1(s,t)=CrossDatasetTable.F1(find(idx,1));
            end
        end
    end

    figure('Name','V14 Spectral-CORAL Cross-Dataset Generalization');
    imagesc(CrossF1);
    colorbar;
    caxis([0 1]);
    set(gca,'XTick',1:nD,'XTickLabel',datasets);
    set(gca,'YTick',1:nD,'YTickLabel',datasets);
    xlabel('Test Dataset');
    ylabel('Train Dataset');
    title('Validity-Selected Spectral CORAL F1');
end

%% ------------------------------------------------------------------------
% 9. SAVE
% -------------------------------------------------------------------------
save(sprintf('CausalHeal_RealData_V15_Seed%03d.mat',seedRun), ...
    'cfg','datasets','methods','Data','models', ...
    'Precision','Recall','F1','Accuracy','FPR','BalancedAccuracy','AUROC','AUPRC','Threshold', ...
    'DatasetWiseTable','AttackTypeTable','AttackMacroTable', ...
    'CrossDatasetTable','TransferValidityTable','SemanticMapTable','FeatureSummary');

fprintf('\nFiles written:\n');
fprintf('  RealDataV15_DatasetWise_Detection_AllSeeds.csv\n');
fprintf('  RealDataV15_SpectralCORAL_CrossDataset_AllSeeds.csv\n');
fprintf('  RealDataV15_DerivedSemantic_Feature_Mapping.csv\n');
fprintf('  RealDataV15_AttackType_Robustness_AllSeeds.csv\n');
fprintf('  RealDataV15_AttackFamily_Macro_AllSeeds.csv\n');
fprintf('  RealDataV15_FeatureSummary.csv\n');
fprintf('  CausalHeal_RealData_V15_Results.mat\n\n');

fprintf('Real-data benchmark completed.\n');
fprintf('\nV15 seed note: frozen V14 algorithm is being rerun for reproducibility.\n');
fprintf('Fixed kappa caps are 1e6, 1e5, 1e4 and 1e3, ordered least to most aggressive.\n');
fprintf('Only pathological eigenvalues are raised; well-conditioned directions are preserved.\n');
fprintf('The least aggressive kappa passing all label-free validity gates is selected.\n');
fprintf('Target attack labels are never used for conditioning selection, alignment or calibration.\n');
fprintf('If no spectral cap passes validity, the transfer abstains.\n');
fprintf('Primary operating point: validity-selected SpectralCORAL + IterativeTrimmedCore.\n');
fprintf('V14 is the final algorithmic public-data transfer version; further work should use frozen multi-seed evaluation.\n');
fprintf('Literal cross-plane causal RCA/remediation remain evaluated in the synchronized synthetic/testbed benchmark.\n');


R.DatasetWiseTable=DatasetWiseTable;
R.AttackTypeTable=AttackTypeTable;
R.AttackMacroTable=AttackMacroTable;
R.CrossDatasetTable=CrossDatasetTable;
R.TransferValidityTable=TransferValidityTable;

end

function Summary=aggregateMetricTable(T,groupVars,metricVars,z)

if height(T)==0
    Summary=table();
    return;
end

% MATLAB-compatible grouping: findgroups(table) returns one grouping vector.
G=findgroups(T(:,groupVars));

validG=G(isfinite(G));
if isempty(validG)
    Summary=table();
    return;
end

groupIDs=unique(validG(:))';
rows={};

for g=groupIDs

    idx=(G==g);
    first=find(idx,1);

    base=cell(1,numel(groupVars));

    for j=1:numel(groupVars)
        v=T.(groupVars{j});

        if iscell(v)
            base{j}=v{first};
        elseif isstring(v)
            base{j}=char(v(first));
        elseif iscategorical(v)
            base{j}=char(string(v(first)));
        else
            base{j}=v(first);
        end
    end

    row=base;

    for j=1:numel(metricVars)

        x=T.(metricVars{j})(idx);
        x=x(isfinite(x));

        if isempty(x)
            mu=NaN; sd=NaN; lo=NaN; hi=NaN; n=0;
        else
            n=numel(x);
            mu=mean(x);

            if n>1
                sd=std(x,0);
                se=sd/sqrt(n);
                lo=mu-z*se;
                hi=mu+z*se;
            else
                sd=0;
                lo=mu;
                hi=mu;
            end
        end

        row=[row,{mu,sd,lo,hi,n}]; %#ok<AGROW>
    end

    rows(end+1,:)=row; %#ok<AGROW>
end

varNames=groupVars;

for j=1:numel(metricVars)
    m=metricVars{j};
    varNames=[varNames,{[m '_Mean'],[m '_Std'], ...
        [m '_CI95_Low'],[m '_CI95_High'],[m '_N']}]; %#ok<AGROW>
end

Summary=cell2table(rows,'VariableNames',varNames);
end

function V=aggregateValidityFrequency(T)

if height(T)==0
    V=table();
    return;
end

groupVars={'TrainDataset','TestDataset','AlignmentMode'};

% Include kappa if available because spectral validity depends on it.
if ismember('SpectralKappa',T.Properties.VariableNames)
    groupVars{end+1}='SpectralKappa';
end

G=findgroups(T(:,groupVars));
validG=G(isfinite(G));

if isempty(validG)
    V=table();
    return;
end

groupIDs=unique(validG(:))';
rows={};

for g=groupIDs

    idx=(G==g);
    first=find(idx,1);

    row=cell(1,numel(groupVars));

    for j=1:numel(groupVars)
        v=T.(groupVars{j});
        if iscell(v)
            row{j}=v{first};
        elseif isstring(v) || iscategorical(v)
            row{j}=string(v(first));
        else
            row{j}=v(first);
        end
    end

    support=logical(T.TransferSupported(idx));
    n=numel(support);
    pass=sum(support);
    freq=pass/max(n,1);

    alarm=mean(logical(T.AlarmGate(idx)));
    spread=mean(logical(T.SpreadGate(idx)));
    shift=mean(logical(T.CoreShiftGate(idx)));
    scale=mean(logical(T.CoreScaleGate(idx)));
    condg=mean(logical(T.ConditionGate(idx)));

    row=[row,{n,pass,freq,1-freq,alarm,spread,shift,scale,condg}]; %#ok<AGROW>
    rows(end+1,:)=row; %#ok<AGROW>
end

names=[groupVars,{ ...
    'Runs','ValidityPasses','ValidityPassFrequency', ...
    'AbstentionFrequency','AlarmGatePassFrequency', ...
    'SpreadGatePassFrequency','CoreShiftGatePassFrequency', ...
    'CoreScaleGatePassFrequency','ConditionGatePassFrequency'}];

V=cell2table(rows,'VariableNames',names);
end

function S=aggregatePrimaryPolicy(T,z)

if height(T)==0
    S=table();
    return;
end

pairs=unique(T(:,{'TrainDataset','TestDataset'}),'rows');
rows={};

for i=1:height(pairs)

    src=pairs.TrainDataset(i);
    tgt=pairs.TestDataset(i);

    idx=strcmp(string(T.TrainDataset),string(src)) & ...
        strcmp(string(T.TestDataset),string(tgt));

    Ti=T(idx,:);

    supported=logical(Ti.TransferSupported);
    n=numel(supported);
    pass=sum(supported);
    passFreq=pass/max(n,1);

    f1=Ti.F1(supported & isfinite(Ti.F1));
    bacc=Ti.BalancedAccuracy(supported & isfinite(Ti.BalancedAccuracy));
    auc=Ti.AUROC(supported & isfinite(Ti.AUROC));
    auprc=Ti.AUPRC(supported & isfinite(Ti.AUPRC));

    [f1m,f1s,f1lo,f1hi]=meanCI(f1,z);
    [bm,bs,blo,bhi]=meanCI(bacc,z);
    [am,as,alo,ahi]=meanCI(auc,z);
    [pm,ps,plo,phi]=meanCI(auprc,z);

    rows(end+1,:)={ ...
        char(string(src)),char(string(tgt)),n,pass,passFreq,1-passFreq, ...
        f1m,f1s,f1lo,f1hi,bm,bs,blo,bhi, ...
        am,as,alo,ahi,pm,ps,plo,phi}; %#ok<AGROW>
end

S=cell2table(rows,'VariableNames',{ ...
    'TrainDataset','TestDataset','Runs','SupportedRuns', ...
    'ValidityPassFrequency','AbstentionFrequency', ...
    'F1_Mean','F1_Std','F1_CI95_Low','F1_CI95_High', ...
    'BalancedAccuracy_Mean','BalancedAccuracy_Std', ...
    'BalancedAccuracy_CI95_Low','BalancedAccuracy_CI95_High', ...
    'AUROC_Mean','AUROC_Std','AUROC_CI95_Low','AUROC_CI95_High', ...
    'AUPRC_Mean','AUPRC_Std','AUPRC_CI95_Low','AUPRC_CI95_High'});
end

function [mu,sd,lo,hi]=meanCI(x,z)

x=x(isfinite(x));

if isempty(x)
    mu=NaN; sd=NaN; lo=NaN; hi=NaN;
elseif numel(x)==1
    mu=x(1); sd=0; lo=mu; hi=mu;
else
    mu=mean(x);
    sd=std(x,0);
    se=sd/sqrt(numel(x));
    lo=mu-z*se;
    hi=mu+z*se;
end
end

function D = loadCICIoT2023(folder,cfg)

files = listCSVFiles(folder);

if isempty(files)
    error(['No CICIoT2023 CSV files found in: ',folder]);
end

% CICIoT2023 releases may be split across many CSV files. Reading files
% sequentially until maxRows is reached can accidentally select only attack
% files. Sample approximately evenly across files instead.
T = readAndMergeCSVBalanced(files,cfg.maxRowsPerDataset);

labelCandidates = {'label','Label','Attack','attack','Attack_type','attack_type'};
attackTypeCandidates = {'label','Label','Attack_type','attack_type'};

[D.X,D.Y,D.AttackType,D.FeatureNames] = ...
    convertTableToDataset(T,labelCandidates,attackTypeCandidates,'CICIoT2023');

D.TemporalInfo = detectTemporalInfo(T);

% Diagnostics
fprintf('  CICIoT23 unique raw attack labels (first 20):\n');
u = unique(string(D.AttackType));
disp(u(1:min(20,numel(u))));
end

function D = loadToNIoTV6(file,cfg)

if ~isfile(file)
    error(['No ToN_IoT CSV file found: ',file]);
end

if cfg.printSchema
    inspectCSVSchema(file,cfg,'ToN_IoT');
end

T=readSingleCSVSampled(file,cfg.maxRowsPerDataset);

% ToN_IoT network dataset commonly uses:
%   label : binary 0=normal, 1=attack
%   type  : multiclass attack family
labelCandidates={'label','Label'};
attackTypeCandidates={'type','Type'};

[D.X,D.Y,D.AttackType,D.FeatureNames] = ...
    convertTableToDataset(T,labelCandidates,attackTypeCandidates,'ToN_IoT');

D.TemporalInfo=detectTemporalInfo(T);
D.SourceFiles={file};
end

function D = loadEdgeIIoTV6(files,cfg)

existing=files(cellfun(@isfile,files));

if isempty(existing)
    error('No supplied Edge-IIoTset CSV files were found.');
end

priorityNames={ ...
    cfg.edgePreferredFile, ...
    'ML-EdgeIIoT-dataset.csv', ...
    'train_test_network.csv', ...
    'live_data_training.csv'};

ordered={};

for p=1:numel(priorityNames)
    for i=1:numel(existing)
        [~,nm,ex]=fileparts(existing{i});
        if strcmpi([nm ex],priorityNames{p})
            ordered{end+1}=existing{i}; %#ok<AGROW>
        end
    end
end

% Add any remaining files not already listed.
for i=1:numel(existing)
    if ~any(strcmpi(existing{i},ordered))
        ordered{end+1}=existing{i}; %#ok<AGROW>
    end
end

selected='';
selectedTable=[];
selectedLabelCandidates={};
selectedTypeCandidates={};

for i=1:numel(ordered)

    candidate=ordered{i};

    fprintf('\n  Edge-IIoT candidate file: %s\n',candidate);

    if cfg.printSchema
        inspectCSVSchema(candidate,cfg,'Edge-IIoTset candidate');
    end

    try
        Tcandidate=readSingleCSVSampled(candidate,cfg.maxRowsPerDataset);
    catch ME
        fprintf('  -> rejected: read failure: %s\n',ME.message);
        continue;
    end

    vars=Tcandidate.Properties.VariableNames;

    labelCandidates={'Attack_label','attack_label','Label','label'};
    attackTypeCandidates={'Attack_type','attack_type','Type','type'};

    labelVar=findFirstVariable(vars,labelCandidates);

    if isempty(labelVar)
        fprintf('  -> rejected: no recognized binary label column.\n');
        continue;
    end

    % Basic sanity check: need both benign and attack labels.
    try
        yCandidate=labelToBinary(Tcandidate.(labelVar));
    catch
        fprintf('  -> rejected: label column could not be converted.\n');
        continue;
    end

    if numel(unique(yCandidate))<2
        fprintf('  -> rejected: label column contains only one class.\n');
        continue;
    end

    selected=candidate;
    selectedTable=Tcandidate;
    selectedLabelCandidates=labelCandidates;
    selectedTypeCandidates=attackTypeCandidates;

    fprintf('  -> selected as canonical Edge-IIoT evaluation file.\n');
    break;
end

if isempty(selected)
    error(['None of the supplied Edge-IIoTset files exposed a usable ', ...
           'binary label column. Check delimiter/file format.']);
end

if numel(existing)>1
    fprintf('  Edge-IIoT note: only ONE labeled release is used to avoid overlap/leakage.\n');
end

[D.X,D.Y,D.AttackType,D.FeatureNames] = ...
    convertTableToDataset( ...
    selectedTable,selectedLabelCandidates,selectedTypeCandidates,'Edge-IIoTset');

% Treat Edge-IIoT public CSV as static unless a validated, preserved
% chronological sequence is explicitly established.
D.TemporalInfo.available=false;
D.TemporalInfo.variable='';
D.TemporalInfo.reason='Static public-table evaluation';
D.SourceFiles={selected};
end

function D = loadInSDNV6(files,cfg)

existing=files(cellfun(@isfile,files));

if isempty(existing)
    error('None of the supplied InSDN CSV files were found.');
end

tables=cell(numel(existing),1);
fallbackLabels=cell(numel(existing),1);
fallbackTypes=cell(numel(existing),1);

for i=1:numel(existing)

    file=existing{i};

    if cfg.printSchema
        inspectCSVSchema(file,cfg,['InSDN ',num2str(i)]);
    end

    Ti=readSingleCSVSampled(file,ceil(cfg.maxRowsPerDataset/numel(existing)));

    vars=Ti.Properties.VariableNames;

    binaryVar=findFirstVariable(vars, ...
        {'Label','label','Attack','attack','Class','class'});

    typeVar=findFirstVariable(vars, ...
        {'Label','label','Attack','attack','Class','class','Type','type'});

    [~,base,~]=fileparts(file);
    baseLower=lower(base);

    if isempty(binaryVar)

        % Conservative filename fallback:
        % Normal_data.csv is benign. metasploitable-2.csv and OVS.csv are
        % treated as attack-source files only when no label column exists.
        if contains(baseLower,'normal')
            fallbackLabels{i}=zeros(height(Ti),1);
            fallbackTypes{i}=repmat("Normal",height(Ti),1);
        else
            fallbackLabels{i}=ones(height(Ti),1);
            fallbackTypes{i}=repmat(string(base),height(Ti),1);
        end

        Ti.('__V6_binary_label__')=fallbackLabels{i};
        Ti.('__V6_attack_type__')=fallbackTypes{i};

    else
        % Preserve existing labels.
        if isempty(typeVar)
            Ti.('__V6_attack_type__')=string(Ti.(binaryVar));
        end
    end

    tables{i}=Ti;
end

% Keep only common variables, plus generated labels where needed.
% First harmonize binary/type columns to V6 names.
for i=1:numel(tables)

    Ti=tables{i};
    vars=Ti.Properties.VariableNames;

    binaryVar=findFirstVariable(vars, ...
        {'__V6_binary_label__','Label','label','Attack','attack','Class','class'});

    typeVar=findFirstVariable(vars, ...
        {'__V6_attack_type__','Type','type','Label','label','Attack','attack','Class','class'});

    if ~strcmp(binaryVar,'__V6_binary_label__')
        Ti.('__V6_binary_label__')=labelToBinary(Ti.(binaryVar));
    end

    if ~strcmp(typeVar,'__V6_attack_type__')
        Ti.('__V6_attack_type__')=string(Ti.(typeVar));
    end

    tables{i}=Ti;
end

commonVars=tables{1}.Properties.VariableNames;

for i=2:numel(tables)
    commonVars=intersect(commonVars,tables{i}.Properties.VariableNames,'stable');
end

% Force V6 labels to remain.
commonVars=union(commonVars,{'__V6_binary_label__','__V6_attack_type__'},'stable');

for i=1:numel(tables)
    tables{i}=tables{i}(:,commonVars);
end

T=vertcat(tables{:});

if isfinite(cfg.maxRowsPerDataset) && height(T)>cfg.maxRowsPerDataset
    ids=randperm(height(T),cfg.maxRowsPerDataset);
    T=T(ids,:);
end

[D.X,D.Y,D.AttackType,D.FeatureNames] = ...
    convertTableToDataset(T, ...
    {'__V6_binary_label__'}, ...
    {'__V6_attack_type__'}, ...
    'InSDN');

% Although each InSDN file contains Timestamp, this benchmark merges
% multiple source files and samples rows. That destroys a defensible
% single-process temporal sequence, so temporal prediction is disabled.
D.TemporalInfo.available=false;
D.TemporalInfo.variable='';
D.TemporalInfo.reason='Disabled after multi-file merge/sampling';
D.SourceFiles=existing;
end

function inspectCSVSchema(file,cfg,datasetName)

fprintf('\n  Schema check: %s\n',datasetName);
fprintf('    file: %s\n',file);

try
    opts=detectImportOptions(file,'VariableNamingRule','preserve');

    vars=opts.VariableNames;
    n=min(cfg.schemaPreviewVariables,numel(vars));

    fprintf('    variables (%d total; first %d):\n',numel(vars),n);

    for j=1:n
        fprintf('      %s\n',vars{j});
    end

    labelCandidates={ ...
        'label','Label','type','Type', ...
        'Attack_label','attack_label','Attack_type','attack_type', ...
        'Attack','attack','Class','class'};

    found={};

    for j=1:numel(labelCandidates)
        idx=find(strcmpi(vars,labelCandidates{j}),1);
        if ~isempty(idx)
            found{end+1}=vars{idx}; %#ok<AGROW>
        end
    end

    if isempty(found)
        fprintf('    candidate label columns: NONE detected\n');
    else
        fprintf('    candidate label columns: %s\n',strjoin(unique(found,'stable'),', '));
    end

    if numel(vars)<=3 && all(startsWith(string(vars),"Var"))
        fprintf('    WARNING: suspicious parse (Var1/Var2/Var3 only); delimiter retry will be attempted.\n');
    end

catch ME
    fprintf('    schema inspection failed: %s\n',ME.message);
end
end

function T=readSingleCSVSampled(file,maxRows)

% First attempt: MATLAB automatic detection.
opts=detectImportOptions(file,'VariableNamingRule','preserve');
T=readtable(file,opts);

vars=T.Properties.VariableNames;
suspicious=(width(T)<=3) && all(startsWith(string(vars),"Var"));

if suspicious
    delimiters={',',';','\t','|'};

    bestT=T;
    bestWidth=width(T);

    for k=1:numel(delimiters)
        try
            o=detectImportOptions(file, ...
                'Delimiter',delimiters{k}, ...
                'VariableNamingRule','preserve');

            Tk=readtable(file,o);

            if width(Tk)>bestWidth
                bestT=Tk;
                bestWidth=width(Tk);
            end
        catch
        end
    end

    T=bestT;
end

if isfinite(maxRows) && height(T)>maxRows
    ids=randperm(height(T),maxRows);
    T=T(ids,:);
end
end

function files = listCSVFiles(folder)

if ~isfolder(folder)
    files = {};
    return;
end

f = dir(fullfile(folder,'**','*.csv'));

files = cell(numel(f),1);

for i=1:numel(f)
    files{i}=fullfile(f(i).folder,f(i).name);
end
end

function T = readAndMergeCSVBalanced(files,maxRows)

nFiles = numel(files);

if isfinite(maxRows)
    rowsPerFile = max(1,ceil(maxRows/nFiles));
else
    rowsPerFile = Inf;
end

tables = {};
rowsLoaded = 0;

for i=1:nFiles

    try
        opts = detectImportOptions(files{i}, ...
            'VariableNamingRule','preserve');

        Ti = readtable(files{i},opts);

        if isempty(Ti)
            continue;
        end

        if isfinite(rowsPerFile) && height(Ti)>rowsPerFile
            ids = randperm(height(Ti),rowsPerFile);
            Ti = Ti(ids,:);
        end

        tables{end+1,1}=Ti; %#ok<AGROW>
        rowsLoaded=rowsLoaded+height(Ti);

    catch ME
        warning('Could not read %s: %s',files{i},ME.message);
    end
end

if isempty(tables)
    error('CSV files were found, but no rows could be loaded.');
end

% Keep common variables across all successfully loaded files.
commonVars=tables{1}.Properties.VariableNames;

for i=2:numel(tables)
    commonVars=intersect(commonVars, ...
        tables{i}.Properties.VariableNames,'stable');
end

for i=1:numel(tables)
    tables{i}=tables{i}(:,commonVars);
end

T=vertcat(tables{:});

% Final cap after cross-file balancing.
if isfinite(maxRows) && height(T)>maxRows
    ids=randperm(height(T),maxRows);
    T=T(ids,:);
end
end

function T = readAndMergeCSV(files,maxRows)

tables = cell(numel(files),1);
rowsLoaded = 0;

for i=1:numel(files)

    opts = detectImportOptions(files{i}, ...
        'VariableNamingRule','preserve');

    Ti = readtable(files{i},opts);

    if isfinite(maxRows)

        remaining = maxRows-rowsLoaded;

        if remaining<=0
            break;
        end

        if height(Ti)>remaining
            ids=randperm(height(Ti),remaining);
            Ti=Ti(ids,:);
        end
    end

    tables{i}=Ti;
    rowsLoaded=rowsLoaded+height(Ti);

    if isfinite(maxRows) && rowsLoaded>=maxRows
        break;
    end
end

tables = tables(~cellfun(@isempty,tables));

if isempty(tables)
    error('CSV files were found, but no rows could be loaded.');
end

% Keep only common variables across files.
commonVars = tables{1}.Properties.VariableNames;

for i=2:numel(tables)
    commonVars = intersect(commonVars, ...
        tables{i}.Properties.VariableNames,'stable');
end

for i=1:numel(tables)
    tables{i}=tables{i}(:,commonVars);
end

T=vertcat(tables{:});
end

function [X,Y,AttackType,featureNames] = ...
    convertTableToDataset(T,labelCandidates,attackTypeCandidates,datasetName)

vars=T.Properties.VariableNames;

labelVar=findFirstVariable(vars,labelCandidates);

if isempty(labelVar)
    error('%s: Could not identify binary/attack label column.',datasetName);
end

attackTypeVar=findFirstVariable(vars,attackTypeCandidates);

labelData=T.(labelVar);

% Convert label to binary
Y=labelToBinary(labelData);

if isempty(attackTypeVar)
    AttackType=strings(height(T),1);
else
    AttackType=string(T.(attackTypeVar));
end

% Remove labels and identifier-heavy/string columns
dropVars={labelVar};

if ~isempty(attackTypeVar) && ~strcmp(attackTypeVar,labelVar)
    dropVars{end+1}=attackTypeVar;
end

identifierPatterns = { ...
    'flow id','flow_id','src ip','src_ip','dst ip','dst_ip', ...
    'timestamp','time_stamp','date','mac','payload','frame.time'};

for j=1:numel(vars)
    low=lower(vars{j});

    for p=1:numel(identifierPatterns)
        if contains(low,identifierPatterns{p})
            dropVars{end+1}=vars{j}; %#ok<AGROW>
            break;
        end
    end
end

dropVars=unique(dropVars,'stable');

featureVars=setdiff(vars,dropVars,'stable');

Xparts=[];
kept={};

for j=1:numel(featureVars)

    v=T.(featureVars{j});

    if isnumeric(v) || islogical(v)

        x=double(v);

        if all(isnan(x))
            continue;
        end

        Xparts=[Xparts x]; %#ok<AGROW>
        kept{end+1}=featureVars{j}; %#ok<AGROW>

    elseif iscategorical(v) || isstring(v) || iscellstr(v)

        % Low-cardinality categorical one-hot encoding.
        s=categorical(string(v));

        if numel(categories(s))<=20

            cats=categories(s);
            dummy=zeros(height(T),numel(cats));

            for c=1:numel(cats)
                dummy(:,c)=double(s==cats{c});
                kept{end+1}=[featureVars{j},'_',matlab.lang.makeValidName(cats{c})]; %#ok<AGROW>
            end

            Xparts=[Xparts dummy]; %#ok<AGROW>
        end
    end
end

if isempty(Xparts)
    error('%s: No usable numeric features found.',datasetName);
end

% Remove Inf
Xparts(~isfinite(Xparts))=NaN;

% Remove near-constant columns using non-missing values
validCols=true(1,size(Xparts,2));

for j=1:size(Xparts,2)
    x=Xparts(:,j);
    x=x(~isnan(x));

    if isempty(x) || std(x)<1e-12
        validCols(j)=false;
    end
end

X=Xparts(:,validCols);
featureNames=kept(validCols);

% Median fill
med=median(X,1,'omitnan');

for j=1:size(X,2)
    idx=isnan(X(:,j));

    if isnan(med(j))
        med(j)=0;
    end

    X(idx,j)=med(j);
end
end

function name=findFirstVariable(vars,candidates)

name='';

for c=1:numel(candidates)
    idx=find(strcmpi(vars,candidates{c}),1);

    if ~isempty(idx)
        name=vars{idx};
        return;
    end
end
end

function Y=labelToBinary(labelData)

if isnumeric(labelData) || islogical(labelData)

    x=double(labelData);

    u=unique(x(~isnan(x)));

    if all(ismember(u,[0 1]))
        Y=x>0;
    else
        Y=x~=0;
    end

else

    s=lower(strtrim(string(labelData)));

    benignWords=[ ...
        "normal","benign","0","normal traffic", ...
        "normal_data","normal data","none", ...
        "benigntraffic","benign traffic","benign_traffic", ...
        "normaltraffic","normal_traffic"];

    Y=ones(numel(s),1);

    for i=1:numel(benignWords)
        Y(s==benignWords(i))=0;
    end

    Y=logical(Y);
end

Y=double(Y(:));
end

function tf=isBenignLabel(x)

s=lower(strtrim(string(x)));

tf=any(s==[ ...
    "normal","benign","0","normal traffic", ...
    "normal_data","normal data","none", ...
    "benigntraffic","benign traffic","benign_traffic", ...
    "normaltraffic","normal_traffic"]);
end

function info=detectTemporalInfo(T)

info.available=false;
info.variable='';
info.reason='No validated timestamp/order field detected';

vars=T.Properties.VariableNames;

candidates={ ...
    'Timestamp','timestamp','Time','time','DateTime','datetime', ...
    'ts','frame.time_epoch','Flow Duration'};

for i=1:numel(candidates)
    idx=find(strcmpi(vars,candidates{i}),1);

    if isempty(idx)
        continue;
    end

    v=T.(vars{idx});

    % Conservative policy:
    % only accept datetime/duration or numeric monotonic timestamps.
    if isdatetime(v) || isduration(v)
        info.available=true;
        info.variable=vars{idx};
        info.reason='datetime/duration field detected';
        return;
    end

    if isnumeric(v)
        x=double(v(:));
        x=x(isfinite(x));

        if numel(x)>=100 && all(diff(x)>=0) && any(diff(x)>0)
            info.available=true;
            info.variable=vars{idx};
            info.reason='monotonic numeric time/order field detected';
            return;
        end
    end
end
end

function enabled=resolveTemporalMode(info,cfg,nRows)

switch lower(cfg.temporalPolicy)
    case 'off'
        enabled=false;

    case 'on'
        enabled=(nRows>=cfg.minTemporalRows);

    otherwise
        enabled=info.available && (nRows>=cfg.minTemporalRows);
end
end

%% ========================================================================
% SPLIT / PREPROCESSING
% ========================================================================

function [trainIdx,testIdx]=buildNormalTrainTestSplitV3(Y,cfg)

normal=find(Y==0);
attack=find(Y==1);

if isempty(normal) || isempty(attack)
    error('Both benign and attack samples are required.');
end

% Random selection is acceptable for static tabular detection, but the
% returned indices are sorted before scoring so the detector never receives
% an artificially shuffled row sequence.
normalShuffled=normal(randperm(numel(normal)));

nTrain=floor(cfg.normalTrainFraction*numel(normalShuffled));
nTrain=max(2,min(nTrain,numel(normalShuffled)-1));

trainIdx=sort(normalShuffled(1:nTrain));
remainingNormal=normalShuffled(nTrain+1:end);

if cfg.balanceEvaluation
    nEval=min([numel(remainingNormal),numel(attack),cfg.maxEvalPerClass]);

    normalEval=remainingNormal(randperm(numel(remainingNormal),nEval));
    attackEval=attack(randperm(numel(attack),nEval));

    testIdx=sort([normalEval;attackEval]);
else
    testIdx=sort([remainingNormal;attack]);
end
end

function prep=fitPreprocessor(X)

prep.median=median(X,1,'omitnan');

for j=1:size(X,2)
    if isnan(prep.median(j))
        prep.median(j)=0;
    end
end

Xf=X;

for j=1:size(X,2)
    idx=isnan(Xf(:,j));
    Xf(idx,j)=prep.median(j);
end

prep.mu=mean(Xf,1);
prep.sigma=std(Xf,[],1);
prep.sigma(prep.sigma<1e-8)=1;
end

function Xn=applyPreprocessor(X,prep)

Xn=X;

for j=1:size(X,2)
    idx=isnan(Xn(:,j));
    Xn(idx,j)=prep.median(j);
end

Xn=(Xn-prep.mu)./prep.sigma;
end

%% ========================================================================
% CAUSALHEAL DETECTOR
% ========================================================================

function detector=trainCausalHealDetector(Xtrain,cfg,temporalInfo)

detector.pca=fitMaskedPCA(Xtrain,cfg.latentDim,cfg.maskProbability);

[Ztrain,~]=applyPCAEncoder(Xtrain,detector.pca);

detector.temporalEnabled=resolveTemporalMode( ...
    temporalInfo,cfg,size(Xtrain,1));

if detector.temporalEnabled
    detector.temporalA=ridgeRegression( ...
        Ztrain(1:end-1,:),Ztrain(2:end,:),cfg.ridgeLambda);
else
    detector.temporalA=[];
end

% Multi-view split from feature space.
% For public datasets this is explicitly a multi-view consistency model,
% not literal IoT/data/control-plane cross-plane telemetry.
detector.viewIdx=buildVarianceBalancedViews(Xtrain,3);

for v=1:3
    detector.viewPCA{v}=fitPlanePCA( ...
        Xtrain(:,detector.viewIdx{v}),1:size(Xtrain,1), ...
        min(4,numel(detector.viewIdx{v})));
end

V1=applyPlanePCA(Xtrain(:,detector.viewIdx{1}),detector.viewPCA{1});
V2=applyPlanePCA(Xtrain(:,detector.viewIdx{2}),detector.viewPCA{2});
V3=applyPlanePCA(Xtrain(:,detector.viewIdx{3}),detector.viewPCA{3});

k=min([size(V1,2),size(V2,2),size(V3,2)]);

V1=V1(:,1:k);
V2=V2(:,1:k);
V3=V3(:,1:k);

detector.W12=ridgeRegression(V1,V2,cfg.ridgeLambda);
detector.W23=ridgeRegression(V2,V3,cfg.ridgeLambda);
detector.W13=ridgeRegression(V1,V3,cfg.ridgeLambda);
end

function [scores,names]=scoreCausalHealDetector(detector,Xtrain,Xtest,cfg)

[Ztr,XhatTr]=applyPCAEncoder(Xtrain,detector.pca);
[Zte,XhatTe]=applyPCAEncoder(Xtest,detector.pca);

% Reconstruction
recTrRaw=mean((Xtrain-XhatTr).^2,2);
recTeRaw=mean((Xtest-XhatTe).^2,2);

[rTr,recNorm]=fitRobustScoreNormalizer(recTrRaw);
rTe=applyRobustScoreNormalizer(recTeRaw,recNorm);

% Multi-view consistency
crossTrRaw=computeViewCrossError(detector,Xtrain);
crossTeRaw=computeViewCrossError(detector,Xtest);

[cTr,crossNorm]=fitRobustScoreNormalizer(crossTrRaw);
cTe=applyRobustScoreNormalizer(crossTeRaw,crossNorm);

% Optional temporal consistency
if detector.temporalEnabled

    predTr=zeros(size(Ztr));
    predTr(2:end,:)=Ztr(1:end-1,:)*detector.temporalA;

    predTe=zeros(size(Zte));
    predTe(2:end,:)=Zte(1:end-1,:)*detector.temporalA;

    tempTrRaw=zeros(size(Ztr,1),1);
    tempTeRaw=zeros(size(Zte,1),1);

    tempTrRaw(2:end)=mean((Ztr(2:end,:)-predTr(2:end,:)).^2,2);
    tempTeRaw(2:end)=mean((Zte(2:end,:)-predTe(2:end,:)).^2,2);

    if numel(tempTrRaw)>1
        tempTrRaw(1)=tempTrRaw(2);
    end

    if numel(tempTeRaw)>1
        tempTeRaw(1)=tempTeRaw(2);
    end

    [pTr,tempNorm]=fitRobustScoreNormalizer(tempTrRaw);
    pTe=applyRobustScoreNormalizer(tempTeRaw,tempNorm);

else
    % No unsupported pseudo-temporal modeling for unordered tabular data.
    pTr=zeros(size(rTr));
    pTe=zeros(size(rTe));
end

% Mahalanobis baseline
mahaTrRaw=mahalanobisScore(Xtrain,Xtrain);
mahaTeRaw=mahalanobisScore(Xtest,Xtrain);

[mahaTr,mahaNorm]=fitRobustScoreNormalizer(mahaTrRaw);
mahaTe=applyRobustScoreNormalizer(mahaTeRaw,mahaNorm);

% w/o Reconstruction = temporal + multiview if temporal exists;
% otherwise multi-view alone.
if detector.temporalEnabled
    noRecTrRaw=cfg.wPred*pTr+cfg.wCross*cTr;
    noRecTeRaw=cfg.wPred*pTe+cfg.wCross*cTe;
else
    noRecTrRaw=cTr;
    noRecTeRaw=cTe;
end

[scoreNoRecTr,noRecScale]=fitFusionScale(noRecTrRaw);
scoreNoRecTe=applyFusionScale(noRecTeRaw,noRecScale);

% CausalHeal-Static = reconstruction + multi-view.
staticTrRaw=cfg.wRec*rTr+cfg.wCross*cTr;
staticTeRaw=cfg.wRec*rTe+cfg.wCross*cTe;

[staticTr,staticScale]=fitFusionScale(staticTrRaw);
staticTe=applyFusionScale(staticTeRaw,staticScale);

% Adaptive Full:
% temporal term is included only when temporal ordering is validated.
if detector.temporalEnabled
    fullTrRaw=cfg.wRec*rTr+cfg.wPred*pTr+cfg.wCross*cTr;
    fullTeRaw=cfg.wRec*rTe+cfg.wPred*pTe+cfg.wCross*cTe;
else
    fullTrRaw=staticTrRaw;
    fullTeRaw=staticTeRaw;
end

[fullTr,fullScale]=fitFusionScale(fullTrRaw);
fullTe=applyFusionScale(fullTeRaw,fullScale);

scores.train={rTr,mahaTr,scoreNoRecTr,staticTr,fullTr};
scores.test ={rTe,mahaTe,scoreNoRecTe,staticTe,fullTe};

names={ ...
    'PCA Reconstruction', ...
    'Mahalanobis', ...
    'CausalHeal w/o Reconstruction', ...
    'CausalHeal-Static', ...
    'CausalHeal Adaptive Full'};
end

function [z,normModel]=fitRobustScoreNormalizer(score)

normModel.median=median(score);
normModel.scale=robustMAD(score);

z=max(0,(score-normModel.median)/(normModel.scale+eps));
z=log1p(z);
end

function z=applyRobustScoreNormalizer(score,normModel)

z=max(0,(score-normModel.median)/(normModel.scale+eps));
z=log1p(z);
end

function [y,scaleModel]=fitFusionScale(x)

scaleModel.scale=median(x)+3*robustMAD(x);

if scaleModel.scale<=eps
    scaleModel.scale=max(x)+eps;
end

y=x/(scaleModel.scale+eps);
end

function y=applyFusionScale(x,scaleModel)

y=x/(scaleModel.scale+eps);
end

function e=computeViewCrossError(detector,X)

V1=applyPlanePCA(X(:,detector.viewIdx{1}),detector.viewPCA{1});
V2=applyPlanePCA(X(:,detector.viewIdx{2}),detector.viewPCA{2});
V3=applyPlanePCA(X(:,detector.viewIdx{3}),detector.viewPCA{3});

k=min([size(V1,2),size(V2,2),size(V3,2)]);

V1=V1(:,1:k);
V2=V2(:,1:k);
V3=V3(:,1:k);

V2h=V1*detector.W12;
V3h2=V2*detector.W23;
V3h1=V1*detector.W13;

e= ...
    mean((V2-V2h).^2,2) + ...
    0.5*mean((V3-V3h2).^2,2) + ...
    0.5*mean((V3-V3h1).^2,2);
end

function views=buildVarianceBalancedViews(X,nViews)

v=var(X,0,1);
[~,ord]=sort(v,'descend');

views=cell(nViews,1);

for k=1:numel(ord)
    target=mod(k-1,nViews)+1;
    views{target}(end+1)=ord(k); %#ok<AGROW>
end
end

%% ========================================================================
% V7 SEMANTIC FEATURE MAPPING
% ========================================================================

function [Xs,Xt,sharedNames,mapInfo]=buildPairwiseDerivedSemanticMatrices(Src,Tgt,cfg)

S=buildHarmonizedSemanticBank(Src,cfg);
T=buildHarmonizedSemanticBank(Tgt,cfg);

srcNames=fieldnames(S.values);
tgtNames=fieldnames(T.values);

sharedNames=intersect(srcNames,tgtNames,'stable');

Xs=zeros(size(Src.X,1),numel(sharedNames));
Xt=zeros(size(Tgt.X,1),numel(sharedNames));

mapInfo.SourceFeature=cell(numel(sharedNames),1);
mapInfo.TargetFeature=cell(numel(sharedNames),1);
mapInfo.FeatureType=cell(numel(sharedNames),1);

for k=1:numel(sharedNames)

    c=sharedNames{k};

    Xs(:,k)=S.values.(c);
    Xt(:,k)=T.values.(c);

    mapInfo.SourceFeature{k}=S.provenance.(c);
    mapInfo.TargetFeature{k}=T.provenance.(c);

    if startsWith(c,'derived_')
        mapInfo.FeatureType{k}='derived';
    else
        mapInfo.FeatureType{k}='direct';
    end
end
end

function B=buildHarmonizedSemanticBank(D,cfg)

B.values=struct();
B.provenance=struct();

M=canonicalSemanticMap(D.FeatureNames);

% ------------------------------------------------------------------
% Direct canonical features
% ------------------------------------------------------------------
canonNames=fieldnames(M);

for i=1:numel(canonNames)

    c=canonNames{i};
    idx=M.(c).index;

    v=double(D.X(:,idx));
    v=sanitizeSemanticVector(v,cfg);

    B.values.(c)=v;
    B.provenance.(c)=D.FeatureNames{idx};
end

% ------------------------------------------------------------------
% Derived totals
% ------------------------------------------------------------------
if hasFields(B.values,{'fwd_packets','bwd_packets'})
    B.values.derived_total_packets = ...
        B.values.fwd_packets + B.values.bwd_packets;
    B.provenance.derived_total_packets = ...
        'fwd_packets + bwd_packets';
end

if hasFields(B.values,{'fwd_bytes','bwd_bytes'})
    B.values.derived_total_bytes = ...
        B.values.fwd_bytes + B.values.bwd_bytes;
    B.provenance.derived_total_bytes = ...
        'fwd_bytes + bwd_bytes';
end

% ------------------------------------------------------------------
% Directional ratios / balance
% ------------------------------------------------------------------
if hasFields(B.values,{'fwd_packets','bwd_packets'})
    den=B.values.fwd_packets+B.values.bwd_packets+cfg.semanticEps;

    B.values.derived_fwd_packet_fraction = ...
        B.values.fwd_packets ./ den;
    B.provenance.derived_fwd_packet_fraction = ...
        'fwd_packets/(fwd_packets+bwd_packets)';

    B.values.derived_bwd_packet_fraction = ...
        B.values.bwd_packets ./ den;
    B.provenance.derived_bwd_packet_fraction = ...
        'bwd_packets/(fwd_packets+bwd_packets)';

    B.values.derived_packet_direction_ratio = ...
        log1p(B.values.fwd_packets) - log1p(B.values.bwd_packets);
    B.provenance.derived_packet_direction_ratio = ...
        'log1p(fwd_packets)-log1p(bwd_packets)';
end

if hasFields(B.values,{'fwd_bytes','bwd_bytes'})
    den=B.values.fwd_bytes+B.values.bwd_bytes+cfg.semanticEps;

    B.values.derived_fwd_byte_fraction = ...
        B.values.fwd_bytes ./ den;
    B.provenance.derived_fwd_byte_fraction = ...
        'fwd_bytes/(fwd_bytes+bwd_bytes)';

    B.values.derived_bwd_byte_fraction = ...
        B.values.bwd_bytes ./ den;
    B.provenance.derived_bwd_byte_fraction = ...
        'bwd_bytes/(fwd_bytes+bwd_bytes)';

    B.values.derived_byte_direction_ratio = ...
        log1p(B.values.fwd_bytes) - log1p(B.values.bwd_bytes);
    B.provenance.derived_byte_direction_ratio = ...
        'log1p(fwd_bytes)-log1p(bwd_bytes)';
end

% ------------------------------------------------------------------
% Mean packet sizes
% ------------------------------------------------------------------
if hasFields(B.values,{'fwd_bytes','fwd_packets'})
    B.values.derived_fwd_mean_packet_size = ...
        B.values.fwd_bytes ./ (B.values.fwd_packets+cfg.semanticEps);
    B.provenance.derived_fwd_mean_packet_size = ...
        'fwd_bytes/fwd_packets';
end

if hasFields(B.values,{'bwd_bytes','bwd_packets'})
    B.values.derived_bwd_mean_packet_size = ...
        B.values.bwd_bytes ./ (B.values.bwd_packets+cfg.semanticEps);
    B.provenance.derived_bwd_mean_packet_size = ...
        'bwd_bytes/bwd_packets';
end

if isfield(B.values,'derived_total_bytes') && ...
        isfield(B.values,'derived_total_packets')

    B.values.derived_mean_packet_size = ...
        B.values.derived_total_bytes ./ ...
        (B.values.derived_total_packets+cfg.semanticEps);

    B.provenance.derived_mean_packet_size = ...
        '(fwd_bytes+bwd_bytes)/(fwd_packets+bwd_packets)';
end

% ------------------------------------------------------------------
% Rates from duration
% ------------------------------------------------------------------
if isfield(B.values,'flow_duration')

    dur=max(abs(B.values.flow_duration),cfg.semanticEps);

    if isfield(B.values,'derived_total_packets')
        B.values.derived_packet_rate = ...
            B.values.derived_total_packets ./ dur;
        B.provenance.derived_packet_rate = ...
            '(fwd_packets+bwd_packets)/flow_duration';
    end

    if isfield(B.values,'derived_total_bytes')
        B.values.derived_byte_rate = ...
            B.values.derived_total_bytes ./ dur;
        B.provenance.derived_byte_rate = ...
            '(fwd_bytes+bwd_bytes)/flow_duration';
    end
end

% Prefer measured rates when present, but derived rates are preserved
% separately so they remain auditable.
% ------------------------------------------------------------------
% TCP control-flag aggregate
% ------------------------------------------------------------------
flagNames={'syn_count','ack_count','rst_count','fin_count','psh_count'};
present={};

for i=1:numel(flagNames)
    if isfield(B.values,flagNames{i})
        present{end+1}=flagNames{i}; %#ok<AGROW>
    end
end

if numel(present)>=2

    flagTotal=zeros(size(D.X,1),1);
    expr={};

    for i=1:numel(present)
        flagTotal=flagTotal+B.values.(present{i});
        expr{end+1}=present{i}; %#ok<AGROW>
    end

    B.values.derived_tcp_control_count=flagTotal;
    B.provenance.derived_tcp_control_count=strjoin(expr,' + ');
end

% ------------------------------------------------------------------
% Log-domain versions of highly skewed nonnegative counters.
% These are semantically identical quantities expressed on a stable scale.
% ------------------------------------------------------------------
logCandidates={ ...
    'flow_duration','fwd_packets','bwd_packets','fwd_bytes','bwd_bytes', ...
    'derived_total_packets','derived_total_bytes', ...
    'packet_rate','byte_rate','derived_packet_rate','derived_byte_rate'};

for i=1:numel(logCandidates)

    c=logCandidates{i};

    if isfield(B.values,c)
        outName=['derived_log_',c];
        B.values.(outName)=log1p(max(B.values.(c),0));
        B.provenance.(outName)=['log1p(',c,')'];
    end
end

% Final sanitization
names=fieldnames(B.values);

for i=1:numel(names)
    c=names{i};
    B.values.(c)=sanitizeSemanticVector(B.values.(c),cfg);
end
end

function tf=hasFields(S,names)

tf=true;

for i=1:numel(names)
    if ~isfield(S,names{i})
        tf=false;
        return;
    end
end
end

function v=sanitizeSemanticVector(v,cfg)

v=double(v(:));

v(~isfinite(v))=NaN;

med=median(v,'omitnan');

if ~isfinite(med)
    med=0;
end

v(isnan(v))=med;

v=max(min(v,cfg.semanticMaxAbs),-cfg.semanticMaxAbs);
end

function M=canonicalSemanticMap(featureNames)

M=struct();

for i=1:numel(featureNames)

    raw=string(featureNames{i});
    n=normalizeFeatureName(raw);

    canon='';

    % Duration
    if any(strcmp(n,{ ...
            'duration','flowduration','flow_duration'}))
        canon='flow_duration';

    % Forward/source packet count
    elseif any(strcmp(n,{ ...
            'srcpkts','src_pkts','totfwdpkts','totalfwdpackets', ...
            'fwdpackets','totalfwdpkts','spkts'}))
        canon='fwd_packets';

    % Backward/destination packet count
    elseif any(strcmp(n,{ ...
            'dstpkts','dst_pkts','totbwdpkts','totalbackwardpackets', ...
            'bwdpackets','totalbwdpkts','dpkts'}))
        canon='bwd_packets';

    % Forward/source byte total
    elseif any(strcmp(n,{ ...
            'srcbytes','src_bytes','srctotalbytes','totlenfwdpkts', ...
            'totalfwdlength','totalfwdpacketlength','sbytes'}))
        canon='fwd_bytes';

    % Backward/destination byte total
    elseif any(strcmp(n,{ ...
            'dstbytes','dst_bytes','dsttotalbytes','totlenbwdpkts', ...
            'totalbwdlength','totalbwdpacketlength','dbytes'}))
        canon='bwd_bytes';

    % Flow packet rate
    elseif any(strcmp(n,{ ...
            'flowpktss','flowpktssec','flowpacketssec','flowpacketspersec', ...
            'rate','packetrate','flowpkts_s'}))
        canon='packet_rate';

    % Flow byte rate
    elseif any(strcmp(n,{ ...
            'flowbytss','flowbytessec','flowbytespersec','byterate', ...
            'flowbytes_s'}))
        canon='byte_rate';

    % Flow IAT
    elseif any(strcmp(n,{ ...
            'flowiatmean','flow_iat_mean'}))
        canon='flow_iat_mean';

    elseif any(strcmp(n,{ ...
            'flowiatstd','flow_iat_std'}))
        canon='flow_iat_std';

    elseif any(strcmp(n,{ ...
            'flowiatmax','flow_iat_max'}))
        canon='flow_iat_max';

    elseif any(strcmp(n,{ ...
            'flowiatmin','flow_iat_min'}))
        canon='flow_iat_min';

    % Forward packet length
    elseif any(strcmp(n,{ ...
            'fwdpktlenmean','fwd_packet_length_mean','fwdpktlengthmean'}))
        canon='fwd_pkt_len_mean';

    elseif any(strcmp(n,{ ...
            'fwdpktlenstd','fwd_packet_length_std','fwdpktlengthstd'}))
        canon='fwd_pkt_len_std';

    elseif any(strcmp(n,{ ...
            'fwdpktlenmax','fwd_packet_length_max','fwdpktlengthmax'}))
        canon='fwd_pkt_len_max';

    elseif any(strcmp(n,{ ...
            'fwdpktlenmin','fwd_packet_length_min','fwdpktlengthmin'}))
        canon='fwd_pkt_len_min';

    % Backward packet length
    elseif any(strcmp(n,{ ...
            'bwdpktlenmean','bwd_packet_length_mean','bwdpktlengthmean'}))
        canon='bwd_pkt_len_mean';

    elseif any(strcmp(n,{ ...
            'bwdpktlenstd','bwd_packet_length_std','bwdpktlengthstd'}))
        canon='bwd_pkt_len_std';

    elseif any(strcmp(n,{ ...
            'bwdpktlenmax','bwd_packet_length_max','bwdpktlengthmax'}))
        canon='bwd_pkt_len_max';

    elseif any(strcmp(n,{ ...
            'bwdpktlenmin','bwd_packet_length_min','bwdpktlengthmin'}))
        canon='bwd_pkt_len_min';

    % Forward IAT
    elseif any(strcmp(n,{ ...
            'fwdiatmean','fwd_iat_mean'}))
        canon='fwd_iat_mean';

    elseif any(strcmp(n,{ ...
            'fwdiatstd','fwd_iat_std'}))
        canon='fwd_iat_std';

    elseif any(strcmp(n,{ ...
            'fwdiatmax','fwd_iat_max'}))
        canon='fwd_iat_max';

    elseif any(strcmp(n,{ ...
            'fwdiatmin','fwd_iat_min'}))
        canon='fwd_iat_min';

    % Backward IAT
    elseif any(strcmp(n,{ ...
            'bwdiatmean','bwd_iat_mean'}))
        canon='bwd_iat_mean';

    elseif any(strcmp(n,{ ...
            'bwdiatstd','bwd_iat_std'}))
        canon='bwd_iat_std';

    elseif any(strcmp(n,{ ...
            'bwdiatmax','bwd_iat_max'}))
        canon='bwd_iat_max';

    elseif any(strcmp(n,{ ...
            'bwdiatmin','bwd_iat_min'}))
        canon='bwd_iat_min';

    % TCP flag counts / indicators
    elseif any(strcmp(n,{ ...
            'synflagcnt','syn_flag_count','tcpconnectionssyn','tcpsyn'}))
        canon='syn_count';

    elseif any(strcmp(n,{ ...
            'ackflagcnt','ack_flag_count','tcpconnectionack','tcpack'}))
        canon='ack_count';

    elseif any(strcmp(n,{ ...
            'rstflagcnt','rst_flag_count','tcpconnectionrst','tcprst'}))
        canon='rst_count';

    elseif any(strcmp(n,{ ...
            'finflagcnt','fin_flag_count','tcpconnectionfin','tcpfin'}))
        canon='fin_count';

    elseif any(strcmp(n,{ ...
            'pshflagcnt','psh_flag_count','tcpconnectionpsh','tcppsh'}))
        canon='psh_count';
    end

    if ~isempty(canon) && ~isfield(M,canon)
        M.(canon).index=i;
        M.(canon).raw=char(raw);
    end
end
end

function n=normalizeFeatureName(x)

n=lower(char(x));

n=strrep(n,'/s','s');
n=strrep(n,'per second','sec');
n=strrep(n,'persecond','sec');
n=regexprep(n,'[^a-z0-9_]','');
end

function model=fitSpectralClippedCORALAlignment( ...
    Xsrc,XtgtCal,cfg,kappaMax)

% Robust trimming before covariance estimation
Xs=trimRowsByRobustDistance(Xsrc,cfg.alignmentTrimQuantile);
Xt=trimRowsByRobustDistance(XtgtCal,cfg.alignmentTrimQuantile);

model.srcMean=mean(Xs,1);
model.tgtMean=mean(Xt,1);

Xs0=Xs-model.srcMean;
Xt0=Xt-model.tgtMean;

Cs=cov(Xs0);
Ct=cov(Xt0);

% Symmetrize to suppress numerical asymmetry.
Cs=(Cs+Cs')/2;
Ct=(Ct+Ct')/2;

% Spectrally clip source and target covariances independently.
[CsClip,srcDiag]=spectralClipCovariance( ...
    Cs,kappaMax,cfg.spectralEigenFloorAbs);

[CtClip,tgtDiag]=spectralClipCovariance( ...
    Ct,kappaMax,cfg.spectralEigenFloorAbs);

% Small numerical ridge remains only as a floating-point floor.
d=size(Xsrc,2);
CsClip=CsClip + cfg.coralRidge*eye(d);
CtClip=CtClip + cfg.coralRidge*eye(d);

CtInvHalf=symmetricInvSqrt(CtClip);
CsHalf=symmetricSqrt(CsClip);

model.A=CtInvHalf*CsHalf;

condCt=cond(CtClip);
condCs=cond(CsClip);
condA=cond(model.A);

model.conditionNumber=max([condCt,condCs,condA]);

if ~isfinite(model.conditionNumber)
    model.conditionNumber=Inf;
end

model.kappaMax=kappaMax;
model.sourceOriginalCondition=srcDiag.originalCondition;
model.targetOriginalCondition=tgtDiag.originalCondition;
model.sourceClippedCondition=srcDiag.clippedCondition;
model.targetClippedCondition=tgtDiag.clippedCondition;
model.sourceClippedEigenvalues=srcDiag.numClipped;
model.targetClippedEigenvalues=tgtDiag.numClipped;
model.totalClippedEigenvalues=srcDiag.numClipped+tgtDiag.numClipped;
end

function [Cclip,diagInfo]=spectralClipCovariance(C,kappaMax,absFloor)

C=(C+C')/2;

[V,D]=eig(C);
e=real(diag(D));

% Covariance eigenvalues should be nonnegative, but finite-sample and
% floating-point effects can create tiny negative values.
e(~isfinite(e))=0;
e=max(e,0);

eMax=max(e);

if ~isfinite(eMax) || eMax<=0
    eMax=1;
end

positive=e(e>0);

if isempty(positive)
    originalCondition=Inf;
else
    originalCondition=eMax/max(min(positive),absFloor);
end

relativeFloor=eMax/max(kappaMax,1);
eigFloor=max(relativeFloor,absFloor);

clipMask=e<eigFloor;
eClip=e;
eClip(clipMask)=eigFloor;

Cclip=V*diag(eClip)*V';
Cclip=real((Cclip+Cclip')/2);

diagInfo.originalCondition=originalCondition;
diagInfo.clippedCondition=max(eClip)/max(min(eClip),absFloor);
diagInfo.numClipped=sum(clipMask);
diagInfo.eigenFloor=eigFloor;
end

function [diagResult,calibScore,evalScore]= ...
    evaluateTransferValidityAndScores( ...
    Xsrc,XcalAligned,XevalAligned,srcModel,srcScore, ...
    sourceThreshold,sourceScoreMedian,sourceScoreMAD, ...
    alignmentCondition,cfg)

calibScore=semanticOneClassScore(srcModel,XcalAligned);
evalScore=semanticOneClassScore(srcModel,XevalAligned);

[validityCore,~]=pseudoNormalCoreThreshold( ...
    calibScore,cfg.validityCoreFraction,cfg);

if isempty(validityCore)
    validityCore=calibScore;
end

targetScoreMedian=median(validityCore);
targetScoreMAD=robustMAD(validityCore);

if targetScoreMAD<1e-12
    targetScoreMAD=1e-12;
end

sourceAlarmRate=mean(calibScore>sourceThreshold);

fullTargetSpread=robustMAD(calibScore);
if fullTargetSpread<1e-12
    fullTargetSpread=1e-12;
end

scoreSpreadRatio=fullTargetSpread/sourceScoreMAD;

coreMedianShiftMAD=abs(targetScoreMedian-sourceScoreMedian) / ...
    sourceScoreMAD;

coreScaleRatio=targetScoreMAD/sourceScoreMAD;

alarmGate = ...
    sourceAlarmRate<=cfg.maxCalibrationAlarmForTransfer;

spreadGate = ...
    scoreSpreadRatio>=cfg.validSpreadRatioMin && ...
    scoreSpreadRatio<=cfg.validSpreadRatioMax;

coreShiftGate = ...
    coreMedianShiftMAD<=cfg.maxCoreMedianShiftMAD;

coreScaleGate = ...
    coreScaleRatio>=cfg.validCoreScaleRatioMin && ...
    coreScaleRatio<=cfg.validCoreScaleRatioMax;

conditionGate = ...
    isfinite(alignmentCondition) && ...
    alignmentCondition<=cfg.maxCovarianceCondition;

transferSupported = ...
    alarmGate && spreadGate && coreShiftGate && ...
    coreScaleGate && conditionGate;

abstainReason=composeValidityFailureReason( ...
    alarmGate,spreadGate,coreShiftGate,coreScaleGate,conditionGate);

if transferSupported
    abstainReason='';
end

diagResult.SourceThresholdAlarmRate=sourceAlarmRate;
diagResult.ScoreSpreadRatio=scoreSpreadRatio;
diagResult.CoreMedianShiftMAD=coreMedianShiftMAD;
diagResult.CoreScaleRatio=coreScaleRatio;
diagResult.AlignmentCondition=alignmentCondition;
diagResult.AlarmGate=alarmGate;
diagResult.SpreadGate=spreadGate;
diagResult.CoreShiftGate=coreShiftGate;
diagResult.CoreScaleGate=coreScaleGate;
diagResult.ConditionGate=conditionGate;
diagResult.TransferSupported=transferSupported;
diagResult.AbstainReason=abstainReason;
end

function [thresholdNames,thresholdValues,coreSizes,coreAlarmRates] = ...
    buildCalibrationThresholds(calibScore,srcScore,sourceThreshold,cfg)

thresholdNames={};
thresholdValues=[];
coreSizes=[];
coreAlarmRates=[];

thresholdNames{end+1}='SourceThreshold';
thresholdValues(end+1)=sourceThreshold;
coreSizes(end+1)=numel(srcScore);
coreAlarmRates(end+1)=mean(calibScore>sourceThreshold);

fullTail=median(calibScore)+cfg.robustTailK*robustMAD(calibScore);

thresholdNames{end+1}='FullUnlabeledRobustTail';
thresholdValues(end+1)=fullTail;
coreSizes(end+1)=numel(calibScore);
coreAlarmRates(end+1)=mean(calibScore>fullTail);

for pf=cfg.pseudoNormalFractions

    [coreScores,coreThreshold]= ...
        pseudoNormalCoreThreshold(calibScore,pf,cfg);

    label=sprintf('PseudoNormalCore%d',round(100*pf));

    thresholdNames{end+1}=label;
    thresholdValues(end+1)=coreThreshold;
    coreSizes(end+1)=numel(coreScores);
    coreAlarmRates(end+1)=mean(calibScore>coreThreshold);
end

[iterCore,iterThreshold]= ...
    iterativePseudoNormalThreshold(calibScore,cfg);

thresholdNames{end+1}='IterativeTrimmedCore';
thresholdValues(end+1)=iterThreshold;
coreSizes(end+1)=numel(iterCore);
coreAlarmRates(end+1)=mean(calibScore>iterThreshold);
end

function reason=composeValidityFailureReason( ...
    alarmGate,spreadGate,coreShiftGate,coreScaleGate,conditionGate)

reasons={};

if ~alarmGate
    reasons{end+1}='AlarmRate'; %#ok<AGROW>
end

if ~spreadGate
    reasons{end+1}='ScoreSpread'; %#ok<AGROW>
end

if ~coreShiftGate
    reasons{end+1}='CoreMedianShift'; %#ok<AGROW>
end

if ~coreScaleGate
    reasons{end+1}='CoreScale'; %#ok<AGROW>
end

if ~conditionGate
    reasons{end+1}='Conditioning'; %#ok<AGROW>
end

if isempty(reasons)
    reason='';
else
    reason=strjoin(reasons,'+');
end
end

function [coreScores,threshold]=pseudoNormalCoreThreshold(calibScore,fraction,cfg)

s=calibScore(:);
s=s(isfinite(s));

if isempty(s)
    coreScores=[];
    threshold=Inf;
    return;
end

cut=quantile(s,fraction);
coreScores=s(s<=cut);

if numel(coreScores)<cfg.minTargetCoreRows
    coreScores=sort(s,'ascend');
    keep=min(numel(coreScores),cfg.minTargetCoreRows);
    coreScores=coreScores(1:keep);
end

threshold=median(coreScores)+cfg.robustTailK*robustMAD(coreScores);
end

function [coreScores,threshold]=iterativePseudoNormalThreshold(calibScore,cfg)

s=calibScore(:);
s=s(isfinite(s));

if isempty(s)
    coreScores=[];
    threshold=Inf;
    return;
end

coreScores=s;

for r=1:cfg.iterativeTrimRounds

    cut=quantile(coreScores,cfg.iterativeTrimFraction);
    nextCore=coreScores(coreScores<=cut);

    if numel(nextCore)<cfg.minTargetCoreRows
        break;
    end

    coreScores=nextCore;
end

if numel(coreScores)<cfg.minTargetCoreRows
    ss=sort(s,'ascend');
    keep=min(numel(ss),cfg.minTargetCoreRows);
    coreScores=ss(1:keep);
end

threshold=median(coreScores)+cfg.robustTailK*robustMAD(coreScores);
end

function model=fitRobustLocationScaleAlignment(Xsrc,XtgtCal,cfg)

% Estimate robust marginal location/scale for each domain.
% Alignment maps target calibration statistics toward source statistics.

model.srcMedian=median(Xsrc,1);
model.tgtMedian=median(XtgtCal,1);

model.srcScale=zeros(1,size(Xsrc,2));
model.tgtScale=zeros(1,size(XtgtCal,2));

for j=1:size(Xsrc,2)

    model.srcScale(j)=robustMAD(Xsrc(:,j));
    model.tgtScale(j)=robustMAD(XtgtCal(:,j));

    if model.srcScale(j)<1e-8
        model.srcScale(j)=1;
    end

    if model.tgtScale(j)<1e-8
        model.tgtScale(j)=1;
    end
end

% Clip factor to avoid extreme amplification caused by degenerate target
% calibration dimensions.
model.scaleRatio=model.srcScale./model.tgtScale;
model.scaleRatio=max(min(model.scaleRatio,20),0.05);
end

function Xout=applyRobustLocationScaleAlignment(X,model)

Xout=(X-model.tgtMedian).*model.scaleRatio + model.srcMedian;
end

function model=fitCORALAlignment(Xsrc,XtgtCal,cfg)

% Robustly trim the calibration clouds before covariance estimation.
Xs=trimRowsByRobustDistance(Xsrc,cfg.alignmentTrimQuantile);
Xt=trimRowsByRobustDistance(XtgtCal,cfg.alignmentTrimQuantile);

model.srcMean=mean(Xs,1);
model.tgtMean=mean(Xt,1);

Xs0=Xs-model.srcMean;
Xt0=Xt-model.tgtMean;

Cs=cov(Xs0);
Ct=cov(Xt0);

d=size(Xsrc,2);

Cs=Cs + cfg.coralRidge*eye(d);
Ct=Ct + cfg.coralRidge*eye(d);

% Target whitening followed by source recoloring:
% (x-mu_t) * Ct^{-1/2} * Cs^{1/2} + mu_s
CtInvHalf=symmetricInvSqrt(Ct);
CsHalf=symmetricSqrt(Cs);

model.A=CtInvHalf*CsHalf;

% Numerical-conditioning diagnostic for validity gate
condCt=cond(Ct);
condCs=cond(Cs);
condA=cond(model.A);

model.conditionNumber=max([condCt,condCs,condA]);

if ~isfinite(model.conditionNumber)
    model.conditionNumber=Inf;
end
end

function Xout=applyCORALAlignment(X,model)

Xout=(X-model.tgtMean)*model.A + model.srcMean;
end

function Xtrim=trimRowsByRobustDistance(X,q)

med=median(X,1);
sc=zeros(1,size(X,2));

for j=1:size(X,2)
    sc(j)=robustMAD(X(:,j));
    if sc(j)<1e-8
        sc(j)=1;
    end
end

Z=(X-med)./sc;
d2=sum(Z.^2,2);

cut=quantile(d2,q);
keep=d2<=cut;

if sum(keep)<max(20,size(X,2)+5)
    Xtrim=X;
else
    Xtrim=X(keep,:);
end
end

function A=symmetricSqrt(C)

C=(C+C')/2;

[V,D]=eig(C);
e=diag(D);
e=max(e,1e-10);

A=V*diag(sqrt(e))*V';
A=real((A+A')/2);
end

function A=symmetricInvSqrt(C)

C=(C+C')/2;

[V,D]=eig(C);
e=diag(D);
e=max(e,1e-10);

A=V*diag(1./sqrt(e))*V';
A=real((A+A')/2);
end

function model=trainSemanticOneClass(Z,cfg)

model.center=median(Z,1);

% Robust scale per semantic dimension
model.scale=zeros(1,size(Z,2));

for j=1:size(Z,2)
    model.scale(j)=robustMAD(Z(:,j));

    if model.scale(j)<1e-8
        model.scale(j)=1;
    end
end

Zr=(Z-model.center)./model.scale;

C=cov(Zr)+cfg.ridgeLambda*eye(size(Zr,2));

model.invC=pinv(C);
end

function score=semanticOneClassScore(model,Z)

Zr=(Z-model.center)./model.scale;

score=sum((Zr*model.invC).*Zr,2);
end

%% ========================================================================
% COMMON LATENT GENERALIZATION
% ========================================================================

function model=fitCommonProjection(X,k)

mu=mean(X,1);
Xc=X-mu;

[~,~,V]=svd(Xc,'econ');

k=min(k,size(V,2));

model.mu=mu;
model.P=V(:,1:k);
end

function Z=applyCommonProjection(X,model)
Z=(X-model.mu)*model.P;
end

function Z=varianceAlignLatent(Z)

v=var(Z,0,1);
[~,ord]=sort(v,'descend');
Z=Z(:,ord);

% Sign standardization
for j=1:size(Z,2)
    if mean(Z(:,j),'omitnan')<0
        Z(:,j)=-Z(:,j);
    end
end
end

function model=trainLatentOneClass(Z,cfg)

model.mu=mean(Z,1);
C=cov(Z)+cfg.ridgeLambda*eye(size(Z,2));
model.invC=pinv(C);
end

function score=latentOneClassScore(model,Z)

XC=Z-model.mu;
score=sum((XC*model.invC).*XC,2);
end

%% ========================================================================
% MODEL HELPERS
% ========================================================================

function model=fitMaskedPCA(Xtrain,latentDim,maskProb)

mu=mean(Xtrain,1);

Xm=Xtrain;

mask=rand(size(Xm))<maskProb;

muMat=repmat(mu,size(Xtrain,1),1);

Xm(mask)=muMat(mask);

Xc=Xm-mu;

[~,~,V]=svd(Xc,'econ');

k=min(latentDim,size(V,2));

model.mu=mu;
model.P=V(:,1:k);
end

function [Z,Xhat]=applyPCAEncoder(X,model)

Xc=X-model.mu;

Z=Xc*model.P;

Xhat=Z*model.P'+model.mu;
end

function model=fitPlanePCA(X,trainIdx,k)

mu=mean(X(trainIdx,:),1);

Xt=X(trainIdx,:)-mu;

[~,~,V]=svd(Xt,'econ');

k=min(k,size(V,2));

model.mu=mu;
model.P=V(:,1:k);
end

function Z=applyPlanePCA(X,model)

Z=(X-model.mu)*model.P;
end

function B=ridgeRegression(X,Y,lambda)

D=size(X,2);

B=(X'*X+lambda*eye(D))\(X'*Y);
end

function z=robustNormalize(score,reference)

med=median(reference);

scale=robustMAD(reference);

z=max(0,(score-med)/(scale+eps));

z=log1p(z);
end

function y=weightedNormalize(x)

scale=median(x)+3*robustMAD(x);

if scale<=eps
    scale=max(x)+eps;
end

y=x/(scale+eps);
end

function value=robustMAD(x)

x=x(:);

m=median(x);

value=1.4826*median(abs(x-m));

if value<1e-10
    value=std(x)+1e-6;
end
end

function score=mahalanobisScore(X,Xtrain)

mu=mean(Xtrain,1);

C=cov(Xtrain)+1e-3*eye(size(Xtrain,2));

invC=pinv(C);

XC=X-mu;

score=sum((XC*invC).*XC,2);
end

function [precision,recall,F1,accuracy,FPR,balancedAccuracy]=classificationMetricsV3(yTrue,yPred)

yTrue=logical(yTrue);
yPred=logical(yPred);

TP=sum(yTrue & yPred);
TN=sum(~yTrue & ~yPred);
FP=sum(~yTrue & yPred);
FN=sum(yTrue & ~yPred);

precision=TP/(TP+FP+eps);
recall=TP/(TP+FN+eps);
specificity=TN/(TN+FP+eps);
F1=2*precision*recall/(precision+recall+eps);
accuracy=(TP+TN)/(TP+TN+FP+FN+eps);
FPR=FP/(FP+TN+eps);
balancedAccuracy=0.5*(recall+specificity);
end

function auc=safeAUROC(Y,score)

try
    [~,~,~,auc]=perfcurve(Y,score,1);
catch
    auc=NaN;
end
end


function auprc=safeAUPRC(Y,score)

try
    [recall,precision,~,auprc]=perfcurve(Y,score,1, ...
        'xCrit','reca','yCrit','prec');

    % Some MATLAB releases may return NaN in edge cases.
    if isempty(recall) || isempty(precision)
        auprc=NaN;
    end
catch
    try
        % Manual precision-recall integration fallback.
        [scoreSorted,ord]=sort(score,'descend'); %#ok<ASGLU>
        y=Y(ord)==1;
        tp=cumsum(y);
        fp=cumsum(~y);
        precision=tp./(tp+fp+eps);
        recall=tp/(sum(y)+eps);
        auprc=trapz(recall,precision);
    catch
        auprc=NaN;
    end
end
end
