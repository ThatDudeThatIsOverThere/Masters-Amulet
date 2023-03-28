--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local applyDamageOriginal;
local messageDamageOriginal;

function onInit()
	table.insert(DataCommon.conditions, "bound");
	table.insert(DataCommon.conditions, "Guardian");

	applyDamageOriginal = ActionDamage.applyDamage;
	ActionDamage.applyDamage = applyDamage;
	
	messageDamageOriginal = ActionDamage.messageDamage;
	ActionDamage.messageDamage = messageDamage;
	
	getDamageAdjustOriginal = ActionDamage.getDamageAdjust;
	ActionDamage.getDamageAdjust = getDamageAdjust;
end

function applyDamage(rSource, rTarget, rRoll)
	local nAmuletOddCheck = 0; --To apply +1 damage to a Shield Guardian if the damage to their Bound PC is odd.
	local bGuardianCheck = false; --To check if damage is being split.
	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	local nAdjustedDamage = 0;
	if not nodeTarget then
		return;
	end
	
	local rDamageOutput = ActionDamage.decodeDamageText(rRoll.nTotal, rRoll.sDesc);
	if rRoll then
		rRoll.aDamageTypes = rDamageOutput.aDamageTypes;
	end
	--make tNotifications into a table
	if not rDamageOutput.tNotifications then
		rDamageOutput.tNotifications = {};
	end
	if (rRoll.sType == "damage") then
		local nDamageAdjust, bVulnerable, bResist, bVulnerable2, bResist2, bImmune2, nDamageTypeCount, nImmuneCount, nResistCount, nVulnerableCount = getDamageAdjust(rSource, rTarget, rDamageOutput.nVal, rDamageOutput);
		nAdjustedDamage = rDamageOutput.nVal + nDamageAdjust;
		
		if nAdjustedDamage < 0 then
			nAdjustedDamage = 0;
		end
		
		if bImmune2 then
			if (nAdjustedDamage <= 0) then
				rRoll.sDesc = rRoll.sDesc .. "[IMMUNE]";
			end
			if ((nDamageTypeCount > nImmuneCount) and (nImmuneCount > 0)) then
				rRoll.sDesc = rRoll.sDesc .. "[PARTIALLY IMMUNE]";
			end
		end
		if bResist2 then
			if (nDamageTypeCount == nResistCount) then
				rRoll.sDesc = rRoll.sDesc .. "[RESISTED]";
			end
			if ((nDamageTypeCount > nResistCount) and (nResistCount > 0)) then
				rRoll.sDesc = rRoll.sDesc .. "[PARTIALLY RESISTED]";
			end
		end
		if bVulnerable2 then
			if (nDamageTypeCount == nVulnerableCount) then
				rRoll.sDesc = rRoll.sDesc .. "[VULNERABLE]";
			end
			if ((nDamageTypeCount > nVulnerableCount) and (nVulnerableCount > 0)) then
				rRoll.sDesc = rRoll.sDesc .. "[PARTIALLY VULNERABLE]";
			end
		end
		
		if (EffectManager5E.hasEffectCondition(rTarget, "Bound") and (rDamageOutput.sType == "damage") and (nAdjustedDamage > 0)) then
			for _,v in ipairs(DB.getChildList(ActorManager.getCTNode(rTarget), "effects")) do
				local sLabel = DB.getValue(v, "label", "");
				-- Get the source of the effect
				local sSource = DB.getValue(v, "source_name", "");
				local rEffectSource = ActorManager.resolveActor(sSource);
				if rEffectSource then 
					if (EffectManager5E.hasEffectCondition(rEffectSource, "Guardian")) then
						bGuardianCheck = true;
					end
				end
			end
		end
		
		if (bGuardianCheck) then	
			nAmuletOddCheck = (nAdjustedDamage % 2);
			nAdjustedDamage = math.floor(nAdjustedDamage / 2);

			--Making the math actually apply to the damage total.
			rRoll.nTotal = nAdjustedDamage;
			-- Also update the sDesc to get rid of the damage type warning.
			local sNewDesc = "";
			

			
			-- finding the start of the sections to be added to sNewDesc and adding everything before that to the base variable.
			local sDescIndex = (tonumber((string.find(rRoll.sDesc, "TYPE")) - 3))
			sNewDesc = (string.sub(rRoll.sDesc, 1, sDescIndex));
			
			-- adding a counter to swap between floor and ceil
			local countOddDamageValues = 1;
			
			local sNewDamageSubTotal = ""; -- Have to declare this up here to fix the nil problem
			
			-- Add approprite damage tags after Amulet
			local otherTags = "";
			-- find last instance of TYPE, then find next instance of ] from there, then grab the rest.
			local _, typeIndex = string.find(rRoll.sDesc, ".*TYPE");			
			local tagIndex = string.find(rRoll.sDesc, "%]", typeIndex);
			otherTags = string.sub(rRoll.sDesc, tagIndex + 1);
			
			for sDamageType, sDamageDice, sDamageSubTotal in string.gmatch(rRoll.sDesc, "%[TYPE: ([^(]*) %(([%d%+%-dD]+)%=(%d+)%)%]") do
				if(((countOddDamageValues % 2) == 1) and ((tonumber(sDamageSubTotal) % 2) == 1)) then
					sNewDamageSubTotal = tostring(math.floor(tonumber(sDamageSubTotal) / 2));
					countOddDamageValues = countOddDamageValues + 1;
				elseif(((countOddDamageValues % 2) == 0) and ((tonumber(sDamageSubTotal) % 2) == 1)) then
					sNewDamageSubTotal = tostring(math.ceil(tonumber(sDamageSubTotal) / 2));
					countOddDamageValues = countOddDamageValues + 1;
				else
					sNewDamageSubTotal = tostring(math.floor(tonumber(sDamageSubTotal) / 2));
				end
				
				sNewDesc = sNewDesc .. " " .. "[TYPE: " .. sDamageType .. "(" .. sDamageDice .. " Split With Guardian =" .. tostring(sNewDamageSubTotal) .. ")]";  -- not sure if this tostring should stay. Currently nothing bad happens if nil, was breaking for me without it when nil even though it exists on 98 and 100
			end
			
			print(rRoll.sDesc)
			
			rRoll.sDesc = sNewDesc;
			rRoll.sDesc = rRoll.sDesc .. " [AMULET] " .. otherTags;	

			print(rRoll.sDesc)
			
		end
	end
		
	EffectManager.startDelayedUpdates();
	applyDamageOriginal(rSource, rTarget, rRoll);
		--apply damage to Shield Guardian *after* original damage is done.
		if ((bGuardianCheck) and (rRoll.sType == "damage")) then
			local rGuardianRoll = {};
			for key, value in pairs(rRoll) do
				rGuardianRoll[key] = value;
			end
			rGuardianRoll.nTotal =  nAdjustedDamage + nAmuletOddCheck;
			rGuardianRoll.sDesc = "[TYPE: amulet=" .. rGuardianRoll.nTotal .. "]";
			-- Loop through the effects, looking for the bound effect being applied by a shield guardian
			for _,v in ipairs(DB.getChildList(ActorManager.getCTNode(rTarget), "effects")) do
				local sLabel = DB.getValue(v, "label", "");
				if (sLabel == "Bound") then
					-- Get the name of the source of the effect
					local sSource = DB.getValue(v, "source_name", "");
					local rEffectSource = ActorManager.resolveActor(sSource);
					if rEffectSource then 
						--Make sure the source of the effect is actually a Shield Guardian
						if (EffectManager5E.hasEffectCondition(rEffectSource, "Guardian")) then
							-- Apply damage to the Guardian
							rGuardianRoll.sDesc = rGuardianRoll.sDesc .. " [GUARDIAN]";
							applyDamageOriginal(rSource, rEffectSource, rGuardianRoll);
						end
					end
				end
			end
		end
	bGuardianCheck = false;
	EffectManager.endDelayedUpdates();
