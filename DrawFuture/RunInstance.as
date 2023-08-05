string pointsFile = "draw_points.txt";
// string infoFile = "info.txt";
CommandList list;
uint oldFileLength = 0;

bool HasFileChanged()
{
    return CommandList(pointsFile).Content.Length != oldFileLength;
}

void Render()
{
    if (HasFileChanged()) {
        //log("huh");
        list = CommandList(pointsFile);
        list.Process(CommandListProcessOption::ExecuteImmediately);
        //Empty the info file
        CommandList list2();
        //list2.Content=""; // TODO
        // list2.Save(pointsFile);

        //log("Content"+list.Content);
        oldFileLength = list.Content.Length;
    }
    
}

/*PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "RunInstance";
    info.Author = "Shweetz";
    info.Version = "v1.0.0";
    info.Description = "Description";
    return info;
}*/
