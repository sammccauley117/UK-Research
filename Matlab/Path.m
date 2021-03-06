% ************************************************** %
% Title:     Path.m                                  %
% Purpose:   Uses Machine Learning to create a model %
%            for basic path finding                  %
% Aurthor:   Sam McCauley                            %
% Professor: Dr. Daniel Lau                          %
% Date:      7/8/2018                                %
% ************************************************** %

% Global Variables
global BOARD_ROWS;  BOARD_ROWS  = 100;     % How many rows    are on the board
global BOARD_COLS;  BOARD_COLS  = 100;     % How many columns are on the board
global ROBOT;       ROBOT       = 1;     % Which number denotes the robot
global DESTINATION; DESTINATION = -1;    % Which number denotes the destination
global DATA_LEN;    DATA_LEN    = 5000;  % How much data should be generated from generateData()
global TEST_LEN;    TEST_LEN    = 50;  % How many random instances of data should be generated to test accuracy
global ANIM_DELAY;  ANIM_DELAY  = .25;   % How long the delay between animation frames is

% Reinforcement Learning
reinforcementHybrid()

% Delta Method 
% model = delta("discr", false); % Get a Delta Method model without popularity and using Discriminant Analysis
                               % Should take a minute to train
% animateModel(model, 50);       % Animate 50 paths of the model

% Delta Iteration Method
% models = deltaIteration("discr");
% animateModelIter(models, 50);

% Prediction Iteration Method
% models = predictionIteration("knn");
% animateModelIter(models, 50);

function reinforcementHybrid()
    % Variables
    global DATA_LEN;
    global BOARD_ROWS;
    global BOARD_COLS;
    global ROBOT;
    global DESTINATION;
    
    RL_R_Row = [0];  RL_R_Col  = [0];
    RL_D_Row = [0];  RL_D_Col  = [0];
    RL_Move  = [0];  RL_Reward = [0];
    % 1 = up
    % 2 = down
    % 3 = left
    % 4 = right
    
    % Theorectically try every action for each instance to try to learn
    [robotRows, robotCols, destRows, destCols] = generateData(DATA_LEN);
    for i = 1:DATA_LEN*4 % *4 because we must check all 4 possible actions
         index = ceil(i/4) % Adjust index to account for the *4
         preDistance  = abs(robotRows(index) - destRows(index)) + abs(robotCols(index) - destCols(index)); % Distance before move
         postDistance = 0; % Distance after move
         move = 0;
         RL_R_Row(i) = robotRows(index);
         RL_R_Col(i) = robotCols(index);
         RL_D_Row(i) = destRows(index);
         RL_D_Col(i) = destCols(index);
         
         if     rem(i,4) == 1
             RL_Move(i) = 1;
             postDistance = abs(robotRows(index) - 1 - destRows(index)) + abs(robotCols(index) - destCols(index));
         elseif rem(i,4) == 2
             RL_Move(i) = 2;
             postDistance = abs(robotRows(index) + 1 - destRows(index)) + abs(robotCols(index) - destCols(index));
         elseif rem(i,4) == 3
             RL_Move(i) = 3;
             postDistance = abs(robotRows(index) - destRows(index)) + abs(robotCols(index) - 1 - destCols(index));
         else
             RL_Move(i) = 4;
             postDistance = abs(robotRows(index) - destRows(index)) + abs(robotCols(index) + 1 - destCols(index));
         end
         
         if(postDistance < preDistance)
             RL_Reward(i) = 1;  % Move made distance shorter, good job
         else
             RL_Reward(i) = -1; % Move made distance longer,  bad  job
         end
    end
    
    % m = zeros(6, 6);
    % m(RL_R_Row(1), RL_R_Col(1)) = 1;
    % m(RL_D_Row(1), RL_D_Col(1)) = -1;
    
    data = table(RL_R_Row', RL_R_Col', RL_D_Row', RL_D_Col', RL_Move', RL_Reward');
    data.Properties.VariableNames = {'RobotRow' 'RobotCol' 'DestRow' 'DestCol' 'Move' 'Reward'};
    
    % Create a model
    model = fitctree(data, 'Reward')
    
    % Test model
    [rr, rc, dr, dc] = generateData(1000);
    pause on;
    numRight = 0;
    for i = 1:1000
        board = zeros(BOARD_ROWS, BOARD_COLS);
        board(rr(i), rc(i)) = ROBOT;
        board(dr(i), dc(i)) = DESTINATION;
        showBoard(board);
        
        valid = false;
        x = 0;
        while(~valid)
            [RR, RC, DR, DC] = findCoords(board);
            upFeatures    = [RR,RC,DR,DC,1];
            downFeatures  = [RR,RC,DR,DC,2];
            leftFeatures  = [RR,RC,DR,DC,3];
            rightFeatures = [RR,RC,DR,DC,4];
            if(predict(model, upFeatures) == 1)
                board = moveRobot(board, "up");
            elseif(predict(model, downFeatures) == 1)
                board = moveRobot(board, "down");
            elseif(predict(model, leftFeatures) == 1)
                board = moveRobot(board, "left");
            elseif(predict(model, rightFeatures) == 1)
                board = moveRobot(board, "right");
            end
            x = x + 1;
            showBoard(board);
            pause(.05);
            
            % Update Valid
            found = false;
            for row = (1:BOARD_ROWS)
                for col = (1:BOARD_COLS)
                    if (board(row,col) == DESTINATION)
                        found = true;
                    end
                end
            end
            valid = ~found;
            if valid
                numRight = numRight + 1; 
            end
            if x > BOARD_ROWS + BOARD_COLS
                valid = true;
            end
        end
    end
    numRight
    p = numRight / 1000
