use std::collections::HashMap;
use std::io::{Read, Write};
use std::os::unix::net::UnixListener;
use std::path::{Path, PathBuf};

use calloop::EventLoop;
use calloop_wayland_source::WaylandSource;
use inotify::{Inotify, WatchMask};
use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_layer, delegate_output, delegate_registry, delegate_shm,
    output::{OutputHandler, OutputState},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    shell::{
        wlr_layer::{
            Anchor, KeyboardInteractivity, Layer, LayerShell, LayerShellHandler, LayerSurface,
            LayerSurfaceConfigure,
        },
        WaylandSurface,
    },
    shm::{slot::SlotPool, Shm, ShmHandler},
};
use wayland_client::{
    globals::registry_queue_init,
    protocol::{wl_output, wl_region, wl_shm, wl_surface},
    Connection, Dispatch, QueueHandle,
};

const MAX_ALPHA_FRACTION: f32 = 1.0;

fn percent_to_alpha(percent: u8) -> u8 {
    let frac = (100 - percent.min(100)) as f32 / 100.0;
    (frac * MAX_ALPHA_FRACTION * 255.0).round() as u8
}

struct DimSurface {
    layer: LayerSurface,
    width: u32,
    height: u32,
}

struct App {
    registry_state: RegistryState,
    output_state: OutputState,
    compositor_state: CompositorState,
    layer_shell: LayerShell,
    shm: Shm,
    pool: SlotPool,
    surfaces: HashMap<wl_surface::WlSurface, DimSurface>,
    skip: Vec<String>,
    percent: u8,
}

impl App {
    fn redraw_all(&mut self, qh: &QueueHandle<Self>) {
        let alpha = percent_to_alpha(self.percent);
        for surf in self.surfaces.values_mut() {
            if surf.width == 0 || surf.height == 0 {
                continue;
            }
            draw(&mut self.pool, &surf.layer, surf.width, surf.height, alpha, qh);
        }
    }

    fn set_percent(&mut self, percent: u8, qh: &QueueHandle<Self>) {
        self.percent = percent.min(100);
        self.redraw_all(qh);
    }

    fn handle_command(&mut self, cmd: &str, qh: &QueueHandle<Self>) {
        let mut parts = cmd.split_whitespace();
        let op = parts.next().unwrap_or("");
        let arg: i32 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
        let new_percent = match op {
            "set" => arg.clamp(0, 100) as u8,
            "up" => (self.percent as i32 + arg).clamp(0, 100) as u8,
            "down" => (self.percent as i32 - arg).clamp(0, 100) as u8,
            _ => {
                eprintln!("unknown command: {cmd}");
                return;
            }
        };
        self.set_percent(new_percent, qh);
    }
}

fn draw(
    pool: &mut SlotPool,
    layer: &LayerSurface,
    width: u32,
    height: u32,
    alpha: u8,
    _qh: &QueueHandle<App>,
) {
    let stride = width as i32 * 4;
    let (buffer, canvas) = pool
        .create_buffer(
            width as i32,
            height as i32,
            stride,
            wl_shm::Format::Argb8888,
        )
        .expect("create buffer");

    for px in canvas.chunks_exact_mut(4) {
        px[0] = 0; // B
        px[1] = 0; // G
        px[2] = 0; // R
        px[3] = alpha; // A (premultiplied; RGB already 0 so no scaling needed)
    }

    let surface = layer.wl_surface();
    surface.damage_buffer(0, 0, width as i32, height as i32);
    buffer.attach_to(surface).expect("attach buffer");
    layer.commit();
}

impl CompositorHandler for App {
    fn scale_factor_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: i32,
    ) {
    }
    fn transform_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: wayland_client::protocol::wl_output::Transform,
    ) {
    }
    fn frame(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: u32,
    ) {
    }
    fn surface_enter(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }
    fn surface_leave(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }
}

