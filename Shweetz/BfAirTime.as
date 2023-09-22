//namespace AirTime
//{
    array<int> baseAirTimes;
    //auto bestAirTime = -1;
    //auto currAirTime = 0;
    //auto currTime = 0;
//}

void UIBfAirTime()
{
    UIAirTime();
    UI::Separator();
    UIConditions();
}

void UIAirTime()
{
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

    // Change eval
    if (UI::CheckboxVar("Change eval if AirTime is tied to best", "shweetz_next_eval_check"))
    {
        // UI::TextDimmed("Good enough means angle can be some degrees off from ideal nosepos.");
        // UI::InputIntVar("Max angle from ideal (°)", "shweetz_angle_min_deg", 1);

        UINextEval();
    }

    UI::Dummy( vec2(0, 25) );
}

BFEvaluationResponse@ OnEvaluateAirTime(SimulationManager@ simManager, const BFEvaluationInfo&in info)
{
    int oldTime = prevTime;
    int raceTime = simManager.TickTime; // After finishing, TickTime=time+10 while RaceTime has the same value twice in a row
    prevTime = raceTime;

    curr.ResetForNewTick();
    curr.time = raceTime;

    int baseIndex = (raceTime - int(GetD("shweetz_eval_time_min"))) / 10;
    bool inAir = CountWheelsOnGround(simManager) == 0;
    iterations = info.Iterations;

    auto resp = BFEvaluationResponse();
    if (baseIndex < 0) {
        curr.airTime = 0;
        return resp;
    }
    //print("oldTime=" + oldTime + ", raceTime=" + raceTime + ", curr.airTime=" + curr.airTime);
    if (info.Rewinded) {
        if (baseIndex >= int(baseAirTimes.Length)) {
            //print("error: raceTime: " + raceTime + "=>" + baseIndex + ">" + baseAirTimes.Length);
            return resp;
        }
        curr.airTime = baseAirTimes[baseIndex];
        return resp;
    }
    if (inAir) {
        curr.airTime += 10;
    }

    if (info.Phase == BFPhase::Initial) {
        if (IsEvalTime(raceTime)) {
            if (baseIndex >= int(baseAirTimes.Length)) {
                baseAirTimes.Add(curr.airTime);
            } else {
                baseAirTimes[baseIndex] = curr.airTime;
            }
        }

        if (IsMaxTime(raceTime) && IsBetterAirTime(simManager)) {
            //print("curr.speed=" + curr.speed + ", raceTime=" + raceTime + ", best.speed=" + best.speed);
            best = curr;
            PrintGreenTextAirTime(best);
        }
    }
    else {
        if (IsEvalTime(raceTime)) {
            if (IsForceRejectAirTime(simManager)) {
                resp.Decision = BFEvaluationDecision::Reject;
                return resp;
            }
            if (IsBetterAirTime(simManager)) {
                // print("better airtime: " + curr.airTime);
                resp.Decision = BFEvaluationDecision::Accept;
                return resp;
            }
        }

        if (IsPastEvalTime(raceTime)) {
            resp.Decision = BFEvaluationDecision::Reject;
            return resp;
        }
    }

    return resp;
}

bool IsForceRejectAirTime(SimulationManager@ simManager)
{
    if (IsForceReject(simManager)) {
        return true;
    }
    if (simManager.SceneVehicleCar.HasAnyLateralContact) {
        print("hit wall - " + iterations);
        return true;
    }

    return best.airTime != -1 && curr.airTime > best.airTime;
}

bool IsBetterAirTime(SimulationManager@ simManager)
{
    int raceTime = simManager.PlayerInfo.RaceTime;
    if (!IsMaxTime(raceTime)) {
        return false;
    }

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

    if (best.distance == -1) {
        // Base run (past conditions)
        return true;
    }

    if (curr.airTime < best.airTime) {
        return true;
    }

    if (curr.airTime > best.airTime) {
        return false;
    }
    
    if (GetB("shweetz_next_eval_check")) {
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
    
    return false;
}

void PrintGreenTextAirTime(CarState best)
{
    string greenText = "Best iteration: AirTime=" + best.airTime;
    if (GetS("shweetz_next_eval") == "Point") greenText += ", Distance=" + best.distance;
    if (GetS("shweetz_next_eval") == "Speed") greenText += ", Speed=" + FormatSpeed(best.speed);
    greenText += ", Iteration=" + iterations;
    print(greenText);
    // TODO print air ticks instead
    //PrintArray(baseAirTimes);
    //print("");
}
