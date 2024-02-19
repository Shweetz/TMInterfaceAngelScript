// array<double> POINT = {50, 50, 300};
// array<double> TRIGGER = {523, 9, 458, 550, 20, 490};

void UIBfNosePos()
{
    UINosePos();
    UI::Separator();
    UIConditions();
}

void UINosePos()
{
    ///// Change a variable manually
    // double time;
    // GetVariable("plugin_time", time);
    // time = UI::InputTime("Some time", time);
    // SetVariable("plugin_time", time);
    //
    ///// Change a variable manually v2
    // string str = GetS("plugin_str");
    // combo shit => SetVariable("plugin_str", str);

    // Eval time
    UI::InputTimeVar("Eval time min", "shweetz_eval_time_min");
    UI::InputTimeVar("Eval time max", "shweetz_eval_time_max");
    
    // eval max >= eval min
    SetVariable("shweetz_eval_time_max", Math::Max(GetD("shweetz_eval_time_min"), GetD("shweetz_eval_time_max")));
    
    if (GetD("bf_inputs_max_time") != 0) {
        // inputs max < eval max
        SetVariable("bf_inputs_max_time", Math::Min(GetD("bf_inputs_max_time"), GetD("shweetz_eval_time_max") - 10));
        
        // inputs max >= inputs min
        SetVariable("bf_inputs_max_time", Math::Max(GetD("bf_inputs_max_time"), GetD("bf_inputs_min_time")));
    }

    UI::Dummy( vec2(0, 25) );

    UI::InputIntVar("Target yaw (°) (90 for left gs and uber, -90 for right)", "shweetz_yaw_deg", 1);
    UI::InputIntVar("Target pitch (°) (85 to 90 for nosepos, 0 for gs, -25 for uber)", "shweetz_pitch_deg", 1);
    UI::InputIntVar("Target roll (°) (usually 0)", "shweetz_roll_deg", 1);
    UI::CheckboxVar("Accept any yaw for nosepos (uncheck for yaw bruteforce)", "shweetz_allow_yaw_180");

    // Change eval
    if (UI::CheckboxVar("Change eval after nosepos is good enough", "shweetz_next_eval_check"))
    {
        UI::TextDimmed("Good enough means angle can be some degrees off from ideal nosepos.");
        UI::InputIntVar("Max angle from ideal (°)", "shweetz_angle_min_deg", 1);
        
        UINextEval();
    }

    UI::Dummy( vec2(0, 25) );
}

void UINextEval()
{
    string next_eval = GetS("shweetz_next_eval");
    if (UI::BeginCombo("Next eval", next_eval)) {
        for (uint i = 0; i < modes.Length; i++)
        {
            string currentMode = modes[i];
            if (UI::Selectable(currentMode, next_eval == currentMode))
            {
                SetVariable("shweetz_next_eval", currentMode);
            }
        }
            
        UI::EndCombo();
    }

    if (next_eval == "Point") {
        UI::DragFloat3Var("Point", "shweetz_point");
        UI::SameLine();
        if (UI::Button("Copy coordinates")) {
            auto camera = GetCurrentCamera();
            if (@camera != null) {
                SetVariable("shweetz_point", camera.Location.Position.ToString());
            }
        }
    }
}

BFEvaluationResponse@ OnEvaluateNosePos(SimulationManager@ simManager, const BFEvaluationInfo&in info)
{
    //int time = simManager.PlayerInfo.RaceTime;
    int raceTime = simManager.TickTime; // After finishing, TickTime=time+10 while RaceTime has the same value twice in a row
    prevTime = raceTime;

    if (info.Rewinded) {
        curr = CarState();
    } else {
        curr.ResetForNewTick();
    }
    curr.time = raceTime;

    iterations = info.Iterations;

    auto resp = BFEvaluationResponse();

    if (GetS("shweetz_next_eval") == "Hold") {        
        if (info.Phase == BFPhase::Initial) {
            if (IsPastEvalTime(raceTime) && IsBetterNosePos(simManager, curr)) {
                best = curr;
                PrintGreenTextNosePos(best);
            }
        }
        else {
            if (IsPastEvalTime(raceTime)) {
                if (IsBetterNosePos(simManager, curr)) {
                    resp.Decision = BFEvaluationDecision::Accept;
                    return resp;
                } 
                if (!IsNosePos(simManager)) {
                    resp.Decision = BFEvaluationDecision::Reject;
                    return resp;
                }
            }
        }
    }
    else {
        if (info.Phase == BFPhase::Initial) {
            if (IsEvalTime(raceTime) && IsBetterNosePos(simManager, curr)) {
                best = curr;
            }

            if (IsMaxTime(raceTime)) {
                PrintGreenTextNosePos(best);
            }
        }
        else {
            if (IsEvalTime(raceTime)) {
                if (IsForceReject(simManager)) {
                    resp.Decision = BFEvaluationDecision::Reject;
                    return resp;
                }
                if (IsBetterNosePos(simManager, curr)) {
                    resp.Decision = BFEvaluationDecision::Accept;
                    return resp;
                }
            }

            if (IsPastEvalTime(raceTime)) {
                resp.Decision = BFEvaluationDecision::Reject;
                return resp;
            }
        }
    }

    return resp;
}

