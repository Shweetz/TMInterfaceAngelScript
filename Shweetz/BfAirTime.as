//namespace AirTime
//{
    array<int> baseAirTimes;
    auto bestAirTime = -1;
    auto currAirTime = 0;
    auto currTime = 0;
    auto num = 0;
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
}

BFEvaluationResponse@ OnEvaluateAirTime(SimulationManager@ simManager, const BFEvaluationInfo&in info)
{
    int oldTime = currTime;
    int raceTime = simManager.TickTime; // After finishing, TickTime=time+10 while RaceTime has the same value twice in a row
    bool hasRewinded = currTime + 10 != raceTime;
        //print("1currTime=" + a + ", raceTime=" + raceTime);
    currTime = raceTime;

    int baseIndex = (raceTime - int(GetD("shweetz_eval_time_min"))) / 10;
    bool inAir = CountWheelsOnGround(simManager) == 0;

    auto resp = BFEvaluationResponse();
    if (baseIndex < 0) {
        currAirTime = 0;
        return resp;
    }
    //print("oldTime=" + oldTime + ", raceTime=" + raceTime + ", currAirTime=" + currAirTime);
    if (hasRewinded) {
        //print("hasRewinded");
        if (baseIndex >= int(baseAirTimes.Length)) {
            print("error: raceTime: " + raceTime + "=>" + baseIndex + ">" + baseAirTimes.Length);
            return resp;
        }
        currAirTime = baseAirTimes[baseIndex];
        //print("currAirTime=" + currAirTime);
        return resp; // return if "currAirTime += 10;" before "baseAirTimes[baseIndex] = currAirTime" ?
    }
            if (inAir) {
                currAirTime += 10;
            }

    if (info.Phase == BFPhase::Initial) {
        if (IsEvalTime(raceTime)) {
            //print("" + raceTime + "=>" + baseIndex + ", " + GetD("shweetz_eval_time_max"));
            /*if (IsBetterAirTime(simManager, curr)) {
                best = curr;
            }*/
            //print("try");
            if (baseIndex >= int(baseAirTimes.Length)) {
                baseAirTimes.Add(currAirTime);
            } else {
                baseAirTimes[baseIndex] = currAirTime;
            }
            
            //print("success");
        }

        if (IsMaxTime(raceTime)) {
            print("better airtime: " + currAirTime);
            PrintArray(baseAirTimes);
            print("");
            bestAirTime = currAirTime;
        }
    }
    else {
        if (IsEvalTime(raceTime)) {
            if (IsForceReject(simManager)) {
                resp.Decision = BFEvaluationDecision::Reject;
                return resp;
            }
            if (IsBetterAirTime(simManager)) {
                //print("accept");
                resp.Decision = BFEvaluationDecision::Accept;
                return resp;
            }
        }

        if (IsPastEvalTime(raceTime)) {
            //print("worse at " + raceTime + ": distance=" + curr.distance);
            resp.Decision = BFEvaluationDecision::Reject;
            return resp;
        }
    }

    return resp;
}

bool IsForceReject(SimulationManager@ simManager)
{
    if (simManager.SceneVehicleCar.HasAnyLateralContact) {
        num += 1;
        print("hit wall - " + num);
        return true;
    }

    return bestAirTime != -1 && currAirTime >= bestAirTime;
}

bool IsBetterAirTime(SimulationManager@ simManager)
{
    int raceTime = simManager.PlayerInfo.RaceTime;
    if (IsMaxTime(raceTime)) {
        //print("currAirTime=" + currAirTime + ", bestAirTime=" + bestAirTime);
    }
    return IsMaxTime(raceTime) && currAirTime <= bestAirTime;
}

void PrintGreenTextAirTime(CarState best)
{
    string greenText = "base at " + best.time + ": airtime=" + bestAirTime;
    print(greenText);
}
