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
            26.0932,
            21.4304,
            16.7575,
            12.4927,
            10.3544,
            8.73542,
            7.25827,
        ],
        "dequeue_latency": [
            0.383242,
            0.466626,
            0.596749,
            0.800467,
            0.965774,
            1.14476,
            1.37774,
        ],
        "enqueue_throughput": [
            32.6573,
            56.3488,
            76.7984,
            54.206,
            54.1057,
            55.7776,
            49.7986,
        ],
        "enqueue_latency": [
            0.30621,
            0.354933,
            0.390634,
            0.737928,
            0.924122,
            1.0757,
            1.40567,
        ],
        "total_throughput": [
            52.1864,
            42.8609,
            33.515,
            24.9855,
            20.7088,
            17.4709,
            14.5166,
        ],
    },
    "LTQueue": {
        "dequeue_throughput": [
            14.3766,
            6.92064,
            5.11002,
            2.86405,
            2.72307,
            2.51691,
            2.10536,
        ],
        "dequeue_latency": [
            0.695576,
            1.44495,
            1.95694,
            3.49156,
            3.67232,
            3.97312,
            4.74979,
        ],
        "enqueue_throughput": [
            14.3794,
            9.46117,
            7.43125,
            4.42041,
            3.96698,
            4.00366,
            3.36004,
        ],
        "enqueue_latency": [
            0.695442,
            2.11391,
            4.03701,
            9.04897,
            12.6041,
            14.9863,
            20.8332,
        ],
        "total_throughput": [
            28.7495,
            13.8413,
            10.22,
            5.72811,
            5.44616,
            5.03383,
            4.21072,
        ],
    },
    "FastQueue": {
        "dequeue_throughput": [
            69.9974,
            67.0051,
            54.7925,
            36.563,
            35.5371,
            34.521,
            32.69,
        ],
        "dequeue_latency": [
            0.142862,
            0.149242,
            0.182507,
            0.273501,
            0.281396,
            0.289678,
            0.305903,
        ],
        "enqueue_throughput": [
            69.9339,
            94.7672,
            82.8406,
            55.4256,
            53.4916,
            61.8244,
            53.3256,
        ],
        "enqueue_latency": [
            0.142992,
            0.211044,
            0.362142,
            0.721691,
            0.934731,
            0.970492,
            1.3127,
        ],
        "total_throughput": [
            139.86,
            134.01,
            109.585,
            73.1261,
            71.0743,
            69.0422,
            65.3803,
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
        )

    # Set title and labels
    title, unit = metric_labels[metric]
    plt.title(f"Comparative {title} Across Queue Implementations")
    plt.xlabel("Number of Processors")
    plt.ylabel(f"{title} ({unit})")

    # Add grid and legend
    plt.grid(True)
    plt.legend()

    # Save the plot
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename)
    plt.close()  # Close the figure to free up memory

print("All comparative plots have been generated in the 'single-one-queue' folder.")
