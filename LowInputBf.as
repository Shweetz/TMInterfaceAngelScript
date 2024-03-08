bool executeHandler = false;
// array<string> modes = { "Press up", "Shift timings", "Try all timings" };
array<string> modes = { "Press up", "Shift timings" };
// array<string> targets = { "Finish", "Checkpoint", "Distance/Speed", "Trigger" };
array<string> targets = { "Finish", "Checkpoint", "Trigger" };
CommandList replayInputList;
SimulationState @stateToRestore = null;
int nextCheck;
int iterationCount;
vec3 lastPos;
int bestFinishTime;
bool stopOnFinish;
bool findAllFinishes;
// string resultFile;
// bool saveWithTimestamp;
int timestampStartSearch;
int timeLimit;
int goalHeight;
float goalPosDiff;
// bool clearReplayInputs;

void Main()
{
    RegisterVariable("lowinput_minTime", 0);
    RegisterVariable("lowinput_maxTime", 1000000);
    RegisterVariable("lowinput_mode", modes[0]);
    RegisterVariable("lowinput_target", targets[0]);
    RegisterVariable("lowinput_cp_count", 1);
    RegisterVariable("lowinput_trigger_index", 1);

    RegisterValidationHandler("low_input_bf", "Low Input BF", UILowInput);
}

void UILowInput()
{
    string lowinput_mode = GetVariableString("lowinput_mode");
    string lowinput_target = GetVariableString("lowinput_target");
    string lowinput_cp_count = GetVariableDouble("lowinput_cp_count");
    string lowinput_trigger_index = GetVariableDouble("lowinput_trigger_index");

    UI::InputTimeVar("Min Time for input change", "lowinput_minTime");
    UI::InputTimeVar("Max Time for finish", "lowinput_maxTime");
    lowinput_mode = BuildCombo("Mode", lowinput_mode, modes);
    lowinput_target = BuildCombo("Optimization target", lowinput_target, targets);
    if (lowinput_target == "Checkpoint") {
        UI::InputIntVar("Checkpoint count", "lowinput_cp_count", 1);
    } else if (lowinput_target == "Trigger") {
        UI::InputIntVar("Trigger index", "lowinput_trigger_index", 1);
    }

    SetVariable("lowinput_mode", lowinput_mode);
    SetVariable("lowinput_target", lowinput_target);
    SetVariable("lowinput_cp_count", lowinput_cp_count);
    SetVariable("lowinput_trigger_index", lowinput_trigger_index);
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    executeHandler = GetVariableString("controller") == "low_input_bf";
    if (!executeHandler) {
        // Not our handler, do nothing.
        return;
    }

    @stateToRestore = null;
    nextCheck = CurRestoreTime() + 1000;
    iterationCount = 0;
    lastPos = vec3(0, 0, 0);
    bestFinishTime = -1;
    
    // Parameters that can be changed
    stopOnFinish = false;
    findAllFinishes = false;
    // resultFile = "result ";
    // saveWithTimestamp = true;
    
    // timestampStartSearch = 667320;
    // timestampStartSearch = 667000;
    // timestampStartSearch = 666000;
    timestampStartSearch = 121200; // 529000
    timeLimit = 743370; // for A01
    timestampStartSearch = int(GetVariableDouble("lowinput_minTime"));
    timeLimit = int(GetVariableDouble("lowinput_maxTime"));
    goalHeight = 9; // 9 fell in water or out of stadium, 24 fell off in A01, use trigger?
    goalPosDiff = 0.1;
    // clearReplayInputs = false;

    // A01 12:22.36 (750000 = 12:30:00)
    // 667320 press up (11:07.32)
    
    // Store replay inputs in a CommandList
    // if (!clearReplayInputs) {
    replayInputList.Content = simManager.InputEvents.ToCommandsText();
    replayInputList.Process(CommandListProcessOption::OnlyParse);
    // }
    
    simManager.RemoveStateValidation();
    simManager.SetSimulationTimeLimit(timeLimit);

    print("");
    print("Starting low input bf in mode " + GetVariableString("lowinput_mode") + " with target " + GetVariableString("lowinput_target"));
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
    if (raceTime == CurRestoreTime()) {
        @stateToRestore = simManager.SaveState(); // an input changed at the restoring timestamp will be applied
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

void OnSimulationEnd(SimulationManager@ simManager)
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

int CurRestoreTime()
{
    return timestampStartSearch + iterationCount * 10;
}

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
    // PrintInputs(simManager);
    simManager.RewindToState(stateToRestore);
    
    // new position after rewind
    lastPos = simManager.Dyna.CurrentState.Location.Position;
    nextCheck = CurRestoreTime() + 1000;
    if (bestFinishTime == -1) {
        print("Trying iteration starting at " + CurRestoreTime());
    } else {
        print("Trying iteration starting at " + CurRestoreTime() + ", bestFinishTime=" + bestFinishTime);
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
    simManager.InputEvents.Clear();
    
    if (GetVariableString("lowinput_mode") == "Press up") {
        simManager.InputEvents.Add(CurRestoreTime(), InputType::Up, 1);
    }
    if (GetVariableString("lowinput_mode") == "Shift timings") {
        for (uint i = 0; i < replayInputList.InputCommands.Length; i++) {
            InputCommand event = replayInputList.InputCommands[i];
            //print("" + event.Timestamp + " " + event.Type + " " + event.State);
            simManager.InputEvents.Add(event.Timestamp + CurRestoreTime(), event.Type, event.State);
        }
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
    if (UI::BeginCombo(label, value)) {
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

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "LowInputBf";
    info.Author = "Shweetz";
    info.Version = "v1.0.2";
    info.Description = "Description";
    return info;
}
