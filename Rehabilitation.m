function gameMenu()
    fig = uifigure('Name', 'Patient Menu', 'Position', [100, 100, 400, 300]);

    newPatientBtn = uibutton(fig, 'Position', [150, 200, 100, 30], 'Text', ...
        'New Patient', 'ButtonPushedFcn', @(btn, event) newPatient(fig));

    existingPatientBtn = uibutton(fig, 'Position', [150, 150, 100, 30], 'Text', ...
        'Existing Patient', 'ButtonPushedFcn', @(btn, event) existingPatient(fig));

    exitBtn = uibutton(fig, 'Text', 'Exit', 'Position', [150, 100, 100, 30], ...
        'ButtonPushedFcn', @(btn, event) close(fig));
end

function newPatient(fig)
    name = inputdlg('Enter New Patient Name:', 'New Patient');
    if isempty(name)
        return;
    end
    patientName = strtrim(name{1});  
    if isempty(patientName)
        uialert(fig, 'Name cannot be empty!', 'Error');
        return;
    end
    
    idFolder = 'Patients';
    if ~isfolder(idFolder)
        mkdir(idFolder);  
    end

    existingPatients = dir(fullfile(idFolder, 'Patient_*'));
    newID = numel(existingPatients) + 1;  

    patientFolderName = sprintf('Patient_%d_%s', newID, patientName);
    patientFolderPath = fullfile(idFolder, patientFolderName);
    mkdir(patientFolderPath);

    infoFile = fullfile(patientFolderPath, sprintf('Patient_%d_%s.txt', newID, patientName));
    fid = fopen(infoFile, 'w');
    fprintf(fid, 'Patient Name: %s\n', patientName);
    fprintf(fid, 'Patient ID: %d\n', newID);
    fclose(fid);

    if ispc 
    winopen(patientFolderPath);
    end
    
    assignin('base', 'patientName', patientName);
    assignin('base', 'patientID', newID);

    uialert(fig, sprintf('Welcome, %s! Your ID is %d.', patientName, newID), 'New Patient Registered');
    
    showMainMenu(fig);
end

function existingPatient(fig)
    prompt = {'Enter Patient ID:'};
    dlgTitle = 'Existing Patient';
    dims = [1 35];
    patientIDCell = inputdlg(prompt, dlgTitle, dims);

    if isempty(patientIDCell)
        return;
    end

    patientID = str2double(patientIDCell{1});

    if isnan(patientID) || patientID <= 0
        uialert(fig, 'Invalid Patient ID. Please enter a valid number.', 'Error');
        return;
    end

    idFolder = 'Patients';
    patientFolders = dir(fullfile(idFolder, sprintf('Patient_%d_*', patientID)));

    if isempty(patientFolders)
        uialert(fig, 'Patient folder not found! Please check the records.', 'Error');
        return;
    end

    patientFolderName = patientFolders(1).name;
    patientFolderPath = fullfile(idFolder, patientFolderName);

    tokens = regexp(patientFolderName, sprintf('Patient_%d_(.*)', patientID), 'tokens');
    if ~isempty(tokens) && ~isempty(tokens{1})
        patientName = tokens{1}{1};
        assignin('base', 'patientName', patientName);
        assignin('base', 'patientID', patientID);
    else
        uialert(fig, 'Failed to extract patient name. Please check the folder format.', 'Error');
        return;
    end

    if isfolder(patientFolderPath)
        winopen(patientFolderPath);
        uialert(fig, sprintf('Welcome back, %s! Your folder: %s', patientName, patientFolderName), 'Existing Patient');
        showMainMenu(fig); 
    else
        uialert(fig, 'Patient folder not found! Please check the records.', 'Error');
    end
end

