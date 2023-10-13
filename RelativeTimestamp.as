void Main()
{
}

void OnRunStep(SimulationManager@ simManager)
{
    int raceTime = simManager.TickTime;

    if (raceTime == -10) {
        ParseInputs();
    }
    
}

void ParseInputs()
{
    CommandList list("inputs.txt");

    string absoluteInputs = "";
    int baseTimestamp = 0;

    array<string> lines = list.Content.Split("\n");
    for (uint i = 0; i < lines.Length; i++) {
        string line = lines[i];

        CommandList listi;
        listi.Content = line;
        listi.Process(CommandListProcessOption::OnlyParse);
        if (listi.InputCommands.Length != 1) {
            continue;
        }
        int timestamp = listi.InputCommands[0].Timestamp;

        if (line.FindFirst("+") == 0) {
            timestamp = baseTimestamp + timestamp;

            InputCommand ic = listi.InputCommands[0];
            ic.Timestamp = timestamp;
            absoluteInputs += ic.ToScript() + "\n";
        } else {
            absoluteInputs += listi.InputCommands[0].ToScript() + "\n";
        }
        baseTimestamp = timestamp;
    }
    CommandList list2;
    list2.Content = absoluteInputs;
    list2.Process(CommandListProcessOption::OnlyParse);
    SetCurrentCommandList(list2);
}

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "RelativeTimestamp";
    info.Author = "Shweetz";
    info.Version = "v1.0.0";
    info.Description = "Description";
    return info;
}
