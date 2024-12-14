bool executeHandler = false;
array<string> modes = { "Press up", "Shift timings", "Try all timings", "Define input ranges" };
// array<string> targets = { "Finish", "Checkpoint", "Distance/Speed", "Trigger" };
array<string> targets = { "Finish", "Checkpoint", "Trigger" };
CommandList replayInputList;
SimulationState @stateToRestore = null;
int curRestoreTime;
int nextCheck;
int iterationCount;
int iterationTotal;
vec3 lastPos;
int bestFinishTime;
bool stopOnFinish;
bool findAllFinishes;
// string resultFile;
// bool saveWithTimestamp;
int inputMinTime;
int inputMaxTime;
int timeLimit;
float goalHeight;
float goalPosDiff;
// bool clearReplayInputs;
array<Rule@> rules;
array<string> inputTypes = { "up", "down", "left", "right", "left/right" };
array<string> changeTypes = { "press", "rel" };
bool printInputs = false;

void Main()
{
    RegisterVariable("lowinput_minTime", 0);
    RegisterVariable("lowinput_maxTime", 1000000);
    RegisterVariable("lowinput_finTime", 1000000);
    RegisterVariable("lowinput_mode", modes[0]);
    RegisterVariable("lowinput_target", targets[0]);
    RegisterVariable("lowinput_cp_count", 1);
    RegisterVariable("lowinput_trigger_index", 1);
    RegisterVariable("lowinput_cond_height", 9);
    RegisterVariable("lowinput_rules", "");

    RegisterValidationHandler("low_input_bf", "Low Input BF", UILowInput);
}

void UILowInput()
{
    string lowinput_mode = GetVariableString("lowinput_mode");
    string lowinput_target = GetVariableString("lowinput_target");

    UI::Dummy(vec2(0, 15));

    if (UI::CollapsingHeader("Optimization"))
    {
        lowinput_target = BuildCombo("Optimization target", lowinput_target, targets);
        if (lowinput_target == "Checkpoint") {
            UI::InputIntVar("Checkpoint count", "lowinput_cp_count", 1);
        } else if (lowinput_target == "Trigger") {
            UI::InputIntVar("Trigger index", "lowinput_trigger_index", 1);
        }

        UI::Dummy(vec2(0, 15));
    }

    if (UI::CollapsingHeader("Input Modification"))
    {
        lowinput_mode = BuildCombo("Mode", lowinput_mode, modes);
        if (lowinput_mode == "Define input ranges") {
            UIRules();
        } else {
            UI::InputTimeVar("Min Time for input change", "lowinput_minTime");
            UI::InputTimeVar("Max Time for input change", "lowinput_maxTime");
        }

        printInputs = UI::Checkbox("Print inputs of every iteration in console", printInputs);

        UI::Dummy(vec2(0, 15));
    }

    if (UI::CollapsingHeader("Conditions"))
    {
        UIConditions();
    }

    SetVariable("lowinput_mode", lowinput_mode);
    SetVariable("lowinput_target", lowinput_target);
}

void UIConditions()
{
    UI::InputTimeVar("Max Time for finish", "lowinput_finTime");
    UI::InputFloatVar("Min car height (default=9 for stadium grass)", "lowinput_cond_height");

    UI::Dummy(vec2(0, 15));
}

