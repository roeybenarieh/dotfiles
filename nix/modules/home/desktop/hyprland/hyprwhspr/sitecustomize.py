# nixpkgs' onnxruntime is built with the OpenVINO execution provider (its
# `openvinoSupport` default is `stdenv.hostPlatform.isLinux` — i.e. on by
# default). hyprwhspr's onnx-asr backend never passes an explicit
# `providers=` list, so onnxruntime auto-selects among whatever's compiled
# in, and OpenVINO gets tried before plain CPU. Its CPU plugin can't handle
# this model's dynamic-rank ops and hard-crashes on load; repeated
# systemd restarts of that crash then OOM the box.
#
# Rebuilding onnxruntime with openvinoSupport = false would fix this too,
# but means compiling onnxruntime (a very large C++ project) from source
# instead of using the cached binary. Forcing CPUExecutionProvider here is
# also just what was asked for in the first place: no GPU/NPU/OpenVINO
# acceleration, plain low-resource CPU inference.
#
# The wrapper script's `exec -a` already renames argv[0] to "hyprwhspr",
# which covers /proc/pid/cmdline (ps aux, htop's default Command column,
# journalctl). But the kernel's separate 15-byte `comm` field — what
# `top`'s default COMMAND column and `ps -o comm=` show — is set from the
# executed binary's own basename (python3.14) and is untouched by argv[0];
# only prctl(PR_SET_NAME) can change it, hence doing it here instead.
try:
    import ctypes

    ctypes.CDLL(None, use_errno=True).prctl(15, b"hyprwhspr", 0, 0, 0)  # PR_SET_NAME
except Exception:
    pass

# Python auto-imports sitecustomize at interpreter startup (via the `site`
# module) if a directory containing it is on sys.path/PYTHONPATH — this
# runs before hyprwhspr's own code, so it's in place before anything
# creates an onnxruntime.InferenceSession.
try:
    import os

    import onnxruntime as _rt

    _orig_init = _rt.InferenceSession.__init__

    def _default_session_options() -> "_rt.SessionOptions":
        # hyprwhspr never passes sess_options either, so onnxruntime falls
        # back to its own defaults: intra_op_num_threads = all CPU cores, and
        # its own CPU memory arena (a pool it grows to the biggest input
        # seen and keeps for reuse — never shrinks on its own). Fine for a
        # benchmark, not for a background dictation daemon meant to stay out
        # of the way of whatever else is running.
        #
        # Cap threads to half the machine's cores (min 1), and disable ORT's
        # own arena/mem-pattern pooling entirely (the documented pairing for
        # lowest CPU memory: onnxruntime.ai/docs/performance/tune-performance/memory.html)
        # so every tensor allocation goes straight through malloc/free rather
        # than being held in a pool "just in case". That would normally cost
        # some speed (glibc's malloc is slow for this), but the wrapper
        # script LD_PRELOADs jemalloc — fast enough per-call that skipping
        # ORT's own pool doesn't show up as extra latency, while jemalloc's
        # decay settings mean freed memory is actually handed back to the OS
        # a few seconds after each transcription instead of held forever.
        #
        # (An earlier version of this tried
        # `add_session_config_entry("memory.enable_memory_arena_shrinkage", ...)`
        # here — that's actually a RunOptions config entry, not a
        # SessionOptions one, so it silently did nothing.)
        opts = _rt.SessionOptions()
        opts.intra_op_num_threads = max(1, (os.cpu_count() or 4) // 2)
        opts.inter_op_num_threads = 1
        opts.execution_mode = _rt.ExecutionMode.ORT_SEQUENTIAL
        opts.enable_cpu_mem_arena = False
        opts.enable_mem_pattern = False
        return opts

    def _cpu_only_init(self, *args, **kwargs):
        # onnx-asr's own loader already builds an explicit, GPU/OpenVINO-first
        # `providers` list before calling InferenceSession (it "automatically
        # uses GPU providers if available"), so a setdefault() here would be a
        # no-op — the key is already populated. Force an unconditional
        # override instead, and drop provider_options with it since it's
        # positionally paired to the providers list being discarded.
        kwargs["providers"] = ["CPUExecutionProvider"]
        kwargs.pop("provider_options", None)
        if len(args) > 2:
            args = args[:2]
        if kwargs.get("sess_options") is None:
            kwargs["sess_options"] = _default_session_options()
        _orig_init(self, *args, **kwargs)

    _rt.InferenceSession.__init__ = _cpu_only_init
except ImportError:
    pass
