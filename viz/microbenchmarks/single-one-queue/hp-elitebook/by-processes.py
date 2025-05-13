import matplotlib.pyplot as plt
import os

# Ensure the output directory exists
output_dir = "hp-elitebook/by-processes/"
os.makedirs(output_dir, exist_ok=True)

# Data for processors and queue types
processors = [2, 3, 4, 5, 6, 7, 8]

# Data for different queues and metrics
queue_data = {
    "SlotQueue": {
        "dequeue_throughput": [
            6.81894,
            5.71659,
            4.83099,
            3.97769,
            3.44791,
            3.02814,
            2.61727,
        ],
        "dequeue_latency": [
            1.4665,
            1.74929,
            2.06997,
            2.51402,
            2.90031,
            3.30236,
            3.82078,
        ],
        "enqueue_throughput": [
            11.3316,
            20.1378,
            25.8008,
            28.7327,
            31.3419,
            38.6143,
            45.297,
        ],
        "enqueue_latency": [
            0.882489,
            0.993158,
            1.16275,
            1.39214,
            1.59531,
            1.55383,
            1.54536,
        ],
        "total_throughput": [
            13.6379,
            11.4333,
            9.66208,
            7.95555,
            6.896,
            6.05634,
            5.23458,
        ],
    },
    "SlotqueueV2a": {
        "dequeue_throughput": [
            6.09889,
            6.15385,
            6.52016,
            6.14641,
            5.91745,
            5.75779,
            5.36214,
        ],
        "dequeue_latency": [1.63964, 1.625, 1.5337, 1.62697, 1.68992, 1.73678, 1.86493],
        "enqueue_throughput": [
            11.3746,
            20.2307,
            31.8985,
            31.8262,
            38.4102,
            46.212,
            51.183,
        ],
        "enqueue_latency": [
            0.879155,
            0.988596,
            0.940483,
            1.25683,
            1.30174,
            1.29836,
            1.36764,
        ],
        "total_throughput": [
            12.1978,
            12.3078,
            13.0405,
            12.2931,
            11.8352,
            11.5157,
            10.7244,
        ],
    },
    "SlotqueueV2b": {
        "dequeue_throughput": [
            6.70067,
            5.57142,
            4.90398,
            3.96746,
            3.49362,
            3.0386,
            2.59459,
        ],
        "dequeue_latency": [
            1.49239,
            1.79488,
            2.03916,
            2.5205,
            2.86236,
            3.29099,
            3.85418,
        ],
        "enqueue_throughput": [
            11.1817,
            20.4358,
            28.9687,
            30.2844,
            38.2494,
            44.3098,
            48.7172,
        ],
        "enqueue_latency": [
            0.894321,
            0.978672,
            1.0356,
            1.32081,
            1.30721,
            1.3541,
            1.43687,
        ],
        "total_throughput": [
            13.4014,
            11.1429,
            9.80807,
            7.93509,
            6.98741,
            6.07727,
            5.18923,
        ],
    },
    "SlotqueueV2bc": {
        "dequeue_throughput": [
            7.62019,
            6.17768,
            5.14497,
            4.20368,
            3.57532,
            3.04596,
            2.56634,
        ],
        "dequeue_latency": [
            1.3123,
            1.61873,
            1.94365,
            2.37887,
            2.79695,
            3.28304,
            3.8966,
        ],
        "enqueue_throughput": [
            11.0081,
            20.9979,
            31.6145,
            30.4032,
            38.0977,
            43.9242,
            46.6678,
        ],
        "enqueue_latency": [
            0.908425,
            0.952477,
            0.948933,
            1.31565,
            1.31241,
            1.36599,
            1.49996,
        ],
        "total_throughput": [
            15.2404,
            12.3555,
            10.29,
            8.40753,
            7.15083,
            6.09197,
            5.13273,
        ],
    },
    "SlotqueueV2c": {
        "dequeue_throughput": [
            7.7,
            6.22422,
            5.00374,
            4.08707,
            3.31598,
            2.95004,
            2.24523,
        ],
        "dequeue_latency": [1.2987, 1.60663, 1.9985, 2.44674, 3.0157, 3.38979, 4.45389],
        "enqueue_throughput": [
            11.2746,
            20.7553,
            30.4501,
            29.5741,
            35.2954,
            44.7213,
            45.4193,
        ],
        "enqueue_latency": [
            0.886949,
            0.963611,
            0.985218,
            1.35254,
            1.41662,
            1.34164,
            1.5412,
        ],
        "total_throughput": [
            15.4001,
            12.4486,
            10.0076,
            8.17431,
            6.63213,
            5.90013,
            4.4905,
        ],
    },
    "LTQueue": {
        "dequeue_throughput": [
            3.95019,
            3.11975,
            2.41366,
            1.67987,
            1.29303,
            1.16547,
            1.04037,
        ],
        "dequeue_latency": [
            2.53152,
            3.20539,
            4.14309,
            5.95285,
            7.73376,
            8.58025,
            9.61195,
        ],
        "enqueue_throughput": [
            3.95032,
            5.20074,
            5.84926,
            3.59356,
            2.89035,
            2.53857,
            2.33592,
        ],
        "enqueue_latency": [
            2.53144,
            3.84561,
            5.12885,
            11.131,
            17.299,
            23.6353,
            29.9668,
        ],
        "total_throughput": [
            7.89979,
            6.23956,
            4.82737,
            3.3598,
            2.58613,
            2.33096,
            2.08076,
        ],
    },
    "FastQueue": {
        "dequeue_throughput": [
            22.4075,
            24.2383,
            22.8367,
            21.762,
            20.8893,
            19.9618,
            18.4989,
        ],
        "dequeue_latency": [
            0.44628,
            0.41257,
            0.437892,
            0.459516,
            0.478714,
            0.500958,
            0.540574,
        ],
        "enqueue_throughput": [
            24.2801,
            46.6557,
            64.2453,
            58.6029,
            51.5705,
            44.8054,
            63.916,
        ],
        "enqueue_latency": [
            0.41186,
            0.428672,
            0.46696,
            0.68256,
            0.969546,
            1.33912,
            1.09519,
        ],
        "total_throughput": [
            44.4614,
            48.4766,
            45.6734,
            43.5241,
            41.7786,
            39.9235,
            36.9977,
        ],
    },
    "CCQueue": {
        "dequeue_throughput": [
            17.616,
            16.4051,
            18.4161,
            18.196,
            17.8664,
            17.5705,
            17.307,
        ],
        "dequeue_latency": [
            0.567666,
            0.609568,
            0.543002,
            0.549572,
            0.55971,
            0.569136,
            0.5778,
        ],
        "enqueue_throughput": [
            16.7991,
            2.2135,
            0.992255,
            0.354012,
            0.334526,
            0.334222,
            0.332161,
        ],
        "enqueue_latency": [
            0.59527,
            9.03547,
            30.2342,
            112.991,
            149.465,
            179.521,
            210.741,
        ],
        "total_throughput": [
            33.4928,
            4.42633,
            1.98423,
            0.707915,
            0.668973,
            0.668368,
            0.664204,
        ],
    },
}

