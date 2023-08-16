class Point {
    float x, y, z;
    
    Point() {}

    Point(vec3 pos) {
        x = pos.x;
        y = pos.y;
        z = pos.z;
    }
}

void AddTriggerCommand(SimulationManager@ simManager) {
    vec3 pos = simManager.Dyna.CurrentState.Location.Position;
    Point p(pos);
    //points.Add(p);
    commands.Add("add_trigger " + p.x + " " + p.y + " " + p.z + " "+ (p.x+0.1) + " " + (p.y+0.1) + " " + (p.z+0.1));
    //commands.Add("add_trigger " + p.x + " " + p.y + " " + p.z + " "+ (p.x+0.1) + " " + (p.y+0.1) + " " + (p.z+0.1) + " # " + simManager.RaceTime);
}

bool executeHandler = false;
// array<Point> points;
// string pointsFile = "points.txt";
string inputsFile = "inputs.txt";
uint oldInputsFileLength = 0;
string oldInputsFileContent = "";
int lastFileCheckTime = 0;

array<string> commands;
SimulationState state;
bool simulatingNewInputs = true;
int maxSimTime = 0; // replaced with simManager.EventsDuration
uint tickCountBetween2Points = 1; // 1 trigger per X ticks

bool NeedParseFile(string fileName)
{
    // Points file
    if (fileName == pointsFile) {
        return CommandList(fileName).Content.Length != oldPointsFileLength;
    } 

    // Inputs file
    bool changed = false;
    if (CommandList(fileName).Content.Length != oldInputsFileLength) {
        // content length changed (warning, a time/steer change will not always trigger this check)
        changed = true;
    }
    
    int nextCheckTime = oldInputsFileLength / 100; // E05 is 1.6M chars, inputs check takes 130ms, should be done every 16000ms
    if (Time::Now - lastFileCheckTime > nextCheckTime) {
        // last check was more than X ms ago
        changed = true;
    }

    // return if it's time to reload
    return changed;

    /*auto start = Time::Now;
    CommandList list(fileName);
    print("" + (Time::Now - start));
    list.Process(CommandListProcessOption::OnlyParse);
    print("" + (Time::Now - start));
    auto a = list.Content != inputsFileContent;
    print("" + (Time::Now - start));
    return a;*/
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    executeHandler = GetVariableString("controller") == "SimInstance";
    if (!executeHandler) {
        // Not our handler, do nothing.
        return;
    }

    simManager.RemoveStateValidation();

    maxSimTime = simManager.EventsDuration;
    print("Validated replay lasts " + maxSimTime);
    //simManager.SetSimulationTimeLimit(maxSimTime + 1000);
}

void OnSimulationStep(SimulationManager@ simManager, bool userCancelled)
{
    if (!executeHandler) {
        // Not our handler, do nothing.
        return;
    }
    if (userCancelled) {
        simManager.SetSimulationTimeLimit(10);
        return;
    }
    
    //print("");
    if (NeedParseFile(inputsFile)) {
        CommandList list(inputsFile);
        list.Process(CommandListProcessOption::OnlyParse);

        if (list.Content != oldInputsFileContent) {
            oldInputsFileLength = list.Content.Length;
            oldInputsFileContent = list.Content;

            // Load inputs
            simManager.InputEvents.Clear();
            for (uint i = 0; i < list.InputCommands.Length; i++) {
                //print("" + list.InputCommands[i].Timestamp + " " + list.InputCommands[i].Type + " " + list.InputCommands[i].State);
                simManager.InputEvents.Add(list.InputCommands[i].Timestamp, list.InputCommands[i].Type, list.InputCommands[i].State);
            }

            lastFileCheckTime = Time::Now;
            print("Inputs file " + inputsFile + " loaded with " + list.InputCommands.Length + " inputs, simulating path until " + maxSimTime);

            // Write to points file to remove triggers
            commands.Resize(0);
            commands.Add("remove_trigger all"); 

            // Rewind to play the inputs
            simManager.RewindToState(state);
            simulatingNewInputs = true;

            // return;
        }
    }

    int raceTime = simManager.RaceTime;
    if (raceTime < 0) {
        //points.Resize(0);
        return;
    } else if (raceTime == 0) {
        state = simManager.SaveState();
        return;
    } else if (raceTime > maxSimTime - 10) {
        // Waiting for inputs to change
        if (simulatingNewInputs) {
            print("Simulating done, waiting for new inputs");
        }

        // Rewind is needed to not get thrown out of sim mode, but waiting would be better
        simManager.RewindToState(state);
        simulatingNewInputs = false;
        return;
    }

    if (simulatingNewInputs) {

        if (raceTime % (tickCountBetween2Points * 10) == 0) {
            AddTriggerCommand(simManager);
        }
        // print("time=" + raceTime);

        if (raceTime % 1000 == 0) { // probably not needed after mutex implem
        // if (simManager.PlayerInfo.RaceFinished) {
        // if (raceTime == maxSimTime - 10) {
            // Write to points file
            CommandList file;
            file.Content = Text::Join(commands, "\n");
            file.Save(pointsFile);

            // Clear the list (only if RunInstance deletes the file content after reading it)
            // commands.Resize(0);
        }
    }
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

void Main()
{
    RegisterValidationHandler("SimInstance", "SimInstance");

    // Create or clear points file
    CommandList emptyList;
    emptyList.Save(pointsFile);
    
    // Create inputs file if doesn't exist
    try {
        CommandList list(inputsFile);
    } catch {
        print("Inputs file " + inputsFile + " needs to contain the inputs to draw");
        emptyList.Save(inputsFile);
    }
}

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "DrawFuture";
    info.Author = "Shweetz";
    info.Version = "v1.0.2";
    info.Description = "Description";
    return info;
}

/*PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "SimInstance";
    info.Author = "Shweetz";
    info.Version = "v1.0.0";
    info.Description = "Description";
    return info;
}*/
