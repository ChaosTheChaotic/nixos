#define _GNU_SOURCE
#include <dlfcn.h>
#include <libinput.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct libinput_event *(*get_event_fn)(struct libinput *);

static get_event_fn real_get_event;
static int have_speed, have_profile;
static double speed;
static enum libinput_config_accel_profile profile;

static void parse_env(void)
{
    const char *s = getenv("FBBROWSER_POINTER_SPEED");
    const char *a = getenv("FBBROWSER_POINTER_ACCEL");

    if (s && *s) {
        char *end;
        double v = strtod(s, &end);
        if (*end != '\0') {
            fprintf(stderr, "fbbrowser: ignoring invalid FBBROWSER_POINTER_SPEED '%s'\n", s);
        } else {
            if (v < -1.0) v = -1.0;
            if (v > 1.0) v = 1.0;
            speed = v;
            have_speed = 1;
        }
    }
    if (a && *a) {
        if (!strcmp(a, "flat")) {
            profile = LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT;
            have_profile = 1;
        } else if (!strcmp(a, "adaptive")) {
            profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
            have_profile = 1;
        } else {
            fprintf(stderr, "fbbrowser: ignoring invalid FBBROWSER_POINTER_ACCEL '%s' (flat|adaptive)\n", a);
        }
    }
}

static void tune(struct libinput_device *dev)
{
    if (!dev || !libinput_device_config_accel_is_available(dev))
        return;
    if (have_profile && (libinput_device_config_accel_get_profiles(dev) & profile))
        libinput_device_config_accel_set_profile(dev, profile);
    if (have_speed)
        libinput_device_config_accel_set_speed(dev, speed);
}

struct libinput_event *libinput_get_event(struct libinput *li)
{
    struct libinput_event *ev;

    if (!real_get_event) {
        real_get_event = (get_event_fn)dlsym(RTLD_NEXT, "libinput_get_event");
        parse_env();
        if (!real_get_event) {
            fprintf(stderr, "fbbrowser: pointer shim could not find libinput_get_event\n");
            return NULL;
        }
    }

    ev = real_get_event(li);
    if (ev && libinput_event_get_type(ev) == LIBINPUT_EVENT_DEVICE_ADDED)
        tune(libinput_event_get_device(ev));
    return ev;
}
