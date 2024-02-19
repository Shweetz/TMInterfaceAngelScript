bool executeHandler = false;
SimulationState@ stateToRestore = null;
int timestampStartSearch;
int iterationCount;
vec3 lastPos;
int bestFinishTime;
int nextCheck;
int timeLimit;
int goalHeight;
int goalPosDiff;

void Main()
{
    RegisterValidationHandler("low_input_bf", "Low Input BF");
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    executeHandler = GetVariableString("controller") == "low_input_bf";
    if (!executeHandler) {
        // Not our handler, do nothing.
        return;
    }
    timestampStartSearch = 667320;
    // timestampStartSearch = 667000;
    // timestampStartSearch = 666000;
    timestampStartSearch = 30000; // 30000
    iterationCount = 0;
    lastPos = vec3(0, 0, 0);
    bestFinishTime = -1;
    nextCheck = CurrentUpTimestamp() + 1000;
    timeLimit = 743370; // for A01
    goalHeight = 24; // 9 fell in water or out of stadium; 24 fell of A01
    goalPosDiff = 0.004; // use trigger?

    // A01 12:22.36 (750000 = 12:30:00)
    // 667320 press up (11:07.32)
    
    simManager.RemoveStateValidation();
    simManager.SetSimulationTimeLimit(timeLimit);

    print("Starting low input bf");
}

void OnSimulationStep(SimulationManager@ simManager, bool userCancelled)
{
    if (!executeHandler) {
        // Not our handler, do nothing.
        return;
    }
    if (userCancelled) {
        simManager.ForceFinish();
        return;
    }

    if (simManager.PlayerInfo.RaceFinished) {
        Accept(simManager);
        Reject(simManager); // keep searching after finding finish
    }

    int raceTime = simManager.RaceTime;
    if (raceTime == 0) {
        simManager.InputEvents.Clear(); // if the bruteforced replay has inputs
    }
    if (raceTime == CurrentUpTimestamp()) {
        @stateToRestore = simManager.SaveState(); // an input changed at the restoring timestamp will be applied
    }
    else if (raceTime == nextCheck) {
        // Check if the run is worth to simulate longer or not
        vec3 pos = simManager.Dyna.CurrentState.Location.Position;
        
        float posDiff = Math::Distance(pos, lastPos);
        bool wantReject = posDiff < goalPosDiff;
        wantReject = wantReject || pos.y < goalHeight;

        if (wantReject) {
            // print("pos=" + pos.ToString());
            Reject(simManager);
            return;
        } else {
            lastPos = pos;
            nextCheck += 1000;
        }
    }
    if (raceTime >= timeLimit - 10)
    {
        Reject(simManager);
    }
}

int CurrentUpTimestamp()
{
    return timestampStartSearch + iterationCount * 10;
}

void Reject(SimulationManager@ simManager)
{
    // print("iteration " + iterationCount);
    iterationCount++;
    simManager.InputEvents.Clear();
    simManager.InputEvents.Add(CurrentUpTimestamp(), InputType::Up, 1);
    simManager.RewindToState(stateToRestore);
    
    // new position after rewind
    lastPos = simManager.Dyna.CurrentState.Location.Position;
    nextCheck = CurrentUpTimestamp() + 1000;
    print("Trying press up " + simManager.RaceTime);
}

void Accept(SimulationManager@ simManager)
{
    int finishTime = simManager.RaceTime;
    if (bestFinishTime == -1 || finishTime < bestFinishTime) 
    {
        bestFinishTime = bestFinishTime;
        CommandList list;
        list.Content = simManager.InputEvents.ToCommandsText();
        list.Save("result.txt");
        print("Run finished! Inputs saved in result.txt");
    } else {
        print("Run finished! But slower: " + finishTime + ">" + bestFinishTime);
    }
}

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "LowInputBf";
    info.Author = "Shweetz";
    info.Version = "v1.0.0";
    info.Description = "Description";
    return info;
}
