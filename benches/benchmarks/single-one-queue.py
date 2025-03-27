import matplotlib.pyplot as plt
import os

# Ensure the output directory exists
output_dir = "single-one-queue"
os.makedirs(output_dir, exist_ok=True)

# Data for processors and queue types
processors = [2, 3, 4, 5, 6, 7, 8]

# Data for different queues and metrics
queue_data = {
    "SlotQueue": {
        "dequeue_throughput": [
            24.63,
            20.7874,
            16.0944,
            11.7676,
            9.42335,
            7.93033,
            7.08211,
        ],
        "dequeue_latency": [
            0.40601,
            0.48106,
            0.621334,
            0.849788,
            1.06119,
            1.26098,
            1.41201,
        ],
        "enqueue_throughput": [
            25.7473,
            51.4197,
            75.5058,
            51.4547,
            51.201,
            49.5148,
            54.6076,
        ],
        "enqueue_latency": [
            0.388391,
            0.388956,
            0.397321,
            0.777383,
            0.976544,
            1.21176,
            1.28187,
        ],
        "total_throughput": [
            49.2599,
            41.5749,
            32.1888,
            23.5353,
            18.8467,
            15.8607,
            14.1643,
        ],
    },
    "LTQueue": {
        "dequeue_throughput": [
            13.6337,
            7.10488,
            5.10363,
            2.83379,
            2.66681,
            2.46513,
            2.10622,
        ],
        "dequeue_latency": [
            0.733479,
            1.40748,
            1.95939,
            3.52885,
            3.7498,
            4.05657,
            4.74784,
        ],
        "enqueue_throughput": [
            13.6642,
            9.9025,
            7.5172,
            4.38752,
            3.83805,
            3.93446,
            3.34175,
        ],
        "enqueue_latency": [
            0.73184,
            2.01969,
            3.99085,
            9.11676,
            13.0275,
            15.2499,
            20.9471,
        ],
        "total_throughput": [
            27.2643,
            14.2098,
            10.2073,
            5.66758,
            5.33363,
            4.93027,
            4.21245,
        ],
    },
    "FastQueue": {
        "dequeue_throughput": [
            62.2857,
            59.3708,
            61.1692,
            35.8975,
            33.2515,
            31.4346,
            28.9998,
        ],
        "dequeue_latency": [
            0.160551,
            0.168433,
            0.163481,
            0.278571,
            0.300738,
            0.318121,
            0.34483,
        ],
        "enqueue_throughput": [
            62.624,
            97.783,
            130.639,
            58.9566,
            57.2932,
            60.2429,
            50.7002,
        ],
        "enqueue_latency": [
            0.159683,
            0.204535,
            0.22964,
            0.678466,
            0.872705,
            0.995968,
            1.38067,
        ],
        "total_throughput": [
            124.428,
            118.742,
            122.339,
            71.7951,
            66.5032,
            62.8692,
            57.9998,
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
            label=queue_name,
            linewidth=2,
            markersize=8,
        )

    # Set title and labels
    title, unit = metric_labels[metric]
    plt.title(f"Comparative {title} Across Queue Implementations", fontsize=16)
    plt.xlabel("Number of Processors", fontsize=12)
    plt.ylabel(f"{title} ({unit})", fontsize=12)

    # Add grid and legend
    plt.grid(True, linestyle="--", alpha=0.7)
    plt.legend(fontsize=10)

    # Adjust layout
    plt.tight_layout()

    # Save the plot
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename, dpi=300)
    plt.close()  # Close the figure to free up memory

print("All comparative plots have been generated in the 'single-one-queue' folder.")
