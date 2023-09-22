void UIConditions()
{
    UI::SliderFloatVar("Min speed (km/h)", "shweetz_condition_speed", 0.0f, 1000.0f);
    UI::InputIntVar("Min CP collected", "shweetz_min_cp", 1);
    UI::SliderIntVar("Min wheels on ground", "shweetz_min_wheels_on_ground", 0, 4);
    UI::SliderIntVar("Gear (0 to disable)", "shweetz_gear", -1, 6);

    // Trigger
    UI::InputIntVar("Trigger index (0 to disable)", "shweetz_trigger_index", 1);
    Trigger3D trigger = GetTriggerVar("shweetz_trigger_index");
    if (trigger.Size.x != -1) {
        vec3 pos2 = trigger.Position + trigger.Size;
        UI::TextDimmed("The car must be in the trigger of coordinates: ");
        UI::TextDimmed("" + trigger.Position.ToString() + " " + pos2.ToString());
    }

    // Anti-Trigger
    UI::InputIntVar("Anti-Trigger index (0 to disable)", "shweetz_antitrigger_index", 1);
    trigger = GetTriggerVar("shweetz_antitrigger_index");
    if (trigger.Size.x != -1) {
        vec3 pos2 = trigger.Position + trigger.Size;
        UI::TextDimmed("The car must never hit the trigger of coordinates: ");
        UI::TextDimmed("" + trigger.Position.ToString() + " " + pos2.ToString());
    }

    // Freewheel
    // UI::PushItemWidth(300);
    // UI::CheckboxVar("Check free wheel condition                 ", "shweetz_fw_act");
    // UI::SameLine();
    // UI::CheckboxVar("Free wheel state", "shweetz_fw");
    // UI::PopItemWidth();

    UI::Dummy( vec2(0, 25) );
    
    UI::InputTimeVar("Tick to print if conditions are met (0 to disable)", "shweetz_debug");

    UI::Dummy( vec2(0, 25) );
}

bool AreConditionsMet(SimulationManager@ simManager)
{
    // Choose a tick to print if a condition failed
    int debugTick = int(GetD("shweetz_debug"));

    float speedKmh = simManager.Dyna.CurrentState.LinearSpeed.Length() * 3.6;
    if (speedKmh < GetD("shweetz_condition_speed")) {
        if (simManager.TickTime == debugTick) { print("Condition speed too low: " + speedKmh + " < " + GetD("shweetz_condition_speed")); }
        return false;
    }

    int cpCount = int(simManager.PlayerInfo.CurCheckpointCount);
    if (cpCount < GetD("shweetz_min_cp")) {
        if (simManager.TickTime == debugTick) { print("Condition CPs not reached: " + cpCount + " < " + GetD("shweetz_min_cp")); }
        return false;
    }

    int wheelCount = CountWheelsOnGround(simManager);
    if (wheelCount < GetD("shweetz_min_wheels_on_ground")) {
        if (simManager.TickTime == debugTick) { print("Condition wheels not reached: " + wheelCount + " < " + GetD("shweetz_min_wheels_on_ground")); }
        return false;
    }

    int gear = simManager.SceneVehicleCar.CarEngine.Gear;
    if (GetD("shweetz_gear") > 0 && GetD("shweetz_gear") != gear) {
        if (simManager.TickTime == debugTick) { print("Condition gear not reached: " + gear + " != " + GetD("shweetz_gear")); }
        return false;
    }

    vec3 pos = simManager.Dyna.CurrentState.Location.Position;
    if (GetD("shweetz_trigger_index") > 0 && !IsInTrigger(pos, "shweetz_trigger_index")) {
        if (simManager.TickTime == debugTick) { print("Condition trigger not reached"); }
        return false;
    }

    // if (simManager.SceneVehicleCar.IsFreeWheeling) {
    //     return false;
    // }

    if (simManager.TickTime == debugTick) { print("Conditions OK"); }

    return true;
}

bool IsForceReject(SimulationManager@ simManager)
{
    int debugTick = int(GetD("shweetz_debug"));
    
    vec3 pos = simManager.Dyna.CurrentState.Location.Position;
    if (GetD("shweetz_antitrigger_index") > 0 && IsInTrigger(pos, "shweetz_antitrigger_index")) {
        if (debugTick > 0) { print("Antitrigger hit at " + curr.time + ", reject iteration " + iterations); }
        return true;
    }

    return false;
}