impl OutputHandler for App {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }

    fn new_output(&mut self, _: &Connection, qh: &QueueHandle<Self>, output: wl_output::WlOutput) {
        let info = match self.output_state.info(&output) {
            Some(i) => i,
            None => return,
        };
        let name = info.name.clone().unwrap_or_default();
        if self.skip.iter().any(|s| s == &name) {
            eprintln!("skipping output {name}");
            return;
        }
        eprintln!("dimming output {name}");

        let surface = self.compositor_state.create_surface(qh);

        let region = self.compositor_state.wl_compositor().create_region(qh, ());
        surface.set_input_region(Some(&region));
        region.destroy();

        let layer = self.layer_shell.create_layer_surface(
            qh,
            surface,
            Layer::Overlay,
            Some("monitor-dim"),
            Some(&output),
        );
        layer.set_anchor(Anchor::TOP | Anchor::BOTTOM | Anchor::LEFT | Anchor::RIGHT);
        layer.set_exclusive_zone(-1);
        layer.set_keyboard_interactivity(KeyboardInteractivity::None);
        layer.commit();

        self.surfaces.insert(
            layer.wl_surface().clone(),
            DimSurface {
                layer,
                width: 0,
                height: 0,
            },
        );
    }

    fn update_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}

    fn output_destroyed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: wl_output::WlOutput,
    ) {
    }
}

impl LayerShellHandler for App {
    fn closed(&mut self, _: &Connection, _: &QueueHandle<Self>, layer: &LayerSurface) {
        self.surfaces.retain(|_, s| &s.layer != layer);
    }

    fn configure(
        &mut self,
        _: &Connection,
        qh: &QueueHandle<Self>,
        layer: &LayerSurface,
        configure: LayerSurfaceConfigure,
        _serial: u32,
    ) {
        let (w, h) = configure.new_size;
        if w == 0 || h == 0 {
            return;
        }
        let alpha = percent_to_alpha(self.percent);
        if let Some(surf) = self
            .surfaces
            .values_mut()
            .find(|s| s.layer.wl_surface() == layer.wl_surface())
        {
            surf.width = w;
            surf.height = h;
        }
        draw(&mut self.pool, layer, w, h, alpha, qh);
    }
}

impl ShmHandler for App {
    fn shm_state(&mut self) -> &mut Shm {
        &mut self.shm
    }
}

impl ProvidesRegistryState for App {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    registry_handlers![OutputState];
}

