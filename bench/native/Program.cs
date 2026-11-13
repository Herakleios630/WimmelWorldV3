// WimmelWorld V3 – G0.5 Native-Vergleich (wegwerfbar).
//
// Bewusste Einschränkung: Es gibt keinen Godot-.NET-Build auf dieser Maschine.
// Dies ist eine reine .NET-8-Konsolen-App, die denselben Scheduler- und
// SoA-Hotloop wie die GDScript-Spike-Dateien ausführt. Keine Godot-Interop,
// keine Szenen, keine GPU. Vergleichbar sind Kosten und – über den
// xorshift64*-PRNG und identische Feldreihenfolge – auch die Zustandshashes.
//
// Aufruf: dotnet run -c Release   (in V3/bench/native)

using System.Diagnostics;
using System.Text.Json;

namespace NativeSpike;

internal static class Program
{
    private const long Seed = 1337;
    private const int Reps = 3;

    private static int Main(string[] args)
    {
        // Auflösung relativ zur Assembly, damit `dotnet run --project ...` aus
        // jedem Arbeitsverzeichnis nach V3/bench/results schreibt.
        // BaseDirectory = V3/bench/native/bin/<cfg>/net8.0/
        string outDir = args.Length > 0
            ? Path.GetFullPath(args[0])
            : Path.GetFullPath(Path.Combine(
                AppContext.BaseDirectory, "..", "..", "..", "..", "results"));
        Directory.CreateDirectory(outDir);
        WarmUp();

        var result = new Dictionary<string, object?>
        {
            ["meta"] = Meta(),
            ["scheduler"] = RunScheduler(),
            ["soa"] = RunSoa(),
            ["parity"] = RunParity(),
            ["limits"] = new Dictionary<string, object?>
            {
                ["godot_dotnet_build"] = false,
                ["godot_interop"] = false,
                ["render"] = false,
                ["note"] = "Reine .NET-8-Konsolen-App; kein Godot-.NET-Build vorhanden. " +
                           "Kosten sind vergleichbar, Godot-Interop/GC/Engine-Kopplung nicht gemessen.",
            },
        };

        string path = Path.Combine(outDir, "native_csharp.json");
        File.WriteAllText(path,
            JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true }));
        PrintScheduler(result);
        PrintSoa(result);
        Console.WriteLine($"NATIVE_SPIKE_OK file={path}");
        return 0;
    }

    private static Dictionary<string, object?> Meta() => new()
    {
        ["kind"] = "native_csharp_console",
        ["seed"] = Seed,
        ["reps"] = Reps,
        ["dotnet"] = Environment.Version.ToString(),
        ["runtime"] = System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription,
        ["os"] = Environment.OSVersion.ToString(),
        ["os_description"] = System.Runtime.InteropServices.RuntimeInformation.OSDescription,
        ["cpu_count"] = Environment.ProcessorCount,
        ["utc"] = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss"),
        ["stopwatch_frequency"] = Stopwatch.Frequency,
        ["optimized"] = !IsDebugBuild(),
    };

    private static bool IsDebugBuild()
    {
#if DEBUG
        return true;
#else
        return false;
#endif
    }

    // -----------------------------------------------------------------------
    // JIT-/Tiering-Warmlauf außerhalb der Messung. Ohne ihn messen die ersten
    // Konfigurationen Tier-0-Code und die letzten Tier-1-Code.
    // -----------------------------------------------------------------------

    private static void WarmUp()
    {
        long until = Stopwatch.GetTimestamp() + Stopwatch.Frequency * 3 / 2;
        var rng = new XorShift64Star(999);
        var store = new AgentStore();
        store.Configure(50000, 999);
        int round = 0;
        while (Stopwatch.GetTimestamp() < until)
        {
            var sched = new Scheduler(50000);
            for (int i = 0; i < 50000; i++) sched.Push(rng.NextRange(3600), i % 5, i);
            while (sched.Pop()) { }
            store.Tick(round * 30L, 30.0, 50000);
            round++;
        }
    }

    // -----------------------------------------------------------------------
    // Deterministic PRNG – muss bitgleich zu SpikeRng (GDScript) sein.
    // -----------------------------------------------------------------------

    private sealed class XorShift64Star
    {
        private const long Mul = 0x2545F4914F6CDD1D;
        private long _state;

        public XorShift64Star(long seed)
        {
            _state = seed;
            if (_state == 0) _state = Mul;
        }

        public long NextU64()
        {
            long x = _state;
            x ^= x >> 12;
            x ^= x << 25;
            x ^= x >> 27;
            _state = x;
            return unchecked(x * Mul);
        }

        public int NextRange(int bound)
        {
            if (bound <= 1) return 0;
            return (int)((NextU64() & long.MaxValue) % bound);
        }

        public double NextUnit() => (NextU64() & long.MaxValue) / 9223372036854775808.0;
    }

    // -----------------------------------------------------------------------
    // Scheduler: Min-Heap (time, seq) über parallele Arrays.
    // -----------------------------------------------------------------------

    private sealed class Scheduler
    {
        private long[] _time;
        private long[] _seq;
        private int[] _kind;
        private long[] _payload;
        private int _size;
        private long _nextSeq;

        public long LastTime;
        public long LastSeq;
        public int LastKind;
        public long LastPayload;

        public Scheduler(int capacity)
        {
            _time = new long[capacity];
            _seq = new long[capacity];
            _kind = new int[capacity];
            _payload = new long[capacity];
        }

        public int Size => _size;

        public void Push(long time, int kind, long payload)
        {
            long s = _nextSeq++;
            int i = _size++;
            while (i > 0)
            {
                int parent = (i - 1) >> 1;
                long pt = _time[parent];
                if (pt < time || (pt == time && _seq[parent] < s)) break;
                _time[i] = pt;
                _seq[i] = _seq[parent];
                _kind[i] = _kind[parent];
                _payload[i] = _payload[parent];
                i = parent;
            }
            _time[i] = time;
            _seq[i] = s;
            _kind[i] = kind;
            _payload[i] = payload;
        }

        public bool Pop()
        {
            int n = _size;
            if (n == 0) return false;
            LastTime = _time[0];
            LastSeq = _seq[0];
            LastKind = _kind[0];
            LastPayload = _payload[0];
            n--;
            _size = n;
            if (n == 0) return true;

            long lt = _time[n];
            long ls = _seq[n];
            int lk = _kind[n];
            long lp = _payload[n];
            int i = 0;
            int half = n >> 1;
            while (i < half)
            {
                int child = (i << 1) + 1;
                int right = child + 1;
                if (right < n)
                {
                    long rt = _time[right];
                    long ct = _time[child];
                    if (rt < ct || (rt == ct && _seq[right] < _seq[child])) child = right;
                }
                long c2 = _time[child];
                if (lt < c2 || (lt == c2 && ls < _seq[child])) break;
                _time[i] = c2;
                _seq[i] = _seq[child];
                _kind[i] = _kind[child];
                _payload[i] = _payload[child];
                i = child;
            }
            _time[i] = lt;
            _seq[i] = ls;
            _kind[i] = lk;
            _payload[i] = lp;
            return true;
        }
    }

    private static (int[] kind, int[] time, int[] payload) MakeEvents(int n, long seed, int burstPercent)
    {
        var kind = new int[n];
        var time = new int[n];
        var payload = new int[n];
        var rng = new XorShift64Star(seed);
        for (int i = 0; i < n; i++)
        {
            kind[i] = i % 5;
            time[i] = rng.NextRange(100) < burstPercent ? 0 : rng.NextRange(3600);
            payload[i] = rng.NextRange(1000000);
        }
        return (kind, time, payload);
    }

    private static Dictionary<string, object?> RunScheduler()
    {
        var rows = new List<Dictionary<string, object?>>();
        foreach (int n in new[] { 10000, 100000 })
        {
            foreach (int burst in new[] { 0, 10, 50, 100 })
            {
                long seed = Seed + n + burst * 97L;
                var (kind, time, payload) = MakeEvents(n, seed, burst);
                int chunk = n <= 10000 ? 64 : 256;
                var runs = new List<Dictionary<string, object?>>();

                for (int rep = 0; rep < Reps; rep++)
                {
                    var sched = new Scheduler(n);
                    long t0 = Stopwatch.GetTimestamp();
                    for (int i = 0; i < n; i++) sched.Push(time[i], kind[i], payload[i]);
                    long t1 = Stopwatch.GetTimestamp();

                    var samples = new List<double>(n / chunk + 1);
                    long acc = 0;
                    bool orderOk = true;
                    long lastT = -1, lastS = -1;
                    int done = 0;
                    while (done < n)
                    {
                        int c = Math.Min(chunk, n - done);
                        long c0 = Stopwatch.GetTimestamp();
                        for (int k = 0; k < c; k++)
                        {
                            sched.Pop();
                            acc += sched.LastSeq;
                            if (sched.LastTime < lastT ||
                                (sched.LastTime == lastT && sched.LastSeq < lastS)) orderOk = false;
                            lastT = sched.LastTime;
                            lastS = sched.LastSeq;
                        }
                        long c1 = Stopwatch.GetTimestamp();
                        samples.Add(Us(c1 - c0) / c);
                        done += c;
                    }
                    long t2 = Stopwatch.GetTimestamp();
                    double totalUs = Us(t2 - t0);
                    double pushUs = Us(t1 - t0);
                    double popUs = Us(t2 - t1);
                    samples.Sort();
                    runs.Add(new Dictionary<string, object?>
                    {
                        ["rep"] = rep,
                        ["total_ms"] = totalUs / 1000.0,
                        ["events_per_s"] = n / (totalUs / 1_000_000.0),
                        ["us_per_event"] = totalUs / n,
                        ["push_us_per_event"] = pushUs / n,
                        ["pop_us_per_event"] = popUs / n,
                        ["p50_us"] = Pct(samples, 50),
                        ["p95_us"] = Pct(samples, 95),
                        ["p99_us"] = Pct(samples, 99),
                        ["max_us"] = samples[^1],
                        ["checksum"] = (uint)acc,
                        ["order_ok"] = orderOk,
                    });
                }

                rows.Add(new Dictionary<string, object?>
                {
                    ["events"] = n,
                    ["burst_percent"] = burst,
                    ["chunk_events"] = chunk,
                    ["order_ok_warmup"] = runs.Count > 0 ? runs.All(r => (bool)r["order_ok"]!) : false,
                    ["median"] = MedianRun(runs, "us_per_event"),
                    ["runs"] = runs,
                });
            }
        }
        return new Dictionary<string, object?>
        {
            ["rows"] = rows,
            ["notes"] = "Gleiche Last wie GDScript (xorshift64*, gleiche Seeds/Reihenfolge).",
        };
    }

    // -----------------------------------------------------------------------
    // SoA: Need-Update + Terminplanung, float32-Speicher, double-Zwischenschritt
    // (muss zu agent_store.gd passen).
    // -----------------------------------------------------------------------

    private sealed class AgentStore
    {
        public const int BytesPerAgent = 58;

        public int Count;
        public int[] Ids = Array.Empty<int>();
        public byte[] Alive = Array.Empty<byte>();
        public byte[] Activity = Array.Empty<byte>();
        public float[] Age = Array.Empty<float>();
        public float[] PosX = Array.Empty<float>();
        public float[] PosY = Array.Empty<float>();
        public long[] NextEvent = Array.Empty<long>();
        public float[] Hunger = Array.Empty<float>();
        public float[] Energy = Array.Empty<float>();
        public float[] Social = Array.Empty<float>();
        public float[] Hygiene = Array.Empty<float>();
        public float[] Fun = Array.Empty<float>();
        public float[] Health = Array.Empty<float>();
        public int[] HomeId = Array.Empty<int>();
        public int[] JobId = Array.Empty<int>();

        public void Configure(int n, long seed)
        {
            Count = n;
            Ids = new int[n];
            Alive = new byte[n];
            Activity = new byte[n];
            Age = new float[n];
            PosX = new float[n];
            PosY = new float[n];
            NextEvent = new long[n];
            Hunger = new float[n];
            Energy = new float[n];
            Social = new float[n];
            Hygiene = new float[n];
            Fun = new float[n];
            Health = new float[n];
            HomeId = new int[n];
            JobId = new int[n];

            var rng = new XorShift64Star(seed);
            for (int i = 0; i < n; i++)
            {
                Ids[i] = i;
                Alive[i] = 1;
                Activity[i] = 0;
                Age[i] = (float)(16.0 + rng.NextUnit() * 44.0);
                PosX[i] = (float)(rng.NextUnit() * 1024.0);
                PosY[i] = (float)(rng.NextUnit() * 1024.0);
                NextEvent[i] = 0;
                Hunger[i] = (float)(rng.NextUnit() * 60.0);
                Energy[i] = (float)(40.0 + rng.NextUnit() * 60.0);
                Social[i] = (float)(rng.NextUnit() * 60.0);
                Hygiene[i] = (float)(rng.NextUnit() * 70.0);
                Fun[i] = (float)(rng.NextUnit() * 70.0);
                Health[i] = (float)(70.0 + rng.NextUnit() * 30.0);
                HomeId[i] = rng.NextRange(5000);
                JobId[i] = rng.NextRange(64);
            }
        }

        public void UpdateNeedsOnly(double dt, int n)
        {
            double hr = dt / Needs.HungerSpu;
            double er = dt / Needs.EnergySpu;
            double sr = dt / Needs.SocialSpu;
            double yr = dt / Needs.HygieneSpu;
            double fr = dt / Needs.FunSpu;
            for (int i = 0; i < n; i++)
            {
                float v = (float)(Hunger[i] + hr);
                Hunger[i] = v > 100.0 ? 100f : v;
                v = (float)(Energy[i] - er);
                Energy[i] = v < 0.0 ? 0f : v;
                v = (float)(Social[i] + sr);
                Social[i] = v > 100.0 ? 100f : v;
                v = (float)(Hygiene[i] + yr);
                Hygiene[i] = v > 100.0 ? 100f : v;
                v = (float)(Fun[i] + fr);
                Fun[i] = v > 100.0 ? 100f : v;
            }
        }

        public int Tick(long now, double dt, int n)
        {
            double hr = dt / Needs.HungerSpu;
            double er = dt / Needs.EnergySpu;
            double sr = dt / Needs.SocialSpu;
            double yr = dt / Needs.HygieneSpu;
            double fr = dt / Needs.FunSpu;
            int scheduled = 0;
            for (int i = 0; i < n; i++)
            {
                float v = (float)(Hunger[i] + hr);
                if (v > 100.0) v = 100f;
                Hunger[i] = v;
                v = (float)(Energy[i] - er);
                if (v < 0.0) v = 0f;
                Energy[i] = v;
                v = (float)(Social[i] + sr);
                if (v > 100.0) v = 100f;
                Social[i] = v;
                v = (float)(Hygiene[i] + yr);
                if (v > 100.0) v = 100f;
                Hygiene[i] = v;
                v = (float)(Fun[i] + fr);
                if (v > 100.0) v = 100f;
                Fun[i] = v;

                double best = (Needs.WakeHunger - Hunger[i]) * Needs.HungerSpu;
                double d = (Energy[i] - Needs.WakeEnergy) * Needs.EnergySpu;
                if (d < best) best = d;
                d = (Needs.WakeSocial - Social[i]) * Needs.SocialSpu;
                if (d < best) best = d;
                d = (Needs.WakeHygiene - Hygiene[i]) * Needs.HygieneSpu;
                if (d < best) best = d;
                d = (Needs.WakeFun - Fun[i]) * Needs.FunSpu;
                if (d < best) best = d;
                if (best < Needs.MinWake) best = Needs.MinWake;
                long jitter = (((long)i * 2654435761L) >> 8) % 83;
                NextEvent[i] = now + (long)best + jitter;
                scheduled++;
            }
            return scheduled;
        }

        public uint StateHash()
        {
            uint h = 2166136261u;
            for (int i = 0; i < Count; i++)
            {
                h = Mix(h, Ids[i]);
                h = Mix(h, Alive[i]);
                h = Mix(h, Activity[i]);
                h = Mix(h, (long)Math.Round(Age[i] * 1000.0, MidpointRounding.AwayFromZero));
                h = Mix(h, (long)Math.Round(PosX[i] * 1000.0, MidpointRounding.AwayFromZero));
                h = Mix(h, (long)Math.Round(PosY[i] * 1000.0, MidpointRounding.AwayFromZero));
                h = Mix(h, NextEvent[i]);
                h = Mix(h, (long)Math.Round(Hunger[i] * 1000.0, MidpointRounding.AwayFromZero));
                h = Mix(h, (long)Math.Round(Energy[i] * 1000.0, MidpointRounding.AwayFromZero));
                h = Mix(h, (long)Math.Round(Social[i] * 1000.0, MidpointRounding.AwayFromZero));
                h = Mix(h, (long)Math.Round(Hygiene[i] * 1000.0, MidpointRounding.AwayFromZero));
                h = Mix(h, (long)Math.Round(Fun[i] * 1000.0, MidpointRounding.AwayFromZero));
                h = Mix(h, (long)Math.Round(Health[i] * 1000.0, MidpointRounding.AwayFromZero));
                h = Mix(h, HomeId[i]);
                h = Mix(h, JobId[i]);
            }
            return h;
        }

        private static uint Mix(uint h, long v)
        {
            return unchecked((h ^ (uint)(v & 0xFFFFFFFF)) * 16777619u);
        }
    }

    private static class Needs
    {
        public const double HungerSpu = 470.0;
        public const double EnergySpu = 840.0;
        public const double SocialSpu = 655.0;
        public const double HygieneSpu = 935.0;
        public const double FunSpu = 750.0;
        public const double WakeHunger = 70.0;
        public const double WakeEnergy = 30.0;
        public const double WakeSocial = 75.0;
        public const double WakeHygiene = 80.0;
        public const double WakeFun = 85.0;
        public const double MinWake = 1.0;
    }

    private static Dictionary<string, object?> RunSoa()
    {
        var rows = new List<Dictionary<string, object?>>();
        foreach (int n in new[] { 10, 1000, 10000, 100000 })
        {
            int ticks = Math.Clamp(2_000_000 / n, 4, 100);
            long seed = Seed + n;
            var runs = new List<Dictionary<string, object?>>();

            for (int rep = 0; rep < Reps; rep++)
            {
                var store = new AgentStore();
                store.Configure(n, seed);
                var samples = new List<double>(ticks);
                int scheduled = 0;
                long t0 = Stopwatch.GetTimestamp();
                for (int t = 0; t < ticks; t++)
                {
                    long c0 = Stopwatch.GetTimestamp();
                    scheduled += store.Tick(t * 30, 30.0, n);
                    long c1 = Stopwatch.GetTimestamp();
                    samples.Add(Us(c1 - c0) / n);
                }
                double totalUs = Us(Stopwatch.GetTimestamp() - t0);
                long u0 = Stopwatch.GetTimestamp();
                for (int t = 0; t < 5; t++) store.UpdateNeedsOnly(30.0, n);
                double updateUs = Us(Stopwatch.GetTimestamp() - u0) / 5.0 / n;
                samples.Sort();
                runs.Add(new Dictionary<string, object?>
                {
                    ["rep"] = rep,
                    ["ticks"] = ticks,
                    ["total_ms"] = totalUs / 1000.0,
                    ["us_per_agent_tick"] = totalUs / n / ticks,
                    ["p50_us_agent"] = Pct(samples, 50),
                    ["p95_us_agent"] = Pct(samples, 95),
                    ["p99_us_agent"] = Pct(samples, 99),
                    ["max_us_agent"] = samples[^1],
                    ["update_only_us_agent"] = updateUs,
                    ["scheduled_events"] = scheduled,
                    ["us_per_scheduled_event"] = totalUs / Math.Max(scheduled, 1),
                    ["state_hash"] = $"0x{store.StateHash():X8}",
                });
            }

            rows.Add(new Dictionary<string, object?>
            {
                ["agents"] = n,
                ["ticks"] = ticks,
                ["memory_bytes"] = n * AgentStore.BytesPerAgent,
                ["bytes_per_agent"] = AgentStore.BytesPerAgent,
                ["median"] = MedianRun(runs, "us_per_agent_tick"),
                ["runs"] = runs,
            });
        }
        return new Dictionary<string, object?>
        {
            ["rows"] = rows,
            ["notes"] = "float32-Speicher, double-Zwischenschritt; gleiche Feldreihenfolge wie GDScript.",
        };
    }

    // -----------------------------------------------------------------------
    // Parität: Workload- und Zustandshashes zum Vergleich mit GDScript.
    // -----------------------------------------------------------------------

    private static Dictionary<string, object?> RunParity()
    {
        var workload = new Dictionary<string, object?>();
        foreach (int n in new[] { 10000, 100000 })
        {
            foreach (int burst in new[] { 0, 50, 100 })
            {
                var (kind, time, payload) = MakeEvents(n, Seed + n + burst * 97L, burst);
                uint h = 2166136261u;
                for (int i = 0; i < n; i++)
                {
                    h = Mix32(h, kind[i]);
                    h = Mix32(h, time[i]);
                    h = Mix32(h, payload[i]);
                }
                workload[$"{n}_{burst}"] = $"0x{h:X8}";
            }
        }

        var soa = new Dictionary<string, object?>();
        var sampleAfter = new List<object?>();
        foreach (int n in new[] { 10000, 100000 })
        {
            var store = new AgentStore();
            store.Configure(n, Seed + n);
            for (int t = 0; t < 20; t++) store.Tick(t * 30, 30.0, n);
            soa[$"{n}"] = $"0x{store.StateHash():X8}";
            if (n == 10000)
            {
                for (int i = 0; i < 3; i++)
                {
                    sampleAfter.Add(new Dictionary<string, object?>
                    {
                        ["hunger"] = store.Hunger[i].ToString("F9", System.Globalization.CultureInfo.InvariantCulture),
                        ["energy"] = store.Energy[i].ToString("F9", System.Globalization.CultureInfo.InvariantCulture),
                        ["next_event"] = store.NextEvent[i],
                    });
                }
            }
        }

        var sampleStore = new AgentStore();
        sampleStore.Configure(3, Seed + 10000);
        var sample = new List<object?>();
        for (int i = 0; i < 3; i++)
        {
            sample.Add(new Dictionary<string, object?>
            {
                ["hunger"] = sampleStore.Hunger[i].ToString("F9", System.Globalization.CultureInfo.InvariantCulture),
                ["energy"] = sampleStore.Energy[i].ToString("F9", System.Globalization.CultureInfo.InvariantCulture),
                ["age"] = sampleStore.Age[i].ToString("F9", System.Globalization.CultureInfo.InvariantCulture),
                ["pos_x"] = sampleStore.PosX[i].ToString("F9", System.Globalization.CultureInfo.InvariantCulture),
                ["home"] = sampleStore.HomeId[i],
                ["job"] = sampleStore.JobId[i],
            });
        }

        return new Dictionary<string, object?>
        {
            ["scheduler_workload_hash"] = workload,
            ["soa_state_hash_20_ticks"] = soa,
            ["sample_configure"] = sample,
            ["sample_after_20_ticks"] = sampleAfter,
        };
    }
    private static uint Mix32(uint h, long v) => unchecked((h ^ (uint)(v & 0xFFFFFFFF)) * 16777619u);

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static double Us(long stopwatchDelta) =>
        stopwatchDelta * 1_000_000.0 / Stopwatch.Frequency;

    private static double Pct(List<double> sorted, double p)
    {
        int idx = (int)Math.Ceiling(p / 100.0 * sorted.Count) - 1;
        return sorted[Math.Clamp(idx, 0, sorted.Count - 1)];
    }

    private static Dictionary<string, object?> MedianRun(List<Dictionary<string, object?>> runs, string key)
    {
        var sorted = runs.OrderBy(r => Convert.ToDouble(r[key])).ToList();
        return sorted[sorted.Count / 2];
    }

    private static void PrintScheduler(Dictionary<string, object?> result)
    {
        var sched = (Dictionary<string, object?>)result["scheduler"]!;
        foreach (var row in (List<Dictionary<string, object?>>)sched["rows"]!)
        {
            var m = (Dictionary<string, object?>)row["median"]!;
            Console.WriteLine(
                $"scheduler events={row["events"]} burst={row["burst_percent"]}% " +
                $"us/event={Convert.ToDouble(m["us_per_event"]):F3} " +
                $"push={Convert.ToDouble(m["push_us_per_event"]):F3} " +
                $"pop={Convert.ToDouble(m["pop_us_per_event"]):F3} " +
                $"events/s={Convert.ToDouble(m["events_per_s"]):F0} " +
                $"p95={Convert.ToDouble(m["p95_us"]):F3}");
        }
    }

    private static void PrintSoa(Dictionary<string, object?> result)
    {
        var soa = (Dictionary<string, object?>)result["soa"]!;
        foreach (var row in (List<Dictionary<string, object?>>)soa["rows"]!)
        {
            var m = (Dictionary<string, object?>)row["median"]!;
            Console.WriteLine(
                $"soa agents={row["agents"]} " +
                $"us/agent/tick={Convert.ToDouble(m["us_per_agent_tick"]):F5} " +
                $"update_only={Convert.ToDouble(m["update_only_us_agent"]):F5} " +
                $"us/event={Convert.ToDouble(m["us_per_scheduled_event"]):F4} " +
                $"mem={row["memory_bytes"]}");
        }
    }
}