end

function getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput)
	local nDamageAdjust = 0;
	local bVulnerable2 = false;
	local bResist2 = false;
	local bImmune2 = false;
	local bResist = false;
	local bVulnerable = false;
	local nDamageTypeCount = 0;
	local nImmuneCount = 0;
	local nResistCount = 0;
	local nVulnerableCount = 0;

	-- Get damage adjustment effects
	local aVuln = ActorManager5E.getDamageVulnerabilities(rTarget, rSource);
	local aResist = ActorManager5E.getDamageResistances(rTarget, rSource);
	local aImmune = ActorManager5E.getDamageImmunities(rTarget, rSource);

	-- Handle immune all
	if aImmune["all"] then
		nDamageAdjust = 0 - nDamage;
		bImmune2 = true;
		return nDamageAdjust, bVulnerable2, bResist2, bImmune2, nDamageTypeCount, nImmuneCount, nResistCount, nVulnerableCount;
	end

	-- Iterate through damage type entries for vulnerability, resistance and immunity
	local nVulnApplied = 0;
	local bResistCarry = false;
	for k, v in pairs(rDamageOutput.aDamageTypes) do
		-- Get individual damage types for each damage clause
		local aSrcDmgClauseTypes = {};
		local aTemp = StringManager.split(k, ",", true);
		for _,vType in ipairs(aTemp) do
			if vType ~= "untyped" and vType ~= "" then
				table.insert(aSrcDmgClauseTypes, vType);
			end
		end

		-- Handle standard immunity, vulnerability and resistance
		local bLocalVulnerable = ActionDamage.checkReductionType(aVuln, aSrcDmgClauseTypes);
		local bLocalResist = ActionDamage.checkReductionType(aResist, aSrcDmgClauseTypes);
		local bLocalImmune = ActionDamage.checkReductionType(aImmune, aSrcDmgClauseTypes);

		-- Calculate adjustment
		-- Vulnerability = double
		-- Resistance = half
		-- Immunity = none
		nDamageTypeCount = nDamageTypeCount + 1;
		local nLocalDamageAdjust = 0;
		if bLocalImmune then
			nLocalDamageAdjust = -v;
			bImmune2 = true;
			nImmuneCount = nImmuneCount + 1;
		else
			-- Handle numerical resistance
			local nLocalResist = ActionDamage.checkNumericalReductionType(aResist, aSrcDmgClauseTypes, v);
			if nLocalResist ~= 0 then
				nLocalDamageAdjust = nLocalDamageAdjust - nLocalResist;
				bResist2 = true;
				nResistCount = nResistCount + 1;
			end
			-- Handle numerical vulnerability
			local nLocalVulnerable = ActionDamage.checkNumericalReductionType(aVuln, aSrcDmgClauseTypes);
			if nLocalVulnerable ~= 0 then
				nLocalDamageAdjust = nLocalDamageAdjust + nLocalVulnerable;
				bVulnerable2 = true;
				nVulnerableCount = nVulnerableCount + 1;
			end
			-- Handle standard resistance
			if bLocalResist then
				local nResistOddCheck = (nLocalDamageAdjust + v) % 2;
				local nAdj = math.ceil((nLocalDamageAdjust + v) / 2);
				nLocalDamageAdjust = nLocalDamageAdjust - nAdj;
				if nResistOddCheck == 1 then
					if bResistCarry then
						nLocalDamageAdjust = nLocalDamageAdjust + 1;
						bResistCarry = false;
					else
						bResistCarry = true;
					end
				end
				bResist2 = true;
				nResistCount = nResistCount + 1;
			end
			-- Handle standard vulnerability
			if bLocalVulnerable then
				nLocalDamageAdjust = nLocalDamageAdjust + (nLocalDamageAdjust + v);
				bVulnerable2 = true;
				nVulnerableCount = nVulnerableCount + 1;
			end

		end

		-- Apply adjustment to this damage type clause
		nDamageAdjust = nDamageAdjust + nLocalDamageAdjust;
	end

	-- Handle damage and mishap threshold
	if (rTarget.sSubtargetPath or "") ~= "" then
		local nDT = DB.getValue(DB.getPath(rTarget.sSubtargetPath, "damagethreshold"), 0);
		if (nDT > 0) and (nDT > (nDamage + nDamageAdjust)) then
			nDamageAdjust = 0 - nDamage;
			bImmune2 = true;
		end
	else
		local nDT = ActorManager5E.getDamageThreshold(rTarget);
		if (nDT > 0) and (nDT > (nDamage + nDamageAdjust)) then
			nDamageAdjust = 0 - nDamage;
			bImmune2 = true;
		end
		local nMT = ActorManager5E.getMishapThreshold(rTarget);
		if (nMT > 0) and (nMT <= (nDamage + nDamageAdjust)) then
			table.insert(rDamageOutput.tNotifications, "[DAMAGE EXCEEDS MISHAP THRESHOLD]");
		end
	end

	-- Shutting these two variables down just in case
	bResist = false;
	bVulnerable = false;
	-- Results
	return nDamageAdjust, bVulnerable, bResist, bVulnerable2, bResist2, bImmune2, nDamageTypeCount, nImmuneCount, nResistCount, nVulnerableCount;
