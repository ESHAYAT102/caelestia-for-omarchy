package main

/*
#cgo pkg-config: gtk4 gtk4-layer-shell-0 cairo
#include <gtk/gtk.h>
#include <gtk4-layer-shell.h>
#include <cairo.h>

extern int goTick(void);
extern void goDraw(int, cairo_t*, int, int);

static GtkWidget *areas[16];
static int area_count;
static guint timer_id;

static void draw(GtkDrawingArea *area, cairo_t *cr, int width, int height, gpointer data) {
	goDraw(GPOINTER_TO_INT(data), cr, width, height);
}

static gboolean tick(gpointer data) {
	int active = goTick();
	for (int i = 0; i < area_count; i++) gtk_widget_queue_draw(areas[i]);
	if (!active) {
		timer_id = 0;
		return G_SOURCE_REMOVE;
	}
	return G_SOURCE_CONTINUE;
}

static gboolean wake(gpointer data) {
	if (!timer_id) timer_id = g_timeout_add(16, tick, NULL);
	return G_SOURCE_REMOVE;
}

static void wake_ui(void) {
	g_main_context_invoke(NULL, wake, NULL);
}

static void make_click_through(GtkWidget *widget, gpointer data) {
	GdkSurface *surface = gtk_native_get_surface(GTK_NATIVE(widget));
	cairo_region_t *empty = cairo_region_create();
	gdk_surface_set_input_region(surface, empty);
	cairo_region_destroy(empty);
}

static void activate(GtkApplication *app, gpointer data) {
	GtkCssProvider *provider = gtk_css_provider_new();
	gtk_css_provider_load_from_string(provider,
		"window.confetti, window.confetti > * { background-color: transparent; }");
	gtk_style_context_add_provider_for_display(gdk_display_get_default(),
		GTK_STYLE_PROVIDER(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
	g_object_unref(provider);

	GListModel *monitors = gdk_display_get_monitors(gdk_display_get_default());
	area_count = MIN((int)g_list_model_get_n_items(monitors), 16);
	for (int i = 0; i < area_count; i++) {
		GdkMonitor *monitor = g_list_model_get_item(monitors, i);
		GtkWidget *window = gtk_application_window_new(app);
		GtkWidget *area = gtk_drawing_area_new();

		gtk_window_set_decorated(GTK_WINDOW(window), FALSE);
		gtk_widget_add_css_class(window, "confetti");
		gtk_layer_init_for_window(GTK_WINDOW(window));
		gtk_layer_set_namespace(GTK_WINDOW(window), "omarchy-confetti");
		gtk_layer_set_layer(GTK_WINDOW(window), GTK_LAYER_SHELL_LAYER_OVERLAY);
		gtk_layer_set_monitor(GTK_WINDOW(window), monitor);
		gtk_layer_set_keyboard_mode(GTK_WINDOW(window), GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);
		gtk_layer_set_exclusive_zone(GTK_WINDOW(window), 0);
		for (int edge = 0; edge < GTK_LAYER_SHELL_EDGE_ENTRY_NUMBER; edge++)
			gtk_layer_set_anchor(GTK_WINDOW(window), edge, TRUE);

		gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA(area), draw, GINT_TO_POINTER(i), NULL);
		gtk_window_set_child(GTK_WINDOW(window), area);
		g_signal_connect(window, "map", G_CALLBACK(make_click_through), NULL);
		areas[i] = area;
		gtk_window_present(GTK_WINDOW(window));
		g_object_unref(monitor);
	}
}

static int run_ui(void) {
	GtkApplication *app = gtk_application_new("org.omarchy.Confetti", G_APPLICATION_DEFAULT_FLAGS);
	g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
	int status = g_application_run(G_APPLICATION(app), 0, NULL);
	g_object_unref(app);
	return status;
}

static void clear(cairo_t *cr) {
	cairo_save(cr);
	cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR);
	cairo_paint(cr);
	cairo_restore(cr);
}

static void particle(cairo_t *cr, double x, double y, double size, double rotation,
		int shape, double r, double g, double b) {
	cairo_save(cr);
	cairo_translate(cr, x, y);
	cairo_rotate(cr, rotation);
	cairo_set_source_rgba(cr, r, g, b, 0.95);
	if (shape == 0) {
		cairo_rectangle(cr, -size / 2, -size / 4, size, size / 2);
	} else if (shape == 1) {
		cairo_arc(cr, 0, 0, size / 3, 0, 6.283185307179586);
	} else {
		cairo_move_to(cr, 0, -size / 2);
		cairo_line_to(cr, size / 2, size / 2);
		cairo_line_to(cr, -size / 2, size / 2);
		cairo_close_path(cr);
	}
	cairo_fill(cr);
	cairo_restore(cr);
}
*/
import "C"

import (
	"errors"
	"math"
	"math/rand/v2"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
)

type color struct{ r, g, b float64 }

type particle struct {
	x, y, vx, vy, size, rotation, delay float64
	shape                               int
	color                               color
}