void UIRules()
{
    //print("" + rules.Length);
    Deserialize(GetVariableString("lowinput_rules"));

    if (UI::Button("Add Rule")) {
        rules.Add(Rule());
    }
    UI::SameLine();
    if (UI::Button("Clear Rules")) {
        rules.Resize(0);
    }
    UI::Dummy( vec2(0, 25) );
    
    int width = 110;
    UI::PushItemWidth(width);

    UI::Text("Start Time (ms)    ");
    UI::SameLine();
    UI::Text("End Time (ms)      ");
    UI::SameLine();
    UI::Text("Input type           ");
    UI::SameLine();
    UI::Text("Change type         ");

    UI::Separator();

    for (uint i = 0; i < rules.Length; i++)
    {
        Rule@ currentRule = rules[i];

        currentRule.start_time = UI::InputInt("##start_time_" + i, currentRule.start_time, 100);
        UI::SameLine();
        
        currentRule.end_time = UI::InputInt("##end_time_" + i, currentRule.end_time, 100);
        UI::SameLine();

        string changeType = currentRule.change;
        if (UI::BeginCombo("##changeType_" + i, changeType)) {
            for (uint j = 0; j < changeTypes.Length; j++)
            {
                string currentChangeType = changeTypes[j];
                if (currentChangeType == "Steering" && currentRule.input != "Steer") {
                    continue;
                }
                if (UI::Selectable(currentChangeType, changeType == currentChangeType)) {
                    currentRule.change = currentChangeType;
                }
            }
                
            UI::EndCombo();
        }
        UI::SameLine();
        
        string inputType = currentRule.input;
        if (UI::BeginCombo("##inputType_" + i, inputType)) {
            for (uint j = 0; j < inputTypes.Length; j++)
            {
                string currentInputType = inputTypes[j];
                if (UI::Selectable(currentInputType, inputType == currentInputType)) {
                    currentRule.input = currentInputType;
                }
            }
                
            UI::EndCombo();
        }
        // Validate/force values
        if (currentRule.start_time < 0) {
            currentRule.start_time = 0;
        }
        if (currentRule.start_time > currentRule.end_time) {
            currentRule.end_time = currentRule.start_time;
        }
        if (currentRule.input == "") {
            currentRule.input = inputTypes[0];
        }
        if (currentRule.change == "") {
            currentRule.change = changeTypes[0];
        }
        if (currentRule.input != "Steer" && currentRule.change == "Steering") {
            currentRule.change = "Timing";
        }
        //UI::Text(currentRule.toString());
        
        UI::Dummy( vec2(0, 10) );
    }
    
    // UICopyButtons(width);
    
    UI::PopItemWidth();

    SetVariable("lowinput_rules", Serialize(rules));

    UI::Dummy(vec2(0, 15));
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    executeHandler = GetVariableString("controller") == "low_input_bf";
    if (!executeHandler) {
        // Not our handler, do nothing.
        return;
    }
    
    // Parameters that can be changed
    stopOnFinish = false;
    findAllFinishes = false;
    // resultFile = "result ";
    // saveWithTimestamp = true;
    
    // inputMinTime = 667320;
    // inputMinTime = 667000;
    // inputMinTime = 666000;
    inputMinTime = 121200; // 529000
    timeLimit = 743370; // for A01
    inputMinTime = int(GetVariableDouble("lowinput_minTime"));
    inputMaxTime = int(GetVariableDouble("lowinput_maxTime"));
    timeLimit = int(GetVariableDouble("lowinput_finTime"));
    // 9 fell in water or out of stadium, 24 fell off in A01, use trigger?
    goalHeight = GetVariableDouble("lowinput_cond_height"); 
    goalPosDiff = 0.1;
    // clearReplayInputs = false;

    // A01 12:22.36 (750000 = 12:30:00)
    // 667320 press up (11:07.32)

    // Parameters that can't be changed (initialize)
    @stateToRestore = null;
    curRestoreTime = inputMinTime;
    nextCheck = curRestoreTime + 1000;
    iterationCount = -1;
    lastPos = vec3(0, 0, 0);
    bestFinishTime = -1;
    
    // Store replay inputs in a CommandList
    // if (!clearReplayInputs) {
    replayInputList.Content = simManager.InputEvents.ToCommandsText();
    replayInputList.Process(CommandListProcessOption::OnlyParse);
    // }
    
    simManager.RemoveStateValidation();
    simManager.SetSimulationTimeLimit(timeLimit);

    print("");
    print("Starting low input bf in mode " + GetVariableString("lowinput_mode") + " with target " + GetVariableString("lowinput_target"));
    // Count and print total possible iterations
    if (GetVariableString("lowinput_mode") == "Try all timings") {
        int inputCount = replayInputList.InputCommands.Length;
        int possCount = (inputMaxTime - inputMinTime) / 10;
        iterationTotal = int(Math::Pow(possCount, inputCount));
        print("" + inputCount + " inputs and " + possCount + " possible timings, so " + iterationTotal + " iterations needed");
    }
    else if (GetVariableString("lowinput_mode") == "Define input ranges") {
        Deserialize(GetVariableString("lowinput_rules"));
        iterationTotal = 1;
        for (uint i = 0; i < rules.Length; i++)
        {
            Rule rule = rules[i];

            int rulePossibleTimings = (rule.end_time - rule.start_time) / 10 + 1;
            int rulePossibleInputs = 1;
            if (rule.input == "left/right" && rule.change == "press") {
                rulePossibleInputs = 2;
            }

            iterationTotal *= rulePossibleTimings * rulePossibleInputs;
        }
        print("" + iterationTotal + " iterations needed");
    }
}

