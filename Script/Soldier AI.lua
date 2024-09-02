function init()
	SpectatingInfo = {
		Spectating = false,
		Index = nil,
		Body = nil,
		Mode = 1,
		NumberOfModes = 2,
		Head = nil,
	}
	Soldiers = {}
	Teams = {}
	DeadSoldiers = {}
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
						Team = GetTagValue(NewSoldier[i], "Team"),
						BeingSpectated = false,
						MovementInfo = {
							Timer = 0,
							State = GetTagValue(NewSoldier[i], "State") or "Standing",
						},
						TargetInfo = {
							Target = nil,
							Timer = 0,
							Dist = 0,
							CanSee = false,
							CheckTimer = math.random(2,5) + (0.1 * math.random(-1,1)) + math.random() - math.random(),
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
		DebugPrint(#Soldiers)
		local Soldier = Soldiers[i]
		local MovementInfo = Soldier.MovementInfo
		local TargetInfo = Soldier.TargetInfo
		local ShootInfo = Soldier.ShootInfo 
		local PathInfo = Soldier.PathInfo
		if Soldier.Alive then
			if SpectatingInfo.Body == Soldier.Body then
				Soldier.BeingSpectated = true
			else	
				Soldier.BeingSpectated = false
			end
			
			do -- Status
				if IsBodyBroken(Soldier.Body) then
					Soldier.Alive = false
				end
			end
			do -- Targeting
				
				if TargetInfo.CheckTimer <= 0 then
					QueryRejectBody(Soldier.Body)
					local hit, dist, normal, shape = QueryRaycast(GetLightTransform(Soldier.Head).pos, InvertVec(VecNormalize(VecSub(GetLightTransform(Soldier.Barell).pos,TransformToParentPoint(GetBodyTransform(TargetInfo.Target), GetBodyCenterOfMass(TargetInfo.Target))))), TargetInfo.Dist+10)
					if GetShapeBody(shape) == TargetInfo.Target then
						TargetInfo.CanSee = true
					elseif HasTag(GetShapeBody(shape), "Team") then
						if GetTagValue(GetShapeBody(shape), "Team") ~= Soldier.Team then
							TargetInfo.CanSee = true
						end
					else
						TargetInfo.CanSee = false
					end
					TargetInfo.CheckTimer = math.random(2,5) + (0.1 * math.random(-1,1)) + math.random() - math.random()
				end
				
				if TargetInfo.Timer <= 0 or IsBodyBroken(TargetInfo.Target) then
					TargetInfo.Target = GetTarget(Soldier)
					TargetInfo.Timer = math.random(25,30) + math.random() - math.random()
				end
				TargetInfo.Dist = VecLength(VecSub(GetBodyTransform(TargetInfo.Target).pos, GetBodyTransform(Soldier.Body).pos))
				TargetInfo.Timer = TargetInfo.Timer - dt
				TargetInfo.CheckTimer = TargetInfo.CheckTimer - dt
			end
			do -- Movement
				local LookingAt = Vec(GetBodyTransform(TargetInfo.Target).pos[1],GetBodyTransform(Soldier.Body).pos[2],GetBodyTransform(TargetInfo.Target).pos[3])
				if not TargetInfo.CanSee then
					LookingAt = Vec(GetPathPoint(PathInfo.CurrentPoint, PathInfo.ID)[1],GetBodyTransform(Soldier.Body).pos[2],GetPathPoint(PathInfo.CurrentPoint, PathInfo.ID)[3])
				end
				ConstrainOrientation(Soldier.Body, 
					0, 
					GetBodyTransform(Soldier.Body).rot, 
					QuatLookAt(GetBodyTransform(Soldier.Body).pos, 
					LookingAt),
					math.random(1,5)
				)
				if MovementInfo.State == "Standing" then
					if (not PathInfo.HasPath or PathInfo.Timer <= 0) and TargetInfo.Target then
						QueryRejectBody(Soldier.Body)
						PathPlannerQuery(PathInfo.ID, GetBodyTransform(Soldier.Body).pos, GetBodyTransform(TargetInfo.Target).pos, TargetInfo.Dist+10, math.random(5,23), "low")
						PathInfo.HasPath = true
						PathInfo.CurrentPoint = 3
						PathInfo.Timer = math.random(4,7) + (0.25 * math.random(-1,1)) + math.random() - math.random()
					end
					local State = GetPathState(PathInfo.ID)
					local Length = GetPathLength(PathInfo.ID)
					local State = GetPathState(PathInfo.ID)
					local DistToClosestPoint = VecLength(VecSub(GetPathPoint(PathInfo.CurrentPoint, PathInfo.ID), GetBodyTransform(Soldier.Body).pos))
					
					if DistToClosestPoint <= 0.75 then
						PathInfo.CurrentPoint = PathInfo.CurrentPoint + 3
					elseif DistToClosestPoint <= 4 then
						ConstrainPosition(Soldier.Body, 0, GetBodyTransform(Soldier.Body).pos, GetPathPoint(PathInfo.CurrentPoint, PathInfo.ID),5,5)
						
					end
					if Soldier.BeingSpectated then
						DebugCross(GetPathPoint(PathInfo.CurrentPoint, PathInfo.ID),0,0,1,1)
					end
					if MovementInfo.Timer <= 0 and GetBodyVelocity(Soldier.Body)[2] < 0.05 and GetBodyVelocity(Soldier.Body)[2] >= 0 and (ShootInfo.Timer > 0.5 or not TargetInfo.CanSee) then
						local DirectionToPathPoint = GetPathPoint(PathInfo.CurrentPoint, PathInfo.ID)
						SetBodyVelocity(Soldier.Body, VecAdd(VecScale(VecNormalize(VecSub(GetPathPoint(PathInfo.CurrentPoint, PathInfo.ID), GetBodyTransform(Soldier.Body).pos)),4), Vec(0, 4,0)))
						MovementInfo.Timer = 1 + math.random() - math.random()
					end
					MovementInfo.Timer = MovementInfo.Timer - dt
					PathInfo.Timer = PathInfo.Timer - dt
				end
			end
			do -- Debug
				if Soldier.Team == "Green" then
					--DrawBodyOutline(Soldier.Body, 0,1,0,1)
					--DrawLine(GetLightTransform(Soldier.Head).pos, VecAdd(GetBodyTransform(TargetInfo.Target).pos,Vec(0,1,0)), 0, 0 , 1, 1)
				elseif Soldier.Team == "Red" then
					--DrawBodyOutline(Soldier.Body, 1,0,0,1)
				end
				--DebugCross(GetLightTransform(Soldier.Head).pos)
				--DebugCross(GetLightTransform(Soldier.Barell).pos)
				
			end
			do -- Shooting
				if TargetInfo.Target then
					if ShootInfo.Timer <= 0 then
						if TargetInfo.CanSee then
							Shoot(GetLightTransform(Soldier.Barell).pos, InvertVec(VecNormalize(VecSub(GetLightTransform(Soldier.Barell).pos, VecAdd(GetBodyTransform(TargetInfo.Target).pos,Vec(math.random()-math.random(),math.random(0,2) + math.random() - math.random() ,math.random()-math.random()))))),"gun",1,200)
							ShootInfo.Timer = 0.5--math.random(1,2) + math.random() - math.random()
						end
					end
					if Soldier.BeingSpectated then
						if TargetInfo.CanSee then
							--DrawLine(GetLightTransform(Soldier.Head).pos, VecAdd(GetBodyTransform(TargetInfo.Target).pos, Vec(0,1,0)),0,0,1,1)
						else
							--DrawLine(GetLightTransform(Soldier.Head).pos, VecAdd(GetBodyTransform(TargetInfo.Target).pos, Vec(0,1,0)),1,0,0,1)
						end
					end
					ShootInfo.Timer = ShootInfo.Timer - dt 
				end
			end
			do -- State
				if MovementInfo.State == "Prone" and InputPressed("h") then
					ChangeSoldierState(Soldier, i, "Standing")
				elseif MovementInfo.State == "Standing" and InputPressed("g") then
					ChangeSoldierState(Soldier, i, "Prone")
				end	
			end
		
		else
			SetBodyVelocity(Soldier.Body, Vec(math.random() * math.random(-8,8),math.random() * math.random(2,7),math.random() * math.random(-8,8)))
			DeletePathPlanner(PathInfo.ID)
			table.insert(DeadSoldiers, Soldier.Body)
			table.remove(Soldiers, i)
			Teams[Soldier.Team][Soldier.Body] = nil
		end
	end
	
	
	
	if SpectatingInfo.Spectating then
		if #Soldiers == 0 then
			SpectatingInfo.Spectating = false
		end
		if SpectatingInfo.Index == nil or IsBodyBroken(SpectatingInfo.Body) or InputPressed("8") then
			SpectatingInfo.Index = math.random(1,#Soldiers)
			SpectatingInfo.Body = Soldiers[SpectatingInfo.Index].Body
			SpectatingInfo.Head = Soldiers[SpectatingInfo.Index].Head
		end
		if InputPressed("7") then
			if SpectatingInfo.Mode < SpectatingInfo.NumberOfModes then
				SpectatingInfo.Mode = SpectatingInfo.Mode + 1 
			else 
				SpectatingInfo.Mode = 1
			end
		end
		if SpectatingInfo.Mode == 1 then
			SetCameraTransform(Transform(
			VecAdd(TransformToParentPoint(GetBodyTransform(SpectatingInfo.Body), GetBodyCenterOfMass(SpectatingInfo.Body)),Vec(0,16,0)),
			QuatEuler(-90,0,0)))
			DrawBodyOutline(SpectatingInfo.Body,1,1,1,1)
		elseif SpectatingInfo.Mode == 2 then
			SetCameraTransform(Transform(
				VecAdd(GetLightTransform(SpectatingInfo.Head).pos, Vec(0, 1, 0)),
				QuatRotateQuat(GetLightTransform(SpectatingInfo.Head).rot, QuatEuler(-15,0,0))
				
			
			))
		end	
		RequestFirstPerson(true)
		SetPlayerHidden()
	end
	if InputPressed("9") then	
		SpectatingInfo.Spectating = not SpectatingInfo.Spectating
	end
end

function ChangeSoldierState(Soldier, Index, State)
	path = nil
	if State == "Standing" then
		path = '<vox pos="0.0 0.0 0.1" rot="0.0 90.0 0.0" file="MOD/Vox/Army Men '.. Soldier.Team ..'.vox" object="standfire"><light name="Head" tags="Part=Head" pos="-0.45 1.7 -0.05" rot="0.0 -90.0 0.0" color="0.0 0.0 0.0" size="0.1"/><light name="Barell" tags="Part=Barell" pos="0.95 1.55 0.05" rot="0.0 -90.0 0.0" color="0.0 0.0 0.0" size="0.05"/></vox>'
	elseif State == "Prone" then
		path = '<vox tags="unbreakabel" pos="0.0 0.0 0.1" rot="0.0 90.0 0.0" file="MOD/Vox/Army Men '.. Soldier.Team ..'.vox" object="pronefire"><light name="Head" tags="Part=Head" pos="0.25 0.3 -0.05" rot="0.0 -90.0 0.0" color="0.0 0.0 0.0" size="0.1"/><light name="Barell" tags="Part=Barell" pos="1.65 0.15 0.05" color="0.0 0.0 0.0" size="0.05"/></vox>'
	end
	
	local entity = Spawn(path,GetBodyTransform(Soldier.Body))	
	local Table = {
		shapes = {},
		lights = {},
	}
	local oldshapes = GetBodyShapes(Soldier.Body)
	for i=1,#oldshapes do 
		Delete(oldshapes[i])
	end	
	
	for i=1,#entity do 
		if GetEntityType(entity[i]) == "shape" then
			table.insert(Table.shapes, entity[i])
		end
		if GetEntityType(entity[i]) == "light" then
			table.insert(Table.lights, {shape = entity[i], transform = GetLightTransform(entity[i])})
		end
	end
	for i=1,#Table.shapes do
		local transform = TransformToLocalTransform(GetBodyTransform(Soldier.Body),GetShapeWorldTransform(Table.shapes[i]))	
		SetShapeBody(Table.shapes[i], Soldier.Body,transform)
	end
	for i=1,#Table.lights do
		local trans1 = Table.lights[i].transform
		local light = Table.lights[i].shape
		
		SetProperty(light, "transform", TransformToLocalTransform(GetBodyTransform(Soldier.Body),trans1))
	end
	local Lights = {}
		local Shapes = GetBodyShapes(Soldier.Body)
		for j=1,#Shapes do
			local ShapeLights = GetShapeLights(Shapes[j])
			for k=1,#ShapeLights do 
				Lights[GetTagValue(ShapeLights[k],"Part")] = ShapeLights[k]
			end
		end
	
	Soldiers[Index] = {
		Body = Soldier.Body,
		Head = Lights.Head,
		Barell = Lights.Barell,
		Alive = true,
		Team = Soldier.Team,
		BeingSpectated = false,
		MovementInfo = {
			Timer = Soldier.MovementInfo.Timer,
			State = State,
		},
		TargetInfo = {
			Target = Soldier.TargetInfo.Target,
			Timer = Soldier.TargetInfo.Timer,
			Dist = Soldier.TargetInfo.Dist,
			CanSee = false,
			CheckTimer = 0,
			},
		ShootInfo = {
			Timer = Soldier.ShootInfo.Timer,				
		},
		PathInfo = {
			Timer = Soldier.PathInfo.Timer,
			HasPath = Soldier.PathInfo.HasPath,
			ID = Soldier.PathInfo.ID,
			CurrentPoint = Soldier.PathInfo.CurrentPoint,
		}
	}
	SetBodyDynamic(Soldier.Body, true)
end

function InvertVec(OldVec)
	local NewVec = Vec(-OldVec[1],-OldVec[2],-OldVec[3])
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