# TMInterfaceAngelScript
My AngelScript plugins for TMInterface


## Nosepos+/AirTime
To use my main plugin, download the folder "Shweetz" and place it in TMI's Plugins so the path is: Documents\TMInterface\Plugins\Shweetz


## DrawFuture
To use my DrawFuture plugin, download the folder "DrawFuture" and place it in TMI's Plugins so the path is: Documents\TMInterface\Plugins\DrawFuture

This plugin requires 2 TMI instances, and you need to have a replay on the map you want to draw on.

One instance will simulate the path. For this, open the Bruteforce Settings tab and select the bruteforce mode "SimInstance" (instead of Bruteforce (built-in). Then, then select any replay that was saved on the same map and bruteforce it (the button should be renamed "SimInstance").
The other instance should open the map in run mode.

The plugin will read "inputs.txt" as the inputs for the replay in simulation, and will read&write to "draw_points.txt".

You can also separate the AS files, because you only really need the TMI run instance to enable the RunInstance file, and the TMI sim instance to enable the SimInstance file.


# General info on TMI & AS
AS plugins in TMI are recognized when they are dragged as folders (containing several AS files) or singles files in Documents\TMInterface\Plugins.

You should usually not separate files that are in a plugin folder as they are meant to work together.

For example, Documents\TMInterface\Plugins\Shweetz should contain several AS files.
