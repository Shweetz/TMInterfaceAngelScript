# TMInterfaceAngelScript
My AngelScript plugins for TMInterface


To use my Nosepos+ plugin, download the folder "Shweetz" and place it in TMI's Plugins so the path is: Documents\TMInterface\Plugins\Shweetz


To use my DrawFuture plugin, download the folder "DrawFuture" and place it in TMI's Plugins so the path is: Documents\TMInterface\Plugins\DrawFuture

This one requires 2 TMI instances, 1 being in run mode for the map you want, and the other needs to select the alternate bruteforce "SimInstance", then simulate any replay that was saved on the same map.

The plugin will read "inputs.txt" as the inputs for the replay in simulation, and the plugin will read&write to "draw_points.txt".

You can also separate the AS files, because you only really need the TMI run instance to enable the RunInstance plugin, and the TMI sim instance to enable the SimInstance plugin.



AS plugins in TMI are recognized when they are dragged as folders (containing several AS files) or singles files in Documents\TMInterface\Plugins.

You should usually not separate files that are in a plugin folder as they are meant to work together.

For example, Documents\TMInterface\Plugins\Shweetz should contain several AS files.
