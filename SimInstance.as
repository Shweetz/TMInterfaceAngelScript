array<Point> points;
string pointsFile = "points.txt";

class Point {
    float x, y, z;
    
    Point() {}

    Point(vec3 pos) {
        x = pos.x;
        y = pos.y;
        z = pos.z;
    }
}

void AddPoint(SimulationManager@ simManager) {
    vec3 pos = simManager.Dyna.CurrentState.Location.Position;
    Point p(pos);
    points.Add(p);
}

Point GetPoint(uint index) {
    return points[index];
}

void Main()
{
    RegisterValidationHandler("SimInstance", "SimInstance");
}

SimulationState state;
string inputsFile = "inputs.txt";
string inputsFileContent = "";
string newContent = "";
CommandList list;

bool HasFileChanged()
{
    CommandList list(inputsFile);
    list.Process(CommandListProcessOption::OnlyParse);
    //SetCurrentCommandList(list);
    /*if (list.Content != pointsFileContent) {
        pointsFileContent = list.Content;
        return true;
    }
    return false;*/
    return list.Content != inputsFileContent;
}
bool executeHandler = false;
void OnSimulationBegin(SimulationManager@ simManager)
{
    CommandList list(inputsFile);
    list.Process(CommandListProcessOption::ExecuteImmediately);
    simManager.RemoveStateValidation();
    //simManager.SetSimulationTimeLimit(1000000);

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
    if (HasFileChanged()) {
        print("changed");
        simManager.InputEvents.Clear();
        CommandList list(inputsFile);
        list.Process(CommandListProcessOption::OnlyParse);
        for (uint i = 0; i < list.InputCommands.Length; i++) {
            //simManager.InputEvents.Add(list.InputCommands[i]);
            log("" + list.InputCommands[i].Timestamp + " " + list.InputCommands[i].Type + " " + list.InputCommands[i].State);
            simManager.InputEvents.Add(list.InputCommands[i].Timestamp, list.InputCommands[i].Type, list.InputCommands[i].State);
        }
        inputsFileContent = list.Content;
        // simManager.GiveUp();
        points.Resize(0);

        simManager.RewindToState(state);
        // return;
    }

    int raceTime = simManager.RaceTime;
    if (raceTime < 0) {
        points.Resize(0);
        return;
    } else if (raceTime == 0) {
        state = simManager.SaveState();
    } else if (raceTime > 15000) {
        simManager.RewindToState(state);
        return;
    } else {
        AddPoint(simManager);
    }

    if (raceTime % 1000 == 0) {
        array<string> strings;
        for (uint i = 0; i < points.Length; i++) {
            Point p = points[i];
            strings.Add("add_trigger " + p.x + " " + p.y + " " + p.z + " "+ (p.x+0.1) + " " + (p.y+0.1) + " " + (p.z+0.1));
        }
        CommandList file;
        file.Content = Text::Join(strings, "\n");
        file.Save(pointsFile);
    }
}

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "SimInstance";
    info.Author = "Shweetz";
    info.Version = "v1.0.0";
    info.Description = "Description";
    return info;
}
