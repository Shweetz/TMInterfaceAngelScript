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

// array<Point> points;
// string pointsFile = "points.txt";
array<string> commands;
SimulationState state;
string inputsFile = "inputs.txt";
string inputsFileContent = "";
string newContent = "";
bool executeHandler = false;
bool simulatingNewInputs = true;
int maxSimTime = 15000; // replaced with simManager.EventsDuration

bool HasFileChanged(string fileName)
{
    CommandList list(fileName);
    list.Process(CommandListProcessOption::OnlyParse);
    //SetCurrentCommandList(list);
    /*if (list.Content != pointsFileContent) {
        pointsFileContent = list.Content;
        return true;
    }
    return false;*/
    return list.Content != inputsFileContent;
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    simManager.RemoveStateValidation();

    CommandList list(inputsFile);
    list.Process(CommandListProcessOption::ExecuteImmediately);
    
    maxSimTime = simManager.EventsDuration;
    //simManager.SetSimulationTimeLimit(maxSimTime + 1000);

    executeHandler = GetVariableString("controller") == "SimInstance";
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
    /*if (simManager.PlayerInfo.RaceFinished) {
        simManager.RewindToState(state);
        return;
    }*/
    //print("");
    if (HasFileChanged(inputsFile)) {
        print("Inputs file changed, simulating new path until " + maxSimTime);
        CommandList list(inputsFile);
        list.Process(CommandListProcessOption::OnlyParse);
        inputsFileContent = list.Content;

        // Load inputs
        simManager.InputEvents.Clear();
        for (uint i = 0; i < list.InputCommands.Length; i++) {
            //print("" + list.InputCommands[i].Timestamp + " " + list.InputCommands[i].Type + " " + list.InputCommands[i].State);
            simManager.InputEvents.Add(list.InputCommands[i].Timestamp, list.InputCommands[i].Type, list.InputCommands[i].State);
        }

        // Rewind to play the inputs
        simManager.RewindToState(state);
        simulatingNewInputs = true;

        // Write to points file to remove triggers
        commands.Resize(0);
        commands.Add("remove_trigger all"); 

        //simManager.RewindToState(state);
        // return;
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
        // Rewind is needed to not get thrown out of sim mode, but waiting would be better
        simManager.RewindToState(state);
        simulatingNewInputs = false;
        return;
    }

    if (simulatingNewInputs) {
        // print("time=" + raceTime);
        AddTriggerCommand(simManager);

        if (raceTime % 1000 == 0) { // probably not needed after mutex implem
        // if (simManager.PlayerInfo.RaceFinished) {
            /*for (uint i = 0; i < points.Length; i++) {
                Point p = points[i];
                commands.Add("add_trigger " + p.x + " " + p.y + " " + p.z + " "+ (p.x+0.1) + " " + (p.y+0.1) + " " + (p.z+0.1));
            }*/
            // print(Text::Join(strings, "\n"));
            // Write to points file
            CommandList file;
            file.Content = Text::Join(commands, "\n");            
            file.Save(pointsFile);

            // Clear the list (only if RunInstance deletes the file content after reading it)
            // commands.Resize(0);
        }
    }
}

void Main()
{
    RegisterValidationHandler("SimInstance", "SimInstance");

    // Create or empty points file
    CommandList list;
    list.Save(pointsFile);
}

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "DrawFuture";
    info.Author = "Shweetz";
    info.Version = "v1.0.0";
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
