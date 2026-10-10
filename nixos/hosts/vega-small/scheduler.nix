{
  services.scx-loader = {
    enable = true;
    config = {
      default_mode = "Auto";

      default_sched = "scx_rustland";

      scheds = {
        # Laptop: keep work in LLC domains, prefer energy, steal only when
        # a remote queue actually has backlog. Hybrid Intel benefits from
        # local kthreads and letting the kernel place kworkers.
        scx_rusty = {
          auto_mode = [
            "--perf"
            "0"
            "--kthreads-local"
            "--balanced-kworkers"
            "--slice-us-underutil"
            "30000"
            "--slice-us-overutil"
            "2000"
            "--interval"
            "3.0"
            "--tune-interval"
            "0.15"
            "--greedy-threshold"
            "2"
            "--direct-greedy-under"
            "70"
          ];
          gaming_mode = [
            "--perf"
            "1024"
            "--kthreads-local"
            "--balanced-kworkers"
            "--slice-us-underutil"
            "15000"
            "--slice-us-overutil"
            "1000"
            "--interval"
            "1.0"
            "--greedy-threshold"
            "1"
          ];
          lowlatency_mode = [
            "--perf"
            "1024"
            "--kthreads-local"
            "--balanced-kworkers"
            "--slice-us-underutil"
            "8000"
            "--slice-us-overutil"
            "500"
            "--interval"
            "1.0"
            "--tune-interval"
            "0.05"
            "--greedy-threshold"
            "1"
          ];
          powersave_mode = [
            "--perf"
            "0"
            "--kthreads-local"
            "--balanced-kworkers"
            "--slice-us-underutil"
            "40000"
            "--slice-us-overutil"
            "3000"
            "--interval"
            "4.0"
            "--greedy-threshold"
            "3"
            "--direct-greedy-under"
            "40"
          ];
          server_mode = [
            "--perf"
            "1024"
            "--balanced-kworkers"
            "--slice-us-underutil"
            "20000"
            "--slice-us-overutil"
            "2000"
            "--interval"
            "2.0"
            "--greedy-threshold"
            "1"
          ];
        };

        # Desktop: interactive vruntime, follow the power profile, scale
        # frequency, prefer faster idle cores. Modes match scx-loader/
        # CachyOS profiles with workstation extras.
        scx_bpfland = {
          auto_mode = [
            "-m"
            "auto"
            "-f"
            "-P"
          ];
          gaming_mode = [
            "-m"
            "all"
            "-f"
          ];
          lowlatency_mode = [
            "-m"
            "performance"
            "-w"
            "-P"
          ];
          powersave_mode = [
            "-s"
            "20000"
            "-m"
            "powersave"
            "-I"
            "100"
            "-t"
            "100"
          ];
          server_mode = [
            "-s"
            "20000"
            "-S"
            "-p"
          ];
        };
      };
    };
  };
}
