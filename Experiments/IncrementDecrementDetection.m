function IncrementDecrementDetection

global SYSPARAMS StimParams VideoParams CFG fileNames Mov;

if exist('handles','var') == 0
    handles = guihandles;
end

startup;

%----------------Hard-coded configuration stuff here-----------------------
%--------------------------------------------------------------------------

CFG.ok = 1;
CFG.subjectID = '11046';

% Video paramters
CFG.record = 1;
CFG.vidDurSec = 1; % Video duration in seconds
CFG.fps = 16;
CFG.stimDurFrames = 4;

% Stimulus parameters
CFG.stimGain = 0; % Gain of 1 means tracked on the retina; 0 = natural retinal motion
CFG.maxStimSize = 180;
CFG.minStimSize = 3;
CFG.xTCA = 0;
CFG.yTCA = 0;
CFG.testContrastPercent = 100;
CFG.backgroundIntensity = 0.5;
CFG.increment = 1;
CFG.decrement = 1;
lutFlag = 1; % Set to 1 to use AOM look-up-table for calibrated stimulus control; important for getting background intensity right

% QUEST parameters
CFG.numTrialsPerCondition = 40;
CFG.tGuess = 75; % Detectable stimulus size, in pixels
CFG.tGuessSD = 100;
CFG.pThreshold = 0.75; % 75% threshold for now is good
CFG.beta = 3.5;
CFG.delta = 0.01; % This is the lapse rate
CFG.gamma = 0.50; % This is the guess rate

% Load in calibration file
calFile = ('C:\Programs\AOMcontrol_V3_2\calibrationData\2018_02_28\15_41_18_calibrationData.mat');

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

% Get experiment config data stored in appdata for 'hAomControl'
hAomControl = getappdata(0,'hAomControl');