type screen struct {
	width, height int
	particles     []particle
}

var (
	colors = []color{
		{1, 0.31, 0.39}, {1, 0.54, 0}, {1, 0.84, 0.04}, {1, 0.36, 0.69},
		{0.61, 0.43, 1}, {0.36, 0.55, 1}, {0.19, 0.77, 0.96}, {0.45, 0.84, 0.45},
	}
	screens [16]screen
	pending atomic.Int32
	last    time.Time
)

func runtimePath(name string) string {
	dir := os.Getenv("XDG_RUNTIME_DIR")
	if dir == "" {
		dir = filepath.Join("/run/user", strconv.Itoa(os.Getuid()))
	}
	return filepath.Join(dir, name)
}

func sendFire() error {
	address := &net.UnixAddr{Name: runtimePath("omarchy-confetti.sock"), Net: "unixgram"}
	var err error
	for range 40 {
		var conn *net.UnixConn
		conn, err = net.DialUnix("unixgram", nil, address)
		if err == nil {
			_, err = conn.Write([]byte("fire"))
			conn.Close()
			return err
		}
		time.Sleep(25 * time.Millisecond)
	}
	return err
}

func serve() error {
	lock, err := os.OpenFile(runtimePath("omarchy-confetti.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}

	socket := runtimePath("omarchy-confetti.sock")
	_ = os.Remove(socket)
	conn, err := net.ListenUnixgram("unixgram", &net.UnixAddr{Name: socket, Net: "unixgram"})
	if err != nil {
		return err
	}
	defer func() {
		conn.Close()
		os.Remove(socket)
	}()

	go func() {
		buf := make([]byte, 16)
		for {
			n, _, err := conn.ReadFromUnix(buf)
			if err != nil {
				return
			}
			if strings.TrimSpace(string(buf[:n])) == "fire" {
				pending.Add(1)
				C.wake_ui()
			}
		}
	}()

	runtime.LockOSThread()
	returnCode := C.run_ui()
	if returnCode != 0 {
		return errors.New("GTK application exited with status " + strconv.Itoa(int(returnCode)))
	}
	return nil
}

func addBurst(s *screen) {
	if s.width <= 0 || s.height <= 0 {
		return
	}
	h := float64(s.height)
	w := float64(s.width)
	for range 320 {
		left := rand.IntN(2) == 0
		angle := math.Pi + rand.Float64()*math.Pi/2
		if left {
			angle += math.Pi / 2
		}
		speed := h * (0.68 + rand.Float64()*0.72)
		x := w
		if left {
			x = 0
		}
		s.particles = append(s.particles, particle{
			x: x, y: h, vx: math.Cos(angle) * speed, vy: math.Sin(angle) * speed,
			size: 8 + rand.Float64()*8, rotation: rand.Float64() * 2 * math.Pi,
			delay: rand.Float64() * 0.45, shape: rand.IntN(3), color: colors[rand.IntN(len(colors))],
		})
	}
}

//export goTick
func goTick() C.int {
	now := time.Now()
	dt := now.Sub(last).Seconds()
	if last.IsZero() || dt > 0.05 {
		dt = 0.016
	}
	last = now

	bursts := pending.Swap(0)
	active := false
	for i := range screens {
		s := &screens[i]
		for range bursts {
			addBurst(s)
		}
		gravity := float64(s.height) * 1.25
		alive := s.particles[:0]
		for j := range s.particles {
			p := &s.particles[j]
			if p.delay > 0 {
				p.delay -= dt
			} else {
				p.x += p.vx * dt
				p.y += p.vy * dt
				p.vy += gravity * dt
				p.rotation += dt * 8
			}
			if p.delay > 0 || p.y <= float64(s.height)+p.size {
				alive = append(alive, *p)
			}
		}
		s.particles = alive
		active = active || len(alive) > 0
	}
	if active || pending.Load() > 0 {
		return 1
	}
	last = time.Time{}
	return 0
}

//export goDraw
func goDraw(index C.int, cr *C.cairo_t, width, height C.int) {
	C.clear(cr)
	i := int(index)
	if i < 0 || i >= len(screens) {
		return
	}
	s := &screens[i]
	s.width, s.height = int(width), int(height)
	for _, p := range s.particles {
		if p.delay <= 0 {
			C.particle(cr, C.double(p.x), C.double(p.y), C.double(p.size), C.double(p.rotation),
				C.int(p.shape), C.double(p.color.r), C.double(p.color.g), C.double(p.color.b))
		}
	}
}

func animationsEnabled() bool {
	out, err := exec.Command("gsettings", "get", "org.gnome.desktop.interface", "enable-animations").Output()
	return err != nil || strings.TrimSpace(string(out)) != "false"
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "fire" {
		if animationsEnabled() {
			_ = sendFire()
		}
		return
	}
	if err := serve(); err != nil {
		_, _ = os.Stderr.WriteString(err.Error() + "\n")
		os.Exit(1)
	}
}
