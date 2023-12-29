#define BRUISED_2_EFFICIENCY 80
#define BROKEN_2_EFFICIENCY 50
#define DEAD_2_EFFICIENCY 0

//Has processes for all internal organs, called from /mob/living/carbon/human/Life()

/mob/living/carbon/human/proc/process_internal_organs() //Calls all of the internal organ processes
	if(should_have_process(OP_EYES))	//Bad way to do this, should be reworked to call procs from a list that's generated by the species.has_process list + extra processes gotten from organs (carrion)
		eye_process()
	if(should_have_process(OP_KIDNEY_LEFT) || should_have_process(OP_KIDNEY_RIGHT))
		kidney_process()
	if(should_have_process(OP_LIVER))
		liver_process()
	if(should_have_process(OP_HEART))
		heart_process()
	if(should_have_process(OP_LUNGS))
		lung_process()
	if(should_have_process(OP_STOMACH))
		stomach_process()
	if(is_carrion(src))
		carrion_process()

/mob/living/carbon/human/proc/get_organ_efficiency(process_define)
	var/list/process_list = internal_organs_by_efficiency[process_define]
	var/effective_efficiency = 0
	if(process_list && process_list.len)
		for(var/organ in process_list)
			var/obj/item/organ/internal/I = organ
			effective_efficiency += I.get_process_efficiency(process_define)

	return effective_efficiency ? effective_efficiency : 1

/mob/living/carbon/human/get_specific_organ_efficiency(process_define, parent_organ_tag)
	var/effective_efficiency = 0
	var/obj/item/organ/external/parent_organ
	if(isorgan(parent_organ_tag))
		parent_organ = parent_organ_tag
	else
		parent_organ = get_organ(parent_organ_tag)
	if(parent_organ)
		for(var/organ in parent_organ.internal_organs)
			var/obj/item/organ/internal/I = organ
			if(process_define in I.organ_efficiency)
				effective_efficiency += I.get_process_efficiency(process_define)

	return effective_efficiency ? effective_efficiency : 1

/mob/living/carbon/human/proc/eye_process()
	var/eye_efficiency = get_organ_efficiency(OP_EYES)

	if(eye_efficiency < BRUISED_2_EFFICIENCY)
		eye_blurry = 1
	if(eye_efficiency < BROKEN_2_EFFICIENCY)
		eye_blind = 1
	//update_client_colour()

/mob/living/carbon/human/proc/kidney_process()
	var/kidneys_efficiency = get_organ_efficiency(OP_KIDNEYS)
	var/obj/item/organ/internal/kidney = random_organ_by_process(OP_KIDNEYS)
	var/chem_toxicity = chem_effects[CE_ANTITOX] + chem_effects[CE_BLOODCLOT] + chem_effects[CE_SPEEDBOOST]
	var/toxin_strength = chem_effects[CE_TOXIN] * IORGAN_KIDNEY_TOX_RATIO + chem_toxicity

	// Existing damage is subtracted to prevent weaker toxins from maxing out tox wounds on the organ
	var/toxin_damage = kidney ? (toxin_strength / (stats.getPerk(PERK_BLOOD_OF_LEAD) ? 2 : 1)) - (kidneys_efficiency / 100) - kidney.damage * 2 : 0

	// Organ functions
	// Blood regeneration if there is some space
	regenerate_blood(0.2 + 2 * chem_effects[CE_BLOODRESTORE] * (kidneys_efficiency / 100))

	// Bad stuff
	if(kidneys_efficiency < BROKEN_2_EFFICIENCY)
		if(toxin_strength > 0)
			apply_damage(toxin_strength, TOX)	// If your kidneys aren't working, your body will start to take damage

	if(toxin_damage > 0 && kidney)
		kidney.take_damage(toxin_damage, TOX)

