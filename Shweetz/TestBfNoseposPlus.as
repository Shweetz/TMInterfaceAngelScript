/*class CarState
{
    double time = -1;
    double angle = -1;
    double distance = -1;
    double speed = -1;
}

auto best = CarState();*/

//bool TestAreConditionsMet
/*bool TestIsBetterNosePos(SimulationManager@ simManager, CarState& curr) {
    // Get values
    int raceTime = simManager.PlayerInfo.RaceTime;
    vec3 pos = simManager.Dyna.CurrentState.Location.Position;
    vec3 speedVec = simManager.Dyna.CurrentState.LinearSpeed;
    float speed = Norm(speedVec);
    float speedKmh = speed * 3.6;
    float carYaw, carPitch, carRoll;
    simManager.Dyna.CurrentState.Location.Rotation.GetYawPitchRoll(carYaw, carPitch, carRoll);

    // Conditions
    if (!AreConditionsMet(simManager)) {
        return false;
    }
    
    // Do calculations
    double targetYaw = Math::ToDeg(Math::Atan2(speedVec.x, speedVec.z));
    double targetPitch = 90;
    double targetRoll = 0;

    double diffYaw   = Math::Abs(Math::ToDeg(carYaw) - targetYaw);
    double diffPitch = Math::Abs(Math::ToDeg(carPitch) - targetPitch);
    double diffRoll  = Math::Abs(Math::ToDeg(carRoll) - targetRoll);
    diffYaw = Math::Max(diffYaw - 90, 0.0); // [-90; 90]° yaw is ok to nosebug, so 100° should only add 10°

    curr.angle = diffYaw + diffPitch + diffRoll;
    curr.distance = DistanceToPoint(pos);
    curr.speed = speedKmh;

    //print("distance=" + curr.distance);
    //print("" + raceTime + ": distance=" + DistanceToPoint(pos));

    if (best.distance == -1) {
        // Base run (past conditions)
        return true;
    } 
    
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
    //print("" + curr.angle + " vs " + best.angle);
    return curr.angle < best.angle;
}*/

/*void OnSimulationBeginBf(SimulationManager@ simManager)
{
    best = CarState();
}*/