function showMainMenu(fig)
    fig.Visible = 'off';
    delete(fig);

    mainFig = uifigure('Name', 'Game Menu', 'Position', [100, 100, 400, 300]);

    history = uibutton(mainFig, 'Position', [150, 250, 100, 30], 'Text', ...
        'history', 'ButtonPushedFcn', @(btn, event) plotTimeScoreMatrix());

    calBtn = uibutton(mainFig, 'Position', [150, 200, 100, 30], 'Text', ...
        'Calibration', 'ButtonPushedFcn', @(btn, event) startCalibration(), 'Enable', 'off');

    loadBtn = uibutton(mainFig, 'Text', 'Load Data', 'Position', [150, 150, 100, 30], ...
        'ButtonPushedFcn', @(btn, event) loadData());

    startBtn = uibutton(mainFig, 'Text', 'Start Game', 'Position', [150, 100, 100, 30], ...
        'ButtonPushedFcn', @(btn, event) StartGame(mainFig));

    exitBtn = uibutton(mainFig, 'Text', 'Exit', 'Position', [150, 50, 100, 30], ...
        'ButtonPushedFcn', @(btn, event) close(mainFig));

    patientName = evalin('base', 'patientName');
    patientID = evalin('base', 'patientID');

    if ~isempty(patientName) && ~isempty(patientID)
        calBtn.Enable = 'on'; 
    end
end

function startCalibration()
    patientName = evalin('base', 'patientName');
    patientID = evalin('base', 'patientID');

    idFolder = 'Patients';
    patientFolderName = sprintf('Patient_%d_%s', patientID, patientName);
    patientFolderPath = fullfile(idFolder, patientFolderName);

    if ~isfolder(patientFolderPath)
        uialert(fig, 'Patient folder not found!', 'Error');
        return;
    end

    dataFiles = dir(fullfile(patientFolderPath, 'calibration_data_*.mat'));
    fileCount = numel(dataFiles); 
    newFileName = sprintf('calibration_data_%d.mat', fileCount + 1);
    dataFilePath = fullfile(patientFolderPath, newFileName);

    comPort = "COM11";
    baudRate = 9600;
    arduinoObj = serialport(comPort, baudRate);

    configureTerminator(arduinoObj, "LF");
    arduinoObj.Timeout = 10;

    figure;
    hold on;
    grid on;
    xlabel('Time (s)');
    ylabel('Sensor Value');
    title('Real-time Data from Arduino');
    dataPlot = plot(NaN, NaN); 
    startTime = datetime('now');
    sensorData = [];
    timeStamps = [];

    disp('Reading data from Arduino. Press Ctrl+C to stop.');

    while true
        data = readline(arduinoObj);

        sensorValue = str2double(data);

        if ~isnan(sensorValue)
            sensorValue = sensorValue/1024;
            currentTime = seconds(datetime('now') - startTime);
            timeStamps = [timeStamps, currentTime];
            sensorData = [sensorData, sensorValue];
            dataa = sensorData;
            time = timeStamps;
            set(dataPlot, 'XData', timeStamps, 'YData', sensorData);
            drawnow;

            save(dataFilePath, 'dataa', 'time');
        end
    end
end

function loadData()
    patientName = evalin('base', 'patientName');
    patientID = evalin('base', 'patientID');

    idFolder = 'Patients';
    patientFolderName = sprintf('Patient_%d_%s', patientID, patientName);
    patientFolderPath = fullfile(idFolder, patientFolderName);

    if ~isfolder(patientFolderPath)
        error('Patient folder not found!'); 
    end

    dataFiles = dir(fullfile(patientFolderPath, 'calibration_data_*.mat'));
    fileCount = numel(dataFiles); 

    if fileCount == 0
        error('No calibration data files found!');
    end

    latestFile = fullfile(patientFolderPath, dataFiles(fileCount).name);
    loadedData = load(latestFile); 

    if isfield(loadedData, 'dataa')
        calibrationData = loadedData.dataa;
    else
        error('The loaded file does not contain "data" variable.');
    end

    min_data = min(calibrationData);
    max_data = max(calibrationData);

    assignin('base', 'min_data', min_data);
    assignin('base', 'max_data', max_data);

    disp(['Calibration complete. Min: ', num2str(min_data), ', Max: ', num2str(max_data)]);
end


function StartGame(fig)
    min_data = evalin('base', 'min_data');
    max_data = evalin('base', 'max_data');
    
    if isempty(min_data) || isempty(max_data)
        uialert(fig, 'Please load data for calibration first!', 'Calibration Error');
        return;
    end
    
    screen_height = 600;
    bird_radius = 15;

    gameFig = uifigure('Name', 'Flappy Bird Game', 'Position', [100, 100, 800, 600]);
    timerLabel = uilabel(gameFig, 'Position', [20, 580, 100, 30], 'Text', 'Time: 0');
    scoreLabel = uilabel(gameFig, 'Position', [120, 580, 100, 30], 'Text', 'Score: 0');

    setupGameGraphics(gameFig, bird_radius, screen_height, min_data, max_data, timerLabel,scoreLabel);