/mob/living/carbon/human/proc/liver_process()
	var/liver_efficiency = get_organ_efficiency(OP_LIVER) * (1 + chem_effects[CE_ANTITOX])
	var/obj/item/organ/internal/liver = random_organ_by_process(OP_LIVER)
	var/alcohol_strength = chem_effects[CE_ALCOHOL]
	var/toxin_strength = chem_effects[CE_TOXIN] * IORGAN_LIVER_TOX_RATIO + chem_effects[CE_ALCOHOL_TOXIC]

	// Existing damage is subtracted to prevent weaker toxins from maxing out tox wounds on the organ
	var/toxin_damage = liver ? (toxin_strength / (stats.getPerk(PERK_BLOOD_OF_LEAD) ? 2 : 1)) - (liver_efficiency / 100) - liver.damage * 2 : 0

	// Bad stuff
	// If you're not filtering well, you're in trouble. Ammonia buildup to toxic levels and damage from alcohol
	if(liver_efficiency < BROKEN_2_EFFICIENCY)
		if(alcohol_strength)
			toxin_damage += 0.5 * max(2 - (liver_efficiency * 0.01), 0) * alcohol_strength
		if(toxin_strength > 0)
			apply_damage(toxin_strength, TOX)	// If your liver isn't working, your body will start to take damage

	if(toxin_damage > 0 && liver)
		liver.take_damage(toxin_damage, TOX)

	// Blood loss or liver damage make you lose nutriments
	var/blood_volume = get_blood_volume()
	if(blood_volume < total_blood_req + BLOOD_VOLUME_SAFE_MODIFIER || (liver_efficiency < BRUISED_2_EFFICIENCY))
		if(nutrition >= 300)
			adjustNutrition(-10)
		else if(nutrition >= 200)
			adjustNutrition(-2)


/mob/living/carbon/human/proc/heart_process()
	handle_pulse()
	handle_heart_blood()

/mob/living/carbon/human/proc/handle_pulse()
	var/roboheartcheck = TRUE //Check if all hearts are robotic
	for(var/obj/item/organ/internal/vital/heart in organ_list_by_process(OP_HEART))
		if(!BP_IS_ROBOTIC(heart))
			roboheartcheck = FALSE
			break

	if(stat == DEAD || roboheartcheck)
		pulse = PULSE_NONE	//that's it, you're dead (or your metal heart is), nothing can influence your pulse
		return

	if(life_tick % 5 == 0)//update pulse every 5 life ticks (~1 tick/sec, depending on server load)
		pulse = PULSE_NORM

		if(round(vessel.get_reagent_amount("blood")) <= total_blood_req + BLOOD_VOLUME_BAD_MODIFIER)	//how much blood do we have
			pulse  = PULSE_THREADY	//not enough :(

		if(status_flags & FAKEDEATH || chem_effects[CE_NOPULSE])
			pulse = PULSE_NONE		//pretend that we're dead. unlike actual death, can be inflienced by meds

		pulse = CLAMP(pulse + chem_effects[CE_PULSE], PULSE_SLOW, PULSE_2FAST)

/mob/living/carbon/human/proc/handle_heart_blood()
	var/heart_efficiency = get_organ_efficiency(OP_HEART)
	var/blood_oxygenation = 0.4 * chem_effects[CE_OXYGENATED] - 0.2 * chem_effects[CE_BLOODCLOT]
	var/blood_volume_raw = vessel.get_reagent_amount("blood")
	var/blood_volume = round((blood_volume_raw/species.blood_volume)*100) // Percentage.

	// Damaged heart virtually reduces the blood volume, as the blood isn't being pumped properly anymore.
	if(heart_efficiency <= 100)	//flat scaling up to 100
		blood_volume *= (heart_efficiency / 100) + blood_oxygenation
	else	//half scaling at over 100
		blood_volume *= 1 + ((heart_efficiency - 100) / 200) + blood_oxygenation

	//Effects of bloodloss
	var/blood_safe = total_blood_req + BLOOD_VOLUME_SAFE_MODIFIER
	var/blood_okay = total_blood_req + BLOOD_VOLUME_OKAY_MODIFIER
	var/blood_bad = total_blood_req + BLOOD_VOLUME_BAD_MODIFIER

	if(blood_volume < total_blood_req)
		status_flags |= BLEEDOUT
		if(prob(15))
			to_chat(src, SPAN_WARNING("Your organs feel extremely heavy"))
	else
		status_flags &= ~BLEEDOUT

	if(blood_volume < 1)
		eye_blurry = max(eye_blurry,6)
		adjustOxyLoss(20)
		if(prob(15))
			to_chat(src, SPAN_WARNING("You feel [pick("extremely tired","terribly weak","the world fade around you")]"))
	else if(blood_volume < blood_bad)
		eye_blurry = max(eye_blurry,6)
		adjustOxyLoss(10)
		if(prob(15))
			to_chat(src, SPAN_WARNING("You feel very [pick("dizzy","woosey","faint")]"))
	else if(blood_volume < blood_okay)
		eye_blurry = max(eye_blurry,6)
		adjustOxyLoss(5)
		if(prob(15))
			Weaken(rand(1,3))
			to_chat(src, SPAN_WARNING("You feel [pick("dizzy","woosey","faint")]"))
	else if(blood_volume < blood_safe)
		if(prob(1))
			to_chat(src, SPAN_WARNING("You feel slightly [pick("dizzy","woosey","faint")]"))
		if(getOxyLoss() < 10)
			adjustOxyLoss(1)

	// Blood loss or heart damage make you lose nutriments
	if(blood_volume < blood_safe || heart_efficiency < BRUISED_2_EFFICIENCY)
		if(nutrition >= 300)
			adjustNutrition(-10)
		else if(nutrition >= 200)
			adjustNutrition(-2)