% if isstruct(getappdata(getappdata(0,'hAomControl'),'CFG')) == 1
    % Get configuration structure (CFG) from Config GUI
    %     CFG = getappdata(getappdata(0,'hAomControl'),'CFG');
    if CFG.ok == 1
        StimParams.stimpath = [cd '\tempStimulus\'];
        VideoParams.vidprefix = CFG.subjectID;
        set(handles.aom1_state, 'String', 'Configuring Experiment...');
        if SYSPARAMS.realsystem == 1 && SYSPARAMS.board == 'm'
            set(handles.aom1_state, 'String', 'Off - Press Start Button To Begin Experiment');
        else
            set(handles.aom1_state, 'String', 'On - Press Start Button To Begin Experiment');
        end
        if CFG.record == 1
            VideoParams.videodur = CFG.vidDurSec;
        end
        psyfname = set_VideoParams_PsyfileName();
        hAomControl = getappdata(0,'hAomControl');
        Parse_Load_Buffers(1);
        set(handles.image_radio1, 'Enable', 'off');
        set(handles.seq_radio1, 'Enable', 'off');
        set(handles.im_popup1, 'Enable', 'off');
        set(handles.display_button, 'String', 'Running Exp...');
        set(handles.display_button, 'Enable', 'off');
        set(handles.aom1_state, 'String', 'On - Experiment Mode - Running Experiment');
    else
        return;
    end
% end

% Can pass TCA offsets to ICANDI this way (need to check these are
% implemented correctly); NEED TO VERIFY AT UPENN
% if SYSPARAMS.realsystem == 1
%     command = ['UpdateOffset#' num2str(-CFG.xTCA) '#' num2str(CFG.yTCA) '#0#0#'];
%     netcomm('write',SYSPARAMS.netcommobj,int8(command));
% end

% Get the stimulus parameters
dirname = StimParams.stimpath;
fprefix = StimParams.fprefix;

% Set up the movie parameters
Mov.dir = dirname;
Mov.suppress = 0;
Mov.pfx = fprefix;

% generate file names for saving data
cdir = pwd;
if strcmp(cdir(18:22), 'Tuten') %working on my laptop
    fileNames.matfname = [psyfname(1:end-4) '_IncrementDecrementDetectionData.mat'];
    fileNames.CFGname = [psyfname(1:end-4) '_lastCFG.mat'];
    fileNames.fig1name = [psyfname(1:end-4) '_figure1.fig'];
    fileNames.fig2name = [psyfname(1:end-4) '_figure2.fig'];
else
    fileNames.matfname = ['D' psyfname(2:end-4) '_IncrementDecrementDetectionData.mat'];
    fileNames.CFGname = ['D' psyfname(2:end-4) '_lastCFG.mat'];
    fileNames.fig1name = ['D' psyfname(2:end-4) '_figure1.fig'];
    fileNames.fig2name = ['D' psyfname(2:end-4) '_figure2.fig'];
end


% Generate a stimulus sequence that can be used throughout the experiment
bmpNum = 2; % The index of your bitmap

% Place stimulus in the middle of each trial video
startFrame = floor((CFG.vidDurSec.*CFG.fps)/2)-floor(CFG.stimDurFrames/2)+1; % The frame at which it starts presenting stimulus

% Generic AOM sequence (a vector of equal length to the number of frames in
% the stimulus video, with the bmp index inserted for the frames on which the stimulus should be delivered)
aomSeq = [zeros(1,startFrame-1) ones(1,CFG.stimDurFrames).*bmpNum zeros(1,(CFG.vidDurSec*CFG.fps)-startFrame+1-CFG.stimDurFrames)];

% AOM0 (increment/decrement modulation) parameters
aom0seq = aomSeq;
aom0locx = -CFG.xTCA.*ones(size(aomSeq)); % Check that these move in the proper direction
aom0locy = CFG.yTCA.*ones(size(aomSeq)); % Check that these move in the proper direction
aom0pow = ones(size(aomSeq)).*CFG.backgroundIntensity;

% AOM1 (stimulus modulation -- increment only) parameters; not used in this
% experiment
aom1seq = zeros(size(aomSeq));
aom1pow = ones(size(aomSeq));
aom1offx = zeros(size(aomSeq)); % Spatial offset relative to AOM0 position
aom1offy = zeros(size(aomSeq)); % Spatial offset relative to AOM0 position

% AOM2 (another channel like AOM1); not currently in use at UPENN
aom2seq = zeros(size(aomSeq));
aom2pow = ones(size(aomSeq));
aom2offx = zeros(size(aomSeq)); % Spatial offset relative to AOM0 position
aom2offy = zeros(size(aomSeq)); % Spatial offset relative to AOM0 position

% Stimulus delivery parameters;
gainseq = CFG.stimGain*ones(size(aomSeq));
angleseq = zeros(size(aomSeq));
stimbeep = zeros(size(aomSeq));

%Set up movie parameters
Mov.duration = length(aomSeq);
Mov.aom0seq = aom0seq;
Mov.aom0pow = aom0pow;
Mov.aom0locx = aom0locx;
Mov.aom0locy = aom0locy;

Mov.aom1seq = aom1seq;
Mov.aom1pow = aom1pow;
Mov.aom1offx = aom1offx;
Mov.aom1offy = aom1offy;

Mov.aom2seq = aom2seq;
Mov.aom2pow = aom2pow;
Mov.aom2offx = aom2offx;
Mov.aom2offy = aom2offy;

Mov.gainseq = gainseq;
Mov.angleseq = angleseq;
Mov.stimbeep = stimbeep;
Mov.frm = 1;
Mov.seq = '';

% Set up the experiment sequence
conditionVector = [];
if CFG.increment == 1
    conditionVector = [conditionVector 1];
end
if CFG.decrement == 1
    conditionVector = [conditionVector -1];
end

% tesSeq contains either 1s or -1s to indicate stimulus polarity
% (increments and decrements, respectively);
testSeq(:,1) = reshape(repmat(conditionVector, [CFG.numTrialsPerCondition 1]),[length(conditionVector).*CFG.numTrialsPerCondition 1]); % Stimulus polarity flag
testSeq(:,2) = randi([1 2], [length(testSeq(:,1)) 1]); % Stimulus interval flag (first or second)
testSeq(:,3) = reshape(repmat((1:length(conditionVector)), [CFG.numTrialsPerCondition 1]),[length(conditionVector).*CFG.numTrialsPerCondition 1]); % A second flag will be the index of the Quest structure
testSeq(:,4) = randn(length(testSeq),1); % Insert random vector
testSeq = sortrows(testSeq,4); % Shuffle to randomize
testSeq(:,4) = []; % Delete sorted column
% Add a trial counter for each staircase (useful for plotting staircases
% later)
staircaseIndices = unique(testSeq(:,3));
for n = 1:length(staircaseIndices)
    testSeq(testSeq(:,3)==staircaseIndices(n),4) = 1:CFG.numTrialsPerCondition;
end

% Put the trial info and subject responses here
trialMatrix = nan(CFG.numTrialsPerCondition,length(staircaseIndices));
responseMatrix = trialMatrix;
correctMatrix = trialMatrix;
thresholdMatrix = trialMatrix;

% Initialize the Quest structure
for conditionNum = 1:length(conditionVector)
    qMatrix(conditionNum) = QuestCreate(log10(CFG.tGuess), log10(CFG.tGuessSD), CFG.pThreshold, CFG.beta, CFG.delta, CFG.gamma);
end

% Set initial while the loop conditions
runExperiment = 1;
trialNum = 1;
numTrialsTotal = length(testSeq);
presentStimulus = 1;
getResponse = 1;

while(runExperiment ==1)
    % This is the part where you're "listening" to the game pad for
    % responses
    if getResponse == 1
        [gamePad, ~] = GamePadInput(gcf);
        if (gamePad.buttonBack)
            resp = 'Abort';
            Beeper(200, 0.5, 0.15);
        elseif (gamePad.buttonX)
            resp = '1'; % First interval
            Beeper(200, 0.5, 0.15);
        elseif (gamePad.buttonB)
            resp = '2'; % Second interval
            Beeper(200, 0.5, 0.15);
            %         elseif (gamePad.buttonY)
            %             resp = 'increment'; % Save for future, if desired
            %             Beeper(200, 0.5, 0.15);
            %         elseif (gamePad.buttonA)
            %             resp = 'decrement'; % Save for future, if desired
            %             Beeper(200, 0.5, 0.15);
        elseif gamePad.buttonLeftUpperTrigger || gamePad.buttonLeftLowerTrigger
            resp = 'StartTrial';
        elseif gamePad.buttonRightUpperTrigger || gamePad.buttonRightLowerTrigger
            resp = 'Repeat';
            Beeper(200,1,0.05);
        else
            getResponse = 1;
        end
    end
    
    % In this section the responses determine how the experiment loop
    % progresses
    if strcmp(resp,'Abort') % Experiment aborted
        if SYSPARAMS.realsystem == 1 % If running on AOSLO
            command = 'UpdateOffset#0#0#0#0#'; % Reset stimulus offsets;
            netcomm('write',SYSPARAMS.netcommobj,int8(command));
        end
        runExperiment = 0; % Exit the while loop
        TerminateExp;
        message = ['Off - Experiment Aborted - Trial ' num2str(trialNum) ' of ' num2str(numTrialsTotal)];
        set(handles.aom1_state, 'String',message);
        Speak('Experiment aborted');
        
    elseif strcmp(resp,'StartTrial')    % Check if present stimulus button was pressed
        
        if presentStimulus == 1
            % Play out the two intervals, but only save the video from the
            % one in which the stimulus was presented
            for intervalNum = 1:2
                if testSeq(trialNum,2) == intervalNum % Present stimulus in this interval
                    testIntensity = CFG.backgroundIntensity+(CFG.backgroundIntensity.*(testSeq(trialNum,1).*CFG.testContrastPercent./100));
                else
                    % Present a patch matched to the background
                    testIntensity = CFG.backgroundIntensity;
                end
                % Get the stimulus size from Quest
                stimSize = round(10.^QuestQuantile(qMatrix(testSeq(trialNum,3))));
                if stimSize < CFG.minStimSize
                    stimSize = CFG.minStimSize;
                elseif stimSize > CFG.maxStimSize
                    stimSize = CFG.maxStimSize;
                end
                
                % Make the stimulus
                createStimulus(testIntensity, CFG.backgroundIntensity, stimSize, lutFlag,calFile);
                
                % Tell ICANDI where the stimuli reside
                if SYSPARAMS.realsystem == 1
                    StimParams.stimpath = Mov.dir;
                    StimParams.fprefix = Mov.pfx;
                    StimParams.sframe = 2;
                    StimParams.eframe = 4;
                    StimParams.fext = 'bmp';
                    Parse_Load_Buffers(0);
                end
                Mov.frm = 1;
                Mov.duration = CFG.vidDurSec*CFG.fps;
                
                message = ['Trial (' num2str(trialNum) '/' num2str(numTrialsTotal) '); size: ' num2str(stimSize) ' pixels'];
                Mov.msg = message;
                Mov.seq = '';
                setappdata(hAomControl, 'Mov',Mov);
                if testSeq(trialNum,2) == intervalNum % Record this one
                    VideoParams.vidrecord = 1;
                else
                    VideoParams.vidrecord = 0;
                end
                VideoParams.vidname = [CFG.subjectID '_' sprintf('%03d',trialNum)];
                PlayMovie;                
                if intervalNum == 1
                    pause(0.5);
                    Beeper(500,1,0.05); % Play a sound to delineate the two intervals
                end                
            end
            presentStimulus = 0;
        end
        WaitSecs(0.1); % Lock the subject out for a little bit to prevent iCANDI crashes
        getResponse = 1; % Now retrieve subject's response from controller
        
    else % Neither startTrial nor Abort button were pressed
        if presentStimulus == 0 % Stimulus has been presented
            presentStimulus = 1;
            if strcmp(resp,'Repeat') % Repeat the trial
                response = NaN;
                goodCheck = 0;
            else % Log the response
                response = str2double(resp);
                goodCheck = 1;  % Indicates if it was a good trial
                
                if response == testSeq(trialNum,2)
                    % Correct
                    correctResp = 1;
                    Beeper(400,1,0.05); Beeper(600,1,0.05);
                else
                    % Incorect
                    correctResp = 0;
                    Beeper(220,1,0.25);
                end
                
                % Proceed if repeat button not pressed
                if goodCheck == 1
                    
                    % Add to the output vectors
                    responseMatrix(testSeq(trialNum,4),testSeq(trialNum,3)) = response;
                    trialMatrix(testSeq(trialNum,4),testSeq(trialNum,3)) = stimSize;
                    correctMatrix(testSeq(trialNum,4),testSeq(trialNum,3)) = correctResp;
                    
                    % Update QUEST
                    if trialNum > 6
                        qMatrix(testSeq(trialNum,3)) = QuestUpdate(qMatrix(testSeq(trialNum,3)),log10(stimSize),correctResp);
                    end
                    thresholdMatrix(testSeq(trialNum,4),testSeq(trialNum,3)) = 10.^QuestMean(qMatrix(testSeq(trialNum,3)));
                    % Save data to .mat file
                    save(fileNames.matfname, 'responseMatrix', 'trialMatrix', 'correctMatrix', 'thresholdMatrix', 'testSeq','qMatrix','fileNames');
                    save(fileNames.CFGname,'CFG');
                    save([cd '\lastIncDecDetectionExp.mat'], 'psyfname', 'fileNames');
                    
                    % Update trial counter
                    trialNum = trialNum + 1;
                    
                    if(trialNum > numTrialsTotal) % Time to quit
                        getResponse = 0;
                        runExperiment = 0;
                        TerminateExp;
                        message = 'Off - Experiment Complete';
                        set(handles.aom1_state, 'String',message);
                        
                        Beeper(400, 0.5, 0.15), WaitSecs(0.05),Beeper(400, 0.5, 0.15);
                        Speak('Experiment complete');
                        
                        % Save data to .mat file
                        save(fileNames.matfname, 'responseMatrix', 'trialMatrix', 'correctMatrix', 'thresholdMatrix', 'testSeq','qMatrix','fileNames');
                        save(fileNames.CFGname,'CFG');
                        save([cd '\lastIncDecDetectionExp.mat'], 'psyfname', 'fileNames');
                        
                        % Figure out the plotting later
                        f1 = figure;
                        hold on
                        set(f1,'Color', [1 1 1], 'PaperPositionMode', 'auto');
                        set(f1, 'Units', 'centimeters');
                        set(f1, 'Position', [5 5 15 15]);
                        set(gca, 'Color', 'none', 'LineWidth', 1, 'TickDir', 'out');                        
                        for j = 1:length(staircaseIndices)
                            if unique(testSeq(testSeq(:,3)==staircaseIndices(j),1)) == 1 % Increment
                                markerStyle = '^';
                            elseif unique(testSeq(testSeq(:,3)==staircaseIndices(j),1)) == -1 % Decrement
                                markerStyle = 'v';
                            end
                            
                            % First plot the staircase lines
                            xStaircase = 1:CFG.numTrialsPerCondition;
                            plot(xStaircase,trialMatrix(:,j),'k-', 'LineWidth', 2);
                            hold on
                            % Next plot markers indicating
                            % correct/incorrect
                            correctIndices = find(correctMatrix(:,j)==1);
                            incorrectIndices = find(correctMatrix(:,j)==0);
                            plot(xStaircase(correctIndices),trialMatrix(correctIndices,j), markerStyle, ...
                                'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g', 'MarkerSize', 8);                            
                            plot(xStaircase(incorrectIndices),trialMatrix(incorrectIndices,j), markerStyle, ...
                                'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
                            xlabel('Trial number', 'FontSize', 14);
                            ylabel('Stimulus diameter (pixels)', 'FontSize', 14);
                        end                                                       
                    else
                        % Continue experiment
                        getResponse = 1;
                    end
                else
                    getResponse = 1;
                end
                getResponse = 1;
            end
        end
    end
end

function createStimulus(trialIntensity, backgroundIntensity, stimSize, lutFlag,calFile)

% Determine whether a look-up-table correction should be applied to the
% stimulus
% Default calFile
if nargin <4
    calFile = 'C:\Programs\AOMcontrol_V3_2\calibrationData\2018_02_28\15_41_18_calibrationData.mat';
end

if lutFlag == 1
%
[imIntensity] = getNormalizedImageIntensityLevel(trialIntensity, calFile);

else
    imIntensity = trialIntensity;
end

% Now make the circle stimulus
stim_im = double(Circle(stimSize/2)); % Scale by trial intensity
stim_im(stim_im==0) = backgroundIntensity;
stim_im(stim_im==1) = imIntensity;



% Write the stimulus image to the tempStimulus folder
if isdir([pwd,'\tempStimulus']) == 0
    mkdir(pwd,'tempStimulus');
    cd([pwd,'\tempStimulus']);
    blank_im = ones(size(stim_im,1),size(stim_im,2));
    imwrite(stim_im,'frame2.bmp');
    imwrite(blank_im,'frame3.bmp');
else
    cd([pwd,'\tempStimulus']);
end
blank_im = ones(size(stim_im,1),size(stim_im,2));
imwrite(stim_im,'frame2.bmp');
imwrite(blank_im,'frame3.bmp');
imwrite(blank_im,'frame4.bmp');
cd ..;


function startup
dummy=ones(10,10);
if isdir([pwd,'\tempStimulus']) == 0
    mkdir(pwd,'tempStimulus');
    cd([pwd,'\tempStimulus']);
    imwrite(dummy,'frame2.bmp');
    %     fid = fopen('frame2.buf','w');
    %     fwrite(fid,size(dummy,2),'uint16');
    %     fwrite(fid,size(dummy,1),'uint16'); fwrite(fid, dummy, 'double');
    %     fclose(fid);
else
    cd([pwd,'\tempStimulus']);
    delete ('*.*');
    imwrite(dummy,'frame2.bmp');
    %     fid = fopen('frame2.buf','w');
    %     fwrite(fid,size(dummy,2),'uint16');
    %     fwrite(fid,size(dummy,1),'uint16'); fwrite(fid, dummy, 'double');
    %     fclose(fid);
end
cd ..;

function [imIntensity] = getNormalizedImageIntensityLevel(trialIntensity, calFile)
load(calFile);
if exist('calSeq', 'var') && exist('powerReadings', 'var')
    calIndex = 0; % Just look at ascending calibration data for now; reconsider after reworking calibration routine
    keepIndex = find(calSeq(:,2)==calIndex);
    xCalLevels = calSeq(keepIndex,1);
    yPowerReadings = powerReadings(keepIndex,1);
    yPowerReadingsNorm = yPowerReadings./max(yPowerReadings(:));
    imIntensity = round(interp1(yPowerReadingsNorm, xCalLevels, trialIntensity))./255; 
else
    error('Check calibration file');
end

