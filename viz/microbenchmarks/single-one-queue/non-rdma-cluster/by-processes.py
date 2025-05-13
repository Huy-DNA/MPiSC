import matplotlib.pyplot as plt
import os

# Ensure the output directory exists
output_dir = "non-rdma-cluster/all/by-processes/"
os.makedirs(output_dir, exist_ok=True)

# Data for processors and queue types - expanded to include processors 2-32
processors = [
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
]

# Data for different queues and metrics - updated with all data points
queue_data = {
    "SlotQueue": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "LTQueue": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "FastQueue": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "SlotqueueV2a": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "SlotqueueV2b": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "SlotqueueV2bc": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
    },
    "SlotqueueV2c": {
        "dequeue_throughput": [],
        "dequeue_latency": [],
        "enqueue_throughput": [],
        "enqueue_latency": [],
        "total_throughput": [],
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
    "SlotqueueV2b": {"color": "pink", "marker": "o", "linestyle": "--"},
    "SlotqueueV2bc": {"color": "black", "marker": "s", "linestyle": "--"},
    "SlotqueueV2c": {"color": "orange", "marker": "^", "linestyle": "--"},
}

# Generate merged plots for each metric
for metric in metrics:
    # Create a new figure for each metric
    plt.figure(figsize=(14, 8))

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
    plt.title(f"Comparative {title} Across Queue Implementations (2-32 Processors)")
    plt.xlabel("Number of Processors")
    plt.ylabel(f"{title} ({unit})")

    # Add grid and legend
    plt.grid(True)
    plt.legend(title="Queue Types", loc="best")

    # Add x-axis ticks for every processor count
    plt.xticks(processors)

    # Save the plot
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename, dpi=300)
    plt.close()  # Close the figure to free up memory

print(
    "All comparative plots have been generated in the 'non-rdma-cluster/all/by-processes' folder."
)

# Ensure the output directory exists
output_dir = "non-rdma-cluster/no-ltqueue/by-processes/"
os.makedirs(output_dir, exist_ok=True)

# Generate merged plots for each metric
for metric in metrics:
    # Create a new figure for each metric
    plt.figure(figsize=(14, 8))

    # Plot data for each queue
    for queue_name, queue_metrics in queue_data.items():
        if queue_name != "LTQueue":
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
    plt.title(f"Comparative {title} Across Queue Implementations (2-32 Processors)")
    plt.xlabel("Number of Processors")
    plt.ylabel(f"{title} ({unit})")

    # Add grid and legend
    plt.grid(True)
    plt.legend(title="Queue Types", loc="best")

    # Add x-axis ticks for every processor count
    plt.xticks(processors)

    # Save the plot
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename, dpi=300)
    plt.close()  # Close the figure to free up memory

print(
    "All comparative plots have been generated in the 'non-rdma-cluster/no-ltqueue/by-processes' folder."
)

print(
    "Note: SlotqueueV2a is marked with an asterisk (*) in the legend to indicate it is experimental."
)
