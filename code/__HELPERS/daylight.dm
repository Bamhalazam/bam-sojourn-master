var/is_forest = FALSE

/proc/Enable_Area_Dynamic_Lighting() //works
    Determine_Time_Of_Day()
    if(night == TRUE)
        dynamic_lighting = TRUE
    else
        dynamic_lighting = FALSE
    return dynamic_lighting


/atom/proc/in_forest()
    var/area/A = get_area(src)
    if (A && A.is_forest && night)
        return TRUE
    return FALSE

var/obj/screen/screenOverlay = null

/obj/mob/proc/Toggle_Visual_Noise()
	. = ..()
	screenOverlay = global_hud.noise
