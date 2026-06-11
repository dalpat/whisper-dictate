/*
 * indicator.c — Persistent toast overlay for whisper-dictate.
 *
 * Usage:  indicator "message"           (recording mode, stays until killed)
 *         indicator "message" result    (result mode, auto-dismisses after 4s)
 *         indicator "message" stream    (stream mode, polls /tmp/whisper_stream.txt)
 */

#include <gtk/gtk.h>
#include <string.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

#define N_BARS 5
#define N_FRAMES 12
#define STREAM_PATH "/tmp/whisper_stream.txt"
#define PID_PATH "/tmp/whisper_rec.pid"

static GtkWidget *window;
static GtkWidget *wave_l[N_BARS];
static GtkWidget *wave_r[N_BARS];
static GtkWidget *stream_label;
static int frame = 0;
static int is_stream = 0;
static char last_content[2048] = "";

static const int wave_data[N_FRAMES][N_BARS] = {
    {1,2,3,2,1}, {1,3,4,3,1}, {2,3,4,3,2}, {2,4,3,4,2},
    {3,4,2,4,3}, {3,2,4,2,3}, {4,3,2,3,4}, {4,2,3,2,4},
    {3,2,1,2,3}, {3,1,2,1,3}, {2,1,0,1,2}, {1,0,1,0,1},
};

static const char *bar_char(int h) {
    const char *bars[] = {" ", "▁", "▃", "▅", "▇"};
    return (h >= 0 && h <= 4) ? bars[h] : " ";
}

static gboolean on_timeout(gpointer d) {
    (void)d;
    gtk_main_quit();
    return FALSE;
}

static gboolean on_wave(gpointer d) {
    (void)d;
    frame = (frame + 1) % N_FRAMES;
    for (int i = 0; i < N_BARS; i++) {
        gtk_label_set_text(GTK_LABEL(wave_l[i]), bar_char(wave_data[frame][i]));
        gtk_label_set_text(GTK_LABEL(wave_r[i]), bar_char(wave_data[frame][N_BARS-1-i]));
    }
    return TRUE;
}

static gboolean on_stream_poll(gpointer d) {
    (void)d;
    if (!is_stream) return FALSE;

    FILE *f = fopen(STREAM_PATH, "r");
    if (f) {
        char buf[2048] = "";
        if (fgets(buf, sizeof(buf), f)) {
            buf[strcspn(buf, "\n")] = 0;
            if (strcmp(buf, last_content) != 0) {
                strncpy(last_content, buf, sizeof(last_content) - 1);
                last_content[sizeof(last_content) - 1] = '\0';
                if (stream_label) {
                    gtk_label_set_text(GTK_LABEL(stream_label),
                                       strlen(last_content) > 0 ? last_content : " ");
                }
            }
        }
        fclose(f);
    }

    return access(PID_PATH, F_OK) == 0;
}

static gboolean on_draw(GtkWidget *w, cairo_t *cr) {
    (void)w;
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    return FALSE;
}

static gboolean position_after_show(gpointer d) {
    (void)d;

    GdkDisplay *display = gtk_widget_get_display(window);
    GdkMonitor *mon = gdk_display_get_primary_monitor(display);
    if (!mon) mon = gdk_display_get_monitor(display, 0);
    GdkRectangle geo;
    gdk_monitor_get_geometry(mon, &geo);

    GtkAllocation alloc;
    gtk_widget_get_allocation(window, &alloc);
    if (alloc.width < 2 || alloc.height < 2) return TRUE;

    int x = geo.x + (geo.width - alloc.width) / 2;
    int y = geo.y + geo.height - alloc.height - 24;
    gtk_window_move(GTK_WINDOW(window), x, y);
    return FALSE;
}

