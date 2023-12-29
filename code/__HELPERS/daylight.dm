/////////////////////
///DAY/NIGHT CYCLE///
/////////////////////

var/global/nighttime = null
var/day_or_night = 0

/proc/check_daynight()
    if (day_or_night == 1)
        nighttime = TRUE
    else
        nighttime = FALSE