void OnSimulationStep(SimulationManager@ simManager, bool userCancelled)
{
    if (!executeHandler) {
        // Not our handler, do nothing.
        return;
    }
    if (userCancelled) {
        return;
    }

    if (CheckIfAccept(simManager)) {
        Accept(simManager);
        if (!stopOnFinish) {
            Reject(simManager); // keep searching for faster end after finding finish
            return;
        }
    }

    int raceTime = simManager.RaceTime;
    // print("" + raceTime);
    // if (raceTime == 0 && GetVariableString("lowinput_mode") == "Press up") {
    //     simManager.InputEvents.Clear();
    // }
    if (raceTime == curRestoreTime) {
        @stateToRestore = simManager.SaveState(); // an input changed at the restoring timestamp will be applied
        
        if (iterationCount == -1) {
            Reject(simManager); // this loads inputs for iteration 0 and rewinds
            return;
        }
    }
    else if (raceTime == nextCheck) {
        // Check if the run is worth to simulate longer or not
        if (CheckIfReject(simManager)) {
            Reject(simManager);
            return;
        } else {
            lastPos = simManager.Dyna.CurrentState.Location.Position;
            nextCheck += 1000;
        }
    }
    if (raceTime >= timeLimit - 10)
    {
        Reject(simManager);
    }
}

void OnSimulationEnd(SimulationManager@ simManager, SimulationResult result)
{
    executeHandler = false;
}

void OnCheckpointCountChanged(SimulationManager@ simManager, int count, int target)
{
    if (!executeHandler) {
        // Not our handler, do nothing.
        return;
    }
    if (count == target) {
        // Keep simulation going if the replay finishes before the inputs
        simManager.PreventSimulationFinish();
    }
}

// int CurRestoreTime()
// {
//     if (GetVariableString("lowinput_mode") == "Try all timings") {
//         return 0;
//     }
//     return inputMinTime + 10 * iterationCount;
// }

bool CheckIfReject(SimulationManager@ simManager)
{
    vec3 pos = simManager.Dyna.CurrentState.Location.Position;
    // print("pos=" + pos.ToString());
    float posDiff = Math::Distance(pos, lastPos);
    bool wantReject = posDiff < goalPosDiff;
    wantReject = wantReject || pos.y < goalHeight;
    return wantReject;
}

void Reject(SimulationManager@ simManager)
{
    iterationCount++;
    // print("iteration " + iterationCount);

    LoadNextInputs(simManager);
    simManager.RewindToState(stateToRestore);
    
    // new position after rewind
    lastPos = simManager.Dyna.CurrentState.Location.Position;
    nextCheck = curRestoreTime + 1000;
    if (curRestoreTime < inputMaxTime) {
        if (bestFinishTime == -1) {
            print("Iteration " + iterationCount + " starting at " + curRestoreTime);
        } else {
            print("Iteration " + iterationCount + " starting at " + curRestoreTime + ", bestFinishTime=" + bestFinishTime);
        }
    } else {
        print("Next iteration would start at " + curRestoreTime + ", stop bf");
        simManager.SetSimulationTimeLimit(inputMaxTime);
    }
}

bool CheckIfAccept(SimulationManager@ simManager)
{
    string target = GetVariableString("lowinput_target");
    if (target == "Finish") {
        return simManager.PlayerInfo.RaceFinished;
    }
    else if (target == "Checkpoint") {
        return simManager.PlayerInfo.CurCheckpointCount >= uint(GetVariableDouble("lowinput_cp_count"));
    }
    else if (target == "Trigger") {
        Trigger3D trigger = GetTriggerByIndex(uint(GetVariableDouble("lowinput_trigger_index"))-1);
        return trigger.ContainsPoint(simManager.Dyna.CurrentState.Location.Position);
    }

    print("Error lowinput_target=" + target);
    return simManager.PlayerInfo.RaceFinished;
}

