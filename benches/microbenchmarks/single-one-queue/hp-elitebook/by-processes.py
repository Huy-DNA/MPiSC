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