end

function setupGameGraphics(gameFig, bird_radius, screen_height, min_data, max_data,timerLabel,scoreLabel)
    screen_width = 800;
    bird_screen_x = 300;  
    scroll_speed = 5;  
    gap_height = 100;  
    obstacle_width = 50;  

    ax = axes(gameFig, 'Position', [0, 0, 1, 1]);
    axis off;
    axis equal;
    
    bird = plot(ax, bird_screen_x, screen_height / 2, 'o', 'MarkerSize', bird_radius, 'MarkerFaceColor', '#EDB120', 'MarkerEdgeColor','#EDB120');
    title(ax, 'Flappy Bird Game - MATLAB');
    hold on;
    
    bird_y = 0;
    %bird_y = screen_height / 2; 
    obstacles = [];
    axis(ax, [0, screen_width, 0, screen_height]);

    startTime = tic;  
    obstacleTimer = tic; 

    random_interval = 10;
    score = 0;

    comPort = "COM11";
    baudRate = 9600;
    arduinoObj = serialport(comPort, baudRate);
    configureTerminator(arduinoObj, "LF");
    arduinoObj.Timeout = 5;
    previousOutput = 0;
    alpha = 0.05;

    while true
        try
            data = readline(arduinoObj);  
            sensorValue = str2double(data);  
            if ~isnan(sensorValue)
                sensorValue = sensorValue/1024;
                normalized = sensorValue / (0.6*(max_data - min_data)); 

                smoothedOutput = alpha * normalized + (1 - alpha) * previousOutput;
                previousOutput = smoothedOutput; 

                bird_y = max(bird_radius, min(screen_height - bird_radius, smoothedOutput * screen_height));
            else
                disp('Invalid data received from Arduino.');
            end
        catch ME
            disp(['Error reading from Arduino: ', ME.message]);
        end

        set(bird, 'XData', bird_screen_x, 'YData', bird_y);
           
        elapsedTime1 = toc(startTime); 
        timerLabel.Text = sprintf('Time: %.2f', elapsedTime1); 
        scoreLabel.Text = sprintf('Score: %d', score);  

        k = get(gameFig, 'CurrentCharacter');
        if strcmp(k, 27) 
            break; 
        end

        elapsedTime2 = toc(obstacleTimer); 

        if elapsedTime2 >= random_interval  
            generateObstacle();  
            obstacleTimer = tic;  
            random_interval = randi([7, 13]);
        end

        for i = 1:2:length(obstacles)
            top_obstacle = obstacles(i);
            bottom_obstacle = obstacles(i + 1);

            if isvalid(top_obstacle) && isvalid(bottom_obstacle)
                top_obstacle.Position(1) = top_obstacle.Position(1) - scroll_speed;
                bottom_obstacle.Position(1) = bottom_obstacle.Position(1) - scroll_speed;
            end

            bird_left = bird_screen_x - bird_radius;

            obs_right = top_obstacle.Position(1);

            if top_obstacle.Position(1) == 225
            score = score + 10; 
            set(scoreLabel, 'Text', sprintf('Score: %d', score));  
            end

            if checkCollision(bird, top_obstacle, bird_radius) || checkCollision(bird, bottom_obstacle, bird_radius)
                uialert(gameFig, 'Game Over! You hit an obstacle!', 'Game Over');
                saveGameTimeScore(elapsedTime1,score);
                uiwait(gameFig , 3)
                close(gameFig);
                return;
            end
        end

        drawnow;
        pause(0.001);
    end


    function generateObstacle()
        gap_position = randi([150, screen_height - gap_height - 150]);

        top_obstacle = rectangle('Position', [screen_width, gap_position + gap_height, obstacle_width, screen_height - gap_position - gap_height], ...
            'FaceColor', "#0072BD", 'EdgeColor', "#0072BD", 'Curvature', 0.2, 'Parent', ax);
        bottom_obstacle = rectangle('Position', [screen_width, 0, obstacle_width, gap_position], ...
            'FaceColor', "#0072BD", 'EdgeColor', "#0072BD", 'Curvature', 0.2, 'Parent', ax);
        
        obstacles = [obstacles, top_obstacle, bottom_obstacle];
    end

    function collided = checkCollision(bird, obstacle, bird_radius)
        bird_x = bird.XData;
        bird_y = bird.YData;
        bird_left = bird_x - bird_radius;
        bird_right = bird_x + bird_radius;
        bird_top = bird_y + bird_radius;
        bird_bottom = bird_y - bird_radius;

        obs_left = obstacle.Position(1);
        obs_right = obstacle.Position(1) + obstacle.Position(3);
        obs_top = obstacle.Position(2) + obstacle.Position(4);
        obs_bottom = obstacle.Position(2);

        if (bird_right > obs_left && bird_left < obs_right && bird_top > obs_bottom && bird_bottom < obs_top)
            collided = true;
        else
            collided = false;
        end
    end