void Accept(SimulationManager@ simManager)
{
    int finishTime = simManager.RaceTime;

    CommandList list;
    list.Content = simManager.InputEvents.ToCommandsText();
    
    if (bestFinishTime == -1 || finishTime < bestFinishTime) 
    {
        bestFinishTime = finishTime;
        if (!findAllFinishes) {
            // Speeds up the later runs because lowers timeLimit
            timeLimit = finishTime;
            simManager.SetSimulationTimeLimit(timeLimit);
        }

        string resultFile = "result_" + finishTime + ".txt";
        resultFile = "result.txt";
        list.Save(resultFile);
        print("Run finished! Time: " + finishTime + ", inputs saved in " + resultFile + ":");
    } else {
        print("Run finished! But slower: " + finishTime + ">" + bestFinishTime + ":");
    }

    print("" + list.Content);
    print("");
}

void LoadNextInputs(SimulationManager@ simManager)
{
    // print("LoadNextInputs");
    simManager.InputEvents.Clear();
    
    string mode = GetVariableString("lowinput_mode");
    if (mode == "Press up") {
        curRestoreTime = inputMinTime + 10 * iterationCount;
        simManager.InputEvents.Add(curRestoreTime, InputType::Up, 1);
    }
    else if (mode == "Shift timings") {
        curRestoreTime = inputMinTime + 10 * iterationCount;
        for (uint i = 0; i < replayInputList.InputCommands.Length; i++) {
            InputCommand event = replayInputList.InputCommands[i];
            //print("" + event.Timestamp + " " + event.Type + " " + event.State);
            simManager.InputEvents.Add(event.Timestamp + curRestoreTime, event.Type, event.State);
        }
    }
    else if (mode == "Try all timings") {
        int minTime = int(GetVariableDouble("lowinput_minTime"));
        int maxTime = int(GetVariableDouble("lowinput_maxTime"));
        int possibleTimings = (maxTime - minTime) / 10 + 1;

        // remainder when reading iterationCount
        // example, 10 timings with 2 inputs, so 100 iterations
        // iteration 15 => 2nd input is at timing 5, remainder 1, 1st input is at timing 1
        int remainder = iterationCount;

        // index backwards
        uint len = replayInputList.InputCommands.Length;
        for (uint i = len - 1; i < len; i--) {
            int inputCode = remainder % possibleTimings;
            int inputTime = minTime + 10 * inputCode;

            InputCommand event = replayInputList.InputCommands[i];
            simManager.InputEvents.Add(inputTime, event.Type, event.State);
            //print("" + event.Timestamp + " " + event.Type + " " + event.State);

            remainder = int(remainder / possibleTimings);
        }

        if (remainder > 0) {
            print("All combinations have been tried, stop bf");
            simManager.SetSimulationTimeLimit(0);
        }
    }
    else if (mode == "Define input ranges") {
        // Get updated rules
        Deserialize(GetVariableString("lowinput_rules"));
        
        // Transform unique i (iteration number) in a unique code holding the rules' state
        // Iterate backwards in rules (it creates a nicer code progression)
        array<int> inputCodes;
        int remainder = iterationCount;
        for (uint i = rules.Length - 1; i < rules.Length; i--)
        {
            Rule rule = rules[i];
            
            // Possible timings for the rule
            int possibleTimings = (rule.end_time - rule.start_time) / 10 + 1;
            if (rule.input == "left/right" && rule.change == "press") { possibleTimings *= 2; }

            // Insert front because we're iterating backwards
            inputCodes.InsertAt(0, remainder % possibleTimings);
            
            remainder = int(remainder / possibleTimings);
        }

        InputType currentLeftRightType = InputType::Left;

        // Use the unique code to create a unique rule state, and store the resulting events in InputEvents
        for (uint i = 0; i < rules.Length; i++)
        {
            Rule rule = rules[i];
            int inputCode = inputCodes[i];

            // Input type
            InputType inputType = InputType::Up;
            if (rule.input == "down" ) { inputType = InputType::Down;  }
            if (rule.input == "left" ) { inputType = InputType::Left;  }
            if (rule.input == "right") { inputType = InputType::Right; }

            // Input time
            int inputTime = rule.start_time + 10 * inputCode;

            // Case with double possibilities : left or right
            if (rule.input == "left/right") {
                if (rule.change == "press") {
                    // Even iterations (0, 2, 4...) will be for Left, odd ones for Right
                    if (inputCode % 2 == 0) { currentLeftRightType = InputType::Left; }
                    else                    { currentLeftRightType = InputType::Right; }

                    inputType = currentLeftRightType;
                    // Time should only be incremented every 2 iterations, so Left and Right can both be tried before time increases
                    inputTime = rule.start_time + 10 * int(inputCode / 2);
                }
                else {
                    // Release the previous left/right
                    inputType = currentLeftRightType;
                }
            }
            
            // Input value (press or rel)
            int value = 1;
            if (rule.change == "rel") { value = 0; }

            // Add the rule's event in InputEvents
            simManager.InputEvents.Add(inputTime, inputType, value);
        }

        if (remainder > 0) {
            print("All combinations have been tried, stop bf");
            simManager.SetSimulationTimeLimit(0);
        }
    }
    
    if (printInputs) {
        PrintInputs(simManager);
    }
}