end

function models = deltaIteration(modelType)
    % Variables
    global DATA_LEN;
    global BOARD_ROWS;
    global BOARD_COLS;
    global ROBOT;
    global DESTINATION;
    tic; % Begin stop watch for timing
    trainTime = 0.0; % Time it takes to train the model  
    modelAccuracy = 0.0;
    [robotRows, robotCols, destRows, destCols, moves] = generateData(DATA_LEN);
    rr = {robotRows'};
    rc = {robotCols'};
    dr = {destRows'};
    dc = {destCols'};
    m  = {moves'};
    
    % Train Initial Model
    iteration = 1; % Current model iteration
    data = table(rr{iteration}, rc{iteration}, dr{iteration}, dc{iteration}, m{iteration});
    data.Properties.VariableNames = {'RobotRow' 'RobotCol' 'DestRow' 'DestCol' 'Move'};
    model  = getModel(modelType, data);
    models = {model}; % Create cell array of models
    
    noMoves = 1; % How many times "no move" appears in moves[]
    % Keep checking previous iterations until there is no "no move"
    while(noMoves ~= 0)
        iteration = iteration + 1; % Begin new iteration
        fprintf("No Moves: %d     Iteration: %d\n",noMoves, iteration - 1);
        
        % Copy previous iteration data 
        rr{iteration} = rr{iteration - 1};
        rc{iteration} = rc{iteration - 1};
        dr{iteration} = dr{iteration - 1};
        dc{iteration} = dc{iteration - 1};
        m{iteration}  = m{iteration  - 1};
        
        % Check for patterns in previous iteration
        noMoves = 0;
        for i = 1:DATA_LEN
            if m{iteration}(i) == "no move"
                noMoves = noMoves + 1;
                for j = 1:DATA_LEN
                    if(m{iteration - 1}(j) ~= "no move")
                        if (rr{iteration}(i)     + 1 - dr{iteration}(i)     == ...
                            rr{iteration - 1}(j)     - dr{iteration - 1}(j) && ...
                            rc{iteration}(i)         - dc{iteration}(i)     == ...
                            rc{iteration - 1}(j)     - dc{iteration - 1}(j))
                            m{iteration}(i) = "down";
                            break;
                        end
                        if (rr{iteration}(i)    - 1 - dr{iteration}(i)     == ...
                            rr{iteration - 1}(j)    - dr{iteration - 1}(j) && ...
                            rc{iteration}(i)        - dc{iteration}(i)     == ...
                            rc{iteration - 1}(j)    - dc{iteration - 1}(j))
                            m{iteration}(i) = "up";
                            break;
                        end
                        if (rr{iteration}(i)         - dr{iteration}(i)     == ...
                            rr{iteration - 1}(j)     - dr{iteration - 1}(j) && ...
                            rc{iteration}(i)     + 1 - dc{iteration}(i)     == ...
                            rc{iteration - 1}(j)     - dc{iteration - 1}(j))
                            m{iteration}(i) = "right";
                            break;
                        end
                        if (rr{iteration}(i)         - dr{iteration}(i)     == ...
                            rr{iteration - 1}(j)     - dr{iteration - 1}(j) && ...
                            rc{iteration}(i)     - 1 - dc{iteration}(i)     == ...
                            rc{iteration - 1}(j)     - dc{iteration - 1}(j))
                            m{iteration}(i) = "left";
                            break;
                        end
                    end
                end
            end
        end
        
        % Create and push new model using updated data
        data = table(rr{iteration}, rc{iteration}, dr{iteration}, dc{iteration}, m{iteration});
        data.Properties.VariableNames = {'RobotRow' 'RobotCol' 'DestRow' 'DestCol' 'Move'};
        model  = getModel(modelType, data);
        models{iteration} = model; % Push model
    end
    
    trainTime = toc; % Model trained, clock in timer
    
    modelAccuracy = calcAccuracyIter(models); % Test accuracy of model
    
    % Data logging info
    fprintf("%d,%d,%d,%s,%.2f,%.2f\n", BOARD_ROWS, BOARD_COLS, DATA_LEN, modelType, trainTime, (modelAccuracy*100));
end

function models = predictionIteration(modelType)
    % Variables
    global DATA_LEN;
    global BOARD_ROWS;
    global BOARD_COLS;
    global ROBOT;
    global DESTINATION;
    tic; % Begin stop watch for timing
    trainTime = 0.0; % Time it takes to train the model  
    modelAccuracy = 0.0;
    [robotRows, robotCols, destRows, destCols, moves] = generateData(DATA_LEN);
    
    % Train Initial Model
    data = table(robotRows', robotCols', destRows', destCols', moves');
    data.Properties.VariableNames = {'RobotRow' 'RobotCol' 'DestRow' 'DestCol' 'Move'};
    model  = getModel(modelType, data);
    models = {model}; % Create cell array of models
    
    noMoves = 1;
    iteration = 1;
    while noMoves ~= 0
        [robotRows, robotCols, destRows, destCols, moves] = generateData(DATA_LEN);
        for i = 1:DATA_LEN
            if moves(i) == "no move"
                moves(i) = checkPreviousIter(models{iteration},robotRows(i),robotCols(i),destRows(i),destCols(i));
            end
        end
        
        % Check how many "no move"s there are after checkSurrounging
        noMoves = 0;
        for i = 1:DATA_LEN
            if moves(i) == "no move"
                noMoves = noMoves + 1;
            end
        end
        
        % fprintf("%d / %d\n", noMoves, DATA_LEN);
        
        data = table(robotRows', robotCols', destRows', destCols', moves');
        data.Properties.VariableNames = {'RobotRow' 'RobotCol' 'DestRow' 'DestCol' 'Move'};
        model = getModel(modelType, data);
        iteration = iteration + 1;
        models{iteration} = model;
    end
    
    % trainTime = toc; % Model trained, clock in timer
    
    % modelAccuracy = calcAccuracyIter(models); % Test accuracy of model
    
    % Data logging info
    % fprintf("%d,%d,%d,%s,%.2f,%.2f\n", BOARD_ROWS, BOARD_COLS, DATA_LEN, modelType, trainTime, (modelAccuracy*100));
end

% Trains a model based on the delta method of previous iterations
% Uses additional popularity method if 'popularity' is set to true
function model = delta(modelType, popularity)
    % Variables
    global DATA_LEN;
    global BOARD_ROWS;
    global BOARD_COLS;
    global ROBOT;
    global DESTINATION;
    tic; % Begin stop watch for timing
    trainTime = 0.0; % Time it takes to train the model  
    modelAccuracy = 0.0;
    valid = false;
    [robotRows, robotCols, destRows, destCols, moves] = generateData(DATA_LEN);
    
    % Keep checking previous iterations until there is no "no move"
    while(~valid)
        % Check previous iterations
        numNoMoves = 0; % How many times "no move" appears in moves[]
        for i = 1:DATA_LEN
            % if(rem(i, 100) == 0)
            %    fprintf("%d / %d\n", i, DATA_LEN); 
            % end
            if(moves(i) == "no move")
                numNoMoves = numNoMoves + 1;
                % Count how many times each suggested move comes up
                % to pick the best (used only if 'popularity' is true
                up    = 0; 
                down  = 0;
                left  = 0;
                right = 0;
                for j = 1:DATA_LEN
                    if(moves(j) ~= "no move")
                        if (robotRows(i) + 1 - destRows(i) == ...
                            robotRows(j)     - destRows(j) && ...
                            robotCols(i)     - destCols(i) == ...
                            robotCols(j)     - destCols(j))
                            if popularity
                                down = down + 1;
                            else
                                moves(i) = "down";
                                break;
                            end
                        end
                        if (robotRows(i) - 1 - destRows(i) == ...
                            robotRows(j)     - destRows(j) && ...
                            robotCols(i)     - destCols(i) == ...
                            robotCols(j)     - destCols(j))
                            if popularity
                                up = up + 1;
                            else
                                moves(i) = "up";
                                break;
                            end
                        end
                        if (robotRows(i)     - destRows(i) == ...
                            robotRows(j)     - destRows(j) && ...
                            robotCols(i) + 1 - destCols(i) == ...
                            robotCols(j)     - destCols(j))
                            if popularity
                                right = right + 1;
                            else
                                moves(i) = "right";
                                break;
                            end
                        end
                        if (robotRows(i)     - destRows(i) == ...
                            robotRows(j)     - destRows(j) && ...
                            robotCols(i) - 1 - destCols(i) == ...
                            robotCols(j)     - destCols(j))
                            if popularity
                                left = left + 1;
                            else
                                moves(i) = "left";
                                break;
                            end
                        end
                    end
                end
                % fprintf("up: %d     down: %d     left: %d     right: %d\n", up, down, left, right);
                % Find most common suggested pattern
                if (up ~= 0 && up >= down && up >= left && up >= right)
                    % fprintf("up\n");
                    moves(i) = "up"
                end
                if (down ~= 0 && down >= up && down >= left && down >= right)
                    % fprintf("down\n");
                    moves(i) = "down"
                end
                if (left ~= 0 && left >= up && left >= down && left >= right)
                    % fprintf("left\n");
                    moves(i) = "left"
                end
                if (right ~= 0 && right >= up && right >= down && right >= left)
                    % fprintf("right\n");
                    moves(i) = "right"
                end
            end
        end
        % fprintf("'No Moves' Left: %d\n", numNoMoves);
        valid = numNoMoves == 0;
    end
    
    % Now that every spot has a classification, we can train the model
    data = table(robotRows', robotCols', destRows', destCols', moves');
    data.Properties.VariableNames = {'RobotRow' 'RobotCol' 'DestRow' 'DestCol' 'Move'};
    model = getModel(modelType, data);
    trainTime = toc; % Model trained, clock in timer
    
    % Test accuracy of model
    modelAccuracy = calcAccuracy(model);
    
    % Data logging info
    % fprintf("Board: %dx%d\tTrain Data Length: %d\tModel Type: %s\tTrain Time: %d\tAccuracy: %d", BOARD_ROWS, BOARD_COLS, DATA_LEN, modelType, trainTime, modelAccuracy);
    fprintf("%d,%d,%d,%s,%.2f,%.2f\n", BOARD_ROWS, BOARD_COLS, DATA_LEN, modelType, trainTime, (modelAccuracy*100));
end

% Show animation of a model using model cell array iteration
function animateModelIter(models, numToShow)
    global BOARD_ROWS;
    global BOARD_COLS;
    global ROBOT;
    global DESTINATION;
    global ANIM_DELAY;
    pause on;
    [robotRows, robotCols, destRows, destCols, moves] = generateData(numToShow);
    [x, modelsLen] = size(models);

    for i = 1:numToShow
        valid = false;
        board = zeros(BOARD_ROWS, BOARD_COLS);
        board(robotRows(i), robotCols(i)) = ROBOT;
        board(destRows(i),  destCols(i))  = DESTINATION;
        showBoard(board);
        pause(.5);
        x = 0;
        while(~valid)
            [rr, rc, dr, dc] = findCoords(board);
            features = [rr, rc, dr, dc];
            m = "no move";
            for iter = 1:modelsLen
                m = predict(models{iter}, features);
                if m ~= "no move"
                    break;
                end
            end
            board = moveRobot(board, m);
            showBoard(board);
            pause(ANIM_DELAY);
            x = x + 1;

            % Update Valid
            found = false;
            for row = (1:BOARD_ROWS)
                for col = (1:BOARD_COLS)
                    if (board(row,col) == DESTINATION)
                        found = true;
                    end
                end
            end
            valid = ~found;
            if x > BOARD_ROWS + BOARD_COLS
                valid = true;
            end
        end
    end
end

% Show animation of a model running
function animateModel(model, numToShow)
    global BOARD_ROWS;
    global BOARD_COLS;
    global ROBOT;
    global DESTINATION;
    global ANIM_DELAY;
    pause on;
    [robotRows, robotCols, destRows, destCols, moves] = generateData(numToShow);

    for i = 1:numToShow
        valid = false;
        board = zeros(BOARD_ROWS, BOARD_COLS);
        board(robotRows(i), robotCols(i)) = ROBOT;
        board(destRows(i),  destCols(i))  = DESTINATION;
        showBoard(board);
        pause(ANIM_DELAY);
        x = 0;
        while(~valid)
            [rr, rc, dr, dc] = findCoords(board);
            features = [rr, rc, dr, dc];
            m = predict(model, features);
            board = moveRobot(board, m);
            showBoard(board);
            pause(ANIM_DELAY);
            x = x + 1;

            % Update Valid
            found = false;
            for row = (1:BOARD_ROWS)
                for col = (1:BOARD_COLS)
                    if (board(row,col) == DESTINATION)
                        found = true;
                    end
                end
            end
            valid = ~found;
            if x > BOARD_ROWS + BOARD_COLS
                valid = true;
            end
        end
    end
end

% Returns the model based on the passed modelType
function model = getModel(modelType, data)
    if(modelType     == "nb")       % Naive Bayes
        model = fitcnb(data,     'Move');
    elseif(modelType == "tree")     % Tree
        model = fitctree(data,   'Move');
    elseif(modelType == "knn")      % K Nearest Number
        model = fitcknn(data,    'Move');
    elseif(modelType == "discr")    % Discriminant
        model = fitcdiscr(data,  'Move');
    elseif(modelType == "linear")   % Linear
        model = fitclinear(data, 'Move');
    elseif(modelType == "kernel")   % Gaussian Kernel
        model = fitckernel(data, 'Move');
    end
end

% Calc accuracy of a model using cell array of models
function accuracy = calcAccuracyIter(models)
    % Variables
    global TEST_LEN;
    global ROBOT;
    global DESTINATION;
    global BOARD_ROWS;
    global BOARD_COLS;
    numCorrect = 0;
    [robotRows, robotCols, destRows, destCols] = generateData(TEST_LEN);
    [x, modelsLen] = size(models);

    for i = 1:TEST_LEN
        % Initialize board
        board = zeros(BOARD_ROWS, BOARD_COLS);
        board(robotRows(i), robotCols(i)) = ROBOT;
        board(destRows(i),  destCols(i))  = DESTINATION;
        rr = robotRows(i); rc = robotCols(i);
        dr = destRows(i);  dc = destCols(i);
        next = false; % Becomes true when either robot reaches the dest or too many moves pass
        numMoves = 0;
        maxMoves = BOARD_ROWS + BOARD_COLS;
        while(~next) % Loop through moves until either the robot makes it to dest or gets stuck
            features = [rr, rc, dr, dc];
            move = "no move";
            for iter = 1:modelsLen
                move = predict(models{iter}, features);
                if(move ~= "no move")
                    break; 
                end
            end 
            if(move == "no move")
                next = true;
            else
                board = moveRobot(board, move);
                numMoves = numMoves + 1;
                [rr, rc, dr, dc] = findCoords(board);
                if(dr == -1 && dc == -1) % Robot made it to dest
                    next = true;
                    numCorrect = numCorrect + 1;
                elseif numMoves > maxMoves
                    next = true;
                end
            end
        end
    end
    accuracy = numCorrect / TEST_LEN;
end

% Test how accurate a given model is
function accuracy = calcAccuracy(model)
    % Variables
    global TEST_LEN;
    global ROBOT;
    global DESTINATION;
    global BOARD_ROWS;
    global BOARD_COLS;
    numCorrect = 0;
    [robotRows, robotCols, destRows, destCols] = generateData(TEST_LEN);

    for i = 1:TEST_LEN
        % Initialize board
        board = zeros(BOARD_ROWS, BOARD_COLS);
        board(robotRows(i), robotCols(i)) = ROBOT;
        board(destRows(i),  destCols(i))  = DESTINATION;
        rr = robotRows(i); rc = robotCols(i);
        dr = destRows(i);  dc = destCols(i);
        next = false; % Becomes true when either robot reaches the dest or too many moves pass
        numMoves = 0;
        maxMoves = BOARD_ROWS + BOARD_COLS;
        while(~next) % Loop through moves until either the robot makes it to dest or gets stuck
            features = [rr, rc, dr, dc];
            move = predict(model, features);
            board = moveRobot(board, move);
            numMoves = numMoves + 1;
            [rr, rc, dr, dc] = findCoords(board);
            if(dr == -1 && dc == -1) % Robot made it to dest
                next = true;
                numCorrect = numCorrect + 1;
            elseif numMoves > maxMoves
                next = true;
            end
        end
    end
    accuracy = numCorrect / TEST_LEN;
end

function [robotRow, robotCol, destRow, destCol] = findCoords(board)
    % Variables
    global BOARD_ROWS;
    global BOARD_COLS;
    global ROBOT;
    global DESTINATION;
    robotRow = -1;
    robotCol = -1;
    destRow  = -1;
    destCol  = -1;

    % Get x,y for the robot and destination
    for row = (1:BOARD_ROWS)
        for col = (1:BOARD_COLS)
            if (board(row,col) == ROBOT)
                robotRow = row;
                robotCol = col;
            end
            if (board(row,col) == DESTINATION)
                destRow  = row;
                destCol  = col;
            end
        end
    end
end

function board = moveRobot(board, move)
    % Variables
    global BOARD_ROWS; 
    global BOARD_COLS;
    global ROBOT;
    [robotRow, robotCol, destRow, destCol] = findCoords(board);
    
    if(move == "up" && robotRow - 1 >= 1)
        board(robotRow, robotCol)     = 0;
        board(robotRow - 1, robotCol) = ROBOT;
    end
    if(move == "down" && robotRow + 1 <= BOARD_ROWS)
        board(robotRow, robotCol)     = 0;
        board(robotRow + 1, robotCol) = ROBOT;
    end
    if(move == "left" && robotCol - 1 >= 1)
        board(robotRow, robotCol)     = 0;
        board(robotRow, robotCol - 1) = ROBOT;
    end
    if(move == "right" && robotCol + 1 <= BOARD_COLS)
        board(robotRow, robotCol)     = 0;
        board(robotRow, robotCol + 1) = ROBOT;
    end
end

% Uses previous iterations of the model to update "no move"s 
function move = checkPreviousIter(model, robotRow, robotCol, destRow, destCol)
    % Variables
    global BOARD_ROWS;
    global BOARD_COLS;
    move = "no move"; % Default value
    
    if(move == "no move" && robotRow + 1 <= BOARD_ROWS)
       features = [robotRow+1, robotCol, destRow, destCol];
       predictedMove = predict(model, features);
       if(predictedMove ~= "no move")
           move = predictedMove;
       end 
    end
    
    if(move == "no move" && robotRow - 1 >= 1)
       features = [robotRow-1, robotCol, destRow, destCol];
       predictedMove = predict(model, features);
       if(predictedMove ~= "no move")
           move = predictedMove;
       end 
    end
    
    if(move == "no move" && robotCol + 1 <= BOARD_COLS)
       features = [robotRow, robotCol+1, destRow, destCol];
       predictedMove = predict(model, features);
       if(predictedMove ~= "no move")
           move = predictedMove;
       end 
    end
    
    if(move == "no move" && robotCol - 1 >= 1)
       features = [robotRow, robotCol-1, destRow, destCol];
       predictedMove = predict(model, features);
       if(predictedMove ~= "no move")
           move = predictedMove;
       end 
    end
end

% Generates training data (size set at global level)
function [robotRows, robotCols, destRows, destCols, classifications] = generateData(numToGen)
    % Variables
    global ROBOT;
    global DESTINATION;
    global BOARD_ROWS; 
    global BOARD_COLS;
    robotRows = [0]; robotCols = [0];
    destRows  = [0]; destCols  = [0];
    classStrings = [""];
    
    % Generate samples of data
    for i = 1:numToGen
        board = zeros(BOARD_ROWS, BOARD_COLS);
        board = placeDot(board, ROBOT);
        board = placeDot(board, DESTINATION);
        [robotRow, robotCol, destRow, destCol, classification] = classifyMove(board);
        robotRows(i) = robotRow;
        robotCols(i) = robotCol;
        destRows(i)  = destRow;
        destCols(i)  = destCol;
        classStrings(i) = classification;
    end
    classifications = categorical(classStrings); % Convert classes to categorical datatype
end

% Labels training data
function [robotRow, robotCol, destRow, destCol, classification] = classifyMove(board)
    % Variables
    [robotRow, robotCol, destRow, destCol] = findCoords(board);
    classification = "no move"; % Default classification
    
    % Check possible moves
    if (robotRow == destRow)
        if (robotCol + 1 == destCol)
           classification = "right";
        end
        if (robotCol - 1 == destCol)
           classification = "left";
        end
    end
    if (robotCol == destCol)
        if (robotRow + 1 == destRow)
           classification = "down";
        end
        if (robotRow - 1 == destRow)
           classification = "up";
        end
    end
end

% Shows figure of a board
function showBoard(board)
    % Variables
    global BOARD_ROWS; 
    global BOARD_COLS;
    global ROBOT;
    global DESTINATION;
    CELL_SIZE = 1;
    
    clf % Clear previous figure
    
    % Draw Checker Board
    for row = (BOARD_ROWS:-1:1)
        for col = (1:BOARD_COLS)
            if rem(abs(row - col), 2) == 1
                rectangle('Position',[(col - 1)*CELL_SIZE (row - 1)*CELL_SIZE CELL_SIZE CELL_SIZE],...
                    'FaceColor',[0 0 0]);
            end
        end
    end
    
    % Draw Dots
    for row = (BOARD_ROWS:-1:1)
        for col = (1:BOARD_COLS)
            % Draw Green 'Robot' Dot
            if board(row, col) == ROBOT
                % fprintf("R:\t(%d,%d)\n",row,col);
                rectangle('Position',[((col - 1)*CELL_SIZE)+(CELL_SIZE/4)...
                    BOARD_ROWS-1-((row - 1)*CELL_SIZE)+(CELL_SIZE/4) CELL_SIZE/2 CELL_SIZE/2],...
                    'Curvature', [1 1], 'FaceColor',[0 1 0], 'EdgeColor', [0 1 0])
            end
            
            % Draw Red 'Destination' Dot
            if board(row, col) == DESTINATION
                % fprintf("D:\t(%d,%d)\n",row,col);
                rectangle('Position',[((col - 1)*CELL_SIZE)+(CELL_SIZE/4)...
                    BOARD_ROWS-1-((row - 1)*CELL_SIZE)+(CELL_SIZE/4) CELL_SIZE/2 CELL_SIZE/2],...
                    'Curvature', [1 1], 'FaceColor',[1 0 0], 'EdgeColor', [1 0 0])
            end
        end
    end
    
    axis equal; % Set aspect ration to 1:1
end

% Randomly places a number (num) on the board
function board = placeDot(board, num)
    [BOARD_ROWS, BOARD_COLS] = size(board); 
    valid = 0;
    while(valid == 0)
       m = randi([1, BOARD_ROWS]);
       n = randi([1, BOARD_COLS]);
       if board(m,n) == 0
          board(m,n) = num;
          valid = 1;
       end
    end
end

%{
%     % Train Initial Model
%     data = table(robotRows', robotCols', destRows', destCols', moves');
%     data.Properties.VariableNames = {'RobotRow' 'RobotCol' 'DestRow' 'DestCol' 'Move'};
%     if(modelType     == "nb")       % Naive Bayes
%         model = fitcnb(data,     'Move');
%     elseif(modelType == "tree")     % Tree
%         model = fitctree(data,   'Move');
%     elseif(modelType == "knn")      % K Nearest Number
%         model = fitcknn(data,    'Move');
%     elseif(modelType == "discr")    % Discriminant
%         model = fitcdiscr(data,  'Move');
%     end
%     models = {model};
%     
%     noMoves = 1;
%     iteration = 1;
%     while noMoves ~= 0
%         [robotRows, robotCols, destRows, destCols, moves] = generateData(DATA_LEN);
%         for i = 1:DATA_LEN
%             if moves(i) == "no move"
%                 moves(i) = checkPreviousIter(models{iteration},robotRows(i),robotCols(i),destRows(i),destCols(i));
%             end
%         end
%         
%         % Check how many "no move"s there are after checkSurrounging
%         noMoves = 0;
%         for i = 1:DATA_LEN
%             if moves(i) == "no move"
%                 noMoves = noMoves + 1;
%             end
%         end
%         
%         fprintf("%d / %d\n", noMoves, DATA_LEN);
%         
%         data = table(robotRows', robotCols', destRows', destCols', moves');
%         data.Properties.VariableNames = {'RobotRow' 'RobotCol' 'DestRow' 'DestCol' 'Move'};
%         if(modelType     == "nb")       % Naive Bayes
%             models{iteration + 1} = fitcnb(data,     'Move');
%         elseif(modelType == "tree")     % Tree
%             models{iteration + 1} = fitctree(data,   'Move');
%         elseif(modelType == "knn")      % K Nearest Number
%             models{iteration + 1} = fitcknn(data,    'Move');
%         elseif(modelType == "discr")    % Discriminant
%             models{iteration + 1} = fitcdiscr(data,  'Move');
%         end
%         iteration = iteration + 1;
%     end
%     
%     trainTime = toc; % Model trained, clock in timer
%     
%     % Test accuracy of model
%     modelAccuracy = calcAccuracyIter(models);
%     
%     % Data logging info
%     % fprintf("Board: %dx%d\tTrain Data Length: %d\tModel Type: %s\tTrain Time: %d\tAccuracy: %d", BOARD_ROWS, BOARD_COLS, DATA_LEN, modelType, trainTime, modelAccuracy);
%     fprintf("%d,%d,%d,%s,%.2f,%.2f\n", BOARD_ROWS, BOARD_COLS, DATA_LEN, modelType, trainTime, (modelAccuracy*100));
%}


% m = zeros(6, 6);
% m(robotRows(i), robotCols(i)) = 1;
% m(destRows(i), destCols(i)) = -1