int main(int argc, char *argv[]) {
    signal(SIGTERM, (void (*)(int))gtk_main_quit);

    const char *msg = "Listening...";
    int is_result = 0;
    if (argc > 1) msg = argv[1];
    if (argc > 2 && strcmp(argv[2], "result") == 0) is_result = 1;
    if (argc > 2 && strcmp(argv[2], "stream") == 0) is_stream = 1;

    /* Force XWayland so we control window position (Wayland compositor ignores move requests) */
    g_setenv("GDK_BACKEND", "x11", TRUE);

    gtk_init(&argc, &argv);

    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_widget_set_app_paintable(window, TRUE);
    gtk_window_set_decorated(GTK_WINDOW(window), FALSE);
    gtk_window_set_skip_taskbar_hint(GTK_WINDOW(window), TRUE);
    gtk_window_set_skip_pager_hint(GTK_WINDOW(window), TRUE);
    gtk_window_set_keep_above(GTK_WINDOW(window), TRUE);
    gtk_window_set_accept_focus(GTK_WINDOW(window), FALSE);
    gtk_window_set_focus_on_map(GTK_WINDOW(window), FALSE);
    gtk_window_set_type_hint(GTK_WINDOW(window), GDK_WINDOW_TYPE_HINT_DIALOG);

    GdkScreen *screen = gtk_widget_get_screen(window);
    GdkVisual *vis = gdk_screen_get_rgba_visual(screen);
    if (vis) gtk_widget_set_visual(window, vis);
    g_signal_connect(window, "draw", G_CALLBACK(on_draw), NULL);

    /* ── CSS ─────────────────────────────────────────────────────────────── */
    GtkCssProvider *css = gtk_css_provider_new();
    gtk_css_provider_load_from_data(css,
        "* { font-family: sans-serif; }"
        ".pill { background: rgba(24,24,28,0.94); border-radius: 20px; "
        "border: 1px solid rgba(255,255,255,0.06); padding: 14px 20px; }"
        ".mic { background: #5b6abf; color: white; font-size: 18px; "
        "border-radius: 50%; min-width: 44px; min-height: 44px; "
        "font-weight: bold; }"
        ".mic-ok { background: #4caf50; }"
        ".bar { color: #7c8adf; font-size: 18px; font-family: monospace; "
        "min-width: 10px; }"
        ".msg { color: #e0e0e0; font-size: 13px; font-weight: 500; "
        "margin-left: 10px; }", -1, NULL);
    gtk_style_context_add_provider_for_screen(screen,
        GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(css);

    /* ── Layout ──────────────────────────────────────────────────────────── */
    GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_style_context_add_class(gtk_widget_get_style_context(row), "pill");
    gtk_container_add(GTK_CONTAINER(window), row);

    if (is_result) {
        GtkWidget *mic = gtk_label_new("✓");
        gtk_style_context_add_class(gtk_widget_get_style_context(mic), "mic");
        gtk_style_context_add_class(gtk_widget_get_style_context(mic), "mic-ok");
        gtk_box_pack_start(GTK_BOX(row), mic, FALSE, FALSE, 0);

        GtkWidget *txt = gtk_label_new(msg);
        gtk_style_context_add_class(gtk_widget_get_style_context(txt), "msg");
        gtk_box_pack_start(GTK_BOX(row), txt, FALSE, FALSE, 0);
        g_timeout_add(4000, on_timeout, NULL);
    } else if (is_stream) {
        /* Stream mode: waves + mic + live text label */
        for (int i = 0; i < N_BARS; i++) {
            wave_l[i] = gtk_label_new(" ");
            gtk_style_context_add_class(gtk_widget_get_style_context(wave_l[i]), "bar");
            gtk_box_pack_start(GTK_BOX(row), wave_l[i], FALSE, FALSE, 0);
        }

        GtkWidget *mic = gtk_label_new("🎙");
        gtk_style_context_add_class(gtk_widget_get_style_context(mic), "mic");
        gtk_box_pack_start(GTK_BOX(row), mic, FALSE, FALSE, 6);

        for (int i = 0; i < N_BARS; i++) {
            wave_r[i] = gtk_label_new(" ");
            gtk_style_context_add_class(gtk_widget_get_style_context(wave_r[i]), "bar");
            gtk_box_pack_start(GTK_BOX(row), wave_r[i], FALSE, FALSE, 0);
        }

        stream_label = gtk_label_new(" ");
        gtk_style_context_add_class(gtk_widget_get_style_context(stream_label), "msg");
        gtk_box_pack_start(GTK_BOX(row), stream_label, FALSE, FALSE, 0);

        g_timeout_add(100, on_wave, NULL);
        g_timeout_add(200, on_stream_poll, NULL);
    } else {
        for (int i = 0; i < N_BARS; i++) {
            wave_l[i] = gtk_label_new(" ");
            gtk_style_context_add_class(gtk_widget_get_style_context(wave_l[i]), "bar");
            gtk_box_pack_start(GTK_BOX(row), wave_l[i], FALSE, FALSE, 0);
        }

        GtkWidget *mic = gtk_label_new("🎙");
        gtk_style_context_add_class(gtk_widget_get_style_context(mic), "mic");
        gtk_box_pack_start(GTK_BOX(row), mic, FALSE, FALSE, 6);

        for (int i = 0; i < N_BARS; i++) {
            wave_r[i] = gtk_label_new(" ");
            gtk_style_context_add_class(gtk_widget_get_style_context(wave_r[i]), "bar");
            gtk_box_pack_start(GTK_BOX(row), wave_r[i], FALSE, FALSE, 0);
        }
        g_timeout_add(100, on_wave, NULL);
    }

    gtk_widget_show_all(window);
    g_timeout_add(50, position_after_show, NULL);

    gtk_main();
    return 0;
}
