string pointsFile = "points.txt";
string pointsFileContent = "";
string newContent = "";
CommandList list;

bool HasFileChanged()
{
    list = CommandList(pointsFile);
    list.Process(CommandListProcessOption::OnlyParse);
    /*if (list.Content != pointsFileContent) {
        pointsFileContent = list.Content;
        return true;
    }
    return false;*/
    return list.Content != pointsFileContent;
}

void OnRunStep(SimulationManager@ simManager)
{
            print("a");
    int raceTime = simManager.RaceTime;
    
    if (raceTime % 1000 == 0) {
        //if (HasFileChanged()) {
        if (true) {
            list = CommandList(pointsFile);
            list.Process(CommandListProcessOption::OnlyParse);
            pointsFileContent = list.Content;
            print(pointsFileContent);
            ExecuteCommand("remove_trigger all");
            CommandList list(pointsFile);
            list.Process(CommandListProcessOption::QueueAndExecute);
        }
    }
}
void Main()
{
    RegisterValidationHandler("Yooo","Why not");
}

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "RunInstance";
    info.Author = "Shweetz";
    info.Version = "v1.0.0";
    info.Description = "Description";
    return info;
}