end

function messageDamage(rSource, rTarget, rRoll)
	if rRoll.sType == "damage" then
		if ((string.match(rRoll.sDesc, "%[AMULET%]")) and not (string.match(rRoll.sDesc, "%[GUARDIAN%]"))) then
			rRoll.sResults = rRoll.sResults .. "[AMULET]";
		elseif string.match(rRoll.sDesc, "%[GUARDIAN%]") then
			rRoll.sResults = rRoll.sResults .. "[GUARDIAN]";
		end
		if string.match(rRoll.sDesc, "%[IMMUNE%]") then
			if string.match(rRoll.sResults, "%[IMMUNE%]") then
				rRoll.sResults = string.gsub(rRoll.sResults, "%[IMMUNE%]", "");
			end
			rRoll.sResults = rRoll.sResults .. "[IMMUNE] ";
		end
		if string.match(rRoll.sDesc, "%[PARTIALLY IMMUNE%]") then
			if string.match(rRoll.sResults, "%[PARTIALLY IMMUNE%]") then
				rRoll.sResults = string.gsub(rRoll.sResults, "%[PARTIALLY IMMUNE%]", "");
			end
			rRoll.sResults = rRoll.sResults .. "[PARTIALLY IMMUNE] ";
		end
		if string.match(rRoll.sDesc, "%[RESISTED%]") then
			if string.match(rRoll.sResults, "%[RESISTED%]") then
				rRoll.sResults = string.gsub(rRoll.sResults, "%[RESISTED%]", "");
			end
			rRoll.sResults = rRoll.sResults .. "[RESISTED] ";
		end
		if string.match(rRoll.sDesc, "%[PARTIALLY RESISTED%]") then
			if string.match(rRoll.sResults, "%[PARTIALLY RESISTED%]") then
				rRoll.sResults = string.gsub(rRoll.sResults, "%[PARTIALLY RESISTED%]", "");
			end
			rRoll.sResults = rRoll.sResults .. "[PARTIALLY RESISTED] ";
		end
		if string.match(rRoll.sDesc, "%[VULNERABLE%]") then
			if string.match(rRoll.sResults, "%[VULNERABLE%]") then
				rRoll.sResults = string.gsub(rRoll.sResults, "%[VULNERABLE%]", "");
			end
			rRoll.sResults = rRoll.sResults .. "[VULNERABLE] ";
		end
		if string.match(rRoll.sDesc, "%[PARTIALLY VULNERABLE%]") then
			if string.match(rRoll.sResults, "%[PARTIALLY VULNERABLE%]") then
				rRoll.sResults = string.gsub(rRoll.sResults, "%[PARTIALLY VULNERABLE%]", "");
			end
			rRoll.sResults = rRoll.sResults .. "[PARTIALLY VULNERABLE] ";
		end
		if string.sub(rRoll.sResults, 1, 1) == " " then
			rRoll.sResults = string.gsub(rRoll.sResults, "%s+" ,  "", 1);
		end
		rRoll.sResults = string.gsub(rRoll.sResults, "%]%s*%[", "] [");
	end
	messageDamageOriginal(rSource, rTarget, rRoll);
end