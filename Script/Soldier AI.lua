function init()
	Soldiers = {}
	Teams = {}
	do 
		local NewSoldier = FindBodies("Initiate", true)
		if #NewSoldier ~= 0 then
			for i=1,#NewSoldier do 
				local Lights = {}
				local Shapes = GetBodyShapes(NewSoldier[i])
				for j=1,#Shapes do
					local ShapeLights = GetShapeLights(Shapes[j])
					for k=1,#ShapeLights do 
						Lights[GetTagValue(ShapeLights[k],"Part")] = ShapeLights[k]
					end
				end
				table.insert(Soldiers,{
						Body = NewSoldier[i],
						Head = Lights.Head,
						Barell = Lights.Barell,
						Alive = true,
						CanSeeTarget = false,
						Team = GetTagValue(NewSoldier[i], "Team"),
						MovementInfo = {
							Timer = 0
						
						},
						TargetInfo = {
							Target = nil,
							Timer = 0,
							Dist = 0,
						},
						ShootInfo = {
							Timer = math.random(1,5) + math.random() - math.random(),
						
						
						},
						PathInfo = {
							Timer = 0,
							HasPath = false,
							ID = CreatePathPlanner(),
							CurrentPoint = 3,
						}
					}
				)
				if not Teams[GetTagValue(NewSoldier[i], "Team")] then
					Teams[GetTagValue(NewSoldier[i], "Team")] = {}
				end
				Teams[GetTagValue(NewSoldier[i], "Team")][NewSoldier[i]] = {}
				RemoveTag(NewSoldier[i], "Initiate")
			end
		end
	end
end

function tick(dt)
	for i = #Soldiers, 1, -1 do
		local Soldier = Soldiers[i]
		local MovementInfo = Soldier.MovementInfo
		local TargetInfo = Soldier.TargetInfo
		local ShootInfo = Soldier.ShootInfo 
		local PathInfo = Soldier.PathInfo
		if Soldier.Alive then
			do -- Status
				if IsBodyBroken(Soldier.Body) then
					Soldier.Alive = false
				end
			end
			
	
			do -- Targeting
				if TargetInfo.Timer <= 0 or IsBodyBroken(TargetInfo.Target) then
					TargetInfo.Target = GetTarget(Soldier)
					TargetInfo.Timer = math.random(25,30) + math.random() - math.random()
				end
				TargetInfo.Dist = VecLength(VecSub(GetBodyTransform(TargetInfo.Target).pos, GetBodyTransform(Soldier.Body).pos))
				TargetInfo.Timer = TargetInfo.Timer - dt
			end
			do -- Movement
				ConstrainOrientation(Soldier.Body, 
					0, 
					GetBodyTransform(Soldier.Body).rot, 
					QuatLookAt(GetBodyTransform(Soldier.Body).pos, 
					Vec(GetBodyTransform(TargetInfo.Target).pos[1],GetBodyTransform(Soldier.Body).pos[2],GetBodyTransform(TargetInfo.Target).pos[3])),
					math.random(1,5)
				)
				if (not PathInfo.HasPath or PathInfo.Timer <= 0) and TargetInfo.Target then
					QueryRejectBody(Soldier.Body)
					PathPlannerQuery(PathInfo.ID, GetBodyTransform(Soldier.Body).pos, GetBodyTransform(TargetInfo.Target).pos, 100, math.random(5,12), "low")
					PathInfo.HasPath = true
					PathInfo.Timer = math.random(5,9) + (0.25 * math.random(-1,1))
				end
				local State = GetPathState(PathInfo.ID)
				local Length = GetPathLength(PathInfo.ID)
				local State = GetPathState(PathInfo.ID)
				local DistToClosestPoint = VecLength(VecSub(GetPathPoint(PathInfo.CurrentPoint, PathInfo.ID), GetBodyTransform(Soldier.Body).pos))

				if DistToClosestPoint <= 1 then
					PathInfo.CurrentPoint = PathInfo.CurrentPoint + 3
				end

				if MovementInfo.Timer <= 0 and GetBodyVelocity(Soldier.Body)[2] < 0.05 and GetBodyVelocity(Soldier.Body)[2] >= 0 then
					local DirectionToPathPoint = GetPathPoint(PathInfo.CurrentPoint, PathInfo.ID)
					SetBodyVelocity(Soldier.Body, VecAdd(VecScale(VecNormalize(VecSub(GetPathPoint(PathInfo.CurrentPoint, PathInfo.ID), GetBodyTransform(Soldier.Body).pos)),3), Vec(0, 4, 0)))


				
					MovementInfo.Timer = math.random(0,1) + math.random() - math.random()
				end
				MovementInfo.Timer = MovementInfo.Timer - dt
				PathInfo.Timer = PathInfo.Timer - dt
			end
			do -- Debug
				if Soldier.Team == "Green" then
					--DrawBodyOutline(Soldier.Body, 0,1,0,1)
					--DrawLine(GetLightTransform(Soldier.Head).pos, VecAdd(GetBodyTransform(TargetInfo.Target).pos,Vec(0,1,0)), 0, 0 , 1, 1)
				elseif Soldier.Team == "Red" then
					--DrawBodyOutline(Soldier.Body, 1,0,0,1)
				end
				DebugCross(GetLightTransform(Soldier.Head).pos)
				DebugCross(GetLightTransform(Soldier.Barell).pos)
				
			end
			do -- Shooting
				if TargetInfo.Target then
					if ShootInfo.Timer <= 0 then
						if TargetInfo.Dist <= math.random(5,15) then
							Shoot(GetLightTransform(Soldier.Barell).pos, InvertVec(VecNormalize(VecSub(GetLightTransform(Soldier.Barell).pos, VecAdd(GetBodyTransform(TargetInfo.Target).pos,Vec(math.random()-math.random(),1.5,math.random()-math.random()))))),"gun")
							ShootInfo.Timer = math.random(1,2) + math.random() - math.random()
						end
					end
					ShootInfo.Timer = ShootInfo.Timer - dt 
				end
			end

		
		else
			SetBodyVelocity(Soldier.Body, Vec(math.random() * math.random(-8,8),math.random() * math.random(2,7),math.random() * math.random(-8,8)))
			DeletePathPlanner(PathInfo.ID)
			table.remove(Soldiers, i)
			Teams[Soldier.Team][Soldier.Body] = nil
		end
	end
end

function InvertVec(OldVec)
	local NewVec = Vec(-OldVec[1],OldVec[2],-OldVec[3])
	return NewVec
end

function GetTarget(Soldier)
	local ViableTargets = {}
	local EnemyTeam = nil
	local Target = nil
	local ClosestTarget = nil
	local ClosestDist = 900
	local EnemyTeams = {}
	do
		for Team, _ in pairs(Teams) do 
			if Team ~= Soldier.Team then
				table.insert(EnemyTeams, Team)
			end
		end
		for i=1,#EnemyTeams do 
			for Target, TargetInfo in pairs(Teams[EnemyTeams[i]]) do
				local Dist = VecLength(VecSub(GetBodyTransform(Target).pos, GetBodyTransform(Soldier.Body).pos))
				if Dist < ClosestDist then
					ClosestTarget = Target
					ClosestDist = Dist
				end
			end
		end
	end
	return ClosestTarget
end