impl Dispatch<wl_region::WlRegion, ()> for App {
    fn event(
        _: &mut Self,
        _: &wl_region::WlRegion,
        _: wl_region::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

delegate_compositor!(App);
delegate_output!(App);
delegate_shm!(App);
delegate_layer!(App);
delegate_registry!(App);

// Acts as a client if invoked as `monitor-dim <set|up|down> <n>`: sends the
// command to a running daemon's socket, prints its reply, and exits. This
// keeps the tool self-contained (no netcat/socat dependency needed at the
// keybinding call site) the same way `hyprctl` is both the compositor and
// its own IPC client.
fn run_client(verb: &str, arg: &str) -> std::io::Result<()> {
    use std::os::unix::net::UnixStream;
    let runtime_dir = std::env::var("XDG_RUNTIME_DIR").expect("XDG_RUNTIME_DIR not set");
    let sock_path = format!("{runtime_dir}/monitor-dim.sock");
    let mut stream = UnixStream::connect(&sock_path)?;
    stream.write_all(format!("{verb} {arg}").as_bytes())?;
    stream.shutdown(std::net::Shutdown::Write)?;
    let mut reply = String::new();
    stream.read_to_string(&mut reply)?;
    print!("{reply}");
    Ok(())
}

// Every real brightness tool on Linux — brightnessctl, light, a desktop
// environment's settings daemon, systemd-logind's SetBrightness — ultimately
// writes the same kernel sysfs file. Watching it directly with inotify (it's
// a plain write(), so IN_MODIFY fires reliably even though it's sysfs, not a
// regular file) means every one of those tools, present or future, drives
// this overlay automatically with nothing to patch or wire up per-tool.
fn find_backlight_device(explicit: Option<&str>) -> Option<PathBuf> {
    let base = Path::new("/sys/class/backlight");
    if let Some(name) = explicit {
        let p = base.join(name);
        return p.is_dir().then_some(p);
    }
    std::fs::read_dir(base)
        .ok()?
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .next()
}

fn read_backlight_percent(dir: &Path, max_brightness: u64) -> Option<u8> {
    let raw = std::fs::read_to_string(dir.join("brightness")).ok()?;
    let value: u64 = raw.trim().parse().ok()?;
    Some(((value * 100 / max_brightness.max(1)) as u8).min(100))
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();

    if let [verb, arg] = args.as_slice() {
        if matches!(verb.as_str(), "set" | "up" | "down") {
            if let Err(e) = run_client(verb, arg) {
                eprintln!("monitor-dim: {e}");
                std::process::exit(1);
            }
            return;
        }
    }

    let mut skip = Vec::new();
    let mut backlight: Option<String> = None;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--skip" => {
                if let Some(v) = args.get(i + 1) {
                    skip.push(v.clone());
                    i += 1;
                }
            }
            "--backlight" => {
                if let Some(v) = args.get(i + 1) {
                    backlight = Some(v.clone());
                    i += 1;
                }
            }
            _ => {}
        }
        i += 1;
    }

    let conn = Connection::connect_to_env().expect("connect to wayland");
    let (globals, event_queue) = registry_queue_init::<App>(&conn).expect("registry init");
    let qh = event_queue.handle();

    let compositor_state =
        CompositorState::bind(&globals, &qh).expect("wl_compositor not available");
    let layer_shell = LayerShell::bind(&globals, &qh).expect("wlr-layer-shell not available");
    let shm = Shm::bind(&globals, &qh).expect("wl_shm not available");
    let pool = SlotPool::new(1, &shm).expect("create pool");

    let mut app = App {
        registry_state: RegistryState::new(&globals),
        output_state: OutputState::new(&globals, &qh),
        compositor_state,
        layer_shell,
        shm,
        pool,
        surfaces: HashMap::new(),
        skip,
        percent: 100,
    };

    let mut event_loop: EventLoop<App> = EventLoop::try_new().expect("create event loop");
    let loop_handle = event_loop.handle();

    let wayland_source = WaylandSource::new(conn, event_queue);
    loop_handle
        .insert_source(wayland_source, |_, queue, app| queue.dispatch_pending(app))
        .expect("insert wayland source");

    let runtime_dir = std::env::var("XDG_RUNTIME_DIR").expect("XDG_RUNTIME_DIR not set");
    let sock_path = format!("{runtime_dir}/monitor-dim.sock");
    let _ = std::fs::remove_file(&sock_path);
    let listener = UnixListener::bind(&sock_path).expect("bind control socket");
    listener.set_nonblocking(true).expect("set nonblocking");
    println!("monitor-dim listening on {sock_path}");

    let qh_for_socket = qh.clone();
    loop_handle
        .insert_source(
            calloop::generic::Generic::new(listener, calloop::Interest::READ, calloop::Mode::Level),
            move |_, listener, app: &mut App| {
                loop {
                    match listener.accept() {
                        Ok((mut stream, _)) => {
                            let mut buf = String::new();
                            let _ = stream.read_to_string(&mut buf);
                            app.handle_command(buf.trim(), &qh_for_socket);
                            let _ = stream.write_all(b"ok\n");
                        }
                        Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => break,
                        Err(_) => break,
                    }
                }
                Ok(calloop::PostAction::Continue)
            },
        )
        .expect("insert socket source");

    if let Some(backlight_dir) = find_backlight_device(backlight.as_deref()) {
        let max_brightness: u64 = std::fs::read_to_string(backlight_dir.join("max_brightness"))
            .ok()
            .and_then(|s| s.trim().parse().ok())
            .unwrap_or(1);

        if let Some(p) = read_backlight_percent(&backlight_dir, max_brightness) {
            app.set_percent(p, &qh);
        }

        match Inotify::init() {
            Ok(inotify) => {
                match inotify
                    .watches()
                    .add(backlight_dir.join("brightness"), WatchMask::MODIFY)
                {
                    Ok(_) => {
                        eprintln!("watching backlight: {}", backlight_dir.display());
                        let qh_for_backlight = qh.clone();
                        loop_handle
                            .insert_source(
                                calloop::generic::Generic::new(
                                    inotify,
                                    calloop::Interest::READ,
                                    calloop::Mode::Level,
                                ),
                                move |_, inotify, app: &mut App| {
                                    let mut buf = [0u8; 4096];
                                    // Drain all pending events (a single write can
                                    // sometimes generate more than one) before
                                    // reading the value back, so we always redraw
                                    // with the final settled brightness.
                                    let _ = unsafe { inotify.get_mut() }.read_events(&mut buf);
                                    if let Some(p) =
                                        read_backlight_percent(&backlight_dir, max_brightness)
                                    {
                                        app.set_percent(p, &qh_for_backlight);
                                    }
                                    Ok(calloop::PostAction::Continue)
                                },
                            )
                            .expect("insert backlight watcher");
                    }
                    Err(e) => eprintln!("monitor-dim: failed to watch backlight: {e}"),
                }
            }
            Err(e) => eprintln!("monitor-dim: failed to init inotify: {e}"),
        }
    } else {
        eprintln!("monitor-dim: no backlight device found, real-backlight sync disabled");
    }

    event_loop
        .run(None, &mut app, |_| {})
        .expect("event loop run");
}
