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
            6.63307,
            5.55829,
            4.69622,
            3.98042,
            3.38794,
            3.03398,
            2.54464,
        ],
        "dequeue_latency": [1.5076, 1.79912, 2.12937, 2.5123, 2.95165, 3.296, 3.92983],
        "enqueue_throughput": [
            10.2544,
            19.618,
            28.8674,
            29.3826,
            33.7418,
            40.3065,
            43.9944,
        ],
        "enqueue_latency": [
            0.975194,
            1.01947,
            1.03923,
            1.36135,
            1.48184,
            1.48859,
            1.59111,
        ],
        "total_throughput": [
            13.2662,
            11.1167,
            9.39253,
            7.96099,
            6.77605,
            6.06803,
            5.08933,
        ],
    },
    "SlotqueueV2a": {
        "dequeue_throughput": [
            6.12935,
            6.44171,
            6.40048,
            5.83681,
            5.84371,
            5.64016,
            5.31076,
        ],
        "dequeue_latency": [
            1.63149,
            1.55238,
            1.56238,
            1.71327,
            1.71124,
            1.773,
            1.88297,
        ],
        "enqueue_throughput": [
            11.3278,
            21.4789,
            30.8998,
            30.4612,
            38.2551,
            45.1242,
            50.1327,
        ],
        "enqueue_latency": [
            0.882781,
            0.931145,
            0.970881,
            1.31315,
            1.30702,
            1.32966,
            1.39629,
        ],
        "total_throughput": [
            12.2588,
            12.8836,
            12.8011,
            11.6738,
            11.6877,
            11.2804,
            10.6216,
        ],
    },
    "SlotqueueV2b": {
        "dequeue_throughput": [
            6.92319,
            5.7495,
            4.86717,
            3.83262,
            3.24694,
            2.74829,
            2.37893,
        ],
        "dequeue_latency": [
            1.44442,
            1.73928,
            2.05458,
            2.60918,
            3.07982,
            3.63863,
            4.20357,
        ],
        "enqueue_throughput": [
            10.9696,
            21.4022,
            30.8999,
            29.2926,
            36.4267,
            40.7422,
            43.9797,
        ],
        "enqueue_latency": [
            0.911613,
            0.934485,
            0.970877,
            1.36553,
            1.37262,
            1.47267,
            1.59164,
        ],
        "total_throughput": [
            13.8465,
            11.4991,
            9.73443,
            7.66539,
            6.49405,
            5.49663,
            4.75791,
        ],
    },
    "SlotqueueV2bc": {
        "dequeue_throughput": [
            7.63835,
            6.30407,
            5.05353,
            4.05938,
            3.37212,
            2.85279,
            2.48758,
        ],
        "dequeue_latency": [
            1.30918,
            1.58628,
            1.97882,
            2.46343,
            2.9655,
            3.50534,
            4.01997,
        ],
        "enqueue_throughput": [
            10.6786,
            21.3014,
            30.1369,
            28.8688,
            35.604,
            40.5299,
            45.2221,
        ],
        "enqueue_latency": [
            0.936449,
            0.938903,
            0.995456,
            1.38558,
            1.40434,
            1.48039,
            1.54792,
        ],
        "total_throughput": [
            15.2768,
            12.6083,
            10.1072,
            8.11892,
            6.7444,
            5.70563,
            4.97521,
        ],
    },
    "SlotqueueV2c": {
        "dequeue_throughput": [
            7.6345,
            6.04767,
            4.90764,
            3.99454,
            3.34632,
            2.8309,
            2.48215,
        ],
        "dequeue_latency": [
            1.30984,
            1.65353,
            2.03764,
            2.50342,
            2.98835,
            3.53244,
            4.02876,
        ],
        "enqueue_throughput": [
            11.2675,
            21.0002,
            29.9032,
            29.9612,
            35.7316,
            43.5121,
            48.8721,
        ],
        "enqueue_latency": [
            0.887511,
            0.952371,
            1.00324,
            1.33506,
            1.39932,
            1.37893,
            1.43231,
        ],
        "total_throughput": [
            15.2691,
            12.0955,
            9.81537,
            7.98923,
            6.69281,
            5.66186,
            4.96435,
        ],
    },
    "LTQueue": {
        "dequeue_throughput": [
            3.8022,
            2.95278,
            2.4062,
            1.63283,
            1.38335,
            1.13891,
            1.04291,
        ],
        "dequeue_latency": [
            2.63006,
            3.38664,
            4.15594,
            6.12433,
            7.22884,
            8.78034,
            9.58853,
        ],
        "enqueue_throughput": [
            3.80498,
            5.14678,
            6.10691,
            3.61271,
            3.26702,
            2.5615,
            2.41199,
        ],
        "enqueue_latency": [
            2.62814,
            3.88592,
            4.91247,
            11.072,
            15.3045,
            23.4238,
            29.0217,
        ],
        "total_throughput": [
            7.60422,
            5.90561,
            4.81244,
            3.26573,
            2.76676,
            2.27784,
            2.08585,
        ],
    },
    "FastQueue": {
        "dequeue_throughput": [
            25.8909,
            25.4756,
            23.3356,
            21.9261,
            20.9015,
            20.0701,
            17.3319,
        ],
        "dequeue_latency": [
            0.386236,
            0.392532,
            0.42853,
            0.456078,
            0.478434,
            0.498254,
            0.57697,
        ],
        "enqueue_throughput": [
            25.7998,
            47.4989,
            64.1599,
            59.4465,
            50.4432,
            43.9945,
            53.6659,
        ],
        "enqueue_latency": [
            0.3876,
            0.421062,
            0.467582,
            0.672874,
            0.991214,
            1.36381,
            1.30437,
        ],
        "total_throughput": [
            51.4501,
            50.9513,
            46.6712,
            43.8521,
            41.803,
            40.1402,
            34.6638,
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
    "SlotqueueV2a": {"color": "purple", "marker": "d", "linestyle": "--"},
    "SlotqueueV2b": {"color": "cyan", "marker": "s", "linestyle": "--"},
    "SlotqueueV2bc": {"color": "magenta", "marker": "x", "linestyle": "--"},
    "SlotqueueV2c": {"color": "brown", "marker": "+", "linestyle": "--"},
    "LTQueue": {"color": "red", "marker": "s"},
    "FastQueue": {"color": "green", "marker": "^"},
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
            label=f"{queue_name}{'*' if 'V2a' in queue_name else ''}",
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
    "Note: SlotqueueV2a are marked with an asterisk (*) in the legend to indicate they are experimental."
)