# Metrics to plot
metrics = [
    "dequeue_throughput",
    "dequeue_latency",
    "enqueue_throughput",
    "enqueue_latency",
    "total_throughput",
]

# Metric labels and units
metric_labels = {
    "dequeue_throughput": ("Dequeue Throughput", "10^5 ops/s"),
    "dequeue_latency": ("Dequeue Latency", "μs"),
    "enqueue_throughput": ("Enqueue Throughput", "10^5 ops/s"),
    "enqueue_latency": ("Enqueue Latency", "μs"),
    "total_throughput": ("Total Throughput", "10^5 ops/s"),
}

# Color and marker styles for each queue
queue_styles = {
    "SlotQueue": {"color": "blue", "marker": "o"},
    "LTQueue": {"color": "red", "marker": "s"},
    "FastQueue": {"color": "green", "marker": "^"},
    "SlotqueueV2a": {"color": "purple", "marker": "d", "linestyle": "--"},
    "SlotqueueV2b": {"color": "orange", "marker": "x", "linestyle": "-."},
    "SlotqueueV2c": {"color": "brown", "marker": "*", "linestyle": ":"},
    "SlotqueueV2bc": {"color": "magenta", "marker": "+", "linestyle": "--"},
    "CCQueue": {"color": "cyan", "marker": "v", "linestyle": "-"},
}

# Generate merged plots for each metric
for metric in metrics:
    # Create a new figure for each metric
    plt.figure(figsize=(12, 7))
    # Plot data for each queue
    for queue_name, queue_metrics in queue_data.items():
        style = queue_styles[queue_name]
        plt.plot(
            processors,
            queue_metrics[metric],
            color=style["color"],
            marker=style["marker"],
            linestyle=style.get("linestyle", "-"),
            label=f"{queue_name}{'*' if queue_name == 'SlotqueueV2a' else ''}",
        )

    # Set title and labels
    title, unit = metric_labels[metric]
    plt.title(f"Comparative {title} Across Queue Implementations")
    plt.xlabel("Number of Processors")
    plt.ylabel(f"{title} ({unit})")

    # Add grid and legend
    plt.grid(True)
    plt.legend(title="Queue Types", loc="best")

    # Save the plot
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename)
    plt.close()  # Close the figure to free up memory

print(
    "All comparative plots have been generated in the 'hp-elitebook/by-processes' folder."
)
print(
    "Note: SlotqueueV2a is marked with an asterisk (*) in the legend to indicate it is experimental."
)