/**
 * Project an angle in degrees in [-180; 180[
 */
double AngleProject180To180Deg(double angle_deg) {
    while (angle_deg < -180) {
        angle_deg += 360;
    }
    while (angle_deg >= 180) {
        angle_deg -= 360;
    }
    return angle_deg;
}

double ComputeCarAngleToTarget(SimulationManager@ simManager)
{
    // Get values
    vec3 speedVec = simManager.Dyna.CurrentState.LinearSpeed;
    float carYaw, carPit, carRol;
    simManager.Dyna.CurrentState.Location.Rotation.GetYawPitchRoll(carYaw, carPit, carRol); // -180 to 180°

    // Do calculations
    double targetYaw = GetD("shweetz_yaw_deg") + Math::ToDeg(Math::Atan2(speedVec.x, speedVec.z));
    double targetPit = GetD("shweetz_pitch_deg");
    double targetRol = GetD("shweetz_roll_deg");
    targetYaw = AngleProject180To180Deg(targetYaw);
    targetPit = AngleProject180To180Deg(targetPit);
    targetRol = AngleProject180To180Deg(targetRol);

    double diffYaw = Math::Abs(Math::ToDeg(carYaw) - targetYaw);
    double diffPit = Math::Abs(Math::ToDeg(carPit) - targetPit);
    double diffRol = Math::Abs(Math::ToDeg(carRol) - targetRol);
    diffYaw = diffYaw > 180 ? 360 - diffYaw : diffYaw;
    diffPit = diffPit > 180 ? 360 - diffPit : diffPit;
    diffRol = diffRol > 180 ? 360 - diffRol : diffRol;

    if (GetB("shweetz_allow_yaw_180")) {
        diffYaw = Math::Max(diffYaw - 90, 0.0); // [-90; 90]° yaw is ok to nosebug, so 100° should only add 10°
    }

    return diffYaw + diffPit + diffRol;
}

bool IsNosePos(SimulationManager@ simManager)
{
    // Conditions
    if (!AreConditionsMet(simManager)) {
        return false;
    }

    return ComputeCarAngleToTarget(simManager) < GetD("shweetz_angle_min_deg");
}

bool IsBetterNosePos(SimulationManager@ simManager, CarState& curr)
{
    Print("IsBetterNosePos");

    // Conditions
    if (!AreConditionsMet(simManager)) {
        return false;
    }

    // Get values
    vec3 pos = simManager.Dyna.CurrentState.Location.Position;
    float speedKmh = simManager.Dyna.CurrentState.LinearSpeed.Length() * 3.6;

    curr.angle = ComputeCarAngleToTarget(simManager);
    curr.distance = DistanceToPoint(pos);
    curr.speed = Math::Min(speedKmh, 1000);
    if (IsNosePos(simManager)) {
        if (curr.noseposUntil == 0 || curr.noseposUntil == curr.time - 10) {
            curr.noseposUntil = curr.time;
        }
    }

    if (best.distance == -1) {
        // Base run (past conditions)
        return true;
    }
    
    if (GetB("shweetz_next_eval_check")) {
        if (best.angle < GetD("shweetz_angle_min_deg") && curr.angle < GetD("shweetz_angle_min_deg")) {
            // Best and current have a good angle, now check next eval
            if (GetS("shweetz_next_eval") == "Point") {
                return curr.distance < best.distance;
            }
            if (GetS("shweetz_next_eval") == "Speed") {
                return curr.speed > best.speed;
            }
            if (GetS("shweetz_next_eval") == "Time") {
                return curr.time < best.time;
            }
        }
        if (GetS("shweetz_next_eval") == "Hold") {
            return curr.noseposUntil > best.noseposUntil;
        }
    }
    Print("" + curr.angle + " vs " + best.angle);
    return curr.angle < best.angle;
}

void PrintGreenTextNosePos(CarState best)
{
    string greenText = "base at " + best.time + ": angle=" + best.angle;
    if (GetS("shweetz_next_eval") == "Point") greenText += ", Distance=" + best.distance;
    if (GetS("shweetz_next_eval") == "Speed") greenText += ", Speed=" + best.speed;
    greenText += ", Iteration=" + iterations;
    print(greenText);
}

/*void OnSimulationBeginBf(SimulationManager@ simManager)
{
    best = CarState();
}*/
