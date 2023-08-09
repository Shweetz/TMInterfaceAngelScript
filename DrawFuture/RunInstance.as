string pointsFile = "draw_points.txt";
uint oldPointsFileLength = 0;

void Render()
{
    if (executeHandler) {
        // The instance in simulation should not try to change triggers
        return;
    }

    if (HasFileChanged(pointsFile)) {
        // Execute commands to update triggers
        CommandList list(pointsFile);
        list.Process(CommandListProcessOption::ExecuteImmediately);
        oldPointsFileLength = list.Content.Length;
        //log("Content"+list.Content);

        // Empty the info file
        // CommandList list2();
        // list2.Save(pointsFile);
    }
    
}

/*bool HasFileChanged(string fileName)
{
    uint oldLength = oldInputsFileLength;
    if (fileName == pointsFile) {
        oldLength = oldPointsFileLength;
    } else {
        // return false to optimize if we don't listen for inputs file changing
        //return false;
    }
    return CommandList(fileName).Content.Length != oldLength;
}*/

/*PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "RunInstance";
    info.Author = "Shweetz";
    info.Version = "v1.0.0";
    info.Description = "Description";
    return info;
}*/