/mob/living/carbon/human/proc/lung_process()
	var/lung_efficiency = get_organ_efficiency(OP_LUNGS)
	var/internal_oxygen = 100 - oxyloss

	internal_oxygen *= lung_efficiency / 100

	if(internal_oxygen < total_oxygen_req)
		if(prob(1))
			Weaken(1.5 SECONDS)
			visible_message(SPAN_WARNING("[src] falls to the ground and starts hyperventilating!."), SPAN_DANGER("AIR! I NEED MORE AIR!"))
			var/i
			for(i = 1; i <= 5; i++)	//gasps 5 times
				spawn(i)
					emote("gasp")

		if(prob(2))
			spawn emote("me", 1, "coughs up blood!")
			drip_blood(10)

		if(prob(4))
			spawn emote("me", 1, "gasps for air!")
			losebreath += 15

		if(prob(15))
			var/heavy_spot = pick("chest", "skin", "brain")
			to_chat(src, SPAN_WARNING("Your [heavy_spot] feels too heavy for your body"))

	if(lung_efficiency < BROKEN_2_EFFICIENCY)
		adjustOxyLoss(1)

/mob/living/carbon/human/proc/stomach_process()
	var/stomach_efficiency = get_organ_efficiency(OP_STOMACH)
	max_nutrition = MOB_BASE_MAX_HUNGER * (stomach_efficiency / 100)
	if(nutrition > 0 && stat != 2)
		if(stomach_efficiency <= 0)
			nutrition = 0
		else
			adjustNutrition(-(total_nutriment_req * (stomach_efficiency/100)))

/* We dont have vore
	if(stomach_efficiency <= 1)
		for(var/mob/living/M in stomach_contents)
			M.loc = loc
			stomach_contents.Remove(M)
			continue
		ingested.trans_to_turf(get_turf(src))
*/

/mob/living/carbon/human/var/carrion_stored_chemicals = 0
/mob/living/carbon/human/var/carrion_hunger = 0
/mob/living/carbon/human/var/carrion_last_hunger = -2 MINUTES
/mob/living/carbon/human/proc/carrion_process()
	var/vessel_efficiency = get_organ_efficiency(OP_CHEMICALS)
	var/maw_efficiency = get_organ_efficiency(OP_MAW)
	if(vessel_efficiency)
		carrion_stored_chemicals = min(carrion_stored_chemicals + (0.01 * vessel_efficiency), 0.5 * vessel_efficiency)

	if((maw_efficiency > 1 )&& (world.time > (carrion_last_hunger + 2 MINUTES)))
		var/max_hunger = round(10 * (maw_efficiency / 100))
		if(carrion_hunger < max_hunger)
			carrion_hunger = min(carrion_hunger + (round(1* (maw_efficiency / 100))), max_hunger)
		else
			to_chat(src, SPAN_WARNING("Your hunger is restless!"))
		carrion_last_hunger = world.time

#undef BRUISED_2_EFFICIENCY
#undef BROKEN_2_EFFICIENCY
#undef DEAD_2_EFFICIENCY