void PrintInputs(SimulationManager@ simManager)
{
    CommandList list;
    list.Content = simManager.InputEvents.ToCommandsText();
    print(list.Content);
}

// array<TM::InputEvent> DeepCopyInputBuffer(TM::InputEventBuffer@ inputBuffer)
// {
//     array<TM::InputEvent> otherBuffer;
//     for (uint i = 0; i < inputBuffer.Length; i++) {
//         otherBuffer.Add(inputBuffer[i]);
//     }
//     return otherBuffer;
// }

// Testing purposes
// void OnRunStep(SimulationManager@ simManager, bool userCancelled) {
//     print("" + simManager.PlayerInfo.CurCheckpoint);
//     print("" + simManager.PlayerInfo.CurCheckpointCount);
//     print("");
// }

string BuildCombo(string& label, string& value, array<string> values)
{
    string ret = value;
    if (UI::BeginCombo(label, value))
    {
        for (uint i = 0; i < values.Length; i++)
        {
            string currentValue = values[i];
            if (UI::Selectable(currentValue, value == currentValue))
            {
                ret = currentValue;
            }
        }
            
        UI::EndCombo();
    }
    return ret;
}

class Rule
{
    string input;
    string change;
    float proba;
    int start_time;
    int end_time;
    int diff;

    Rule()
    {
        Rule(inputTypes[0], changeTypes[0], 0.01, 0, 0, 50);
    }

    Rule(string& i, string& c, float p, int s, int e, int d)
    {
        input = i;
        change = c;
        proba = p;
        start_time = s;
        end_time = e;
        diff = d;
    }

    string serialize()
    {
        return input + "," + change + "," + proba + "," + start_time + "," + end_time + "," + diff;
    }

    void deserialize(string& str)
    {
        // print(str);
        array<string>@ splits = str.Split(",");
        input = splits[0];
        change = splits[1];
        proba = Text::ParseFloat(splits[2]);
        start_time = Text::ParseInt(splits[3]);
        end_time = Text::ParseInt(splits[4]);
        diff = Text::ParseInt(splits[5]);
    }

    string toString()
    {
        return "rule: From " + start_time + " to " + end_time + ", change " + input + " " + change + " with max diff of " + diff + " and modify_prob=" + proba;
    }
}

string Serialize(array<Rule@> rules)
{
    string str = "";
    for (uint i = 0; i < rules.Length; i++) {
        str += rules[i].serialize() + " ";
    }
    return str;
}

void Deserialize(string& rules_str)
{
    rules.Resize(0);
    // Separate big string in rules
    array<string>@ splits = rules_str.Split(" ");
    // print("<" + rules_str + ">");
    // print("a " + splits.Length);
    for (uint i = 0; i < splits.Length; i++) {
        if (splits[i] == "") {
            continue;
        }
        rules.Add(Rule());
        rules[i].deserialize(splits[i]);
    }
}

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "LowInputBf";
    info.Author = "Shweetz";
    info.Version = "v1.0.5";
    info.Description = "Description";
    return info;
}