end

function saveGameTimeScore(elapsedTime, score)
    patientName = evalin('base', 'patientName');
    patientID = evalin('base', 'patientID');

    idFolder = 'Patients';
    patientFolderName = sprintf('Patient_%d_%s', patientID, patientName);
    patientFolderPath = fullfile(idFolder, patientFolderName);
    infoFile = fullfile(patientFolderPath, sprintf('Patient_%d_%s.txt', patientID, patientName));

    timeMatrix = [];
    scoreMatrix = [];
    
    if isfile(infoFile)
        fid = fopen(infoFile, 'r');
        data = textscan(fid, '%s', 'Delimiter', '\n');
        fclose(fid);

        for i = 1:length(data{1})
            line = data{1}{i};
            if contains(line, 'Time Matrix =')
                timeMatrix = str2num(strrep(line, 'Time Matrix =', '')); 
            elseif contains(line, 'Score Matrix =')
                scoreMatrix = str2num(strrep(line, 'Score Matrix =', '')); 
            end
        end
    end

    timeMatrix = [timeMatrix, elapsedTime];
    scoreMatrix = [scoreMatrix, score];

    fid = fopen(infoFile, 'w');  
    fprintf(fid, 'Time Matrix = [%s]\n', num2str(timeMatrix, '%.2f '));
    fprintf(fid, 'Score Matrix = [%s]\n', num2str(scoreMatrix, '%.0f '));
    fclose(fid);
end


function plotTimeScoreMatrix()
    patientName = evalin('base', 'patientName');
    patientID = evalin('base', 'patientID');

    idFolder = 'Patients';
    patientFolderName = sprintf('Patient_%d_%s', patientID, patientName);
    patientFolderPath = fullfile(idFolder, patientFolderName);
    infoFile = fullfile(patientFolderPath, sprintf('Patient_%d_%s.txt', patientID, patientName));

    timeMatrix = [];
    if isfile(infoFile)
        fid = fopen(infoFile, 'r');
        data = textscan(fid, '%s', 'Delimiter', '\n');
        fclose(fid);

        for i = 1:length(data{1})
            line = data{1}{i};
            if contains(line, 'Time Matrix =')
                timeMatrix = str2num(strrep(line, 'Time Matrix =', '')); %#ok<ST2NM>
                break;
            end
        end
    end

    ScoreMatrix = [];
    if isfile(infoFile)
      fids = fopen(infoFile, 'r');
      datas = textscan(fids, '%s', 'Delimiter', '\n');
      fclose(fids);

        for i = 1:length(datas{1})
            lines = datas{1}{i}; 
            if contains(lines, 'Score Matrix =')
                ScoreMatrix = str2num(strrep(lines, 'Score Matrix =', '')); 
                break;
            end
        end
    end
    
     if ~isempty(timeMatrix)
      figure; 
      subplot(2,1,1)
      plot(timeMatrix, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'b');
      title('Game Time History');
      xlabel('Game Index');
      ylabel('Time(s)');
      grid on;
    else
      errordlg('No score matrix found to plot.', 'Error');
    end

    if ~isempty(ScoreMatrix)
        subplot(2,1,2) 
      plot(ScoreMatrix, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'r');
      title('Game Score History');
      xlabel('Game Index');
      ylabel('Score');
      grid on;
    else
      errordlg('No score matrix found to plot.', 'Error');
    end

end
